-- Buff Digger: minimap button, settings window, two list windows, and the "pick a buff" menu.
-- Minimap button: left click = settings, right click = Nearby, Shift+right click = Give buffs,
-- drag = move around the minimap.
--   * Nearby (idea 4): who around can give me what; click asks, right click picks the buff (#4).
--   * Give buffs (idea 5, buffer classes): who around lacks a buff I can cast, chosen from THEIR
--     class preferences; one click casts it on them (secure button, out of combat only).
-- Both hide in combat and come back after it.

local _, ns = ...
local BUFFS, rankAt, L = ns.BUFFS, ns.rankAt, ns.L
local MAX_ROWS = 10
local ROW_HEIGHT = 20
local DELAYS = { 60, 120, 300, 600 } -- choices for the anti-nagging delay (#6)

local function classColored(text, class)
  local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  return color and ("|c" .. color.colorStr .. text .. "|r") or text
end

local function spellName(key) return C_Spell.GetSpellName(BUFFS[key].id) or BUFFS[key].en end

-- ---------------------------------------------------------------- pick-a-buff menu (#4)

-- Right click on an icon or a Nearby line: every buff that player can probably give,
-- my priorities first. Choosing one asks for it, whatever the automatic choice would be.
function ns.openMenu(owner, unit)
  if InCombatLockdown() or not unit then return end
  if not (MenuUtil and MenuUtil.CreateContextMenu) then ns.say(L["The game's menu is not available."]) return end
  local name, class, level = ns.identity(unit)
  if not name then return end
  local offers = ns.offers(class, level)
  if #offers == 0 then ns.say(L["%s has nothing better for you right now."]:format(name)) return end
  MenuUtil.CreateContextMenu(owner, function(_, root)
    root:CreateTitle(L["Ask %s for:"]:format(name))
    for _, key in ipairs(offers) do
      local label = ("|T%s:0|t %s r%d%s"):format(C_Spell.GetSpellTexture(BUFFS[key].id) or 134400, spellName(key),
        rankAt(BUFFS[key], level), ns.haveBuff(key) and L[" (you have it)"] or "")
      root:CreateButton(label, function()
        -- In a city, the nameplate token may now belong to someone else: check it is still them.
        if not ns.truthy(UnitExists(unit)) or UnitName(unit) ~= name then
          ns.say(L["%s is no longer around."]:format(name))
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
    { key = "icons",   label = "Icon next to players' health bar" },
    { key = "tooltip", label = "Line in players' tooltip" },
    { key = "nearby",  label = "Nearby window: who can buff me" },
    { key = "give",    label = "Give buffs window: who lacks my buffs" },
  }, nameplates = true },
  { title = "Requests", options = {
    { key = "useSay",  label = "Ask in /say by default (not whisper)" },
    { key = "frenchMessages", label = "Write to players in French" },
    { key = "acceptRequests", label = "Pop up requests from Buff Digger users" },
  }, delay = true },
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
  box:SetScript("OnShow", function(self) self:SetChecked(BuffDiggerDB[option.key]) end)
  box:SetScript("OnClick", function(self)
    BuffDiggerDB[option.key] = self:GetChecked() and true or false
    ns.applyWindows()
    ns.refreshAll()
  end)
end

-- Anti-nagging delay: a label and a small button; each click moves to the next choice (#6).
local function delayRow(x, y)
  text(settings, "GameFontHighlight", x + 4, y - 4, COL_W - 80, L["Wait before asking again"])
  local button = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
  button:SetSize(64, 22)
  button:SetPoint("TOPLEFT", x + COL_W - 64, y)
  local function label() return L["%d min"]:format(BuffDiggerDB.delay / 60) end
  button:SetScript("OnShow", function(self) self:SetText(label()) end)
  button:SetScript("OnClick", function(self)
    local i = indexOf(DELAYS, BuffDiggerDB.delay) or 1
    BuffDiggerDB.delay = DELAYS[i % #DELAYS + 1]
    self:SetText(label())
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
    if section.nameplates then
      nameplateRow(LEFT_X, y - 4)
      y = y - 28
    end
    if section.delay then
      delayRow(LEFT_X, y - 4)
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
    row.icon:SetSize(16, 16)
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
  "Click an icon or a Nearby line to ask. Shift/Ctrl-click: /say instead of whisper (or the reverse).",
  "Right-click it to pick the buff yourself.",
  "Minimap button: right click = Nearby, Shift + right click = Give buffs.",
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
    GameTooltip:AddDoubleLine(L["Right click"], L["Nearby: who can buff me"], 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(L["Shift + right click"], L["Give buffs: who lacks mine"], 1, 1, 1, 1, 1, 1)
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

-- A movable window holding up to MAX_ROWS lines; `secure` lines cast a spell on click.
-- `setting` is the BuffDiggerDB key that remembers whether it is open.
local function makeWindow(globalName, title, setting, secure, point)
  local w = CreateFrame("Frame", globalName, UIParent, "BasicFrameTemplateWithInset")
  w:SetSize(290, 60)
  w:SetPoint(unpack(point))
  w:SetMovable(true)
  w:EnableMouse(true)
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", w.StartMoving)
  w:SetScript("OnDragStop", w.StopMovingOrSizing)
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
    row:SetSize(262, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 12, -28 - (i - 1) * ROW_HEIGHT)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", 2, 0)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.text:SetPoint("RIGHT", -2, 0)
    row.text:SetJustifyH("LEFT")
    if secure then
      row:RegisterForClicks("AnyUp", "AnyDown")
      row:SetAttribute("type", "spell")
      row:HookScript("PostClick", function() ns.flushThanks() end)
    else
      row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      row:SetScript("OnClick", function(self, mouse)
        if mouse == "RightButton" then ns.openMenu(self, self.unit) else ns.request(self.unit) end
      end)
    end
    row:Hide()
    w.rows[i] = row
  end
  return w
end

-- entries: { { unit, icon, text, spell (secure windows only) }, ... }
local function fill(w, entries, emptyMessage)
  for i, row in ipairs(w.rows) do
    local e = entries[i]
    if e then
      row.unit = e.unit
      row.icon:SetTexture(e.icon)
      row.text:SetText(e.text)
      if e.spell then
        row:SetAttribute("unit", e.unit)
        row:SetAttribute("spell", e.spell)
      end
    end
    row:SetShown(e ~= nil)
  end
  local count = math.min(#entries, MAX_ROWS)
  w.empty:SetText(emptyMessage)
  w.empty:SetShown(count == 0)
  w:SetHeight(40 + math.max(count, 1) * ROW_HEIGHT)
end

local nearby, give

-- ---------------------------------------------------------------- Nearby (idea 4)

local function nearbyEntries()
  local entries = {}
  for _, unit in ipairs(ns.nearbyUnits()) do
    local name, class, level = ns.identity(unit)
    if name then
      local key, kind = ns.bestBuff(name, class, level)
      if key then
        local buff = BUFFS[key]
        local extra = kind == "replace" and L[" (swap)"] or kind == "upgrade" and L[" (higher rank)"] or ""
        entries[#entries + 1] = {
          unit = unit,
          icon = C_Spell.GetSpellTexture(buff.id),
          text = ("%s%s %d — %s r%d%s"):format(classColored(name, class),
            ns.isPeer(name) and " |TInterface\\COMMON\\FavoritesIcon:12|t" or "", level,
            spellName(key), rankAt(buff, level), extra),
        }
      end
    end
  end
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

local function giveEntries(myBuffs)
  local entries = {}
  for _, unit in ipairs(ns.nearbyUnits()) do
    local name, class, level = ns.identity(unit)
    local key = name and buffToGive(unit, class, myBuffs)
    if key then
      local spell = C_Spell.GetSpellName(BUFFS[key].id)
      entries[#entries + 1] = {
        unit = unit,
        icon = C_Spell.GetSpellTexture(BUFFS[key].id),
        text = ("%s %d — %s"):format(classColored(name, class), level, spell),
        spell = spell,
      }
    end
  end
  return entries
end

-- ---------------------------------------------------------------- refresh and visibility

function ns.refreshWindow()
  if InCombatLockdown() then return end -- secure rows cannot change in combat
  if nearby and nearby:IsShown() then
    fill(nearby, nearbyEntries(), L["Nobody around can buff you better right now.\n(Friendly nameplates on?)"])
  end
  if give and give:IsShown() then
    local myBuffs = myCastableBuffs()
    if #myBuffs == 0 then
      fill(give, {}, L["You know no buff to give (paladin, priest, mage or druid)."])
    else
      fill(give, giveEntries(myBuffs), L["Everyone around has your buffs.\n(Friendly nameplates on?)"])
    end
  end
end

-- Show each window according to its setting (out of combat only).
function ns.applyWindows()
  if InCombatLockdown() or not nearby then return end
  nearby:SetShown(BuffDiggerDB.nearby)
  give:SetShown(BuffDiggerDB.give)
  ns.refreshWindow()
end

function ns.toggleWindow()
  BuffDiggerDB.nearby = not BuffDiggerDB.nearby
  ns.applyWindows()
end

function ns.toggleGive()
  BuffDiggerDB.give = not BuffDiggerDB.give
  ns.applyWindows()
end

-- Hide on entering combat (still allowed during PLAYER_REGEN_DISABLED), back on leaving it.
function ns.onCombat(inCombat)
  if not nearby then return end
  if inCombat then
    nearby:Hide()
    give:Hide()
  else
    ns.applyWindows()
  end
end

function ns.buildUI()
  buildSettings()
  buildMinimapButton()
  nearby = makeWindow("BuffDiggerNearby", L["Buff Digger — Nearby"], "nearby", false, { "LEFT", 40, 60 })
  give = makeWindow("BuffDiggerGive", L["Buff Digger — Give buffs"], "give", true, { "LEFT", 40, -140 })
  ns.applyWindows()
end
