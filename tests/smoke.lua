-- Scenarios for Buff Digger, under the fake WoW API of tests/fakewow.lua.
-- Run from the repo root: uv run --no-project -q --with lupa python -I tests/run_smoke.py
dofile(DIR.."tests/fakewow.lua")
-- The only way to thank (#37): click every waiting Thank line, newest first.
local function thankWaiting() while ns.thanksWaiting()[1] do ns.thankBuffer(ns.thanksWaiting()[1].name) end end
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
assert(fb.swap._shown, "his best other blessing: circling arrows (swap)")
ns.styleBuff(fb,"kings","might","kings"); assert(not fb.swap._shown, "the one he gave: no arrows")
ns.styleBuff(fb,"might","might"); assert(not fb.swap._shown, "no blessing of his on me: no arrows")
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
-- Every language x tone (#49): each ask bag (whatever its name, class bags too) has 3 lines or more,
-- %s once, and fits the chat at worst ("Name : " in /say + longest hello, line, link and bye).
-- A request never thanks. An unknown language falls back to English, an unknown tone to Casual.
assert(BuffDiggerDB.tone=="casual", "a profile without a tone loads as Casual")
local longest=0
for _,b in pairs(ns.BUFFS) do for _,n in ipairs({b.en, C_Spell.GetSpellName(b.id)}) do
  longest=math.max(longest, #(C_Spell.GetSpellLink(b.id):gsub("%[.-%]", "["..n.."]")))
end end
local function maxLen(list) local n=0; for _,s in ipairs(list) do n=math.max(n,#s) end return n end
local function strings(t, f) for _,v in pairs(t) do if type(v)=="table" then strings(v,f) else f(v) end end end
-- Every ask bag of a tone table (all but hello and bye), class bags too: f(name, list).
local function eachAsk(m, f)
  for part, list in pairs(m) do
    if part=="byClass" then for class, b in pairs(list) do for p, l in pairs(b) do f(class.."."..p, l) end end
    elseif part~="hello" and part~="bye" then f(part, list) end
  end
end
for _, lang in ipairs(ns.LANGUAGES) do for _, tone in ipairs(ns.TONES) do
  local m, where = ns.MESSAGES[lang[1]][tone[1]], lang[1].."."..tone[1]
  assert(m and m.hello and m.bye and m.new, where)
  local function ask(part, list)
    assert(#list>=3, where.."."..part.." needs 3 lines")
    for _,s in ipairs(list) do
      assert(select(2, s:gsub("%%s", ""))==1, s)
      local worst=27 + maxLen(m.hello) + #s - 2 + longest + maxLen(m.bye)
      assert(worst<=255, where.." too long ("..worst.."): "..s)
    end
  end
  for _,s in ipairs(m.hello) do assert(not s:find("%%"), s) end
  for _,s in ipairs(m.bye) do assert(not s:find("%%"), s) end
  eachAsk(m, ask)
  if tone[1]=="casual" then local none; for _,s in ipairs(m.hello) do none=none or s=="" end; assert(none, where.." hello needs \"\"") end
  strings(m, function(s)
    for _, w in ipairs({ "[Tt]hank", "[Mm]erci", "[Dd]ank", "[Gg]racias", "[Gg]razie", "[Vv]aleu",
      "[Oo]brigad", "Спасибо", "спасибо", "[Бб]лагодар", "[Dd]zięk", "appreciated", "[Cc]heers", "Ty!" }) do
      assert(not s:find(w), where .. " request thanks: " .. s)
    end
  end)
  local t = ns.THANKS[lang[1]][tone[1]]; assert(t and #t.thanks >= 3 and #t.bye > 0, where .. " thanks")
  -- #23: a thank-you never ends like the request did ("" aside), and each side has 2 real endings.
  -- Compared without case, spaces or punctuation: "Safe travels." and "safe travels!" are one ending.
  local function norm(s) return (s:lower():gsub("[%p%s]", "")) end
  local ends, n = {}, 0
  for _,s in ipairs(m.bye) do if s~="" then ends[norm(s)]=true; n=n+1 end end
  assert(n>=2, where.." request ends")
  n=0; for _,s in ipairs(t.bye) do assert(s=="" or not ends[norm(s)], where.." thank-you ends like a request: "..s); if s~="" then n=n+1 end end
  assert(n>=2, where.." thank-you ends")
  print(where, (ns.message("new", "might", lang[1], tone[1]):gsub("|c%x+|H.-|h", ""):gsub("|h|r", "")), ns.thanks(lang[1], tone[1]))
end end
-- Which bag a message came from: one of the ask lines of `m` (any part, class bags too).
local function madeFrom(msg, m)
  local found
  eachAsk(m, function(_, list) for _,s in ipairs(list) do
    local pat=s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("%%%%s", ".-")
    if msg:find(pat) then found=true end
  end end)
  return found
end
-- The tone is a parameter, like the language; Try one and Start from Buff Digger's follow it.
for i=1,10 do assert(madeFrom(ns.message("new","might","en","polite"), ns.MESSAGES.en.polite), "polite") end
for i=1,10 do assert(madeFrom(ns.message("new","might","en","xx"), ns.MESSAGES.en.casual), "unknown tone: Casual") end
for i=1,10 do assert(madeFrom(ns.message("new","might","en"), ns.MESSAGES.en.casual), "no tone: Casual") end
local bi=ns.builtIn("new","en","polite"); assert(#bi==#ns.MESSAGES.en.polite.new and bi[1]==ns.MESSAGES.en.polite.new[1]:gsub("%%s","{spell}"))
for i=1,10 do local t=ns.thanks("en","polite"); local ok
  for _,s in ipairs(ns.THANKS.en.polite.thanks) do ok=ok or t:sub(1,#s)==s end; assert(ok, "polite thanks: "..t) end
assert(ns.message("new", "might", "xx") and ns.thanks(nil) and ns.thanks("xx", "xx"))

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
BuffDiggerCharDB.asked = {}
print("offers paladin 25:", table.concat(ns.offers("PALADIN",25), ","))
ns.request("nameplate1", "wisdom"); print("CHOSEN", sent[#sent])
print("askedAgo:", ns.askedAgo("Arthas"))
BuffDiggerDB.prefs.WARRIOR = {"kings","might"}
print("custom prefs best:", ns.bestBuff("Zed","PALADIN",25))

-- Thanks flow: never on its own, only a Thank click (#37)
SHIFT=false; BuffDiggerDB.language="en"; BuffDiggerCharDB.asked={}; BuffDiggerDB.prefs.WARRIOR=nil
local gift=ns.thanksWaiting()[1]; assert(gift and gift.name=="Arthas" and gift.request.gift, "his Kings, unasked: a gift line (#43)"); ns.dismissThank()
BuffDiggerDB.thankGifts=false -- below: the request rules of #37; gifts at the end (#43)
units.nameplate4={"Uther","PALADIN",30}
myAuras={}; fire("UNIT_AURA","player")
ns.request("nameplate4"); print("REQ", sent[#sent])
myAuras[1]={auraInstanceID=20,name="Bénédiction de puissance",spellId=19740,sourceUnit="nameplate4"}
local before=#sent; fire("UNIT_AURA","player"); runTimers(); assert(#sent==before, "nothing goes out on its own")
ns.thankBuffer("Uther"); print("thanked:", sent[before+1]); assert(sent[before+1]:find("^WHISPER Uther") and sent[before+2]=="EMOTE THANK Uther")
-- Asked in /say: the click thanks in /say at once
SHIFT=true; units.nameplate5={"Anduin","PRIEST",40}; ns.request("nameplate5"); SHIFT=false
myAuras[2]={auraInstanceID=21,name="Mot de pouvoir : Robustesse",spellId=1243,sourceUnit="nameplate5"}
fire("UNIT_AURA","player"); before=#sent; ns.thankBuffer("Anduin"); assert(sent[before+1]:find("^SAY") and sent[before+2]=="EMOTE THANK Anduin")
-- Unknown giver, one open Fortitude request: nobody waits (no guessing)
BuffDiggerCharDB.asked = { A = {at=time(), key="fortitude", channel="WHISPER"} }
myAuras[3]={auraInstanceID=30,name="Mot de pouvoir : Robustesse",spellId=1243,sourceUnit=nil}; fire("UNIT_AURA","player")
assert(#ns.thanksWaiting()==0, "unknown giver must not wait for a thank-you")

print("=== #10")
units.player={"Yann","WARRIOR",21}; IsPlayerSpell=function() return false end
BuffDiggerCharDB.asked={}; BuffDiggerDB.peers={}; SHIFT=false; myAuras={}; fire("UNIT_AURA","player"); runTimers()
units.nameplate6={"Tirion","PALADIN",40}; fire("NAME_PLATE_UNIT_ADDED","nameplate6"); runTimers()
local b=#sent; ns.request("nameplate6"); for i=b+1,#sent do print("P1", sent[i]) end
fire("CHAT_MSG_ADDON","BuffDigger","ACK","WHISPER","Tirion-Realm"); print("peer?", ns.isPeer("Tirion"))
BuffDiggerCharDB.asked={}; b=#sent; ns.request("nameplate6"); for i=b+1,#sent do print("P2 before timer", sent[i]) end
fire("CHAT_MSG_ADDON","BuffDigger","ACK","WHISPER","Tirion-Realm"); runTimers(); print("P2 after ACK, new sends:", #sent-b)
BuffDiggerCharDB.asked={}; b=#sent; ns.request("nameplate6"); runTimers(); for i=b+1,#sent do print("P3 no ACK", sent[i]) end
-- buffer side
units.player={"Yann","PRIEST",40}; IsPlayerSpell=function(id) return id==1243 end
b=#sent; fire("CHAT_MSG_ADDON","BuffDigger","REQ:fortitude:new","WHISPER","Bob-Realm"); for i=b+1,#sent do print("BUF", sent[i]) end
b=#sent; fire("CHAT_MSG_ADDON","BuffDigger","REQ:might:new","WHISPER","Carl-Realm"); print("unknown spell -> sends:", #sent-b)
b=#sent; fire("CHAT_MSG_ADDON","BuffDigger","REQ:fortitude:new","WHISPER","Bob-Realm"); print("Bob again within 10s -> sends:", #sent-b)
b=#sent; fire("CHAT_MSG_ADDON","BuffDigger","garbage","WHISPER","Eve-Realm"); print("garbage -> peer?", ns.isPeer("Eve"), "sends:", #sent-b)
ns.selfTest(); print("SELF", sent[#sent])
print("plates before:", ns.friendlyPlatesOn()); SlashCmdList.BUFFDIGGER("nameplates"); print("plates after:", ns.friendlyPlatesOn())

print("=== #8 rank from the value on the buff (aura.points)")
units.player={"Yann","WARRIOR",21}; IsPlayerSpell=function() return false end; BuffDiggerCharDB.asked={}
myAuras={}; fire("UNIT_AURA","player")
-- Login: Might +35 (rank 2) already there, giver unknown.
ns.__relog=nil
myAuras={{auraInstanceID=50,name="Bénédiction de puissance",spellId=19834,sourceUnit=nil,points={35},expirationTime=NOW+3000,duration=3600}}
fire("PLAYER_ENTERING_WORLD", true) -- a login
units.nameplate7={"Bolvar","PALADIN",40}
BuffDiggerDB.prefs.WARRIOR={"might"} -- only Might matters here: a missing buff would come first
local k, kind = ns.bestBuff("Bolvar","PALADIN",40); print("rank known at login -> paladin 40 offers:", k, kind)
assert(k=="might" and kind=="upgrade", "rank 2 from points should allow an upgrade")
-- Value not in Data.lua: rank unknown, no upgrade offered (old behaviour), and /bd log flags it.
myAuras={{auraInstanceID=51,name="Bénédiction de puissance",spellId=19834,sourceUnit=nil,points={30},expirationTime=NOW+3000,duration=3600}}
fire("PLAYER_ENTERING_WORLD", true) -- a login
k, kind = ns.bestBuff("Bolvar","PALADIN",40); print("unknown value ->", k, kind)
assert(not (k=="might" and kind=="upgrade"))
SlashCmdList.BUFFDIGGER("log")
BuffDiggerDB.prefs.WARRIOR=nil

print("=== refresh before it runs out")
BuffDiggerDB.refreshBefore=300
myAuras={{auraInstanceID=60,name="Mot de pouvoir : Robustesse",spellId=1243,sourceUnit=nil,points={8},expirationTime=NOW+1000,duration=3600}}
fire("PLAYER_ENTERING_WORLD", true) -- a login
units.player={"Yann","WARLOCK",30}  -- Fortitude is a warlock's top pick
k, kind = ns.bestBuff("Anduin","PRIEST",40); print("16 min left ->", k, kind); assert(k~="fortitude" or kind~="refresh")
NOW=NOW+800  -- 3 min 20 left
k, kind = ns.bestBuff("Anduin","PRIEST",40); print("3 min left ->", k, kind); assert(k=="fortitude" and kind=="refresh")
k = ns.bestBuff("Lowbie","PRIEST",5); print("lower-rank priest won't refresh ->", k); assert(k~="fortitude")
BuffDiggerDB.refreshBefore=0
k, kind = ns.bestBuff("Anduin","PRIEST",40); print("setting off ->", k, kind); assert(kind~="refresh")
BuffDiggerDB.refreshBefore=300
local b=#sent; ns.request("nameplate5"); print("REFRESH REQ", sent[#sent]); assert(#sent>b)
-- Anduin refreshes it: same aura, later end -> a Thank line ("thanked" below: its line, clicked).
ns.dismissThank()
b=#sent; myAuras[1].expirationTime=NOW+1800; myAuras[1].sourceUnit="nameplate5"; fire("UNIT_AURA","player"); thankWaiting()
for i=b+1,#sent do print("THANKS", sent[i]) end; assert(#sent>b, "refresh should be thanked")
-- Recast 20 s after the last one (an upgrade I asked for right after it landed): thanked too.
BuffDiggerCharDB.asked.Anduin={at=time(), key="fortitude", channel="WHISPER", target="Anduin"}
b=#sent; myAuras[1].expirationTime=myAuras[1].expirationTime+20; fire("UNIT_AURA","player"); thankWaiting()
print("recast 20 s later:", sent[#sent]); assert(#sent>b and sent[#sent]:find("WHISPER Anduin"), "a quick recast I asked for should be thanked")
-- Another quick recast, that request already thanked: nothing (a recast alone never thanks).
b=#sent; myAuras[1].expirationTime=myAuras[1].expirationTime+20; fire("UNIT_AURA","player"); thankWaiting()
print("recast, nothing asked:", #sent-b); assert(#sent==b, "a recast nobody asked for must not thank")
-- A peer sees a refresh request (kind accepted).
units.player={"Yann","PRIEST",40}; IsPlayerSpell=function(id) return id==1243 end
b=#sent; fire("CHAT_MSG_ADDON","BuffDigger","REQ:fortitude:refresh","WHISPER","Zia-Realm"); print("refresh REQ -> ACK:", sent[#sent]); assert(sent[#sent]:find("ACK"))

-- Unknown rank (value hidden): no refresh asked, it could lower the rank.
myAuras={{auraInstanceID=61,name="Mot de pouvoir : Robustesse",spellId=1243,sourceUnit=nil,expirationTime=NOW+100,duration=3600}}
units.player={"Yann","WARLOCK",30}; IsPlayerSpell=function() return false end; fire("PLAYER_ENTERING_WORLD", true) -- a login
k, kind = ns.bestBuff("Anduin","PRIEST",40); print("unknown rank, 100 s left ->", k, kind); assert(kind~="refresh")
-- Short buff: a 10 min buff with 5 min left is NOT running out (last quarter only).
myAuras={{auraInstanceID=62,name="Mot de pouvoir : Robustesse",spellId=1243,sourceUnit=nil,points={32},expirationTime=NOW+290,duration=600}}
fire("PLAYER_ENTERING_WORLD", true) -- a login
k, kind = ns.bestBuff("Anduin","PRIEST",40); print("10 min buff, 290 s left ->", k, kind); assert(kind~="refresh")
-- Unsolicited renewal: nobody asked -> no thanks.
BuffDiggerCharDB.asked={}; local b2=#sent; myAuras[1].expirationTime=NOW+600; myAuras[1].sourceUnit="nameplate5"; fire("UNIT_AURA","player")
print("unsolicited renewal sends:", #sent-b2); assert(#sent==b2)
-- Food from another player (mage food, table): not a buff, no thanks.
units.nameplate6={"Jaina","MAGE",40}; b2=#sent
myAuras[#myAuras+1]={auraInstanceID=63,name="Food",spellId=433,sourceUnit="nameplate6"}; fire("UNIT_AURA","player"); thankWaiting()
print("food sends:", #sent-b2); assert(#sent==b2, "eating must not thank")
-- Only the buff I asked this player for is thanked (eating, a buff nobody asked for: nothing).
units.nameplate7={"Tirion","PALADIN",40}; BuffDiggerCharDB.asked={Tirion={at=time(), key="kings", channel="WHISPER", target="Tirion"}}; b2=#sent
myAuras[#myAuras+1]={auraInstanceID=64,name="Bénédiction de puissance",spellId=19740,sourceUnit="nameplate7",expirationTime=NOW+300,duration=300}
fire("UNIT_AURA","player"); thankWaiting(); print("asked Kings, got Might, sends:", #sent-b2); assert(#sent==b2, "another buff than the one asked must not thank")
BuffDiggerCharDB.asked={}; myAuras[#myAuras].auraInstanceID=65; myAuras[#myAuras].expirationTime=NOW+250
units.nameplate7={"Turalyon","PALADIN",40}; fire("UNIT_AURA","player"); thankWaiting()
print("buff nobody asked for sends:", #sent-b2); assert(#sent==b2, "a buff nobody asked for must not thank")
table.remove(myAuras); units.nameplate7=nil; fire("UNIT_AURA","player")
-- Ghost Wolf: my Fortitude comes back with a new instance ID, from a priest I just asked for
-- something else. Same buff, not a landing: no thanks.
BuffDiggerCharDB.asked={Anduin={at=time(), key="spirit", channel="WHISPER", target="Anduin"}}
local fort=myAuras[1]; b2=#sent
myAuras[1]={auraInstanceID=99,name=fort.name,spellId=fort.spellId,sourceUnit="nameplate5",points=fort.points,expirationTime=fort.expirationTime,duration=fort.duration}
fire("UNIT_AURA","player"); thankWaiting(); print("re-indexed aura sends:", #sent-b2); assert(#sent==b2, "a re-indexed aura must not thank")
-- A stale token pointing at the mage I asked for Intellect, on a real new Fortitude: a mage
-- can't give it, no thanks either.
BuffDiggerCharDB.asked={Jaina={at=time(), key="intellect", channel="WHISPER", target="Jaina"}}
myAuras[1].sourceUnit="nameplate6"; myAuras[1].auraInstanceID=100; myAuras[1].expirationTime=NOW+3000; fire("UNIT_AURA","player"); thankWaiting()
print("mage giving Fortitude sends:", #sent-b2); assert(#sent==b2, "wrong-class giver must not thank")
-- Same stale token, but I did ask a priest for Fortitude: the giver is unknown, so no guessing.
BuffDiggerCharDB.asked={Anduin={at=time(), key="fortitude", channel="WHISPER", target="Anduin"}}
myAuras[1].auraInstanceID=101; myAuras[1].expirationTime=NOW+3500; fire("UNIT_AURA","player"); thankWaiting()
print("unknown giver, asked priest:", #sent-b2); assert(#sent==b2, "an unknown giver must not thank the player I asked")
-- No unit token at all: same.
myAuras[1].sourceUnit=nil; myAuras[1].auraInstanceID=102; myAuras[1].expirationTime=NOW+3550; fire("UNIT_AURA","player"); thankWaiting()
print("no source, asked priest:", #sent-b2); assert(#sent==b2, "a buff with no giver must not thank")
-- My own cast of the buff I asked for: nobody thanked, and the request stays open.
units.player={"Yann","PRIEST",40}
myAuras[1].sourceUnit="player"; myAuras[1].auraInstanceID=103; myAuras[1].expirationTime=NOW+3580; fire("UNIT_AURA","player"); thankWaiting()
print("self-buff sends:", #sent-b2); assert(#sent==b2, "my own buff must not thank")
-- A stranger priest gives it first: no thanks, and my request to Anduin stays open.
units.nameplate8={"Velen","PRIEST",40}
myAuras[1].sourceUnit="nameplate8"; myAuras[1].auraInstanceID=104; myAuras[1].expirationTime=NOW+3590; fire("UNIT_AURA","player"); thankWaiting()
print("stranger gives it:", #sent-b2); assert(#sent==b2, "a buff from someone I didn't ask must not thank")
-- Anduin answers after all: thanked, once.
myAuras[1].sourceUnit="nameplate5"; myAuras[1].expirationTime=NOW+3600; fire("UNIT_AURA","player"); thankWaiting()
print("asked priest answers:", sent[#sent]); assert(sent[#sent]:find("WHISPER Anduin"), "the asked player giving the asked buff is thanked")
units.nameplate8=nil
-- Time left hidden, aura re-indexed (shapeshift) while a request to its giver is open: no landing.
BuffDiggerCharDB.asked={Anduin={at=time(), key="fortitude", channel="WHISPER", target="Anduin"}}; b2=#sent
myAuras[1].auraInstanceID=105; myAuras[1].expirationTime=nil; myAuras[1].duration=nil; fire("UNIT_AURA","player")
myAuras[1].auraInstanceID=106; fire("UNIT_AURA","player"); thankWaiting()
print("hidden time, re-indexed:", #sent-b2); assert(#sent==b2, "a re-indexed aura with hidden time must not thank")
-- Time hidden, but another priest's cast replaces it (new instance): a landing, Velen asked -> thanked.
units.nameplate8={"Velen","PRIEST",40}; BuffDiggerCharDB.asked={Velen={at=time(), key="fortitude", channel="WHISPER", target="Velen"}}; b2=#sent
myAuras[1].auraInstanceID=107; myAuras[1].sourceUnit="nameplate8"; fire("UNIT_AURA","player"); thankWaiting()
print("hidden time, other caster:", sent[b2+1]); assert(#sent>b2 and sent[b2+1]:find("WHISPER Velen"), "a new caster replacing my buff is a landing")
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
myAuras={}; BuffDiggerCharDB.asked={}; fire("UNIT_AURA","player"); runTimers()
local plate, onPlate = {}, {}
C_NamePlate.GetNamePlateForUnit=function(u) if u=="nameplate1" then return plate end end
local mk=CreateFrame; CreateFrame=function(t,n,parent,...) local f=mk(t,n,parent,...); if parent==plate then onPlate[#onPlate+1]=f end; return f end
local function shownKeys() local out={} for _,x in ipairs(onPlate) do if x._shown then out[#out+1]=tostring(rawget(x,"key")) end end return out end
BuffDiggerDB.plates="all"; ns.refreshAll(); runTimers()
print("all:", table.concat(shownKeys(), ",")); assert(#shownKeys()==3, "might, kings, wisdom")
local b=#sent; onPlate[3]._OnClick(onPlate[3], "LeftButton"); print("3rd icon asks:", sent[#sent]); assert(#sent>b and BuffDiggerCharDB.asked.Arthas.key==onPlate[3].key)
for _, mode in ipairs({"best","hint"}) do
  BuffDiggerDB.plates=mode; BuffDiggerCharDB.asked={}; ns.refreshAll(); runTimers()
  print(mode..":", table.concat(shownKeys(), ",")); assert(#shownKeys()==1 and shownKeys()[1]=="nil")
end
BuffDiggerDB.plates="off"; ns.refreshAll(); runTimers(); print("off:", #shownKeys()); assert(#shownKeys()==0)
CreateFrame=mk; BuffDiggerDB.plates="best"
-- An old saved "icons = false" becomes "off".
local saved=BuffDiggerDB; BuffDiggerDB={icons=false}; fire("ADDON_LOADED","BuffDigger"); assert(BuffDiggerDB.plates=="off" and BuffDiggerDB.icons==nil); BuffDiggerDB=saved
-- #37: the automatic thanks' old keys are cleared from an old save.
BuffDiggerDB={thankByHand=false, thankByHandOn=true, emoteNeedsClick=true}; fire("ADDON_LOADED","BuffDigger")
assert(BuffDiggerDB.thankByHand==nil and BuffDiggerDB.thankByHandOn==nil and BuffDiggerDB.emoteNeedsClick==nil and BuffDiggerDB.thank, "old keys gone"); BuffDiggerDB=saved

print("=== Get buffs: one icon per buff, scrolling")
local w=_G.BuffDiggerNearby; BuffDiggerDB.nearby=true; ns.applyWindows()
local row=w.rows[1]; print("row 1:", row.text._t or "", "icons shown:", (row.buffs[1]._shown and 1 or 0)+(row.buffs[2]._shown and 1 or 0)+(row.buffs[3]._shown and 1 or 0))
local first=w.entries[1]; assert(#first.buffs>=1)
b=#sent; BuffDiggerCharDB.asked={}; local pick=row.buffs[#first.buffs]
for _,f in ipairs(pick._hooks.PostClick) do f(pick,"LeftButton",false) end -- a release: one request
-- The fix of 2026-11-09: release only, whatever ActionButtonUseKeyDown says.
for _,sb in ipairs({row, pick, _G.BuffDiggerGiveNext, _G.BuffDiggerGive.rows[1], _G.BuffDiggerGive.rows[1].buffs[1], _G.BuffDiggerRequests.rows[1].buffs[1]}) do
  assert(rawget(sb,"_clicks")=="AnyUp" and sb:GetAttribute("useOnKeyDown")==false, "secure clicks: AnyUp only")
end
local who=UnitName(first.unit); print("icon asks", who, "for", BuffDiggerCharDB.asked[who].key); assert(BuffDiggerCharDB.asked[who].key==pick.key); print("sent:", sent[b+1]); assert(#sent==b+2 and sent[b+1]:find("^ADDON"), "one request: addon REQ + whisper")
-- #14: the name targets them (any modifier), asks nothing; icons target only with targetOnAsk.
print("name click:", row:GetAttribute("*type1"), row:GetAttribute("macrotext"))
assert(row:GetAttribute("*type1")=="macro" and row:GetAttribute("macrotext")=="/target "..who)
b=#sent; for _,f in ipairs(row._hooks.PostClick) do f(row,"LeftButton",false) end; assert(#sent==b, "name click asks nothing")
assert(pick:GetAttribute("*type1")==nil and pick:GetAttribute("macrotext")==nil, "icon: no target by default")
BuffDiggerDB.targetOnAsk=true; ns.refreshWindow(); assert(pick:GetAttribute("macrotext")=="/target "..who, "icon targets with the option")
BuffDiggerDB.targetOnAsk=false; ns.refreshWindow(); assert(pick:GetAttribute("*type1")==nil)
-- The token went to someone else while the list sat under the cursor: the icon asks nobody.
local wasP=units[first.unit]; units[first.unit]={"Intrus","PALADIN",30}; b=#sent; BuffDiggerCharDB.asked={}
for _,f in ipairs(pick._hooks.PostClick) do f(pick,"LeftButton",false) end; units[first.unit]=wasP
assert(#sent==b and not BuffDiggerCharDB.asked.Intrus, "stale token: no request")
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
myAuras={}; fire("UNIT_AURA","player"); runTimers(); BuffDiggerCharDB.asked={}; BuffDiggerDB.peers={Pal11=time(), Pal13=time()}
b=#sent; ns.request("nameplate11"); runTimers()
for i=b+1,#sent do print("PEER", sent[i]) end
assert(#sent==b+1 and sent[b+1]:find("^ADDON>Pal11"), "a peer gets only the silent request, no whisper after a while")
assert(BuffDiggerCharDB.asked.Pal11.silent and not ns.unanswered("Pal11"))
b=#sent; ns.request("nameplate11"); assert(#sent==b, "too early to ask again")
BuffDiggerCharDB.asked.Pal11.at=time()-31; ns.refreshWindow()
local marked; for _,e in ipairs(w.entries) do if e.unit=="nameplate11" then marked=e.text:find("no answer") end end
print("Get buffs offers a re-ask:", marked ~= nil); assert(marked, "Get buffs proposes the whisper")
b=#sent; ns.request("nameplate11"); print("re-ask:", sent[#sent])
assert(#sent==b+1 and sent[b+1]:find("^WHISPER Pal11"), "the click re-asks by whisper only")
assert(not ns.unanswered("Pal11"), "offered once")
BuffDiggerCharDB.asked.Pal12={at=time()-31, key="might", silent=true, thanked=true}; assert(not ns.unanswered("Pal12"), "buff came: nothing to offer")
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
units.player={"Yann","PRIEST",40}; IsPlayerSpell=function(id) return id==1243 end; BuffDiggerCharDB.asked={}
units.nameplate50={"Jean Dupont","WARRIOR",40}; fire("NAME_PLATE_UNIT_ADDED","nameplate50"); runTimers()
-- Give buffs: the whole name on the line; the macro targets the first name (what worked in game).
BuffDiggerDB.give=true; ns.applyWindows(); local gv=_G.BuffDiggerGive
gv._OnMouseWheel(gv,-100); local jean; for _,r in ipairs(gv.rows) do if r._shown and r.unit=="nameplate50" then jean=r end end
assert(jean, "Jean Dupont listed in Give buffs"); print("line:", jean.text._t, "| macro:", (jean.buffs[1]:GetAttribute("macrotext"):gsub("\n"," | ")))
assert(jean.text._t:find("Jean Dupont", 1, true), "whole name shown in Give buffs")
assert(jean.buffs[1]:GetAttribute("macrotext"):find("^/target Jean\n"), "macro targets the first name")
assert(jean.entry.who=="Jean Dupont", "aim frozen on the whole name")
-- Setting reads off, but a friendly player's plate is in sight: they are on (seen in Forever).
local cv=CVARS.nameplateShowFriendlyPlayers; CVARS.nameplateShowFriendlyPlayers="0"
assert(ns.friendlyPlatesOn(), "a friendly plate in sight means friendly nameplates are on")
-- Nobody around: the setting alone decides; a write that doesn't take is not reported as "on".
local realNearby=ns.nearbyUnits; ns.nearbyUnits=function() return {} end
CVARS.nameplateShowFriendlyPlayers="0"; assert(not ns.friendlyPlatesOn())
local said2; UIErrorsFrame={AddMessage=function(_, m) said2=m end}
-- A write that doesn't take (the addon kept its own SetCVar: block the table instead).
CVARS.nameplateShowFriendlyPlayers=nil; setmetatable(CVARS, {__newindex=function() end})
ns.turnOnFriendlyPlates(); assert(said2:find("^Couldn't"), tostring(said2))
setmetatable(CVARS, nil); ns.turnOnFriendlyPlates(); assert(said2=="Friendly nameplates are on." and ns.friendlyPlatesOn())
-- Look of the plates (#22): full, name only, icons only (name only + simplified bit), off.
local BITS={}; Enum=Enum or {}; Enum.NamePlateSimplifiedType={FriendlyPlayer=3}
C_CVar={GetCVar=GetCVar, SetCVar=SetCVar, GetCVarBitfield=function(k,i) return BITS[k..i]==true end,
  SetCVarBitfield=function(k,i,v) BITS[k..i]=v end}
for _,style in ipairs({"name","icons","full","off","icons"}) do
  ns.setPlateStyle(style); assert(ns.plateStyle()==style, style.." -> "..ns.plateStyle())
end
assert(CVARS.nameplateUseClassColorForFriendlyPlayerUnitNames=="1", "a bare name in class colour")
ns.setPlateStyle("full"); assert(not BITS.nameplateSimplifiedTypes3, "full: not simplified")
-- Changed in the game's options: icons follow; a write that doesn't take is said.
fire("CVAR_UPDATE","nameplateShowOnlyNameForFriendlyPlayerUnits","1")
said2=nil; setmetatable(CVARS, {__newindex=function() end}); CVARS.nameplateShowOnlyNameForFriendlyPlayerUnits=nil
ns.setPlateStyle("name"); assert(said2 and said2:find("^Couldn't change"), tostring(said2)); setmetatable(CVARS, nil)
said2=nil; ns.setPlateStyle("icons"); assert(said2==nil and ns.plateStyle()=="icons", tostring(said2))
local fakeUnit=Enum.NamePlateSimplifiedType; Enum.NamePlateSimplifiedType=nil; assert(not ns.canSimplify()); Enum.NamePlateSimplifiedType=fakeUnit
ns.setPlateStyle("full")
C_CVar=nil
UIErrorsFrame=nil; ns.nearbyUnits=realNearby; CVARS.nameplateShowFriendlyPlayers=cv
-- A cast sent at "Jean-Dupont" skips them for a while.
fire("UNIT_SPELLCAST_SENT","player","Jean-Dupont","guid",1243); ns.refreshWindow()
for _,e in ipairs(_G.BuffDiggerGive.entries) do assert(e.unit~="nameplate50", "just buffed: skipped") end
-- Same with "Jean Dupont", the form the game gives (seen in game, recette 45).
NOW=NOW+60; ns.refreshWindow(); local back; for _,e in ipairs(_G.BuffDiggerGive.entries) do back = back or e.unit=="nameplate50" end
assert(back, "listed again once the skip is over")
fire("UNIT_SPELLCAST_SENT","player","Jean Dupont","guid",1243); ns.refreshWindow()
for _,e in ipairs(_G.BuffDiggerGive.entries) do assert(e.unit~="nameplate50", "spell sent at \"Jean Dupont\": skipped too") end
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
BuffDiggerCharDB.asked={}; BuffDiggerDB.peers={}; b=#sent; ns.request("nameplate51"); print("ask:", sent[b+1], sent[b+2])
assert(sent[b+1]:find("^ADDON>Marie%-Curie:") and sent[b+2]:find("^WHISPER Marie%-Curie:"), "silent request and whisper to Marie-Curie")
assert(BuffDiggerCharDB.asked["Marie Curie"], "request kept under the whole name")
-- Marie buffs me: thanked by the whole name; the emote gets the first name (what worked in game).
myAuras[#myAuras+1]={auraInstanceID=500,name="Bénédiction de puissance",spellId=19740,sourceUnit="nameplate51",expirationTime=NOW+600,duration=600}
b=#sent; fire("UNIT_AURA","player"); thankWaiting(); for i=b+1,#sent do print("thanks:", sent[i]) end
local emote, whisper; for i=b+1,#sent do emote = emote or sent[i]=="EMOTE THANK Marie"; whisper = whisper or sent[i]:find("^WHISPER Marie%-Curie:") end
assert(emote and whisper, "Marie Curie thanked: /thank Marie, whisper to Marie-Curie")
print("=== Group (#16): members first under a header, even without a nameplate")
units.player={"Yann","WARRIOR",21}; BuffDiggerCharDB.asked={}; BuffDiggerDB.nearbyUseful=false
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
BuffDiggerCharDB.asked={}; ns.askBest(); assert(not BuffDiggerCharDB.asked.Tirion, "the key never asks a member out of sight")
-- Get buffs: the far member says so, greyed, after the members in sight; a click asks nothing.
BuffDiggerDB.nearby=true; ns.applyWindows(); local fe=_G.BuffDiggerNearby.entries; local tir, tirAt, lastNear
for i,x in ipairs(fe) do if x.unit=="party3" then tir, tirAt = x, i elseif x.group then lastNear = i end end
print("far member:", tir and tir.text); assert(tir and tir.far and not tir.text:find("(too far)", 1, true) and tirAt > lastNear, "far member flagged, after")
for _,r in ipairs(_G.BuffDiggerNearby.rows) do if r._shown and r.entry.buffs[1] then
  assert(r.buffs[1].icon._red == (r.entry.unit=="party3"), "red icons for the far member only") end end
local b=#sent; ns.request("party3"); assert(#sent==b and not BuffDiggerCharDB.asked.Tirion, "no whisper to a member out of sight")
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
for _,x in ipairs(fe) do assert(not x.group or x.first, "folded: only members I asked or have to thank listed") end
BuffDiggerDB.hideGroup.nearby=nil; BuffDiggerDB.nearby=false; ns.applyWindows()
UnitIsVisible=realVis; units.party3=nil; GetNumSubgroupMembers=function() return 2 end
-- The ask key looks at members too (in a dungeon, the only players it can see).
BuffDiggerCharDB.asked={}; local b=#sent; ns.askBest(); print("ask key:", sent[b+1]); assert(BuffDiggerCharDB.asked.Uther or BuffDiggerCharDB.asked.Anduin, "the key asks a member")
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
BuffDiggerCharDB.asked={}; b=#sent; m.click(); assert(BuffDiggerCharDB.asked.Arthas, "a line asks for that buff")
assert(#menu("MENU_UNIT_PLAYER","player")==0, "nothing on myself")
assert(#menu("MENU_UNIT_PLAYER",nil)==0, "nothing without a unit (name in chat)")
units.target={"Garrosh","WARRIOR",40}; assert(#menu("MENU_UNIT_PARTY","target")==0, "nothing when they can't buff")
units.target={"Arthas","PALADIN",25}; BuffDiggerDB.gameMenu=false; assert(#menu("MENU_UNIT_RAID_PLAYER","target")==0, "setting off: nothing")
BuffDiggerDB.gameMenu=true; units.target=nil

print("=== thanks by hand, only what I asked for (#21, #37)")
BuffDiggerCharDB.asked={}; myAuras={}; fire("UNIT_AURA","player"); runTimers()
units.nameplate30={"Malfurion","DRUID",40}; units.nameplate31={"Benedictus","PRIEST",40}
local function aura(id, name, spell, src) return {auraInstanceID=id,name=name,spellId=spell,sourceUnit=src,expirationTime=NOW+600,duration=600} end
local function asked(...) BuffDiggerCharDB.asked={}; for _,n in ipairs({...}) do BuffDiggerCharDB.asked[n]={at=time(), key="thorns", channel="WHISPER", target=n} end end
-- Asked Malfurion for Mark: it lands, nothing goes out, he waits with one row.
BuffDiggerCharDB.asked={Malfurion={at=time(), key="wild", channel="WHISPER", target="Malfurion-Realm"}}
b=#sent; myAuras[1]=aura(300,"spell1126",1126,"nameplate30"); fire("UNIT_AURA","player"); runTimers()
assert(#sent==b, "by hand: no automatic thanks"); assert(#ns.thanksWaiting()==1 and ns.thanksWaiting()[1].name=="Malfurion")
-- Then Thorns from him, unasked: not added to his row.
myAuras[2]=aura(301,"spell467",467,"nameplate30"); fire("UNIT_AURA","player")
local e=ns.thanksWaiting()[1]; assert(#ns.thanksWaiting()==1 and #e.keys==1, "unasked Thorns: not on his row")
-- An unasked Fortitude from a stranger, out of combat: no Thank line.
myAuras[3]=aura(302,"Mot de pouvoir : Robustesse",1243,"nameplate31"); fire("UNIT_AURA","player")
assert(#ns.thanksWaiting()==1 and ns.thanksWaiting()[1].name=="Malfurion", "unasked buff: no Thank line")
-- Thanking Malfurion: whisper in my request's channel and emote, both at once (a click: no delay, #24), row gone.
b=#sent; ns.thankBuffer("Malfurion"); assert(#sent==b+2 and sent[#sent]=="EMOTE THANK Malfurion")
print("thanked by hand:", sent[b+1]); assert(sent[b+1]:find("^WHISPER Malfurion%-Realm: ")); assert(#ns.thanksWaiting()==0)
runTimers(); assert(#sent==b+2, "nothing left for later")
-- Shift/Ctrl-click on a Thank line: the other channel. A whisper ask is thanked in /say.
asked("Whisperwind"); units.nameplate35={"Whisperwind","DRUID",40}; myAuras[#myAuras+1]=aura(399,"spell467",467,"nameplate35"); fire("UNIT_AURA","player")
b=#sent; ns.thankBuffer("Whisperwind", true); print("flipped to say:", sent[#sent]); assert(sent[b+1]:find("^SAY nil: Whisperwind : "), "flip: thanked in /say")
ns.dismissThank()
-- Asked again for buffs already on me: a re-read taken for a landing would show a Thank line (#25).
BuffDiggerCharDB.asked={Malfurion={at=time(), key="wild", channel="WHISPER", target="Malfurion"},
  Whisperwind={at=time(), key="thorns", channel="WHISPER", target="Whisperwind"}}
-- In combat my auras turn secret, then readable again: a buff I already had is not a new landing.
local ids={}; for k,a in ipairs(myAuras) do ids[k]=a.auraInstanceID; a.auraInstanceID=SECRET end
fire("UNIT_AURA","player"); for k,a in ipairs(myAuras) do a.auraInstanceID=ids[k] end
local rt=time; time=function() return rt()+120 end
fire("UNIT_AURA","player"); print("after combat:", #ns.thanksWaiting()); assert(#ns.thanksWaiting()==0, "secret in combat: no Thank after the fight"); time=rt
-- In combat the read can also throw instead of returning secrets: same thing, nothing forgotten.
local realRead=C_UnitAuras.GetAuraDataByIndex; C_UnitAuras.GetAuraDataByIndex=function() error("Auras cannot be accessed when secret") end
fire("UNIT_AURA","player"); C_UnitAuras.GetAuraDataByIndex=realRead
time=function() return rt()+240 end; fire("UNIT_AURA","player"); time=rt
assert(#ns.thanksWaiting()==0, "read error in combat: no Thank after the fight")
-- In combat my auras can also be missing from the list: not read at all then, nothing forgotten.
InCombatLockdown=function() return true end; local saved=myAuras; myAuras={}
C_UnitAuras.GetAuraDataByIndex=function(u,i) if u=="player" then return myAuras[i] end end
fire("UNIT_AURA","player"); myAuras=saved; C_UnitAuras.GetAuraDataByIndex=realRead; InCombatLockdown=function() return false end
time=function() return rt()+360 end; fire("PLAYER_REGEN_ENABLED"); time=rt
assert(#ns.thanksWaiting()==0, "auras missing in combat: no Thank after the fight")
-- A buff I asked for that lands in combat: nothing then, one Thank line once the fight ends.
BuffDiggerCharDB.asked={Tirion={at=time(), key="kings", channel="WHISPER", target="Tirion"}}; units.nameplate40={"Tirion","PALADIN",40}; InCombatLockdown=function() return true end
myAuras[#myAuras+1]=aura(390,"Bénédiction des rois",20217,"nameplate40"); fire("UNIT_AURA","player"); assert(#ns.thanksWaiting()==0, "in combat: not yet")
InCombatLockdown=function() return false end; fire("PLAYER_REGEN_ENABLED")
assert(#ns.thanksWaiting()==1 and ns.thanksWaiting()[1].name=="Tirion", "after the fight: one Thank"); ns.dismissThank(); table.remove(myAuras); fire("UNIT_AURA","player")
-- Two priests' Fortitude on me (journal 2026-11-15), new instance IDs after the fight: neither is a new landing.
units.nameplate38={"Cecirae","PRIEST",33}; units.nameplate39={"Bismillos","PRIEST",35}
myAuras[#myAuras+1]=aura(380,"Mot de pouvoir : Robustesse",1243,"nameplate38"); myAuras[#myAuras].expirationTime=NOW+1800; myAuras[#myAuras].duration=3600 -- landed half an hour ago
myAuras[#myAuras+1]=aura(381,"Mot de pouvoir : Robustesse",1243,"nameplate39"); myAuras[#myAuras].expirationTime=NOW+1801; myAuras[#myAuras].duration=3600 -- landed half an hour ago
time=function() return rt()+480 end; fire("UNIT_AURA","player"); ns.dismissThank()
BuffDiggerCharDB.asked={Cecirae={at=time(), key="fortitude", channel="WHISPER", target="Cecirae"},
  Bismillos={at=time(), key="fortitude", channel="WHISPER", target="Bismillos"}} -- asked again: still no landing
myAuras[#myAuras-1].auraInstanceID=382; myAuras[#myAuras].auraInstanceID=383
time=function() return rt()+600 end; fire("UNIT_AURA","player"); time=rt
print("two Forts, new IDs:", #ns.thanksWaiting()); assert(#ns.thanksWaiting()==0, "two Forts, new IDs: no Thank")
table.remove(myAuras); table.remove(myAuras); fire("UNIT_AURA","player")
-- A buff that falls off while my auras are secret is gone once the fight ends.
local idOf={}; for _,a in ipairs(myAuras) do idOf[a]=a.auraInstanceID; a.auraInstanceID=SECRET end
local function held() local n=0 for k in pairs(ns.BUFFS) do if ns.haveBuff(k) then n=n+1 end end return n end
local had=held(); local gone=table.remove(myAuras, 1); fire("UNIT_AURA","player") -- Mark (1126): the only one
for a,id in pairs(idOf) do a.auraInstanceID=id end
fire("PLAYER_REGEN_ENABLED"); assert(held()==had-1 and #ns.thanksWaiting()==0, "the buff that fell off in combat is gone")
table.insert(myAuras, 1, gone); fire("UNIT_AURA","player"); ns.dismissThank() -- back as it was for what follows
-- His renewal, unasked: no row; asked in /say: a row, and the click sends it in /say right away.
myAuras[3].expirationTime=NOW+1800; fire("UNIT_AURA","player"); assert(#ns.thanksWaiting()==0, "renewal, unasked")
BuffDiggerCharDB.asked={Benedictus={at=time(), key="fortitude", channel="SAY", target="Benedictus"}}
myAuras[3].expirationTime=NOW+2100; fire("UNIT_AURA","player"); assert(#ns.thanksWaiting()==1, "renewal, asked")
b=#sent; ns.thankBuffer("Benedictus"); print("say by hand:", sent[b+1]); assert(sent[b+1]:find("^SAY nil: Benedictus : "))
-- Nothing to send (both boxes off): no row. Rows expire after 5 minutes.
asked("Hamuul", "Remulos"); BuffDiggerDB.thank, BuffDiggerDB.thankMessage = false, false
units.nameplate33={"Hamuul","DRUID",40}; myAuras[4]=aura(303,"spell467",467,"nameplate33"); fire("UNIT_AURA","player"); assert(#ns.thanksWaiting()==0)
BuffDiggerDB.thank, BuffDiggerDB.thankMessage = true, true
units.nameplate34={"Remulos","DRUID",40}; myAuras[5]=aura(304,"spell467",467,"nameplate34"); fire("UNIT_AURA","player"); assert(#ns.thanksWaiting()==1)
local realTime=time; time=function() return realTime()+301 end; assert(#ns.thanksWaiting()==0, "expired"); time=realTime
-- The list (no Thanks window any more): newest first, Thank thanks, dismiss forgets.
asked("Cenarius","Lunara","Broll")
units.nameplate35={"Cenarius","DRUID",40}; myAuras[6]=aura(305,"spell467",467,"nameplate35"); fire("UNIT_AURA","player")
units.nameplate36={"Lunara","DRUID",40}; myAuras[7]=aura(306,"spell467",467,"nameplate36"); fire("UNIT_AURA","player")
assert(_G.BuffDiggerThanks==nil, "no Thanks window")
local w1=ns.thanksWaiting(); assert(#w1==2 and w1[1].name=="Lunara" and w1[2].name=="Cenarius" and #w1[1].keys==1, "newest first, one buff each")
ns.thankBuffer("Lunara"); assert(sent[#sent]=="EMOTE THANK Lunara" and ns.thanksWaiting()[1].name=="Cenarius")
runTimers(); b=#sent; ns.dismissThank("Cenarius"); runTimers(); assert(#sent==b and #ns.thanksWaiting()==0, "forgotten, nothing sent")
units.nameplate37={"Broll","DRUID",40}; myAuras[8]=aura(307,"spell467",467,"nameplate37"); fire("UNIT_AURA","player"); ns.dismissThank()
assert(#ns.thanksWaiting()==0, "all forgotten")
-- The key: the newest line.
asked("Cenarius"); units.nameplate35={"Cenarius","DRUID",40}; myAuras[#myAuras+1]=aura(319,"spell467",467,"nameplate35"); myAuras[#myAuras].expirationTime=NOW+900 -- his recast ends later
fire("UNIT_AURA","player")
BuffDigger.thankLast(); assert(sent[#sent]=="EMOTE THANK Cenarius", "key: the newest line")
-- Full list: the oldest goes.
asked("Remulos","Druid1","Druid2","Druid3","Druid4","Druid5"); units.nameplate34={"Remulos","DRUID",40}; myAuras[#myAuras+1]=aura(321,"spell467",467,"nameplate34"); myAuras[#myAuras].expirationTime=NOW+900 -- his recast ends later
fire("UNIT_AURA","player")
for i=1,5 do units["nameplate"..(47+i)]={"Druid"..i,"DRUID",40}; myAuras[#myAuras+1]=aura(321+i,"spell467",467,"nameplate"..(47+i)); fire("UNIT_AURA","player") end
local names={}; for _,x in ipairs(ns.thanksWaiting()) do names[x.name]=true end
assert(#ns.thanksWaiting()==5 and not names.Remulos and names.Druid1, "full: the oldest goes")
ns.dismissThank()
-- Key "Thank the last player who buffed me": the newest line; nobody left -> nothing sent.
asked("Naralex", "Keeper")
units.nameplate38={"Naralex","DRUID",40}; myAuras[9]=aura(308,"spell467",467,"nameplate38"); fire("UNIT_AURA","player")
units.nameplate39={"Keeper","DRUID",40}; myAuras[10]=aura(309,"spell467",467,"nameplate39"); fire("UNIT_AURA","player")
BuffDigger.thankLast(); assert(sent[#sent]=="EMOTE THANK Keeper" and ns.thanksWaiting()[1].name=="Naralex")
BuffDigger.thankLast(); runTimers(); b=#sent; BuffDigger.thankLast(); runTimers(); assert(#sent==b and #ns.thanksWaiting()==0)
-- Dismissing a line I asked for closes that request.
units.nameplate40={"Aponi","DRUID",40}; BuffDiggerCharDB.asked={Aponi={at=time(), key="thorns", channel="WHISPER", target="Aponi"}}
myAuras[11]=aura(311,"spell467",467,"nameplate40"); fire("UNIT_AURA","player"); assert(ns.thanksWaiting()[1].name=="Aponi")
ns.dismissThank("Aponi"); assert(BuffDiggerCharDB.asked.Aponi.thanked, "skipped: request answered")
print("=== a re-read of my auras never makes a Thank line (#25, #26)")
do
  ns.dismissThank()
  local savedAsked, realRead, rt, base = BuffDiggerCharDB.asked, C_UnitAuras.GetAuraDataByIndex, time, #myAuras
  -- s seconds later, both clocks: a buff's start (GetTime) is compared with my request's time() (#30).
  local now0=NOW; local function at(s) time=function() return rt()+s end; NOW=now0+s end
  local function waiting() return #ns.thanksWaiting() end
  units.party1={"Ilyria","PRIEST",33}; units.party2={"Corwen","PRIEST",35}
  -- (1) Two buffs asked from my group, dismissed, then asked again: same auras, so no new line. A minute
  -- later, out of combat, the read gives nil (auras still secret: restriction lifted after
  -- PLAYER_REGEN_ENABLED, or never announced): nothing comes back.
  local function askBoth() BuffDiggerCharDB.asked={Ilyria={at=time(), key="fortitude", channel="WHISPER", target="Ilyria"},
    Corwen={at=time(), key="spirit", channel="WHISPER", target="Corwen"}} end
  askBoth()
  myAuras[base+1]=aura(9500,"Mot de pouvoir : Robustesse",1243,"party1"); myAuras[base+1].expirationTime=NOW+1800
  myAuras[base+2]=aura(9501,"spell14752",14752,"party2"); myAuras[base+2].expirationTime=NOW+1801
  fire("UNIT_AURA","player"); assert(waiting()==2, "two asked buffs seen live: two rows"); ns.dismissThank(); at(30); askBoth()
  -- A fight (the payload is secret), then a read that gives nil when it ends.
  at(60); InCombatLockdown=function() return true end; fire("UNIT_AURA","player"); InCombatLockdown=function() return false end
  at(120); C_UnitAuras.GetAuraDataByIndex=function() return nil end
  fire("PLAYER_REGEN_ENABLED"); runTimers(); assert(not ns.haveBuff("spirit"), "nothing read: no buff shown")
  C_UnitAuras.GetAuraDataByIndex=realRead; fire("UNIT_AURA","player"); runTimers()
  assert(ns.haveBuff("spirit"), "read again: shown again")
  print("nil read, no lockdown -> waiting:", waiting()); assert(waiting()==0, "nil read out of lockdown: no Thank line after it")
  -- (2) Restricted map (dungeon, out of combat): C_Secrets says auras are secret, the read only gives the
  -- auras flagged non-secret. Still nothing once readable again.
  at(240); C_Secrets={ShouldAurasBeSecret=function() return true end}
  C_UnitAuras.GetAuraDataByIndex=function(u,i) if u=="player" and i<=base then return myAuras[i] end end
  fire("UNIT_AURA","player"); runTimers()
  C_Secrets=nil; C_UnitAuras.GetAuraDataByIndex=realRead; fire("UNIT_AURA","player"); runTimers()
  print("restricted map -> waiting:", waiting()); assert(waiting()==0, "restricted map: no Thank line after it")
  -- Same partial list, nothing says it is partial (no C_Secrets): the missing buffs come back as the same auras.
  at(270); C_UnitAuras.GetAuraDataByIndex=function(u,i) if u=="player" and i<=base then return myAuras[i] end end
  fire("PLAYER_REGEN_ENABLED"); runTimers()
  C_UnitAuras.GetAuraDataByIndex=realRead; fire("UNIT_AURA","player"); runTimers()
  print("partial read -> waiting:", waiting()); assert(waiting()==0, "partial read: no Thank line after it")
  table.remove(myAuras); table.remove(myAuras); fire("UNIT_AURA","player"); ns.dismissThank()
  -- An unasked buff landing mid-fight: no row after it.
  at(285); BuffDiggerCharDB.asked={}; InCombatLockdown=function() return true end
  myAuras[base+1]=aura(9505,"spell14752",14752,"party2"); fire("UNIT_AURA","player")
  InCombatLockdown=function() return false end; fire("PLAYER_REGEN_ENABLED"); runTimers()
  assert(waiting()==0, "unasked, mid-fight: no row"); assert(ns.haveBuff("spirit"))
  table.remove(myAuras); fire("UNIT_AURA","player")
  -- (3) Journal 2026-11-15: two requests, two landings, two thanks, then 12 fights with no new aura.
  units.party1={"Seraphine","PRIEST",33}; units.party2={"Aldric","PRIEST",35}; at(300)
  BuffDiggerCharDB.asked={Seraphine={at=time(), key="fortitude", channel="WHISPER", target="Seraphine"},
    Aldric={at=time(), key="spirit", channel="WHISPER", target="Aldric"}}
  myAuras[base+1]=aura(9510,"Mot de pouvoir : Robustesse",1243,"party1"); myAuras[base+1].expirationTime=NOW+3000; myAuras[base+1].duration=3000
  myAuras[base+2]=aura(9511,"spell14752",14752,"party2"); myAuras[base+2].expirationTime=NOW+3001; myAuras[base+2].duration=3001
  fire("UNIT_AURA","player"); assert(waiting()==2, "two asked buffs: two rows")
  ns.thankBuffer("Seraphine"); ns.thankBuffer("Aldric"); runTimers(); assert(waiting()==0)
  local function askBoth2() BuffDiggerCharDB.asked={Seraphine={at=time(), key="fortitude", channel="WHISPER", target="Seraphine"},
    Aldric={at=time(), key="spirit", channel="WHISPER", target="Aldric"}} end
  local inFight={function() error("Auras cannot be accessed when secret") end, function() return nil end,
    function(u,i) if myAuras[i] then return {auraInstanceID=SECRET,name=SECRET} end end}
  for cycle=1,12 do
    at(300+70*cycle); askBoth2() -- asked again each fight: only a real new aura could make a line InCombatLockdown=function() return true end; fire("PLAYER_REGEN_DISABLED")
    InCombatLockdown=function() return false end -- what the read gives when the lockdown check misses it
    -- The payload is secret in a fight (#30): the full read comes after it, and gives what inFight gives.
    C_UnitAuras.GetAuraDataByIndex=inFight[cycle%3+1]; fire("UNIT_AURA","player",SECRET)
    if cycle%2==0 then C_UnitAuras.GetAuraDataByIndex=function() return nil end else C_UnitAuras.GetAuraDataByIndex=realRead end
    fire("PLAYER_REGEN_ENABLED"); runTimers()
    C_UnitAuras.GetAuraDataByIndex=realRead; fire("UNIT_AURA","player"); runTimers()
    assert(waiting()==0, "fight "..cycle..": no Thank line without a new aura")
  end
  table.remove(myAuras); table.remove(myAuras); fire("UNIT_AURA","player")
  time=rt; units.party1=nil; units.party2=nil; BuffDiggerCharDB.asked=savedAsked; ns.dismissThank()
end
print("=== my buffs followed by UNIT_AURA's updateInfo (#30)")
do
  ns.dismissThank(); BuffDiggerCharDB.asked={}
  local realRead, reads, savedAuras = C_UnitAuras.GetAuraDataByIndex, 0, myAuras
  C_UnitAuras.GetAuraDataByIndex=function(...) reads=reads+1 return realRead(...) end
  local function waiting() return #ns.thanksWaiting() end
  local function ask(n, key) BuffDiggerCharDB.asked[n]={at=time(), key=key, channel="WHISPER", target=n} end
  units.nameplate60={"Mograine","PRIEST",40}
  -- Fortitude from him, half an hour ago (end and duration readable, as out of combat).
  local fort={auraInstanceID=6000,name="Mot de pouvoir : Robustesse",spellId=1243,sourceUnit="nameplate60",points={32},expirationTime=NOW+1800,duration=3600}
  myAuras={fort}; fire("UNIT_AURA","player"); runTimers(); reads=0
  -- Ghost Wolf while I asked him to refresh it: a new ID, same buff, same end. Not his answer: no line.
  ask("Mograine","fortitude")
  local function giver() return BuffDigger.debugState().mine.fortitude.giver end
  fort.auraInstanceID=6001; fort.sourceUnit=nil; fire("UNIT_AURA","player")
  assert(waiting()==0, "Ghost Wolf: a new ID for the buff I had is not a landing")
  assert(giver()=="Mograine", "Ghost Wolf: the giver is kept, even when the new aura doesn't name him")
  -- The same in two payloads (removed, then added): its start, an hour before, still says it is old.
  fort.sourceUnit="nameplate60"; local keep=table.remove(myAuras, 1); fire("UNIT_AURA","player")
  keep.auraInstanceID=6011; myAuras[1]=keep; fire("UNIT_AURA","player")
  assert(waiting()==0, "Ghost Wolf in two payloads: no line")
  -- A zone change: a full read that keeps what I knew by ID (his unit token is gone by then).
  fort.sourceUnit=nil; fire("PLAYER_ENTERING_WORLD", false, false); assert(giver()=="Mograine", "zone change: giver kept")
  fort.sourceUnit="nameplate60"; fire("UNIT_AURA","player"); reads=0
  -- He recasts it (same ID, end an hour away): the refresh I asked for, a Thank line.
  fort.expirationTime=NOW+3600; fire("UNIT_AURA","player")
  assert(waiting()==1 and ns.thanksWaiting()[1].name=="Mograine", "a refresh I asked for is thanked")
  ns.thankBuffer("Mograine")
  -- Unasked recast: nothing. None of the above read all my auras.
  NOW=NOW+60; fort.expirationTime=NOW+3600; fire("UNIT_AURA","player")
  assert(waiting()==0 and reads==0, "ordinary UNIT_AURA: no full read")
  -- Food (not a Data.lua buff): nothing to refresh.
  runTimers(); myAuras[2]={auraInstanceID=6002,name="Food",spellId=433,sourceUnit="nameplate60"}; fire("UNIT_AURA","player")
  assert(#TIMERS==0, "an aura that isn't a buff of Data.lua refreshes nothing")
  -- A full update: one silent full read. It honors the buff I asked for that started after my request,
  -- not the one I already had.
  ask("Mograine","fortitude"); units.nameplate61={"Saidan","PALADIN",40}; ask("Saidan","kings"); NOW=NOW+30
  myAuras[3]={auraInstanceID=6003,name="Bénédiction des rois",spellId=20217,sourceUnit="nameplate61",expirationTime=NOW+600,duration=600}
  fire("UNIT_AURA","player",{isFullUpdate=true})
  assert(reads>0 and waiting()==1 and ns.thanksWaiting()[1].name=="Saidan", "full update: only the asked buff given after the request")
  ns.dismissThank(); reads=0
  -- Kings removed: gone at once.
  table.remove(myAuras, 3); fire("UNIT_AURA","player"); assert(not ns.haveBuff("kings") and ns.haveBuff("fortitude") and reads==0)
  -- A restricted map while the payload still reads (nothing says it can't): stale, a full read once readable.
  C_Secrets={ShouldAurasBeSecret=function() return SECRET_AURAS end} -- an earlier scenario removed it
  SECRET_AURAS=true; myAuras[3]={auraInstanceID=6004,name="Bénédiction des rois",spellId=20217,sourceUnit="nameplate61",expirationTime=NOW+600,duration=600}
  ask("Saidan","kings"); fire("UNIT_AURA","player"); assert(waiting()==0 and not ns.haveBuff("kings"), "restricted: nothing yet")
  SECRET_AURAS=false; fire("ADDON_RESTRICTION_STATE_CHANGED", 4, 0)
  assert(ns.haveBuff("kings") and waiting()==1, "readable again: the asked Kings is honored")
  ns.dismissThank()
  -- A line left to run out (not clicked): its request is answered, Ghost Wolf doesn't bring it back.
  ask("Saidan","kings"); NOW=NOW+30; local kings={auraInstanceID=6005,name="Bénédiction des rois",spellId=20217,sourceUnit="nameplate61",expirationTime=NOW+600,duration=600}
  myAuras[4]=kings; fire("UNIT_AURA","player"); assert(waiting()==1)
  local rt=time; time=function() return rt()+301 end; assert(waiting()==0, "ran out")
  kings.auraInstanceID=6006; fire("UNIT_AURA","player"); assert(waiting()==0, "Ghost Wolf after a line ran out: no line again"); time=rt
  C_UnitAuras.GetAuraDataByIndex=realRead; BuffDiggerCharDB.asked={}
  myAuras=savedAuras; fire("UNIT_AURA","player"); units.nameplate60=nil; units.nameplate61=nil; runTimers()
end
print("=== giver found by GUID when his nameplate is gone (#41)")
do
  ns.dismissThank(); BuffDiggerCharDB.asked={}; local savedAuras=myAuras
  local function ask(n, key) BuffDiggerCharDB.asked[n]={at=time(), key=key, channel="WHISPER", target=n} end
  PLAYERS["Player-1-A"]={"Lin Dupont","PALADIN",40}; PLAYERS["Player-1-B"]={"Griff Martin","MAGE",40}
  ask("Lin Dupont","kings"); NOW=NOW+30
  -- Recette 2: Kings from Lin, her nameplate just removed (sourceUnit nil): the GUID names her.
  local kings={auraInstanceID=7000,name="Bénédiction des rois",spellId=20217,sourceUnit=nil,casterGUID="Player-1-A",expirationTime=NOW+600,duration=600}
  myAuras={kings}; fire("UNIT_AURA","player")
  assert(#ns.thanksWaiting()==1 and ns.thanksWaiting()[1].name=="Lin Dupont", "no nameplate: the caster's GUID names the giver")
  assert(BuffDigger.debugState().mine.kings.giver=="Lin Dupont")
  ns.dismissThank()
  -- A GUID that can't give it (a mage's Kings) or nobody asked: no line (#37).
  ask("Griff Martin","kings"); NOW=NOW+30; kings.auraInstanceID=7001; kings.casterGUID="Player-1-B"; kings.expirationTime=NOW+600
  fire("UNIT_AURA","player"); assert(#ns.thanksWaiting()==0, "a GUID of the wrong class gives no line")
  -- Restricted: not read (the call would fail), nothing until readable.
  ask("Lin Dupont","kings"); NOW=NOW+30; SECRET_AURAS=true; kings.auraInstanceID=7002; kings.casterGUID="Player-1-A"; kings.expirationTime=NOW+600
  fire("UNIT_AURA","player"); assert(#ns.thanksWaiting()==0, "restricted: nothing read")
  SECRET_AURAS=false; fire("ADDON_RESTRICTION_STATE_CHANGED", 4, 0)
  assert(#ns.thanksWaiting()==1 and ns.thanksWaiting()[1].name=="Lin Dupont", "readable again: the GUID names her")
  ns.dismissThank()
  -- A stale token (now an NPC, then a druid) or a secret one: the GUID names her; her level hidden is fine.
  units.nameplate70={"Elune","DRUID",40}; PLAYERS["Player-1-A"][3]=nil
  for i, src in ipairs({"nameplate71", "nameplate70", SECRET}) do
    ask("Lin Dupont","kings"); NOW=NOW+30; kings.auraInstanceID=7010+i; kings.sourceUnit=src; kings.expirationTime=NOW+600
    fire("UNIT_AURA","player")
    assert(#ns.thanksWaiting()==1 and ns.thanksWaiting()[1].name=="Lin Dupont", "stale or secret token "..i..": the GUID wins")
    ns.dismissThank()
  end
  units.nameplate70=nil; BuffDiggerCharDB.asked={}; PLAYERS={}; myAuras=savedAuras; fire("UNIT_AURA","player"); runTimers()
end
print("=== Get buffs: my request amber, the buff gold (#24)")
BuffDiggerCharDB.asked={}; ns.dismissThank()
units.nameplate42={"Tyrande","DRUID",40}; units.nameplate43={"Shandris","DRUID",40}
fire("NAME_PLATE_UNIT_ADDED","nameplate42"); fire("NAME_PLATE_UNIT_ADDED","nameplate43"); runTimers()
local gw2=_G.BuffDiggerNearby; gw2:Show()
local function lineOf(name) for _,r in ipairs(gw2.rows) do if r._shown and r.entry and r.entry.who==name then return r end end end
-- Nothing better from them and "only those with something better": hidden until I ask.
local realBest2=ns.bestBuff; ns.bestBuff=function(name, ...) if name=="Tyrande" or name=="Shandris" then return nil end return realBest2(name, ...) end
BuffDiggerDB.nearbyUseful=true; ns.refreshWindow(); assert(not lineOf("Tyrande"))
ns.request("nameplate42", "thorns"); ns.refreshWindow(); local r=lineOf("Tyrande")
print("asked line:", r and r.text._t); assert(r and r.state=="asked" and r.close._shown and r.band._shown and r.status._shown and not r.thank._shown, "asked: kept, a band, a cross")
assert(r.entry.order==-0.5 and r:GetAttribute("macrotext")=="/target Tyrande", "first of Around, the name still targets")
-- Her Thorns lands: gold (one flash), the click thanks (at once) and doesn't target; Thanks stays hidden.
myAuras[13]=aura(313,"spell467",467,"nameplate42"); fire("UNIT_AURA","player"); ns.refreshWindow(); r=lineOf("Tyrande")
print("thank line:", r.text._t); assert(r.state=="thank" and r.thank._shown and r.band._shown and r:GetAttribute("*type1")==nil)
assert(r.text._t==r.entry.text, "the name keeps its class colour")
local plays=0; for _,row in ipairs(gw2.rows) do row.pulse.Play=function() plays=plays+1 end end
ns.refreshWindow(); assert(plays==0, "already flashed: no flash on refresh")
b=#sent; for _,f in ipairs(r._hooks.PostClick) do f(r,"LeftButton",false) end
assert(#sent==b and r.state=="thank", "a click on the gold line itself sends nothing")
assert(r.thankButton._shown); r.thankButton._OnClick(r.thankButton)
assert(#sent==b+2 and sent[b+1]:find("^WHISPER Tyrande") and sent[b+2]=="EMOTE THANK Tyrande", "gold click thanks at once")
assert(r.state==nil and not r.close._shown and not r.band._shown and not r.thank._shown and r:GetAttribute("macrotext")=="/target Tyrande", "back to normal")
ns.refreshWindow(); assert(not lineOf("Tyrande"), "thanked: the filter applies again")
-- The cross on an amber line: nothing sent, the request closed.
ns.request("nameplate43", "thorns"); ns.refreshWindow(); r=lineOf("Shandris"); assert(r.state=="asked")
b=#sent; r.close._OnClick(r.close); assert(#sent==b and BuffDiggerCharDB.asked.Shandris.thanked and r.state==nil, "cross: closed, silent")
-- No buff in time: amber goes on its own.
BuffDiggerCharDB.asked.Shandris={at=time()-BuffDiggerDB.delay, key="thorns", channel="WHISPER"}; assert(ns.askState("Shandris")==nil, "expired")
-- His buff lands while the cursor is still on Get buffs: gold anyway, never in Thanks.
units.nameplate44={"Mathrengyl","DRUID",40}; fire("NAME_PLATE_UNIT_ADDED","nameplate44"); runTimers()
ns.request("nameplate44", "wild"); ns.refreshWindow(); assert(lineOf("Mathrengyl").state=="asked"); gw2.IsMouseOver=function() return true end
myAuras[#myAuras+1]=aura(315,"spell1126",1126,"nameplate44"); fire("UNIT_AURA","player"); ns.refreshWindow(); r=lineOf("Mathrengyl")
assert(r.state=="thank", "hovered: gold on Get buffs"); gw2.IsMouseOver=nil
-- Combat hides Get buffs: his line waits.
InCombatLockdown=function() return true end; fire("PLAYER_REGEN_DISABLED"); assert(not gw2._shown and ns.askState("Mathrengyl")=="thank", "combat: Get buffs hidden, the line waits")
InCombatLockdown=function() return false end; fire("PLAYER_REGEN_ENABLED"); gw2:Show(); ns.refreshWindow()
-- The cross on his gold line, while I asked him for something else since: that request stays open.
BuffDiggerCharDB.asked.Mathrengyl={at=time(), key="thorns", channel="WHISPER"}; ns.closeAsk("Mathrengyl")
assert(not BuffDiggerCharDB.asked.Mathrengyl.thanked and ns.askState("Mathrengyl")=="asked", "skipping a thank-you keeps the open request")
-- His thank-you skipped away from his line (closeAsk): the Thorns I asked flashes again.
local flashes=0; for _,row in ipairs(gw2.rows) do row.pulse.Play=function() flashes=flashes+1 end end
ns.refreshWindow(); myAuras[#myAuras+1]=aura(316,"spell467",467,"nameplate44"); fire("UNIT_AURA","player"); ns.refreshWindow()
assert(lineOf("Mathrengyl").state=="thank" and flashes==1, "a new buff from him flashes again"); ns.dismissThank("Mathrengyl")
-- A late buff (asked less than 10 minutes ago, past the delay) while Get buffs is closed: it waits for Get buffs.
myAuras[#myAuras+1]=aura(314,"spell467",467,"nameplate43"); fire("UNIT_AURA","player"); ns.refreshWindow(); r=lineOf("Shandris")
assert(r.state=="thank")
-- She walks out of sight: her gold line stays on Get buffs (no icons).
units.nameplate43=nil; fire("NAME_PLATE_UNIT_REMOVED","nameplate43"); ns.refreshWindow(); r=lineOf("Shandris")
print("gone line:", r and r.text._t); assert(r and r.state=="thank" and #r.entry.buffs==0 and r.text._t:find("^|cff808080Shandris"), "out of sight: still on Get buffs, name grey")
ns.dismissThank(); ns.bestBuff=realBest2; BuffDiggerDB.nearbyUseful=false
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
pw.copy._OnClick(pw.copy); assert(typed:find("^Could I get {spell} please%?\n") and #BuffDiggerDB.custom.new==#ns.MESSAGES.en.casual.new, typed)
pw.tabs[5]._OnClick(pw.tabs[5]); pw.copy._OnClick(pw.copy); assert(BuffDiggerDB.custom.thanks[1]=="Thanks!")
ns.setCustom("new", ""); ns.setCustom("thanks", "")
-- #52: the settings window, in tabs. Self-contained: puts back what it changes.
do
  local s = _G.BuffDiggerSettings
  local function rows() local all = {} for _, p in ipairs(s.panels) do for _, r in ipairs(p.rows) do all[#all+1] = r end end return all end
  local function rowFor(key) for _, r in ipairs(rows()) do if r.def.key == key then return r end end end
  local function click(b) b._OnClick(b) end
  -- No setting lost: each key of ns.DEFAULTS in exactly one row (those without a box aside), none unknown.
  local seen, noBox, kinds = {}, { lockWindows = true, requests = true, showAdvanced = true }, {}
  for _, r in ipairs(rows()) do
    local k = r.def.key
    if r.def.kind then kinds[r.def.kind] = true end
    if k then assert(ns.DEFAULTS[k] ~= nil, "row for an unknown key: "..k); assert(not seen[k], "two rows for "..k); seen[k] = true end
  end
  for k in pairs(ns.DEFAULTS) do assert(seen[k] or noBox[k], "setting in no tab: "..k) end
  assert(kinds.prefs and kinds.plates and kinds.keys, "priorities, the game's nameplates, key bindings")
  -- Opens on General; a tab shows its panel and hides the others; opening again goes back to General.
  ns.toggleSettings(); assert(s:IsShown() and s.selectedTab == 1 and s.panels[1]:IsShown())
  click(s.tabButtons[2]); assert(s.selectedTab == 2 and s.panels[2]:IsShown())
  for i, p in ipairs(s.panels) do assert(i == 2 or not p:IsShown(), "only Buffs shows") end
  ns.toggleSettings(); assert(not s:IsShown()); ns.toggleSettings()
  assert(s.selectedTab == 1 and s.panels[1]:IsShown() and not s.panels[2]:IsShown(), "back on General")
  -- Fixed size; every column ends above the bottom line, with 13 priorities (#47 adds water and food).
  local saved, n = BuffDiggerDB.showAdvanced, 0
  for _ in pairs(ns.BUFFS) do n = n + 1 end
  BuffDiggerDB.showAdvanced = true
  assert(s:GetHeight() == 464)
  for i in ipairs(s.panels) do
    click(s.tabButtons[i])
    for c, col in ipairs(s.panels[i].columns) do
      local bottom = col.bottom - ((i == 2 and c == 1) and (13 - n) * 24 or 0)
      assert(bottom >= s.limit, ("tab %d column %d overflows: %d < %d"):format(i, c, bottom, s.limit))
    end
  end
  -- Each widget writes the key it wrote before.
  local box = rowFor("useSay").control
  box.GetChecked = function() return false end; BuffDiggerDB.useSay = true; click(box); assert(BuffDiggerDB.useSay == false)
  box.GetChecked = nil; click(box); assert(BuffDiggerDB.useSay == true); BuffDiggerDB.useSay = false
  BuffDiggerDB.tone = "casual"; click(rowFor("tone").control); assert(BuffDiggerDB.tone == "polite"); BuffDiggerDB.tone = "casual"
  BuffDiggerDB.delay = 120; click(rowFor("delay").control); assert(BuffDiggerDB.delay == 300); BuffDiggerDB.delay = 120
  -- A tooltip on every setting, on its control and on its label (the row): the label, then the tip.
  local tip = {}
  GameTooltip.AddLine = function(_, t) tip[#tip+1] = t end
  local function hover(w) tip = {}; assert(w._OnEnter, "no tooltip"); w._OnEnter(w); return tip end
  for _, r in ipairs(rows()) do
    local what = r.def.key or r.def.kind
    if what and r.def.kind ~= "help" and r.def.kind ~= "prefs" and r.def.kind ~= "phrases" then
      assert(r.def.tip and r.def.tip ~= "", "no tip: "..what)
      for _, w in ipairs({ r.control, r }) do
        hover(w); assert(tip[1] == r.def.label and tip[2] == r.def.tip, "tooltip of "..what..": "..tostring(tip[1]))
      end
    end
  end
  local prefs; for _, r in ipairs(rows()) do if r.def.kind == "prefs" then prefs = r end end
  s._OnShow(s); hover(prefs.lines[1].box); assert(tip[1] and tip[2]:find("^Ticked"), "priority line")
  hover(prefs.reset); assert(tip[2]:find("default"), "Reset")
  GameTooltip.AddLine = nil
  -- Key bindings: the key each one has, or Not bound.
  local keys; for _, r in ipairs(rows()) do if r.def.kind == "keys" then keys = r end end
  BOUND = nil; keys._OnShow(keys); assert(keys.keys[1]._t:find("Not bound"))
  BOUND = "F5"; keys._OnShow(keys); assert(keys.keys[1]._t == "F5"); BOUND = nil
  local said; local realNotice = ns.notice; ns.notice = function(t) said = t end
  click(keys.control); assert(said:find("Keybindings > AddOns"), "no settings API: says where"); ns.notice = realNotice
  BuffDiggerDB.showAdvanced = saved; s:Hide()
end
print("SETTINGS OK")
-- #38: requests are per character. Each character has its own BuffDiggerCharDB (the game swaps it at
-- login); settings stay in the account-wide BuffDiggerDB. Self-contained: puts back what it changes.
do
  local realBuild, savedChar, savedPlayer, savedAuras, savedSpell = ns.buildUI, BuffDiggerCharDB, units.player, myAuras, IsPlayerSpell
  local function login(charDB) BuffDiggerCharDB = charDB; ns.buildUI = nil; fire("ADDON_LOADED", "BuffDigger"); ns.buildUI = realBuild end
  -- Migration: the first character loaded takes the old account-wide requests, once.
  BuffDiggerDB.asked = { Old = { at = time(), key = "kings", channel = "WHISPER", target = "Old" } }
  login(nil); local first = BuffDiggerCharDB
  assert(first.asked.Old and BuffDiggerDB.asked == nil, "first character takes the old requests, account key gone")
  login(nil); local second = BuffDiggerCharDB
  assert(next(second.asked) == nil, "second character starts empty")
  login(first); assert(first.asked.Old, "a character keeps its own requests at the next login")
  -- Two characters: asking with one doesn't block the other.
  units.player = { "Yann", "WARRIOR", 21 }; IsPlayerSpell = function() return false end; myAuras = {}
  units.nameplate90 = { "Turalyon", "PALADIN", 40 }; fire("NAME_PLATE_UNIT_ADDED", "nameplate90"); runTimers()
  first.asked = {}; ns.request("nameplate90")
  assert(first.asked.Turalyon and ns.askedAgo("Turalyon"), "first character asked")
  login(second); local b = #sent; ns.request("nameplate90")
  print("#38 second character asks:", sent[b + 1]); assert(#sent > b and second.asked.Turalyon, "the other character is not blocked")
  assert(BuffDiggerDB.asked == nil and BuffDiggerDB.delay, "settings shared, no requests in them")
  fire("NAME_PLATE_UNIT_REMOVED", "nameplate90"); units.nameplate90 = nil
  login(savedChar); units.player, myAuras, IsPlayerSpell = savedPlayer, savedAuras, savedSpell
end
print("=== Two players, one first name: each keyed by the whole name (#33)")
do
  NOW=NOW+60; units.player={"Yann","PRIEST",40}; IsPlayerSpell=function(id) return id==1243 end
  units.nameplate71={"Raide Boule","WARRIOR",40}; units.nameplate72={"Raide Tartempion","WARRIOR",40}
  fire("NAME_PLATE_UNIT_ADDED","nameplate71"); fire("NAME_PLATE_UNIT_ADDED","nameplate72"); runTimers()
  BuffDiggerDB.give=true; ns.applyWindows()
  local function listed(u) for _,e in ipairs(_G.BuffDiggerGive.entries) do if e.unit==u then return true end end end
  ns.refreshWindow(); assert(listed("nameplate71") and listed("nameplate72"), "both listed")
  -- The spell target arrives as "Raide Boule" (seen in game): only Boule is skipped.
  fire("UNIT_SPELLCAST_SENT","player","Raide Boule","guid",1243); ns.refreshWindow()
  assert(not listed("nameplate71"), "Boule just buffed: skipped")
  assert(listed("nameplate72"), "Tartempion not blocked by Boule")
  -- A click on a Give buffs icon (castOn) on Tartempion does not hide Boule.
  NOW=NOW+60; ns.castOn("nameplate72"); ns.refreshWindow()
  assert(listed("nameplate71") and not listed("nameplate72"), "castOn skips Tartempion only")
  BuffDiggerDB.give=false; ns.applyWindows(); NOW=NOW+60
  fire("NAME_PLATE_UNIT_REMOVED","nameplate71"); fire("NAME_PLATE_UNIT_REMOVED","nameplate72"); units.nameplate71=nil; units.nameplate72=nil
end
print("=== #35 /bd perf, refreshes skipped when nothing shows")
do
  local realTime, rq = time, _G.BuffDiggerRequests
  BuffDiggerDB.requests=false; BuffDiggerDB.give=false; BuffDiggerDB.nearby=false; ns.applyWindows(); BOUND=nil
  time=function() return realTime()+1000 end; ns.refreshIncoming(); time=realTime -- every request expired
  local realNearby, scans = ns.nearbyUnits, 0
  ns.nearbyUnits=function(...) scans=scans+1; return realNearby(...) end
  ns.refreshIncoming(); assert(scans==0, "no request, Requests closed: no nameplate scan")
  units.player={"Yann","PRIEST",40}; IsPlayerSpell=function(id) return id==1243 end; BuffDiggerDB.acceptRequests=true
  fire("CHAT_MSG_ADDON","BuffDigger","REQ:fortitude:new","WHISPER","Perfo-Realm"); assert(scans>0, "a request: scanned")
  ns.toggleRequests(); local seen
  for _,r in ipairs(rq.rows) do seen = seen or (r._shown and r.entry.request.name=="Perfo") end
  assert(seen, "Requests reopened: the request that came while it was closed is there"); ns.toggleRequests()
  ns.nearbyUnits=realNearby
  BOUND="F5"; ns.refreshWindow(); assert(_G.BuffDiggerGiveNext:GetAttribute("type")=="macro", "key bound, windows closed: still aimed"); BOUND=nil
  local out, realPrint = {}, print
  print=function(...) out[#out+1]=table.concat({...}," ") end
  BuffDiggerDB.debug=false; SlashCmdList.BUFFDIGGER("perf"); BuffDiggerDB.debug=true; SlashCmdList.BUFFDIGGER("perf")
  BuffDiggerDB.debug=false; print=realPrint
  local all = table.concat(out,"\n"); print(all)
  assert(all:find("debug mode only") and all:find("refreshIncoming") and all:find("refreshWindow"), "/bd perf lists the refreshes")
end
print("PERF OK")
print("=== Several buffs from one player, one request (#39)")
do
  NOW=NOW+3600; units.player={"Yann","MAGE",40}; IsPlayerSpell=function() return false end
  BuffDiggerCharDB.asked={}; BuffDiggerDB.peers={}; BuffDiggerDB.language="en"
  BuffDiggerDB.prefs.MAGE=nil; ns.dismissThank(); myAuras={}; fire("UNIT_AURA","player")
  units.nameplate80={"Anduin","PRIEST",40}; fire("NAME_PLATE_UNIT_ADDED","nameplate80"); runTimers()
  local function whispers(from) local n=0; for i=from+1,#sent do if sent[i]:find("^WHISPER") then n=n+1 end end return n end
  local function last(prefix) for i=#sent,1,-1 do if sent[i]:find(prefix) then return sent[i] end end end
  -- Priest 40, mage with neither Fort nor Spirit: one whisper naming both, one REQ + one ADD.
  local both={"fortitude","spirit"}
  local b=#sent; ns.request("nameplate80", both)
  for i=b+1,#sent do print("#39 sent:", sent[i]) end
  assert(whispers(b)==1, "one whisper"); local w=last("^WHISPER")
  assert(w:find("Hspell:1243") and w:find("Hspell:14752") and w:find("|r and |c"), "both links, joined by 'and': "..w)
  assert(sent[b+1]=="ADDON>Anduin: REQ:fortitude:new" and sent[b+2]=="ADDON>Anduin: ADD:spirit:new", "REQ first, then ADD")
  local e=BuffDiggerCharDB.asked.Anduin; assert(e.key=="fortitude" and #e.keys==2 and e.keys[2]=="spirit")
  -- Anti-nagging buff by buff: both just asked, nothing goes out.
  b=#sent; ns.request("nameplate80", both); assert(#sent==b, "both asked a moment ago: nothing")
  -- Fort lands: a Thank line right away, Spirit still asked.
  myAuras[1]=aura(3901,"Mot de pouvoir : Robustesse",1243,"nameplate80"); fire("UNIT_AURA","player")
  assert(#ns.thanksWaiting()==1 and ns.askState("Anduin")=="thank" and not e.thanked, "one landed: Thank line")
  assert(ns.askedAgo("Anduin","spirit"), "Spirit still asked")
  -- Spirit lands too: the same line, both icons; one click thanks once.
  myAuras[2]=aura(3902,"spell14752",14752,"nameplate80"); fire("UNIT_AURA","player")
  local t=ns.thanksWaiting(); assert(#t==1 and #t[1].keys==2, "one Thank line for both")
  b=#sent; ns.thankBuffer("Anduin"); assert(whispers(b)==1 and e.thanked, "one thank-you for both")
  -- Only Spirit lands: still a Thank line; Fort stays asked and joins the line if it comes.
  NOW=NOW+3600; BuffDiggerCharDB.asked={}; myAuras={}; fire("UNIT_AURA","player"); ns.request("nameplate80", both)
  myAuras[1]=aura(3903,"spell14752",14752,"nameplate80"); fire("UNIT_AURA","player")
  assert(#ns.thanksWaiting()==1 and ns.askedAgo("Anduin","fortitude") and not BuffDiggerCharDB.asked.Anduin.thanked, "Fort still asked")
  ns.dismissThank()
  -- Get buffs (#40): a plain click asks for that buff alone; Ctrl+click ticks, the arrow sends.
  NOW=NOW+3600; BuffDiggerCharDB.asked={}; myAuras={}; fire("UNIT_AURA","player")
  BuffDiggerDB.nearby=true; ns.applyWindows(); ns.refreshWindow()
  local gw40=_G.BuffDiggerNearby
  local function row40(name) for _,r in ipairs(gw40.rows) do if r._shown and r.entry and r.entry.who==name then return r end end end
  local function icon40(r, key) for _,ic in ipairs(r.buffs) do if ic._shown and ic.key==key then return ic end end end
  local function click(b) for _,f in ipairs(b._hooks.PostClick) do f(b,"LeftButton",false) end end
  local r=row40("Anduin"); assert(r and not r.send._shown, "nothing ticked: no arrow")
  b=#sent; click(icon40(r,"fortitude"))
  assert(whispers(b)==1 and not last("^WHISPER"):find("14752") and sent[b+1]=="ADDON>Anduin: REQ:fortitude:new" and not sent[b+2]:find("ADD:"), "plain click: Fort alone")
  BuffDiggerCharDB.asked={}; ns.dismissThank(); ns.refreshWindow(); r=row40("Anduin")
  CTRL=true; b=#sent; click(icon40(r,"fortitude")); r=row40("Anduin"); click(icon40(r,"spirit")); CTRL=false; r=row40("Anduin")
  assert(#sent==b and not BuffDiggerCharDB.asked.Anduin, "Ctrl+click: nothing sent")
  assert(icon40(r,"fortitude").pick._shown and icon40(r,"spirit").pick._shown and r.send._shown, "both ticked, the arrow shows")
  r.send._OnClick(r.send); r=row40("Anduin")
  assert(whispers(b)==1 and last("^WHISPER"):find("|r and |c") and sent[b+1]=="ADDON>Anduin: REQ:fortitude:new" and sent[b+2]=="ADDON>Anduin: ADD:spirit:new", "the arrow: one request, both buffs")
  assert(#BuffDiggerCharDB.asked.Anduin.keys==2 and not r.send._shown and not icon40(r,"fortitude").pick._shown, "sent: ticks cleared")
  -- Both asked a moment ago: the arrow sends nothing and the ticks stay.
  CTRL=true; click(icon40(r,"fortitude")); r=row40("Anduin"); click(icon40(r,"spirit")); CTRL=false; r=row40("Anduin")
  b=#sent; r.send._OnClick(r.send); r=row40("Anduin"); assert(#sent==b and r.send._shown and icon40(r,"spirit").pick._shown, "refused: ticks kept")
  CTRL=true; click(icon40(r,"fortitude")); r=row40("Anduin"); click(icon40(r,"spirit")); CTRL=false; r=row40("Anduin")
  -- Ctrl+click again unticks.
  BuffDiggerCharDB.asked={}; ns.refreshWindow(); r=row40("Anduin")
  CTRL=true; click(icon40(r,"spirit")); r=row40("Anduin"); click(icon40(r,"spirit")); CTRL=false; r=row40("Anduin")
  assert(not r.send._shown and not icon40(r,"spirit").pick._shown, "ticked twice: unticked")
  -- A paladin: ticking a second blessing replaces the first.
  units.player={"Yann","WARRIOR",40}; units.nameplate81={"Tirion","PALADIN",40}; fire("NAME_PLATE_UNIT_ADDED","nameplate81"); runTimers(); ns.refreshWindow()
  r=row40("Tirion"); CTRL=true; click(icon40(r,"might")); r=row40("Tirion"); click(icon40(r,"kings")); CTRL=false; r=row40("Tirion")
  assert(icon40(r,"kings").pick._shown and not icon40(r,"might").pick._shown, "one blessing ticked")
  b=#sent; r.send._OnClick(r.send); assert(whispers(b)==1 and not last("^WHISPER"):find("|r and |c") and not last("^ADDON"):find("ADD:"), "one blessing asked")
  -- Ticks are forgotten once the player leaves the list.
  BuffDiggerCharDB.asked={}; ns.refreshWindow(); r=row40("Tirion"); CTRL=true; click(icon40(r,"might")); CTRL=false
  fire("NAME_PLATE_UNIT_REMOVED","nameplate81"); units.nameplate81=nil; runTimers(); ns.refreshWindow(); assert(not row40("Tirion"))
  units.nameplate81={"Tirion","PALADIN",40}; fire("NAME_PLATE_UNIT_ADDED","nameplate81"); runTimers(); ns.refreshWindow()
  assert(not row40("Tirion").send._shown, "back in sight: nothing ticked")
  -- The nameplate's icon: one click, one buff.
  units.player={"Yann","MAGE",40}; BuffDiggerCharDB.asked={}; ns.refreshWindow()
  b=#sent; ns.request("nameplate80"); assert(whispers(b)==1 and #BuffDiggerCharDB.asked.Anduin.keys==1, "no automatic extra buff")
  BuffDiggerDB.nearby=false; ns.applyWindows(); BuffDiggerCharDB.asked={}
  -- A custom phrase: its {spell} stands for every link.
  ns.setCustom("new","Buffs please: {spell}!"); BuffDiggerCharDB.asked={}; b=#sent; ns.request("nameplate80", both)
  assert(last("^WHISPER"):find("Buffs please: |c.-1243.- and |c.-14752.-!$"), last("^WHISPER")); ns.setCustom("new","")
  -- Every language: a multi line with %s once, and its own "and".
  for _,lang in ipairs(ns.LANGUAGES) do
    local m=ns.message("new",{"fortitude","spirit","shadow"},lang[1]); assert(m:find(ns.AND[lang[1]],1,true) and m:find(", |c"), m)
    print("#39", lang[1], (m:gsub("|c%x+|H.-|h",""):gsub("|h|r","")))
  end
  -- Between two Buff Digger users: the priest's Requests line shows both icons, cast one by one.
  units.player={"Yann","PRIEST",40}; IsPlayerSpell=function(id) return id==1243 or id==14752 end; BuffDiggerDB.acceptRequests=true
  units.nameplate82={"Kael","MAGE",40}; fire("NAME_PLATE_UNIT_ADDED","nameplate82"); runTimers()
  fire("CHAT_MSG_ADDON","BuffDigger","REQ:fortitude:new","WHISPER","Kael-Realm")
  fire("CHAT_MSG_ADDON","BuffDigger","ADD:spirit:new","WHISPER","Kael-Realm")
  BuffDiggerDB.requests=true; ns.applyWindows()
  local kr; for _,x in ipairs(_G.BuffDiggerRequests.entries) do if x.request and x.request.name=="Kael" then kr=x end end
  assert(kr and #kr.buffs==2 and kr.buffs[1].key=="fortitude" and kr.buffs[2].key=="spirit", "both icons")
  -- A refresh extra can't close by itself (they have it): a click on its icon, the second one, does.
  units.nameplate84={"Rhonin","MAGE",40}; fire("NAME_PLATE_UNIT_ADDED","nameplate84"); runTimers()
  fire("CHAT_MSG_ADDON","BuffDigger","REQ:fortitude:refresh","WHISPER","Rhonin-Realm")
  fire("CHAT_MSG_ADDON","BuffDigger","ADD:spirit:refresh","WHISPER","Rhonin-Realm"); ns.refreshIncoming()
  local function rhonin() for _,r in ipairs(_G.BuffDiggerRequests.rows) do if r._shown and r.entry.request and r.entry.request.name=="Rhonin" then return r end end end
  click(rhonin().buffs[2], false); ns.refreshIncoming(); assert(#rhonin().entry.buffs==1 and rhonin().entry.buffs[1].key=="fortitude", "second icon: Spirit closed")
  click(rhonin().buffs[1], false); ns.refreshIncoming(); assert(not rhonin(), "both clicked: request gone")
  fire("NAME_PLATE_UNIT_REMOVED","nameplate84"); units.nameplate84=nil
  -- An older Buff Digger reads only REQ:<key>:<kind> (its pattern): it still gets Fort, ignores ADD.
  assert(("ADD:spirit:new"):match("^REQ:(%a+):(%a+)$")==nil and ("REQ:fortitude:new"):match("^REQ:(%a+):(%a+)$")=="fortitude")
  -- First buff unknown to me (no Fort): the ADD alone is the request.
  IsPlayerSpell=function(id) return id==14752 end; NOW=NOW+60
  units.nameplate83={"Ilya","MAGE",40}; fire("NAME_PLATE_UNIT_ADDED","nameplate83"); runTimers()
  fire("CHAT_MSG_ADDON","BuffDigger","REQ:fortitude:new","WHISPER","Ilya-Realm")
  fire("CHAT_MSG_ADDON","BuffDigger","ADD:spirit:new","WHISPER","Ilya-Realm"); ns.refreshIncoming()
  local ir; for _,x in ipairs(_G.BuffDiggerRequests.entries) do if x.request and x.request.name=="Ilya" then ir=x end end
  assert(ir and #ir.buffs==1 and ir.buffs[1].key=="spirit", "ADD alone: Spirit asked")
  BuffDiggerDB.requests=false; ns.applyWindows()
  for _,u in ipairs({"nameplate80","nameplate81","nameplate82","nameplate83"}) do fire("NAME_PLATE_UNIT_REMOVED",u); units[u]=nil end
  units.player={"Yann","WARRIOR",21}; IsPlayerSpell=function() return false end; myAuras={}; fire("UNIT_AURA","player"); BuffDiggerCharDB.asked={}
end
print("=== Sort the lists (#42)")
do
  for u in pairs(units) do if u~="player" then fire("NAME_PLATE_UNIT_REMOVED",u); units[u]=nil end end
  BuffDiggerCharDB.asked={}; ns.dismissThank(); myAuras={}; fire("UNIT_AURA","player"); BuffDiggerDB.nearbyUseful=false
  local function add(u, who) units[u]=who; fire("NAME_PLATE_UNIT_ADDED",u) end
  -- Get buffs, a warrior: a member (Group), four players around with known kinds of request.
  units.player={"Yann","WARRIOR",40}
  IsInGroup=function() return true end; IsInRaid=function() return false end; GetNumSubgroupMembers=function() return 1 end
  units.party1={"Eve Ent","PRIEST",10}
  add("nameplate91",{"Ali Zed","PALADIN",50}); add("nameplate92",{"Bob Brun","PRIEST",30})
  add("nameplate93",{"Cid Cole","DRUID",40}); add("nameplate94",{"Dan Dorn","MAGE",20}); runTimers()
  local realBest=ns.bestBuff
  local KINDS={["Ali Zed"]={"might","refresh",false}, ["Cid Cole"]={"wild","new",true}, ["Dan Dorn"]={"intellect","upgrade",false}}
  ns.bestBuff=function(name) local k=KINDS[name]; if k then return k[1], k[2], k[3] end end
  -- Ali's spells don't reach me: in sight, not in spell range.
  C_Spell.IsSpellInRange=function(_, u) return u~="nameplate91" end
  local w=_G.BuffDiggerNearby; BuffDiggerDB.nearby=true; ns.applyWindows()
  local function order(win)
    local t={}; for _,e in ipairs(win.entries) do t[#t+1]=e.header and "|" or e.who:match("^%S+") end
    return table.concat(t," ")
  end
  local o=order(w); print("best:", o)
  assert(BuffDiggerDB.sort.nearby==nil, "Best by default")
  assert(o:find("^| Eve | Cid ") and o:find(" Bob$"), "Best: unchanged order "..o)
  -- No MenuUtil: each click moves to the next criterion, kept in BuffDiggerDB.
  local expect={
    {"level","| Eve | Ali Cid Bob Dan"},      -- highest first: who gives the highest ranks
    {"range","| Eve | %a+ %a+ %a+ Ali"},            -- in spell range, then in sight
    {"missing","| Eve | Cid Ali Dan Bob"},    -- new, refresh, upgrade, nothing
    {"name","| Eve | Ali Bob Cid Dan"},
    {"class","| Eve | Cid Dan Ali Bob"},      -- DRUID, MAGE, PALADIN, PRIEST
  }
  for _,x in ipairs(expect) do
    w.sortBar._OnClick(w.sortBar); o=order(w); print(x[1]..":", o)
    assert(BuffDiggerDB.sort.nearby==x[1] and o:find("^"..x[2]:gsub("|","%%|").."$"), x[1]..": "..o)
  end
  w.sortBar._OnClick(w.sortBar); assert(BuffDiggerDB.sort.nearby==nil and order(w):find("^| Eve | Cid "), "back to Best")
  -- The game's menu: one radio per criterion, the current one checked; a pick re-sorts.
  local radios; MenuUtil={CreateContextMenu=function(owner, gen) radios={}
    gen(owner, {CreateTitle=function() end, CreateRadio=function(_,label,isSel,set) radios[#radios+1]={label=label,isSel=isSel,set=set} end}) end}
  w.sortBar._OnClick(w.sortBar); assert(#radios==6 and radios[1].isSel() and radios[5].label=="Name", "six radios, Best checked")
  radios[5].set(); assert(BuffDiggerDB.sort.nearby=="name" and order(w)=="| Eve | Ali Bob Cid Dan")
  w.sortBar._OnClick(w.sortBar); assert(radios[5].isSel() and not radios[1].isSel(), "Name checked now")
  MenuUtil=nil
  -- Under the cursor the list doesn't move: a line I just asked stays where I clicked it.
  w.IsMouseOver=function() return true end
  BuffDiggerCharDB.asked["Cid Cole"]={at=time(), key="wild", channel="WHISPER", target="Cid-Cole"}
  ns.refreshWindow(); assert(order(w)=="| Eve | Ali Bob Cid Dan", "hovered: no move "..order(w))
  w.IsMouseOver=nil; BuffDiggerCharDB.asked={}
  -- Asked (amber) and to thank (gold) stay first of their section, whatever the order.
  BuffDiggerCharDB.asked["Dan Dorn"]={at=time(), key="intellect", channel="WHISPER", target="Dan-Dorn"}
  ns.refreshWindow(); o=order(w); assert(o=="| Eve | Dan Ali Bob Cid", "asked first: "..o)
  BuffDiggerDB.sort.nearby="level"; ns.refreshWindow(); o=order(w); assert(o=="| Eve | Dan Ali Cid Bob", "asked first: "..o)
  -- Gold line out of sight: no unit, still first of Around, still sorted without error.
  myAuras[1]={auraInstanceID=4201,name="Bénédiction de puissance",spellId=19740,sourceUnit="nameplate91",expirationTime=NOW+600,duration=600}
  BuffDiggerCharDB.asked["Ali Zed"]={at=time(), key="might", channel="WHISPER", target="Ali-Zed"}
  fire("UNIT_AURA","player"); assert(ns.askState("Ali Zed")=="thank")
  fire("NAME_PLATE_UNIT_REMOVED","nameplate91"); units.nameplate91=nil; runTimers()
  for _,s in ipairs({"best","level","range","missing","name","class"}) do
    BuffDiggerDB.sort.nearby=s; ns.refreshWindow(); o=order(w)
    assert(o:find("^| Eve | [AD]%a+ [AD]%a+ "), s..": asked and gold first: "..o)
  end
  -- Kept across a /reload: the saved choice is what the bar shows.
  BuffDiggerDB.sort.nearby="class"; ns.refreshWindow()
  ns.dismissThank(); BuffDiggerCharDB.asked={}; BuffDiggerDB.nearby=false; ns.applyWindows(); ns.bestBuff=realBest
  myAuras={}; fire("UNIT_AURA","player")
  for u in pairs(units) do if u~="player" then fire("NAME_PLATE_UNIT_REMOVED",u); units[u]=nil end end
  IsInGroup=nil

  -- Give buffs, a priest with Fort and Spirit. Their auras: Fort fading on Ali and Dan, Spirit on
  -- Eve with its time secret; Bob and Cid lack everything; Cid is out of range.
  units.player={"Yann","PRIEST",40}; IsPlayerSpell=function(id) return id==1243 or id==14752 end
  add("nameplate95",{"Ali Zed","WARRIOR",50}); add("nameplate96",{"Bob Brun","MAGE",20}); add("nameplate97",{"Cid Cole","ROGUE",30})
  add("nameplate98",{"Dan Dorn","WARLOCK",40}); add("nameplate99",{"Eve Ent","PRIEST",10}); runTimers()
  local FORT, SPIRIT = "Mot de pouvoir : Robustesse", "spell14752"
  local AURAS={nameplate95={[FORT]={expirationTime=NOW+600}}, nameplate98={[FORT]={expirationTime=NOW+100}},
    nameplate99={[SPIRIT]={expirationTime=SECRET}}}
  local realAura=C_UnitAuras.GetAuraDataBySpellName
  C_UnitAuras.GetAuraDataBySpellName=function(u, name) return AURAS[u] and AURAS[u][name] end
  C_Spell.IsSpellInRange=function(_, u) return u~="nameplate97" end
  local g=_G.BuffDiggerGive; BuffDiggerDB.give=true; ns.applyWindows(); ns.refreshWindow()
  o=order(g); print("give best:", o); local nextUnit=_G.BuffDiggerGiveNext.unit; assert(o:find(" Cid$") and #g.entries==5, "Best: in range, then too far "..o)
  local gexpect={
    {"level","Eve Bob Cid Dan Ali"},     -- lowest first: who needs it most
    {"range","%a+ %a+ %a+ %a+ Cid"},
    {"missing","Bob Cid Dan Ali Eve"},   -- lacking all, then the soonest gone; secret time last
    {"name","Ali Bob Cid Dan Eve"},
    {"class","Bob Eve Cid Dan Ali"},     -- MAGE, PRIEST, ROGUE, WARLOCK, WARRIOR
  }
  for _,x in ipairs(gexpect) do
    g.sortBar._OnClick(g.sortBar); o=order(g); print("give "..x[1]..":", o)
    assert(BuffDiggerDB.sort.give==x[1] and o:find("^"..x[2].."$"), "give "..x[1]..": "..o)
  end
  assert(BuffDiggerDB.sort.nearby=="class", "each window keeps its own order")
  assert(nextUnit and _G.BuffDiggerGiveNext.unit==nextUnit, "the next-player key keeps the Best order")
  -- Combat: someone's auras turn secret (left out, as before); a click on the bar is harmless.
  AURAS.nameplate95=nil; C_UnitAuras.GetAuraDataBySpellName=function(u, name) if u=="nameplate95" then return SECRET end return AURAS[u] and AURAS[u][name] end
  BuffDiggerDB.sort.give="missing"; ns.refreshWindow(); o=order(g); assert(o=="Bob Cid Dan Eve", "secret auras: no error "..o)
  InCombatLockdown=function() return true end; g.sortBar._OnClick(g.sortBar); InCombatLockdown=function() return false end
  assert(BuffDiggerDB.sort.give=="name"); ns.refreshWindow(); assert(order(g)=="Bob Cid Dan Eve")
  BuffDiggerDB.give=false; ns.applyWindows(); C_UnitAuras.GetAuraDataBySpellName=realAura; C_Spell.IsSpellInRange=nil
  for u in pairs(units) do if u~="player" then fire("NAME_PLATE_UNIT_REMOVED",u); units[u]=nil end end
  units.player={"Yann","WARRIOR",21}; IsPlayerSpell=function() return false end
end
print("SMOKE OK")
print("=== buffKeyOf: spell names not loaded yet (#34)")
do -- A fresh Buff Digger whose first name lookups come back nil: the buff is known once names arrive.
  local ns34, real, ready, keep = {}, C_Spell.GetSpellName, false, BuffDigger
  C_Spell.GetSpellName = function(id) if ready then return real(id) end end
  for _,f in ipairs{"Locales","Data","BuffDigger"} do assert(setfenv(loadfile(DIR..f..".lua"), addonEnv))("BuffDigger", ns34) end
  ns34.isPeer = function() return false end -- no Comm.lua here; its frames still get the later events
  -- Fort already on me at login, read before its name loads: known once the name is there.
  for i=#myAuras,1,-1 do myAuras[i]=nil end; myAuras[1]=aura(3401,"Mot de pouvoir : Robustesse",1243)
  fire("UNIT_AURA","player")
  assert(ns34.buffKeyOf("Mot de pouvoir : Robustesse")==nil and not ns34.haveBuff("fortitude"), "no names yet")
  ready = true
  assert(ns34.buffKeyOf("Mot de pouvoir : Robustesse")=="fortitude", "names arrived: Fort known without /reload")
  fire("UNIT_AURA","player"); assert(ns34.haveBuff("fortitude"), "the Fort read too early is mine now")
  C_Spell.GetSpellName = real
  BuffDigger = keep -- the key bindings stay the first Buff Digger's
end
print("BUFFKEYOF OK")
print("=== window style (#44)")
do -- Minimal hides the frame art and shows the flat background; Classic the reverse, on every window.
  local w, t = _G.BuffDiggerNearby, _G.BuffDiggerGive
  local art = CreateFrame("Frame"); w.chrome[1] = art
  BuffDiggerDB.windowStyle = "minimal"; ns.applyStyle()
  assert(w.flat._shown and t.flat._shown and art._shown == false, "minimal: flat background, no frame art")
  BuffDiggerDB.windowStyle = "classic"; ns.applyStyle()
  assert(w.flat._shown == false and t.flat._shown == false and art._shown, "classic: Blizzard's frame back")
  w.chrome[1] = nil
end
print("STYLE OK")
print("=== other faction (#45)")
do -- A Horde paladin around an Alliance player: no icon, no line, no tooltip offer; back to Alliance, he is.
  reset(); fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
  local function listed() for _, u in ipairs(ns.nearbyUnits()) do if u == "nameplate1" then return true end end return false end
  assert(listed(), "Alliance paladin listed")
  FACTION.nameplate1 = "Horde"
  assert(not listed() and not ns.onMySide("nameplate1"), "Horde paladin: not listed")
  FACTION.nameplate1 = SECRET
  assert(listed(), "faction unreadable: kept")
  FACTION.nameplate1 = nil
end
print("FACTION OK")
print("=== gifts (#43)")
do -- A buff I didn't ask for, from a known giver, seen landing: a Thank line, by whisper.
  BuffDiggerDB.thankGifts=true; BuffDiggerCharDB.asked={}; ns.dismissThank(); InCombatLockdown=function() return false end
  myAuras={}; fire("UNIT_AURA","player")
  local function waiting(n) for _,x in ipairs(ns.thanksWaiting()) do if x.name==n then return x end end end
  units.nameplate60={"Elune","DRUID",40}
  local mark=aura(9601,"spell1126",1126,"nameplate60"); myAuras[#myAuras+1]=mark; fire("UNIT_AURA","player")
  local g=waiting("Elune"); assert(g and g.request.gift and g.keys[1]=="wild", "gift: a line")
  local b=#sent; ns.thankBuffer("Elune"); assert(sent[b+1]:find("^WHISPER Elune") and sent[b+2]=="EMOTE THANK Elune", "thanked by whisper")
  -- His recast (same aura, later end), then his Thorns within a minute: no new line.
  mark.expirationTime=NOW+1200; fire("UNIT_AURA","player"); assert(not waiting("Elune"), "his recast: no line")
  myAuras[#myAuras+1]=aura(9602,"spell467",467,"nameplate60"); fire("UNIT_AURA","player"); assert(not waiting("Elune"), "thanked a minute ago: no line")
  -- My request stays the line's request when a gift from the same player follows it.
  units.nameplate61={"Hamuul2","DRUID",40}; BuffDiggerCharDB.asked={Hamuul2={at=time(), key="thorns", channel="SAY", target="Hamuul2"}}
  myAuras[#myAuras+1]=aura(9603,"spell467",467,"nameplate61"); fire("UNIT_AURA","player")
  myAuras[#myAuras+1]=aura(9604,"spell1126",1126,"nameplate61"); fire("UNIT_AURA","player")
  g=waiting("Hamuul2"); assert(g and not g.request.gift and #g.keys==2, "asked then gift: one line, my request")
  b=#sent; ns.thankBuffer("Hamuul2"); assert(sent[b+1]:find("^SAY") and BuffDiggerCharDB.asked.Hamuul2.thanked, "thanked in my request's channel")
  -- Option off: nothing.
  BuffDiggerDB.thankGifts=false; units.nameplate62={"Cenarius2","DRUID",40}
  myAuras[#myAuras+1]=aura(9605,"spell1126",1126,"nameplate62"); fire("UNIT_AURA","player"); assert(not waiting("Cenarius2"), "option off: no gift line")
  BuffDiggerDB.thankGifts=true; ns.dismissThank()
  -- No stray gift (#43, the reason #37 dropped them): a buff landed mid-fight, a full update, the same auras under new IDs.
  units.nameplate63={"Tyrande2","DRUID",40}; units.nameplate64={"Velen2","PRIEST",40}
  InCombatLockdown=function() return true end; fire("PLAYER_REGEN_DISABLED")
  myAuras[#myAuras+1]=aura(9610,"spell1126",1126,"nameplate63"); fire("UNIT_AURA","player",SECRET)
  InCombatLockdown=function() return false end; fire("PLAYER_REGEN_ENABLED"); runTimers(); fire("UNIT_AURA","player"); runTimers()
  assert(#ns.thanksWaiting()==0, "landed mid-fight: no gift line after it")
  myAuras[#myAuras+1]=aura(9611,"Mot de pouvoir : Robustesse",1243,"nameplate64"); fire("UNIT_AURA","player",{isFullUpdate=true}); runTimers()
  assert(#ns.thanksWaiting()==0, "full update: no gift line")
  for i,a in ipairs(myAuras) do local c={}; for k,v in pairs(a) do c[k]=v end; c.auraInstanceID=a.auraInstanceID+1000; myAuras[i]=c end
  fire("UNIT_AURA","player"); runTimers(); assert(#ns.thanksWaiting()==0, "same auras, new IDs (Ghost Wolf, zoning): no gift line")
  -- A group member's buff is no gift (rebuffs in a dungeon would flood); seen by his nameplate, the name
  -- decides (UnitIsUnit(nameplate, party) fails in Forever). My request to a member keeps its line.
  units.party1={"Malfurion2","DRUID",40}; units.nameplate70={"Malfurion2","DRUID",40}
  IsInGroup=function() return true end; IsInRaid=function() return false end; GetNumSubgroupMembers=function() return 1 end
  myAuras={}; fire("UNIT_AURA","player")
  myAuras[#myAuras+1]=aura(9630,"spell1126",1126,"nameplate70"); fire("UNIT_AURA","player"); assert(not waiting("Malfurion2"), "member's buff: no gift line")
  BuffDiggerCharDB.asked={Malfurion2={at=time(), key="thorns", channel="PARTY", target="Malfurion2"}}
  myAuras[#myAuras+1]=aura(9631,"spell467",467,"party1"); fire("UNIT_AURA","player"); assert(waiting("Malfurion2"), "member, asked: a line")
  IsInGroup=nil; IsInRaid=nil; GetNumSubgroupMembers=nil; units.party1=nil; units.nameplate70=nil; BuffDiggerCharDB.asked={}; ns.dismissThank()
  -- The Thank key thanks my honoured request first, then the newest gift (a request is owed, a gift is a bonus).
  myAuras={}; fire("UNIT_AURA","player")
  units.nameplate71={"Giver7","DRUID",40}; units.nameplate72={"Asked7","DRUID",40}; units.nameplate73={"Giver8","PRIEST",40}
  myAuras[#myAuras+1]=aura(9640,"spell1126",1126,"nameplate71"); fire("UNIT_AURA","player")
  BuffDiggerCharDB.asked={Asked7={at=time(), key="thorns", channel="WHISPER", target="Asked7"}}
  myAuras[#myAuras+1]=aura(9641,"spell467",467,"nameplate72"); fire("UNIT_AURA","player")
  myAuras[#myAuras+1]=aura(9642,"Mot de pouvoir : Robustesse",1243,"nameplate73"); fire("UNIT_AURA","player")
  assert(#ns.thanksWaiting()==3 and ns.thanksWaiting()[1].name=="Giver8", "three lines, newest gift on top")
  -- Get buffs: one gold band for both; a gift shows the buff it brought instead of the tick (#43).
  local nw=_G.BuffDiggerNearby; BuffDiggerDB.nearby=true; ns.applyWindows(); nw.fill()
  local rg, ra; for _,r in ipairs(nw.rows) do if r.entry and r.entry.who=="Giver8" then rg=r elseif r.entry and r.entry.who=="Asked7" then ra=r end end
  assert(rg and rg.state=="thank" and rg.gift and rg.thank._shown, "gift: gold line, Thank, the buff's icon")
  assert(ra and ra.state=="thank" and not ra.gift, "my request: the tick")
  BuffDigger.thankLast(); assert(not waiting("Asked7") and waiting("Giver8"), "key: my request first")
  BuffDigger.thankLast(); assert(not waiting("Giver8") and waiting("Giver7"), "then the newest gift")
  BuffDiggerCharDB.asked={}; ns.dismissThank()
  -- Full list: gifts go before my request.
  units.nameplate65={"Remulos2","DRUID",40}; BuffDiggerCharDB.asked={Remulos2={at=time(), key="thorns", channel="WHISPER", target="Remulos2"}}
  myAuras[#myAuras+1]=aura(9620,"spell467",467,"nameplate65"); fire("UNIT_AURA","player")
  for i=1,5 do units["nameplate"..(65+i)]={"Giver"..i,"DRUID",40}; myAuras[#myAuras+1]=aura(9620+i,"spell1126",1126,"nameplate"..(65+i)); myAuras[#myAuras].expirationTime=NOW+600+10*i; fire("UNIT_AURA","player") end
  assert(#ns.thanksWaiting()==5 and waiting("Remulos2"), "full: my request stays, the oldest gift goes")
  ns.dismissThank()
end
print("GIFTS OK")
print("=== tone (#49)")
do
  -- The request a player sends uses the Tone setting; my own phrases (#20) still come first.
  units.player={"Yann","MAGE",40}; units.nameplate90={"Velen","PRIEST",40}; fire("NAME_PLATE_UNIT_ADDED","nameplate90")
  SHIFT=false; BuffDiggerDB.useSay=false; BuffDiggerDB.language="en"; myAuras={}; fire("UNIT_AURA","player")
  local function ask(tone) BuffDiggerDB.tone=tone; BuffDiggerCharDB.asked={}; local b=#sent
    ns.request("nameplate90","fortitude"); assert(#sent>b, "sent"); return sent[#sent] end
  for i=1,6 do assert(madeFrom(ask("polite"), ns.MESSAGES.en.polite), "request in Polite") end
  for i=1,6 do assert(madeFrom(ask(nil), ns.MESSAGES.en.casual), "no tone: Casual") end
  -- Every language has its own Polite; outside English and French, Role play is Polite.
  for _,lang in ipairs(ns.LANGUAGES) do local M, T = ns.MESSAGES[lang[1]], ns.THANKS[lang[1]]
    assert(M.polite~=M.casual and T.polite~=T.casual, lang[1].." needs its own Polite") end
  BuffDiggerDB.language="de"; for i=1,6 do assert(madeFrom(ask("roleplay"), ns.MESSAGES.de.polite), "de Role play: Polite") end
  BuffDiggerDB.language="en"
  -- Role play is its own (en, fr), with a touch of the giver's class where a bag exists for it.
  for _,lang in ipairs({"en","fr"}) do local M=ns.MESSAGES[lang]
    assert(M.roleplay~=M.polite and ns.THANKS[lang].roleplay~=ns.THANKS[lang].polite, lang.." Role play")
    assert(M.roleplay.byClass.PRIEST.new, lang.." a priest's bag") end
  for i=1,6 do local m=ask("roleplay"); assert(madeFrom(m, {x=ns.MESSAGES.en.roleplay.byClass.PRIEST.new}), "priest: his bag "..m)
    assert(not madeFrom(m, ns.MESSAGES.en.polite), "true Role play") end
  for i=1,6 do assert(madeFrom(ns.message("new","might","en","roleplay","WARRIOR"), {x=ns.MESSAGES.en.roleplay.new}), "no bag: neutral") end
  for i=1,6 do assert(madeFrom(ns.message("upgrade","might","en","roleplay","PRIEST"), {x=ns.MESSAGES.en.roleplay.upgrade}), "no such part: neutral") end
  ns.setCustom("new","Mine: {spell}"); assert(ask("polite"):find("Mine: |c"), "my phrases first"); ns.setCustom("new","")
  BuffDiggerDB.tone="casual"; BuffDiggerCharDB.asked={}
  -- #23: a request then a thank-you to the same player never end the same way ("Safe travels!" twice).
  local function endsWith(s, e) return e~="" and s:sub(-#e)==e end
  for _,lang in ipairs({"en","fr","de"}) do for _,tone in ipairs(ns.TONES) do for i=1,50 do
    local m, t = ns.message("new","might",lang,tone[1]), ns.thanks(lang,tone[1])
    for _,e in ipairs(ns.MESSAGES[lang][tone[1]].bye) do
      assert(not (endsWith(m,e) and endsWith(t,e)), lang.." same ending twice: "..e)
    end
  end end end
  -- The tone reaches the thank-you, "Start from Buff Digger's" and "Try one".
  BuffDiggerDB.tone="polite"; ns.dismissThank()
  BuffDiggerCharDB.asked={Velen={at=time(), key="fortitude", channel="WHISPER", target="Velen"}}
  myAuras={aura(9700,"Mot de pouvoir : Robustesse",1243,"nameplate90")}; fire("UNIT_AURA","player")
  local b=#sent; ns.thankBuffer("Velen"); local msg=sent[b+1]:match("^WHISPER Velen: (.*)")
  local polite; for _,s in ipairs(ns.THANKS.en.polite.thanks) do polite=polite or msg:sub(1,#s)==s end
  assert(polite, "thank-you in Polite: "..msg)
  local pw=_G.BuffDiggerPhrases; pw.tabs[1]._OnClick(pw.tabs[1]); pw.edit:SetText(""); pw.copy._OnClick(pw.copy)
  assert(pw.edit:GetText():find("^"..ns.MESSAGES.en.polite.new[1]:gsub("%%s","{spell}"):gsub("%p","%%%0").."\n"), "Start from: Polite")
  ns.setCustom("new", ""); pw.edit:SetText("")
  local said; local realSay=ns.say; ns.say=function(t) said=t end
  for i=1,10 do pw.preview._OnClick(pw.preview); assert(madeFrom(said, ns.MESSAGES.en.polite), "Try one: Polite "..said) end
  ns.say=realSay; BuffDiggerDB.tone="casual"; myAuras={}; fire("UNIT_AURA","player")
end
print("TONE OK")
