-- Buff Digger: what each buff is worth, and to whom.
--
-- Sources (2026-11-08):
--   * Ranks and training levels: WoW Forever trainer lists (conquestcapped.com, paladin/priest/mage/druid
--     abilities pages). Forever made Blessing of Kings a level 20 trainer spell, removed Salvation, Light and
--     Sanctuary, and made blessings last 1 hour.
--   * Spell IDs: rank 1 IDs confirmed present in Forever with /bd spells. The "group" IDs (Greater Blessing,
--     Prayer of..., Arcane Brilliance, Gift of the Wild) are vanilla IDs, not yet checked in Forever.
--   * Stat values per rank: vanilla values, not yet checked in Forever. Only used to say "higher rank".
--   * Preference order: common vanilla leveling knowledge (no official ranking exists). The "why" sits
--     next to each class; every order is a default the player will be able to change.
--
-- Rules of the game the decision tree relies on:
--   * The same buff never stacks: a higher rank from someone else replaces mine.
--   * A paladin keeps only ONE blessing per target: asking a paladin who already blessed me for another
--     blessing REPLACES his first one.
--   * A player may not have bought a rank at the trainer (Forever sells them): everything is "probably".

local _, ns = ...

ns.BUFFS = {
  might = {
    en = "Blessing of Might", id = 19740, group = { 25782 }, class = "PALADIN",
    ranks = { 4, 12, 22, 32, 42, 52, 60 },
    values = { 20, 35, 55, 85, 115, 155, 185 }, stat = "attack power",
  },
  wisdom = {
    en = "Blessing of Wisdom", id = 19742, group = { 25894 }, class = "PALADIN",
    ranks = { 14, 24, 34, 44, 54, 60 },
    values = { 10, 15, 20, 25, 30, 33 }, stat = "mana per 5 sec",
  },
  kings = {
    en = "Blessing of Kings", id = 20217, group = { 25898 }, class = "PALADIN",
    ranks = { 20 },
    values = { 10 }, stat = "% all stats",
  },
  intellect = {
    en = "Arcane Intellect", id = 1459, group = { 23028 }, class = "MAGE",
    ranks = { 1, 14, 28, 42, 56 },
    values = { 2, 7, 15, 22, 31 }, stat = "intellect",
  },
  fortitude = {
    en = "Power Word: Fortitude", id = 1243, group = { 21562 }, class = "PRIEST",
    ranks = { 1, 12, 24, 36, 48, 60 },
    values = { 3, 8, 20, 32, 43, 54 }, stat = "stamina",
  },
  spirit = {
    en = "Divine Spirit", id = 14752, group = { 27681 }, class = "PRIEST",
    ranks = { 30, 40, 50, 60 },
    values = { 17, 23, 33, 40 }, stat = "spirit",
  },
  shadow = {
    en = "Shadow Protection", id = 976, group = { 27683 }, class = "PRIEST",
    ranks = { 30, 42, 56 },
    values = { 30, 45, 60 }, stat = "shadow resistance",
  },
  wild = {
    en = "Mark of the Wild", id = 1126, group = { 21849 }, class = "DRUID",
    ranks = { 1, 10, 20, 30, 40, 50, 60 },
    values = { 25, 65, 105, 150, 195, 240, 285 }, stat = "armor (+ stats from rank 2)",
  },
  thorns = {
    en = "Thorns", id = 467, class = "DRUID",
    ranks = { 6, 14, 24, 34, 44, 54 },
    values = { 3, 6, 9, 12, 15, 18 }, stat = "damage to attackers",
  },
}

-- Order of preference for MY class, best first. A buff not listed is useless to that class.
-- Why, class by class (leveling, solo, out of combat):
ns.PREFERENCES = {
  -- Rage, no mana: Might feeds damage directly; Fortitude and Mark keep you alive between pulls;
  -- Kings is 10% of small stat totals while leveling, so below Might.
  WARRIOR = { "might", "fortitude", "kings", "wild", "thorns" },
  ROGUE   = { "might", "fortitude", "kings", "wild" },
  -- Might only raises MELEE attack power in vanilla, useless for a bow. Mana matters (Aspects, Serpent Sting).
  HUNTER  = { "kings", "fortitude", "wild", "wisdom", "intellect" },
  -- Casters: downtime is drinking. Wisdom and Intellect cut it; Spirit helps priests/mages regen.
  MAGE    = { "wisdom", "intellect", "fortitude", "kings", "wild", "spirit" },
  PRIEST  = { "wisdom", "intellect", "fortitude", "spirit", "kings", "wild" },
  -- Warlocks trade health for mana (Life Tap): Stamina first.
  WARLOCK = { "fortitude", "wisdom", "intellect", "kings", "wild", "spirit" },
  -- Hybrids leveling in melee (Retribution, Enhancement, Feral) but healing between pulls.
  PALADIN = { "might", "fortitude", "kings", "wisdom", "wild", "intellect" },
  SHAMAN  = { "might", "fortitude", "kings", "wisdom", "wild", "intellect" },
  DRUID   = { "might", "fortitude", "kings", "wisdom", "intellect", "wild" },
}

-- What other players read. The language is a setting (English by default), NOT the client's language:
-- a French client on an English-speaking realm must still write in English. In English the spell name
-- comes from `en` above (a French client only knows French names); in French it comes from the game.
-- Several phrasings per case, picked at random (never the same twice in a row) so asking around
-- does not read like a bot. %s is the spell link.
ns.MESSAGES = {
  fr = {
    -- The spell goes in brackets or after a colon: French needs ta/ton/tes depending on the spell.
    new = {
      "Salut ! Tu pourrais me buff stp ? (%s) Merci :)",
      "Hello ! Un petit buff en passant ? %s Merci d'avance !",
      "Coucou, je peux te gratter un buff ? (%s) Merci :D",
      "Salut ! Si t'as deux secondes : %s stp. Merci beaucoup !",
      "Yo ! Tu me ferais l'honneur d'un buff ? %s Merci !",
      "Bonjour ! Je ne dirais pas non à %s :) Merci !",
      "Salut, possible d'avoir %s stp ? Bonne aventure à toi !",
    },
    replace = {
      "Salut ! Tu pourrais changer ta bénédiction stp ? (%s plutôt) Merci :)",
      "Hello ! Merci pour la béné ! Tu pourrais me mettre %s à la place ? Ça m'aide plus :)",
      "Coucou, petite requête : tu pourrais échanger ta bénédiction contre %s ? Merci !",
      "Salut ! Ta béné est top, mais %s m'irait encore mieux, si ça te va :)",
    },
    upgrade = {
      "Salut ! Tu pourrais me rebuff stp ? (%s, le tien est d'un rang plus haut) Merci :)",
      "Hello ! Ton buff est plus costaud que le mien (%s), tu pourrais me le remettre ? Merci !",
      "Coucou ! Un buff de ton rang, ce serait le luxe : %s :) Merci !",
      "Salut, le mien est de rang bas : tu pourrais me remettre %s ? Merci d'avance !",
    },
  },
  en = {
    new = {
      "Hi! Could I get %s please? Thanks :)",
      "Hey there! Mind sparing me %s? Much appreciated!",
      "Hello! Any chance of %s? Thank you!",
      "Hi! Would you be so kind as to toss me %s? Thanks a lot!",
      "Hey! If you've got a sec, %s would be amazing. Thanks!",
      "Greetings, friend! %s for a weary traveler? Thanks :)",
      "Hi! I'd love %s if you don't mind. Have a good one!",
    },
    replace = {
      "Hi! Could you swap my blessing for %s please? Thanks :)",
      "Hey! Thanks for the blessing! Could you make it %s instead? It helps me more :)",
      "Hello! Small request: would you mind switching my blessing to %s? Thank you!",
      "Hi! Your blessing is great, but %s would suit me even better, if that's ok :)",
    },
    upgrade = {
      "Hi! Could I get your %s please? Yours is a higher rank. Thanks :)",
      "Hey! Your %s is stronger than mine, would you mind refreshing it? Thanks!",
      "Hello! Your rank of %s would be a real treat :) Thank you!",
      "Hi! Mine's a low rank, could I get your %s? Thanks in advance!",
    },
  },
}

local lastPick = {}

local function pick(list)
  local i = math.random(#list)
  if #list > 1 and list[i] == lastPick[list] then i = i % #list + 1 end
  lastPick[list] = list[i]
  return list[i]
end

-- The spell goes in as a clickable link: the reader gets the tooltip in their own language.
-- The link's visible text is the game's (French on a French client); in English we swap in the
-- English name. To check in game: the server could refuse a link whose text it did not write
-- (then the whisper never shows up as sent).
local function spellText(buff, french)
  local name = french and (C_Spell.GetSpellName(buff.id) or buff.en) or buff.en
  local link = C_Spell.GetSpellLink and C_Spell.GetSpellLink(buff.id)
  if not link then return name end
  return (link:gsub("%[.-%]", "[" .. name .. "]"))
end

function ns.message(kind, key, french)
  local texts = french and ns.MESSAGES.fr or ns.MESSAGES.en
  return pick(texts[kind]):format(spellText(ns.BUFFS[key], french))
end

-- Highest rank a player of this level can (probably) have; 0 if none yet.
function ns.rankAt(buff, level)
  local rank = 0
  for r, needed in ipairs(buff.ranks) do
    if level >= needed then rank = r end
  end
  return rank
end
