-- Buff Digger Journal: dev only (dev/ is never packaged, see .pkgmeta). During a play session it
-- writes what Buff Digger does into BuffDiggerJournalDB (saved when the game closes or on /reload),
-- so the in-game test checklist (docs/recette-en-jeu.md) can be filled from the file afterwards.
-- /bdj = how many lines; /bdj clear = start over. Only watches: never calls Buff Digger itself.
-- Install: copy this folder next to BuffDigger in Interface/AddOns (restart WoW the first time).

local MAX = 800
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
-- come back as events; requests are read from BuffDiggerDB.asked as they appear (tests 1-4, 17, 38).
local lastAsked = {}
local function snapshotAsked()
  for name, e in pairs(BuffDiggerDB and BuffDiggerDB.asked or {}) do
    if type(e) == "table" and lastAsked[name] ~= e.at then
      lastAsked[name] = e.at
      add("request", name, e.key, "channel=" .. show(e.channel), "to=" .. show(e.target), e.silent and "silent" or "")
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

local rosterPending = false
f:SetScript("OnEvent", function(_, event, a1, a2, a3, a4)
  if event == "ADDON_LOADED" and a1 == "BuffDiggerJournal" then
    BuffDiggerJournalDB = BuffDiggerJournalDB or {}
    log = BuffDiggerJournalDB
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
    for name, e in pairs(db.asked or {}) do if type(e) == "table" then lastAsked[name] = e.at end end
    C_Timer.NewTicker(2, snapshotWindows)
    C_Timer.NewTicker(1, snapshotAsked)
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
  elseif event == "UNIT_SPELLCAST_FAILED" then
    add("spell-failed", a3 and C_Spell.GetSpellName(a3), a3)
  end
end)

SLASH_BUFFDIGGERJOURNAL1 = "/bdj"
SlashCmdList.BUFFDIGGERJOURNAL = function(msg)
  if msg == "clear" then
    for i = #log, 1, -1 do log[i] = nil end
    add("session", "cleared")
  end
  print("|cff66ccff[Buff Digger Journal]|r " .. #log .. " lines (saved on /reload or logout). /bdj clear to start over.")
end
