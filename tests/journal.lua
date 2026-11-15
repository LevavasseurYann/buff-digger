-- The dev journal (dev/BuffDiggerJournal/Journal.lua) under a tiny fake API: it loads, its raw events
-- (#27) survive a SavedVariables round trip (dofile), and the ring stays bounded.
-- Run from the repo root: uv run --no-project -q --with lupa python -I tests/run_smoke.py
local handlers, tickers = {}, {}
local function frame()
  return setmetatable({}, { __index = function(_, k)
    if k == "SetScript" then return function(_, _, fn) handlers[#handlers + 1] = fn end end
    return function() end
  end })
end
CreateFrame = function() return frame() end
SECRET, LOCKED = newproxy(), {} -- a userdata: the writer below refuses it if one slips through
issecretvalue = function(v) return v == SECRET end
canaccesstable = function(t) return t ~= LOCKED end
NOW = 100; GetTime = function() return NOW end; time = os.time; date = os.date
GetBuildInfo = function() return "1.60.1", 1, "", 16001 end
UnitName = function(u) if u == "nameplate1" then return SECRET end return "Yann" end
UnitClass = function() return "Warrior", "WARRIOR" end; UnitLevel = function() return 21 end
IsInRaid = function() return false end; GetNumSubgroupMembers = function() return 1 end
InCombatLockdown = function() return true end
C_Secrets = { ShouldAurasBeSecret = function() return true end }
C_RestrictedActions = { GetAddOnRestrictionState = function(t) if t == 1 then error("boom") end return 2 end }
Enum = { AddOnRestrictionType = { Combat = 0, Encounter = 1 } }
C_UnitAuras = { GetAuraDataByIndex = function(_, i) if i == 1 then return { auraInstanceID = 7, spellId = 1243, points = { 10 } } end error("secret aura") end }
C_Timer = { NewTicker = function(_, fn) tickers[#tickers + 1] = fn end, After = function() end }
SlashCmdList = {}; wipe = function(t) for k in pairs(t) do t[k] = nil end end
_G.BuffDigger = { debugState = function() return { toThank = { { name = "Arthas", at = 1 } }, mine = {}, asked = {} } end }

assert(loadfile(DIR .. "dev/BuffDiggerJournal/Journal.lua"))("BuffDiggerJournal", {})
local function fire(...) for _, fn in ipairs(handlers) do fn(nil, ...) end end
fire("ADDON_LOADED", "BuffDiggerJournal")
fire("PLAYER_LOGIN")
for _, fn in ipairs(tickers) do fn() end
fire("UNIT_AURA", "player", { addedAuras = { { auraInstanceID = 7, sourceUnit = "nameplate1", name = SECRET, points = LOCKED } },
  removedAuraInstanceIDs = { 3 }, weird = setmetatable({}, { __pairs = nil, __index = function() error("x") end }) })
fire("UNIT_AURA", "player", SECRET)
fire("PLAYER_REGEN_DISABLED")
fire("NAME_PLATE_UNIT_ADDED", "nameplate1")

-- WoW's SavedVariables writer, near enough: plain values, nested tables, string or number keys.
local function write(v, out)
  local t = type(v)
  if t == "string" then out[#out + 1] = string.format("%q", v)
  elseif t == "number" or t == "boolean" then out[#out + 1] = tostring(v)
  elseif t == "table" then
    out[#out + 1] = "{"
    for k, x in pairs(v) do
      assert(type(k) == "string" or type(k) == "number" or type(k) == "boolean", "key type " .. type(k))
      out[#out + 1] = "["; write(k, out); out[#out + 1] = "]="; write(x, out); out[#out + 1] = ","
    end
    out[#out + 1] = "}"
  else error("cannot save a " .. t) end
end
local out = { "BuffDiggerJournalDB=" }
write(BuffDiggerJournalDB, out)
local saved = BuffDiggerJournalDB
BuffDiggerJournalDB = nil
assert(loadstring(table.concat(out)))()
local ev = BuffDiggerJournalDB.events
local by = {}
for _, e in ipairs(ev) do by[e.ev] = by[e.ev] or e end
assert(by.SESSION and by.STATE and by.UNIT_AURA and by.PLAYER_REGEN_DISABLED and by.NAME_PLATE_UNIT_ADDED, "events kept")
assert(by.STATE.state.toThank[1].name == "Arthas")
local added = by.UNIT_AURA.info.addedAuras[1]
assert(added.name == "<secret>" and added.points == "<locked>" and added.auraInstanceID == 7)
assert(by.UNIT_AURA.units.nameplate1.name == "<secret>" and by.UNIT_AURA.units.nameplate1.class == "WARRIOR")
assert(ev[3].info == "<secret>" or ev[4].info == "<secret>", "a secret payload")
local snap = by.PLAYER_REGEN_DISABLED.snapshot
assert(snap.secret == true and snap.lockdown == true and snap.auras[1].spellId == 1243 and snap.auras[2].err)
assert(snap.restrictions.Combat == 2 and snap.restrictions.Encounter.err)

-- The ring: never more than 5000, the oldest dropped.
BuffDiggerJournalDB = saved
for i = 1, 5100 do NOW = 1000 + i; fire("NAME_PLATE_UNIT_REMOVED", "nameplate1") end
assert(#saved.events == 5000 and saved.events[5000].t == 6100 and saved.events[1].t == 1101, "ring bounded")
SlashCmdList.BUFFDIGGERJOURNAL("clear")
assert(#saved.events == 0)
print("journal: ok")
