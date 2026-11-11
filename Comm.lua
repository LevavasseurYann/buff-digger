-- Buff Digger: talking to other Buff Digger users (#10).
--
-- Requester side (ns.deliver, called by ns.request):
--   * Every request also sends an invisible addon message "REQ:<buff key>" to that player.
--   * Player not yet known to have Buff Digger: the usual whisper / /say goes out too.
--   * Known Buff Digger user: ONLY the invisible request, never a whisper on its own (#13). If no
--     buff comes within NO_ANSWER seconds, Get buffs says so, and the player's next click on one
--     of their buffs re-asks by whisper (ns.unanswered, ns.request).
-- Buffer side:
--   * On "REQ", if I accept requests and know that spell, I answer "ACK", a sound plays, and the
--     request joins the Requests window (UI.lua, opened by the player, never by itself) and the
--     count on the minimap button: their name and the requested buff's icon. Clicking the icon casts it.
--   * Requests expire after REQUEST_TTL seconds, or as soon as the player has the buff.
-- Blizzard blocks addon messages between players inside instances: there, plain chat only.
-- Anyone who answers or asks is remembered as a Buff Digger user (star on their icon).

local _, ns = ...
local BUFFS, L = ns.BUFFS, ns.L

local PREFIX = "BuffDigger" -- 16 characters max
local NO_ANSWER = 30 -- seconds without the buff before Get buffs offers to whisper them
local REQUEST_TTL = 90

local sendAddon = C_ChatInfo and C_ChatInfo.SendAddonMessage
local sendChat = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) end

local myRealm = ns.myRealm

-- "Name-Realm", the form CHAT_MSG_ADDON uses for the sender: two players with the same name on
-- different realms must never be mixed up (casting on the wrong one, or on myself).
local function fullName(name, realm)
  return name .. "-" .. ((realm and realm ~= "") and realm or myRealm())
end
local function canTalk() return sendAddon ~= nil and not IsInInstance() end

-- One sender may not make me ring, list a request and answer more than once per SENDER_GAP seconds.
local SENDER_GAP = 10
local lastFrom = {}

function ns.isPeer(name) return name and BuffDiggerDB.peers[name] ~= nil end

-- ---------------------------------------------------------------- requester side

-- Sends the request; returns the channel the thank-you should use later ("SAY" or "WHISPER"), and
-- true when it went out silently (addon message only). `reask`: a whisper whatever the peer (#13).
function ns.deliver(name, target, key, text, useSay, kind, reask)
  local function visible()
    if useSay then sendChat(name .. " : " .. text, "SAY") else sendChat(text, "WHISPER", nil, target) end
  end
  if reask or not canTalk() then visible() return useSay and "SAY" or "WHISPER" end

  sendAddon(PREFIX, "REQ:" .. key .. ":" .. (kind or "new"), "WHISPER", target)
  if not ns.isPeer(name) then visible() return useSay and "SAY" or "WHISPER" end
  return "WHISPER", true
end

-- A silent request with no buff after NO_ANSWER seconds (thanks close it once the buff lands).
function ns.unanswered(name)
  local e = BuffDiggerDB.asked[name]
  local ago = type(e) == "table" and e.silent and not e.thanked and time() - e.at
  return ago and ago >= NO_ANSWER and ago < 600 or false
end

-- ---------------------------------------------------------------- buffer side

local incoming = {} -- { name, full, key, at }

-- A click on a Requests icon (makeWindow's own hook casts, thanks and refreshes): a higher-rank or
-- refresh request can't close itself (they already have the buff), so the click closes it. A normal
-- one clears once they have the buff (a failed cast — range, line of sight — leaves it to retry).
function ns.onRequestClick(self) -- self: the buff icon of a Requests line
  local entry = self:GetParent().entry
  local req = entry and entry.request
  if req and req.kind ~= "new" and self:GetAttribute("type") then
    for i, r in ipairs(incoming) do
      if r == req then tremove(incoming, i) break end
    end
  end
end

-- The unit of a player around me (by "Name-Realm"), or nil if out of sight.
-- ponytail: nameplate tokens can pass to another player between two refreshes; refreshes follow
-- every NAME_PLATE_UNIT_* event, so the window is short. Check the name in PostClick if it bites.
-- `units`: where to look (nameplates for the marker, group members too for the window).
local function unitOf(full, units)
  local myName, realm = UnitFullName("player")
  if full == fullName(myName, realm) then return "player" end -- /bd selftest
  for _, unit in ipairs(units) do
    local n, r = UnitName(unit)
    if ns.readable(n) and ns.readable(r) and fullName(n, r) == full then return unit end
  end
end

function ns.refreshIncoming()
  -- Drop expired requests and the ones already fulfilled.
  local listed, plates = ns.listUnits(), ns.nearbyUnits()
  for i = #incoming, 1, -1 do
    local req = incoming[i]
    local unit = unitOf(req.full, listed)
    req.unit = unitOf(req.full, plates) -- for the marker above their nameplate (#15)
    -- "Has it already" only closes a request for a buff they lacked: a higher-rank request
    -- is for a buff they already have. My own (/bd selftest) is never closed this way.
    local done = req.kind == "new" and unit and unit ~= "player"
      and ns.unitHas and ns.unitHas(unit, BUFFS[req.key])
    if time() - req.at > REQUEST_TTL or done then
      tremove(incoming, i)
    end
  end
  if ns.showRequestCount then ns.showRequestCount(#incoming) end -- not secure: in combat too
  ns.refreshMarkers(incoming) -- above their nameplate (#15); hidden in combat by itself
  local w = ns.requestsWindow
  -- Secure rows: never in combat, never under the cursor (a re-fill between press and release
  -- would cast on someone else), and only when the player opened it.
  if not w or InCombatLockdown() or not w:IsShown() or w:IsMouseOver() then return end
  local parts = { {}, {}, {}, {} } -- group in range, group too far, others in sight, others out of sight
  local myLevel = UnitLevel("player")
  for _, req in ipairs(incoming) do
    local buff = BUFFS[req.key]
    local unit = unitOf(req.full, listed)
    local member = unit and ns.isMember(unit)
    local far = member and ns.tooFar(buff.id, unit)
    local castable = unit and not far
    -- The requested buff is the line's icon (its name in the tooltip), like Give buffs.
    local e = { unit = unit, who = unit and ns.targetName(unit) or false, request = req, grey = not castable,
      group = member,
      buffs = { { key = req.key, icon = C_Spell.GetSpellTexture(buff.id), rank = ns.rankAt(buff, myLevel),
        spell = castable and C_Spell.GetSpellName(buff.id) or nil } },
      text = far and req.name .. L[" (too far)"] or unit and req.name or L["%s (out of sight)"]:format(req.name) }
    -- Group members first, even far away (#16); like Give buffs: castable first, greyed after.
    tinsert(parts[(member and 0 or 2) + (castable and 1 or 2)], e)
  end
  local entries = {}
  for _, part in ipairs(parts) do
    for _, e in ipairs(part) do entries[#entries + 1] = e end
  end
  ns.fillRequests(entries)
end

local function onRequest(full, key, kind)
  local name = ns.chatName(full)
  local buff = BUFFS[key]
  if not BuffDiggerDB.acceptRequests or not buff or not IsPlayerSpell(buff.id) then return end
  if lastFrom[full] and time() - lastFrom[full] < SENDER_GAP then return end
  lastFrom[full] = time()
  BuffDiggerDB.peers[name] = time()
  -- Answer first: the requester then skips the whisper.
  sendAddon(PREFIX, "ACK", "WHISPER", full)
  for i, req in ipairs(incoming) do
    if req.name == name then tremove(incoming, i) break end
  end
  incoming[#incoming + 1] = { name = name, full = full, key = key, kind = kind, at = time() }
  -- Its own sound, not a whisper's (a party invite's chime); off in the settings.
  local sound = SOUNDKIT and (SOUNDKIT.IG_PLAYER_INVITE or SOUNDKIT.TELL_MESSAGE)
  if BuffDiggerDB.requestSound and sound then PlaySound(sound) end
  ns.refreshIncoming()
end

local function onAck(full)
  BuffDiggerDB.peers[ns.chatName(full)] = time() -- next time, the request goes out silently
end

-- ---------------------------------------------------------------- events

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, prefix, message, _, sender)
  if event == "PLAYER_LOGIN" then
    for name, at in pairs(BuffDiggerDB.peers) do -- forget users not seen for 30 days
      if time() - at > 30 * 86400 then BuffDiggerDB.peers[name] = nil end
    end
    -- Every second, like Get buffs: expiry, players coming into sight, and a re-fill once the cursor
    -- leaves the window (a clicked request then disappears quickly).
    C_Timer.NewTicker(1, ns.refreshIncoming)
  elseif event == "CHAT_MSG_ADDON" and prefix == PREFIX and ns.readable(message) and ns.readable(sender) then
    local myName, realm = UnitFullName("player")
    if sender == fullName(myName, realm) and message == "ACK" then return end -- my own self-test answer
    -- Only well-formed messages count; anything else is ignored (and never stored).
    local key, kind = message:match("^REQ:(%a+):(%a+)$")
    if key and (kind == "new" or kind == "refresh" or kind == "replace" or kind == "upgrade") then
      onRequest(sender, key, kind)
    elseif message == "ACK" then onAck(sender) end
  end
end)

-- /bd selftest: send myself a request for my first castable buff, to see the Requests window alone.
function ns.selfTest()
  local _, myClass = UnitClass("player")
  for key, buff in pairs(BUFFS) do
    if buff.class == myClass and IsPlayerSpell(buff.id) then
      sendAddon(PREFIX, "REQ:" .. key .. ":new", "WHISPER", (select(2, ns.unitName("player"))))
      BuffDiggerDB.requests = true -- the one time it opens by itself: the player asked to see it
      ns.applyWindows()
      return
    end
  end
  ns.notice(L["You know no buff to give (paladin, priest, mage or druid)."])
end
