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
COMBAT = true; InCombatLockdown = function() return COMBAT end
C_Secrets = { ShouldAurasBeSecret = function() return true end }
C_RestrictedActions = { GetAddOnRestrictionState = function(t) if t == 1 then error("boom") end return 2 end }
Enum = { AddOnRestrictionType = { Combat = 0, Encounter = 1 } }
C_UnitAuras = { GetAuraDataByIndex = function(_, i) if i == 1 and CVARS.addonCombatRestrictionsForced ~= "1" then return { auraInstanceID = 7, spellId = 1243, points = { 10 } } end error("secret aura") end }
TIMERS = {}; C_Timer = { NewTicker = function(_, fn) tickers[#tickers + 1] = fn end, After = function(_, fn) TIMERS[#TIMERS + 1] = fn end }
local function runTimers() while #TIMERS > 0 do table.remove(TIMERS, 1)() end end
CVARS = { addonCombatRestrictionsForced = "0" }
C_CVar = { GetCVarInfo = function(k) return CVARS[k] end, GetCVar = function(k) return CVARS[k] end,
  SetCVar = function(k, v) CVARS[k] = v return true end }
C_Spell = { GetSpellName = function(id) return "spell" .. id end }
SlashCmdList = {}; wipe = function(t) for k in pairs(t) do t[k] = nil end end
_G.BuffDigger = { debugState = function() return { toThank = { { name = "Arthas", at = 1 } }, mine = {}, asked = {},
  spellIDs = { fortitude = { 1243, 21562 } } } end }

assert(loadfile(DIR .. "dev/BuffDiggerJournal/Journal.lua"))("BuffDiggerJournal", {})
local function fire(...) for _, fn in ipairs(handlers) do fn(nil, ...) end end
fire("ADDON_LOADED", "BuffDiggerJournal")
fire("PLAYER_LOGIN")
for _, fn in ipairs(tickers) do fn() end
fire("UNIT_AURA", "player", { addedAuras = { { auraInstanceID = 7, sourceUnit = "nameplate1", name = SECRET, points = LOCKED, duration = math.huge, expirationTime = 0/0 } },
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
assert(added.duration == "inf" and type(added.expirationTime) == "string", "nan and inf saved as text")
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

-- /bdj probe: refused in combat; then reads, forces the restriction, reads, puts the CVar back, reads.
local bdj = SlashCmdList.BUFFDIGGERJOURNAL
bdj("probe"); assert(saved.probe == nil, "no probe in combat")
COMBAT = false
C_UnitAuras.GetAuraDataByAuraInstanceID = function(_, id) if CVARS.addonCombatRestrictionsForced == "1" then error("restricted") end return { auraInstanceID = id } end
C_UnitAuras.GetPlayerAuraBySpellID = function(id) if id == 1243 then return { spellId = id } end end
C_UnitAuras.GetAuraDataBySpellName = function() return nil end
bdj("probe")
local p = saved.probe
assert(p.running and CVARS.addonCombatRestrictionsForced == "1" and p.restore == "0")
fire("ADDON_RESTRICTION_STATE_CHANGED", 0, 1)
runTimers()
assert(not p.running and p.restore == nil and CVARS.addonCombatRestrictionsForced == "0", "CVar put back")
assert(p.secrecy[21562].should == "<missing>" and p.before.bySpellID[1243].spellId == 1243 and p.before.bySpellID[21562] == "<nil>")
assert(p.before.byID[7].auraInstanceID == 7 and p.forced.byID[7].err and p.after.byID[7].auraInstanceID == 7)
assert(p.before.byName[1243] == "<nil>" and p.before.caster[7] == "<missing>")
assert(p.sameIDsForced == false and p.sameIDs == true and p.events[1].ev == "ADDON_RESTRICTION_STATE_CHANGED")
-- An error after the CVar is set still puts it back.
local after = C_Timer.After; C_Timer.After = function() error("timer") end
bdj("probe"); C_Timer.After = after
assert(CVARS.addonCombatRestrictionsForced == "0" and saved.probe.err and not saved.probe.running)
-- A /reload in the middle: put back when the journal loads again.
bdj("probe"); TIMERS = {}; assert(CVARS.addonCombatRestrictionsForced == "1")
fire("ADDON_LOADED", "BuffDiggerJournal")
assert(CVARS.addonCombatRestrictionsForced == "0" and not saved.probe.running)
-- A restore that fails is retried after combat, and blocks a new probe meanwhile.
local set = C_CVar.SetCVar
bdj("probe"); C_CVar.SetCVar = function() return false end; runTimers()
assert(CVARS.addonCombatRestrictionsForced == "1" and saved.probe.restore == "0")
bdj("probe"); assert(saved.probe.restore == "0" and not saved.probe.running, "no new probe while the CVar is forced")
C_CVar.SetCVar = set; fire("PLAYER_REGEN_ENABLED")
assert(CVARS.addonCombatRestrictionsForced == "0" and saved.probe.restore == nil)
-- No such CVar: the reads are still there.
CVARS.addonCombatRestrictionsForced = nil
bdj("probe")
assert(saved.probe.cvar == "<missing>" and saved.probe.before.auras[1].spellId == 1243 and not saved.probe.running)
out = { "BuffDiggerJournalDB=" }; write(saved, out); assert(loadstring(table.concat(out)))() -- the probe saves too
assert(BuffDiggerJournalDB.probe.cvar == "<missing>")
print("journal: ok")
