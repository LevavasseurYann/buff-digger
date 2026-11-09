-- Buff Digger: core logic.
-- Shows which nearby players can probably buff you, and asks them in one click. Out of combat only.
-- The chat stays quiet: diagnostics ("bets", see docs/ideas/demande-de-buffs.md) only print when
-- "Debug messages" is ticked in the settings; /bd always prints the full report.

local ADDON_NAME, ns = ...
local isSecret = issecretvalue or function() return false end
local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
local BUFFS, rankAt, L = ns.BUFFS, ns.rankAt, ns.L

-- Chat stays for what the player typed (/bd ...) and for debug. Everything else is discreet:
-- the answer to a click goes to the yellow text mid-screen (like "Out of range"), which fades;
-- what happens on its own (thanks waiting, Blizzard blocks...) only shows with "Debug messages".
local function say(...) print("|cff66ccff[Buff Digger]|r", ...) end
ns.say = say
local function notice(text)
  if UIErrorsFrame then UIErrorsFrame:AddMessage(text, 1, 0.82, 0) else say(text) end
end
ns.notice = notice
local function debug(...) if BuffDiggerDB and BuffDiggerDB.debug then say(...) end end
ns.debug = debug
local function readable(v) return not isSecret(v) end
-- A "secret" boolean breaks an `if`: only test what is readable.
local function truthy(v) return readable(v) and v and true or false end
ns.readable, ns.truthy = readable, truthy
local function show(v)
  if isSecret(v) then return "|cffff5555<secret>|r" end
  return tostring(v)
end

ns.DEFAULTS = {
  plates = "best",   -- nameplates: "off", "hint" (small Buff Digger icon), "best" (best buff), "all" (each buff)
  tooltip = true,    -- "Can probably give you..." line
  nearby = false,    -- "Nearby" window
  nearbyUseful = false, -- Get buffs: hide players with nothing better for me
  lockWindows = false, -- windows can't be moved or resized
  give = false,      -- "Give buffs" window (buffer classes)
  thank = true,      -- automatic /thank emote
  thankMessage = true, -- thank-you message in the request's channel once the buff lands
  useSay = false,    -- ask in /say instead of a whisper
  language = "en",   -- language of messages to other players (a key of ns.MESSAGES)
  debug = false,     -- print bet verdicts in chat
  delay = 120,       -- seconds before asking the same player again (#6)
  refreshBefore = 300, -- a buff with less than this many seconds left counts as missing (0 = never)
  acceptRequests = true, -- show silent requests from other Buff Digger users (#10)
  requests = false,  -- "Requests" window (#13)
  requestSound = true, -- a sound when a request arrives (#13)
  targetOnAsk = false, -- Get buffs: asking for a buff also targets the player (#14)
  requestMarkers = true, -- big pulsing icon above the nameplate of a Buff Digger user asking me (#15)
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
  { key = "whisper",  label = "Send a whisper (with a spell link)" },
  { key = "say",      label = "Talk in /say" },
  { key = "key",      label = "Ask with a key binding" },
  { key = "cast",     label = "Cast a buff from a Buff Digger click or key" },
  { key = "points",   label = "Read the value of my buffs (their rank)" },
  { key = "expires",  label = "Read the time left on my buffs" },
}
local verdicts = {}

local function record(key, ok, detail)
  -- First YES ever, dated and kept across sessions: /bd then doubles as the in-game test checklist (#1).
  if ok and BuffDiggerDB and BuffDiggerDB.confirmed and not BuffDiggerDB.confirmed[key] then
    BuffDiggerDB.confirmed[key] = date("%Y-%m-%d")
  end
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

-- What I currently have: key -> { rank = rank or nil if unknown, giver = name or nil, expires = GetTime()
-- at which it wears off, or nil }.
-- The rank comes from the value the buff gives (aura.points, #8), else from the giver's level when it
-- lands. Neither known (value hidden or not in Data.lua, giver unknown): unknown rank, never "upgraded".
local mine = {}
local byInstance = {} -- auraInstanceID -> { key, rank, giver, expires }
local ready = false

-- What the buff gives (+55 attack power -> 55), or nil when the game hides it.
local function auraValue(aura)
  local p = aura.points
  if not (readable(p) and type(p) == "table") then return end
  local v = p[1]
  if readable(v) and type(v) == "number" then return v end
end

-- GetTime() at which the buff wears off and its full duration, or nil (hidden, or no duration).
local function auraExpires(aura)
  local t, d = aura.expirationTime, aura.duration
  if readable(t) and readable(d) and type(t) == "number" and type(d) == "number" and t > 0 and d > 0 then
    return t, d
  end
end

-- Running out: less than BuffDiggerDB.refreshBefore seconds left, and never more than the last
-- quarter of the buff (Forever's buffs last an hour; a 10-minute Thorns must not look "running
-- out" half its life). Such a buff is asked for again.
local function expiring(have)
  local before = BuffDiggerDB and BuffDiggerDB.refreshBefore or 0
  return have.expires ~= nil and before > 0
    and have.expires - GetTime() < math.min(before, have.duration / 4)
end

-- Raw log, to check Data.lua against reality (#2): spell ID -> name, value given, giver classes.
local function logEntry(aura)
  if not readable(aura.spellId) then return end
  local entry = BuffDiggerDB.buffs[aura.spellId] or { name = aura.name, classes = {} }
  BuffDiggerDB.buffs[aura.spellId] = entry
  return entry
end

-- ---------------------------------------------------------------- thanks

-- Blizzard only lets an addon talk in /say (outside instances) during a real click or key press,
-- and maybe emotes too. Such thanks wait here and go out with the next Buff Digger click or key
-- (ns.flushThanks, called by every action). Whispers never need to wait.
-- At most one waiting thank-you per player; after PENDING_MAX seconds it is dropped (they left).
local PENDING_MAX = 120
local pendingThanks = {} -- name -> { at, fns }

local function sendLater(name, fn)
  local p = pendingThanks[name]
  if not p then
    p = { at = time(), fns = {} }
    pendingThanks[name] = p
    debug(L["Thanks to %s will go out with your next Buff Digger click or key."]:format(name))
  end
  p.fns[#p.fns + 1] = fn
end

function ns.flushThanks()
  local todo = pendingThanks
  pendingThanks = {}
  for _, p in pairs(todo) do
    if time() - p.at <= PENDING_MAX then
      for _, fn in ipairs(p.fns) do fn() end
    end
  end
end

-- Did I ask this player for a buff in the last 10 minutes? Giver unknown: only when exactly ONE
-- open request is for this very buff — with two candidates, guessing could thank the wrong one.
-- Once the buff has landed, every other open request for it is closed: nobody else gets thanked.
local function findRequest(name, key)
  local function fresh(e) return type(e) == "table" and not e.thanked and time() - e.at < 600 end
  local result, resultEntry, matches = name, nil, 0
  if name and fresh(BuffDiggerDB.asked[name]) then resultEntry = BuffDiggerDB.asked[name] end
  for n, e in pairs(BuffDiggerDB.asked) do
    if fresh(e) and key and e.key == key and e ~= resultEntry then
      matches = matches + 1
      if not name then result, resultEntry = n, e end
      if name then e.thanked = true end -- someone else gave it: close their request
    end
  end
  if not name and matches ~= 1 then
    -- Ambiguous: close them all, thank nobody.
    for _, e in pairs(BuffDiggerDB.asked) do
      if fresh(e) and key and e.key == key then e.thanked = true end
    end
    return nil
  end
  return result, resultEntry
end

-- One /thank per player per THANK_GAP seconds: a druid casting Mark then Thorns, or a paladin
-- swapping blessings, must not make me /thank them again and again.
local THANK_GAP = 60
local lastThank = {}

local function thank(name, request)
  -- A thank-you in the same channel as the request, if there was one.
  if request then request.thanked = true end -- answered: Get buffs stops offering a re-ask (#13)
  if request and BuffDiggerDB.thankMessage then
    local text = ns.thanks(BuffDiggerDB.language)
    if request.channel == "SAY" then
      sendLater(name, function() send(name .. " : " .. text, "SAY") end)
    else
      -- A second or two, like someone typing: an instant thank-you reads like a bot.
      -- (The /thank emote stays immediate: that's the reflex.)
      local target = request.target or name
      C_Timer.After(1 + math.random(), function() send(text, "WHISPER", nil, target) end) -- 1 to 2 s
    end
  end
  if BuffDiggerDB.thank and not (lastThank[name] and time() - lastThank[name] < THANK_GAP) then
    lastThank[name] = time()
    local emote = function() DoEmote("THANK", name) end
    if BuffDiggerDB.emoteNeedsClick then sendLater(name, emote) else emote() end
    record("thank", true, "/thank to " .. name)
  end
end

local function onBuffLanded(aura, info, renewed)
  local source = aura.sourceUnit
  if not readable(source) or not readable(aura.spellId) then record("source", false, "source or spell secret") return end
  local name, class, level, _
  if source then
    if truthy(UnitIsUnit(source, "player")) or not truthy(UnitIsPlayer(source)) then return end
    name = UnitName(source)
    _, class = UnitClass(source)
    level = UnitLevel(source)
    if not (readable(name) and readable(class) and readable(level)) then record("source", false, "giver secret") return end
  end
  -- A mage can't give Fortitude: the source is wrong (a stale unit token), so the giver is unknown.
  if name and info.key and BUFFS[info.key].class ~= class then
    debug("Ignored: " .. name .. " can't give " .. show(aura.name))
    name = nil
  elseif name then
    record("source", true, name .. " → " .. show(aura.name))
    info.giver = name
    -- The value read on the buff wins; the giver's level is only a guess at what they bought.
    if info.key and not info.rank then info.rank = rankAt(BUFFS[info.key], level) end

    local entry = logEntry(aura)
    local seen = entry.classes[class]
    entry.classes[class] = seen and math.min(seen, level) or level
  else
    -- A stranger outside the group does not always have a unit token: count those cases.
    BuffDiggerDB.noSource = BuffDiggerDB.noSource + 1
  end

  -- Giver unknown: if I just asked someone for this very buff, it was most likely them.
  local asked, request = findRequest(name, info.key)
  if not name and asked then name = asked; info.giver = asked end
  -- A renewal nobody asked for (a raid buffer keeping buffs up) is not thanked again and again.
  -- Only buffs from Data.lua: eating a mage's food or sitting at a table is not a buff to thank.
  if name and info.key and (request or not renewed) then thank(name, request) end
end

local function readMyBuffs()
  local seen = {}
  -- A shapeshift (Ghost Wolf...) can hand every aura a new instance ID: a known buff ending at the
  -- same time is the one I already had, not a new landing to thank.
  local had = {}
  for _, info in pairs(byInstance) do if info.key then had[info.key] = info end end
  for i = 1, 40 do
    local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
    if not ok or not aura then break end
    local id = aura.auraInstanceID
    if readable(id) and readable(aura.name) then
      local info = byInstance[id]
      local expires, duration = auraExpires(aura)
      local old = not info and had[buffKeyOf(aura.name) or false]
      local same = old and old.expires and expires and math.abs(old.expires - expires) < 2
      -- Same aura with a later end: someone refreshed it. That counts as a new landing (thanks).
      local renewed = info and info.expires and expires and expires > info.expires + 60
      if not info or renewed then
        local oldRank = info and info.rank
        info = info or { key = buffKeyOf(aura.name) }
        if info.key then
          local value = auraValue(aura)
          record("points", value ~= nil, value and (aura.name .. " = " .. value) or "value hidden")
          if expires then record("expires", true) else record("expires", false, "time left hidden") end
          info.rank = value and ns.rankOfValue(BUFFS[info.key], value)
          local entry = value and logEntry(aura)
          if entry then entry.value = value end
        end
        local oldGiver = info.giver or (same and old.giver)
        info.giver = nil
        if ready and not same then onBuffLanded(aura, info, renewed) end
        info.giver = info.giver or oldGiver -- renewal by a hidden giver: keep the one we knew
        info.rank = info.rank or oldRank -- nothing better known: keep what we had
      end
      info.expires, info.duration = expires, duration
      seen[id] = info
    end
  end
  byInstance, ready = seen, true -- the first pass thanks nobody
  mine = {}
  for _, info in pairs(byInstance) do
    if info.key then
      mine[info.key] = { rank = info.rank, giver = info.giver, expires = info.expires, duration = info.duration }
    end
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
-- kind: "new" (I lack it), "refresh" (mine is running out), "replace" (this paladin swaps his
--       blessing for one I value more), "upgrade" (same buff, higher rank than mine).
-- 1. Buffs I lack or that are running out, in my preference order (a refresh never lowers the rank).
--    A paladin who already blessed me only counts if the new blessing ranks higher than his current
--    one (his old one disappears); his blessing that is running out no longer holds him back.
-- 2. Otherwise, a higher rank of a buff I already have — never from a paladin who already
--    blessed me (it would replace his other blessing), never when my rank is unknown.
function ns.bestBuff(name, class, level)
  local _, myClass = UnitClass("player")
  local prefs = ns.prefsFor(myClass)
  local hisBlessing = ns.hisBlessing(name)
  if hisBlessing and expiring(mine[hisBlessing]) then hisBlessing = nil end

  local missingSeen = 0
  for i, key in ipairs(prefs) do
    local buff, have = BUFFS[key], mine[key]
    if not have or expiring(have) then
      missingSeen = missingSeen + 1
      -- A refresh must be at least the rank I have; rank unknown: no refresh (it could lower it).
      -- A new buff: any rank.
      local need = have and (have.rank or math.huge) or 1
      if buff.class == class and rankAt(buff, level) >= need then
        if not hisBlessing then return key, have and "refresh" or "new", missingSeen == 1 end
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
  local e = BuffDiggerDB.asked[name]
  local ago = type(e) == "table" and (time() - e.at)
  if ago and ago < BuffDiggerDB.delay then return ago end
end

-- What kind of request is asking `name` for `key`, when the player chose the buff themselves?
-- Same rules as ns.bestBuff: "upgrade" only when my rank is known and theirs is higher.
local function kindFor(name, key, level)
  local have = mine[key]
  if have then
    if expiring(have) then return "refresh" end
    return (have.rank and rankAt(BUFFS[key], level) > have.rank) and "upgrade" or "new"
  end
  local his = ns.hisBlessing(name)
  if his and his ~= key and BUFFS[key].class == "PALADIN" then return "replace" end
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

-- The blessing this paladin put on me, if any: he has one per target, a new one replaces it.
function ns.hisBlessing(name)
  for key, have in pairs(mine) do
    if have.giver == name and BUFFS[key].class == "PALADIN" then return key end
  end
end

-- Ask `unit` for a buff: the best one, or `chosenKey` when the player picked it (#4).
function ns.request(unit, chosenKey)
  if InCombatLockdown() then return end
  ns.flushThanks()
  if not unit or not truthy(UnitExists(unit)) then notice(L["No player targeted."]) return end
  local name, class, level, realm = ns.identity(unit)
  if not name then return end
  local key, kind
  if chosenKey then
    key, kind = chosenKey, kindFor(name, chosenKey, level)
  else
    key, kind = ns.bestBuff(name, class, level)
  end
  if not key then notice(L["%s has nothing better for you right now."]:format(name)) return end
  -- A silent request that brought nothing: this click re-asks them by whisper (#13).
  local reask = ns.unanswered(name)
  local ago = not reask and ns.askedAgo(name)
  if ago then
    notice(L["Already asked %s %d s ago, give them a moment."]:format(name, ago))
    return
  end
  local text = ns.message(kind, key, BuffDiggerDB.language)
  -- Shift or Ctrl held: the other channel than the default one (whisper <-> /say).
  local useSay = not reask and BuffDiggerDB.useSay ~= (IsShiftKeyDown() or IsControlKeyDown() or false)
  local target = (realm and realm ~= "") and (name .. "-" .. realm) or name
  -- Comm.lua delivers it: silently to another Buff Digger user, in chat otherwise (#10).
  local channel, silent = ns.deliver(name, target, key, text, useSay, kind, reask)
  BuffDiggerDB.asked[name] = { at = time(), key = key, channel = channel, target = target, silent = silent }
end

-- One key press, no aiming: among the players around me, ask the one who can give the buff I
-- want most (missing buffs before replacements before upgrades), skipping anyone asked recently.
-- A key press counts as a real input, so /say works from here too.
function ns.askBest()
  if InCombatLockdown() then return end
  ns.flushThanks()
  local _, myClass = UnitClass("player")
  local prefs = ns.prefsFor(myClass)
  local KIND_ORDER = { new = 0, refresh = 1, replace = 2, upgrade = 3 }
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
  if bestUnit then ns.request(bestUnit) else notice(L["Nobody around can give you anything better right now."]) end
end

-- ---------------------------------------------------------------- friendly nameplates

-- Icons, Get buffs, Give buffs and Requests all find players through friendly nameplates: WoW gives
-- addons no other list of the players around you. One click (or /bd nameplates) turns them on.
local getCVar = (C_CVar and C_CVar.GetCVar) or GetCVar
local setCVar = (C_CVar and C_CVar.SetCVar) or SetCVar

function ns.friendlyPlatesOn() return getCVar("nameplateShowFriends") == "1" end

function ns.turnOnFriendlyPlates()
  if InCombatLockdown() then notice(L["Can't change that in combat."]) return end
  setCVar("nameplateShowFriends", "1")
  notice(L["Friendly nameplates are on."])
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

local icons = {} -- nameplate -> our buttons, 1 = next to the bar; Blizzard's frames are never modified

-- The i-th icon of that player's nameplate; button.key = the buff it asks for (nil = the best one).
local function iconFor(unit, i)
  local plate = C_NamePlate.GetNamePlateForUnit(unit, issecure())
  if not plate then record("plate", false, "nameplate missing or forbidden") return end
  if plate.IsForbidden and plate:IsForbidden() then record("plate", false, "nameplate forbidden") return end
  icons[plate] = icons[plate] or {}
  local button = icons[plate][i]
  if not button then
    local ok, err = pcall(function()
      button = CreateFrame("Button", nil, plate)
      button:SetSize(18, 18)
      button.icon = button:CreateTexture(nil, "OVERLAY")
      button.icon:SetAllPoints()
      -- Small star: this player has Buff Digger too (#10).
      button.peer = button:CreateTexture(nil, "OVERLAY", nil, 2)
      button.peer:SetSize(10, 10)
      button.peer:SetPoint("TOPRIGHT", 4, 4)
      button.peer:SetTexture("Interface\\COMMON\\FavoritesIcon")
      button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      button:SetScript("OnClick", function(self, mouse)
        record("click", true)
        if mouse == "RightButton" and ns.openMenu then ns.openMenu(self, self.unit)
        else ns.request(self.unit, self.key) end
      end)
      button:SetScript("OnEnter", function(self) if ns.buffTooltip then ns.buffTooltip(self, self.unit, self.shows) end end)
      button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end)
    if not ok then record("plate", false, tostring(err)) return end
    icons[plate][i] = button
  end
  -- Left of the health bar (the plate itself if Blizzard shows names only), the next ones further left.
  local frame = plate.UnitFrame
  local bar = frame and (frame.HealthBarsContainer or frame.healthBar)
  button:ClearAllPoints()
  if i > 1 then
    button:SetPoint("RIGHT", icons[plate][i - 1], "LEFT", -2, 0)
  elseif bar and bar:IsShown() then
    button:SetPoint("RIGHT", bar, "LEFT", -3, 0)
  else
    button:SetPoint("RIGHT", plate, "LEFT", -3, 0)
  end
  button.unit = unit
  record("plate", true)
  return button
end

local function hideIcons(unit)
  for _, buttons in pairs(icons) do
    for _, button in ipairs(buttons) do
      if unit == nil or button.unit == unit then button:Hide() end
    end
  end
end

local function updateIcon(unit)
  local name, class, level = ns.identity(unit)
  local key = name and ns.bestBuff(name, class, level)
  local his = name and ns.hisBlessing(name)
  local mode = BuffDiggerDB.plates
  if mode == "off" or not name then return end
  -- "all": every buff they can give, I pick (my priorities left to right).
  -- "best": that choice only. "hint": a small Buff Digger icon saying "this one can buff you".
  local keys = mode == "all" and ns.offers(class, level) or { key }
  for i, k in ipairs(keys) do
    local button = iconFor(unit, i)
    if not button then return end
    button.key = mode == "all" and k or nil
    button.shows = k
    if mode == "hint" then
      button:SetSize(12, 12)
      button.icon:SetTexture("Interface\\AddOns\\BuffDigger\\Media\\icon")
      ns.styleBuff(button)
      button.icon:SetAlpha(0.8)
    else
      button:SetSize(18, 18)
      button.icon:SetTexture(C_Spell.GetSpellTexture(BUFFS[k].id))
      ns.styleBuff(button, k, key, his)
    end
    button.peer:SetShown(i == 1 and mode ~= "hint" and ns.isPeer(name))
    button:Show()
  end
end

-- Request markers (#15): a Buff Digger user asked me for a buff, so a big pulsing icon of that
-- buff floats above their nameplate. Visual only, seen by me alone (not a raid marker).
-- Follows the incoming requests of Comm.lua, which calls ns.refreshMarkers whenever they change.
local markers = {} -- nameplate -> our marker frame, one per player

local function markerFor(unit)
  local plate = C_NamePlate.GetNamePlateForUnit(unit, issecure())
  if not plate or (plate.IsForbidden and plate:IsForbidden()) then return end
  local m = markers[plate]
  if not m then
    m = CreateFrame("Frame", nil, plate) -- no mouse: never steals a click from the plate
    m:SetSize(32, 32)
    m:SetPoint("BOTTOM", plate, "TOP", 0, 2)
    m.icon = m:CreateTexture(nil, "ARTWORK")
    m.icon:SetAllPoints()
    m.glow = m:CreateTexture(nil, "OVERLAY")
    m.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    m.glow:SetBlendMode("ADD")
    m.glow:SetSize(58, 58)
    m.glow:SetPoint("CENTER")
    m.pulse = m.glow:CreateAnimationGroup()
    local fade = m.pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.2)
    fade:SetDuration(0.8)
    m.pulse:SetLooping("BOUNCE")
    markers[plate] = m
  end
  return m
end

-- requests: { key, unit } (unit = their nameplate token, nil when out of sight).
function ns.refreshMarkers(requests)
  local kept = {}
  if BuffDiggerDB.requestMarkers and not InCombatLockdown() then
    for _, req in ipairs(requests) do
      local m = req.unit and BUFFS[req.key] and markerFor(req.unit)
      if m then
        kept[m] = true
        m.unit = req.unit
        m.icon:SetTexture(C_Spell.GetSpellTexture(BUFFS[req.key].id))
        m:Show()
        if not m.pulse:IsPlaying() then m.pulse:Play() end -- hiding a frame stops its animations
      end
    end
  end
  -- Only the unwanted ones are hidden: hiding a kept one would restart its pulse every refresh.
  for _, m in pairs(markers) do if not kept[m] then m:Hide() m.unit = nil end end
end

-- A buff icon (nameplate or Get buffs), fully opaque: buffs I already have are grey, like spells you
-- can't use (not when it's Buff Digger's pick: a refresh or a higher rank). Order says the rest.
-- `his`: the blessing this paladin already put on me, framed in gold: asking him for another one
-- would replace it (the tooltip says so on his other blessings).
function ns.styleBuff(button, k, best, his)
  button.icon:SetAlpha(1)
  button.icon:SetDesaturated(k ~= nil and k ~= best and ns.haveBuff(k))
  if not button.his then
    button.his = button:CreateTexture(nil, "BACKGROUND")
    button.his:SetPoint("TOPLEFT", -2, 2)
    button.his:SetPoint("BOTTOMRIGHT", 2, -2)
    button.his:SetColorTexture(1, 0.82, 0) -- gold, like a quest reward border
  end
  button.his:SetShown(k ~= nil and k == his)
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
  if ns.refreshIncoming then ns.refreshIncoming() end
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
    elseif kind == "refresh" then line = line .. L[" — yours is running out"]
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
    local v, since = verdicts[b.key], BuffDiggerDB.confirmed[b.key]
    local state = v == nil and "|cffaaaaaa not seen yet|r" or (v.ok and "|cff55ff55YES|r" or "|cffff5555NO|r")
    print("  " .. state .. "  " .. b.label .. ((v and v.detail) and (" — " .. v.detail) or "")
      .. (since and (" |cff888888(confirmed " .. since .. ")|r") or ""))
  end
  print("  Buffs received with no identifiable giver: " .. BuffDiggerDB.noSource)
  if not ns.friendlyPlatesOn() then
    print("  Friendly nameplates are off: /bd nameplates turns them on.")
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
    -- #2: is the value this spell really gives one of Data.lua's values for that buff?
    local key, check = buffKeyOf(e.name), ""
    if key and e.value then
      local rank = ns.rankOfValue(BUFFS[key], e.value)
      check = rank and ("  +" .. e.value .. " = rank " .. rank)
        or ("  |cffff5555+" .. e.value .. " not in Data.lua|r")
    end
    print(("  %d %s%s ← %s"):format(id, e.name, check, #who > 0 and table.concat(who, ", ") or "?"))
  end
  if empty then say(L["No buff received from another player yet."]) end
end

function COMMANDS.ask() ns.request("target") end -- for a macro: /bd ask (current target)
COMMANDS.best = function() ns.askBest() end     -- for a macro: /bd best (no aiming)

-- Key Bindings menu (Bindings.xml).
BINDING_HEADER_BUFFDIGGER = "Buff Digger"
BINDING_NAME_BUFFDIGGER_BEST = L["Ask the best buff around me"]
BINDING_NAME_BUFFDIGGER_TARGET = L["Ask my target for a buff"]
BINDING_NAME_BUFFDIGGER_NEARBY = L["Show / hide the Get buffs window"]
BINDING_NAME_BUFFDIGGER_GIVE = L["Show / hide the Give buffs window"]
BuffDigger = {
  askBest = function() record("key", true) ns.askBest() end,
  request = function(unit) record("key", true) ns.request(unit) end,
  toggleWindow = function() COMMANDS.get() end,
  toggleGive = function() COMMANDS.give() end,
}
_G["BINDING_NAME_CLICK BuffDiggerGiveNext:LeftButton"] = L["Give my buff to the next player around"]
function COMMANDS.config() if ns.toggleSettings then ns.toggleSettings() end end
function COMMANDS.get() if ns.toggleWindow then ns.toggleWindow() end end
COMMANDS.nearby = COMMANDS.get -- its name before 0.4.0
function COMMANDS.give() if ns.toggleGive then ns.toggleGive() end end
function COMMANDS.requests() if ns.toggleRequests then ns.toggleRequests() end end
function COMMANDS.whisper() send("Buff Digger: whisper test", "WHISPER", nil, UnitName("player")) end
function COMMANDS.say() send("Buff Digger: /say test", "SAY") end
function COMMANDS.selftest() if ns.selfTest then ns.selfTest() end end -- see the Requests window alone
function COMMANDS.nameplates() ns.turnOnFriendlyPlates() end

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
frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
frame:RegisterEvent("UI_ERROR_MESSAGE")

-- Secure cast buttons (Give buffs, next-player key, Requests): did a click really send a spell?
-- Only a cast sent DURING the click counts (between PreClick and PostClick), so a spell cast by
-- hand right after a failed click is never taken for a success. With "Debug messages", every
-- click prints what the button held and what came of it.
local clicking, sentDuringClick = false, nil

-- Aim a secure button at a player: a click casts `spell` on them. Seen in game (2026-11-08): with
-- type=spell and unit=nameplateN the click sends nothing, no error. So it goes through a macro, the
-- classic buff-addon way: target them by name, cast, give the previous target back.
-- [help,nodead]: if they left and the targeting failed, never buff whoever is targeted instead.
-- ponytail: with no target before, the buffed player stays targeted (/targetlasttarget has nothing).
-- The name for /target; nil when the game hides it. In game (2026-11-09) /targetexact did nothing,
-- with or without the realm, while /target Name (no realm) targeted a player from another realm.
-- ponytail: /target falls back to a partial match ("Mista" -> "Mistake") when the player is gone;
-- same with two players of the same name from different realms nearby. Check UnitName("target")
-- in PostClick if that ever bites.
local function targetName(unit)
  local name = UnitName(unit)
  return readable(name) and name or nil
end

function ns.castMacro(unit, spell)
  local macro
  if unit == "player" and spell then
    macro = "/cast [@player] " .. spell -- /bd selftest
  elseif unit and spell then
    local who = targetName(unit)
    if who then macro = ("/target %s\n/cast [help,nodead] %s\n/targetlasttarget"):format(who, spell) end
  end
  return macro
end

-- A left click on this secure button targets `unit` (Get buffs, #14); nil = the click targets nobody.
-- "*type1": any modifier, so Shift/Ctrl-click (the other channel) still targets.
function ns.aimTarget(button, unit)
  local who = unit and targetName(unit)
  button:SetAttribute("*type1", who and "macro" or nil)
  button:SetAttribute("macrotext", who and "/target " .. who or nil)
end

function ns.aimCast(button, unit, spell)
  local macro = ns.castMacro(unit, spell)
  button:SetAttribute("type", macro and "macro" or nil)
  button:SetAttribute("macrotext", macro)
end

-- Clicks a secure button listens to: release only, and act on release whatever the player's
-- ActionButtonUseKeyDown. Registering down clicks too (with ActionButtonUseKeyDown=1) left Get
-- buffs dead; a test button with exactly this setup ran its macro (seen in game 2026-11-09).
function ns.secureClicks(button)
  button:SetAttribute("useOnKeyDown", false)
  button:RegisterForClicks("AnyUp")
end

function ns.watchClick(button)
  button:HookScript("PreClick", function() clicking = true end)
  button:HookScript("PostClick", function(self, mouse, down)
    clicking = false
    if down then return end -- release only (secureClicks); kept as a guard
    local macro = self:GetAttribute("macrotext")
    debug(("Click %s: type=%s macro=%s keydown=%s -> %s"):format(tostring(mouse),
      tostring(self:GetAttribute("type")), macro and macro:gsub("\n", " | ") or "nil",
      tostring(getCVar("ActionButtonUseKeyDown")), sentDuringClick or "|cffff5555nothing sent|r"))
    if sentDuringClick then record("cast", true, sentDuringClick) end
    sentDuringClick = nil
  end)
end

frame:SetScript("OnEvent", function(_, event, a1, a2, a3, a4)
  if event == "ADDON_LOADED" and a1 == ADDON_NAME then
    BuffDiggerDB = BuffDiggerDB or {}
    -- Older versions only had a "write in French" checkbox: keep that choice.
    if BuffDiggerDB.frenchMessages and BuffDiggerDB.language == nil then BuffDiggerDB.language = "fr" end
    BuffDiggerDB.frenchMessages = nil
    -- Up to 0.4.0, nameplate icons were a checkbox: unticked means "off".
    if BuffDiggerDB.icons == false and BuffDiggerDB.plates == nil then BuffDiggerDB.plates = "off" end
    BuffDiggerDB.icons = nil
    for k, v in pairs(ns.DEFAULTS) do
      if BuffDiggerDB[k] == nil then BuffDiggerDB[k] = v end
    end
    BuffDiggerDB.buffs = BuffDiggerDB.buffs or {}
    BuffDiggerDB.noSource = BuffDiggerDB.noSource or 0
    BuffDiggerDB.prefs = BuffDiggerDB.prefs or {}
    BuffDiggerDB.asked = BuffDiggerDB.asked or {}
    BuffDiggerDB.peers = BuffDiggerDB.peers or {} -- name -> last time they answered (#10)
    BuffDiggerDB.confirmed = BuffDiggerDB.confirmed or {} -- bet key -> date of the first YES (#1)
    for name, e in pairs(BuffDiggerDB.asked) do -- forget requests older than an hour (or old format)
      if type(e) ~= "table" or time() - e.at > 3600 then BuffDiggerDB.asked[name] = nil end
    end
    hookTooltip()
    if ns.buildUI then ns.buildUI() end
    -- Buffs run out without any event: look again every 30 s (refreshAll is cheap and batched).
    C_Timer.NewTicker(30, ns.refreshAll)
  elseif event == "PLAYER_ENTERING_WORLD" then
    ready = false
    readMyBuffs()
    -- One line at login, only while they're off: without them most of the addon sees nobody.
    if a1 and not ns.friendlyPlatesOn() then
      say(L["Friendly nameplates are off, so icons and windows can't see anyone. Type /bd nameplates to turn them on."])
    end
  elseif event == "PLAYER_REGEN_DISABLED" then
    -- Hiding frames that hold protected buttons is still allowed during this very event.
    hideIcons(nil)
    ns.refreshMarkers({}) -- plates change hands in combat while nothing refreshes
    if ns.onCombat then ns.onCombat(true) end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if ns.onCombat then ns.onCombat(false) end
    ns.refreshAll()
  elseif event == "NAME_PLATE_UNIT_ADDED" then
    shownPlates[a1] = true
    ns.refreshAll()
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    shownPlates[a1] = nil
    for _, m in pairs(markers) do if m.unit == a1 then m:Hide() end end -- before the plate serves someone else
    ns.refreshAll()
  elseif event == "UNIT_AURA" then
    readMyBuffs() -- buffs received in combat are still recorded and thanked
    ns.refreshAll()
  elseif event == "UNIT_SPELLCAST_SENT" then
    -- a2 = target name, a4 = spell ID
    local spell = readable(a4) and a4 and C_Spell.GetSpellName(a4)
    if clicking and spell then sentDuringClick = spell .. " -> " .. show(a2) end
    if spell and readable(a2) then ns.onSpellSent(a2) end
    debug("Spell sent: " .. show(spell) .. " on " .. show(a2) .. (clicking and " (during a click)" or ""))
  elseif event == "UI_ERROR_MESSAGE" then
    debug("Game error: " .. show(a2))
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    ns.refreshAll() -- the player I just buffed leaves Give buffs
  elseif event == "CHAT_MSG_WHISPER_INFORM" then
    record("whisper", true, "message sent to " .. show(a2))
  elseif event == "CHAT_MSG_SAY" then
    if readable(a1) and readable(a2) and a2 == UnitName("player") then record("say", true) end
  elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
    if a1 == ADDON_NAME then
      debug("|cffff5555Blizzard blocked|r " .. tostring(a2)) -- also in the /bd report
      if tostring(a2):find("SendChatMessage") then record("say", false, "blocked: " .. tostring(a2)) end
      -- The emote needs a real click here: from now on, /thank waits for the next Buff Digger action.
      if tostring(a2):find("DoEmote") then BuffDiggerDB.emoteNeedsClick = true end
    end
  end
end)
