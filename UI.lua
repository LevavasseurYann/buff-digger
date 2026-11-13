-- Buff Digger: minimap button, settings window, three list windows, and the "pick a buff" menu.
-- Minimap button: left click = settings, right click = Get buffs, Shift+right click = Give buffs,
-- Ctrl+right click = Requests (with the count of waiting requests on it), drag = move around the minimap.
--   * Get buffs (idea 4, "Nearby" before 0.4.0): who around can give me what; click asks, right click picks the buff (#4).
--   * Give buffs (idea 5, buffer classes): who around lacks a buff I can cast, chosen from THEIR
--     class preferences; one icon per buff, a click on it casts it on them (secure, out of combat).
-- The three share one line: buff icons, then the name (click = target them); see makeWindow.
--   * Requests (#10, #13): what other Buff Digger users asked me for; filled by Comm.lua.
-- All three hide in combat and come back after it.

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

-- First lines of a buff icon's tooltip: the spell, and the rank a caster of that level gives.
local function spellLines(owner, key, level)
  local buff = BUFFS[key]
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:AddLine(spellName(key))
  local rank = rankAt(buff, level)
  if rank > 0 then
    GameTooltip:AddLine(L["Rank %d"]:format(rank) .. (" (+%s %s)"):format(buff.values[rank], L[buff.stat]), 1, 1, 1)
  end
end

-- Hovering an icon of Give buffs or Requests: the spell, the rank I give, what a click does. No
-- name: it is on the line already. `who`: nil = can't cast (too far).
function ns.castTooltip(owner, key, who)
  if not key or InCombatLockdown() then return end
  spellLines(owner, key, UnitLevel("player"))
  if who then GameTooltip:AddLine(L["Click: cast it."], 0.4, 0.8, 1, true)
  else GameTooltip:AddLine(L["Too far"], 0.6, 0.6, 0.6) end
  GameTooltip:Show()
end

-- Hovering a buff icon (nameplate or Get buffs): the spell, the rank they can probably give me,
-- what a click does. No name: it is on the line (or above the nameplate) already.
function ns.buffTooltip(owner, unit, key)
  if not (key and unit) or InCombatLockdown() then return end
  local name, _, level = ns.identity(unit)
  if not name then return end
  local buff = BUFFS[key]
  spellLines(owner, key, level)
  -- A paladin's blessings replace each other: say which one he gave me, and what asking would cost.
  local his = ns.hisBlessing(name)
  if his == key then
    GameTooltip:AddLine(L["They gave you this one."], 1, 0.82, 0)
  else
    if ns.haveBuff(key) then GameTooltip:AddLine(L["You have it already."], 0.6, 0.6, 0.6) end
    if his and buff.class == "PALADIN" then
      GameTooltip:AddLine(L["Replaces the %s they gave you."]:format("|cffffd100" .. spellName(his) .. "|r"), 1, 0.5, 0.25, true)
    end
  end
  GameTooltip:AddLine(L["Click: ask for it. Right click: other buffs."], 0.4, 0.8, 1, true)
  GameTooltip:Show()
end

-- ---------------------------------------------------------------- pick-a-buff menu (#4)

-- Right click on an icon or a Get buffs line: every buff that player can probably give,
-- my priorities first. Choosing one asks for it, whatever the automatic choice would be.
local function addOffers(root, unit, name, level, offers)
  root:CreateTitle("Buff Digger") -- their name is on the line or the portrait already
  for _, key in ipairs(offers) do
    local label = ("|T%s:0|t %s |cff9d9d9d" .. L["Rank %d"] .. "|r%s"):format(C_Spell.GetSpellTexture(BUFFS[key].id) or 134400, spellName(key),
      rankAt(BUFFS[key], level), ns.haveBuff(key) and L[" (you have it)"] or "")
    root:CreateButton(label, function()
      -- In a city, the nameplate token may now belong to someone else: check it is still them.
      if not ns.truthy(UnitExists(unit)) or ns.unitName(unit) ~= name then
        ns.notice(L["%s is no longer around."]:format(name))
        return
      end
      ns.request(unit, key)
    end)
  end
end

function ns.openMenu(owner, unit)
  if InCombatLockdown() or not unit then return end
  if not (MenuUtil and MenuUtil.CreateContextMenu) then ns.notice(L["The game's menu is not available."]) return end
  local name, class, level = ns.identity(unit)
  if not name then return end
  local offers = ns.offers(class, level)
  if #offers == 0 then ns.notice(L["%s has nothing better for you right now."]:format(name)) return end
  MenuUtil.CreateContextMenu(owner, function(_, root) addOffers(root, unit, name, level, offers) end)
end

-- The game's own right-click menu on a player (target, party and raid frames) gets the same lines
-- at its bottom (#17). Blizzard's lines are left alone; nothing is added for a name clicked in chat
-- (no unit: class and level unknown). The setting is read each time the menu opens.
local function extendGameMenu()
  if not (Menu and Menu.ModifyMenu) then return end
  for _, tag in ipairs({ "MENU_UNIT_PLAYER", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_RAID" }) do
    Menu.ModifyMenu(tag, function(_, root, data)
      local unit = data and data.unit
      if not (BuffDiggerDB.gameMenu and unit) or InCombatLockdown() then return end
      if not ns.truthy(UnitIsPlayer(unit)) or ns.truthy(UnitIsUnit(unit, "player"))
        or not ns.truthy(UnitIsFriend("player", unit)) then return end
      local name, class, level = ns.identity(unit)
      local offers = name and ns.offers(class, level) or {}
      if #offers == 0 then return end
      root:CreateDivider()
      addOffers(root, unit, name, level, offers)
    end)
  end
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
    { key = "nearbyUseful", label = "Get buffs: only those with something better" },
    { key = "give",    label = "Give buffs window: who lacks my buffs" },
  }, nameplates = true, plates = true },
  { title = "Requests", options = {
    { key = "useSay",  label = "Ask in /say by default (not whisper)" },
    { key = "targetOnAsk", label = "Get buffs: target the player I ask" },
    { key = "acceptRequests", label = "Accept requests from Buff Digger users" },
    { key = "requestSound", label = "Sound when a request arrives" },
    { key = "requestMarkers", label = "Marker above players who request a buff" },
    { key = "gameMenu", label = "Buff requests in the game's right-click menu" },
  }, delay = true, language = true },
  { title = "Thanks", options = {
    { key = "thankByHand", label = "Let me click Thank (no automatic thanks)" },
    { key = "thank",   label = "/thank emote when someone buffs me" },
    { key = "thankMessage", label = "Thank-you in my request's channel" },
  } },
  { title = "Advanced", options = {
    { key = "debug",   label = "Debug messages in chat" },
  } },
}

local settings, prefRows, refreshPrefs, phrases

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
      text(settings, "GameFontHighlight", LEFT_X + 4, y - 8, COL_W - 120, L["My own phrases"])
      local edit = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
      edit:SetSize(104, 22)
      edit:SetPoint("TOPLEFT", LEFT_X + COL_W - 104, y - 4)
      edit:SetText(L["Edit..."])
      edit:SetScript("OnClick", function() phrases:SetShown(not phrases:IsShown()) end)
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

-- ---------------------------------------------------------------- my own phrases (#20)
-- One box per case, one phrase per line, saved as typed (ns.setCustom); refused lines in red.

-- Tab label and when Buff Digger uses that case.
local PHRASE_KINDS = {
  { "new", "Missing buff", "Asking for a buff you don't have." },
  { "replace", "Swap blessing", "Asking a paladin to swap your blessing for a better one." },
  { "upgrade", "Better rank", "Asking for a higher rank of a buff you already have." },
  { "refresh", "Running out", "Asking for a buff you have that's about to wear off." },
  { "thanks", "Thank-you", "Thanking someone who just buffed you." },
}

local function buildPhrases()
  local w = CreateFrame("Frame", "BuffDiggerPhrases", UIParent, "BasicFrameTemplateWithInset")
  local width = 5 * 88 - 4
  w:SetSize(2 * PAD + width, 376) -- room for 4 error lines above the buttons
  w:SetPoint("CENTER", 0, 40)
  w:SetFrameStrata("DIALOG") -- above the settings
  w:SetMovable(true)
  w:EnableMouse(true)
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", w.StartMoving)
  w:SetScript("OnDragStop", w.StopMovingOrSizing)
  w:Hide()
  tinsert(UISpecialFrames, "BuffDiggerPhrases") -- Escape closes it
  local title = w:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", 0, -5)
  title:SetText(L["Buff Digger — My own phrases"])
  text(w, "GameFontHighlightSmall", PAD, -30, width,
    L["Write what you want to say, one phrase per line: Buff Digger picks one at random. {spell} becomes the buff's link."])

  w.when = text(w, "GameFontNormal", PAD, -86, width, "")

  local box = CreateFrame("ScrollFrame", nil, w, "UIPanelScrollFrameTemplate")
  box:SetPoint("TOPLEFT", PAD + 4, -108)
  box:SetSize(width - 28, 140)
  local bg = box:CreateTexture(nil, "BACKGROUND") -- the box shows where to type
  bg:SetPoint("TOPLEFT", -4, 4)
  bg:SetPoint("BOTTOMRIGHT", 4, -4)
  bg:SetColorTexture(0, 0, 0, 0.6)
  local edit = CreateFrame("EditBox", nil, box)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetFontObject(ChatFontNormal)
  edit:SetWidth(width - 28)
  edit:SetScript("OnEscapePressed", edit.ClearFocus)
  -- Keep the cursor in sight while typing past the bottom (Blizzard's helpers, if Forever has them).
  if ScrollingEdit_OnCursorChanged and ScrollingEdit_OnUpdate then
    edit:SetScript("OnCursorChanged", ScrollingEdit_OnCursorChanged)
    edit:SetScript("OnUpdate", function(self, elapsed) ScrollingEdit_OnUpdate(self, elapsed, box) end)
  end
  box:SetScrollChild(edit)
  box:EnableMouse(true)
  box:SetScript("OnMouseDown", function() edit:SetFocus() end)
  w.edit = edit
  w.status = text(w, "GameFontHighlightSmall", PAD, -258, width, "")
  w.errors = text(w, "GameFontRedSmall", PAD, -274, width, "")

  -- Copy ours into an empty box, to edit them rather than start from nothing.
  local copy = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
  copy:SetSize(190, 22)
  copy:SetPoint("BOTTOMLEFT", PAD, PAD)
  copy:SetText(L["Start from Buff Digger's"])
  w.copy = copy

  local function check()
    local errors = ns.setCustom(w.kind, edit:GetText() or "")
    local more = #errors - 3 -- room for 3 lines above the buttons
    for i = #errors, 4, -1 do errors[i] = nil end
    if more > 0 then errors[4] = L["+%d more"]:format(more) end
    w.errors:SetText(table.concat(errors, "\n"))
    local n = #BuffDiggerDB.custom[w.kind]
    w.status:SetText(n > 0 and ("|cff33ff33" .. L["Sending your phrases (%d)."]:format(n) .. "|r")
      or L["Box empty: Buff Digger's own phrases are sent."])
    copy:SetEnabled(not (edit:GetText() or ""):find("%S"))
  end
  edit:SetScript("OnTextChanged", function(_, typed) if typed then check() end end)

  w.tabs = {}
  local function show(kind)
    w.kind = kind
    for i, t in ipairs(w.tabs) do
      if t.kind == kind then t:LockHighlight() else t:UnlockHighlight() end
      if t.kind == kind then w.when:SetText(L[PHRASE_KINDS[i][3]]) end
    end
    local list = BuffDiggerDB.custom[kind]
    edit:SetText(BuffDiggerDB.customText[kind] or (list and table.concat(list, "\n")) or "")
    check() -- the language may have changed: lengths are checked again
  end
  for i, k in ipairs(PHRASE_KINDS) do
    local t = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
    t:SetSize(84, 22)
    t:SetPoint("TOPLEFT", PAD + (i - 1) * 88, -58)
    t:SetText(L[k[2]])
    t.kind = k[1]
    t:SetScript("OnClick", function() show(k[1]) end)
    w.tabs[i] = t
  end
  w:SetScript("OnShow", function() show(w.kind or "new") end)
  copy:SetScript("OnClick", function()
    edit:SetText(table.concat(ns.builtIn(w.kind, BuffDiggerDB.language), "\n"))
    check()
    edit:SetFocus()
  end)

  -- Preview: a phrase drawn for this case, printed for me only.
  local preview = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
  preview:SetSize(150, 22)
  preview:SetPoint("BOTTOMRIGHT", -PAD, PAD)
  preview:SetText(L["Try one (only you see it)"])
  preview:SetScript("OnClick", function()
    local lang = BuffDiggerDB.language
    ns.say(w.kind == "thanks" and ns.thanks(lang)
      or ns.message(w.kind, w.kind == "replace" and "kings" or "fortitude", lang))
  end)
  w.preview = preview
  phrases = w
end

local HOW_TO = {
  "Click a buff icon to ask for that buff, a name in Get buffs to target them. Shift/Ctrl-click: /say instead of whisper (or the reverse).",
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

  buildPhrases()
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
  -- Requests waiting (#13): their count, even with the Requests window closed or in combat.
  local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  count:SetPoint("BOTTOMRIGHT", -2, 2)
  function ns.showRequestCount(n) count:SetText(n > 0 and n or "") end

  button:SetScript("OnClick", function(_, mouse)
    ns.flushThanks() -- a real click: waiting thanks can go out
    if mouse ~= "RightButton" then ns.toggleSettings()
    elseif IsShiftKeyDown() then ns.toggleGive()
    elseif IsControlKeyDown() then ns.toggleRequests()
    else ns.toggleWindow() end
  end)
  -- Hover: what each click does (the only place the shortcuts are listed outside the settings).
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Buff Digger")
    GameTooltip:AddDoubleLine(L["Left click"], L["Settings"], 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(L["Right click"], L["Get buffs: who can buff me"], 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(L["Shift + right click"], L["Give buffs: who lacks mine"], 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(L["Ctrl + right click"], L["Requests: what others ask me"], 1, 1, 1, 1, 1, 1)
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

local listWindows = {} -- Get buffs, Give buffs and Requests: they share the padlock
local pulsed = {} -- name -> their Get buffs band already flashed gold (#24)

-- A colour fading out to the right (section lines, Get buffs bands); plain without SetGradient.
-- On white: SetGradient tints the texture, a coloured one would get the colour twice.
local function fadeRight(tex, r, g, b, a)
  if tex.SetGradient and CreateColor then
    tex:SetColorTexture(1, 1, 1)
    tex:SetGradient("HORIZONTAL", CreateColor(r, g, b, a), CreateColor(r, g, b, 0))
  else
    tex:SetColorTexture(r, g, b, a)
  end
end

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

-- A movable, resizable window holding up to MAX_ROWS lines; with `cast`, its icons cast the buff.
-- Size kept in BuffDiggerDB.sizes; "Lock windows" stops both moving and resizing.
-- `setting` is the BuffDiggerDB key that remembers whether it is open.
local function makeWindow(globalName, title, setting, cast, point)
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
    -- Secure in both windows: Give buffs rows cast, Get buffs rows target (#14).
    -- The same line in every window: one icon slot per buff, in priority order, then the name,
    -- so names line up whatever the number of icons. Click the name = target them (secure).
    -- Click an icon: Get buffs asks them for that buff (and targets them too with "targetOnAsk");
    -- Give buffs and Requests cast it on them. The spell's name is only in the icon's tooltip.
    local row = CreateFrame("Button", nil, w, "SecureActionButtonTemplate")
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 12, -28 - (i - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", -24, 0) -- room for the scroll arrows
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", 2 + MAX_BUFFS * 22 + 4, 0)
    row.text:SetPoint("RIGHT", cast and -2 or -18, 0) -- Get buffs: room for the cross
    row.text:SetJustifyH("LEFT")
    -- Section header (#16): a thin gold line under the title, fading out to the right.
    row.line = row:CreateTexture(nil, "ARTWORK")
    row.line:SetHeight(1)
    row.line:SetPoint("BOTTOMLEFT", 2, 1)
    row.line:SetPoint("BOTTOMRIGHT", -2, 1)
    fadeRight(row.line, 1, 0.82, 0, 0.8) -- gold
    -- The Group header folds, like a quest log header: [-] shows the members, [+] hides them.
    -- A plain button over the (unclickable) secure row: nothing secure to set, the click re-fills.
    row.fold = CreateFrame("Button", nil, row)
    row.fold:SetAllPoints()
    row.fold:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.fold.icon = row.fold:CreateTexture(nil, "ARTWORK")
    row.fold.icon:SetSize(14, 14)
    row.fold.icon:SetPoint("LEFT", 2, 0)
    row.fold:SetScript("OnClick", function()
      if InCombatLockdown() then return end
      BuffDiggerDB.hideGroup[setting] = not BuffDiggerDB.hideGroup[setting] or nil
      w.fill()
      if GameTooltip:IsOwned(row.fold) then row.fold:GetScript("OnEnter")(row.fold) end -- Hide <-> Show
    end)
    row.fold:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(BuffDiggerDB.hideGroup[setting] and L["Show your group"] or L["Hide your group"])
      GameTooltip:Show()
    end)
    row.fold:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- The token may have gone to someone else since the list was built (cursor on it): then
    -- the menu or the request would reach whoever holds it now, not the player shown.
    local function gone()
      if ns.targetName(row.unit) == row.entry.who then return false end
      ns.notice(L["%s is no longer around."]:format(row.entry.who or "?"))
      return true
    end
    ns.secureClicks(row)
    row:HookScript("PostClick", function(self, mouse)
      if cast then return end
      if mouse == "RightButton" and not gone() then ns.openMenu(self, self.unit)
      -- A gold line (#24): the click thanks them (a real click: /say goes too), it doesn't target.
      elseif mouse == "LeftButton" and self.state == "thank" then
        ns.thankBuffer(self.entry.who)
        if not InCombatLockdown() then w.fill() end
      end
    end)
    -- Get buffs (#24): a cross ends the wait (amber) or skips the thank-you (gold), sending nothing.
    -- A plain button on the secure row, like the fold: nothing secure to set.
    if not cast then
      row.close = CreateFrame("Button", nil, row)
      row.close:SetSize(14, 14)
      row.close:SetPoint("RIGHT", -2, 0)
      row.close:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
      row.close:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
      row.close:SetScript("OnClick", function()
        ns.closeAsk(row.entry.who)
        if not InCombatLockdown() then w.fill() end
      end)
      row.close:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(row.state == "thank" and L["Skip the thank-you"] or L["Stop waiting for this buff"])
        GameTooltip:Show()
      end)
      row.close:SetScript("OnLeave", function() GameTooltip:Hide() end)
      row.close:Hide()
      -- My request to them (#24), in WoW's own words: a soft band from the name, fading to the
      -- right like the section lines, with a bright edge; amber + ready check "?" while it waits,
      -- gold + ready check tick once their buff landed, and "Thank" says what the click does.
      row.band = row:CreateTexture(nil, "BACKGROUND")
      row.band:SetPoint("LEFT", row.text, "LEFT", -4, 0)
      row.band:SetPoint("RIGHT")
      row.band:SetHeight(ROW_HEIGHT - 2)
      row.edge = row:CreateTexture(nil, "BORDER")
      row.edge:SetPoint("TOPLEFT", row.band)
      row.edge:SetPoint("BOTTOMLEFT", row.band)
      row.edge:SetWidth(2)
      row.status = row:CreateTexture(nil, "OVERLAY")
      row.status:SetSize(14, 14)
      row.thank = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") -- gold, like a button label
      row.thank:SetPoint("RIGHT", -20, 0)
      row.thank:SetText(L["Thank"])
      -- The buff just landed: the band and its edge flash twice.
      row.pulse = row:CreateAnimationGroup()
      for k = 1, 4 do
        for _, tex in ipairs({ row.band, row.edge }) do -- same order: both at once, not the name
          local a = row.pulse:CreateAnimation("Alpha")
          a:SetTarget(tex)
          a:SetFromAlpha(k % 2 == 1 and 1 or 0.15)
          a:SetToAlpha(k % 2 == 1 and 0.15 or 1)
          a:SetDuration(0.25)
          a:SetOrder(k)
        end
      end
    end
    row.buffs = {}
    for j = 1, MAX_BUFFS do
      local b = CreateFrame("Button", nil, row, "SecureActionButtonTemplate")
      b:SetSize(18, 18) -- room for the rank number in its corner
      b:SetPoint("LEFT", 2 + (j - 1) * 22, 0)
      b.icon = b:CreateTexture(nil, "ARTWORK")
      b.icon:SetAllPoints()
      b.rank = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
      b.rank:SetPoint("BOTTOMRIGHT", 3, -2)
      b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
      ns.secureClicks(b)
      if cast then
        ns.watchClick(b)
        b:HookScript("PostClick", function(self)
          if not self:GetAttribute("type") then ns.notice(L["Too far"]) return end
          ns.castOn()
        end)
      else
        b:HookScript("PostClick", function(self, mouse)
          if gone() then return end
          if mouse == "RightButton" then ns.openMenu(self, row.unit)
          elseif mouse == "LeftButton" then ns.request(row.unit, self.key) end
        end)
      end
      b:SetScript("OnEnter", function(self)
        if cast then ns.castTooltip(self, self.key, self:GetAttribute("type") and row.entry.who or nil)
        else ns.buffTooltip(self, row.unit, self.key) end
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      row.buffs[j] = b
    end
    row:Hide()
    w.rows[i] = row
  end
  -- More players than rows (a city): the mouse wheel scrolls; small arrows show there is more
  -- above or below, and a click on one scrolls too. fill() re-aims every row (out of combat).
  w.offset = 0
  w.cast = cast
  w.setting = setting
  local function scroll(delta)
    if InCombatLockdown() or not w.entries then return end
    w.offset = math.max(0, math.min(w.offset - delta, #w.entries - visibleRows(w)))
    w.fill()
  end
  w:EnableMouseWheel(true)
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

-- entries: { { unit, who (their name, read with the text: scrolling re-fills from these cached
--   entries, by then the nameplate token may be someone else's; false = unreadable), text, far (Get buffs: red icons),
--   buffs = { { key, icon, rank, upgrade, best, his (Get buffs), spell (cast windows; nil = red,
--   not castable) }, ... } }, ... }
-- In a group (#16): a "Group (n)" header line, the members (entries say `group`, and come first),
-- then "Around" and everyone else. Out of a group, the list as it is.
-- Folded (hideGroup): the header stays, with its count, the members don't.
local function withHeaders(entries, hideGroup)
  local members = 0
  for _, e in ipairs(entries) do if e.group then members = members + 1 end end
  if members == 0 then return entries end
  local out, around = { { header = true, fold = true, text = L["Group (%d)"]:format(members), buffs = {} } }, false
  for _, e in ipairs(entries) do
    if not e.group and not around then
      around = true
      out[#out + 1] = { header = true, text = L["Around"], buffs = {} }
    end
    if not (e.group and hideGroup) then out[#out + 1] = e end
  end
  return out
end

local function fill(w, list, emptyMessage)
  -- Re-fills (scroll, resize, [-]) start again from the list without headers: headers on headers
  -- piled up "Group / Around" and lost the folded members.
  w.fill = function() fill(w, list, emptyMessage) end
  local entries = withHeaders(list, BuffDiggerDB.hideGroup[w.setting])
  w.entries = entries
  -- A gold line flashes once per buff: forget those no longer to thank, wherever they were thanked
  -- (Thanks window, key, folded group), so their next buff flashes again.
  if not w.cast then
    for n in pairs(pulsed) do if ns.askState(n) ~= "thank" then pulsed[n] = nil end end
  end
  -- Icon column as wide as the most icons on any line of this list (not just the visible ones:
  -- scrolling must not move the names), icons against the name: names stay lined up, and no empty
  -- slots when nobody gives 3 buffs (a mage, Requests).
  local slots = 0
  for _, e in ipairs(entries) do slots = math.max(slots, #e.buffs) end
  local shown = visibleRows(w)
  w.offset = math.max(0, math.min(w.offset, #entries - shown))
  for i, row in ipairs(w.rows) do
    local e = i <= shown and entries[w.offset + i] or nil
    if e then
      row.unit = e.unit
      row.entry = e
      -- Get buffs (#24): my request to them, amber while it waits, gold once their buff landed.
      local state = not w.cast and not e.header and e.who and ns.askState(e.who) or nil
      row.state = state
      row.text:SetText(e.text) -- the name keeps its class colour: the band says the rest
      if row.band then
        row.close:SetShown(state ~= nil)
        row.band:SetShown(state ~= nil)
        row.edge:SetShown(state ~= nil)
        row.status:SetShown(state ~= nil)
        row.thank:SetShown(state == "thank")
        if state == "thank" then
          fadeRight(row.band, 1, 0.82, 0, 0.35)
          row.edge:SetColorTexture(1, 0.82, 0, 0.9)
          row.status:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
          row.status:SetPoint("RIGHT", row.thank, "LEFT", -2, 0)
        else
          fadeRight(row.band, 1, 0.5, 0.1, 0.25)
          row.edge:SetColorTexture(1, 0.5, 0.1, 0.9)
          row.status:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
          row.status:SetPoint("RIGHT", -20, 0)
        end
        -- Never under them, whatever the width of "Thank".
        if state then row.text:SetPoint("RIGHT", row.status, "LEFT", -4, 0) else row.text:SetPoint("RIGHT", -18, 0) end
        -- Flash once when it turns gold, not on every refresh or scroll; the flash is the row's,
        -- not the player's: a row scrolled to someone else stops it.
        if row.pulseFor ~= e.who then row.pulse:Stop(); row.pulseFor = nil end
        if state == "thank" and not pulsed[e.who] then
          pulsed[e.who] = true; row.pulseFor = e.who; row.pulse:Play()
        end
      end
      row:EnableMouse(not e.header) -- a header: no click, no highlight
      row.line:SetShown(e.header == true)
      row.fold:SetShown(e.fold == true)
      if e.fold then
        row.fold.icon:SetTexture(BuffDiggerDB.hideGroup[w.setting] and "Interface\\Buttons\\UI-PlusButton-Up"
          or "Interface\\Buttons\\UI-MinusButton-Up")
      end
      if e.header then row.text:SetTextColor(1, 0.82, 0) -- gold, like the settings' section titles
      else row.text:SetTextColor(1, 1, 1) end -- the name keeps its class colour; far = red icons
      -- Every attribute is set each time: a row reused for another player never keeps the old target.
      -- A gold line thanks instead of targeting.
      ns.aimTarget(row, state ~= "thank" and e.unit or nil, e.who)
      -- Headers start at the left edge, after the [+]/[-] box (both, so they line up).
      row.text:SetPoint("LEFT", e.header and 20 or 2 + slots * 22 + 4, 0)
      local first = slots - #e.buffs -- empty slots on the left
      for j, b in ipairs(row.buffs) do
        b:SetPoint("LEFT", 2 + (first + j - 1) * 22, 0)
        local buff = e.buffs[j]
        if buff then
          b.key = buff.key
          b.icon:SetTexture(buff.icon)
          b.rank:SetText(buff.rank or "")
          -- Green: higher than the one I have, like an upgrade in a loot tooltip.
          if buff.upgrade then b.rank:SetTextColor(0.1, 1, 0.1) else b.rank:SetTextColor(1, 1, 1) end
          if w.cast then
            ns.styleBuff(b) -- no gold frame, full colour
            ns.aimCast(b, e.unit, buff.spell, e.who)
          else
            ns.styleBuff(b, buff.key, buff.best, buff.his)
            ns.aimTarget(b, BuffDiggerDB.targetOnAsk and e.unit, e.who)
          end
          -- Too far: red, like an action bar button out of range (grey already says "you have it").
          if (w.cast and buff.spell == nil) or (not w.cast and e.far) then b.icon:SetVertexColor(0.8, 0.1, 0.1)
          else b.icon:SetVertexColor(1, 1, 1) end
        end
        b:SetShown(buff ~= nil)
      end
    end
    row:SetShown(e ~= nil)
  end
  w.empty:SetText(emptyMessage)
  w.empty:SetShown(#entries == 0)
  w.up:SetShown(w.offset > 0)
  w.down:SetShown(#entries - w.offset > shown)
end

local nearby, give, giveNext, requests, thanksWindow

-- ---------------------------------------------------------------- Thanks window (#21)
-- "Let me click Thank": who just buffed me, one line each (ns.thanksWaiting keeps at most 5). Shown only
-- while someone waits; click = thank them, right click = forget them, close = forget everyone.
-- Nothing secure here, so it also works in combat.

local function buildThanks()
  local w = CreateFrame("Frame", "BuffDiggerThanks", UIParent, "BasicFrameTemplateWithInset")
  w:SetSize(240, 60)
  w:SetPoint("TOP", 0, -220)
  w:SetMovable(true)
  w:EnableMouse(true)
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", function(self) if not BuffDiggerDB.lockWindows then self:StartMoving() end end)
  w:SetScript("OnDragStop", w.StopMovingOrSizing)
  w:Hide()
  w.CloseButton:HookScript("OnClick", function() ns.dismissThank() end)
  local header = w:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  header:SetPoint("TOP", 0, -5)
  header:SetText(L["Buff Digger — Thanks"])
  w.rows = {}
  for i = 1, 5 do
    local row = CreateFrame("Button", nil, w)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 12, -28 - (i - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", -12, 0)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, mouse)
      if mouse == "RightButton" then ns.dismissThank(self.name) else ns.thankBuffer(self.name) end
    end)
    row:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(L["Click: thank %s. Right click: forget it."]:format(self.name), 0.4, 0.8, 1, true)
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.icons = {}
    for j = 1, MAX_BUFFS do
      local icon = row:CreateTexture(nil, "ARTWORK")
      icon:SetSize(18, 18)
      icon:SetPoint("LEFT", 2 + (j - 1) * 22, 0)
      row.icons[j] = icon
    end
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", 2 + MAX_BUFFS * 22 + 4, 0)
    row.text:SetPoint("RIGHT", -2, 0)
    row.text:SetJustifyH("LEFT")
    row:Hide()
    w.rows[i] = row
  end
  thanksWindow = w
end

-- Is this player on a Get buffs line I can see (not scrolled away)? There, the gold line thanks them (#24).
local function onGetBuffs(name)
  if not (nearby and nearby:IsShown()) then return false end
  for _, row in ipairs(nearby.rows) do
    if row:IsShown() and row.entry and row.entry.who == name then return true end
  end
  return false
end

function ns.refreshThanks()
  if not thanksWindow then return end
  -- Only those Get buffs doesn't show (closed, nameplate gone, group folded): a gift from someone out
  -- of sight can still be thanked.
  local list = {}
  for _, e in ipairs(ns.thanksWaiting()) do
    if not onGetBuffs(e.name) then list[#list + 1] = e end
  end
  for i, row in ipairs(thanksWindow.rows) do
    local e = list[i]
    if e then
      row.name = e.name
      row.text:SetText(classColored(e.name, e.class))
      for j, icon in ipairs(row.icons) do
        local key = e.keys[j]
        if key then icon:SetTexture(C_Spell.GetSpellTexture(BUFFS[key].id)) end
        icon:SetShown(key ~= nil)
      end
    end
    row:SetShown(e ~= nil)
  end
  thanksWindow:SetHeight(40 + math.max(#list, 1) * ROW_HEIGHT)
  thanksWindow:SetShown(#list > 0)
end

-- ---------------------------------------------------------------- Get buffs (idea 4)

-- Everyone around who can give me something: those with a buff I'm missing (or an upgrade) first,
-- my top pick first among them; then the ones whose buffs I all have, for picking by hand
-- (left out with "nearbyUseful": nothing from my priority list missing, no higher rank, nothing
-- running out — ns.bestBuff gave no key).
local function nearbyEntries()
  local entries = {}
  for _, unit in ipairs(ns.listUnits()) do
    local name, class, level = ns.identity(unit)
    local offers = name and ns.offers(class, level) or {}
    local key, kind, top
    if #offers > 0 then key, kind, top = ns.bestBuff(name, class, level) end
    -- Asked, or to thank (#24): kept on the list whatever the filter, first of its section.
    local state = name and ns.askState(name)
    if #offers > 0 and (key or state or not BuffDiggerDB.nearbyUseful) then
      -- A member at the other end of the world: listed, red icons, never asked (ns.request says so).
      local far = ns.outOfSight(unit)
      local his = ns.hisBlessing(name)
      local buffs = {}
      for j = 1, math.min(#offers, MAX_BUFFS) do
        local k = offers[j]
        buffs[j] = {
          key = k, icon = C_Spell.GetSpellTexture(BUFFS[k].id), rank = rankAt(BUFFS[k], level),
          upgrade = k == key and kind == "upgrade", best = key, his = his,
        }
      end
      local extra = kind == "replace" and L[" (swap)"] or kind == "upgrade" and L[" (higher rank)"]
        or kind == "refresh" and L[" (running out)"] or ""
      -- A silent request to another Buff Digger user brought nothing: offer, never send (#13).
      if ns.unanswered(name) then extra = extra .. L[" |cffffd100no answer: click a buff to whisper|r"] end
      if far then extra = L[" (too far)"] end
      local tail = ("%s %d%s"):format(ns.isPeer(name) and " |TInterface\\COMMON\\FavoritesIcon:12|t" or "", level, extra)
      entries[#entries + 1] = {
        unit = unit, who = name, buffs = buffs, group = ns.isMember(unit), far = far,
        -- Members in sight, then members too far, then everyone else; asked or to thank first of each.
        order = state and (ns.isMember(unit) and -7 or -0.5)
          or (ns.isMember(unit) and (far and -3 or -6) or 0) + (key and (top and 0 or 1) or 2),
        text = classColored(name, class) .. tail,
      }
    end
  end
  -- Group members first (#16); table.sort is not stable: keep the list order within each rank.
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

-- Which of my buffs should this player get, best first? THEIR class's default preferences decide
-- (not my own edited list: that one says what I want, not what a warrior wants).
-- A paladin keeps one blessing per target: if mine is already on them, offer nothing.
local function buffsToGive(unit, theirClass, myBuffs)
  local list = {}
  local _, myClass = UnitClass("player")
  if myClass == "PALADIN" then
    for _, key in ipairs(myBuffs) do
      local _, fromMe = unitHas(unit, BUFFS[key])
      if fromMe then return list end
    end
  end
  for _, key in ipairs(ns.PREFERENCES[theirClass] or {}) do
    for _, mineKey in ipairs(myBuffs) do
      if key == mineKey and #list < MAX_BUFFS then
        local has = unitHas(unit, BUFFS[key])
        if has == nil then return {} end -- unreadable: stay silent rather than guess
        if has == false then list[#list + 1] = key end
      end
    end
  end
  return list
end

-- Players I just buffed with the next-player key: name -> GetTime(). They stay out of the list a
-- few seconds, so pressing the key again moves on to someone else, even when the game can't show me
-- their new buff yet or the cast failed (line of sight). A click in the window passes no unit.
local justCast = {}

function ns.castOn(unit)
  ns.flushThanks()
  local name = unit and ns.unitName(unit)
  if name then justCast[ns.firstName(name)] = GetTime() end
  C_Timer.After(1, ns.refreshAll)
end

-- Out of reach of my spell. The game can't tell (nil): a nameplate in sight counts as in range; a
-- group member, who can be anywhere, only while in sight.
function ns.tooFar(spellId, unit)
  local r = C_Spell.IsSpellInRange and C_Spell.IsSpellInRange(spellId, unit)
  if r == nil and ns.isMember(unit) then return not ns.truthy(UnitIsVisible(unit)) end
  return ns.readable(r) and r == false
end

local function giveEntries(myBuffs)
  local entries, myLevel = {}, UnitLevel("player")
  for _, unit in ipairs(ns.listUnits()) do
    local name, class, level = ns.identity(unit)
    local cast = name and justCast[ns.firstName(name)]
    if cast and GetTime() - cast < SKIP_AFTER_CAST then name = nil end
    local keys = name and buffsToGive(unit, class, myBuffs) or {}
    if #keys > 0 then
      -- Nameplates (and group members, anywhere) can be far beyond a buff's 30 yards: those are
      -- listed with red icons, not clickable, after the ones in range.
      local far = ns.tooFar(BUFFS[keys[1]].id, unit)
      local buffs = {}
      for j, k in ipairs(keys) do
        buffs[j] = { key = k, icon = C_Spell.GetSpellTexture(BUFFS[k].id), rank = rankAt(BUFFS[k], myLevel),
          spell = not far and C_Spell.GetSpellName(BUFFS[k].id) or nil }
      end
      entries[#entries + 1] = {
        unit = unit, who = name, far = far, buffs = buffs, group = ns.isMember(unit),
        text = ("%s %d%s"):format(classColored(name, class), level, far and L[" (too far)"] or ""),
      }
    end
  end
  -- Group members first (#16), in range before too far within each part.
  local sorted = {}
  for _, group in ipairs({ true, false }) do
    for _, far in ipairs({ false, true }) do
      for _, e in ipairs(entries) do
        if e.group == group and e.far == far then sorted[#sorted + 1] = e end
      end
    end
  end
  return sorted
end

-- I cast at someone (macro or by hand): skip them for a few seconds, the macro moves to the next one.
function ns.onSpellSent(target)
  -- nil for a spell with no target (an attack, a self buff). Keyed by first name: whether the game
  -- gives "Raide", "Raide-Boule" or "Raide Boule" here is not known yet (recette 45).
  -- ponytail: two players sharing a first name are both skipped for SKIP_AFTER_CAST seconds.
  local name = type(target) == "string" and ns.firstName(ns.chatName(target)) -- "" -> nil
  if not name then return end
  justCast[name] = GetTime()
  C_Timer.After(1, ns.refreshAll)
end

-- ---------------------------------------------------------------- refresh and visibility

function ns.refreshWindow()
  if InCombatLockdown() then return end -- secure rows cannot change in combat
  -- Not under the cursor either: with targetOnAsk, the list must not change between aiming and
  -- releasing, or the click would ask someone else than the one targeted.
  if nearby and nearby:IsShown() and not nearby:IsMouseOver() then
    fill(nearby, nearbyEntries(), BuffDiggerDB.nearbyUseful
      and L["Nobody around has anything better for you.\n(Friendly nameplates on?)"]
      or L["Nobody around can buff you.\n(Friendly nameplates on?)"])
  elseif nearby and nearby:IsShown() and nearby.fill then
    -- Under the cursor: same list, same rows, only amber/gold changes (#24). The buff that lands
    -- while I still hover the icon I clicked turns the line gold without waiting for the mouse to leave.
    nearby.fill()
  end
  ns.refreshThanks() -- who Get buffs shows (or no longer shows) leaves (or comes back to) Thanks
  -- The next-player key works without the window, once it is bound.
  local nextBound = GetBindingKey and GetBindingKey("CLICK BuffDiggerGiveNext:LeftButton")
  if not ((give and give:IsShown()) or nextBound) then return end
  local myBuffs = myCastableBuffs()
  local entries = #myBuffs > 0 and giveEntries(myBuffs) or {}
  -- Never re-fill under the cursor: rows would shift while the player aims (the cast
  -- fires on release, on whatever the row then holds).
  if give and give:IsShown() and not (give:IsMouseOver() and #myBuffs > 0) then
    if #myBuffs == 0 then
      fill(give, {}, L["You know no buff to give (paladin, priest, mage or druid)."])
    else
      fill(give, entries, L["Everyone around has your buffs.\n(Friendly nameplates on?)"])
    end
  end
  -- The first line in range (group members first), their first buff in their class's order.
  local first
  for _, e in ipairs(entries) do
    if e.buffs[1].spell then first = e break end
  end
  giveNext.unit = first and first.unit
  ns.aimCast(giveNext, first and first.unit, first and first.buffs[1].spell)
end

-- Show each window according to its setting (out of combat only).
function ns.applyWindows()
  if InCombatLockdown() or not nearby then return end
  nearby:SetShown(BuffDiggerDB.nearby)
  give:SetShown(BuffDiggerDB.give)
  requests:SetShown(BuffDiggerDB.requests)
  ns.refreshWindow()
  if ns.refreshIncoming then ns.refreshIncoming() end
end

function ns.toggleWindow()
  BuffDiggerDB.nearby = not BuffDiggerDB.nearby
  ns.applyWindows()
end

function ns.toggleGive()
  BuffDiggerDB.give = not BuffDiggerDB.give
  ns.applyWindows()
end

function ns.toggleRequests()
  BuffDiggerDB.requests = not BuffDiggerDB.requests
  ns.applyWindows()
end

-- Hide on entering combat (still allowed during PLAYER_REGEN_DISABLED), back on leaving it.
function ns.onCombat(inCombat)
  if not nearby then return end
  if inCombat then
    nearby:Hide()
    give:Hide()
    requests:Hide()
    ns.refreshThanks() -- Get buffs gone: its gold lines go to Thanks now (not secure: fine in combat)
    -- Still allowed during PLAYER_REGEN_DISABLED: in combat the key can't be re-aimed (nameplate
    -- tokens move to other players), so it does nothing until combat ends.
    giveNext:SetAttribute("type", nil)
  else
    ns.applyWindows()
  end
end

function ns.buildUI()
  extendGameMenu()
  buildSettings()
  buildMinimapButton()
  nearby = makeWindow("BuffDiggerNearby", L["Buff Digger — Get buffs"], "nearby", false, { "LEFT", 40, 60 })
  give = makeWindow("BuffDiggerGive", L["Buff Digger — Give buffs"], "give", true, { "LEFT", 40, -140 })
  -- Requests: opened by the player and placed where they like; requests never pop it up (#13).
  requests = makeWindow("BuffDiggerRequests", L["Buff Digger — Requests"], "requests", true, { "RIGHT", -40, 60 })
  ns.requestsWindow = requests
  function ns.fillRequests(entries) fill(requests, entries, L["No requests right now."]) end
  for _, row in ipairs(requests.rows) do row.buffs[1]:HookScript("PostClick", ns.onRequestClick) end
  -- Key "Give my buff to the next player around" (Bindings.xml, CLICK binding): an invisible secure
  -- button aimed at the first Give buffs line, re-aimed after every refresh (out of combat only).
  giveNext = CreateFrame("Button", "BuffDiggerGiveNext", UIParent, "SecureActionButtonTemplate")
  ns.secureClicks(giveNext)
  giveNext:Hide()
  ns.watchClick(giveNext)
  giveNext:HookScript("PostClick", function(self, _, down)
    if down then return end -- a CLICK binding may send the press too: kept until recette test 14
    if self:GetAttribute("type") then ns.castOn(self.unit)
    else ns.notice(L["Nobody around lacks your buffs right now."]) end
  end)
  -- Players walk in and out of range without any event: look again every second (the windows,
  -- and the next-player key's aim when it is bound).
  C_Timer.NewTicker(1, ns.refreshWindow)
  buildThanks()
  C_Timer.NewTicker(5, ns.refreshThanks) -- lines older than 2 minutes go
  ns.applyWindows()
end
