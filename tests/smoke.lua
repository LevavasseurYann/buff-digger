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
  if k=="RegisterForClicks" then return function(s,...) rawset(s,"_clicks",table.concat({...},",")) end end
  if k=="RegisterEvent" or k=="RegisterUnitEvent" then return function(s) if not rawget(s,"_reg") then rawset(s,"_reg",true); events[#events+1]=s end end end
  if k=="CreateFontString" or k=="CreateTexture" or k=="CreateAnimationGroup" or k=="CreateAnimation" then return function() return obj() end end
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
-- Same stale token, but I did ask a priest for Fortitude: the buff is theirs, they get the thanks.
BuffDiggerDB.asked={Anduin={at=time(), key="fortitude", channel="WHISPER", target="Anduin"}}
myAuras[1].auraInstanceID=101; myAuras[1].expirationTime=NOW+3500; fire("UNIT_AURA","player"); runTimers()
print("falls back to the asked priest:", sent[#sent]); assert(sent[#sent]:find("WHISPER Anduin"))
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

-- In the window: a far player is listed last, greyed, and his row casts nothing.
local gw=_G.BuffDiggerGive; BuffDiggerDB.give=true; ns.applyWindows()
C_Spell.IsSpellInRange=function(_, u) return u ~= "nameplate1" end
NOW=NOW+60 -- the casts on Arthas above skip him for 10 s
ns.refreshWindow()
local last; for _,r in ipairs(gw.rows) do if r._shown then last=r end end
print("last row:", last.unit, last:GetAttribute("type")); assert(last.unit=="nameplate1" and last:GetAttribute("type")==nil)
assert(gw.rows[1]:GetAttribute("type")=="macro" and gw.rows[1].unit~="nameplate1")
print("row 1 macro:", gw.rows[1]:GetAttribute("macrotext"))
-- Aimed by name (no realm, /target), cast only on a friendly living target, previous target back.
assert(gw.rows[1]:GetAttribute("macrotext"):find("^/target [^\n]+\n/cast %[help,nodead%] Mot de pouvoir : Robustesse\n/targetlasttarget$"))
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
b=#sent; BuffDiggerDB.asked={}; local pick=row.buffs[#first.buffs]
for _,f in ipairs(pick._hooks.PostClick) do f(pick,"LeftButton",false) end -- a release: one request
-- The fix of 2026-11-09: release only, whatever ActionButtonUseKeyDown says.
for _,sb in ipairs({row, pick, _G.BuffDiggerGiveNext, _G.BuffDiggerGive.rows[1], _G.BuffDiggerRequests.rows[1]}) do
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
assert(g.rows[1]:GetAttribute("macrotext"):find("^/target "..shown.."\n"), "scrolled row aims at the name it shows")
assert(g.rows[10]:GetAttribute("macrotext"):find("^/target "..shown11.."\n"), "newly shown row too")
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
for i,r in ipairs(rq.rows) do if r._shown then byName[r.entry.request.name]=r; lastSeen=r; print("row", i, r.entry.request.name, r:GetAttribute("type")) end end
assert(rq.rows[1].entry.request.name=="Arthas" and rq.rows[1]:GetAttribute("type")=="macro", "in sight first, in arrival order")
assert(byName.Ghost:GetAttribute("type")==nil and not lastSeen.entry.spell, "out of sight: after, not castable")
click(byName.Pal10, false); ns.refreshIncoming(); assert(count==c0+3, "clicking a higher-rank request closes it")
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
click(ned, false); ns.refreshIncoming(); assert(not marked("nameplate42"), "clicked: marker gone"); ns.toggleRequests()
-- Setting off: no marker.
BuffDiggerDB.requestMarkers=false
units.nameplate43={"Oli","WARRIOR",40}; fire("NAME_PLATE_UNIT_ADDED","nameplate43"); runTimers()
fire("CHAT_MSG_ADDON","BuffDigger","REQ:fortitude:new","WHISPER","Oli-Realm"); assert(not marked("nameplate43"), "setting off: none")
BuffDiggerDB.requestMarkers=true; CreateFrame=mk
-- A spell with no target (Lightning Bolt with nothing selected): no error (seen in game 2026-11-09).
fire("UNIT_SPELLCAST_SENT","player",nil,"guid",403)
print("SMOKE OK")
