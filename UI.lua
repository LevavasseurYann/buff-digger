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
-- Sort criteria (#42): { key, label, help in Get buffs, help in Give buffs }. Each entry carries
-- `by[key]`, lower first; ties keep the Best order.
local SORTS = {
  { "best", "Best", "Who has the buff you want most, first.", "In range first, then too far." },
  { "level", "Level", "Highest level first: the highest ranks.", "Lowest level first: who needs it most." },
  { "range", "Range", "In spell range, then in sight, then too far.", "In range, then in sight, then too far." },
  { "missing", "Missing / fading", "Buffs you lack, then running out, then swaps and higher ranks.",
    "Lacking all your buffs first, then whose buff runs out soonest." },
  { "name", "Name", "A to Z.", "A to Z." },
  { "class", "Class", "By class, then name.", "By class, then name." },
}
local PLATE_CHOICES = { { "off", "Nothing" }, { "hint", "Small icon" }, { "best", "Best buff" }, { "all", "Every buff" } }
local WINDOW_STYLES = { { "classic", "Classic" }, { "minimal", "Minimal" } } -- #44

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
-- `tickable`: Get buffs, where Ctrl+click ticks it (#40).
function ns.buffTooltip(owner, unit, key, tickable)
  if not (key and unit) or InCombatLockdown() then return end
  local name, class, level = ns.identity(unit)
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
  if tickable then GameTooltip:AddLine(L["Ctrl+click: tick it, then the arrow asks for every ticked buff at once."], 0.4, 0.8, 1, true) end
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
        or not ns.onMySide(unit) then return end
      local name, class, level = ns.identity(unit)
      local offers = name and ns.offers(class, level) or {}
      if #offers == 0 then return end
      root:CreateDivider()
      addOffers(root, unit, name, level, offers)
    end)
  end
end

-- ---------------------------------------------------------------- settings window (#52)
-- One window of fixed size, its tabs under it as on the game's Character and Social frames. Each
-- tab has two columns of rows, listed in TABS. Layout follows Blizzard's own option panels: gold
-- group titles, white labels, small help. Spacing on a 4/8 px grid; every text has a fixed width
-- and wraps instead of overflowing.

local PAD, COL_W, ROW_H, GAP = 16, 296, 24, 8
local LEFT_X, RIGHT_X = PAD, PAD + COL_W + 24
local WIDTH, HEIGHT, TOP = RIGHT_X + COL_W + PAD, 464, -32 -- 648 x 464, every tab
local LIMIT = -(HEIGHT - PAD - ROW_H - GAP) -- columns end above the bottom line (Show advanced options)

local HOW_TO = {
  "Click a buff icon to ask for that buff, a name in Get buffs to target them. Shift-click: /say instead of whisper (or the reverse). Get buffs: Ctrl-click ticks buffs, the arrow asks for them all at once.",
  "Right-click: every buff that player can give.",
  "Minimap button: right click = Get buffs.",
  "Icons and windows find players through friendly nameplates: keep them on.",
}

-- The key bindings shown in General (Bindings.xml), and where the game lists them.
local KEYS = { "BUFFDIGGER_BEST", "BUFFDIGGER_TARGET", "BUFFDIGGER_THANK", "BUFFDIGGER_NEARBY", "BUFFDIGGER_GIVE",
  "CLICK BuffDiggerGiveNext:LeftButton" }
local KEYS_PATH = "Esc > Options > Keybindings > AddOns > Buff Digger"

-- Rows of each tab: { tab name, left column, right column }. A row is a group title ({ title = ... })
-- or a setting: `key` in BuffDiggerDB, `kind` (check when none), `label`, `tip` (what it changes in
-- game), `advanced` (shown with Show advanced options only). Other kinds: plates (the game's own
-- friendly nameplates), prefs (my buff priorities), help, keys (key bindings).
local TABS = {
  { "General", {
    { title = "Nameplates" },
    { kind = "plates", label = "Friendly nameplates",
      tip = "Buff Digger sees players through their nameplates: with them off, it only sees your group. Pick how they look; hover each choice for more." },
    { key = "plates", kind = "choice", choices = PLATE_CHOICES, translate = true, label = "Icons on nameplates",
      tip = "What Buff Digger puts on friendly players' nameplates: nothing, a small icon, the best buff they can give you, or every buff they can give. Click an icon to ask for it." },
    { key = "tooltip", label = "Buffs line in players' tooltips",
      tip = "Adds a line to a friendly player's tooltip: the buffs they can probably give you." },
    { title = "Windows" },
    { key = "nearby", label = "Get buffs window: who can buff me",
      tip = "Shows the Get buffs window: players around you and the buffs they can give you. Click an icon to ask. Same as right-clicking the minimap button." },
    { key = "give", label = "Give buffs window: who lacks my buffs",
      tip = "Shows the Give buffs window: players around you who lack one of your buffs. Click an icon to cast it on them (out of combat). Same as Shift + right-clicking the minimap button." },
    { key = "nearbyUseful", advanced = true, label = "Get buffs: only those with something better",
      tip = "Get buffs lists only players who can give you something: a buff you lack, a higher rank, or one running out." },
    { key = "windowStyle", kind = "choice", choices = WINDOW_STYLES, translate = true, advanced = true,
      after = function() ns.applyStyle() end, label = "Window style",
      tip = "How Get buffs, Give buffs and Requests look. Classic: Blizzard's frame. Minimal: see-through, fades when the mouse leaves." },
    { title = "Other", advanced = true },
    { key = "gameMenu", advanced = true, label = "Buff requests in the right-click menu",
      tip = "Adds Buff Digger's buff requests to the game's right-click menu on a player, a party or a raid frame." },
    { key = "debug", advanced = true, label = "Debug messages in chat",
      tip = "Prints Buff Digger's notes in chat: what it decided and why, Blizzard blocks, other Buff Digger users found. Useful for bug reports." },
  }, {
    { title = "How to use" },
    { kind = "help" },
    { title = "Key bindings" },
    { kind = "keys", label = "Set key bindings...",
      tip = "Opens the game's key bindings, where Buff Digger's are: " .. KEYS_PATH .. "." },
  } },
  { "Buffs", {
    { kind = "prefs" },
  }, {
    { title = "When to ask again", advanced = true },
    { key = "delay", kind = "cycle", choices = DELAYS, advanced = true, label = "Wait before asking the same player again",
      tip = "How long Buff Digger waits before letting you ask the same player again, so nobody gets spammed." },
    { key = "refreshBefore", kind = "cycle", choices = REFRESH_CHOICES, advanced = true,
      label = "Ask again when a buff has less left than",
      tip = "A buff with less time left than this counts as missing, so you can ask for it again. Never: only missing buffs." },
  } },
  { "Requests & Thanks", {
    { title = "Asking" },
    { key = "language", kind = "choice", choices = ns.LANGUAGES, label = "Write to players in",
      tip = "The language of what Buff Digger sends to other players: requests and thank-yous. Buff Digger's own windows stay in English." },
    { key = "tone", kind = "choice", choices = ns.TONES, translate = true, label = "Tone", -- #49
      tip = "How those messages sound: Casual, Polite or Role play. Try one in the Phrases tab." },
    { kind = "phrases", label = "My own phrases" },
    { key = "useSay", label = "Ask in /say by default (not whisper)",
      tip = "A click on a buff icon asks in /say instead of a whisper. Shift + click does the other one." },
    { key = "targetOnAsk", advanced = true, label = "Get buffs: target the player I ask",
      tip = "Asking from the Get buffs window also targets that player." },
  }, {
    { title = "Thanks" },
    { key = "thankMessage", label = "Send a thank-you message",
      tip = "Clicking Thank sends a thank-you in the channel you asked in (whisper or /say)." },
    { key = "thank", label = "/thank emote when I click Thank",
      tip = "Clicking Thank also does the /thank emote on that player." },
    { key = "thankGifts", advanced = true, label = "Thank line for buffs I didn't ask for",
      tip = "When someone buffs you without being asked, a Thank line shows in Get buffs too, so you can thank them." },
    { title = "Requests from other Buff Digger users" },
    { key = "acceptRequests", label = "Accept requests from Buff Digger users",
      tip = "Other Buff Digger users can ask you for a buff without a whisper: their requests go to the Requests window (Ctrl + right-click the minimap button). Off: you don't get them." },
    { key = "requestSound", advanced = true, label = "Sound when a request arrives",
      tip = "Plays a sound when another Buff Digger user asks you for a buff." },
    { key = "requestMarkers", advanced = true, label = "Marker above players who request a buff",
      tip = "Shows a big pulsing icon above the nameplate of a player asking you for a buff." },
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

-- A label on the left of the row, a button on its right.
local function labelButton(row, caption, width, labelWidth)
  text(row, "GameFontHighlight", 4, -8, labelWidth, caption)
  local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  button:SetSize(width, 22)
  button:SetPoint("TOPRIGHT", 0, -4)
  return button
end

-- Each kind of row: build(row, def) -> the control its tooltip goes on, the row's height.
local BUILD = {}

function BUILD.title(row, def)
  text(row, "GameFontNormal", 0, 0, COL_W, L[def.title])
  return nil, 20
end

function BUILD.check(row, def)
  local box = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
  box:SetSize(ROW_H, ROW_H)
  box:SetPoint("TOPLEFT")
  local label = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("LEFT", box, "RIGHT", 4, 0)
  label:SetWidth(COL_W - ROW_H - 8)
  label:SetJustifyH("LEFT")
  label:SetText(L[def.label])
  box:SetScript("OnShow", function(self) self:SetChecked(BuffDiggerDB[def.key]) end)
  box:SetScript("OnClick", function(self)
    BuffDiggerDB[def.key] = self:GetChecked() and true or false
    ns.applyWindows()
    ns.refreshAll()
  end)
  return box, ROW_H
end

-- A small button; each click moves to the next choice (in seconds, shown in minutes). Room for a
-- label on two lines.
function BUILD.cycle(row, def)
  local key, choices = def.key, def.choices
  local button = labelButton(row, L[def.label], 64, COL_W - 80)
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
  return button, 36
end

-- A button showing the current choice, opening the list. def.choices = { { value, label }, ... }
-- (labels are shown as is unless def.translate: language names stay in their own language).
function BUILD.choice(row, def)
  local key, choices = def.key, def.choices
  local button = labelButton(row, L[def.label], 104, COL_W - 120)
  local function label(c) return def.translate and L[c[2]] or c[2] end
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
    if def.after then def.after() end
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
  return button, 28
end

-- Friendly nameplates (#22): off, or how they look; read from the game's settings, not saved by us.
local PLATE_STYLES = {
  { "full", "Full", "The game's nameplates: name and health bar. Buff Digger's icons next to the bar." },
  { "name", "Name only", "Just their name, in class colour, Buff Digger's icons next to it." },
  { "icons", "Icons only", "No bar, no name (except your target): only Buff Digger's icons float over players." },
  { "off", "Off", "No friendly nameplates: Buff Digger can't see anyone around you (group members still listed)." },
}
function BUILD.plates(row)
  local label = text(row, "GameFontHighlight", 4, -8, COL_W - 120, "")
  local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  button:SetSize(104, 22)
  button:SetPoint("TOPRIGHT", 0, -4)
  local function update()
    local style = ns.plateStyle()
    label:SetText(style == "off" and L["|cffff5555Friendly nameplates|r (needed)"] or L["Friendly nameplates"])
    for _, c in ipairs(PLATE_STYLES) do if c[1] == style then button:SetText(L[c[2]]) end end
  end
  local function choose(style) ns.setPlateStyle(style) update() end
  button:SetScript("OnShow", update)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Friendly nameplates"])
    GameTooltip:AddLine(L["Buff Digger sees players through them. Pick how they look; hover each choice for more."], 1, 1, 1, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- Changed elsewhere (game options, /bd nameplates) while the settings are open.
  C_Timer.NewTicker(1, function() if button:IsVisible() then update() end end)
  button:SetScript("OnClick", function(self)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then -- no menu: each click moves to the next one
      local i = 1
      for j, c in ipairs(PLATE_STYLES) do if c[1] == ns.plateStyle() then i = j end end
      local nxt = PLATE_STYLES[i % #PLATE_STYLES + 1][1]
      if nxt == "icons" and not ns.canSimplify() then nxt = "off" end
      choose(nxt)
      return
    end
    MenuUtil.CreateContextMenu(self, function(_, root)
      for _, c in ipairs(PLATE_STYLES) do
        if c[1] ~= "icons" or ns.canSimplify() then
          local radio = root:CreateRadio(L[c[2]], function() return ns.plateStyle() == c[1] end, function() choose(c[1]) end)
          if radio and radio.SetTooltip then
            radio:SetTooltip(function(tooltip)
              GameTooltip_SetTitle(tooltip, L[c[2]])
              GameTooltip_AddNormalLine(tooltip, L[c[3]])
            end)
          end
        end
      end
    end)
  end)
  return button, 28
end

-- Until the Phrases tab: a button opening the Phrases window.
function BUILD.phrases(row, def)
  local edit = labelButton(row, L[def.label], 104, COL_W - 120)
  edit:SetText(L["Edit..."])
  edit:SetScript("OnClick", function() phrases:SetShown(not phrases:IsShown()) end)
  return edit, 28
end

function BUILD.help(row)
  local lines = {}
  for i, line in ipairs(HOW_TO) do lines[i] = L[line] end
  local help = text(row, "GameFontDisableSmall", 0, 0, COL_W, table.concat(lines, "\n"))
  help:SetSpacing(2)
  -- Measured at each layout (the text is shown then); GetStringHeight can be 0 on a hidden frame:
  -- never less than one line per tip.
  row.measure = function() return math.max(help:GetStringHeight() or 0, #HOW_TO * 14) + 4 end
  return nil, row.measure()
end

-- The game's key bindings page: opened if the game lets us, else where to find it.
local function openKeyBindings()
  if C_SettingsUtil and C_SettingsUtil.OpenSettingsPanel and Settings and Settings.KEYBINDINGS_CATEGORY_ID
    and not InCombatLockdown() then
    settings:Hide() -- shown again, keys read again, when the player comes back
    C_SettingsUtil.OpenSettingsPanel(Settings.KEYBINDINGS_CATEGORY_ID)
  else
    ns.notice(L["Key bindings: %s."]:format(L[KEYS_PATH]))
  end
end

-- Buff Digger's key bindings and the key each one has (decision on #52: they were too well hidden).
function BUILD.keys(row, def)
  local keys = {}
  for i, action in ipairs(KEYS) do
    local y = -(i - 1) * 16
    text(row, "GameFontHighlightSmall", 4, y, COL_W - 100, _G["BINDING_NAME_" .. action])
    keys[i] = text(row, "GameFontNormalSmall", COL_W - 92, y, 92, "")
    keys[i]:SetJustifyH("RIGHT")
  end
  row:SetScript("OnShow", function()
    for i, action in ipairs(KEYS) do
      local key = GetBindingKey(action)
      keys[i]:SetText(key and (GetBindingText and GetBindingText(key) or key) or ("|cff808080" .. L["Not bound"] .. "|r"))
    end
  end)
  local open = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  open:SetSize(160, 22)
  open:SetPoint("TOPLEFT", 0, -(#KEYS * 16 + 4))
  open:SetText(L[def.label])
  open:SetScript("OnClick", openKeyBindings)
  return open, #KEYS * 16 + 4 + 22
end

-- My class's priorities (#5).
function BUILD.prefs(row)
  local _, myClass = UnitClass("player")
  local className = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[myClass] or myClass
  text(row, "GameFontNormal", 0, 0, COL_W, L["My buff priorities (%s)"]:format(className))
  text(row, "GameFontDisableSmall", 0, -20, COL_W, L["Ticked buffs get asked for, top first. Unticked: never asked."])

  prefRows = {}
  local count, y = 0, -40
  for _ in pairs(BUFFS) do count = count + 1 end
  for i = 1, count do
    local line = CreateFrame("Frame", nil, row)
    line:SetSize(COL_W, ROW_H)
    line:SetPoint("TOPLEFT", 0, y)
    line.box = CreateFrame("CheckButton", nil, line, "UICheckButtonTemplate")
    line.box:SetSize(ROW_H, ROW_H)
    line.box:SetPoint("LEFT")
    line.icon = line:CreateTexture(nil, "ARTWORK")
    line.icon:SetSize(18, 18) -- room for the rank number in its corner
    line.icon:SetPoint("LEFT", line.box, "RIGHT", 4, 0)
    line.down = arrow(line, "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown", function()
      local prefs = myPrefs(true)
      local at = indexOf(prefs, line.key)
      prefs[at], prefs[at + 1] = prefs[at + 1], prefs[at]
      changed()
    end)
    line.down:SetPoint("RIGHT")
    line.up = arrow(line, "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp", function()
      local prefs = myPrefs(true)
      local at = indexOf(prefs, line.key)
      prefs[at], prefs[at - 1] = prefs[at - 1], prefs[at]
      changed()
    end)
    line.up:SetPoint("RIGHT", line.down, "LEFT", -4, 0)
    line.text = line:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    line.text:SetPoint("LEFT", line.icon, "RIGHT", 8, 0)
    line.text:SetPoint("RIGHT", line.up, "LEFT", -8, 0)
    line.text:SetJustifyH("LEFT")
    line.text:SetWordWrap(false)
    line.box:SetScript("OnClick", function(self)
      local prefs = myPrefs(true)
      local at = indexOf(prefs, line.key)
      if self:GetChecked() and not at then tinsert(prefs, line.key)
      elseif not self:GetChecked() and at then tremove(prefs, at) end
      changed()
    end)
    prefRows[i] = line
    y = y - ROW_H
  end

  local reset = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  reset:SetSize(120, 22)
  reset:SetPoint("TOPLEFT", 0, y - GAP)
  reset:SetText(L["Reset to default"])
  reset:SetScript("OnClick", function()
    BuffDiggerDB.prefs[myClass] = nil
    changed()
  end)
  return nil, -y + GAP + 22
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

-- A tab's two columns, each row built once; layout() places them.
local function buildPanel(tab)
  local panel = CreateFrame("Frame", nil, settings)
  panel:SetAllPoints()
  panel.rows, panel.columns = {}, {}
  for c = 1, 2 do
    local column = { x = c == 1 and LEFT_X or RIGHT_X }
    for _, def in ipairs(tab[c + 1]) do
      local row = CreateFrame("Frame", nil, panel)
      row.def = def
      row.control, row.h = BUILD[def.kind or (def.title and "title") or "check"](row, def)
      row:SetSize(COL_W, row.h)
      column[#column + 1] = row
      panel.rows[#panel.rows + 1] = row
    end
    panel.columns[c] = column
  end
  return panel
end

-- Top to bottom in each column, a gap before each group title but the first.
local function layout(panel)
  for _, column in ipairs(panel.columns) do
    local y = TOP
    for _, row in ipairs(column) do
      if row.measure then row.h = row.measure(); row:SetHeight(row.h) end
      if row.def.title and y ~= TOP then y = y - GAP end
      row:SetPoint("TOPLEFT", column.x, y)
      row.y = y
      y = y - row.h
    end
    column.bottom = y
  end
end

local function selectTab(i)
  PanelTemplates_SetTab(settings, i)
  for j, panel in ipairs(settings.panels) do panel:SetShown(j == i) end
  layout(settings.panels[i])
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
    edit:SetText(table.concat(ns.builtIn(w.kind, BuffDiggerDB.language, BuffDiggerDB.tone), "\n"))
    check()
    edit:SetFocus()
  end)

  -- Preview: a phrase drawn for this case, printed for me only.
  local preview = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
  preview:SetSize(150, 22)
  preview:SetPoint("BOTTOMRIGHT", -PAD, PAD)
  preview:SetText(L["Try one (only you see it)"])
  preview:SetScript("OnClick", function()
    local lang, tone = BuffDiggerDB.language, BuffDiggerDB.tone
    ns.say(w.kind == "thanks" and ns.thanks(lang, tone)
      or ns.message(w.kind, w.kind == "replace" and "kings" or "fortitude", lang, tone))
  end)
  w.preview = preview
  phrases = w
end

local function buildSettings()
  settings = CreateFrame("Frame", "BuffDiggerSettings", UIParent, "BasicFrameTemplateWithInset")
  settings:SetSize(WIDTH, HEIGHT)
  settings:SetPoint("CENTER")
  settings:SetMovable(true)
  settings:EnableMouse(true)
  settings:RegisterForDrag("LeftButton")
  settings:SetScript("OnDragStart", settings.StartMoving)
  settings:SetScript("OnDragStop", settings.StopMovingOrSizing)
  settings:SetScript("OnShow", function() refreshPrefs() end)
  settings:Hide()
  tinsert(UISpecialFrames, "BuffDiggerSettings") -- Escape closes it
  settings.limit = LIMIT

  local title = settings:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", 0, -5)
  title:SetText("Buff Digger")

  buildPhrases()
  settings.panels, settings.tabButtons = {}, {}
  for i, tab in ipairs(TABS) do
    settings.panels[i] = buildPanel(tab)
    local button = CreateFrame("Button", "BuffDiggerSettingsTab" .. i, settings, "PanelTabButtonTemplate")
    button:SetID(i)
    button:SetText(L[tab[1]])
    button:SetScript("OnClick", function() selectTab(i) end)
    settings.tabButtons[i] = button
  end
  settings.tabButtons[1]:SetPoint("TOPLEFT", settings, "BOTTOMLEFT", 12, 2)
  PanelTemplates_SetNumTabs(settings, #TABS) -- anchors the other tabs, each after the one before
end

-- Minimap left click, /bd config: always opens on General (#52).
function ns.toggleSettings()
  if not settings then return end
  if settings:IsShown() then settings:Hide() return end
  settings:Show()
  selectTab(1)
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

-- Window style (#44). "classic": Blizzard's frame. "minimal": like the borderless skins of Details!
-- or Skada, a flat see-through dark background without the frame art, and the window fades while
-- the mouse is elsewhere (full again under it, like the chat frame). The template's textures are
-- only hidden: back to classic shows them again.
local MINIMAL_BG, MINIMAL_REST = 0.45, 0.6 -- background opacity; window opacity with the mouse away
local styled = {} -- the list windows
local function skin(w)
  w.chrome = { w:GetRegions() } -- the template's own textures: call right after CreateFrame
  w.flat = w:CreateTexture(nil, "BACKGROUND")
  w.flat:SetAllPoints()
  w.flat:SetColorTexture(0, 0, 0, MINIMAL_BG)
  styled[#styled + 1] = w
end

function ns.applyStyle()
  local minimal = BuffDiggerDB.windowStyle == "minimal"
  for _, w in ipairs(styled) do
    for _, r in ipairs(w.chrome) do r:SetShown(not minimal) end
    w.flat:SetShown(minimal)
    w:SetAlpha(1) -- minimal: the fader takes it from there
  end
end

-- Minimal: each shown window eases to full opacity under the mouse, to MINIMAL_REST elsewhere.
-- Not secure (alpha only): fine in combat too.
local fader = CreateFrame("Frame")
fader:SetScript("OnUpdate", function(_, elapsed)
  if not (BuffDiggerDB and BuffDiggerDB.windowStyle == "minimal") then return end
  for _, w in ipairs(styled) do
    if w:IsShown() then
      local a, target = w:GetAlpha(), w:IsMouseOver() and 1 or MINIMAL_REST
      if a < target then w:SetAlpha(math.min(target, a + elapsed * 5)) -- quick in, slow out
      elseif a > target then w:SetAlpha(math.max(target, a - elapsed * 1.5)) end
    end
  end
end)
local pulsed = {} -- name -> their Get buffs band already flashed gold (#24)

-- Get buffs (#40): name -> the buffs ticked on their line with Ctrl+click, in click order; the arrow
-- at the end of the line asks for them all in one request. Forgotten once sent or off the list.
local picked = {}
local function togglePick(name, key)
  local list = picked[name] or {}
  for i, k in ipairs(list) do
    if k == key then
      table.remove(list, i)
      picked[name] = #list > 0 and list or nil
      return
    end
  end
  -- A paladin's blessings replace each other on me: ticking one unticks his other one (#39).
  if BUFFS[key].class == "PALADIN" then list = {} end
  list[#list + 1] = key
  picked[name] = list
end
local function isPicked(name, key)
  for _, k in ipairs(picked[name] or {}) do if k == key then return true end end
  return false
end

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
-- `setting` is the BuffDiggerDB key that remembers whether it is open. `sortable`: the order in the
-- title bar, left of the title (#42), its choice kept in BuffDiggerDB.sort[setting].
local function makeWindow(globalName, title, setting, cast, point, sortable)
  local w = CreateFrame("Frame", globalName, UIParent, "BasicFrameTemplateWithInset")
  skin(w)
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
  w.lock:SetSize(24, 24) -- its art fills ~2/3 of the frame: shows ~16 px, the sort arrow's size (#42)
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
      if row.unit and ns.targetName(row.unit) == row.entry.who then return false end -- a line out of sight has no unit
      ns.notice(L["%s is no longer around."]:format(row.entry.who or "?"))
      return true
    end
    ns.secureClicks(row)
    row:HookScript("PostClick", function(self, mouse)
      if cast then return end
      -- A gold line (#24) does nothing on its own: only its tick + "Thank" (row.thankButton) thanks,
      -- a click next to the cross must not whisper anyone.
      if mouse == "RightButton" and not gone() then ns.openMenu(self, self.unit) end
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
      -- The tick and "Thank" are the button (a real click: /say goes too); Shift/Ctrl: other channel.
      row.thankButton = CreateFrame("Button", nil, row)
      row.thankButton:SetPoint("TOPLEFT", row.status, "TOPLEFT", -2, 2)
      row.thankButton:SetPoint("BOTTOMRIGHT", row.thank, "BOTTOMRIGHT", 2, -2)
      row.thankButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
      row.thankButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      row.thankButton:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then -- the player's menu, as anywhere else on the line
          if not gone() then ns.openMenu(row, row.unit) end
          return
        end
        ns.thankBuffer(row.entry.who, IsShiftKeyDown() or IsControlKeyDown())
        if not InCombatLockdown() then w.fill() end
      end)
      row.thankButton:SetScript("OnEnter", function(self)
        local t = row.gift
        if not t then return end
        local names = {}
        for i, k in ipairs(t.keys) do names[i] = spellName(k) end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["Gift: %s (unasked)"]:format(table.concat(names, ", ")))
        GameTooltip:Show()
      end)
      row.thankButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
      row.thankButton:Hide()
      -- Buffs ticked on this line (#40): the arrow sends them, one request; Shift: the other channel.
      row.send = CreateFrame("Button", nil, row)
      row.send:SetSize(18, 18)
      row.send:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
      row.send:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
      row.send:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
      row.send:SetScript("OnClick", function()
        local keys = picked[row.entry.who]
        if InCombatLockdown() or not keys or gone() then return end
        -- Refused (too far, all asked a moment ago): the ticks stay, ns.request said why.
        if ns.request(row.unit, keys) then picked[row.entry.who] = nil end
        w.fill()
      end)
      row.send:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["Ask for the ticked buffs"])
        GameTooltip:AddLine(L["Shift-click: /say instead of whisper (or the reverse)."], 0.4, 0.8, 1, true)
        GameTooltip:Show()
      end)
      row.send:SetScript("OnLeave", function() GameTooltip:Hide() end)
      row.send:Hide()
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
        -- Ticked with Ctrl+click (#40): a check mark in the corner.
        b.pick = b:CreateTexture(nil, "OVERLAY", nil, 2)
        b.pick:SetSize(14, 14)
        b.pick:SetPoint("TOPLEFT", -4, 4)
        b.pick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        b.pick:Hide()
        b:HookScript("PostClick", function(self, mouse)
          if gone() then return end
          if mouse == "RightButton" then ns.openMenu(self, row.unit)
          elseif mouse ~= "LeftButton" then return
          elseif IsControlKeyDown() then
            if InCombatLockdown() then return end
            togglePick(row.entry.who, self.key)
            w.fill()
          else ns.request(row.unit, self.key) end
        end)
      end
      b:SetScript("OnEnter", function(self)
        if cast then ns.castTooltip(self, self.key, self:GetAttribute("type") and row.entry.who or nil)
        else ns.buffTooltip(self, row.unit, self.key, true) end
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
  if sortable then
    -- A red arrow button in the title bar, mirroring the padlock (#42): a click opens the criteria
    -- as radios; without the game's menu, each click moves to the next one. No text: the title bar
    -- holds controls (close, padlock), the current order is in the tooltip and checked in the menu.
    local bar = CreateFrame("Button", nil, w)
    -- The padlock's family, not the close button's: small and inside the title bar (20 px high,
    -- centre 11 px down), with a clear margin. Right against the border, the dark strip left
    -- between the frame and the button's bevel read as a hole.
    bar:SetSize(16, 16)
    bar:SetPoint("LEFT", w, "TOPLEFT", 7, -11)
    -- Blizzard's own red arrow button (character select, shop cart), present in Forever.
    bar:SetNormalAtlas("128-RedButton-ArrowDown")
    bar:SetPushedAtlas("128-RedButton-ArrowDown-Pressed")
    bar:SetHighlightAtlas("128-RedButton-ArrowDown-Highlight", "ADD")
    local function current()
      for i, c in ipairs(SORTS) do if c[1] == BuffDiggerDB.sort[setting] then return i, c end end
      return 1, SORTS[1]
    end
    local function choose(key)
      BuffDiggerDB.sort[setting] = key ~= "best" and key or nil
      w.offset = 0 -- back to the top of the new order
      if w.fill and not InCombatLockdown() then w.fill() end
    end
    bar:SetScript("OnClick", function(self)
      if not (MenuUtil and MenuUtil.CreateContextMenu) then
        choose(SORTS[current() % #SORTS + 1][1])
        return
      end
      MenuUtil.CreateContextMenu(self, function(_, root)
        root:CreateTitle(L["Sort by"])
        for _, c in ipairs(SORTS) do
          root:CreateRadio(L[c[2]], function() return select(2, current()) == c end, function() choose(c[1]) end)
        end
      end)
    end)
    bar:SetScript("OnEnter", function(self)
      local c = select(2, current())
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(L["Sort: %s"]:format(L[c[2]]))
      GameTooltip:AddLine(L[cast and c[4] or c[3]], 1, 1, 1, true)
      if not cast then GameTooltip:AddLine(L["Players you asked or have to thank stay first of their section."], 0.6, 0.6, 0.6, true) end
      GameTooltip:AddLine(L["Click: change the order."], 0.4, 0.8, 1, true)
      GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
    w.sortBar = bar
  end
  listWindows[#listWindows + 1] = w
  applyLock()
  return w
end

-- entries: { { unit, who (their name, read with the text: scrolling re-fills from these cached
--   entries, by then the nameplate token may be someone else's; false = unreadable), text, far (Get buffs: red icons),
--   buffs = { { key, icon, rank, upgrade, refresh, best, his (Get buffs), spell (cast windows; nil = red,
--   not castable) }, ... } }, ... }
-- In a group (#16): a "Group (n)" header line, the members (entries say `group`, and come first),
-- then "Around" and everyone else. Out of a group, the list as it is.
-- Folded (hideGroup): the header stays, with its count, the members don't, but those I asked or have
-- to thank (`first`): no other place shows a gold line (#43).
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
    if not (e.group and hideGroup and not e.first) then out[#out + 1] = e end
  end
  return out
end

-- The list in the window's sort order (#42): a copy, `list` stays in the Best order. Group members
-- stay first (withHeaders' sections); in Get buffs, so do the lines I asked or have to thank (#24),
-- as they were when the list was built (`first`): under the cursor a re-fill must not move a line.
local function sorted(w, list)
  local by = w.sortBar and BuffDiggerDB.sort[w.setting]
  if not by then return list end
  local out, rank, pos = {}, {}, {}
  for i, e in ipairs(list) do
    out[i], pos[e] = e, i
    rank[e] = (e.group and 0 or 2) + (e.first and 0 or 1)
  end
  table.sort(out, function(a, b)
    if rank[a] ~= rank[b] then return rank[a] < rank[b] end
    local ka, kb = a.by[by], b.by[by]
    if ka ~= kb then return ka < kb end
    return pos[a] < pos[b] -- table.sort is not stable
  end)
  return out
end

local function fill(w, list, emptyMessage)
  -- Re-fills (scroll, resize, [-]) start again from the list without headers: headers on headers
  -- piled up "Group / Around" and lost the folded members.
  w.fill = function() fill(w, list, emptyMessage) end
  local entries = withHeaders(sorted(w, list), BuffDiggerDB.hideGroup[w.setting])
  w.entries = entries
  -- A gold line flashes once per buff: forget those no longer to thank, wherever they were thanked
  -- (key, folded group), so their next buff flashes again.
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
        row.thankButton:SetShown(state == "thank")
        -- A gift (#43): the buff they gave instead of the tick (my request honoured); same gold band.
        local t = state == "thank" and ns.thankEntry(e.who)
        local gift = t and t.request.gift and t.keys[#t.keys]
        row.gift = gift and t or nil
        if gift then
          row.status:SetTexture(C_Spell.GetSpellTexture(BUFFS[gift].id) or 134400)
          row.status:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- the icon's border trimmed, like action buttons
        else
          row.status:SetTexCoord(0, 1, 0, 1)
        end
        row.status:SetDesaturated(gift and not e.unit or false) -- out of sight: grey, like the name
        if GameTooltip:IsOwned(row.thankButton) then row.thankButton:GetScript("OnEnter")(row.thankButton) end
        if state == "thank" then
          fadeRight(row.band, 1, 0.82, 0, 0.35)
          row.edge:SetColorTexture(1, 0.82, 0, 0.9)
          if not gift then row.status:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready") end
          row.status:SetPoint("RIGHT", row.thank, "LEFT", -2, 0)
        else
          fadeRight(row.band, 1, 0.5, 0.1, 0.25)
          row.edge:SetColorTexture(1, 0.5, 0.1, 0.9)
          row.status:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
          row.status:SetPoint("RIGHT", -20, 0)
        end
        -- The arrow (#40) before the status icon, if any; the name never under them, whatever the width of "Thank".
        local ticked = e.who and picked[e.who] ~= nil
        row.send:SetShown(ticked)
        if state then row.send:SetPoint("RIGHT", row.status, "LEFT", -2, 0) else row.send:SetPoint("RIGHT", -20, 0) end
        local stop = ticked and row.send or state and row.status
        if stop then row.text:SetPoint("RIGHT", stop, "LEFT", -4, 0) else row.text:SetPoint("RIGHT", -18, 0) end
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
          if b.pick then b.pick:SetShown(isPicked(e.who, buff.key)) end
          -- Green: higher than the one I have, like an upgrade in a loot tooltip. Orange: mine is
          -- running out, like a buff's timer about to end.
          if buff.upgrade then b.rank:SetTextColor(0.1, 1, 0.1)
          elseif buff.refresh then b.rank:SetTextColor(1, 0.5, 0)
          else b.rank:SetTextColor(1, 1, 1) end
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

local nearby, give, giveNext, requests

-- ---------------------------------------------------------------- Get buffs (idea 4)

-- Everyone around who can give me something: those with a buff I'm missing (or an upgrade) first,
-- my top pick first among them; then the ones whose buffs I all have, for picking by hand
-- (left out with "nearbyUseful": nothing from my priority list missing, no higher rank, nothing
-- running out — ns.bestBuff gave no key).
local MISSING_RANK = { new = 0, refresh = 1, replace = 2, upgrade = 2 } -- "Missing / fading" sort (#42)
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
          upgrade = k == key and kind == "upgrade", refresh = k == key and kind == "refresh", best = key, his = his,
        }
      end
      -- No words (#22): higher rank and running out by the rank's colour, a swap by circling arrows,
      -- too far by red icons; the tooltip still says it.
      -- A silent request to another Buff Digger user brought nothing: offer, never send (#13).
      local extra = ns.unanswered(name) and L[" |cffffd100no answer: click a buff to whisper|r"] or ""
      local tail = ("%s %d%s"):format(ns.isPeer(name) and " |TInterface\\COMMON\\FavoritesIcon:12|t" or "", level, extra)
      entries[#entries + 1] = {
        unit = unit, who = name, buffs = buffs, group = ns.isMember(unit), far = far, first = state and true,
        -- Sort keys (#42). Range: their spell can reach me (when the game says), in sight, too far.
        by = { level = -level, range = far and 2 or ns.tooFar(BUFFS[offers[1]].id, unit) and 1 or 0,
          missing = MISSING_RANK[kind] or 3, name = name:lower(), class = class .. " " .. name:lower() },
        -- Members in sight, then members too far, then everyone else; asked or to thank first of each.
        order = state and (ns.isMember(unit) and -7 or -0.5)
          or (ns.isMember(unit) and (far and -3 or -6) or 0) + (key and (top and 0 or 1) or 2),
        text = classColored(name, class) .. tail,
      }
    end
  end
  -- Someone to thank who walked out of sight keeps their gold line (no unit, no icons) until I thank
  -- them, close it or ns.thanksWaiting lets them go (#24).
  local listed = {}
  for _, e in ipairs(entries) do listed[e.who] = true end
  for n in pairs(picked) do if not listed[n] then picked[n] = nil end end -- off the list: ticks forgotten (#40)
  for _, t in ipairs(ns.thanksWaiting()) do
    if not listed[t.name] then
      entries[#entries + 1] = { who = t.name, buffs = {}, order = -0.5, first = true,
        by = { level = 0, range = 2, missing = 3, name = t.name:lower(), class = (t.class or "") .. " " .. t.name:lower() },
        text = "|cff808080" .. t.name .. "|r" } -- grey: out of sight, like an offline friend
    end
  end
  -- Group members first (#16); table.sort is not stable: keep the list order within each rank.
  for i, e in ipairs(entries) do e.i = i end
  table.sort(entries, function(a, b) if a.order ~= b.order then return a.order < b.order end return a.i < b.i end)
  return entries
end

-- ---------------------------------------------------------------- Give buffs (idea 5)

-- Does this unit have this buff (rank 1 or group version)? Second value: cast by me; third: when it
-- wears off (GetTime(), nil when hidden or none). nil when the game keeps it secret.
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
        local t = aura.expirationTime
        return true, ns.readable(aura.sourceUnit) and aura.sourceUnit == "player",
          ns.readable(t) and type(t) == "number" and t > 0 and t or nil
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
-- Second value (#42): seconds left on the first to wear off of those they have; -1: they have none,
-- math.huge: time hidden or none.
local function buffsToGive(unit, theirClass, myBuffs)
  local list, left = {}, -1
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
        local has, _, ends = unitHas(unit, BUFFS[key])
        if has == nil then return {} end -- unreadable: stay silent rather than guess
        if has == false then list[#list + 1] = key
        else left = math.min(left < 0 and math.huge or left, ends and math.max(0, ends - GetTime()) or math.huge) end
      end
    end
  end
  return list, left
end

-- Players I just buffed with the next-player key: "First Last" (ns.unitName) -> GetTime(). They
-- stay out of the list a few seconds, so pressing the key again moves on to someone else, even when
-- the game can't show me their new buff yet or the cast failed (line of sight). A click in the
-- window passes no unit.
local justCast = {}

function ns.castOn(unit)
  local name = unit and ns.unitName(unit)
  if name then justCast[name] = GetTime() end
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
    local cast = name and justCast[name]
    if cast and GetTime() - cast < SKIP_AFTER_CAST then name = nil end
    local keys, left = {}, nil
    if name then keys, left = buffsToGive(unit, class, myBuffs) end
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
        by = { level = level, range = far and (ns.outOfSight(unit) and 2 or 1) or 0, missing = left,
          name = name:lower(), class = class .. " " .. name:lower() }, -- sort keys (#42)
        text = ("%s %d"):format(classColored(name, class), level),
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
  -- nil for a spell with no target (an attack, a self buff). The game gives "Raide Boule" (seen in
  -- game, recette 45); chatName also turns "Raide-Boule" into it. Keyed by the whole name (#33).
  local name = type(target) == "string" and target ~= "" and ns.chatName(target)
  if not name then return end
  justCast[name] = GetTime()
  C_Timer.After(1, ns.refreshAll)
end

-- ---------------------------------------------------------------- refresh and visibility

ns.refreshWindow = ns.timed("refreshWindow", function()
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
end)

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
  nearby = makeWindow("BuffDiggerNearby", L["Buff Digger — Get buffs"], "nearby", false, { "LEFT", 40, 60 }, true)
  give = makeWindow("BuffDiggerGive", L["Buff Digger — Give buffs"], "give", true, { "LEFT", 40, -140 }, true)
  -- Requests: opened by the player and placed where they like; requests never pop it up (#13).
  requests = makeWindow("BuffDiggerRequests", L["Buff Digger — Requests"], "requests", true, { "RIGHT", -40, 60 })
  ns.requestsWindow = requests
  function ns.fillRequests(entries) fill(requests, entries, L["No requests right now."]) end
  for _, row in ipairs(requests.rows) do
    for _, b in ipairs(row.buffs) do b:HookScript("PostClick", ns.onRequestClick) end
  end
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
  ns.applyStyle()
  ns.applyWindows()
end
