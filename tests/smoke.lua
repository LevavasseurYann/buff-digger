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
  if k=="GetAttribute" then return function(s,a) return rawget(s,"_a_"..a) end end
  if k=="SetAttribute" then return function(s,a,v) rawset(s,"_a_"..a,v) end end
  if k=="RegisterEvent" or k=="RegisterUnitEvent" then return function(s) if not rawget(s,"_reg") then rawset(s,"_reg",true); events[#events+1]=s end end end
  if k=="CreateFontString" or k=="CreateTexture" then return function() return obj() end end
  if k=="CloseButton" then local c=obj(); rawset(t,k,c); return c end
  return function() end end}) end
CreateFrame=function(_,name) local o=obj(); if name then _G[name]=o end; return o end
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
-- His blessing is framed in gold; his others warn they would replace it; nobody else's.
assert(ns.hisBlessing("Arthas")=="kings" and ns.hisBlessing("Jaina")==nil)
local fb=CreateFrame(); fb.icon=CreateFrame(); ns.styleBuff(fb,"kings","might","kings"); assert(fb.his._shown, "his blessing: gold frame")
ns.styleBuff(fb,"might","might","kings"); assert(not fb.his._shown, "another blessing: no frame")
ns.styleBuff(fb,"kings","might","kings"); ns.styleBuff(fb); assert(not fb.his._shown, "hint mode (no buff): frame gone")
local tip={}; GameTooltip.AddLine=function(_,t) tip[#tip+1]=t end
ns.buffTooltip(fb,"nameplate1","might"); print("tooltip:", table.concat(tip," / "))
assert(table.concat(tip,"\n"):find("Replaces the .- that Arthas gave you"), "warns it replaces his blessing")
units.nameplate9={"Turalyon","PALADIN",25}; tip={}; ns.buffTooltip(fb,"nameplate9","might")
assert(not table.concat(tip,"\n"):find("Replaces"), "another paladin replaces nothing")
tip={}; ns.buffTooltip(fb,"nameplate1","kings"); assert(table.concat(tip,"\n"):find("Arthas gave you this one"))
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
-- Off in the game (ns.CASTING: nothing casts from an addon in Forever): no ACK, so the asker whispers.
b=#sent; fire("CHAT_MSG_ADDON","BuffDigger","REQ:fortitude:refresh","WHISPER","Zoe-Realm"); assert(#sent==b, "casting off: no ACK")
ns.CASTING=true -- on for the rest, to keep that code tested
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
local function click(b, sendSpell)
  for _,f in ipairs(b._hooks.PreClick) do f(b,"LeftButton",true) end
  if sendSpell then fire("UNIT_SPELLCAST_SENT","player","Arthas","guid",1243) end
  for _,f in ipairs(b._hooks.PostClick) do f(b,"LeftButton",true) end
  for _,f in ipairs(b._hooks.PreClick) do f(b,"LeftButton",false) end
  for _,f in ipairs(b._hooks.PostClick) do f(b,"LeftButton",false) end
end
BuffDiggerDB.confirmed.cast=nil; BuffDiggerDB.debug=true
click(nb, false); fire("UNIT_SPELLCAST_SENT","player","Arthas","guid",1243)
print("manual cast after a dead click -> cast confirmed?", BuffDiggerDB.confirmed.cast); assert(not BuffDiggerDB.confirmed.cast)
click(nb, true); print("cast during the click -> confirmed:", BuffDiggerDB.confirmed.cast); assert(BuffDiggerDB.confirmed.cast)
BuffDiggerDB.debug=false

-- In the window: a far player is listed last, greyed, and his row casts nothing.
local gw=_G.BuffDiggerGive; BuffDiggerDB.give=true; ns.applyWindows()
C_Spell.IsSpellInRange=function(_, u) return u ~= "nameplate1" end
NOW=NOW+60 -- the casts on Arthas above skip him for 10 s
ns.refreshWindow()
local last; for _,r in ipairs(gw.rows) do if r._shown then last=r end end
print("last row:", last.unit, last:GetAttribute("type")); assert(last.unit=="nameplate1" and last:GetAttribute("type")==nil)
assert(gw.rows[1]:GetAttribute("type")=="macro" and gw.rows[1].unit~="nameplate1")
print("row 1 macro:", gw.rows[1]:GetAttribute("macrotext"))
-- Aimed by exact name (and realm), cast only on a friendly living target, previous target back.
assert(gw.rows[1]:GetAttribute("macrotext"):find("^/targetexact [%a%-]+\n/cast %[help,nodead%] Mot de pouvoir : Robustesse\n/targetlasttarget$"))
-- A click in the window does not hide that player (the list used to empty this way).
local clicked=gw.rows[1].unit; click(gw.rows[1], false); ns.refreshWindow()
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
b=#sent; BuffDiggerDB.asked={}; local pick=row.buffs[#first.buffs]; pick._OnClick(pick,"LeftButton")
local who=UnitName(first.unit); print("icon asks", who, "for", BuffDiggerDB.asked[who].key); assert(BuffDiggerDB.asked[who].key==pick.key)
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
local g=_G.BuffDiggerGive; if g.fill then g.fill() end; assert(not g.down._shown, "Give buffs never scrolls: no arrow")
print("SMOKE OK")
