-- Fake WoW API: just enough to run Buff Digger end to end (scenarios at the bottom).
-- Run from the repo root: uv run --no-project -q --with lupa python -I tests/run_smoke.py
local sent, events = {}, {}
local function obj() local o = {} ; return setmetatable(o, {__index=function(t,k)
  if type(k)=="string" and k:match("^%l") then return nil end -- a field, not a method: nil, as on a real frame
  if k=="IsShown" then return function(s) return s._shown end end
  if k=="SetShown" then return function(s,v) s._shown=v end end
  if k=="Show" then return function(s) s._shown=true end end
  if k=="Hide" then return function(s) s._shown=false end end
  if k=="GetChecked" then return function() return true end end
  if k=="GetStringHeight" then return function() return 60 end end
  if k=="GetWidth" then return function() return 140 end end
  if k=="SetSize" then return function(s,_,h) rawset(s,"_h",h) end end
  if k=="SetHeight" then return function(s,h) rawset(s,"_h",h) end end
  if k=="GetHeight" then return function(s) return rawget(s,"_h") or 0 end end
  if k=="GetCenter" then return function() return 0,0 end end
  if k=="SetScript" then return function(s,e,f) s["_"..e]=f end end
  if k=="HookScript" then return function(s,e,f) local h=rawget(s,"_hooks") or {}; rawset(s,"_hooks",h); h[e]=h[e] or {}; table.insert(h[e],f) end end
  if k=="SetVertexColor" then return function(s,r) rawset(s,"_red",r<1) end end
  if k=="SetText" then return function(s,t) rawset(s,"_t",t) end end
  if k=="GetParent" then return function(s) return rawget(s,"_parent") end end
  if k=="GetAttribute" then return function(s,a) return rawget(s,"_a_"..a) end end
  if k=="SetAttribute" then return function(s,a,v) rawset(s,"_a_"..a,v) end end
  if k=="RegisterForClicks" then return function(s,...) rawset(s,"_clicks",table.concat({...},",")) end end
  if k=="RegisterEvent" or k=="RegisterUnitEvent" then return function(s) if not rawget(s,"_reg") then rawset(s,"_reg",true); events[#events+1]=s end end end
  if k=="CreateFontString" or k=="CreateTexture" or k=="CreateAnimationGroup" or k=="CreateAnimation" then return function() return obj() end end
  if k=="CloseButton" then local c=obj(); rawset(t,k,c); return c end
  return function() end end}) end
CreateFrame=function(_,name,parent) local o=obj(); rawset(o,"_parent",parent); if name then _G[name]=o end; return o end
UIParent, Minimap, UISpecialFrames, GameTooltip = obj(), obj(), {}, obj()
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
-- Forever: "Jean Dupont" comes back as "Jean", "Dupont" (the last name where WoW puts the realm).
local function split(n) if not n then return nil end local f, l = n:match("^(%S+) (.+)$") if f then return f, l end return n end
UnitName=function(u) return split(units[u] and units[u][1]) end
UnitClass=function(u) return "x", units[u] and units[u][2] end
UnitLevel=function(u) return units[u] and units[u][3] end
GetNormalizedRealmName=function() return "Realm" end; GetRealmName=function() return "Realm" end; UnitFullName=function(u) local f, l = split(units[u][1]) return f, l or "Realm" end
UnitIsPlayer=function(u) return units[u]~=nil end; UnitExists=UnitIsPlayer
UnitIsUnit=function(a,b) return a==b end; UnitIsVisible=UnitIsPlayer; UnitIsConnected=function(u) return units[u]~=nil and not OFFLINE[u] end; OFFLINE={}; UnitIsDeadOrGhost=function() return false end; UnitIsFriend=function() return true end
C_NamePlate={GetNamePlates=function() return {} end,
  GetNamePlateForUnit=function() return {} end}
C_ChatInfo={SendChatMessage=function(m,c,_,t) sent[#sent+1]=c.." "..tostring(t)..": "..m end, RegisterAddonMessagePrefix=function() end, SendAddonMessage=function(p,m,c,t) sent[#sent+1]="ADDON>"..t..": "..m end}
TooltipDataProcessor=nil
MENUS={}; Menu={ModifyMenu=function(tag,f) MENUS[tag]=f end} -- the game's right-click menus (#17)
local ns={}
-- The addon may only create its own globals: a forgotten `local` fails here instead of leaking.
local addonEnv = setmetatable({}, {__index=_G, __newindex=function(_,k,v)
  if not (k:match("^BuffDigger") or k:match("^SLASH_BUFFDIGGER") or k:match("^BINDING_")) then error("addon sets global "..k, 2) end
  _G[k]=v end})
for _,f in ipairs{"Locales","Data","BuffDigger","UI","Comm"} do assert(setfenv(loadfile(DIR..f..".lua"), addonEnv))("BuffDigger", ns) end
local function fire(ev,...) for _,f in ipairs(events) do if f._OnEvent then f._OnEvent(f,ev,...) end end end
fire("ADDON_LOADED","BuffDigger"); fire("PLAYER_LOGIN"); fire("PLAYER_ENTERING_WORLD", true); fire("NAME_PLATE_UNIT_ADDED","nameplate1"); fire("NAME_PLATE_UNIT_ADDED","nameplate2"); print("nearby:", #ns.nearbyUnits())
-- Login warning: checked 10 s later, once plates showed; friendly players in sight -> no false "off".
do local said, p0 = false, print; print=function(...) for _,v in ipairs({...}) do if tostring(v):find("nameplates are off") then said=true end end p0(...) end
  runTimers(); print=p0; assert(not said, "no 'nameplates off' line while friendly plates show") end
-- 1. Warrior lacks everything: paladin 25 should offer Might (top pick), mage nothing.
print("paladin:", ns.bestBuff("Arthas","PALADIN",25)); print("mage:", ns.bestBuff("Jaina","MAGE",30))
ns.askBest()
-- 2. Arthas blesses me with Kings -> he may only REPLACE with Might (higher in my prefs).
myAuras[1]={auraInstanceID=7,name="Bénédiction des rois",spellId=20217,sourceUnit="nameplate1"}
fire("UNIT_AURA","player")
print("after kings:", ns.bestBuff("Arthas","PALADIN",25))
-- His blessing is framed in gold; his others warn they would replace it; nobody else's.
assert(ns.hisBlessing("Arthas")=="kings" and ns.hisBlessing("Jaina")==nil)
local fb=CreateFrame(); fb.icon=CreateFrame(); ns.styleBuff(fb,"kings","might","kings"); assert(fb.his._shown, "his blessing: gold frame")
ns.styleBuff(fb,"might","might","kings"); assert(not fb.his._shown, "another blessing: no frame")
ns.styleBuff(fb,"kings","might","kings"); ns.styleBuff(fb); assert(not fb.his._shown, "hint mode (no buff): frame gone")
local tip={}; GameTooltip.AddLine=function(_,t) tip[#tip+1]=t end
ns.buffTooltip(fb,"nameplate1","might"); print("tooltip:", table.concat(tip," / "))
assert(table.concat(tip,"\n"):find("Replaces the .- they gave you"), "warns it replaces his blessing")
units.nameplate9={"Turalyon","PALADIN",25}; tip={}; ns.buffTooltip(fb,"nameplate9","might")
assert(not table.concat(tip,"\n"):find("Replaces"), "another paladin replaces nothing")
tip={}; ns.buffTooltip(fb,"nameplate1","kings"); assert(table.concat(tip,"\n"):find("They gave you this one"))
GameTooltip.AddLine=nil
-- 3. Anti-nag: asking him again right away is refused.
ns.request("nameplate1")
SlashCmdList.BUFFDIGGER("spells"); SlashCmdList.BUFFDIGGER("")
ns.toggleWindow(); ns.refreshWindow()
for _,s in ipairs(sent) do print("SENT", s) end
BuffDiggerDB.language = "fr"
print("FR:", ns.message("new", "fortitude", "fr"))
print("EN:", ns.message("upgrade", "fortitude", "en"))
-- Every language has every kind and thanks; an unknown setting falls back to English.
for _, lang in ipairs(ns.LANGUAGES) do
  for _, kind in ipairs({ "new", "replace", "upgrade", "refresh" }) do
    for _, m in ipairs(ns.MESSAGES[lang[1]][kind]) do assert(select(2, m:gsub("%%s", "")) == 1, m) end
  end
  -- A request never thanks: the thank-you comes after the buff (ns.THANKS).
  for part, list in pairs(ns.MESSAGES[lang[1]]) do
    assert(#list > 0, lang[1] .. "." .. part)
    for _, m in ipairs(list) do
      if part == "hello" or part == "bye" then assert(not m:find("%%"), m) end
      for _, w in ipairs({ "[Tt]hank", "[Mm]erci", "[Dd]ank", "[Gg]racias", "[Gg]razie", "[Vv]aleu",
        "[Oo]brigad", "Спасибо", "спасибо", "[Бб]лагодар", "[Dd]zięk", "appreciated", "[Cc]heers", "Ty!" }) do
        assert(not m:find(w), lang[1] .. " request thanks: " .. m)
      end
    end
  end
  local t = ns.THANKS[lang[1]]; assert(#t.thanks > 0 and #t.bye > 0, lang[1] .. " thanks")
  print(lang[1], (ns.message("new", "might", lang[1]):gsub("|c%x+|H.-|h", ""):gsub("|h|r", "")), ns.thanks(lang[1]))
end
assert(ns.message("new", "might", "xx") and ns.thanks(nil))

SHIFT=true; ns.request("nameplate2"); units.nameplate3={"Anduin","PRIEST",40}; ns.request("nameplate3"); print("LAST", sent[#sent])
local prev; for i=1,6 do local m=ns.message("new","might","en"); assert(m~=prev,"same twice"); prev=m; print("EN"..i, (m:gsub("|c%x+|H.-|h","")):gsub("|h|r","")) end
print("FR", (ns.message("upgrade","kings","fr"):gsub("|c%x+|H.-|h",""):gsub("|h|r","")))
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
SHIFT=false; BuffDiggerDB.language="en"; BuffDiggerDB.asked={}; BuffDiggerDB.prefs.WARRIOR=nil
units.nameplate4={"Uther","PALADIN",30}
myAuras={}; fire("UNIT_AURA","player")
ns.request("nameplate4"); print("REQ", sent[#sent])
myAuras[1]={auraInstanceID=20,name="Bénédiction de puissance",spellId=19740,sourceUnit="nameplate4"}
fire("UNIT_AURA","player"); print("T0 emote first:", sent[#sent]); assert(sent[#sent]:find("EMOTE"))
runTimers(); print("T1 thank-you after the delay:", sent[#sent]); assert(sent[#sent]:find("WHISPER Uther"))
-- Asked in /say, giver known: the emote now, the /say thank-you waits for the next click
SHIFT=true; units.nameplate5={"Anduin","PRIEST",40}; ns.request("nameplate5"); SHIFT=false
myAuras[2]={auraInstanceID=21,name="Mot de pouvoir : Robustesse",spellId=1243,sourceUnit="nameplate5"}
local n=#sent; fire("UNIT_AURA","player"); print("emote now:", sent[#sent]); assert(sent[#sent]:find("EMOTE THANK Anduin"))
ns.flushThanks(); print("after click:", sent[#sent]); assert(sent[#sent]:find("SAY"))
-- Unknown giver, one open Fortitude request: nobody thanked (no guessing)
BuffDiggerDB.asked = { A = {at=time(), key="fortitude", channel="WHISPER"} }
local before=#sent; myAuras[3]={auraInstanceID=30,name="Mot de pouvoir : Robustesse",spellId=1243,sourceUnit=nil}; fire("UNIT_AURA","player"); runTimers()
print("unknown giver sent:", #sent-before); assert(#sent==before, "unknown giver must not thank")
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
myAuras={{auraInstanceID=51,name="Bénédiction de puissance",spellId=19834,sourceUnit=nil,points={30},expirationTime=NOW+3000,duration=3600}}
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
-- Recast 20 s after the last one (an upgrade I asked for right after it landed): thanked too.
BuffDiggerDB.asked.Anduin={at=time(), key="fortitude", channel="WHISPER", target="Anduin"}
b=#sent; myAuras[1].expirationTime=myAuras[1].expirationTime+20; fire("UNIT_AURA","player"); runTimers()
print("recast 20 s later:", sent[#sent]); assert(#sent>b and sent[#sent]:find("WHISPER Anduin"), "a quick recast I asked for should be thanked")
-- Another quick recast, that request already thanked: nothing (a recast alone never thanks).
b=#sent; myAuras[1].expirationTime=myAuras[1].expirationTime+20; fire("UNIT_AURA","player"); runTimers()
print("recast, nothing asked:", #sent-b); assert(#sent==b, "a recast nobody asked for must not thank")
-- A peer sees a refresh request (kind accepted).
units.player={"Yann","PRIEST",40}; IsPlayerSpell=function(id) return id==1243 end
b=#sent; fire("CHAT_MSG_ADDON","BuffDigger","REQ:fortitude:refresh","WHISPER","Zia-Realm"); print("refresh REQ -> ACK:", sent[#sent]); assert(sent[#sent]:find("ACK"))

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
-- Food from another player (mage food, table): not a buff, no thanks.
units.nameplate6={"Jaina","MAGE",40}; b2=#sent
myAuras[#myAuras+1]={auraInstanceID=63,name="Food",spellId=433,sourceUnit="nameplate6"}; fire("UNIT_AURA","player"); runTimers()
print("food sends:", #sent-b2); assert(#sent==b2, "eating must not thank")
-- Only the buff I asked this player for is thanked (eating, a buff nobody asked for: nothing).
units.nameplate7={"Tirion","PALADIN",40}; BuffDiggerDB.asked={Tirion={at=time(), key="kings", channel="WHISPER", target="Tirion"}}; b2=#sent
myAuras[#myAuras+1]={auraInstanceID=64,name="Bénédiction de puissance",spellId=19740,sourceUnit="nameplate7",expirationTime=NOW+300,duration=300}
fire("UNIT_AURA","player"); runTimers(); print("asked Kings, got Might, sends:", #sent-b2); assert(#sent==b2, "another buff than the one asked must not thank")
BuffDiggerDB.asked={}; myAuras[#myAuras].auraInstanceID=65; myAuras[#myAuras].expirationTime=NOW+250
units.nameplate7={"Turalyon","PALADIN",40}; fire("UNIT_AURA","player"); runTimers()
print("buff nobody asked for sends:", #sent-b2); assert(#sent==b2, "a buff nobody asked for must not thank")
table.remove(myAuras); units.nameplate7=nil; fire("UNIT_AURA","player")
-- Ghost Wolf: my Fortitude comes back with a new instance ID, from a priest I just asked for
-- something else. Same buff, not a landing: no thanks.
BuffDiggerDB.asked={Anduin={at=time(), key="spirit", channel="WHISPER", target="Anduin"}}
local fort=myAuras[1]; b2=#sent
myAuras[1]={auraInstanceID=99,name=fort.name,spellId=fort.spellId,sourceUnit="nameplate5",points=fort.points,expirationTime=fort.expirationTime,duration=fort.duration}
fire("UNIT_AURA","player"); runTimers(); print("re-indexed aura sends:", #sent-b2); assert(#sent==b2, "a re-indexed aura must not thank")
-- A stale token pointing at the mage I asked for Intellect, on a real new Fortitude: a mage
-- can't give it, no thanks either.
BuffDiggerDB.asked={Jaina={at=time(), key="intellect", channel="WHISPER", target="Jaina"}}
myAuras[1].sourceUnit="nameplate6"; myAuras[1].auraInstanceID=100; myAuras[1].expirationTime=NOW+3000; fire("UNIT_AURA","player"); runTimers()
print("mage giving Fortitude sends:", #sent-b2); assert(#sent==b2, "wrong-class giver must not thank")
-- Same stale token, but I did ask a priest for Fortitude: the giver is unknown, so no guessing.
BuffDiggerDB.asked={Anduin={at=time(), key="fortitude", channel="WHISPER", target="Anduin"}}
myAuras[1].auraInstanceID=101; myAuras[1].expirationTime=NOW+3500; fire("UNIT_AURA","player"); runTimers()
print("unknown giver, asked priest:", #sent-b2); assert(#sent==b2, "an unknown giver must not thank the player I asked")
-- No unit token at all: same.
myAuras[1].sourceUnit=nil; myAuras[1].auraInstanceID=102; myAuras[1].expirationTime=NOW+3550; fire("UNIT_AURA","player"); runTimers()
print("no source, asked priest:", #sent-b2); assert(#sent==b2, "a buff with no giver must not thank")
-- My own cast of the buff I asked for: nobody thanked, and the request stays open.
units.player={"Yann","PRIEST",40}
myAuras[1].sourceUnit="player"; myAuras[1].auraInstanceID=103; myAuras[1].expirationTime=NOW+3580; fire("UNIT_AURA","player"); runTimers()
print("self-buff sends:", #sent-b2); assert(#sent==b2, "my own buff must not thank")
-- A stranger priest gives it first: no thanks, and my request to Anduin stays open.
units.nameplate8={"Velen","PRIEST",40}
myAuras[1].sourceUnit="nameplate8"; myAuras[1].auraInstanceID=104; myAuras[1].expirationTime=NOW+3590; fire("UNIT_AURA","player"); runTimers()
print("stranger gives it:", #sent-b2); assert(#sent==b2, "a buff from someone I didn't ask must not thank")
-- Anduin answers after all: thanked, once.
myAuras[1].sourceUnit="nameplate5"; myAuras[1].expirationTime=NOW+3600; fire("UNIT_AURA","player"); runTimers()
print("asked priest answers:", sent[#sent]); assert(sent[#sent]:find("WHISPER Anduin"), "the asked player giving the asked buff is thanked")
units.nameplate8=nil
-- Time left hidden, aura re-indexed (shapeshift) while a request to its giver is open: no landing.
BuffDiggerDB.asked={Anduin={at=time(), key="fortitude", channel="WHISPER", target="Anduin"}}; b2=#sent
myAuras[1].auraInstanceID=105; myAuras[1].expirationTime=nil; myAuras[1].duration=nil; fire("UNIT_AURA","player")
myAuras[1].auraInstanceID=106; fire("UNIT_AURA","player"); runTimers()
print("hidden time, re-indexed:", #sent-b2); assert(#sent==b2, "a re-indexed aura with hidden time must not thank")
-- Time hidden, but another priest's cast replaces it (new instance): a landing, Velen asked -> thanked.
units.nameplate8={"Velen","PRIEST",40}; BuffDiggerDB.asked={Velen={at=time(), key="fortitude", channel="WHISPER", target="Velen"}}; b2=#sent
myAuras[1].auraInstanceID=107; myAuras[1].sourceUnit="nameplate8"; fire("UNIT_AURA","player"); runTimers()
print("hidden time, other caster:", sent[#sent]); assert(#sent>b2 and sent[#sent]:find("WHISPER Velen"), "a new caster replacing my buff is a landing")
units.nameplate8=nil
units.player={"Yann","PRIEST",40}; IsPlayerSpell=function(id) return id==1243 end

print("=== next-player key")
BOUND="F5"; C_UnitAuras.GetAuraDataBySpellName=function() return false end -- nobody has my Fortitude
ns.refreshWindow()
local nb=_G.BuffDiggerGiveNext
print("aimed at:", nb and nb.unit); assert(nb.unit, "the key should aim at someone lacking Fortitude")
ns.castOn(nb.unit); ns.refreshWindow(); local second=nb.unit; print("after a press, aimed at:", second); assert(second ~= "nameplate1")

-- Out of range: listed greyed, never aimed at; the key goes to someone in range.
C_Spell.IsSpellInRange=function(_, u) return u ~= "nameplate1" end
NOW=NOW+60; ns.refreshWindow(); print("nameplate1 too far -> key aims at:", nb.unit); assert(nb.unit and nb.unit ~= "nameplate1")
C_Spell.IsSpellInRange=function() return false end
ns.refreshWindow(); print("everyone too far -> key aims at:", rawget(nb,"unit")); assert(rawget(nb,"unit") == nil)
C_Spell.IsSpellInRange=nil

-- The cast check: a spell sent by hand after a click is not a success; one sent during the click is.
-- Secure buttons hear the release only ("AnyUp", ns.secureClicks), so a click is one release.
local function click(b, sendSpell)
  for _,f in ipairs(b._hooks.PreClick) do f(b,"LeftButton",false) end
  if sendSpell then fire("UNIT_SPELLCAST_SENT","player","Arthas","guid",1243) end
  for _,f in ipairs(b._hooks.PostClick) do f(b,"LeftButton",false) end
end
BuffDiggerDB.confirmed.cast=nil
click(nb, false); fire("UNIT_SPELLCAST_SENT","player","Arthas","guid",1243)
print("manual cast after a dead click -> cast confirmed?", BuffDiggerDB.confirmed.cast); assert(not BuffDiggerDB.confirmed.cast)
click(nb, true); print("cast during the click -> confirmed:", BuffDiggerDB.confirmed.cast); assert(BuffDiggerDB.confirmed.cast)
-- The next-player key ignores a press (a CLICK binding may send one): no cast until the release.
local rc, rn, hit = ns.castOn, ns.notice, false; ns.castOn=function() hit=true end; ns.notice=function() hit=true end
for _,f in ipairs(nb._hooks.PostClick) do f(nb,"LeftButton",true) end; ns.castOn, ns.notice = rc, rn; assert(not hit, "key press: nothing")

-- In the window: a far player is listed last, red icons, and his row casts nothing.
local gw=_G.BuffDiggerGive; BuffDiggerDB.give=true; ns.applyWindows()
C_Spell.IsSpellInRange=function(_, u) return u ~= "nameplate1" end
NOW=NOW+60 -- the casts on Arthas above skip him for 10 s
ns.refreshWindow()
local last; for _,r in ipairs(gw.rows) do if r._shown then last=r end end
print("last row:", last.unit, last.buffs[1]:GetAttribute("type")); assert(last.unit=="nameplate1" and last.buffs[1]:GetAttribute("type")==nil)
-- Like Get buffs: icons, no spell name on the line, the name targets them, the tooltip says it all.
local r1=gw.rows[1]; print("give row 1:", rawget(r1.text,"_t"))
assert(not rawget(r1.text,"_t"):find("Robustesse") and r1.buffs[1]._shown, "icon, no spell name on the line")
assert(r1:GetAttribute("*type1")=="macro" and r1:GetAttribute("macrotext")=="/target "..UnitName(r1.unit), "name click targets")
local tip={}; local realAdd=GameTooltip.AddLine; GameTooltip.AddLine=function(_,t) tip[#tip+1]=t end
r1.buffs[1]._OnEnter(r1.buffs[1]); GameTooltip.AddLine=realAdd; print("give tooltip:", table.concat(tip," / "))
assert(tip[1]=="Mot de pouvoir : Robustesse" and tip[#tip]=="Click: cast it.", "tooltip: spell, rank, what a click does")
assert(gw.rows[1].buffs[1]:GetAttribute("type")=="macro" and gw.rows[1].unit~="nameplate1")
print("row 1 macro:", gw.rows[1].buffs[1]:GetAttribute("macrotext"))
-- Aimed by name (no realm, /target), cast only on a friendly living target, previous target back.
assert(gw.rows[1].buffs[1]:GetAttribute("macrotext"):find("^/target [^\n]+\n/cast %[help,nodead%] Mot de pouvoir : Robustesse\n/targetlasttarget$"))
-- A click in the window does not hide that player (the list used to empty this way).
local clicked=gw.rows[1].unit; click(gw.rows[1].buffs[1], false); ns.refreshWindow()
local still=false; for _,r in ipairs(gw.rows) do if r._shown and r.unit==clicked then still=true end end
print("clicked player still listed:", still); assert(still)
C_Spell.IsSpellInRange=nil

print("=== checklist")
SlashCmdList.BUFFDIGGER("")
for key, d in pairs(BuffDiggerDB.confirmed) do print("confirmed", key, d) end
assert(BuffDiggerDB.confirmed.points and BuffDiggerDB.confirmed.expires)

-- Talented givers seen in Forever (2026-11-08): values above the base rank still give that rank.
local B = ns.BUFFS
assert(ns.rankOfValue(B.fortitude, 8) == 2 and ns.rankOfValue(B.fortitude, 10) == 2)
assert(ns.rankOfValue(B.fortitude, 26) == 3 and ns.rankOfValue(B.thorns, 7) == 2)
assert(ns.rankOfValue(B.intellect, 8) == nil and ns.rankOfValue(B.fortitude, 99) == nil)
print("rankOfValue talents OK")

print("=== nameplates: off / hint / best / all")
units.player={"Yann","SHAMAN",30}; IsPlayerSpell=function() return false end
myAuras={}; BuffDiggerDB.asked={}; fire("UNIT_AURA","player"); runTimers()
local plate, onPlate = {}, {}
C_NamePlate.GetNamePlateForUnit=function(u) if u=="nameplate1" then return plate end end
local mk=CreateFrame; CreateFrame=function(t,n,parent,...) local f=mk(t,n,parent,...); if parent==plate then onPlate[#onPlate+1]=f end; return f end
local function shownKeys() local out={} for _,x in ipairs(onPlate) do if x._shown then out[#out+1]=tostring(rawget(x,"key")) end end return out end
BuffDiggerDB.plates="all"; ns.refreshAll(); runTimers()
print("all:", table.concat(shownKeys(), ",")); assert(#shownKeys()==3, "might, kings, wisdom")
local b=#sent; onPlate[3]._OnClick(onPlate[3], "LeftButton"); print("3rd icon asks:", sent[#sent]); assert(#sent>b and BuffDiggerDB.asked.Arthas.key==onPlate[3].key)
for _, mode in ipairs({"best","hint"}) do
  BuffDiggerDB.plates=mode; BuffDiggerDB.asked={}; ns.refreshAll(); runTimers()
  print(mode..":", table.concat(shownKeys(), ",")); assert(#shownKeys()==1 and shownKeys()[1]=="nil")
end
BuffDiggerDB.plates="off"; ns.refreshAll(); runTimers(); print("off:", #shownKeys()); assert(#shownKeys()==0)
CreateFrame=mk; BuffDiggerDB.plates="best"
-- An old saved "icons = false" becomes "off".
local saved=BuffDiggerDB; BuffDiggerDB={icons=false}; fire("ADDON_LOADED","BuffDigger"); assert(BuffDiggerDB.plates=="off" and BuffDiggerDB.icons==nil); BuffDiggerDB=saved

print("=== Get buffs: one icon per buff, scrolling")
local w=_G.BuffDiggerNearby; BuffDiggerDB.nearby=true; ns.applyWindows()
local row=w.rows[1]; print("row 1:", row.text._t or "", "icons shown:", (row.buffs[1]._shown and 1 or 0)+(row.buffs[2]._shown and 1 or 0)+(row.buffs[3]._shown and 1 or 0))
local first=w.entries[1]; assert(#first.buffs>=1)
b=#sent; BuffDiggerDB.asked={}; local pick=row.buffs[#first.buffs]
for _,f in ipairs(pick._hooks.PostClick) do f(pick,"LeftButton",false) end -- a release: one request
-- The fix of 2026-11-09: release only, whatever ActionButtonUseKeyDown says.
for _,sb in ipairs({row, pick, _G.BuffDiggerGiveNext, _G.BuffDiggerGive.rows[1], _G.BuffDiggerGive.rows[1].buffs[1], _G.BuffDiggerRequests.rows[1].buffs[1]}) do
  assert(rawget(sb,"_clicks")=="AnyUp" and sb:GetAttribute("useOnKeyDown")==false, "secure clicks: AnyUp only")
end
local who=UnitName(first.unit); print("icon asks", who, "for", BuffDiggerDB.asked[who].key); assert(BuffDiggerDB.asked[who].key==pick.key); print("sent:", sent[b+1]); assert(#sent==b+2 and sent[b+1]:find("^ADDON"), "one request: addon REQ + whisper")
-- #14: the name targets them (any modifier), asks nothing; icons target only with targetOnAsk.
print("name click:", row:GetAttribute("*type1"), row:GetAttribute("macrotext"))
assert(row:GetAttribute("*type1")=="macro" and row:GetAttribute("macrotext")=="/target "..who)
b=#sent; for _,f in ipairs(row._hooks.PostClick) do f(row,"LeftButton",false) end; assert(#sent==b, "name click asks nothing")
assert(pick:GetAttribute("*type1")==nil and pick:GetAttribute("macrotext")==nil, "icon: no target by default")
BuffDiggerDB.targetOnAsk=true; ns.refreshWindow(); assert(pick:GetAttribute("macrotext")=="/target "..who, "icon targets with the option")
BuffDiggerDB.targetOnAsk=false; ns.refreshWindow(); assert(pick:GetAttribute("*type1")==nil)
-- The token went to someone else while the list sat under the cursor: the icon asks nobody.
local wasP=units[first.unit]; units[first.unit]={"Intrus","PALADIN",30}; b=#sent; BuffDiggerDB.asked={}
for _,f in ipairs(pick._hooks.PostClick) do f(pick,"LeftButton",false) end; units[first.unit]=wasP
assert(#sent==b and not BuffDiggerDB.asked.Intrus, "stale token: no request")
-- "Only those with something better": the players whose buffs I all have leave the list.
local realBest, n0 = ns.bestBuff, #w.entries
ns.bestBuff=function(name, ...) if name==who then return nil end return realBest(name, ...) end -- I have all of who's buffs
ns.refreshWindow(); assert(#w.entries==n0 and w.entries[#w.entries].order==2, "shown last by default")
BuffDiggerDB.nearbyUseful=true; ns.refreshWindow()
for _,e in ipairs(w.entries) do assert(UnitName(e.unit)~=who, "nothing better: hidden") end
print("nothing better:", who, "hidden, entries", n0, "->", #w.entries); assert(#w.entries==n0-1)
BuffDiggerDB.nearbyUseful=false; ns.bestBuff=realBest; ns.refreshWindow()
-- 15 paladins around: 10 rows, the wheel shows the rest.
for i=10,24 do units["nameplate"..i]={"Pal"..i,"PALADIN",30}; fire("NAME_PLATE_UNIT_ADDED","nameplate"..i) end; runTimers(); ns.refreshWindow()
print("entries:", #w.entries, "offset:", w.offset); assert(#w.entries>10)
w._OnMouseWheel(w,-1); print("after wheel down, offset:", w.offset); assert(w.offset==1)
w._OnMouseWheel(w,-100); assert(w.offset==#w.entries-10); w._OnMouseWheel(w,100); assert(w.offset==0)
print("arrows: up", w.up._shown, "down", w.down._shown); assert(not w.up._shown and w.down._shown)
-- Taller window: more rows show, the down arrow goes once everyone fits.
w:SetSize(290, 40+20*20); w._OnSizeChanged(w, 290, 440); assert(BuffDiggerDB.sizes.BuffDiggerNearby[2]==440); local n=0; for _,r in ipairs(w.rows) do if r._shown then n=n+1 end end
print("rows at 440 px:", n, "down arrow:", w.down._shown); assert(n==#w.entries and not w.down._shown)
w.lock._OnClick(w.lock); assert(BuffDiggerDB.lockWindows and not w.grip._shown, "padlock locks: no grip")
w.lock._OnClick(w.lock); assert(not BuffDiggerDB.lockWindows and w.grip._shown, "padlock unlocks")
-- The padlock of one window locks both, at once (even in combat: nothing secure).
InCombatLockdown=function() return true end; local gw=_G.BuffDiggerGive; gw.lock._OnClick(gw.lock)
assert(not w.grip._shown and not gw.grip._shown, "both locked at once"); gw.lock._OnClick(gw.lock); InCombatLockdown=function() return false end
-- Give buffs scrolls too: a scrolled row casts on the player it now shows.
units.player={"Yann","PRIEST",40}; IsPlayerSpell=function(id) return id==1243 end
local realAura=C_UnitAuras.GetAuraDataBySpellName; C_UnitAuras.GetAuraDataBySpellName=function() return nil end -- nobody has Fortitude
local g=_G.BuffDiggerGive; BuffDiggerDB.give=true; ns.applyWindows()
print("give entries:", #g.entries); assert(#g.entries>10 and g.down._shown, "Give buffs: more than 10, down arrow")
-- Its token goes to someone else before the scroll: the row still aims at the name it shows.
-- Same for an entry never shown yet (row 10 after one notch shows entry 11).
local second, eleventh = g.entries[2], g.entries[11]; local shown, shown11 = UnitName(second.unit), UnitName(eleventh.unit)
local was, was11 = units[second.unit], units[eleventh.unit]
units[second.unit]={"Intrus","WARRIOR",40}; units[eleventh.unit]={"Bob","WARRIOR",40}
g._OnMouseWheel(g,-1); assert(g.offset==1 and g.rows[1].entry==second and g.rows[10].entry==eleventh)
assert(g.rows[1].buffs[1]:GetAttribute("macrotext"):find("^/target "..shown.."\n"), "scrolled row aims at the name it shows")
assert(g.rows[10].buffs[1]:GetAttribute("macrotext"):find("^/target "..shown11.."\n"), "newly shown row too")
units[second.unit], units[eleventh.unit] = was, was11
g._OnMouseWheel(g,100); BuffDiggerDB.give=false; ns.applyWindows(); C_UnitAuras.GetAuraDataBySpellName=realAura
print("=== #13 Requests window (buffer side)")
units.player={"Yann","PRIEST",40}; IsPlayerSpell=function(id) return id==1243 end
local rq=_G.BuffDiggerRequests; local played, count=0, nil
PlaySound=function() played=played+1 end; SOUNDKIT.IG_PLAYER_INVITE=2
local realCount=ns.showRequestCount; ns.showRequestCount=function(n) count=n; realCount(n) end
BuffDiggerDB.requests=false; ns.applyWindows(); local c0=count -- Zia's refresh request above still waits
fire("CHAT_MSG_ADDON","BuffDigger","REQ:fortitude:new","WHISPER","Arthas-Realm")
print("window:", rq._shown, "count:", count, "sounds:", played)
assert(not rq._shown and count==c0+1 and played==1, "a request rings and counts, never pops the window")
BuffDiggerDB.requestSound=false
fire("CHAT_MSG_ADDON","BuffDigger","REQ:fortitude:new","WHISPER","Jaina-Realm"); assert(count==c0+2 and played==1, "sound off")
ns.toggleRequests(); assert(rq._shown and BuffDiggerDB.requests)
fire("CHAT_MSG_ADDON","BuffDigger","REQ:fortitude:new","WHISPER","Ghost-Realm") -- out of sight
fire("CHAT_MSG_ADDON","BuffDigger","REQ:fortitude:upgrade","WHISPER","Pal10-Realm")
local byName, lastSeen = {}, nil
for i,r in ipairs(rq.rows) do if r._shown then byName[r.entry.request.name]=r; lastSeen=r; print("row", i, r.entry.request.name, r.buffs[1]:GetAttribute("type")) end end
assert(rq.rows[1].entry.request.name=="Arthas" and rq.rows[1].buffs[1]:GetAttribute("type")=="macro", "in sight first, in arrival order")
assert(byName.Ghost.buffs[1]:GetAttribute("type")==nil and not lastSeen.entry.buffs[1].spell, "out of sight: after, not castable")
click(byName.Pal10.buffs[1], false); ns.refreshIncoming(); assert(count==c0+3, "clicking a higher-rank request closes it")
for _,r in ipairs(rq.rows) do assert(not (r._shown and r.entry.request.name=="Pal10")) end
InCombatLockdown=function() return true end; fire("PLAYER_REGEN_DISABLED"); assert(not rq._shown, "hidden in combat")
InCombatLockdown=function() return false end; fire("PLAYER_REGEN_ENABLED"); assert(rq._shown, "back after combat")
rq.CloseButton._hooks.OnClick[1](); assert(BuffDiggerDB.requests==false)
BuffDiggerDB.requestSound=true; ns.showRequestCount=realCount

print("=== #13 silent request, re-ask offered (requester side)")
units.player={"Yann","WARRIOR",21}; IsPlayerSpell=function() return false end
myAuras={}; fire("UNIT_AURA","player"); runTimers(); BuffDiggerDB.asked={}; BuffDiggerDB.peers={Pal11=time(), Pal13=time()}
b=#sent; ns.request("nameplate11"); runTimers()
for i=b+1,#sent do print("PEER", sent[i]) end
assert(#sent==b+1 and sent[b+1]:find("^ADDON>Pal11"), "a peer gets only the silent request, no whisper after a while")
assert(BuffDiggerDB.asked.Pal11.silent and not ns.unanswered("Pal11"))
b=#sent; ns.request("nameplate11"); assert(#sent==b, "too early to ask again")
BuffDiggerDB.asked.Pal11.at=time()-31; ns.refreshWindow()
local marked; for _,e in ipairs(w.entries) do if e.unit=="nameplate11" then marked=e.text:find("no answer") end end
print("Get buffs offers a re-ask:", marked ~= nil); assert(marked, "Get buffs proposes the whisper")
b=#sent; ns.request("nameplate11"); print("re-ask:", sent[#sent])
assert(#sent==b+1 and sent[b+1]:find("^WHISPER Pal11"), "the click re-asks by whisper only")
assert(not ns.unanswered("Pal11"), "offered once")
BuffDiggerDB.asked.Pal12={at=time()-31, key="might", silent=true, thanked=true}; assert(not ns.unanswered("Pal12"), "buff came: nothing to offer")
IsInInstance=function() return true end; b=#sent; ns.request("nameplate13")
assert(#sent==b+1 and sent[b+1]:find("^WHISPER Pal13"), "in an instance: whisper at once"); IsInInstance=function() return false end

print("=== #15 marker above a Buff Digger user asking me")
units.player={"Yann","PRIEST",40}; IsPlayerSpell=function(id) return id==1243 end
local plates, markerOf = {}, {}
C_NamePlate.GetNamePlateForUnit=function(u) plates[u]=plates[u] or {}; return plates[u] end
CreateFrame=function(t,n,parent,...) local f=mk(t,n,parent,...); for u,p in pairs(plates) do if parent==p and t=="Frame" then markerOf[u]=f end end; return f end
local function marked(u) return markerOf[u] and markerOf[u]._shown or false end
C_UnitAuras.GetAuraDataBySpellName=function() return false end
units.nameplate40={"Lia","WARRIOR",40}; fire("NAME_PLATE_UNIT_ADDED","nameplate40"); runTimers()
fire("CHAT_MSG_ADDON","BuffDigger","REQ:fortitude:new","WHISPER","Lia-Realm")
print("marker on REQ:", marked("nameplate40")); assert(marked("nameplate40"))
fire("NAME_PLATE_UNIT_REMOVED","nameplate40"); assert(not marked("nameplate40"), "plate gone: marker hidden at once"); runTimers()
fire("NAME_PLATE_UNIT_ADDED","nameplate40"); runTimers(); assert(marked("nameplate40"), "plate back: marker back")
fire("PLAYER_REGEN_DISABLED"); assert(not marked("nameplate40"), "combat: hidden"); fire("PLAYER_REGEN_ENABLED"); runTimers(); assert(marked("nameplate40"))
-- They got the buff: gone.
C_UnitAuras.GetAuraDataBySpellName=function(u) if u=="nameplate40" then return {} end return false end
ns.refreshIncoming(); assert(not marked("nameplate40"), "got the buff: marker gone"); C_UnitAuras.GetAuraDataBySpellName=function() return false end
-- Expiry (REQUEST_TTL).
units.nameplate41={"Max","WARRIOR",40}; fire("NAME_PLATE_UNIT_ADDED","nameplate41"); runTimers()
fire("CHAT_MSG_ADDON","BuffDigger","REQ:fortitude:new","WHISPER","Max-Realm"); assert(marked("nameplate41"))
local realTime=time; time=function() return realTime()+91 end; ns.refreshIncoming(); time=realTime
assert(not marked("nameplate41"), "expired: marker gone")
-- A higher-rank request clicked in Requests: closed, marker gone.
units.nameplate42={"Ned","WARRIOR",40}; fire("NAME_PLATE_UNIT_ADDED","nameplate42"); runTimers()
fire("CHAT_MSG_ADDON","BuffDigger","REQ:fortitude:upgrade","WHISPER","Ned-Realm"); assert(marked("nameplate42"))
ns.toggleRequests(); local ned; for _,r in ipairs(_G.BuffDiggerRequests.rows) do if r._shown and r.entry.request.name=="Ned" then ned=r end end
click(ned.buffs[1], false); ns.refreshIncoming(); assert(not marked("nameplate42"), "clicked: marker gone"); ns.toggleRequests()
-- Setting off: no marker.
BuffDiggerDB.requestMarkers=false
units.nameplate43={"Oli","WARRIOR",40}; fire("NAME_PLATE_UNIT_ADDED","nameplate43"); runTimers()
fire("CHAT_MSG_ADDON","BuffDigger","REQ:fortitude:new","WHISPER","Oli-Realm"); assert(not marked("nameplate43"), "setting off: none")
BuffDiggerDB.requestMarkers=true; CreateFrame=mk
-- A spell with no target (Lightning Bolt with nothing selected): no error (seen in game 2026-11-09).
fire("UNIT_SPELLCAST_SENT","player",nil,"guid",403)
fire("UNIT_SPELLCAST_SENT","player","","guid",403) -- an empty target must not break either
print("=== Give buffs, a paladin: one icon per blessing they lack, in THEIR class's order")
units.player={"Yann","PALADIN",40}; IsPlayerSpell=function(id) return id==19740 or id==20217 or id==19742 end
units.nameplate60={"Garrosh","WARRIOR",40}; fire("NAME_PLATE_UNIT_ADDED","nameplate60"); runTimers()
local realAura2=C_UnitAuras.GetAuraDataBySpellName; C_UnitAuras.GetAuraDataBySpellName=function() return nil end
local gp=_G.BuffDiggerGive; BuffDiggerDB.give=true; ns.applyWindows()
local function rowOf(u) gp._OnMouseWheel(gp,100); for _=1,#gp.entries do for _,r in ipairs(gp.rows) do if r._shown and r.unit==u then return r end end; gp._OnMouseWheel(gp,-1) end end
local gr=rowOf("nameplate60"); assert(gr, "Garrosh listed")
-- Warrior: Might then Kings (Wisdom is not on a warrior's list), each icon its own spell.
assert(gr.buffs[1].key=="might" and gr.buffs[2].key=="kings" and not gr.buffs[3]._shown, "their order, only what they want")
assert(gr.buffs[2]:GetAttribute("macrotext"):find("/cast %[help,nodead%] Bénédiction des rois\n"), "2nd icon casts Kings")
local tip={}; local realAdd=GameTooltip.AddLine; GameTooltip.AddLine=function(_,t) tip[#tip+1]=t end
units.nameplate60={"Intrus","WARRIOR",40}; gr.buffs[2]._OnEnter(gr.buffs[2]); GameTooltip.AddLine=realAdd; units.nameplate60={"Garrosh","WARRIOR",40}
assert(tip[#tip]=="Click: cast it.", "tooltip: no name, the line shows it")
-- Too far: icons red, tooltip says so, nothing cast.
C_Spell.IsSpellInRange=function(_, u) return u ~= "nameplate60" end; ns.refreshWindow(); gr=rowOf("nameplate60")
assert(gr.buffs[1]:GetAttribute("type")==nil and gr.buffs[2]:GetAttribute("type")==nil, "too far: no cast")
assert(gr.buffs[1].icon._red and gr.buffs[2].icon._red, "too far: red icons")
tip={}; GameTooltip.AddLine=function(_,t) tip[#tip+1]=t end; gr.buffs[1]._OnEnter(gr.buffs[1]); GameTooltip.AddLine=realAdd
assert(tip[#tip]=="Too far", "too far: the tooltip says so"); C_Spell.IsSpellInRange=nil
ns.refreshWindow(); assert(not rowOf("nameplate60").buffs[1].icon._red, "back in range: not red")
-- My blessing already on them: a paladin keeps one per target, offer nothing.
C_UnitAuras.GetAuraDataBySpellName=function(u, name) if u=="nameplate60" and name=="Bénédiction de puissance" then return {sourceUnit="player"} end end
ns.refreshWindow(); assert(not rowOf("nameplate60"), "my blessing on them: nothing")
-- One of their auras unreadable (Kings readable, missing): stay silent rather than guess.
C_UnitAuras.GetAuraDataBySpellName=function(u, name) if u=="nameplate60" and name=="Bénédiction de puissance" then error("secret") end end
ns.refreshWindow(); assert(not rowOf("nameplate60"), "unreadable: nothing")
C_UnitAuras.GetAuraDataBySpellName=realAura2; BuffDiggerDB.give=false; ns.applyWindows(); fire("NAME_PLATE_UNIT_REMOVED","nameplate60"); units.nameplate60=nil

print("=== Forever names: first name + last name, with a space")
-- In game (2026-11-09) UnitName gives "Jean", "Dupont": the fake API does the same (split above).
units.player={"Yann","PRIEST",40}; IsPlayerSpell=function(id) return id==1243 end; BuffDiggerDB.asked={}
units.nameplate50={"Jean Dupont","WARRIOR",40}; fire("NAME_PLATE_UNIT_ADDED","nameplate50"); runTimers()
-- Give buffs: the whole name on the line; the macro targets the first name (what worked in game).
BuffDiggerDB.give=true; ns.applyWindows(); local gv=_G.BuffDiggerGive
gv._OnMouseWheel(gv,-100); local jean; for _,r in ipairs(gv.rows) do if r._shown and r.unit=="nameplate50" then jean=r end end
assert(jean, "Jean Dupont listed in Give buffs"); print("line:", jean.text._t, "| macro:", (jean.buffs[1]:GetAttribute("macrotext"):gsub("\n"," | ")))
assert(jean.text._t:find("Jean Dupont", 1, true), "whole name shown in Give buffs")
assert(jean.buffs[1]:GetAttribute("macrotext"):find("^/target Jean\n"), "macro targets the first name")
assert(jean.entry.who=="Jean Dupont", "aim frozen on the whole name")
-- Setting reads off, but a friendly player's plate is in sight: they are on (seen in Forever).
local cv=CVARS.nameplateShowFriends; CVARS.nameplateShowFriends="0"
assert(ns.friendlyPlatesOn(), "a friendly plate in sight means friendly nameplates are on"); CVARS.nameplateShowFriends=cv
-- A cast sent at "Jean-Dupont" skips them for a while.
fire("UNIT_SPELLCAST_SENT","player","Jean-Dupont","guid",1243); ns.refreshWindow()
for _,e in ipairs(_G.BuffDiggerGive.entries) do assert(e.unit~="nameplate50", "just buffed: skipped") end
-- Same if the game names the target "Jean" only (format not known yet, recette 45).
NOW=NOW+60; ns.refreshWindow(); local back; for _,e in ipairs(_G.BuffDiggerGive.entries) do back = back or e.unit=="nameplate50" end
assert(back, "listed again once the skip is over")
fire("UNIT_SPELLCAST_SENT","player","Jean","guid",1243); ns.refreshWindow()
for _,e in ipairs(_G.BuffDiggerGive.entries) do assert(e.unit~="nameplate50", "spell sent at \"Jean\": skipped too") end
BuffDiggerDB.give=false; ns.applyWindows()
-- A request from "Jean-Dupont": shown as "Jean Dupont", in sight, ACK back to "Jean-Dupont".
BuffDiggerDB.acceptRequests=true; BuffDiggerDB.requests=true; ns.applyWindows()
fire("CHAT_MSG_ADDON","BuffDigger","REQ:fortitude:new","WHISPER","Jean-Dupont"); ns.refreshIncoming()
local rq; for _,r in ipairs(_G.BuffDiggerRequests.rows) do if r._shown and r.entry.request.name=="Jean Dupont" then rq=r end end
assert(rq and rq.unit=="nameplate50" and rq.buffs[1]:GetAttribute("macrotext"):find("^/target Jean\n"), "request from a two-word name")
print("ACK to:", sent[#sent]); assert(sent[#sent]=="ADDON>Jean-Dupont: ACK")
assert(ns.isPeer("Jean Dupont"), "known Buff Digger user by the whole name")
BuffDiggerDB.requests=false; ns.applyWindows()
-- Asking them: the whisper goes to "Marie-Curie" (what worked in game), the request is kept as "Marie Curie".
units.player={"Yann","WARRIOR",21}; units.nameplate51={"Marie Curie","PALADIN",40}; fire("NAME_PLATE_UNIT_ADDED","nameplate51")
-- Get buffs shows her whole name.
BuffDiggerDB.nearby=true; ns.applyWindows(); ns.refreshWindow(); local gt
for _,e in ipairs(_G.BuffDiggerNearby.entries) do if e.unit=="nameplate51" then gt=e end end
print("Get buffs line:", gt and gt.text); assert(gt and gt.text:find("Marie Curie", 1, true), "whole name shown in Get buffs")
BuffDiggerDB.nearby=false; ns.applyWindows()
BuffDiggerDB.asked={}; BuffDiggerDB.peers={}; b=#sent; ns.request("nameplate51"); print("ask:", sent[b+1], sent[b+2])
assert(sent[b+1]:find("^ADDON>Marie%-Curie:") and sent[b+2]:find("^WHISPER Marie%-Curie:"), "silent request and whisper to Marie-Curie")
assert(BuffDiggerDB.asked["Marie Curie"], "request kept under the whole name")
-- Marie buffs me: thanked by the whole name; the emote gets the first name (what worked in game).
myAuras[#myAuras+1]={auraInstanceID=500,name="Bénédiction de puissance",spellId=19740,sourceUnit="nameplate51",expirationTime=NOW+600,duration=600}
b=#sent; fire("UNIT_AURA","player"); runTimers(); for i=b+1,#sent do print("thanks:", sent[i]) end
local emote, whisper; for i=b+1,#sent do emote = emote or sent[i]=="EMOTE THANK Marie"; whisper = whisper or sent[i]:find("^WHISPER Marie%-Curie:") end
assert(emote and whisper, "Marie Curie thanked: /thank Marie, whisper to Marie-Curie")
print("=== Group (#16): members first under a header, even without a nameplate")
units.player={"Yann","WARRIOR",21}; BuffDiggerDB.asked={}; BuffDiggerDB.nearbyUseful=false
units.party1={"Uther","PALADIN",40}                                          -- no nameplate: far away, or in an instance
units.party2={"Anduin","PRIEST",40}; units.nameplate70=units.party2; fire("NAME_PLATE_UNIT_ADDED","nameplate70") -- a member's own plate
IsInGroup=function() return true end; IsInRaid=function() return false end; GetNumSubgroupMembers=function() return 2 end
local realIsUnit=UnitIsUnit; UnitIsUnit=function(a,b) return a==b or (a=="nameplate70" and b=="party2") end
local listed=ns.listUnits(); assert(listed[1]=="party1" and listed[2]=="party2", "members first")
for _,u in ipairs(listed) do assert(u~="nameplate70", "a member's plate is not listed twice") end
UnitIsUnit=realIsUnit -- Forever: nameplate vs party token never matches; the name still does
for _,u in ipairs(ns.listUnits()) do assert(u~="nameplate70", "a member's plate is not listed twice, by name") end
UnitIsUnit=function(a,b) return a==b or (a=="nameplate70" and b=="party2") end
BuffDiggerDB.nearby=true; ns.applyWindows(); local nw=_G.BuffDiggerNearby
local e=nw.entries; print("Get buffs:", e[1].text, e[2].who, e[3].who, e[4].text)
assert(e[1].header and e[1].text=="Group (2)" and e[2].group and e[3].group and e[4].header and e[4].text=="Around", "Group (2), members, then Around")
nw._OnMouseWheel(nw,100); ns.refreshWindow(); local hr=nw.rows[1]
assert(hr.text._t=="Group (2)" and not hr.buffs[1]._shown and hr:GetAttribute("macrotext")==nil, "header row: no icon, no click")
BuffDiggerDB.nearby=false; ns.applyWindows()
-- An offline member: nowhere. One out of sight: listed, but greyed in Give buffs and never asked by the key.
units.party3={"Tirion","PALADIN",40}; OFFLINE.party3=true; GetNumSubgroupMembers=function() return 3 end
for _,u in ipairs(ns.listUnits()) do assert(u~="party3", "offline member skipped") end
OFFLINE.party3=nil; local realVis=UnitIsVisible; UnitIsVisible=function(u) return u~="party3" and realVis(u) end
assert(ns.tooFar(19740,"party3") and not ns.tooFar(19740,"party2"), "member out of sight: too far")
BuffDiggerDB.asked={}; ns.askBest(); assert(not BuffDiggerDB.asked.Tirion, "the key never asks a member out of sight")
-- Get buffs: the far member says so, greyed, after the members in sight; a click asks nothing.
BuffDiggerDB.nearby=true; ns.applyWindows(); local fe=_G.BuffDiggerNearby.entries; local tir, tirAt, lastNear
for i,x in ipairs(fe) do if x.unit=="party3" then tir, tirAt = x, i elseif x.group then lastNear = i end end
print("far member:", tir and tir.text); assert(tir and tir.far and tir.text:find("(too far)", 1, true) and tirAt > lastNear, "far member flagged, after")
for _,r in ipairs(_G.BuffDiggerNearby.rows) do if r._shown and r.entry.buffs[1] then
  assert(r.buffs[1].icon._red == (r.entry.unit=="party3"), "red icons for the far member only") end end
local b=#sent; ns.request("party3"); assert(#sent==b and not BuffDiggerDB.asked.Tirion, "no whisper to a member out of sight")
-- [-] on the Group header folds the members away; the header stays, with its count.
local nwr=_G.BuffDiggerNearby.rows; assert(nwr[1].entry.fold and nwr[1].fold._shown and nwr[1].line._shown, "Group header: [-] and line")
assert(not nwr[2].fold._shown and not nwr[2].line._shown, "a member's row: no [-], no line")
nwr[1].fold._OnClick(nwr[1].fold); fe=_G.BuffDiggerNearby.entries
assert(BuffDiggerDB.hideGroup.nearby, "the click folds")
nwr[1].fold._OnClick(nwr[1].fold); nwr[1].fold._OnClick(nwr[1].fold); _G.BuffDiggerNearby.fill()
local heads=0; for _,x in ipairs(_G.BuffDiggerNearby.entries) do if x.header then heads=heads+1 end end
assert(heads==2, "re-fills never pile up headers: "..heads)
fe=_G.BuffDiggerNearby.entries
assert(fe[1].header and fe[1].fold and fe[1].text=="Group (3)", "folded: header kept")
for _,x in ipairs(fe) do assert(not x.group, "folded: no member listed") end
BuffDiggerDB.hideGroup.nearby=nil; BuffDiggerDB.nearby=false; ns.applyWindows()
UnitIsVisible=realVis; units.party3=nil; GetNumSubgroupMembers=function() return 2 end
-- The ask key looks at members too (in a dungeon, the only players it can see).
BuffDiggerDB.asked={}; local b=#sent; ns.askBest(); print("ask key:", sent[b+1]); assert(BuffDiggerDB.asked.Uther or BuffDiggerDB.asked.Anduin, "the key asks a member")
-- Give buffs, as a paladin: a far member stays in Group (greyed), the key aims at the first one in range.
units.player={"Yann","PALADIN",40}; IsPlayerSpell=function(id) return id==19740 or id==20217 end
units.party1={"Garrosh","WARRIOR",40}; C_UnitAuras.GetAuraDataBySpellName=function() return false end
C_Spell.IsSpellInRange=function(_, u) return u ~= "party1" end; BOUND="F"
BuffDiggerDB.give=true; ns.applyWindows(); ns.refreshWindow(); local ge=_G.BuffDiggerGive.entries
print("Give buffs:", ge[1].text, ge[2].text, ge[3].text, ge[4].text)
assert(ge[1].header and ge[2].unit=="party2" and ge[3].unit=="party1" and ge[3].far and ge[4].header, "far member last in Group, flagged far")
assert(_G.BuffDiggerGiveNext.unit and _G.BuffDiggerGiveNext.unit~="party1", "the key skips the far member")
C_Spell.IsSpellInRange=nil; BOUND=nil; BuffDiggerDB.give=false; ns.applyWindows()
-- Requests: a member's request comes first, even after another one.
units.player={"Yann","PRIEST",40}; IsPlayerSpell=function(id) return id==1243 end; BuffDiggerDB.acceptRequests=true
fire("CHAT_MSG_ADDON","BuffDigger","REQ:fortitude:new","WHISPER","Marie-Curie")
fire("CHAT_MSG_ADDON","BuffDigger","REQ:fortitude:new","WHISPER","Garrosh-Realm")
BuffDiggerDB.requests=true; ns.applyWindows(); local re=_G.BuffDiggerRequests.entries
print("Requests:", re[1].text, re[2].text, re[3].text, re[4].text)
assert(re[1].header and re[2].request.name=="Garrosh" and re[2].unit=="party1" and re[3].header, "member's request first")
BuffDiggerDB.requests=false; ns.applyWindows()
IsInGroup=nil; UnitIsUnit=realIsUnit; units.party1=nil; units.party2=nil

print("=== The game's right-click menu (#17)")
units.player={"Yann","WARRIOR",21}; units.target={"Arthas","PALADIN",25}
local function menu(tag, unit)
  local lines={}; local root={CreateDivider=function() end, CreateTitle=function(_,t) lines[#lines+1]=t end,
    CreateButton=function(_,t,f) lines[#lines+1]=t; lines.click=lines.click or f end}
  MENUS[tag](nil, root, {unit=unit}); return lines
end
local m=menu("MENU_UNIT_PLAYER","target"); print("menu:", m[1], m[2]); assert(m[1]=="Buff Digger" and #m==4, "title + 3 blessings")
BuffDiggerDB.asked={}; b=#sent; m.click(); assert(BuffDiggerDB.asked.Arthas, "a line asks for that buff")
assert(#menu("MENU_UNIT_PLAYER","player")==0, "nothing on myself")
assert(#menu("MENU_UNIT_PLAYER",nil)==0, "nothing without a unit (name in chat)")
units.target={"Garrosh","WARRIOR",40}; assert(#menu("MENU_UNIT_PARTY","target")==0, "nothing when they can't buff")
units.target={"Arthas","PALADIN",25}; BuffDiggerDB.gameMenu=false; assert(#menu("MENU_UNIT_RAID_PLAYER","target")==0, "setting off: nothing")
BuffDiggerDB.gameMenu=true; units.target=nil

print("=== thanks by hand (#21)")
BuffDiggerDB.thankByHand=true; BuffDiggerDB.asked={}; myAuras={}; fire("UNIT_AURA","player"); runTimers()
units.nameplate30={"Malfurion","DRUID",40}; units.nameplate31={"Benedictus","PRIEST",40}
local function aura(id, name, spell, src) return {auraInstanceID=id,name=name,spellId=spell,sourceUnit=src,expirationTime=NOW+600,duration=600} end
-- Asked Malfurion for Mark: it lands, nothing goes out, he waits with one row.
BuffDiggerDB.asked={Malfurion={at=time(), key="wild", channel="WHISPER", target="Malfurion-Realm"}}
b=#sent; myAuras[1]=aura(300,"spell1126",1126,"nameplate30"); fire("UNIT_AURA","player"); runTimers()
assert(#sent==b, "by hand: no automatic thanks"); assert(#ns.thanksWaiting()==1 and ns.thanksWaiting()[1].name=="Malfurion")
-- Then Thorns from him, unasked: same row, two buffs.
myAuras[2]=aura(301,"spell467",467,"nameplate30"); fire("UNIT_AURA","player")
local e=ns.thanksWaiting()[1]; print("Malfurion row:", table.concat(e.keys, ",")); assert(#ns.thanksWaiting()==1 and #e.keys==2)
-- An unasked Fortitude from a stranger: a second row, newest first.
myAuras[3]=aura(302,"Mot de pouvoir : Robustesse",1243,"nameplate31"); fire("UNIT_AURA","player")
assert(#ns.thanksWaiting()==2 and ns.thanksWaiting()[1].name=="Benedictus")
-- Thanking Malfurion: emote now, whisper in my request's channel after the delay, row gone.
b=#sent; ns.thankBuffer("Malfurion"); assert(sent[#sent]=="EMOTE THANK Malfurion"); runTimers()
print("thanked by hand:", sent[#sent]); assert(sent[#sent]:find("^WHISPER Malfurion%-Realm: ")); assert(#ns.thanksWaiting()==1)
-- His next buff within a minute: no new row (Mark then Thorns after a thank-you). Thorns wears off,
-- then he casts it again (a new aura, no previous giver): only THANK_GAP keeps him out.
local thorns=table.remove(myAuras, 2); fire("UNIT_AURA","player")
thorns.auraInstanceID=310; table.insert(myAuras, 2, thorns); fire("UNIT_AURA","player"); assert(#ns.thanksWaiting()==1, "just thanked: no row")
-- Benedictus unasked: whisper to him; dismissing instead sends nothing.
b=#sent; ns.dismissThank("Benedictus"); runTimers(); assert(#sent==b and #ns.thanksWaiting()==0)
-- A renewal by the same giver, unasked: no row. By someone else: a row.
myAuras[3].expirationTime=NOW+1200; fire("UNIT_AURA","player"); assert(#ns.thanksWaiting()==0, "renewal by the same giver")
units.nameplate32={"Moira","PRIEST",40}; local realName=UnitName; UnitName=function(u) if u=="nameplate32" then return "Moira","Ironforge" end return realName(u) end; myAuras[3].sourceUnit="nameplate32"; myAuras[3].expirationTime=NOW+1500; fire("UNIT_AURA","player")
assert(#ns.thanksWaiting()==1 and ns.thanksWaiting()[1].name=="Moira Ironforge")
b=#sent; ns.thankBuffer("Moira Ironforge"); runTimers(); assert(sent[#sent]:find("^WHISPER Moira%-Ironforge: "), "unasked: a whisper, to her realm"); UnitName=realName
-- In an instance: unasked gives no row, asked does.
IsInInstance=function() return true end
myAuras[3].sourceUnit="nameplate31"; myAuras[3].expirationTime=NOW+1800; fire("UNIT_AURA","player"); assert(#ns.thanksWaiting()==0, "instance, unasked")
BuffDiggerDB.asked={Benedictus={at=time(), key="fortitude", channel="SAY", target="Benedictus"}}
units.nameplate31={"Benedictus","PRIEST",40}; myAuras[3].expirationTime=NOW+2100; fire("UNIT_AURA","player"); assert(#ns.thanksWaiting()==1, "instance, asked")
-- Asked in /say: the click sends it in /say right away.
assert(not BuffDiggerDB.asked.Benedictus.thanked)
b=#sent; ns.thankBuffer("Benedictus"); print("say by hand:", sent[#sent]); assert(sent[#sent]:find("^SAY nil: Benedictus : "))
IsInInstance=function() return false end
-- Nothing to send (both boxes off): no row. Rows expire after 2 minutes.
BuffDiggerDB.thank, BuffDiggerDB.thankMessage = false, false
units.nameplate33={"Hamuul","DRUID",40}; myAuras[4]=aura(303,"spell467",467,"nameplate33"); fire("UNIT_AURA","player"); assert(#ns.thanksWaiting()==0)
BuffDiggerDB.thank, BuffDiggerDB.thankMessage = true, true
units.nameplate34={"Remulos","DRUID",40}; myAuras[5]=aura(304,"spell467",467,"nameplate34"); fire("UNIT_AURA","player"); assert(#ns.thanksWaiting()==1)
local realTime=time; time=function() return realTime()+121 end; assert(#ns.thanksWaiting()==0, "expired"); time=realTime
-- The Thanks window: shown while someone waits; click thanks, right click forgets, close clears.
local tw=_G.BuffDiggerThanks; ns.refreshThanks(); assert(not tw._shown, "nobody to thank: hidden")
units.nameplate35={"Cenarius","DRUID",40}; myAuras[6]=aura(305,"spell467",467,"nameplate35"); fire("UNIT_AURA","player")
units.nameplate36={"Lunara","DRUID",40}; myAuras[7]=aura(306,"spell467",467,"nameplate36"); fire("UNIT_AURA","player")
assert(tw._shown and tw.rows[1]._shown and tw.rows[1].name=="Lunara" and tw.rows[2].name=="Cenarius" and not tw.rows[3]._shown)
assert(tw.rows[1].icons[1]._shown and not tw.rows[1].icons[2]._shown, "one icon per buff")
b=#sent; tw.rows[1]._OnClick(tw.rows[1], "LeftButton"); assert(sent[#sent]=="EMOTE THANK Lunara" and tw.rows[1].name=="Cenarius")
runTimers(); b=#sent; tw.rows[1]._OnClick(tw.rows[1], "RightButton"); runTimers(); assert(#sent==b and not tw._shown, "forgotten, window hidden")
units.nameplate37={"Broll","DRUID",40}; myAuras[8]=aura(307,"spell467",467,"nameplate37"); fire("UNIT_AURA","player"); assert(tw._shown)
for _,f in ipairs(tw.CloseButton._hooks.OnClick) do f() end; assert(#ns.thanksWaiting()==0 and not tw._shown, "close forgets everyone")
-- Key "Thank the last player who buffed me": the newest line; nobody left -> nothing sent.
units.nameplate38={"Naralex","DRUID",40}; myAuras[9]=aura(308,"spell467",467,"nameplate38"); fire("UNIT_AURA","player")
units.nameplate39={"Keeper","DRUID",40}; myAuras[10]=aura(309,"spell467",467,"nameplate39"); fire("UNIT_AURA","player")
BuffDigger.thankLast(); assert(sent[#sent]=="EMOTE THANK Keeper" and ns.thanksWaiting()[1].name=="Naralex")
BuffDigger.thankLast(); runTimers(); b=#sent; BuffDigger.thankLast(); runTimers(); assert(#sent==b and #ns.thanksWaiting()==0)
-- Dismissing a line I asked for closes that request; turning the option off empties the list.
units.nameplate40={"Aponi","DRUID",40}; BuffDiggerDB.asked={Aponi={at=time(), key="thorns", channel="WHISPER", target="Aponi"}}
myAuras[11]=aura(311,"spell467",467,"nameplate40"); fire("UNIT_AURA","player"); assert(ns.thanksWaiting()[1].name=="Aponi")
ns.dismissThank("Aponi"); assert(BuffDiggerDB.asked.Aponi.thanked, "skipped: request answered")
units.nameplate41={"Sunwalker","DRUID",40}; myAuras[12]=aura(312,"spell467",467,"nameplate41"); fire("UNIT_AURA","player"); assert(#ns.thanksWaiting()==1)
BuffDiggerDB.thankByHand=false; assert(#ns.thanksWaiting()==0, "option off: list emptied")
print("=== custom phrases (#20)")
BuffDiggerDB.language="en"
local errs=ns.setCustom("new", "Oi, {spell} please, 100% sure\n\n  |cffff0000Red {spell}|r  \nno spell here\n{spell} and {spell}\n" .. ("x"):rep(230) .. " {spell}")
for _,e in ipairs(errs) do print("refused:", e) end
assert(#errs==4 and errs[1]:find("^Line 3: no |") and errs[2]:find("^Line 4: ") and errs[3]:find("^Line 5: ") and errs[4]:find("^Line 6: too long"))
assert(#BuffDiggerDB.custom.new==1 and BuffDiggerDB.custom.new[1]=="Oi, {spell} please, 100% sure", "trimmed, | refused")
local got={}; for i=1,4 do local m=ns.message("new","fortitude","en"); got[m]=true; assert(not m:find("{spell}") and m:find("|Hspell:1243"), m) end
local k=0; for m in pairs(got) do k=k+1; print("custom:", m) end; assert(k==1)
-- Saving the same text again (opening the window) keeps the list: no fresh bag.
local list=BuffDiggerDB.custom.new; ns.setCustom("new", BuffDiggerDB.customText.new); assert(BuffDiggerDB.custom.new==list)
for m in pairs(got) do if m:find("Oi") then assert(m:find("100%% sure$"), "% kept") end end
-- Another case keeps the built-in phrases; thanks without {spell}; 21 lines -> one refused.
assert(not ns.message("upgrade","fortitude","en"):find("Oi"))
errs=ns.setCustom("thanks", "Merci l'ami !\nThanks for {spell}"); assert(#errs==1 and ns.thanks("en")=="Merci l'ami !")
local many={}; for i=1,21 do many[i]="Line "..i.." {spell}" end
errs=ns.setCustom("refresh", table.concat(many,"\n")); assert(#errs==1 and #BuffDiggerDB.custom.refresh==20)
-- Emptying the box: back to the built-in phrases.
ns.setCustom("new", ""); ns.setCustom("thanks", "  \n"); ns.setCustom("refresh", "")
assert(not ns.message("new","fortitude","en"):find("Oi") and ns.thanks("en")~="Merci l'ami !")
-- The Phrases window: shows what I typed, saves as I type, shows refused lines, previews locally.
local pw=_G.BuffDiggerPhrases; local typed="Hey, {spell}?"
pw.edit.GetText=function() return typed end; pw.edit.SetText=function(_, t) typed=t end
pw.errors.SetText=function(self, t) self.t=t end
pw:Show(); pw._OnShow(pw); assert(pw.kind=="new" and typed=="" and pw.errors.t=="")
typed="Hey, {spell}?\nno spell"; pw.edit._OnTextChanged(pw.edit, true)
print("phrases errors:", pw.errors.t); assert(pw.errors.t:find("Line 2") and BuffDiggerDB.custom.new[1]=="Hey, {spell}?")
typed=("x\n"):rep(6); pw.edit._OnTextChanged(pw.edit, true); assert(select(2, pw.errors.t:gsub("\n", ""))==3 and pw.errors.t:find("%+3 more$"), "3 errors shown, then +N")
typed="Hey, {spell}?\nno spell"; pw.edit._OnTextChanged(pw.edit, true)
pw.tabs[5]._OnClick(pw.tabs[5]); assert(pw.kind=="thanks" and typed:match("^%s*$"))
pw.tabs[1]._OnClick(pw.tabs[1]); assert(typed=="Hey, {spell}?\nno spell", "the box comes back as typed")
local said; local realSay=ns.say; ns.say=function(t) said=t end
pw.preview._OnClick(pw.preview); print("preview:", said); assert(said:find("^Hey, .*Hspell:1243.*%?$"), "preview, nothing sent")
ns.say=realSay
-- Status line says what's sent; "Start from Buff Digger's" fills an empty box with ours, {spell} in.
pw.status.SetText=function(self, t) self.t=t end
pw.edit._OnTextChanged(pw.edit, true); assert(pw.status.t:find("your phrases %(1%)"))
typed=""; pw.edit._OnTextChanged(pw.edit, true); assert(pw.status.t:find("Box empty"))
pw.copy._OnClick(pw.copy); assert(typed:find("^Could I get {spell} please%?\n") and #BuffDiggerDB.custom.new==10, typed)
pw.tabs[5]._OnClick(pw.tabs[5]); pw.copy._OnClick(pw.copy); assert(BuffDiggerDB.custom.thanks[1]=="Thanks!")
ns.setCustom("new", ""); ns.setCustom("thanks", "")
print("SMOKE OK")
