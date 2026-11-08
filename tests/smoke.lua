-- Fake WoW API: just enough to run Buff Digger end to end (scenarios at the bottom).
-- Run from the repo root: uv run --no-project -q --with lupa python -I tests/run_smoke.py
local sent, events = {}, {}
local function obj() local o = {} ; return setmetatable(o, {__index=function(t,k)
  if k=="IsShown" then return function(s) return s._shown end end
  if k=="SetShown" then return function(s,v) s._shown=v end end
  if k=="Show" then return function(s) s._shown=true end end
  if k=="Hide" then return function(s) s._shown=false end end
  if k=="GetChecked" then return function() return true end end
  if k=="GetStringHeight" then return function() return 60 end end
  if k=="GetWidth" then return function() return 140 end end
  if k=="GetCenter" then return function() return 0,0 end end
  if k=="SetScript" then return function(s,e,f) s["_"..e]=f end end
  if k=="RegisterEvent" or k=="RegisterUnitEvent" then return function(s) if not rawget(s,"_reg") then rawset(s,"_reg",true); events[#events+1]=s end end end
  if k=="CreateFontString" or k=="CreateTexture" then return function() return obj() end end
  if k=="CloseButton" then local c=obj(); rawset(t,k,c); return c end
  return function() end end}) end
CreateFrame=function(_,name) local o=obj(); if name then _G[name]=o end; return o end
UIParent, Minimap, UISpecialFrames = obj(), obj(), {}
SlashCmdList={}; TIMERS={}; C_Timer={After=function(_,f) TIMERS[#TIMERS+1]=f end, NewTicker=function() end}; function runTimers() local t=TIMERS; TIMERS={}; for _,f in ipairs(t) do f() end end; IsInInstance=function() return false end; PlaySound=function() end; SOUNDKIT={TELL_MESSAGE=1}; wipe=function(t) for k in pairs(t) do t[k]=nil end end; tremove=table.remove; unpack=unpack; tinsert=table.insert; strtrim=function(s) return (s:gsub("^%s+",""):gsub("%s+$","")) end
time=os.time; date=os.date; NOW=1000; GetTime=function() return NOW end; BOUND=nil; GetBindingKey=function() return BOUND end; print=print; GetLocale=function() return "frFR" end
issecure=function() return false end; InCombatLockdown=function() return false end
GetBuildInfo=function() return "1.60.1",1,"",16001 end; CVARS={nameplateShowFriends="0"}; GetCVar=function(k) return CVARS[k] end; SetCVar=function(k,v) CVARS[k]=v end
GetCursorPosition=function() return 0,0 end; IsPlayerSpell=function() return false end
DoEmote=function(e,n) sent[#sent+1]="EMOTE "..e.." "..n end
local NAMES={[19740]="Bénédiction de puissance",[20217]="Bénédiction des rois",[19742]="Bénédiction de sagesse",[1243]="Mot de pouvoir : Robustesse"}
SHIFT=false; IsShiftKeyDown=function() return SHIFT end; IsControlKeyDown=function() return false end
C_Spell={GetSpellLink=function(id) return "|cff71d5ff|Hspell:"..id..":0|h["..(NAMES[id] or "x").."]|h|r" end, GetSpellName=function(id) return NAMES[id] or ("spell"..id) end, GetSpellTexture=function() return 1 end}
local myAuras={}
C_UnitAuras={GetAuraDataByIndex=function(u,i) if u=="player" then return myAuras[i] end end,
  GetAuraDataBySpellName=function() return nil end}
local units={player={"Yann","WARRIOR",21}, nameplate1={"Arthas","PALADIN",25}, nameplate2={"Jaina","MAGE",30}}
UnitName=function(u) return units[u] and units[u][1] end
UnitClass=function(u) return "x", units[u] and units[u][2] end
UnitLevel=function(u) return units[u] and units[u][3] end
GetNormalizedRealmName=function() return "Realm" end; GetRealmName=function() return "Realm" end; UnitFullName=function(u) return units[u][1], "Realm" end
UnitIsPlayer=function(u) return units[u]~=nil end; UnitExists=UnitIsPlayer
UnitIsUnit=function(a,b) return a==b end; UnitIsFriend=function() return true end
C_NamePlate={GetNamePlates=function() return {} end,
  GetNamePlateForUnit=function() return {} end}
C_ChatInfo={SendChatMessage=function(m,c,_,t) sent[#sent+1]=c.." "..tostring(t)..": "..m end, RegisterAddonMessagePrefix=function() end, SendAddonMessage=function(p,m,c,t) sent[#sent+1]="ADDON>"..t..": "..m end}
TooltipDataProcessor=nil
local ns={}
for _,f in ipairs{"Locales","Data","BuffDigger","UI","Comm"} do assert(loadfile(DIR..f..".lua"))("BuffDigger", ns) end
local function fire(ev,...) for _,f in ipairs(events) do if f._OnEvent then f._OnEvent(f,ev,...) end end end
fire("ADDON_LOADED","BuffDigger"); fire("PLAYER_LOGIN"); fire("PLAYER_ENTERING_WORLD", true); fire("NAME_PLATE_UNIT_ADDED","nameplate1"); fire("NAME_PLATE_UNIT_ADDED","nameplate2"); print("nearby:", #ns.nearbyUnits())
-- 1. Warrior lacks everything: paladin 25 should offer Might (top pick), mage nothing.
print("paladin:", ns.bestBuff("Arthas","PALADIN",25)); print("mage:", ns.bestBuff("Jaina","MAGE",30))
ns.askBest()
-- 2. Arthas blesses me with Kings -> he may only REPLACE with Might (higher in my prefs).
myAuras[1]={auraInstanceID=7,name="Bénédiction des rois",spellId=20217,sourceUnit="nameplate1"}
fire("UNIT_AURA","player")
print("after kings:", ns.bestBuff("Arthas","PALADIN",25))
-- 3. Anti-nag: asking him again right away is refused.
ns.request("nameplate1")
SlashCmdList.BUFFDIGGER("spells"); SlashCmdList.BUFFDIGGER("")
ns.toggleWindow(); ns.refreshWindow()
for _,s in ipairs(sent) do print("SENT", s) end
BuffDiggerDB.frenchMessages = true
print("FR:", ns.message("new", "fortitude", true))
print("EN:", ns.message("upgrade", "fortitude", false))

SHIFT=true; ns.request("nameplate2"); units.nameplate3={"Anduin","PRIEST",40}; ns.request("nameplate3"); print("LAST", sent[#sent])
local prev; for i=1,6 do local m=ns.message("new","might",false); assert(m~=prev,"same twice"); prev=m; print("EN"..i, (m:gsub("|c%x+|H.-|h","")):gsub("|h|r","")) end
print("FR", (ns.message("upgrade","kings",true):gsub("|c%x+|H.-|h",""):gsub("|h|r","")))
-- Priest who knows Fortitude: the Give window lists the paladin (Fortitude is in PALADIN prefs).
units.player={"Yann","PRIEST",40}; IsPlayerSpell=function(id) return id==1243 end
local seen={}
local realCreate=CreateFrame
ns.toggleGive(); ns.refreshWindow()
SlashCmdList.BUFFDIGGER("")

-- 0.2.0 checks
units.player={"Yann","WARRIOR",21}; IsPlayerSpell=function() return false end
BuffDiggerDB.asked = {}
print("offers paladin 25:", table.concat(ns.offers("PALADIN",25), ","))
ns.request("nameplate1", "wisdom"); print("CHOSEN", sent[#sent])
print("askedAgo:", ns.askedAgo("Arthas"))
BuffDiggerDB.prefs.WARRIOR = {"kings","might"}
print("custom prefs best:", ns.bestBuff("Zed","PALADIN",25))

-- Thanks flow
SHIFT=false; BuffDiggerDB.frenchMessages=false; BuffDiggerDB.asked={}; BuffDiggerDB.prefs.WARRIOR=nil
units.nameplate4={"Uther","PALADIN",30}
myAuras={}; fire("UNIT_AURA","player")
ns.request("nameplate4"); print("REQ", sent[#sent])
myAuras[1]={auraInstanceID=20,name="Bénédiction de puissance",spellId=19740,sourceUnit="nameplate4"}
fire("UNIT_AURA","player"); print("T0 emote first:", sent[#sent]); assert(sent[#sent]:find("EMOTE"))
runTimers(); print("T1 thank-you after the delay:", sent[#sent]); assert(sent[#sent]:find("WHISPER Uther"))
-- unknown giver, asked in /say: thanks wait for next click
SHIFT=true; units.nameplate5={"Anduin","PRIEST",40}; ns.request("nameplate5"); SHIFT=false
myAuras[2]={auraInstanceID=21,name="Mot de pouvoir : Robustesse",spellId=1243,sourceUnit=nil}
local n=#sent; fire("UNIT_AURA","player"); print("emote now:", sent[#sent]); ns.flushThanks(); print("after click:", sent[#sent])
-- Ambiguous unknown giver: two open Fortitude requests -> nobody thanked
BuffDiggerDB.asked = { A = {at=time(), key="fortitude", channel="WHISPER"}, B = {at=time(), key="fortitude", channel="WHISPER"} }
local before=#sent; myAuras[3]={auraInstanceID=30,name="Mot de pouvoir : Robustesse",spellId=1243,sourceUnit=nil}; fire("UNIT_AURA","player")
print("ambiguous sent:", #sent-before)
-- Same giver twice within 60s: one emote only
myAuras[4]={auraInstanceID=31,name="Marque du fauve",spellId=1126,sourceUnit="nameplate4"}; before=#sent; fire("UNIT_AURA","player")
print("second buff from Uther sent:", #sent-before)

print("=== #10")
units.player={"Yann","WARRIOR",21}; IsPlayerSpell=function() return false end
BuffDiggerDB.asked={}; BuffDiggerDB.peers={}; SHIFT=false; myAuras={}; fire("UNIT_AURA","player"); runTimers()
units.nameplate6={"Tirion","PALADIN",40}; fire("NAME_PLATE_UNIT_ADDED","nameplate6"); runTimers()
local b=#sent; ns.request("nameplate6"); for i=b+1,#sent do print("P1", sent[i]) end
fire("CHAT_MSG_ADDON","BuffDigger","ACK","WHISPER","Tirion-Realm"); print("peer?", ns.isPeer("Tirion"))
BuffDiggerDB.asked={}; b=#sent; ns.request("nameplate6"); for i=b+1,#sent do print("P2 before timer", sent[i]) end
fire("CHAT_MSG_ADDON","BuffDigger","ACK","WHISPER","Tirion-Realm"); runTimers(); print("P2 after ACK, new sends:", #sent-b)
BuffDiggerDB.asked={}; b=#sent; ns.request("nameplate6"); runTimers(); for i=b+1,#sent do print("P3 no ACK", sent[i]) end
-- buffer side
units.player={"Yann","PRIEST",40}; IsPlayerSpell=function(id) return id==1243 end
b=#sent; fire("CHAT_MSG_ADDON","BuffDigger","REQ:fortitude:new","WHISPER","Bob-Realm"); for i=b+1,#sent do print("BUF", sent[i]) end
b=#sent; fire("CHAT_MSG_ADDON","BuffDigger","REQ:might:new","WHISPER","Carl-Realm"); print("unknown spell -> sends:", #sent-b)
b=#sent; fire("CHAT_MSG_ADDON","BuffDigger","REQ:fortitude:new","WHISPER","Bob-Realm"); print("Bob again within 10s -> sends:", #sent-b)
b=#sent; fire("CHAT_MSG_ADDON","BuffDigger","garbage","WHISPER","Eve-Realm"); print("garbage -> peer?", ns.isPeer("Eve"), "sends:", #sent-b)
ns.selfTest(); print("SELF", sent[#sent])
print("plates before:", ns.friendlyPlatesOn()); SlashCmdList.BUFFDIGGER("nameplates"); print("plates after:", ns.friendlyPlatesOn())

print("=== #8 rank from the value on the buff (aura.points)")
units.player={"Yann","WARRIOR",21}; IsPlayerSpell=function() return false end; BuffDiggerDB.asked={}
myAuras={}; fire("UNIT_AURA","player")
-- Login: Might +35 (rank 2) already there, giver unknown.
ns.__relog=nil
myAuras={{auraInstanceID=50,name="Bénédiction de puissance",spellId=19834,sourceUnit=nil,points={35},expirationTime=NOW+3000,duration=3600}}
fire("PLAYER_ENTERING_WORLD", false)
units.nameplate7={"Bolvar","PALADIN",40}
BuffDiggerDB.prefs.WARRIOR={"might"} -- only Might matters here: a missing buff would come first
local k, kind = ns.bestBuff("Bolvar","PALADIN",40); print("rank known at login -> paladin 40 offers:", k, kind)
assert(k=="might" and kind=="upgrade", "rank 2 from points should allow an upgrade")
-- Value not in Data.lua: rank unknown, no upgrade offered (old behaviour), and /bd log flags it.
myAuras={{auraInstanceID=51,name="Bénédiction de puissance",spellId=19834,sourceUnit=nil,points={36},expirationTime=NOW+3000,duration=3600}}
fire("PLAYER_ENTERING_WORLD", false)
k, kind = ns.bestBuff("Bolvar","PALADIN",40); print("unknown value ->", k, kind)
assert(not (k=="might" and kind=="upgrade"))
SlashCmdList.BUFFDIGGER("log")
BuffDiggerDB.prefs.WARRIOR=nil

print("=== refresh before it runs out")
BuffDiggerDB.refreshBefore=300
myAuras={{auraInstanceID=60,name="Mot de pouvoir : Robustesse",spellId=1243,sourceUnit=nil,points={8},expirationTime=NOW+1000,duration=3600}}
fire("PLAYER_ENTERING_WORLD", false)
units.player={"Yann","WARLOCK",30}  -- Fortitude is a warlock's top pick
k, kind = ns.bestBuff("Anduin","PRIEST",40); print("16 min left ->", k, kind); assert(k~="fortitude" or kind~="refresh")
NOW=NOW+800  -- 3 min 20 left
k, kind = ns.bestBuff("Anduin","PRIEST",40); print("3 min left ->", k, kind); assert(k=="fortitude" and kind=="refresh")
k = ns.bestBuff("Lowbie","PRIEST",5); print("lower-rank priest won't refresh ->", k); assert(k~="fortitude")
BuffDiggerDB.refreshBefore=0
k, kind = ns.bestBuff("Anduin","PRIEST",40); print("setting off ->", k, kind); assert(kind~="refresh")
BuffDiggerDB.refreshBefore=300
local b=#sent; ns.request("nameplate5"); print("REFRESH REQ", sent[#sent]); assert(#sent>b)
-- Anduin refreshes it: same aura, later end -> thanked.
b=#sent; myAuras[1].expirationTime=NOW+1800; myAuras[1].sourceUnit="nameplate5"; fire("UNIT_AURA","player"); runTimers()
for i=b+1,#sent do print("THANKS", sent[i]) end; assert(#sent>b, "refresh should be thanked")
-- A peer sees a refresh request (kind accepted).
units.player={"Yann","PRIEST",40}; IsPlayerSpell=function(id) return id==1243 end
b=#sent; fire("CHAT_MSG_ADDON","BuffDigger","REQ:fortitude:refresh","WHISPER","Zoe-Realm"); print("refresh REQ -> ACK:", sent[#sent]); assert(sent[#sent]:find("ACK"))

-- Unknown rank (value hidden): no refresh asked, it could lower the rank.
myAuras={{auraInstanceID=61,name="Mot de pouvoir : Robustesse",spellId=1243,sourceUnit=nil,expirationTime=NOW+100,duration=3600}}
units.player={"Yann","WARLOCK",30}; IsPlayerSpell=function() return false end; fire("PLAYER_ENTERING_WORLD", false)
k, kind = ns.bestBuff("Anduin","PRIEST",40); print("unknown rank, 100 s left ->", k, kind); assert(kind~="refresh")
-- Short buff: a 10 min buff with 5 min left is NOT running out (last quarter only).
myAuras={{auraInstanceID=62,name="Mot de pouvoir : Robustesse",spellId=1243,sourceUnit=nil,points={32},expirationTime=NOW+290,duration=600}}
fire("PLAYER_ENTERING_WORLD", false)
k, kind = ns.bestBuff("Anduin","PRIEST",40); print("10 min buff, 290 s left ->", k, kind); assert(kind~="refresh")
-- Unsolicited renewal: nobody asked -> no thanks.
BuffDiggerDB.asked={}; local b2=#sent; myAuras[1].expirationTime=NOW+600; myAuras[1].sourceUnit="nameplate5"; fire("UNIT_AURA","player")
print("unsolicited renewal sends:", #sent-b2); assert(#sent==b2)
units.player={"Yann","PRIEST",40}; IsPlayerSpell=function(id) return id==1243 end

print("=== next-player key")
BOUND="F5"; C_UnitAuras.GetAuraDataBySpellName=function() return false end -- nobody has my Fortitude
ns.refreshWindow()
local nb=_G.BuffDiggerGiveNext
print("aimed at:", nb and nb.unit); assert(nb.unit, "the key should aim at someone lacking Fortitude")
ns.castOn(nb.unit); ns.refreshWindow(); local second=nb.unit; print("after a press, aimed at:", second); assert(second ~= "nameplate1")

print("=== checklist")
SlashCmdList.BUFFDIGGER("")
for key, d in pairs(BuffDiggerDB.confirmed) do print("confirmed", key, d) end
assert(BuffDiggerDB.confirmed.points and BuffDiggerDB.confirmed.expires)
print("SMOKE OK")
