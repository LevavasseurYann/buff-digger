-- Fake WoW API: just enough to run Buff Digger end to end. Loads the addon; nothing is fired yet.
-- Used by tests/smoke.lua (scenarios) and tests/replay.lua (journals replayed), each in a fresh Lua.
-- Globals for the tests: sent, units, myAuras, ns, fire(event, ...), reset(), SECRET.
sent = {}; local events = {}
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
GetBuildInfo=function() return "1.60.1",1,"",16001 end; CVARS={nameplateShowFriendlyPlayers="0"}; GetCVar=function(k) return CVARS[k] end; SetCVar=function(k,v) CVARS[k]=v end
GetCursorPosition=function() return 0,0 end; IsPlayerSpell=function() return false end
DoEmote=function(e,n) sent[#sent+1]="EMOTE "..e.." "..n end
local NAMES={[19740]="Bénédiction de puissance",[20217]="Bénédiction des rois",[19742]="Bénédiction de sagesse",[1243]="Mot de pouvoir : Robustesse"}
SECRET={}; issecretvalue=function(v) return v==SECRET end
SHIFT=false; IsShiftKeyDown=function() return SHIFT end; IsControlKeyDown=function() return false end
C_Spell={GetSpellLink=function(id) return "|cff71d5ff|Hspell:"..id..":0|h["..(NAMES[id] or "x").."]|h|r" end, GetSpellName=function(id) return NAMES[id] or ("spell"..id) end, GetSpellTexture=function() return 1 end}
myAuras={} -- a function in it stands for a read that fails: it is called (it raises the error)
C_UnitAuras={GetAuraDataByIndex=function(u,i) if u=="player" then local a=myAuras[i]; if type(a)=="function" then return a() end; return a end end,
  GetAuraDataBySpellName=function() return nil end}
units={}
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
ns={}
-- The addon may only create its own globals: a forgotten `local` fails here instead of leaking.
local addonEnv = setmetatable({}, {__index=_G, __newindex=function(_,k,v)
  if not (k:match("^BuffDigger") or k:match("^SLASH_BUFFDIGGER") or k:match("^BINDING_")) then error("addon sets global "..k, 2) end
  _G[k]=v end})
-- Restrictions (Midnight): auras secret on a restricted map, the state of each restriction type.
-- The addon hears ADDON_RESTRICTION_STATE_CHANGED from fire(), like any event.
SECRET_AURAS=false; C_Secrets={ShouldAurasBeSecret=function() return SECRET_AURAS end}
RESTRICTION=0; C_RestrictedActions={GetAddOnRestrictionState=function() return RESTRICTION end}
-- Back to the start: the three players below, no aura, nothing sent, NOW=1000, no request open.
function reset()
  wipe(units); units.player={"Yann","WARRIOR",21}; units.nameplate1={"Arthas","PALADIN",25}; units.nameplate2={"Jaina","MAGE",30}
  myAuras={}; wipe(sent); NOW=1000; SECRET_AURAS=false; RESTRICTION=0
  if BuffDiggerDB then BuffDiggerDB.asked={} end
end
reset()
for _,f in ipairs{"Locales","Data","BuffDigger","UI","Comm"} do assert(setfenv(loadfile(DIR..f..".lua"), addonEnv))("BuffDigger", ns) end
function fire(ev,...) for _,f in ipairs(events) do if f._OnEvent then f._OnEvent(f,ev,...) end end end
