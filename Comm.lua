-- Buff Digger: talking to other Buff Digger users (#10).
--
-- Requester side (ns.deliver, called by ns.request):
--   * Every request also sends an invisible addon message "REQ:<buff key>" to that player.
--   * Player not yet known to have Buff Digger: the usual whisper / /say goes out too.
--   * Known Buff Digger user: ONLY the invisible request. If they don't answer within ACK_WAIT
--     seconds, a plain whisper goes out instead (a whisper needs no click, so it may be delayed;
--     a /say could not, which is why /say is never the fallback).
-- Buffer side:
--   * On "REQ", if I accept requests and know that spell, I answer "ACK" and a small "Requests"
--     window pops up: "Yann wants Blessing of Might". Clicking the line casts it (secure button).
--   * Requests expire after REQUEST_TTL seconds, or as soon as the player has the buff.
-- Blizzard blocks addon messages between players inside instances: there, plain chat only.
-- Anyone who answers or asks is remembered as a Buff Digger user (star on their icon).

local _, ns = ...
local BUFFS, L = ns.BUFFS, ns.L

local PREFIX = "BuffDigger" -- 16 characters max
local ACK_WAIT = 1.5
local REQUEST_TTL = 90
local MAX_ROWS = 5
local ROW_HEIGHT = 20

local sendAddon = C_ChatInfo and C_ChatInfo.SendAddonMessage
local sendChat = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) end

local function shortName(full) return (full:match("^[^-]+")) end

local function myRealm()
  return (GetNormalizedRealmName and GetNormalizedRealmName()) or GetRealmName():gsub("[%s%-]", "")
end

-- "Name-Realm", the form CHAT_MSG_ADDON uses for the sender: two players with the same name on
-- different realms must never be mixed up (casting on the wrong one, or on myself).
local function fullName(name, realm)
  return name .. "-" .. ((realm and realm ~= "") and realm or myRealm())
end
local function canTalk() return sendAddon ~= nil and not IsInInstance() end

-- One sender may not make me ring, pop the window and answer more than once per SENDER_GAP seconds.
local SENDER_GAP = 10
local lastFrom = {}

function ns.isPeer(name) return name and BuffDiggerDB.peers[name] ~= nil end

-- ---------------------------------------------------------------- requester side

local waiting = {} -- name -> the request still waiting for an ACK

-- Sends the request; returns the channel the thank-you should use later ("SAY" or "WHISPER").
function ns.deliver(name, target, key, text, useSay, kind)
  local function visible()
    if useSay then sendChat(name .. " : " .. text, "SAY") else sendChat(text, "WHISPER", nil, target) end
  end
  if not canTalk() then visible() return useSay and "SAY" or "WHISPER" end

  sendAddon(PREFIX, "REQ:" .. key .. ":" .. (kind or "new"), "WHISPER", target)
  if not ns.isPeer(name) then visible() return useSay and "SAY" or "WHISPER" end

  local request = { text = text, target = target }
  waiting[name] = request
  C_Timer.After(ACK_WAIT, function()
    if waiting[name] ~= request then return end -- answered
    waiting[name] = nil
    sendChat(text, "WHISPER", nil, target)
  end)
  return "WHISPER"
end

-- ---------------------------------------------------------------- buffer side

local incoming = {} -- { name, full, key, at }
local window, rows

local function buildWindow()
  window = CreateFrame("Frame", "BuffDiggerRequests", UIParent, "BasicFrameTemplateWithInset")
  window:SetSize(290, 60)
  window:SetPoint("TOP", 0, -140)
  window:SetMovable(true)
  window:EnableMouse(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", window.StopMovingOrSizing)
  window:Hide()
  window.CloseButton:HookScript("OnClick", function() wipe(incoming) end)
  local header = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  header:SetPoint("TOP", 0, -5)
  header:SetText(L["Buff Digger — Requests"])

  rows = {}
  for i = 1, MAX_ROWS do
    local row = CreateFrame("Button", nil, window, "SecureActionButtonTemplate")
    row:SetSize(262, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 12, -28 - (i - 1) * ROW_HEIGHT)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    ns.secureClicks(row)
    ns.watchClick(row)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", 2, 0)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.text:SetPoint("RIGHT", -2, 0)
    row.text:SetJustifyH("LEFT")
    row:HookScript("PostClick", function(self, _, down)
      if down then return end -- registered for down and up: act once
      ns.flushThanks()
      -- A normal request clears itself once the player has the buff (a failed cast — range,
      -- line of sight — leaves it there to retry). A higher-rank or refresh request can't be
      -- checked that way (they already have the buff), so the click closes it.
      local req = self.request
      if req and req.kind ~= "new" and self:GetAttribute("type") then
        for i2, r in ipairs(incoming) do
          if r == req then tremove(incoming, i2) break end
        end
      end
      C_Timer.After(0.5, ns.refreshIncoming)
    end)
    row:Hide()
    rows[i] = row
  end
end

-- The unit of a player around me (by "Name-Realm"), or nil if out of sight.
-- ponytail: nameplate tokens can pass to another player between two refreshes; refreshes follow
-- every NAME_PLATE_UNIT_* event, so the window is short. Check the name in PostClick if it bites.
local function unitOf(full)
  local myName, realm = UnitFullName("player")
  if full == fullName(myName, realm) then return "player" end -- /bd selftest
  for _, unit in ipairs(ns.nearbyUnits()) do
    local n, r = UnitName(unit)
    if ns.readable(n) and ns.readable(r) and fullName(n, r) == full then return unit end
  end
end

function ns.refreshIncoming()
  if not window or InCombatLockdown() then return end -- secure rows cannot change in combat
  -- Drop expired requests and the ones already fulfilled.
  for i = #incoming, 1, -1 do
    local req = incoming[i]
    local unit = unitOf(req.full)
    -- "Has it already" only closes a request for a buff they lacked: a higher-rank request
    -- is for a buff they already have. My own (/bd selftest) is never closed this way.
    local done = req.kind == "new" and unit and unit ~= "player"
      and ns.unitHas and ns.unitHas(unit, BUFFS[req.key])
    if time() - req.at > REQUEST_TTL or done then
      tremove(incoming, i)
    end
  end
  for i, row in ipairs(rows) do
    local req = incoming[i]
    if req then
      local spell = C_Spell.GetSpellName(BUFFS[req.key].id)
      local unit = unitOf(req.full)
      row.request = req
      row.icon:SetTexture(C_Spell.GetSpellTexture(BUFFS[req.key].id))
      row.icon:SetDesaturated(unit == nil)
      if unit then
        ns.aimCast(row, unit, spell)
        row.text:SetText(L["%s wants %s"]:format(req.name, spell))
      else
        row:SetAttribute("type", nil) -- can't target someone out of sight
        row.text:SetText(L["%s wants %s (out of sight)"]:format(req.name, spell))
      end
    end
    row:SetShown(req ~= nil)
  end
  local count = math.min(#incoming, MAX_ROWS)
  window:SetHeight(40 + math.max(count, 1) * ROW_HEIGHT)
  window:SetShown(count > 0)
end

local function onRequest(full, key, kind)
  local name = shortName(full)
  local buff = BUFFS[key]
  if not ns.CASTING or not BuffDiggerDB.acceptRequests or not buff or not IsPlayerSpell(buff.id) then return end
  if lastFrom[full] and time() - lastFrom[full] < SENDER_GAP then return end
  lastFrom[full] = time()
  BuffDiggerDB.peers[name] = time()
  -- Answer first: the requester then skips the whisper.
  sendAddon(PREFIX, "ACK", "WHISPER", full)
  for i, req in ipairs(incoming) do
    if req.name == name then tremove(incoming, i) break end
  end
  incoming[#incoming + 1] = { name = name, full = full, key = key, kind = kind, at = time() }
  if SOUNDKIT and SOUNDKIT.TELL_MESSAGE then PlaySound(SOUNDKIT.TELL_MESSAGE) end
  ns.refreshIncoming()
end

local function onAck(full)
  local name = shortName(full)
  BuffDiggerDB.peers[name] = time()
  if waiting[name] then
    waiting[name] = nil
    ns.debug(L["%s has Buff Digger: request sent without a whisper."]:format(name)) -- the star says it
  end
end

-- ---------------------------------------------------------------- events

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, prefix, message, _, sender)
  if event == "PLAYER_LOGIN" then
    for name, at in pairs(BuffDiggerDB.peers) do -- forget users not seen for 30 days
      if time() - at > 30 * 86400 then BuffDiggerDB.peers[name] = nil end
    end
    buildWindow()
    C_Timer.NewTicker(5, ns.refreshIncoming) -- expiry, and players coming into sight
  elseif event == "PLAYER_REGEN_DISABLED" then
    if window then window:Hide() end -- still allowed during this very event
  elseif event == "PLAYER_REGEN_ENABLED" then
    ns.refreshIncoming()
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
      sendAddon(PREFIX, "REQ:" .. key .. ":new", "WHISPER", UnitName("player"))
      return
    end
  end
  ns.notice(L["You know no buff to give (paladin, priest, mage or druid)."])
end
