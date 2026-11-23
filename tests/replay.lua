-- Replays a journal (dev/BuffDiggerJournal, raw events v2, #27) through Buff Digger under the fake API,
-- and checks invariants after each event. tests/run_smoke.py runs it once per tests/fixtures/*.lua, in a
-- fresh Lua, with DIR (repo root) and FIXTURE (the file) set. A fixture is a SavedVariables file:
-- BuffDiggerJournalDB = { events = { { t = GetTime(), ev = "...", ... }, ... } }.
--   I1  no new Thank line without a readable pose of a Data.lua buff from that giver in the 3 s before
--       (addedAuras, or updatedAuraInstanceIDs of an aura of theirs), or an open request it honors;
--   I2  a fight without a readable addedAuras adds no Thank line (except an open request honored);
--   I3  no Lua error.
-- What the journal can't give is approximated: the player's clicks come from its STATE events (a new
-- request; a line gone from toThank = Thank clicked, even if it was dismissed or ran out), and an updated
-- aura keeps its old end time. One fixture = one client session: exactly one SESSION, no /reload (split
-- the journal there); the auras I already had come from the PLAYER_ENTERING_WORLD snapshot (journals
-- from before that snapshot existed: auras held at the start look like gifts, cut them out).
dofile(DIR .. "tests/fakewow.lua")
reset(); wipe(units) -- only the players the journal names
dofile(FIXTURE)
local events = assert(BuffDiggerJournalDB and BuffDiggerJournalDB.events, FIXTURE .. ": no events")
local fixture = FIXTURE:match("[^/\\]+$")

-- A saved value back to what the game gave: "<secret>" -> SECRET, { err = msg } -> a function raising it.
local function de(v)
  if v == "<secret>" or v == "<locked>" then return SECRET end
  if v == "inf" then return math.huge end
  if v == "nan" or v == "-nan" then return 0 / 0 end
  if type(v) ~= "table" then return v end
  if v.err ~= nil and next(v, next(v)) == nil then return function() error(v.err, 0) end end
  local t = {}
  for k, x in pairs(v) do t[k] = de(x) end
  return t
end
local function plain(v) return type(v) == "string" and not v:find("^<") end

-- Spell names: the journal's own (its client's language), else Data.lua's English one.
-- ponytail: a rank ID with a localized name is unknown to Data.lua; record base IDs, or add a name table.
local spellName = {}
for _, b in pairs(ns.BUFFS) do
  spellName[b.id] = b.en
  for _, id in ipairs(b.group or {}) do spellName[id] = b.en end
end
local function learnSpell(a) if type(a) == "table" and type(a.spellId) == "number" and plain(a.name) then spellName[a.spellId] = a.name end end
for _, e in ipairs(events) do
  for _, a in ipairs(type(e.info) == "table" and type(e.info.addedAuras) == "table" and e.info.addedAuras or {}) do learnSpell(a) end
  for _, a in ipairs(e.snapshot and type(e.snapshot.auras) == "table" and e.snapshot.auras or {}) do learnSpell(a) end
end
C_Spell.GetSpellName = function(id) return spellName[id] or ("spell" .. id) end

-- Who each unit token is, as the journal saw it (a secret name stays unknown).
local function learn(list)
  for token, id in pairs(type(list) == "table" and list or {}) do
    if type(id) == "table" and plain(id.name) then
      units[token] = { plain(id.last) and id.name .. " " .. id.last or id.name, id.class, id.level }
    end
  end
end

-- How my auras read, from the last snapshot, then from each readable UNIT_AURA.
local lockdown = false
InCombatLockdown = function() return lockdown end
local function apply(snap)
  if type(snap) ~= "table" then return end
  lockdown = snap.lockdown == true
  SECRET_AURAS = snap.secret == "<secret>" and SECRET or snap.secret == true
  myAuras = {}
  for i, a in ipairs(type(snap.auras) == "table" and snap.auras or {}) do
    if a == "<nil>" then break end
    myAuras[i] = de(a)
  end
end

-- time() from GetTime(), through the session's one SESSION event: requests keep their real age.
local epoch, t0
for _, e in ipairs(events) do
  if e.ev == "SESSION" then
    assert(not epoch, fixture .. ": two SESSION events (a /reload or a restart): split the journal there")
    epoch, t0 = e.time, e.t
  end
end
assert(type(epoch) == "number", fixture .. ": no SESSION event (cut by the ring?): time() can't be rebuilt")
time = function() return math.floor(epoch + NOW - t0) end

local live = {}          -- giver -> t of the last readable pose of a Data.lua buff from them (I1)
local combat             -- { before = name -> at, added = bool } during a fight (I2)
local recordedThanks = {} -- names in the journal's last toThank (a name gone = Thank clicked)

local function pose(e, a)
  if type(a) ~= "table" or not plain(a.sourceUnit) or not ns.buffKeyOf(a.name) then return end
  local giver = ns.unitName(a.sourceUnit)
  if giver then live[giver] = e.t end
end

local function step(e)
  NOW = e.t
  learn(e.units)
  local ev = e.ev
  if ev ~= "UNIT_AURA" then apply(e.snapshot) end
  if ev == "STATE" then
    local s = e.state or {}
    for who, r in pairs(type(s.asked) == "table" and s.asked or {}) do
      local mine = BuffDiggerCharDB.asked[who]
      if type(r) == "table" and not (type(mine) == "table" and mine.at == r.at) then BuffDiggerCharDB.asked[who] = de(r)
      elseif type(r) == "table" and r.thanked then mine.thanked = true end
    end
    local now = {}
    for _, x in ipairs(type(s.toThank) == "table" and s.toThank or {}) do now[x.name] = true end
    for who in pairs(recordedThanks) do if not now[who] then ns.thankBuffer(who) end end
    recordedThanks = now
  elseif ev == "UNIT_AURA" then
    if e.unit ~= "player" then return end
    local info = de(e.info)
    if type(info) == "table" then
      for _, id in ipairs(info.removedAuraInstanceIDs or {}) do
        for i = #myAuras, 1, -1 do
          if type(myAuras[i]) == "table" and myAuras[i].auraInstanceID == id then table.remove(myAuras, i) end
        end
      end
      for _, a in ipairs(info.addedAuras or {}) do
        myAuras[#myAuras + 1] = a
        pose(e, a)
        if combat then combat.added = true end
      end
      for _, id in ipairs(info.updatedAuraInstanceIDs or {}) do
        for _, a in ipairs(myAuras) do if type(a) == "table" and a.auraInstanceID == id then pose(e, a) end end
      end
    end
    fire(ev, e.unit, info)
  elseif ev == "PLAYER_REGEN_DISABLED" or ev == "PLAYER_REGEN_ENABLED" or ev == "ADDON_RESTRICTION_STATE_CHANGED" then
    fire(ev, de(e.type), de(e.state))
  elseif ev == "GROUP_ROSTER_UPDATE" then
    for token in pairs(units) do
      if token:find("^party") or token:find("^raid") then units[token] = nil end
    end
    learn(e.units)
    fire(ev)
  elseif ev == "PLAYER_ENTERING_WORLD" then
    fire(ev, e.login, e.reload)
  elseif ev == "NAME_PLATE_UNIT_ADDED" then
    fire(ev, e.unit)
  elseif ev == "NAME_PLATE_UNIT_REMOVED" then
    fire(ev, e.unit)
    units[e.unit] = nil
  end
  runTimers() -- C_Timer.After runs before the next event, whatever its delay
end

local function fail(e, inv, msg)
  error(("%s, t=%s (%s): %s: %s"):format(fixture, tostring(e.t), tostring(e.ev), inv, msg), 0)
end

local function thanks()
  local at = {}
  for _, x in ipairs(BuffDigger.debugState().toThank) do at[x.name] = x end
  return at
end

local first = events[1] or {}
NOW = first.t or NOW
for _, e in ipairs(events) do -- who I am, before the addon loads
  if type(e.units) == "table" and e.units.player then learn({ player = e.units.player }) break end
end
fire("ADDON_LOADED", "BuffDigger"); fire("PLAYER_LOGIN"); runTimers()
local before = thanks()
for i, e in ipairs(events) do
  if i > 1 and e.t < events[i - 1].t then fail(e, "order", "time goes backwards (a restart?): split the journal there") end
  local ok, err = pcall(step, e)
  if not ok then fail(e, "I3 Lua error", tostring(err)) end
  local after = thanks()
  for name, x in pairs(after) do
    local new = not before[name] or before[name].at ~= x.at
    if new and (not x.request or x.request.gift) and not (live[name] and e.t - live[name] <= 3) then
      fail(e, "I1 Thank line without a pose seen live or an open request", name)
    end
  end
  if e.ev == "PLAYER_REGEN_DISABLED" then
    combat = { before = after, added = false }
  elseif e.ev == "PLAYER_REGEN_ENABLED" and combat then
    for name, x in pairs(after) do
      local was = combat.before[name]
      if not combat.added and (not x.request or x.request.gift) and not (was and was.at == x.at) then
        fail(e, "I2 a fight without a pose changed toThank", name)
      end
    end
    combat = nil
  end
  before = after
end
print(("replay %s: %d events, ok"):format(fixture, #events))
