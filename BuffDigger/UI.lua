-- Buff Digger: minimap button, settings window, and two list windows.
-- Minimap button: left click = settings, right click = Nearby, Shift+right click = Give buffs,
-- drag = move around the minimap.
--   * Nearby (idea 4): who around can give me what; one click asks — easier than chasing the
--     nameplate of a player who keeps running.
--   * Give buffs (idea 5, buffer classes): who around lacks a buff I can cast, chosen from THEIR
--     class preferences; one click casts it on them (secure button, out of combat only).
-- Both hide in combat and come back after it.

local _, ns = ...
local BUFFS, rankAt = ns.BUFFS, ns.rankAt
local MAX_ROWS = 10
local ROW_HEIGHT = 20

local function classColored(text, class)
  local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  return color and ("|c" .. color.colorStr .. text .. "|r") or text
end

-- ---------------------------------------------------------------- settings window

local SETTINGS = {
  { key = "icons",   label = "Icon next to players' health bar" },
  { key = "tooltip", label = "Line in players' tooltip" },
  { key = "nearby",  label = "Nearby window (who can buff me)" },
  { key = "give",    label = "Give buffs window (who lacks my buffs)" },
  { key = "thank",   label = "Automatic /thank when someone buffs me" },
  { key = "useSay",  label = "Ask in /say by default (not whisper)" },
  { key = "frenchMessages", label = "Messages to players in French" },
  { key = "debug",   label = "Debug messages in chat" },
}

local settings
local function buildSettings()
  settings = CreateFrame("Frame", "BuffDiggerSettings", UIParent, "BasicFrameTemplateWithInset")
  settings:SetSize(340, 70 + #SETTINGS * 26 + 56)
  settings:SetPoint("CENTER")
  settings:SetMovable(true)
  settings:EnableMouse(true)
  settings:RegisterForDrag("LeftButton")
  settings:SetScript("OnDragStart", settings.StartMoving)
  settings:SetScript("OnDragStop", settings.StopMovingOrSizing)
  settings:Hide()
  tinsert(UISpecialFrames, "BuffDiggerSettings") -- Escape closes it

  local title = settings:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", 0, -5)
  title:SetText("Buff Digger")

  for i, s in ipairs(SETTINGS) do
    local box = CreateFrame("CheckButton", nil, settings, "UICheckButtonTemplate")
    box:SetPoint("TOPLEFT", 14, -30 - (i - 1) * 26)
    local text = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", box, "RIGHT", 2, 0)
    text:SetText(s.label)
    box:SetScript("OnShow", function(self) self:SetChecked(BuffDiggerDB[s.key]) end)
    box:SetScript("OnClick", function(self)
      BuffDiggerDB[s.key] = self:GetChecked() and true or false
      ns.applyWindows()
      ns.refreshAll()
    end)
  end

  local hint = settings:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("BOTTOMLEFT", 16, 14)
  hint:SetPoint("BOTTOMRIGHT", -16, 14)
  hint:SetJustifyH("LEFT")
  hint:SetText("Shift/Ctrl-click an icon or a Nearby line: /say instead of whisper (or the reverse).\n"
    .. "Minimap: right click = Nearby, Shift+right click = Give buffs.\n"
    .. "Key Bindings > AddOns > Buff Digger: one key asks the best buff around you.\n"
    .. "Macros: /bd best, /bd ask (target). Friendly nameplates must be on.")
end

function ns.toggleSettings()
  if not settings then return end
  settings:SetShown(not settings:IsShown())
end

-- ---------------------------------------------------------------- minimap button

local function placeMinimapButton(button)
  local angle = math.rad(BuffDiggerDB.minimapAngle or 200)
  local radius = Minimap:GetWidth() / 2 + 8
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function buildMinimapButton()
  local button = CreateFrame("Button", "BuffDiggerMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local icon = button:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER")
  icon:SetTexture(C_Spell.GetSpellTexture(BUFFS.kings.id) or 134400)
  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  button:SetScript("OnClick", function(_, mouse)
    if mouse ~= "RightButton" then ns.toggleSettings()
    elseif IsShiftKeyDown() then ns.toggleGive()
    else ns.toggleWindow() end
  end)
  button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      BuffDiggerDB.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
      placeMinimapButton(self)
    end)
  end)
  button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  placeMinimapButton(button)
end

-- ---------------------------------------------------------------- list windows

-- A movable window holding up to MAX_ROWS lines; `secure` lines cast a spell on click.
-- `setting` is the BuffDiggerDB key that remembers whether it is open.
local function makeWindow(globalName, title, setting, secure, point)
  local w = CreateFrame("Frame", globalName, UIParent, "BasicFrameTemplateWithInset")
  w:SetSize(290, 60)
  w:SetPoint(unpack(point))
  w:SetMovable(true)
  w:EnableMouse(true)
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", w.StartMoving)
  w:SetScript("OnDragStop", w.StopMovingOrSizing)
  w:Hide()
  w.setting = setting
  -- The window's own close button turns the setting off too.
  w.CloseButton:HookScript("OnClick", function() BuffDiggerDB[setting] = false end)

  local header = w:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  header:SetPoint("TOP", 0, -5)
  header:SetText(title)
  w.empty = w:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  w.empty:SetPoint("TOPLEFT", 14, -32)
  w.empty:SetPoint("RIGHT", -14, 0)
  w.empty:SetJustifyH("LEFT")

  w.rows = {}
  for i = 1, MAX_ROWS do
    local row = CreateFrame("Button", nil, w, secure and "SecureActionButtonTemplate" or nil)
    row:SetSize(262, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 12, -28 - (i - 1) * ROW_HEIGHT)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", 2, 0)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.text:SetPoint("RIGHT", -2, 0)
    row.text:SetJustifyH("LEFT")
    if secure then
      row:RegisterForClicks("AnyUp", "AnyDown")
      row:SetAttribute("type", "spell")
    else
      row:SetScript("OnClick", function(self) ns.request(self.unit) end)
    end
    row:Hide()
    w.rows[i] = row
  end
  return w
end

-- entries: { { unit, icon, text, spell (secure windows only) }, ... }
local function fill(w, entries, emptyMessage)
  for i, row in ipairs(w.rows) do
    local e = entries[i]
    if e then
      row.unit = e.unit
      row.icon:SetTexture(e.icon)
      row.text:SetText(e.text)
      if e.spell then
        row:SetAttribute("unit", e.unit)
        row:SetAttribute("spell", e.spell)
      end
    end
    row:SetShown(e ~= nil)
  end
  local count = math.min(#entries, MAX_ROWS)
  w.empty:SetText(emptyMessage)
  w.empty:SetShown(count == 0)
  w:SetHeight(40 + math.max(count, 1) * ROW_HEIGHT)
end

local nearby, give

-- ---------------------------------------------------------------- Nearby (idea 4)

local function nearbyEntries()
  local entries = {}
  for _, unit in ipairs(ns.nearbyUnits()) do
    local name, class, level = ns.identity(unit)
    if name then
      local key, kind = ns.bestBuff(name, class, level)
      if key then
        local buff = BUFFS[key]
        local extra = kind == "replace" and " (swap)" or kind == "upgrade" and " (higher rank)" or ""
        entries[#entries + 1] = {
          unit = unit,
          icon = C_Spell.GetSpellTexture(buff.id),
          text = ("%s %d — %s r%d%s"):format(classColored(name, class), level,
            C_Spell.GetSpellName(buff.id), rankAt(buff, level), extra),
        }
      end
    end
  end
  return entries
end

-- ---------------------------------------------------------------- Give buffs (idea 5)

-- Does this unit have this buff (rank 1 or group version)? Second value: cast by me.
-- nil when the game keeps it secret.
local function unitHas(unit, buff)
  local ids = { buff.id }
  for _, id in ipairs(buff.group or {}) do ids[#ids + 1] = id end
  for _, id in ipairs(ids) do
    local name = C_Spell.GetSpellName(id)
    if name then
      local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, name, "HELPFUL")
      if not ok or not ns.readable(aura) then
        ns.record("others", false, ok and "aura secret" or tostring(aura))
        return nil
      end
      if aura then
        ns.record("others", true)
        return true, ns.readable(aura.sourceUnit) and aura.sourceUnit == "player"
      end
    end
  end
  ns.record("others", true)
  return false
end

local function myCastableBuffs()
  local _, myClass = UnitClass("player")
  local list = {}
  for key, buff in pairs(BUFFS) do
    if buff.class == myClass and IsPlayerSpell(buff.id) then list[#list + 1] = key end
  end
  return list
end

-- Which of my buffs should this player get? Their class preferences decide.
-- A paladin keeps one blessing per target: if mine is already on them, offer nothing.
local function buffToGive(unit, theirClass, myBuffs)
  local _, myClass = UnitClass("player")
  if myClass == "PALADIN" then
    for _, key in ipairs(myBuffs) do
      local _, fromMe = unitHas(unit, BUFFS[key])
      if fromMe then return end
    end
  end
  for _, key in ipairs(ns.prefsFor(theirClass)) do
    for _, mineKey in ipairs(myBuffs) do
      if key == mineKey then
        local has = unitHas(unit, BUFFS[key])
        if has == false then return key end
        if has == nil then return end -- unreadable: stay silent rather than guess
      end
    end
  end
end

local function giveEntries(myBuffs)
  local entries = {}
  for _, unit in ipairs(ns.nearbyUnits()) do
    local name, class, level = ns.identity(unit)
    local key = name and buffToGive(unit, class, myBuffs)
    if key then
      local spell = C_Spell.GetSpellName(BUFFS[key].id)
      entries[#entries + 1] = {
        unit = unit,
        icon = C_Spell.GetSpellTexture(BUFFS[key].id),
        text = ("%s %d — %s"):format(classColored(name, class), level, spell),
        spell = spell,
      }
    end
  end
  return entries
end

-- ---------------------------------------------------------------- refresh and visibility

function ns.refreshWindow()
  if InCombatLockdown() then return end -- secure rows cannot change in combat
  if nearby and nearby:IsShown() then
    fill(nearby, nearbyEntries(), "Nobody around can buff you better right now.\n(Friendly nameplates on?)")
  end
  if give and give:IsShown() then
    local myBuffs = myCastableBuffs()
    if #myBuffs == 0 then
      fill(give, {}, "You know no buff to give (paladin, priest, mage or druid).")
    else
      fill(give, giveEntries(myBuffs), "Everyone around has your buffs.\n(Friendly nameplates on?)")
    end
  end
end

-- Show each window according to its setting (out of combat only).
function ns.applyWindows()
  if InCombatLockdown() or not nearby then return end
  nearby:SetShown(BuffDiggerDB.nearby)
  give:SetShown(BuffDiggerDB.give)
  ns.refreshWindow()
end

function ns.toggleWindow()
  BuffDiggerDB.nearby = not BuffDiggerDB.nearby
  ns.applyWindows()
end

function ns.toggleGive()
  BuffDiggerDB.give = not BuffDiggerDB.give
  ns.applyWindows()
end

-- Hide on entering combat (still allowed during PLAYER_REGEN_DISABLED), back on leaving it.
function ns.onCombat(inCombat)
  if not nearby then return end
  if inCombat then
    nearby:Hide()
    give:Hide()
  else
    ns.applyWindows()
  end
end

function ns.buildUI()
  buildSettings()
  buildMinimapButton()
  nearby = makeWindow("BuffDiggerNearby", "Buff Digger — Nearby", "nearby", false, { "LEFT", 40, 60 })
  give = makeWindow("BuffDiggerGive", "Buff Digger — Give buffs", "give", true, { "LEFT", 40, -140 })
  ns.applyWindows()
end
