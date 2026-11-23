-- Buff Digger Journal: dev only (dev/ is never packaged, see .pkgmeta). During a play session it
-- writes what Buff Digger does into BuffDiggerJournalDB (saved when the game closes or on /reload),
-- so the in-game test checklist (docs/recette-en-jeu.md) can be filled from the file afterwards.
-- Two parts: text lines (BuffDiggerJournalDB[1..n]) for a human, and raw events (BuffDiggerJournalDB.events)
-- for a replay off the game (#27). /bdj = how many; /bdj clear = start over.
-- Only watches: reads Buff Digger through BuffDigger.debugState() (copies), never changes it.
-- Install: copy this folder next to BuffDigger in Interface/AddOns (restart WoW the first time).

local MAX = 20000 -- lines: ~800 per half hour in a crowded town
local log

local function show(v)
  if issecretvalue and issecretvalue(v) then return "<secret>" end
  return tostring(v)
end

local function add(kind, ...)
  if not log then return end
  local parts = { date("%H:%M:%S"), kind }
  for i = 1, select("#", ...) do parts[#parts + 1] = show((select(i, ...))) end
  log[#log + 1] = table.concat(parts, " | ")
  if #log > MAX then table.remove(log, 1) end
end

-- ---------------------------------------------------------------- clicks in the windows

-- What the clicked line showed, to compare with the spell's real target (tests 13, 36, 45).
local function watchWindow(name)
  local w = _G[name]
  if not (w and w.rows) then add("init", name .. " missing") return end
  for i, row in ipairs(w.rows) do
    row:HookScript("PreClick", function(self, button)
      local e = self.entry
      add("click-name", name, "row " .. i, button, e and e.who, self:GetAttribute("macrotext"))
    end)
    for j, b in ipairs(row.buffs) do
      b:HookScript("PreClick", function(self, button)
        local e = row.entry
        add("click-icon", name, "row " .. i, "icon " .. j, button, e and e.who, self.key,
          self:GetAttribute("type"), ((self:GetAttribute("macrotext") or ""):gsub("\n", " / ")))
      end)
    end
  end
end

-- What each window lists, logged when it changes (tests 47, 48, 50, 52): headers, names, greyed.
local seen = {}
local function snapshotWindows()
  for _, name in ipairs({ "BuffDiggerNearby", "BuffDiggerGive", "BuffDiggerRequests" }) do
    local w = _G[name]
    if w and w:IsShown() and w.entries then
      local items = {}
      for _, e in ipairs(w.entries) do
        local icons = e.buffs and #e.buffs or 0
        items[#items + 1] = e.header and ("[" .. show(e.text) .. "]")
          or (show(e.who) .. (e.unit and ("<" .. e.unit .. ">") or "") .. (e.grey and "~grey" or "") .. "x" .. icons)
      end
      local sig = table.concat(items, ", ")
      if seen[name] ~= sig then
        seen[name] = sig
        add("window", name, #w.entries .. " lines", sig)
      end
    end
  end
end

-- ---------------------------------------------------------------- who waits for a thank-you (#21, #24)

-- The gold/amber Get buffs lines, logged when they change: which aura
-- (aura-in, just before) put someone there.
local lastThanks
local function snapshotThanks()
  local items = {}
  local gw = _G.BuffDiggerNearby
  if gw and gw:IsShown() then
    for _, row in ipairs(gw.rows or {}) do
      if row:IsShown() and row.state and row.entry then items[#items + 1] = row.state .. ":" .. show(row.entry.who) end
    end
  end
  local sig = table.concat(items, ", ")
  if sig ~= lastThanks then
    lastThanks = sig
    add("to-thank", sig == "" and "nobody" or sig)
  end
end

-- Every helpful aura landing on me (new or refreshed), with who cast it: what made Buff Digger
-- offer a thank-you.
local function auraIn(id, how)
  local ok, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", id)
  if not (ok and aura) or not aura.isHelpful then return end
  local src = aura.sourceUnit
  local readable = not (issecretvalue and issecretvalue(src))
  if readable and src == "player" then return end -- my own (Lightning Shield charges): noise
  local who = src and readable and UnitName(src)
  add("aura-in", how, aura.name, aura.spellId, "source=" .. show(src), show(who))
end

local function onAura(info)
  if type(info) ~= "table" then return end
  if info.isFullUpdate then add("aura-in", "full update (zoning, shapeshift?)") return end
  for _, aura in ipairs(info.addedAuras or {}) do auraIn(aura.auraInstanceID, "new") end
  for _, id in ipairs(info.updatedAuraInstanceIDs or {}) do auraIn(id, "update") end
end

-- ---------------------------------------------------------------- group (tests 47-50, 49 = dungeon)

local function snapshotGroup(why)
  local inInstance, kind = IsInInstance()
  local raid = IsInRaid()
  local n = raid and GetNumGroupMembers() or GetNumSubgroupMembers()
  add("group", why, "instance=" .. show(inInstance) .. "/" .. show(kind), raid and "raid" or "party", n .. " others")
  for i = 1, math.min(n, 40) do
    local unit = (raid and "raid" or "party") .. i
    local name, last = UnitName(unit)
    local _, class = UnitClass(unit)
    local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, 1, "HELPFUL")
    local r = C_Spell.IsSpellInRange and C_Spell.IsSpellInRange(1243, unit)
    add("member", unit, name, last, class, UnitLevel(unit), "connected=" .. show(UnitIsConnected(unit)),
      "visible=" .. show(UnitIsVisible(unit)), "aura1=" .. (ok and (aura and show(aura.name) or "none") or ("error " .. show(aura))),
      "range=" .. show(r))
  end
end

-- ---------------------------------------------------------------- what went out

-- Buff Digger keeps its own copy of the send functions (a hook would miss them): whispers and /say
-- come back as events; requests are read from BuffDiggerCharDB.asked as they appear (tests 1-4, 17, 38).
local lastAsked = {}
local function snapshotAsked()
  for name, e in pairs(BuffDiggerCharDB and BuffDiggerCharDB.asked or {}) do
    if type(e) == "table" and lastAsked[name] ~= e.at then
      lastAsked[name] = e.at
      add("request", name, table.concat(e.keys or { e.key }, "+"), "channel=" .. show(e.channel), "to=" .. show(e.target), e.silent and "silent" or "")
    end
  end
end

-- The game's right-click menu (#17): which unit it was opened on (test 51).
if Menu and Menu.ModifyMenu then
  for _, tag in ipairs({ "MENU_UNIT_PLAYER", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_RAID" }) do
    Menu.ModifyMenu(tag, function(_, _, data)
      local unit = data and data.unit
      add("game-menu", tag, unit, unit and UnitName(unit))
    end)
  end
end

-- Lua errors from Buff Digger (WoW writes them nowhere): kept, then passed on as before.
if geterrorhandler and seterrorhandler then
  local previous = geterrorhandler()
  seterrorhandler(function(msg, ...)
    if type(msg) == "string" and msg:find("BuffDigger") then add("lua-error", msg, debugstack and debugstack(2, 6, 0)) end
    return previous(msg, ...)
  end)
end

-- ---------------------------------------------------------------- raw events, to replay off the game (#27)

-- BuffDiggerJournalDB.events: { t = GetTime(), ev = "UNIT_AURA", ... }, the last MAX_EVENTS only.
local MAX_EVENTS = 60000 -- ~5000 per half hour in town, ~18 MB: dev/save-journal.ps1 keeps each save (ponytail: a session past ~6 h loses its start, /reload now and then; Lua 5.1 caps a chunk at 262143 constants, ~80k used here)
local events

-- A copy that the SavedVariables file can hold and dofile read back: a secret becomes "<secret>", a
-- table we may not read "<locked>", an error { err = msg }, a function or frame its tostring.
local function ser(v, depth)
  if issecretvalue and issecretvalue(v) then return "<secret>" end
  local tv = type(v)
  if tv == "number" and (v ~= v or v == math.huge or v == -math.huge) then return tostring(v) end
  if tv == "nil" or tv == "number" or tv == "string" or tv == "boolean" then return v end
  if tv ~= "table" then return tostring(v) end
  if canaccesstable and not canaccesstable(v) then return "<locked>" end
  depth = (depth or 0) + 1
  if depth > 6 then return "<deep>" end
  local ok, out = pcall(function()
    local t = {}
    for k, x in pairs(v) do
      local key = ser(k, 6)
      if type(key) == "table" then key = "<table key>" end
      t[key] = ser(x, depth)
    end
    return t
  end)
  if ok then return out end
  return { err = tostring(out) }
end

-- One call, whatever happens: its result, "<nil>", "<secret>", { err = msg } or "<missing>".
local function try(fn, ...)
  if not fn then return "<missing>" end
  local ok, v = pcall(fn, ...)
  if not ok then return { err = tostring(v) } end
  v = ser(v)
  if v == nil then return "<nil>" end
  return v
end

local function ident(unit)
  local name, last = UnitName(unit)
  local _, class = UnitClass(unit)
  return ser({ name = name, last = last, class = class, level = UnitLevel(unit) })
end

local function record(ev, e)
  if not events then return end
  e = e or {}
  e.t, e.ev = GetTime(), ev
  events[#events + 1] = e
  if #events > MAX_EVENTS then table.remove(events, 1) end
end

local function restrictions()
  local r = {}
  local get = C_RestrictedActions and C_RestrictedActions.GetAddOnRestrictionState
  for name, v in pairs(get and Enum and Enum.AddOnRestrictionType or {}) do r[name] = try(get, v) end
  return r
end

-- All my helpful auras by index, stopping at the first nil, secret or error (each kept as such).
local function myAuras()
  local list = {}
  for i = 1, 40 do
    local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
    if not ok then list[i] = { err = tostring(a) } break end
    a = ser(a)
    if a == nil then list[i] = "<nil>" break end
    list[i] = a
    if a == "<secret>" or a == "<locked>" then break end
  end
  return list
end

local function snapshot()
  return { secret = try(C_Secrets and C_Secrets.ShouldAurasBeSecret), lockdown = try(InCombatLockdown),
    restrictions = restrictions(), auras = myAuras() }
end

local function recordAura(unit, info)
  local e = { unit = unit, info = ser(info), units = {} }
  local added = type(e.info) == "table" and e.info.addedAuras
  for _, a in pairs(type(added) == "table" and added or {}) do
    local src = type(a) == "table" and a.sourceUnit
    if type(src) == "string" and not src:find("^<") then e.units[src] = ident(src) end
  end
  record("UNIT_AURA", e)
end

local function recordGroup()
  local raid = IsInRaid()
  local e = { raid = raid, units = {} }
  for i = 1, math.min(raid and GetNumGroupMembers() or GetNumSubgroupMembers(), 40) do
    local unit = (raid and "raid" or "party") .. i
    e.units[unit] = ident(unit)
  end
  record("GROUP_ROSTER_UPDATE", e)
end

-- What Buff Digger itself holds (toThank, mine, asked), logged when it changes.
local function same(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return a == b end
  for k, v in pairs(a) do if not same(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end
local lastState
local function snapshotState()
  if not (BuffDigger and BuffDigger.debugState) then return end
  local s = BuffDigger.debugState()
  s = { toThank = ser(s.toThank), mine = ser(s.mine), asked = ser(s.asked) }
  if not same(s, lastState) then
    lastState = s
    record("STATE", { state = s })
  end
end

-- ---------------------------------------------------------------- /bdj probe (#29)

-- Answers the audit's open questions (docs/audit, § 1.7) in a few seconds, out of combat: which aura
-- APIs work, nil, go secret or raise an error, before / under / after the forced combat restriction.
-- Result: BuffDiggerJournalDB.probe (after /reload).
local CVAR = "addonCombatRestrictionsForced"
local probing -- events received while the probe runs, in order

local function auraIDs(r)
  local ids = {}
  for _, a in ipairs(r.auras) do
    if type(a) == "table" and type(a.auraInstanceID) == "number" then ids[#ids + 1] = a.auraInstanceID end
  end
  table.sort(ids)
  return ids
end

local function readAll(ids, spells)
  local r = snapshot()
  r.byID, r.caster, r.bySpellID, r.byName = {}, {}, {}, {}
  for _, id in ipairs(ids) do
    r.byID[id] = try(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", id)
    r.caster[id] = try(C_UnitAuras.GetAuraCasterGUID, "player", id)
  end
  for _, sid in ipairs(spells) do
    r.bySpellID[sid] = try(C_UnitAuras.GetPlayerAuraBySpellID, sid)
    local ok, name = pcall(C_Spell.GetSpellName, sid)
    r.byName[sid] = (ok and type(name) == "string") and try(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL") or "<no name>"
  end
  r.ids = auraIDs(r)
  return r
end

-- Puts the CVar back as it was; kept in the file until it worked, so a /reload mid-probe still restores it.
local function restoreCVar()
  local p = BuffDiggerJournalDB and BuffDiggerJournalDB.probe
  if not (p and p.restore) then return end
  p.restored = try(C_CVar.SetCVar, CVAR, p.restore)
  local ok, now = pcall(C_CVar.GetCVar, CVAR)
  if ok and now == p.restore then p.restore = nil
  else print("|cff66ccff[Buff Digger Journal]|r Could not put " .. CVAR .. " back: type /console " .. CVAR .. " " .. p.restore) end
end

local function finishProbe(p)
  probing = nil
  p.running = nil
  print("|cff66ccff[Buff Digger Journal]|r probe OK, /reload to save it (BuffDiggerJournalDB.probe).")
end

local function startProbe()
  local p = BuffDiggerJournalDB.probe
  if p and p.running then print("|cff66ccff[Buff Digger Journal]|r A probe is already running.") return end
  if InCombatLockdown() then print("|cff66ccff[Buff Digger Journal]|r In combat: try again after.") return end
  if p and p.restore then restoreCVar() if p.restore then return end end -- never take a forced value as the original
  p = { running = true, at = date("%Y-%m-%d %H:%M:%S"), build = ser({ GetBuildInfo() }), secrecy = {} }
  BuffDiggerJournalDB.probe = p
  -- The spells: every ID in Buff Digger's Data.lua (rank 1 and group), then whatever I wear now.
  local spells, seen = {}, {}
  local function addSpell(id) if type(id) == "number" and not seen[id] then seen[id] = true spells[#spells + 1] = id end end
  local ok, st = pcall(BuffDigger.debugState)
  for _, list in pairs(ok and st.spellIDs or {}) do for _, id in ipairs(list) do addSpell(id) end end
  local worn = myAuras()
  for _, a in ipairs(worn) do if type(a) == "table" then addSpell(a.spellId) end end
  local ids = auraIDs({ auras = worn })
  for _, sid in ipairs(spells) do
    p.secrecy[sid] = { should = try(C_Secrets and C_Secrets.ShouldSpellAuraBeSecret, sid),
      level = try(C_Secrets and C_Secrets.GetSpellAuraSecrecy, sid) }
  end
  p.before = readAll(ids, spells)
  local okInfo, value, _, _, _, _, isSecure = pcall(C_CVar.GetCVarInfo, CVAR)
  if not (okInfo and type(value) == "string") then
    p.cvar = okInfo and "<missing>" or { err = tostring(value) }
    return finishProbe(p)
  end
  p.cvar, p.restore, p.cvarSecure = value, value, ser(isSecure)
  probing = {}
  p.events = probing
  p.set = try(C_CVar.SetCVar, CVAR, "1")
  C_Timer.After(1, function()
    pcall(function() p.forced = readAll(ids, spells) end)
    restoreCVar()
    C_Timer.After(1, function()
      pcall(function()
        p.after = readAll(ids, spells)
        p.sameIDs = same(ids, p.after.ids)
        p.sameIDsForced = p.forced and same(ids, p.forced.ids)
      end)
      finishProbe(p)
    end)
  end)
end

-- ---------------------------------------------------------------- events

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("ADDON_ACTION_BLOCKED")
f:RegisterEvent("ADDON_ACTION_FORBIDDEN")
f:RegisterEvent("UI_ERROR_MESSAGE")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
f:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
f:RegisterEvent("CHAT_MSG_SAY")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
f:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
f:RegisterUnitEvent("UNIT_AURA", "player")
f:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

-- The raw events (#27): never an error, in combat or not.
local function onRawEvent(event, a1, a2)
  if event == "UNIT_AURA" then recordAura(a1, a2)
  elseif event == "ADDON_RESTRICTION_STATE_CHANGED" or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
    record(event, { type = ser(a1), state = ser(a2), snapshot = snapshot() })
  elseif event == "PLAYER_ENTERING_WORLD" then
    record(event, { login = ser(a1), reload = ser(a2), units = { player = ident("player") }, snapshot = snapshot() })
  elseif event == "GROUP_ROSTER_UPDATE" then recordGroup()
  elseif event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
    local unit = ser(a1)
    record(event, { unit = unit, units = type(unit) == "string" and not unit:find("^<") and { [unit] = ident(unit) } or nil })
  end
end

local rosterPending = false
f:SetScript("OnEvent", function(_, event, a1, a2, a3, a4)
  pcall(onRawEvent, event, a1, a2)
  -- A restore that failed (combat, restriction): tried again once the probe is over.
  if (event == "PLAYER_REGEN_ENABLED" or event == "ADDON_RESTRICTION_STATE_CHANGED") and log and log.probe
    and log.probe.restore and not log.probe.running then pcall(restoreCVar) end
  if probing then pcall(function() probing[#probing + 1] = { t = GetTime(), ev = event, a1 = ser(a1), a2 = ser(a2) } end) end
  if event == "ADDON_LOADED" and a1 == "BuffDiggerJournal" then
    BuffDiggerJournalDB = BuffDiggerJournalDB or {}
    log = BuffDiggerJournalDB
    log.events = log.events or {}
    events = log.events
    local p = log.probe
    if p then p.running = nil restoreCVar() end -- a /reload in the middle of a probe
    pcall(record, "SESSION", { time = time(), build = ser({ GetBuildInfo() }), units = { player = ident("player") } })
    add("session", GetBuildInfo(), UnitName("player"), select(2, UnitClass("player")), UnitLevel("player"))
  elseif event == "PLAYER_LOGIN" then
    for _, name in ipairs({ "BuffDiggerNearby", "BuffDiggerGive", "BuffDiggerRequests", "BuffDiggerGiveNext" }) do
      if name == "BuffDiggerGiveNext" then
        local b = _G[name]
        if b then b:HookScript("PreClick", function(self, button, down)
          add("key-give-next", button, show(down), self:GetAttribute("type"), ((self:GetAttribute("macrotext") or ""):gsub("\n", " / ")))
        end) end
      else watchWindow(name) end
    end
    local db = BuffDiggerDB or {}
    add("settings", "plates=" .. show(db.plates), "nearbyUseful=" .. show(db.nearbyUseful), "targetOnAsk=" .. show(db.targetOnAsk),
      "gameMenu=" .. show(db.gameMenu), "useSay=" .. show(db.useSay), "debug=" .. show(db.debug))
    for name, e in pairs(BuffDiggerCharDB and BuffDiggerCharDB.asked or {}) do if type(e) == "table" then lastAsked[name] = e.at end end
    C_Timer.NewTicker(2, snapshotWindows)
    C_Timer.NewTicker(1, snapshotAsked)
    C_Timer.NewTicker(1, snapshotThanks)
    C_Timer.NewTicker(1, function() pcall(snapshotState) end)
  elseif event == "PLAYER_ENTERING_WORLD" then
    snapshotGroup("entering world")
  elseif event == "GROUP_ROSTER_UPDATE" then
    if not rosterPending then -- a raid fires it in bursts
      rosterPending = true
      C_Timer.After(2, function() rosterPending = false snapshotGroup("roster") end)
    end
  elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
    add("blocked", event, a1, a2)
  elseif event == "UI_ERROR_MESSAGE" then
    add("game-error", a1, a2)
  elseif event == "CHAT_MSG_ADDON" and a1 == "BuffDigger" then
    add("addon-in", a3, a4, a2)
  elseif event == "CHAT_MSG_WHISPER_INFORM" then
    add("whisper-out", a2, a1)
  elseif event == "CHAT_MSG_SAY" then
    local me = UnitName("player")
    if a2 and not (issecretvalue and issecretvalue(a2)) and a2:find(me, 1, true) == 1 then add("say-out", a1) end
  elseif event == "CHAT_MSG_TEXT_EMOTE" then
    add("emote-seen", a2, a1)
  elseif event == "PLAYER_REGEN_DISABLED" then add("combat", "in")
  elseif event == "PLAYER_REGEN_ENABLED" then add("combat", "out")
  elseif event == "UNIT_SPELLCAST_SENT" then
    -- a2 = target name, a4 = spell ID: the format of the name answers test 45.
    add("spell-sent", a4 and C_Spell.GetSpellName(a4), a4, "target=" .. show(a2))
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    add("spell-done", a3 and C_Spell.GetSpellName(a3), a3)
  elseif event == "UNIT_AURA" then
    -- In combat (a duel too) the game hides aura details (secret values): nothing logged then.
    pcall(onAura, a2)
  elseif event == "UNIT_SPELLCAST_FAILED" then
    add("spell-failed", a3 and C_Spell.GetSpellName(a3), a3)
  end
end)

SLASH_BUFFDIGGERJOURNAL1 = "/bdj"
SlashCmdList.BUFFDIGGERJOURNAL = function(msg)
  if msg == "probe" then
    local ok, err = pcall(startProbe)
    if not ok then
      probing = nil
      local p = BuffDiggerJournalDB.probe
      if p then p.running, p.err = nil, tostring(err) end
      restoreCVar()
      print("|cff66ccff[Buff Digger Journal]|r probe failed: " .. tostring(err))
    end
    return
  end
  if msg == "clear" then
    for i = #log, 1, -1 do log[i] = nil end
    wipe(events)
    add("session", "cleared")
  end
  print("|cff66ccff[Buff Digger Journal]|r " .. #log .. " lines, " .. #events .. " events (saved on /reload or logout). /bdj clear to start over, /bdj probe to test the aura APIs.")
end
