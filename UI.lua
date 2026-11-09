-- Buff Digger: minimap button, settings window, two list windows, and the "pick a buff" menu.
-- Minimap button: left click = settings, right click = Get buffs, Shift+right click = Give buffs,
-- drag = move around the minimap.
--   * Get buffs (idea 4, "Nearby" before 0.4.0): who around can give me what; click asks, right click picks the buff (#4).
--   * Give buffs (idea 5, buffer classes): who around lacks a buff I can cast, chosen from THEIR
--     class preferences; one click casts it on them (secure button, out of combat only).
-- Both hide in combat and come back after it.

local _, ns = ...
local BUFFS, rankAt, L = ns.BUFFS, ns.rankAt, ns.L
local MAX_ROWS = 30 -- rows built per window; how many show depends on the height the player gives it
local DEFAULT_SIZE = { 290, 240 } -- 10 rows
local ROW_HEIGHT = 20
local DELAYS = { 60, 120, 300, 600 } -- choices for the anti-nagging delay (#6)
local REFRESH_CHOICES = { 0, 120, 300, 600 } -- ask again when less than this is left (0 = never)
local SKIP_AFTER_CAST = 10 -- seconds a player I just buffed with the next-player key stays out of its aim
local MAX_BUFFS = 3 -- a paladin or a priest gives at most 3 of our buffs: one icon slot each
local PLATE_CHOICES = { { "off", "Nothing" }, { "hint", "Small icon" }, { "best", "Best buff" }, { "all", "Every buff" } }

local function classColored(text, class)
  local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  return color and ("|c" .. color.colorStr .. text .. "|r") or text
end

local function spellName(key) return C_Spell.GetSpellName(BUFFS[key].id) or BUFFS[key].en end

-- Hovering a buff icon (nameplate or Get buffs): the spell, the rank they can probably give, what a click does.
function ns.buffTooltip(owner, unit, key)
  if not (key and unit) or InCombatLockdown() then return end
  local name, _, level = ns.identity(unit)
  if not name then return end
  local buff = BUFFS[key]
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:AddLine(spellName(key))
  local rank = rankAt(buff, level)
  if rank > 0 then
    GameTooltip:AddLine(L["Rank %d"]:format(rank) .. (" (+%s %s)"):format(buff.values[rank], L[buff.stat]), 1, 1, 1)
  end
  if ns.haveBuff(key) then GameTooltip:AddLine(L["You have it already."], 0.6, 0.6, 0.6) end
  GameTooltip:AddLine(L["Click: ask %s for it. Right click: other buffs."]:format(name), 0.4, 0.8, 1, true)
  GameTooltip:Show()
end

-- ---------------------------------------------------------------- pick-a-buff menu (#4)

-- Right click on an icon or a Get buffs line: every buff that player can probably give,
-- my priorities first. Choosing one asks for it, whatever the automatic choice would be.
function ns.openMenu(owner, unit)
  if InCombatLockdown() or not unit then return end
  if not (MenuUtil and MenuUtil.CreateContextMenu) then ns.notice(L["The game's menu is not available."]) return end
  local name, class, level = ns.identity(unit)
  if not name then return end
  local offers = ns.offers(class, level)
  if #offers == 0 then ns.notice(L["%s has nothing better for you right now."]:format(name)) return end
  MenuUtil.CreateContextMenu(owner, function(_, root)
    root:CreateTitle(L["Ask %s for:"]:format(name))
    for _, key in ipairs(offers) do
      local label = ("|T%s:0|t %s |cff9d9d9d" .. L["Rank %d"] .. "|r%s"):format(C_Spell.GetSpellTexture(BUFFS[key].id) or 134400, spellName(key),
        rankAt(BUFFS[key], level), ns.haveBuff(key) and L[" (you have it)"] or "")
      root:CreateButton(label, function()
        -- In a city, the nameplate token may now belong to someone else: check it is still them.
        if not ns.truthy(UnitExists(unit)) or UnitName(unit) ~= name then
          ns.notice(L["%s is no longer around."]:format(name))
          return
        end
        ns.request(unit, key)
      end)
    end
  end)
end

-- ---------------------------------------------------------------- settings window
-- Layout follows Blizzard's own option panels: gold section titles, white option labels, small
-- grey help. Spacing on a 4/8 px grid; every text has a fixed width and wraps instead of overflowing.

local PAD, COL_W, ROW_H, GAP = 16, 296, 24, 8
local LEFT_X, RIGHT_X = PAD, PAD + COL_W + 24

local SECTIONS = {
  { title = "Display", options = {
    { key = "tooltip", label = "Line in players' tooltip" },
    { key = "nearby",  label = "Get buffs window: who can buff me" },
    { key = "give",    label = "Give buffs window: who lacks my buffs", soon = true },
  }, nameplates = true, plates = true },
  { title = "Requests", options = {
    { key = "useSay",  label = "Ask in /say by default (not whisper)" },
    { key = "acceptRequests", label = "Pop up requests from Buff Digger users", soon = true },
  }, delay = true, language = true },
  { title = "Thanks", options = {
    { key = "thank",   label = "/thank emote when someone buffs me" },
    { key = "thankMessage", label = "Thank-you in my request's channel" },
  } },
  { title = "Advanced", options = {
    { key = "debug",   label = "Debug messages in chat" },
  } },
}

local settings, prefRows, refreshPrefs

-- My class's priority list, copied from the defaults the first time it is edited (#5).
local function myPrefs(create)
  local _, myClass = UnitClass("player")
  if create and not BuffDiggerDB.prefs[myClass] then
    BuffDiggerDB.prefs[myClass] = { unpack(ns.PREFERENCES[myClass] or {}) }
  end
  return ns.prefsFor(myClass)
end

local function indexOf(list, value)
  for i, v in ipairs(list) do if v == value then return i end end
end

-- Ticked buffs in priority order, then the unticked ones.
local function prefOrder()
  local order, prefs = {}, myPrefs(false)
  for _, key in ipairs(prefs) do order[#order + 1] = key end
  local rest = {}
  for key in pairs(BUFFS) do if not indexOf(prefs, key) then rest[#rest + 1] = key end end
  table.sort(rest)
  for _, key in ipairs(rest) do order[#order + 1] = key end
  return order
end

local function changed()
  refreshPrefs()
  ns.refreshAll()
end

local function text(parent, font, x, y, width, value)
  local fs = parent:CreateFontString(nil, "OVERLAY", font)
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetWidth(width)
  fs:SetJustifyH("LEFT")
  fs:SetText(value)
  return fs
end

local function arrow(parent, texture, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(20, 20)
  b:SetNormalTexture(texture .. "-Up")
  b:SetPushedTexture(texture .. "-Down")
  b:SetDisabledTexture(texture .. "-Disabled")
  b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  b:SetScript("OnClick", onClick)
  return b
end

local function checkbox(x, y, option)
  local box = CreateFrame("CheckButton", nil, settings, "UICheckButtonTemplate")
  box:SetSize(ROW_H, ROW_H)
  box:SetPoint("TOPLEFT", x, y)
  local label = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("LEFT", box, "RIGHT", 4, 0)
  label:SetWidth(COL_W - ROW_H - 8)
  label:SetJustifyH("LEFT")
  label:SetText(L[option.label])
  local soon = option.soon and not ns.CASTING
  if soon then -- a feature that casts: greyed until it works in Forever
    box:Disable()
    label:SetText(L[option.label] .. L[" (coming soon)"])
    label:SetTextColor(0.5, 0.5, 0.5)
  end
  box:SetScript("OnShow", function(self) self:SetChecked(not soon and BuffDiggerDB[option.key]) end)
  box:SetScript("OnClick", function(self)
    BuffDiggerDB[option.key] = self:GetChecked() and true or false
    ns.applyWindows()
    ns.refreshAll()
  end)
end

-- A label and a small button; each click moves to the next choice (in seconds, shown in minutes).
local function cycleRow(x, y, caption, key, choices)
  text(settings, "GameFontHighlight", x + 4, y - 4, COL_W - 80, L[caption])
  local button = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
  button:SetSize(64, 22)
  button:SetPoint("TOPLEFT", x + COL_W - 64, y)
  local function label()
    return BuffDiggerDB[key] == 0 and L["Never"] or L["%d min"]:format(BuffDiggerDB[key] / 60)
  end
  button:SetScript("OnShow", function(self) self:SetText(label()) end)
  button:SetScript("OnClick", function(self)
    local i = indexOf(choices, BuffDiggerDB[key]) or 1
    BuffDiggerDB[key] = choices[i % #choices + 1]
    self:SetText(label())
    ns.refreshAll()
  end)
end

-- A label and a button showing the current choice, opening the list. choices = { { value, label }, ... }
-- (labels are shown as is: language names stay in their own language).
local function choiceRow(x, y, caption, key, choices, translate)
  text(settings, "GameFontHighlight", x + 4, y - 4, COL_W - 120, L[caption])
  local button = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
  button:SetSize(104, 22)
  button:SetPoint("TOPLEFT", x + COL_W - 104, y)
  local function label(c) return translate and L[c[2]] or c[2] end
  local function current()
    for i, c in ipairs(choices) do
      if c[1] == BuffDiggerDB[key] then return i, label(c) end
    end
    return 1, label(choices[1])
  end
  local function choose(value)
    BuffDiggerDB[key] = value
    button:SetText(select(2, current()))
    ns.refreshAll()
  end
  button:SetScript("OnShow", function(self) self:SetText(select(2, current())) end)
  button:SetScript("OnClick", function(self)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then -- no menu: each click moves to the next one
      choose(choices[current() % #choices + 1][1])
      return
    end
    MenuUtil.CreateContextMenu(self, function(_, root)
      for _, c in ipairs(choices) do
        root:CreateRadio(label(c), function() return BuffDiggerDB[key] == c[1] end, function() choose(c[1]) end)
      end
    end)
  end)
end

-- Friendly nameplates: their state, and a button to turn them on.
local function nameplateRow(x, y)
  local label = text(settings, "GameFontHighlight", x + 4, y - 4, COL_W - 96, "")
  local button = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
  button:SetSize(80, 22)
  button:SetPoint("TOPLEFT", x + COL_W - 80, y)
  button:SetText(L["Turn on"])
  local function update()
    local on = ns.friendlyPlatesOn()
    label:SetText(on and L["Friendly nameplates: on"] or L["|cffff5555Friendly nameplates: off|r (needed)"])
    button:SetEnabled(not on)
  end
  button:SetScript("OnShow", update)
  button:SetScript("OnClick", function()
    ns.turnOnFriendlyPlates()
    update()
  end)
end

-- Left column; returns how far down it went.
local function buildOptions()
  local y = -32
  for _, section in ipairs(SECTIONS) do
    text(settings, "GameFontNormal", LEFT_X, y, COL_W, L[section.title])
    y = y - 20
    for _, option in ipairs(section.options) do
      checkbox(LEFT_X, y, option)
      y = y - ROW_H
    end
    if section.plates then
      choiceRow(LEFT_X, y - 4, "On nameplates", "plates", PLATE_CHOICES, true)
      y = y - 28
    end
    if section.nameplates then
      nameplateRow(LEFT_X, y - 4)
      y = y - 28
    end
    if section.language then
      choiceRow(LEFT_X, y - 4, "Write to players in", "language", ns.LANGUAGES)
      y = y - 28
    end
    if section.delay then
      cycleRow(LEFT_X, y - 4, "Wait before asking again", "delay", DELAYS) -- #6
      y = y - 28
      cycleRow(LEFT_X, y - 4, "Ask again when a buff has less left than", "refreshBefore", REFRESH_CHOICES)
      y = y - 28
    end
    y = y - GAP
  end
  return y
end

-- Right column: my class's priorities (#5); returns how far down it went.
local function buildPrefs()
  local _, myClass = UnitClass("player")
  local className = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[myClass] or myClass
  text(settings, "GameFontNormal", RIGHT_X, -32, COL_W, L["My buff priorities (%s)"]:format(className))
  text(settings, "GameFontDisableSmall", RIGHT_X, -52, COL_W,
    L["Ticked buffs get asked for, top first. Unticked: never asked."])

  prefRows = {}
  local count, y = 0, -72
  for _ in pairs(BUFFS) do count = count + 1 end
  for i = 1, count do
    local row = CreateFrame("Frame", nil, settings)
    row:SetSize(COL_W, ROW_H)
    row:SetPoint("TOPLEFT", RIGHT_X, y)
    row.box = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.box:SetSize(ROW_H, ROW_H)
    row.box:SetPoint("LEFT")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18) -- room for the rank number in its corner
    row.icon:SetPoint("LEFT", row.box, "RIGHT", 4, 0)
    row.down = arrow(row, "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown", function()
      local prefs = myPrefs(true)
      local at = indexOf(prefs, row.key)
      prefs[at], prefs[at + 1] = prefs[at + 1], prefs[at]
      changed()
    end)
    row.down:SetPoint("RIGHT")
    row.up = arrow(row, "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp", function()
      local prefs = myPrefs(true)
      local at = indexOf(prefs, row.key)
      prefs[at], prefs[at - 1] = prefs[at - 1], prefs[at]
      changed()
    end)
    row.up:SetPoint("RIGHT", row.down, "LEFT", -4, 0)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.text:SetPoint("RIGHT", row.up, "LEFT", -8, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row.box:SetScript("OnClick", function(self)
      local prefs = myPrefs(true)
      local at = indexOf(prefs, row.key)
      if self:GetChecked() and not at then tinsert(prefs, row.key)
      elseif not self:GetChecked() and at then tremove(prefs, at) end
      changed()
    end)
    prefRows[i] = row
    y = y - ROW_H
  end

  local reset = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
  reset:SetSize(120, 22)
  reset:SetPoint("TOPLEFT", RIGHT_X, y - GAP)
  reset:SetText(L["Reset to default"])
  reset:SetScript("OnClick", function()
    BuffDiggerDB.prefs[myClass] = nil
    changed()
  end)
  return y - GAP - 22
end

refreshPrefs = function()
  if not prefRows then return end
  local prefs = myPrefs(false)
  for i, key in ipairs(prefOrder()) do
    local row, at = prefRows[i], indexOf(prefs, key)
    row.key = key
    row.box:SetChecked(at ~= nil)
    row.icon:SetTexture(C_Spell.GetSpellTexture(BUFFS[key].id))
    row.icon:SetDesaturated(at == nil)
    row.text:SetText((at and (at .. ". ") or "") .. spellName(key))
    row.text:SetTextColor(at and 1 or 0.5, at and 1 or 0.5, at and 1 or 0.5)
    row.up:SetEnabled(at ~= nil and at > 1)
    row.down:SetEnabled(at ~= nil and at < #prefs)
  end
end

local HOW_TO = {
  "Click a buff icon to ask for that buff, a name in Get buffs for the best one. Shift/Ctrl-click: /say instead of whisper (or the reverse).",
  "Right-click: every buff that player can give.",
  "Minimap button: right click = Get buffs.",
  "Key Bindings > AddOns > Buff Digger: one key asks the best buff around you.",
  "Icons and windows find players through friendly nameplates: keep them on.",
}

local function buildSettings()
  settings = CreateFrame("Frame", "BuffDiggerSettings", UIParent, "BasicFrameTemplateWithInset")
  settings:SetPoint("CENTER")
  settings:SetMovable(true)
  settings:EnableMouse(true)
  settings:RegisterForDrag("LeftButton")
  settings:SetScript("OnDragStart", settings.StartMoving)
  settings:SetScript("OnDragStop", settings.StopMovingOrSizing)
  settings:SetScript("OnShow", function() refreshPrefs() end)
  settings:Hide()
  tinsert(UISpecialFrames, "BuffDiggerSettings") -- Escape closes it

  local title = settings:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", 0, -5)
  title:SetText("Buff Digger")

  local bottom = math.min(buildOptions(), buildPrefs()) - GAP
  local width = RIGHT_X + COL_W + PAD
  text(settings, "GameFontNormal", LEFT_X, bottom, width - 2 * PAD, L["How to use"])
  local lines = {}
  for i, line in ipairs(HOW_TO) do lines[i] = L[line] end
  local help = text(settings, "GameFontDisableSmall", LEFT_X, bottom - 20, width - 2 * PAD, table.concat(lines, "\n"))
  help:SetSpacing(2)
  -- GetStringHeight can be 0 on a hidden frame: never less than one line per tip.
  local helpHeight = math.max(help:GetStringHeight() or 0, #HOW_TO * 14)
  settings:SetSize(width, -bottom + 20 + helpHeight + PAD + 4)
end

function ns.toggleSettings()
  if not settings then return end
  settings:SetShown(not settings:IsShown())
end

-- ---------------------------------------------------------------- minimap button

local function placeMinimapButton(button)
  local angle = math.rad(BuffDiggerDB.minimapAngle or 200)
  local radius = Minimap:GetWidth() / 2 + 8
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function buildMinimapButton()
  local button = CreateFrame("Button", "BuffDiggerMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local icon = button:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(21, 21)
  icon:SetPoint("CENTER")
  icon:SetTexture("Interface\\AddOns\\BuffDigger\\Media\\icon") -- round 64x64 TGA, from docs/logo.png
  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  button:SetScript("OnClick", function(_, mouse)
    ns.flushThanks() -- a real click: waiting thanks can go out
    if mouse ~= "RightButton" then ns.toggleSettings()
    elseif IsShiftKeyDown() then ns.toggleGive()
    else ns.toggleWindow() end
  end)
  -- Hover: what each click does (the only place the shortcuts are listed outside the settings).
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Buff Digger")
    GameTooltip:AddDoubleLine(L["Left click"], L["Settings"], 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(L["Right click"], L["Get buffs: who can buff me"], 1, 1, 1, 1, 1, 1)
    if ns.CASTING then
      GameTooltip:AddDoubleLine(L["Shift + right click"], L["Give buffs: who lacks mine"], 1, 1, 1, 1, 1, 1)
    else
      GameTooltip:AddDoubleLine(L["Shift + right click"], L["Give buffs (coming soon)"], 0.5, 0.5, 0.5, 0.5, 0.5, 0.5)
    end
    GameTooltip:AddDoubleLine(L["Drag"], L["Move this button"], 1, 1, 1, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Key Bindings > AddOns > Buff Digger: one key asks the best buff around you."], 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      BuffDiggerDB.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
      placeMinimapButton(self)
    end)
  end)
  button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  placeMinimapButton(button)
end

-- ---------------------------------------------------------------- list windows

local listWindows = {} -- Get buffs and Give buffs: they share the padlock

-- Padlock look and resize grip, from the setting (neither is secure: fine in combat too).
local function applyLock()
  for _, w in ipairs(listWindows) do
    w.grip:SetShown(not BuffDiggerDB.lockWindows)
    w.lock:SetNormalTexture(BuffDiggerDB.lockWindows and "Interface\\Buttons\\LockButton-Locked-Up"
      or "Interface\\Buttons\\LockButton-Unlocked-Up")
  end
end

-- Rows that fit in the window's current height.
local function visibleRows(w)
  return math.max(1, math.min(MAX_ROWS, math.floor((w:GetHeight() - 40) / ROW_HEIGHT)))
end

-- A movable, resizable window holding up to MAX_ROWS lines; `secure` lines cast a spell on click.
-- Size kept in BuffDiggerDB.sizes; "Lock windows" stops both moving and resizing.
-- `setting` is the BuffDiggerDB key that remembers whether it is open.
local function makeWindow(globalName, title, setting, secure, point)
  local w = CreateFrame("Frame", globalName, UIParent, "BasicFrameTemplateWithInset")
  BuffDiggerDB.sizes = BuffDiggerDB.sizes or {}
  w:SetSize(unpack(BuffDiggerDB.sizes[globalName] or DEFAULT_SIZE))
  w:SetPoint(unpack(point))
  w:SetMovable(true)
  w:SetResizable(true)
  if w.SetResizeBounds then w:SetResizeBounds(220, 80, 600, 40 + MAX_ROWS * ROW_HEIGHT) end
  w:EnableMouse(true)
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", function(self) if not BuffDiggerDB.lockWindows then self:StartMoving() end end)
  w:SetScript("OnDragStop", w.StopMovingOrSizing)
  -- Bottom-right grip, like the chat frame's.
  w.grip = CreateFrame("Button", nil, w)
  w.grip:SetSize(16, 16)
  w.grip:SetPoint("BOTTOMRIGHT", -3, 3)
  w.grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  w.grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  w.grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  w.grip:SetScript("OnMouseDown", function()
    if not (InCombatLockdown() or BuffDiggerDB.lockWindows) then w:StartSizing("BOTTOMRIGHT") end
  end)
  w.grip:SetScript("OnMouseUp", function() w:StopMovingOrSizing() end)
  -- Padlock left of the close button: locked = no move, no resize (both list windows at once).
  w.lock = CreateFrame("Button", nil, w)
  w.lock:SetSize(18, 18)
  w.lock:SetPoint("RIGHT", w.CloseButton, "LEFT", 2, 0)
  w.lock:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  w.lock:SetScript("OnClick", function(self)
    BuffDiggerDB.lockWindows = not BuffDiggerDB.lockWindows
    applyLock()
    if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
  end)
  w.lock:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(BuffDiggerDB.lockWindows and L["Locked: click to move and resize"] or L["Click to lock in place"])
    GameTooltip:Show()
  end)
  w.lock:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- Hidden mid-drag (combat starts): the mouse-up never comes, stop here.
  w:SetScript("OnHide", function(self) self:StopMovingOrSizing() end)
  w:SetScript("OnSizeChanged", function(self, width, height)
    BuffDiggerDB.sizes[globalName] = { math.floor(width), math.floor(height) }
    if self.fill and not InCombatLockdown() then self.fill() end
  end)
  w:Hide()
  -- The window's own close button turns the setting off too.
  w.CloseButton:HookScript("OnClick", function() BuffDiggerDB[setting] = false end)

  local header = w:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  header:SetPoint("TOP", 0, -5)
  header:SetText(title)
  w.empty = w:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  w.empty:SetPoint("TOPLEFT", 14, -32)
  w.empty:SetPoint("RIGHT", -14, 0)
  w.empty:SetJustifyH("LEFT")

  w.rows = {}
  for i = 1, MAX_ROWS do
    local row = CreateFrame("Button", nil, w, secure and "SecureActionButtonTemplate" or nil)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 12, -28 - (i - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", -24, 0) -- room for the scroll arrows
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18) -- room for the rank number in its corner
    row.icon:SetPoint("LEFT", 2, 0)
    row.rank = row:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    row.rank:SetPoint("BOTTOMRIGHT", row.icon, 3, -2)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.text:SetPoint("RIGHT", -2, 0)
    row.text:SetJustifyH("LEFT")
    row.secure = secure
    if secure then
      ns.secureClicks(row)
      ns.watchClick(row)
      row:HookScript("PostClick", function(self, _, down)
        if down then return end -- registered for down and up: act once
        if not self:GetAttribute("type") then ns.notice(L["Too far"]) return end
        ns.castOn()
      end)
    else
      row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      row:SetScript("OnClick", function(self, mouse)
        if mouse == "RightButton" then ns.openMenu(self, self.unit) else ns.request(self.unit) end
      end)
      -- One icon slot per buff they can give, my priorities left to right; the name comes after,
      -- so names line up whatever the number of icons. Click an icon = that buff, the name = the best.
      row.icon:Hide()
      row.buffs = {}
      for j = 1, MAX_BUFFS do
        local b = CreateFrame("Button", nil, row)
        b:SetSize(18, 18)
        b:SetPoint("LEFT", 2 + (j - 1) * 22, 0)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.rank = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        b.rank:SetPoint("BOTTOMRIGHT", 3, -2)
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnClick", function(self, mouse)
          if mouse == "RightButton" then ns.openMenu(self, row.unit) else ns.request(row.unit, self.key) end
        end)
        b:SetScript("OnEnter", function(self) ns.buffTooltip(self, row.unit, self.key) end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.buffs[j] = b
      end
      row.text:ClearAllPoints()
      row.text:SetPoint("LEFT", 2 + MAX_BUFFS * 22 + 4, 0)
      row.text:SetPoint("RIGHT", -2, 0)
    end
    row:Hide()
    w.rows[i] = row
  end
  -- More players than rows (a city): the mouse wheel scrolls; small arrows show there is more
  -- above or below, and a click on one scrolls too.
  -- Get buffs only: Give buffs rows aim spells at nameplate tokens that a scroll would leave stale.
  w.offset = 0
  local function scroll(delta)
    if InCombatLockdown() or secure or not w.entries then return end
    w.offset = math.max(0, math.min(w.offset - delta, #w.entries - visibleRows(w)))
    w.fill()
  end
  w:EnableMouseWheel(not secure)
  w:SetScript("OnMouseWheel", function(_, delta) scroll(delta) end)
  local function arrow(dir, delta, point, y)
    local a = CreateFrame("Button", nil, w)
    a:SetSize(16, 16)
    a:SetPoint(point, -6, y)
    a:SetNormalTexture("Interface\\Buttons\\Arrow-" .. dir .. "-Up")
    a:SetPushedTexture("Interface\\Buttons\\Arrow-" .. dir .. "-Down")
    a:SetScript("OnClick", function() scroll(delta) end)
    a:Hide()
    return a
  end
  w.up, w.down = arrow("Up", 1, "TOPRIGHT", -28), arrow("Down", -1, "BOTTOMRIGHT", 20)
  listWindows[#listWindows + 1] = w
  applyLock()
  return w
end

-- entries: { { unit, text, icon, rank, upgrade, spell (secure windows; nil = shown greyed, not castable),
--   buffs = { { key, best, icon, rank, upgrade }, ... } (Get buffs: one icon per buff) }, ... }
local function fill(w, entries, emptyMessage)
  w.entries = entries
  w.fill = function() fill(w, w.entries, emptyMessage) end
  local shown = visibleRows(w)
  w.offset = math.max(0, math.min(w.offset, #entries - shown))
  for i, row in ipairs(w.rows) do
    local e = i <= shown and entries[w.offset + i] or nil
    if e then
      row.unit = e.unit
      row.icon:SetTexture(e.icon)
      row.text:SetText(e.text)
      row.rank:SetText(e.rank or "")
      -- Green: higher than the one I have, like an upgrade in a loot tooltip.
      if e.upgrade then row.rank:SetTextColor(0.1, 1, 0.1) else row.rank:SetTextColor(1, 1, 1) end
      for j, b in ipairs(row.secure and {} or row.buffs) do
        local buff = e.buffs[j]
        if buff then
          b.key = buff.key
          b.icon:SetTexture(buff.icon)
          ns.styleBuff(b, buff.key, buff.best)
          b.rank:SetText(buff.rank)
          if buff.upgrade then b.rank:SetTextColor(0.1, 1, 0.1) else b.rank:SetTextColor(1, 1, 1) end
        end
        b:SetShown(buff ~= nil)
      end
      if row.secure then
        -- Every attribute is set each time: a row reused for another player never keeps the old target.
        ns.aimCast(row, e.unit, e.spell)
        row.icon:SetDesaturated(e.spell == nil)
        local c = e.spell and 1 or 0.5
        row.text:SetTextColor(c, c, c)
      end
    end
    row:SetShown(e ~= nil)
  end
  w.empty:SetText(emptyMessage)
  w.empty:SetShown(#entries == 0)
  w.up:SetShown(not w.rows[1].secure and w.offset > 0)
  w.down:SetShown(not w.rows[1].secure and #entries - w.offset > shown)
end

local nearby, give, giveNext

-- ---------------------------------------------------------------- Get buffs (idea 4)

-- Everyone around who can give me something: those with a buff I'm missing (or an upgrade) first,
-- my top pick first among them; then the ones whose buffs I all have, for picking by hand.
local function nearbyEntries()
  local entries = {}
  for _, unit in ipairs(ns.nearbyUnits()) do
    local name, class, level = ns.identity(unit)
    local offers = name and ns.offers(class, level) or {}
    if #offers > 0 then
      local key, kind, top = ns.bestBuff(name, class, level)
      local buffs = {}
      for j = 1, math.min(#offers, MAX_BUFFS) do
        local k = offers[j]
        buffs[j] = {
          key = k, icon = C_Spell.GetSpellTexture(BUFFS[k].id), rank = rankAt(BUFFS[k], level),
          upgrade = k == key and kind == "upgrade", best = key,
        }
      end
      local extra = kind == "replace" and L[" (swap)"] or kind == "upgrade" and L[" (higher rank)"]
        or kind == "refresh" and L[" (running out)"] or ""
      entries[#entries + 1] = {
        unit = unit, buffs = buffs, order = key and (top and 0 or 1) or 2,
        text = ("%s%s %d%s"):format(classColored(name, class),
          ns.isPeer(name) and " |TInterface\\COMMON\\FavoritesIcon:12|t" or "", level, key and extra or ""),
      }
    end
  end
  -- table.sort is not stable: keep the nameplate order within each group.
  for i, e in ipairs(entries) do e.i = i end
  table.sort(entries, function(a, b) if a.order ~= b.order then return a.order < b.order end return a.i < b.i end)
  return entries
end

-- ---------------------------------------------------------------- Give buffs (idea 5)

-- Does this unit have this buff (rank 1 or group version)? Second value: cast by me.
-- nil when the game keeps it secret.
local function unitHas(unit, buff)
  local ids = { buff.id }
  for _, id in ipairs(buff.group or {}) do ids[#ids + 1] = id end
  for _, id in ipairs(ids) do
    local name = C_Spell.GetSpellName(id)
    if name then
      local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, name, "HELPFUL")
      if not ok or not ns.readable(aura) then
        ns.record("others", false, ok and "aura secret" or tostring(aura))
        return nil
      end
      if aura then
        ns.record("others", true)
        return true, ns.readable(aura.sourceUnit) and aura.sourceUnit == "player"
      end
    end
  end
  ns.record("others", true)
  return false
end
ns.unitHas = unitHas

local function myCastableBuffs()
  local _, myClass = UnitClass("player")
  local list = {}
  for key, buff in pairs(BUFFS) do
    if buff.class == myClass and IsPlayerSpell(buff.id) then list[#list + 1] = key end
  end
  return list
end

-- Which of my buffs should this player get? THEIR class's default preferences decide (not my
-- own edited list: that one says what I want, not what a warrior wants).
-- A paladin keeps one blessing per target: if mine is already on them, offer nothing.
local function buffToGive(unit, theirClass, myBuffs)
  local _, myClass = UnitClass("player")
  if myClass == "PALADIN" then
    for _, key in ipairs(myBuffs) do
      local _, fromMe = unitHas(unit, BUFFS[key])
      if fromMe then return end
    end
  end
  for _, key in ipairs(ns.PREFERENCES[theirClass] or {}) do
    for _, mineKey in ipairs(myBuffs) do
      if key == mineKey then
        local has = unitHas(unit, BUFFS[key])
        if has == false then return key end
        if has == nil then return end -- unreadable: stay silent rather than guess
      end
    end
  end
end

-- Players I just buffed with the next-player key: name -> GetTime(). They stay out of the list a
-- few seconds, so pressing the key again moves on to someone else, even when the game can't show me
-- their new buff yet or the cast failed (line of sight). A click in the window passes no unit.
local justCast = {}

function ns.castOn(unit)
  ns.flushThanks()
  local name = unit and UnitName(unit)
  if ns.readable(name) and name then justCast[name] = GetTime() end
  C_Timer.After(1, ns.refreshAll)
end

local function giveEntries(myBuffs)
  local entries = {}
  for _, unit in ipairs(ns.nearbyUnits()) do
    local name, class, level = ns.identity(unit)
    if name and justCast[name] and GetTime() - justCast[name] < SKIP_AFTER_CAST then name = nil end
    local key = name and buffToGive(unit, class, myBuffs)
    if key then
      local spell = C_Spell.GetSpellName(BUFFS[key].id)
      -- Nameplates show players far beyond a buff's 30 yards: those are listed greyed, not
      -- clickable, after the ones in range. nil (the game can't tell) counts as in range.
      local r = C_Spell.IsSpellInRange and C_Spell.IsSpellInRange(BUFFS[key].id, unit)
      local far = ns.readable(r) and r == false
      entries[#entries + 1] = {
        unit = unit,
        name = name,
        far = far,
        icon = C_Spell.GetSpellTexture(BUFFS[key].id),
        text = ("%s %d — %s%s"):format(classColored(name, class), level, spell, far and L[" (too far)"] or ""),
        spell = not far and spell or nil,
      }
    end
  end
  local sorted = {}
  for _, e in ipairs(entries) do if not e.far then sorted[#sorted + 1] = e end end
  for _, e in ipairs(entries) do if e.far then sorted[#sorted + 1] = e end end
  return sorted
end

-- I cast at someone (macro or by hand): skip them for a few seconds, the macro moves to the next one.
function ns.onSpellSent(target)
  local name = target:match("^[^-]+") -- "Name-Realm" -> "Name", as in justCast
  if not name then return end -- no target (a buff on myself)
  justCast[name] = GetTime()
  C_Timer.After(1, ns.refreshAll)
end

-- ---------------------------------------------------------------- refresh and visibility

function ns.refreshWindow()
  if InCombatLockdown() then return end -- secure rows cannot change in combat
  if nearby and nearby:IsShown() then
    fill(nearby, nearbyEntries(), L["Nobody around can buff you.\n(Friendly nameplates on?)"])
  end
  -- The next-player key works without the window, once it is bound.
  local nextBound = GetBindingKey and GetBindingKey("CLICK BuffDiggerGiveNext:LeftButton")
  if not ns.CASTING or not ((give and give:IsShown()) or nextBound) then return end
  local myBuffs = myCastableBuffs()
  local entries = #myBuffs > 0 and giveEntries(myBuffs) or {}
  -- Never re-fill under the cursor: rows would shift while the player aims (and with
  -- ActionButtonUseKeyDown off, the cast fires on release, on whatever the row then holds).
  if give and give:IsShown() and not (give:IsMouseOver() and #myBuffs > 0) then
    if #myBuffs == 0 then
      fill(give, {}, L["You know no buff to give (paladin, priest, mage or druid)."])
    else
      fill(give, entries, L["Everyone around has your buffs.\n(Friendly nameplates on?)"])
    end
  end
  local first = entries[1] and entries[1].spell and entries[1] -- in range, or nobody
  giveNext.unit = first and first.unit
  ns.aimCast(giveNext, first and first.unit, first and first.spell)
end

-- Show each window according to its setting (out of combat only).
function ns.applyWindows()
  if InCombatLockdown() or not nearby then return end
  nearby:SetShown(BuffDiggerDB.nearby)
  give:SetShown(ns.CASTING and BuffDiggerDB.give)
  ns.refreshWindow()
end

function ns.toggleWindow()
  BuffDiggerDB.nearby = not BuffDiggerDB.nearby
  ns.applyWindows()
end

function ns.toggleGive()
  if not ns.CASTING then ns.notice(L["Give buffs: coming soon."]) return end
  BuffDiggerDB.give = not BuffDiggerDB.give
  ns.applyWindows()
end

-- Hide on entering combat (still allowed during PLAYER_REGEN_DISABLED), back on leaving it.
function ns.onCombat(inCombat)
  if not nearby then return end
  if inCombat then
    nearby:Hide()
    give:Hide()
    -- Still allowed during PLAYER_REGEN_DISABLED: in combat the key can't be re-aimed (nameplate
    -- tokens move to other players), so it does nothing until combat ends.
    giveNext:SetAttribute("type", nil)
  else
    ns.applyWindows()
  end
end

function ns.buildUI()
  buildSettings()
  buildMinimapButton()
  nearby = makeWindow("BuffDiggerNearby", L["Buff Digger — Get buffs"], "nearby", false, { "LEFT", 40, 60 })
  give = makeWindow("BuffDiggerGive", L["Buff Digger — Give buffs"], "give", true, { "LEFT", 40, -140 })
  -- Key "Give my buff to the next player around" (Bindings.xml, CLICK binding): an invisible secure
  -- button aimed at the first Give buffs line, re-aimed after every refresh (out of combat only).
  giveNext = CreateFrame("Button", "BuffDiggerGiveNext", UIParent, "SecureActionButtonTemplate")
  ns.secureClicks(giveNext)
  giveNext:Hide()
  ns.watchClick(giveNext)
  giveNext:HookScript("PostClick", function(self, _, down)
    if down then return end
    if self:GetAttribute("type") then ns.castOn(self.unit)
    else ns.notice(L["Nobody around lacks your buffs right now."]) end
  end)
  -- Players walk in and out of range without any event: look again every second (the windows,
  -- and the next-player key's aim when it is bound).
  C_Timer.NewTicker(1, ns.refreshWindow)
  ns.applyWindows()
end
