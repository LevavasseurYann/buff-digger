-- Buff Digger: core logic.
-- Shows which nearby players can probably buff you, and asks them in one click. Out of combat only.
-- The chat stays quiet: diagnostics ("bets", see docs/ideas/demande-de-buffs.md) only print when
-- "Debug messages" is ticked in the settings; /bd always prints the full report.

local ADDON_NAME, ns = ...
local isSecret = issecretvalue or function() return false end
local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
local BUFFS, rankAt, L = ns.BUFFS, ns.rankAt, ns.L

local function say(...) print("|cff66ccff[Buff Digger]|r", ...) end
ns.say = say
local function readable(v) return not isSecret(v) end
-- A "secret" boolean breaks an `if`: only test what is readable.
local function truthy(v) return readable(v) and v and true or false end
ns.readable, ns.truthy = readable, truthy
local function show(v)
  if isSecret(v) then return "|cffff5555<secret>|r" end
  return tostring(v)
end

ns.DEFAULTS = {
  icons = true,      -- icon left of the health bar
  tooltip = true,    -- "Can probably give you..." line
  nearby = false,    -- "Nearby" window
  give = false,      -- "Give buffs" window (buffer classes)
  thank = true,      -- automatic /thank
  useSay = false,    -- ask in /say instead of a whisper
  frenchMessages = false, -- messages to other players in French (English otherwise)
  debug = false,     -- print bet verdicts in chat
  delay = 120,       -- seconds before asking the same player again (#6)
}

-- ---------------------------------------------------------------- bets (diagnostics)

local BETS = {
  { key = "identity", label = "Read class and level of a player nearby" },
  { key = "plate",    label = "Put an icon on their nameplate" },
  { key = "click",    label = "Receive a click on that icon" },
  { key = "tooltip",  label = "Add a line to their tooltip" },
  { key = "source",   label = "Know who put a buff on me" },
  { key = "thank",    label = "Automatic /thank" },
  { key = "others",   label = "Read another player's buffs (buffer mode)" },
  { key = "whisper",  label = "Send a whisper" },
  { key = "say",      label = "Talk in /say" },
}
local verdicts = {}

local function record(key, ok, detail)
  local before = verdicts[key]
  if before and before.ok == ok then return end
  verdicts[key] = { ok = ok, detail = detail }
  if not (BuffDiggerDB and BuffDiggerDB.debug) then return end
  for _, b in ipairs(BETS) do
    if b.key == key then
      say((ok and "|cff55ff55YES|r " or "|cffff5555NO|r ") .. b.label .. (detail and (" — " .. detail) or ""))
    end
  end
end
ns.record = record

-- ---------------------------------------------------------------- my buffs

-- Spell name (rank 1 and group version) -> buff key, built once names are available.
local keyByName
local function buffKeyOf(spellName)
  if not keyByName then
    keyByName = {}
    for key, buff in pairs(BUFFS) do
      local n = C_Spell.GetSpellName(buff.id)
      if n then keyByName[n] = key end
      for _, id in ipairs(buff.group or {}) do
        n = C_Spell.GetSpellName(id)
        if n then keyByName[n] = key end
      end
    end
  end
  return keyByName[spellName]
end
ns.buffKeyOf = buffKeyOf

-- What I currently have: key -> { rank = estimated rank or nil if unknown, giver = name or nil }.
-- The rank is estimated from the giver's level when the buff lands; a buff already there at login,
-- or from a giver without a unit token, has an unknown rank and is never "upgraded".
local mine = {}
local byInstance = {} -- auraInstanceID -> { key, rank, giver }
local ready = false

local function onBuffLanded(aura, info)
  local source = aura.sourceUnit
  if not readable(source) or not readable(aura.spellId) then record("source", false, "source or spell secret") return end
  if not source then
    -- A stranger outside the group does not always have a unit token: count those cases.
    BuffDiggerDB.noSource = BuffDiggerDB.noSource + 1
    return
  end
  if truthy(UnitIsUnit(source, "player")) or not truthy(UnitIsPlayer(source)) then return end

  local name = UnitName(source)
  local _, class = UnitClass(source)
  local level = UnitLevel(source)
  if not (readable(name) and readable(class) and readable(level)) then record("source", false, "giver secret") return end
  record("source", true, name .. " → " .. show(aura.name))

  info.giver = name
  if info.key then info.rank = rankAt(BUFFS[info.key], level) end

  -- Raw log for checking the data table against reality.
  local entry = BuffDiggerDB.buffs[aura.spellId] or { name = aura.name, classes = {} }
  local seen = entry.classes[class]
  entry.classes[class] = seen and math.min(seen, level) or level
  BuffDiggerDB.buffs[aura.spellId] = entry

  if BuffDiggerDB.thank then
    local ok, err = pcall(DoEmote, "THANK", name)
    record("thank", ok, ok and ("/thank to " .. name) or tostring(err))
  end
end

local function readMyBuffs()
  local seen = {}
  for i = 1, 40 do
    local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
    if not ok or not aura then break end
    local id = aura.auraInstanceID
    if readable(id) and readable(aura.name) then
      local info = byInstance[id]
      if not info then
        info = { key = buffKeyOf(aura.name) }
        if ready then onBuffLanded(aura, info) end
      end
      seen[id] = info
    end
  end
  byInstance, ready = seen, true -- the first pass thanks nobody
  mine = {}
  for _, info in pairs(byInstance) do
    if info.key then mine[info.key] = { rank = info.rank, giver = info.giver } end
  end
end

-- ---------------------------------------------------------------- decision tree

function ns.prefsFor(class)
  return (BuffDiggerDB and BuffDiggerDB.prefs and BuffDiggerDB.prefs[class]) or ns.PREFERENCES[class] or {}
end

local function prefIndex(prefs, key)
  for i, k in ipairs(prefs) do if k == key then return i end end
  return math.huge
end

-- What should I ask this player for? Returns buff key, kind, isTopPick — or nil.
-- kind: "new" (I lack it), "replace" (this paladin swaps his blessing for one I value more),
--       "upgrade" (same buff, higher rank than mine).
-- 1. Buffs I lack, in my preference order. A paladin who already blessed me only counts if the
--    new blessing ranks higher than his current one (his old one disappears).
-- 2. Otherwise, a higher rank of a buff I already have — never from a paladin who already
--    blessed me (it would replace his other blessing), never when my rank is unknown.
function ns.bestBuff(name, class, level)
  local _, myClass = UnitClass("player")
  local prefs = ns.prefsFor(myClass)
  local hisBlessing
  for key, have in pairs(mine) do
    if have.giver == name and BUFFS[key].class == "PALADIN" then hisBlessing = key end
  end

  local missingSeen = 0
  for i, key in ipairs(prefs) do
    local buff = BUFFS[key]
    if not mine[key] then
      missingSeen = missingSeen + 1
      if buff.class == class and rankAt(buff, level) > 0 then
        if not hisBlessing then return key, "new", missingSeen == 1 end
        if i < prefIndex(prefs, hisBlessing) then return key, "replace", missingSeen == 1 end
      end
    end
  end

  if class == "PALADIN" and hisBlessing then return end
  for _, key in ipairs(prefs) do
    local buff, have = BUFFS[key], mine[key]
    if have and have.rank and buff.class == class and have.giver ~= name and rankAt(buff, level) > have.rank then
      return key, "upgrade", false
    end
  end
end

-- Readable identity of a unit, or nil.
function ns.identity(unit)
  local name, realm = UnitName(unit)
  local _, class = UnitClass(unit)
  local level = UnitLevel(unit)
  local ok = readable(name) and readable(class) and readable(level)
  record("identity", ok, show(name) .. " " .. show(class) .. " " .. show(level))
  if ok then return name, class, level, realm end
end

-- ---------------------------------------------------------------- asking

-- Anti-nagging: never ask the same player twice within BuffDiggerDB.delay seconds. Kept in the
-- saved variables (real clock), so a /reload does not reset it (#6).
function ns.askedAgo(name)
  local at = BuffDiggerDB.asked[name]
  local ago = at and (time() - at)
  if ago and ago < BuffDiggerDB.delay then return ago end
end

-- What kind of request is asking `name` for `key`, when the player chose the buff themselves?
-- Same rules as ns.bestBuff: "upgrade" only when my rank is known and theirs is higher.
local function kindFor(name, key, level)
  local have = mine[key]
  if have then
    return (have.rank and rankAt(BUFFS[key], level) > have.rank) and "upgrade" or "new"
  end
  for k, h in pairs(mine) do
    if h.giver == name and BUFFS[k].class == "PALADIN" and BUFFS[key].class == "PALADIN" and k ~= key then
      return "replace"
    end
  end
  return "new"
end

-- Buffs this player can probably give, my priorities first, then the rest (#4's menu).
function ns.offers(class, level)
  local _, myClass = UnitClass("player")
  local prefs = ns.prefsFor(myClass)
  local list = {}
  for key, buff in pairs(BUFFS) do
    if buff.class == class and rankAt(buff, level) > 0 then list[#list + 1] = key end
  end
  table.sort(list, function(a, b)
    local ia, ib = prefIndex(prefs, a), prefIndex(prefs, b)
    if ia ~= ib then return ia < ib end
    return a < b
  end)
  return list
end

function ns.haveBuff(key) return mine[key] ~= nil end

-- Ask `unit` for a buff: the best one, or `chosenKey` when the player picked it (#4).
function ns.request(unit, chosenKey)
  if InCombatLockdown() then return end
  if not unit or not truthy(UnitExists(unit)) then say(L["No player targeted."]) return end
  local name, class, level, realm = ns.identity(unit)
  if not name then return end
  local key, kind
  if chosenKey then
    key, kind = chosenKey, kindFor(name, chosenKey, level)
  else
    key, kind = ns.bestBuff(name, class, level)
  end
  if not key then say(L["%s has nothing better for you right now."]:format(name)) return end
  local ago = ns.askedAgo(name)
  if ago then
    say(L["Already asked %s %d s ago, give them a moment."]:format(name, ago))
    return
  end
  local text = ns.message(kind, key, BuffDiggerDB.frenchMessages)
  -- Shift or Ctrl held: the other channel than the default one (whisper <-> /say).
  local useSay = BuffDiggerDB.useSay ~= (IsShiftKeyDown() or IsControlKeyDown() or false)
  if useSay then
    send(name .. " : " .. text, "SAY")
  else
    local target = (realm and realm ~= "") and (name .. "-" .. realm) or name
    send(text, "WHISPER", nil, target)
  end
  BuffDiggerDB.asked[name] = time()
end

-- One key press, no aiming: among the players around me, ask the one who can give the buff I
-- want most (missing buffs before replacements before upgrades), skipping anyone asked recently.
-- A key press counts as a real input, so /say works from here too.
function ns.askBest()
  if InCombatLockdown() then return end
  local _, myClass = UnitClass("player")
  local prefs = ns.prefsFor(myClass)
  local KIND_ORDER = { new = 0, replace = 1, upgrade = 2 }
  local bestUnit, bestScore
  for _, unit in ipairs(ns.nearbyUnits()) do
    local name, class, level = ns.identity(unit)
    local recent = name and ns.askedAgo(name)
    if name and not recent then
      local key, kind = ns.bestBuff(name, class, level)
      if key then
        local score = KIND_ORDER[kind] * 100 + prefIndex(prefs, key)
        if not bestScore or score < bestScore then bestUnit, bestScore = unit, score end
      end
    end
  end
  if bestUnit then ns.request(bestUnit) else say(L["Nobody around can give you anything better right now."]) end
end

-- ---------------------------------------------------------------- nearby players

-- Nameplate units currently shown, kept from NAME_PLATE_UNIT_ADDED / REMOVED: in Forever,
-- C_NamePlate.GetNamePlates() does not list friendly players' plates (seen 2026-11-08), the events do.
local shownPlates = {}

-- Friendly players whose nameplate is visible (friendly nameplates must be turned on).
function ns.nearbyUnits()
  local units = {}
  for unit in pairs(shownPlates) do
    if truthy(UnitExists(unit)) and truthy(UnitIsPlayer(unit)) and not truthy(UnitIsUnit(unit, "player"))
      and truthy(UnitIsFriend("player", unit)) then
      units[#units + 1] = unit
    end
  end
  return units
end

local icons = {} -- nameplate -> our button; Blizzard's frames are never modified

local function iconFor(unit)
  local plate = C_NamePlate.GetNamePlateForUnit(unit, issecure())
  if not plate then record("plate", false, "nameplate missing or forbidden") return end
  if plate.IsForbidden and plate:IsForbidden() then record("plate", false, "nameplate forbidden") return end
  local button = icons[plate]
  if not button then
    local ok, err = pcall(function()
      button = CreateFrame("Button", nil, plate)
      button:SetSize(18, 18)
      button.icon = button:CreateTexture(nil, "OVERLAY")
      button.icon:SetAllPoints()
      button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      button:SetScript("OnClick", function(self, mouse)
        record("click", true)
        if mouse == "RightButton" and ns.openMenu then ns.openMenu(self, self.unit)
        else ns.request(self.unit) end
      end)
    end)
    if not ok then record("plate", false, tostring(err)) return end
    icons[plate] = button
  end
  -- Left of the health bar; the plate itself if Blizzard shows names only.
  local frame = plate.UnitFrame
  local bar = frame and (frame.HealthBarsContainer or frame.healthBar)
  button:ClearAllPoints()
  if bar and bar:IsShown() then
    button:SetPoint("RIGHT", bar, "LEFT", -3, 0)
  else
    button:SetPoint("RIGHT", plate, "LEFT", -3, 0)
  end
  button.unit = unit
  record("plate", true)
  return button
end

local function hideIcons(unit)
  for _, button in pairs(icons) do
    if unit == nil or button.unit == unit then button:Hide() end
  end
end

local function updateIcon(unit)
  local name, class, level = ns.identity(unit)
  local key, kind, top
  if name then key, kind, top = ns.bestBuff(name, class, level) end
  if not (key and BuffDiggerDB.icons) then return end
  local button = iconFor(unit)
  if not button then return end
  button.icon:SetTexture(C_Spell.GetSpellTexture(BUFFS[key].id))
  -- My top missing buff at full opacity, the rest (and upgrades) dimmed.
  button.icon:SetAlpha(top and 1 or 0.55)
  button:Show()
end

-- Recompute everything visible: icons and the windows. In a capital, nameplates and auras change
-- many times a second: calls within REFRESH_DELAY are merged into one recompute (#7).
local REFRESH_DELAY = 0.25
local refreshPending = false

local function refreshNow()
  refreshPending = false
  if InCombatLockdown() then return end
  hideIcons(nil)
  for _, unit in ipairs(ns.nearbyUnits()) do updateIcon(unit) end
  if ns.refreshWindow then ns.refreshWindow() end
end

function ns.refreshAll()
  if refreshPending then return end
  refreshPending = true
  C_Timer.After(REFRESH_DELAY, refreshNow)
end

-- ---------------------------------------------------------------- tooltip

local function hookTooltip()
  if not (TooltipDataProcessor and Enum.TooltipDataType) then
    record("tooltip", false, "TooltipDataProcessor missing")
    return
  end
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
    if tooltip ~= GameTooltip or InCombatLockdown() or not BuffDiggerDB.tooltip then return end
    local _, unit = tooltip:GetUnit()
    if not unit or not readable(unit) or not truthy(UnitIsPlayer(unit)) then return end
    if truthy(UnitIsUnit(unit, "player")) then return end
    local name, class, level = ns.identity(unit)
    if not name then return end
    local key, kind, top = ns.bestBuff(name, class, level)
    if not key then return end
    local buff = BUFFS[key]
    local rank = rankAt(buff, level)
    local line = L["Can probably give you: %s (rank %d, +%s %s)"]:format(
      C_Spell.GetSpellName(buff.id), rank, buff.values[rank], L[buff.stat])
    if kind == "replace" then line = line .. L[" — replaces their blessing"]
    elseif kind == "upgrade" then line = line .. L[" — higher rank than yours"]
    elseif top then line = line .. L[" — your top pick"] end
    tooltip:AddLine(line, 0.4, 0.8, 1, true)
    record("tooltip", true)
  end)
end

-- ---------------------------------------------------------------- /bd

local COMMANDS = {}

function COMMANDS.report()
  say("Report — interface " .. select(4, GetBuildInfo()) .. ", project " .. tostring(WOW_PROJECT_ID))
  for _, b in ipairs(BETS) do
    local v = verdicts[b.key]
    local state = v == nil and "|cffaaaaaa not seen yet|r" or (v.ok and "|cff55ff55YES|r" or "|cffff5555NO|r")
    print("  " .. state .. "  " .. b.label .. ((v and v.detail) and (" — " .. v.detail) or ""))
  end
  print("  Buffs received with no identifiable giver: " .. BuffDiggerDB.noSource)
  if GetCVar("nameplateShowFriends") ~= "1" then
    print("  Friendly nameplates are hidden: turn them on (Options > Nameplates) to see the icons.")
  end
end

function COMMANDS.spells()
  for key, b in pairs(BUFFS) do
    local have = mine[key]
    local state = have and (" |cff55ff55(on you, rank " .. tostring(have.rank or "?") .. ")|r") or ""
    print(("  %-9s %6d %-8s %s%s"):format(key, b.id, b.class, C_Spell.GetSpellName(b.id) or "|cffff5555missing|r", state))
  end
end

function COMMANDS.log()
  local empty = true
  for id, e in pairs(BuffDiggerDB.buffs) do
    empty = false
    local who = {}
    for class, level in pairs(e.classes) do who[#who + 1] = class .. " lvl " .. level end
    print(("  %d %s ← %s"):format(id, e.name, table.concat(who, ", ")))
  end
  if empty then say(L["No buff received from another player yet."]) end
end

function COMMANDS.ask() ns.request("target") end -- for a macro: /bd ask (current target)
COMMANDS.best = function() ns.askBest() end     -- for a macro: /bd best (no aiming)

-- Key Bindings menu (Bindings.xml).
BINDING_HEADER_BUFFDIGGER = "Buff Digger"
BINDING_NAME_BUFFDIGGER_BEST = L["Ask the best buff around me"]
BINDING_NAME_BUFFDIGGER_TARGET = L["Ask my target for a buff"]
BINDING_NAME_BUFFDIGGER_NEARBY = L["Show / hide the Nearby window"]
BINDING_NAME_BUFFDIGGER_GIVE = L["Show / hide the Give buffs window"]
BuffDigger = { askBest = ns.askBest, request = ns.request, toggleWindow = function() COMMANDS.nearby() end,
  toggleGive = function() COMMANDS.give() end }
function COMMANDS.config() if ns.toggleSettings then ns.toggleSettings() end end
function COMMANDS.nearby() if ns.toggleWindow then ns.toggleWindow() end end
function COMMANDS.give() if ns.toggleGive then ns.toggleGive() end end
function COMMANDS.whisper() send("Buff Digger: whisper test", "WHISPER", nil, UnitName("player")) end
function COMMANDS.say() send("Buff Digger: /say test", "SAY") end

SLASH_BUFFDIGGER1 = "/bd"
SlashCmdList.BUFFDIGGER = function(text)
  local command = COMMANDS[strtrim(text or ""):lower()] or COMMANDS.report
  command()
end

-- ---------------------------------------------------------------- events

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED") -- entering combat
frame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- leaving combat
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
frame:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
frame:RegisterEvent("CHAT_MSG_SAY")
frame:RegisterEvent("ADDON_ACTION_BLOCKED")
frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
frame:RegisterUnitEvent("UNIT_AURA", "player")

frame:SetScript("OnEvent", function(_, event, a1, a2)
  if event == "ADDON_LOADED" and a1 == ADDON_NAME then
    BuffDiggerDB = BuffDiggerDB or {}
    for k, v in pairs(ns.DEFAULTS) do
      if BuffDiggerDB[k] == nil then BuffDiggerDB[k] = v end
    end
    BuffDiggerDB.buffs = BuffDiggerDB.buffs or {}
    BuffDiggerDB.noSource = BuffDiggerDB.noSource or 0
    BuffDiggerDB.prefs = BuffDiggerDB.prefs or {}
    BuffDiggerDB.asked = BuffDiggerDB.asked or {}
    for name, at in pairs(BuffDiggerDB.asked) do -- forget requests older than an hour
      if time() - at > 3600 then BuffDiggerDB.asked[name] = nil end
    end
    hookTooltip()
    if ns.buildUI then ns.buildUI() end
  elseif event == "PLAYER_ENTERING_WORLD" then
    ready = false
    readMyBuffs()
  elseif event == "PLAYER_REGEN_DISABLED" then
    -- Hiding frames that hold protected buttons is still allowed during this very event.
    hideIcons(nil)
    if ns.onCombat then ns.onCombat(true) end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if ns.onCombat then ns.onCombat(false) end
    ns.refreshAll()
  elseif event == "NAME_PLATE_UNIT_ADDED" then
    shownPlates[a1] = true
    ns.refreshAll()
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    shownPlates[a1] = nil
    ns.refreshAll()
  elseif event == "UNIT_AURA" then
    readMyBuffs() -- buffs received in combat are still recorded and thanked
    ns.refreshAll()
  elseif event == "CHAT_MSG_WHISPER_INFORM" then
    record("whisper", true, "message sent to " .. show(a2))
  elseif event == "CHAT_MSG_SAY" then
    if readable(a1) and readable(a2) and a2 == UnitName("player") then record("say", true) end
  elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
    if a1 == ADDON_NAME then
      say("|cffff5555Blizzard blocked|r " .. tostring(a2))
      if tostring(a2):find("SendChatMessage") then record("say", false, "blocked: " .. tostring(a2)) end
    end
  end
end)
