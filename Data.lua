-- Buff Digger: what each buff is worth, and to whom.
--
-- Sources (2026-11-08):
--   * Ranks and training levels: WoW Forever trainer lists (conquestcapped.com, paladin/priest/mage/druid
--     abilities pages). Forever made Blessing of Kings a level 20 trainer spell, removed Salvation, Light and
--     Sanctuary, and made blessings last 1 hour.
--   * Spell IDs: rank 1 IDs confirmed present in Forever with /bd spells. The "group" IDs (Greater Blessing,
--     Prayer of..., Arcane Brilliance, Gift of the Wild) are vanilla IDs, not yet checked in Forever.
--   * Stat values per rank: vanilla values, not yet checked in Forever. Only used to say "higher rank".
--     `talent`: the most a giver's "Improved ..." talent multiplies them by (vanilla talents: Improved
--     Fortitude +30%, Improved Thorns +75%, Improved Mark +35%, Improved Might/Wisdom +20%). Seen in
--     Forever (2026-11-08): Fortitude rank 2 = +10 and rank 3 = +26 (8 and 20 x 1.3), Thorns rank 2 = 7.
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
    values = { 20, 35, 55, 85, 115, 155, 185 }, stat = "attack power", talent = 1.2,
  },
  wisdom = {
    en = "Blessing of Wisdom", id = 19742, group = { 25894 }, class = "PALADIN",
    ranks = { 14, 24, 34, 44, 54, 60 },
    values = { 10, 15, 20, 25, 30, 33 }, stat = "mana per 5 sec", talent = 1.2,
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
    values = { 3, 8, 20, 32, 43, 54 }, stat = "stamina", talent = 1.3,
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
    values = { 25, 65, 105, 150, 195, 240, 285 }, stat = "armor (+ stats from rank 2)", talent = 1.35,
  },
  thorns = {
    en = "Thorns", id = 467, class = "DRUID",
    ranks = { 6, 14, 24, 34, 44, 54 },
    values = { 3, 6, 9, 12, 15, 18 }, stat = "damage to attackers", talent = 1.75,
  },
  -- A mage's water and food (#47): asked like a buff, never an aura (no values, no stat), so never
  -- "had": a request for one is always "new", and Buff Digger never picks one by itself.
  -- `spells`: each rank's own spell (the mage casts the rank the asker can use), `uses`: the level
  -- needed to eat or drink that rank (itemMinLevel, seen in game 2026-11-27, issue #47).
  water = {
    en = "Conjure Water", id = 5504, class = "MAGE", item = true,
    ranks = { 4, 10, 20, 30, 40, 50, 60 }, -- unverified (vanilla trainer levels)
    spells = { 5504, 5505, 5506, 6127, 10138, 10139, 10140 }, -- unverified (vanilla)
    uses = { 1, 5, 15, 25, 35, 45, 55 }, -- items 5350, 2288, 2136, 3772, 8077, 8078, 8079
  },
  food = {
    en = "Conjure Food", id = 587, class = "MAGE", item = true,
    ranks = { 6, 12, 22, 32, 42, 52, 60 }, -- unverified (vanilla trainer levels)
    spells = { 587, 597, 990, 6129, 10144, 10145, 28612 }, -- unverified (vanilla)
    uses = { 1, 5, 15, 25, 35, 45, 55 }, -- items 5349, 1113, 1114, 1487, 8075, 8076, 22895
  },
}

-- Order of preference for MY class, best first. A buff not listed is useless to that class.
-- Why, class by class (leveling, solo, out of combat):
ns.PREFERENCES = {
  -- Rage, no mana: Might feeds damage directly; Fortitude and Mark keep you alive between pulls;
  -- Kings is 10% of small stat totals while leveling, so below Might. Spirit last: faster health
  -- regen out of combat, a warrior's only downtime.
  -- Water (classes with mana) and food (all but the mage) come last (#47): only asked by a click.
  WARRIOR = { "might", "fortitude", "kings", "wild", "thorns", "spirit", "food" },
  ROGUE   = { "might", "fortitude", "kings", "wild", "food" },
  -- Might only raises MELEE attack power in vanilla, useless for a bow. Mana matters (Aspects, Serpent Sting).
  HUNTER  = { "kings", "fortitude", "wild", "wisdom", "intellect", "water", "food" },
  -- Casters: downtime is drinking. Wisdom and Intellect cut it; Spirit helps priests/mages regen.
  MAGE    = { "wisdom", "intellect", "fortitude", "kings", "wild", "spirit" },
  PRIEST  = { "wisdom", "intellect", "fortitude", "spirit", "kings", "wild", "water", "food" },
  -- Warlocks trade health for mana (Life Tap): Stamina first.
  WARLOCK = { "fortitude", "wisdom", "intellect", "kings", "wild", "spirit", "water", "food" },
  -- Hybrids leveling in melee (Retribution, Enhancement, Feral) but healing between pulls.
  PALADIN = { "might", "fortitude", "kings", "wisdom", "wild", "intellect", "water", "food" },
  SHAMAN  = { "might", "fortitude", "kings", "wisdom", "wild", "intellect", "water", "food" },
  DRUID   = { "might", "fortitude", "kings", "wisdom", "intellect", "wild", "water", "food" },
}

-- What other players read. The language is a setting (English by default), NOT the client's language:
-- a French client on an English-speaking realm must still write in English. The spell name comes from
-- the game when the client speaks the chosen language, from `en` above otherwise (a French client only
-- knows French names, and an English one cannot write German names).
--
-- A request is built from three parts: hello .. ask .. bye (hello ends with a space, bye starts with
-- one; "" means "none"). Each part is drawn from a shuffled bag: every line comes out once before any
-- comes back, so a dozen asks in a row never read like a bot. %s (only in the asks) is the spell link.
-- No "thanks" in a request: the thank-you comes with a Thank click once the buff lands (ns.THANKS).
-- Each language has one table per tone (#49), the Tone setting: casual, polite, roleplay. A missing
-- roleplay falls back on polite at the end of this list, so every tone answers.
ns.MESSAGES = {
  fr = {
    -- The spell goes in brackets or after a colon: French needs ta/ton/tes depending on the spell.
    -- Casual says tu, Polite says vous.
    casual = {
      hello = { "Salut ! ", "Hello ! ", "Coucou ! ", "Yo ! ", "Hey ! ", "Salut toi ! ", "" },
      bye = { "", "", " :)", " :D" },
      -- Several buffs from one player (#39): %s is every link, joined by ns.AND.
      multi = {
        "Tu pourrais me buff stp ? (%s)",
        "Si t'as deux secondes : %s stp.",
        "Possible d'avoir quelques buffs stp ? (%s)",
      },
      new = {
        "Tu pourrais me buff stp ? (%s)",
        "Un petit buff en passant ? %s",
        "Je peux te gratter un buff ? (%s)",
        "Si t'as deux secondes : %s stp.",
        "Possible d'avoir un buff stp ? (%s)",
        "Tu me lancerais un buff stp ? %s",
        "Ça te dit de me buff ? (%s)",
      },
      replace = {
        "Tu pourrais changer ma bénédiction stp ? (%s plutôt)",
        "Tu pourrais me mettre une autre béné ? (%s)",
        "Ta béné est top, mais celle-ci m'irait encore mieux : %s",
        "Possible de changer de béné ? Celle-ci m'aide plus : %s",
      },
      upgrade = {
        "Tu pourrais me rebuff stp ? (%s, le tien est d'un rang plus haut)",
        "Ton buff est plus costaud que le mien (%s), tu pourrais me le remettre ?",
        "Un buff de ton rang, ce serait le luxe : %s",
        "Le mien est de rang bas : tu pourrais me remettre le tien ? (%s)",
        "Ton rang est plus haut que le mien, un rebuff stp ? (%s)",
      },
      refresh = {
        "Mon buff s'arrête bientôt, tu pourrais me le remettre ? (%s)",
        "%s va tomber sur moi, un petit rebuff stp ?",
        "Plus que quelques minutes de buff, tu me le remets stp ? (%s)",
        "Mon buff est presque fini, un petit rebuff ? %s",
      },
      -- A mage's water and food (#47): %s is the spell link(s) and my level, "[Conjure Water] (niv. 23)".
      water = {
        "T'aurais un peu d'eau à me filer stp ? %s",
        "Tu pourrais m'invoquer de l'eau ? %s",
        "Je peux te gratter de l'eau ? %s",
      },
      food = {
        "T'aurais un peu de bouffe à me filer stp ? %s",
        "Tu pourrais m'invoquer à manger ? %s",
        "Je peux te gratter à manger ? %s",
      },
      items = { -- water and food together
        "T'aurais de l'eau et de la bouffe à me filer stp ? %s",
        "Tu pourrais m'invoquer à boire et à manger ? %s",
        "Je peux te gratter à boire et à manger ? %s",
      },
    },
    polite = {
      hello = { "Bonjour ! ", "Bien le bonjour ! ", "Salutations ! " },
      bye = { "", "", " Quand vous pourrez.", " Sans urgence, bien sûr." },
      multi = {
        "Je ne dirais pas non à quelques buffs : %s",
        "Pourriez-vous me buff, s'il vous plaît ? (%s)",
        "Auriez-vous un instant pour quelques buffs ? (%s)",
      },
      new = {
        "Me feriez-vous l'honneur d'un buff ? %s",
        "Je ne dirais pas non à un buff : %s",
        "Pourriez-vous me lancer un buff, s'il vous plaît ? (%s)",
        "Auriez-vous un instant pour un buff ? (%s)",
      },
      replace = {
        "Petite requête : pourriez-vous échanger ma bénédiction contre celle-ci ? %s",
        "Votre bénédiction est appréciée, mais celle-ci m'aiderait davantage : %s",
        "Pourriez-vous changer ma bénédiction, s'il vous plaît ? (%s plutôt)",
      },
      upgrade = {
        "Votre buff est d'un rang plus élevé que le mien : pourriez-vous me le relancer ? (%s)",
        "Le mien est de rang faible : accepteriez-vous de me lancer le vôtre ? (%s)",
        "Pourriez-vous remplacer mon buff par le vôtre, plus puissant ? (%s)",
      },
      refresh = {
        "Pourriez-vous rafraîchir ce buff avant qu'il expire, s'il vous plaît ? (%s)",
        "Mon buff touche à sa fin : accepteriez-vous de le renouveler ? (%s)",
        "Il ne me reste que quelques minutes de %s. Pourriez-vous le relancer ?",
      },
      water = {
        "Auriez-vous un peu d'eau à me donner, s'il vous plaît ? %s",
        "Pourriez-vous m'invoquer de l'eau ? %s",
        "Je ne dirais pas non à un peu d'eau : %s",
      },
      food = {
        "Auriez-vous un peu de nourriture à me donner, s'il vous plaît ? %s",
        "Pourriez-vous m'invoquer de quoi manger ? %s",
        "Je ne dirais pas non à un peu de nourriture : %s",
      },
      items = {
        "Auriez-vous de quoi boire et manger ? %s",
        "Pourriez-vous m'invoquer de quoi boire et manger ? %s",
        "Je ne dirais pas non à de quoi boire et manger : %s",
      },
    },
    -- Role play: neutral and vous (see the English one for byClass).
    roleplay = {
      hello = { "Salutations, voyageur ! ", "Bien le bonjour ! ", "Je vous salue ! ", "Holà ! " },
      bye = { "", "", " Si votre mana le permet.", " Sans vouloir vous presser." },
      multi = {
        "Des buffs pour un voyageur fatigué ? (%s)",
        "La route est longue : me feriez-vous la grâce de quelques bienfaits ? (%s)",
        "Puis-je quémander vos bienfaits, l'ami ? (%s)",
      },
      new = {
        "Un buff pour un voyageur fatigué ? (%s)",
        "Accorderiez-vous à un humble voyageur un peu de votre pouvoir ? (%s)",
        "Puis-je quémander votre bienfait, l'ami ? (%s)",
        "La route est longue : me feriez-vous la grâce d'un buff ? (%s)",
      },
      replace = {
        "Votre bénédiction m'honore, mais celle-ci me servirait mieux : %s",
        "Accepteriez-vous d'échanger votre bénédiction contre celle-ci ? %s",
        "Puis-je vous prier de changer ma bénédiction ? (%s plutôt)",
      },
      upgrade = {
        "Votre pouvoir surpasse le mien, l'ami. Me l'accorderiez-vous ? (%s)",
        "Le mien n'est qu'une pâle lueur : accepteriez-vous de me lancer le vôtre ? (%s)",
        "Votre bienfait est plus puissant que le mien : me feriez-vous cet honneur ? (%s)",
      },
      refresh = {
        "Mon bienfait s'étiole, l'ami : le renouvelleriez-vous ? (%s)",
        "Le pouvoir de %s s'estompe en moi. Pourriez-vous le raviver ?",
        "Avant que mon bienfait ne s'efface, me le rendriez-vous ? (%s)",
      },
      water = {
        "Une gourde d'eau pour un voyageur assoiffé ? %s",
        "Puis-je quémander un peu de votre eau enchantée, l'ami ? %s",
        "La route est sèche : me feriez-vous la grâce d'un peu d'eau ? %s",
      },
      food = {
        "Un peu de pain pour un voyageur affamé ? %s",
        "Puis-je quémander un peu de votre pain enchanté, l'ami ? %s",
        "La route est longue : me feriez-vous la grâce d'un peu de pain ? %s",
      },
      items = {
        "À boire et à manger pour un voyageur ? %s",
        "Puis-je quémander eau et pain, l'ami ? %s",
        "Me feriez-vous la grâce d'eau et de pain ? %s",
      },
      byClass = {
        PALADIN = { new = {
          "Au nom de la Lumière, m'accorderiez-vous ceci ? %s",
          "Puis-je recevoir la grâce de la Lumière par vos mains ? (%s)",
          "La Lumière vous guide, l'ami : me feriez-vous ce don ? (%s)",
        } },
        PRIEST = { new = {
          "Par la Lumière, me feriez-vous ce don ? (%s)",
          "Prieriez-vous la Lumière pour moi, l'ami ? (%s)",
          "Un peu de la Lumière pour un voyageur ? (%s)",
        } },
        DRUID = { new = {
          "La nature m'accorderait-elle son don par vos mains ? (%s)",
          "Gardien des bois, me feriez-vous ce présent ? (%s)",
          "Un peu de la force des terres sauvages, l'ami ? (%s)",
        } },
        MAGE = { new = {
          "Tisseriez-vous un peu d'arcane pour moi ? (%s)",
          "Un soupçon d'arcanes pour un voyageur ? (%s)",
          "Me prêteriez-vous un peu de votre savoir arcanique ? (%s)",
        } },
      },
    },
  },
  en = {
    casual = {
      hello = { "Hi! ", "Hey! ", "Hey there! ", "Heya! ", "Yo! ", "" },
      bye = { "", "", " :)", " :D" },
      -- Several buffs from one player (#39): %s is every link, joined by ns.AND.
      multi = {
        "Mind sparing me %s?",
        "Any chance of %s?",
        "If you've got a sec, %s would be amazing.",
        "Could you throw %s my way?",
      },
      new = {
        "Could I get %s please?",
        "Mind sparing me %s?",
        "Any chance of %s?",
        "If you've got a sec, %s would be amazing.",
        "Mind hooking me up with %s?",
        "Could you throw %s my way?",
      },
      replace = {
        "Could you swap my blessing for %s please?",
        "Could you make my blessing %s instead?",
        "Any chance of %s instead of this blessing? It helps me more.",
      },
      upgrade = {
        "Your rank of %s would be a real treat.",
        "Mine's a low rank, could I get your %s?",
        "Mind overwriting my %s? Yours is a higher rank.",
      },
      refresh = {
        "Mind topping up my %s before it drops?",
        "Only a few minutes left on my %s, could I get a fresh one?",
        "My %s is fading, a quick recast?",
      },
      -- A mage's water and food (#47): %s is the spell link(s) and my level, "[Conjure Water] (lvl 23)".
      water = {
        "Got any water to spare? %s",
        "Mind conjuring me some water? %s",
        "Could I grab some water off you? %s",
      },
      food = {
        "Got any food to spare? %s",
        "Mind conjuring me some food? %s",
        "Could I grab some food off you? %s",
      },
      items = { -- water and food together
        "Got any water and food to spare? %s",
        "Mind conjuring me some water and food? %s",
        "Could I grab some water and food off you? %s",
      },
    },
    polite = {
      hello = { "Hello! ", "Hi there! ", "Greetings! ", "Good day! " },
      bye = { "", "", " Whenever you have a moment.", " No rush, of course." },
      multi = {
        "Could I get %s please?",
        "Would you mind casting %s on me?",
        "Could I trouble you for %s?",
      },
      new = {
        "Would you be so kind as to cast me %s?",
        "May I ask you for %s, please?",
        "I'd love %s if you don't mind.",
        "Would you mind casting %s on me?",
        "Could I trouble you for %s?",
      },
      replace = {
        "Would you mind switching my blessing to %s?",
        "Your blessing is great, but %s would suit me even better.",
        "Would it be possible to change my blessing to %s?",
      },
      upgrade = {
        "Could I get your %s please? Yours is a higher rank.",
        "Your %s is stronger than mine, would you mind recasting it?",
        "Would you mind recasting %s on me? Yours is a higher rank than mine.",
      },
      refresh = {
        "My %s is about to wear off, could you refresh it?",
        "Could you refresh my %s please? It's running out.",
        "Would you mind renewing my %s? It is about to wear off.",
      },
      water = {
        "Could you spare some water, please? %s",
        "Would you mind conjuring some water for me? %s",
        "May I ask you for some water? %s",
      },
      food = {
        "Could you spare some food, please? %s",
        "Would you mind conjuring some food for me? %s",
        "May I ask you for some food? %s",
      },
      items = {
        "Could you spare some water and food, please? %s",
        "Would you mind conjuring some water and food for me? %s",
        "May I ask you for some water and food? %s",
      },
    },
    -- Role play: a neutral register that fits any race and class. byClass (optional, any part) gives
    -- the giver's class a touch of its own; a missing bag falls back on the neutral one (#51 adds more).
    roleplay = {
      hello = { "Well met! ", "Hail and well met! ", "Greetings, traveler! ", "Hail, friend! " },
      bye = { "", "", " If thou canst spare the mana.", " Should time allow." },
      multi = {
        "Might I beg %s of thee?",
        "Would you grant a weary traveler %s?",
        "The road is long. Could you spare %s?",
      },
      new = {
        "Might I beg %s of thee, friend?",
        "Would you grant a weary traveler %s?",
        "Could you spare %s for the road ahead?",
        "I would gladly bear %s into battle, if you would grant it.",
      },
      replace = {
        "Might I trade thy blessing for %s? It would serve me better.",
        "Thy blessing honors me, yet %s would serve me better.",
        "Would you bless me with %s instead?",
      },
      upgrade = {
        "Thy %s burns brighter than mine. Wouldst thou lend it to me?",
        "Mine is but a faint %s. Would you grant me yours?",
        "Your %s is mightier than mine, friend. Would you renew it?",
      },
      refresh = {
        "My %s fades, friend. Would you renew it?",
        "The power of %s wanes upon me. Might you restore it?",
        "Ere my %s fades, could you renew it?",
      },
      water = {
        "Could you conjure a flask of water for a weary traveler? %s",
        "Might I beg some conjured water of thee? %s",
        "The road is dry, friend. Could you spare some water? %s",
      },
      food = {
        "Could you conjure some bread for a weary traveler? %s",
        "Might I beg some conjured bread of thee? %s",
        "The road is long, friend. Could you spare some food? %s",
      },
      items = {
        "Water and food for a weary traveler? %s",
        "Might I beg water and food of thee? %s",
        "Could you spare water and food, friend? %s",
      },
      byClass = {
        PALADIN = { new = {
          "Might the Light grant me %s through thy hands?",
          "In the Light's name, would you grant me %s?",
          "Would you call upon the Light for %s, friend?",
        } },
        PRIEST = { new = {
          "Might the Light grant me thy %s?",
          "Would you ask the Light for %s on my behalf?",
          "By the Light, could you spare %s?",
        } },
        DRUID = { new = {
          "Might nature grant me %s through you, friend?",
          "Could you spare %s, keeper of the wilds?",
          "Would you share nature's blessing? %s",
        } },
        MAGE = { new = {
          "Could you weave %s upon me, friend?",
          "Might I borrow a touch of the arcane? %s",
          "Would you spare a little arcane might? %s",
        } },
      },
    },
  },
  de = {
    casual = {
      -- Like French: the spell goes in brackets or after a colon, no article to agree with.
      hello = { "Hallo! ", "Hey! ", "Hi! ", "Grüß dich! ", "Moin! ", "Servus! ", "" },
      bye = { "", "", " :)", " :D" },
      -- Several buffs from one player (#39): %s is every link, joined by ns.AND.
      multi = {
        "Hättest du ein paar Buffs für mich? (%s)",
        "Wenn du kurz Zeit hast: %s bitte.",
        "Über ein paar Buffs würde ich mich sehr freuen: %s",
        "Magst du mich kurz buffen? (%s)",
      },
      new = {
        "Hättest du einen Buff für mich? (%s)",
        "Wenn du kurz Zeit hast: %s bitte.",
        "Könnte ich einen Buff bekommen? %s",
        "Ein kleiner Buff für einen müden Reisenden? (%s)",
        "Über einen Buff würde ich mich sehr freuen: %s",
        "Magst du mich kurz buffen? (%s)",
      },
      replace = {
        "Könntest du meinen Segen tauschen? (lieber %s)",
        "Kleine Bitte: könntest du meinen Segen gegen %s tauschen?",
        "Ein anderer Segen wäre mir lieber: %s",
        "Könntest du meinen Segen ersetzen? Das hilft mir mehr: %s",
      },
      upgrade = {
        "Dein Buff ist einen Rang höher als meiner: %s bitte?",
        "Dein Buff ist stärker als meiner (%s), magst du nachbuffen?",
        "Meiner hat nur einen niedrigen Rang. Nochmal buffen? (%s)",
        "Deiner ist stärker, einmal überbuffen bitte? (%s)",
      },
      refresh = {
        "Mein Buff läuft gleich aus, könntest du nachbuffen? (%s)",
        "%s läuft bei mir bald ab, einmal erneuern bitte?",
        "Nur noch ein paar Minuten %s übrig, kurz nachbuffen bitte?",
        "Mein Buff ist fast weg, einmal auffrischen? (%s)",
      },
      water = {
        "Hast du etwas Wasser übrig? %s",
        "Kannst du mir Wasser zaubern? %s",
        "Hättest du Wasser für mich? %s",
      },
      food = {
        "Hast du etwas Essen übrig? %s",
        "Kannst du mir Essen zaubern? %s",
        "Hättest du Essen für mich? %s",
      },
      items = {
        "Hast du Wasser und Essen übrig? %s",
        "Kannst du mir Wasser und Essen zaubern? %s",
        "Hättest du Wasser und Essen für mich? %s",
      },
    },
    polite = { -- Sie
      hello = { "Hallo! ", "Guten Tag! ", "Grüße! " },
      bye = { "", "", " Wenn es Ihnen passt.", " Ganz ohne Eile." },
      multi = {
        "Hätten Sie ein paar Buffs für mich? (%s)",
        "Wenn Sie kurz Zeit haben: %s, bitte.",
        "Dürfte ich Sie um ein paar Buffs bitten? (%s)",
      },
      new = {
        "Hätten Sie einen Buff für mich? (%s)",
        "Dürfte ich Sie um einen Buff bitten? (%s)",
        "Wenn Sie kurz Zeit haben: %s, bitte.",
      },
      replace = {
        "Könnten Sie meinen Segen tauschen? (lieber %s)",
        "Dürfte ich Sie bitten, meinen Segen gegen %s zu tauschen?",
        "Ihr Segen ist toll, aber dieser würde mir mehr helfen: %s",
      },
      upgrade = {
        "Ihr Buff ist einen Rang höher als meiner. Würden Sie ihn erneuern? (%s)",
        "Meiner hat nur einen niedrigen Rang. Dürfte ich Ihren haben? (%s)",
        "Könnten Sie mir bitte Ihren stärkeren Buff geben? (%s)",
      },
      refresh = {
        "Mein Buff läuft gleich aus. Könnten Sie ihn bitte erneuern? (%s)",
        "%s läuft bei mir bald ab. Würden Sie ihn auffrischen?",
        "Nur noch wenige Minuten %s. Dürfte ich Sie um eine Erneuerung bitten?",
      },
      water = {
        "Hätten Sie etwas Wasser für mich? %s",
        "Könnten Sie mir Wasser herbeizaubern? %s",
        "Dürfte ich Sie um etwas Wasser bitten? %s",
      },
      food = {
        "Hätten Sie etwas Essen für mich? %s",
        "Könnten Sie mir Essen herbeizaubern? %s",
        "Dürfte ich Sie um etwas Essen bitten? %s",
      },
      items = {
        "Hätten Sie Wasser und Essen für mich? %s",
        "Könnten Sie mir Wasser und Essen zaubern? %s",
        "Dürfte ich Sie um Wasser und Essen bitten? %s",
      },
    },
  },
  es = {
    casual = {
      hello = { "¡Hola! ", "¡Buenas! ", "¡Hey! ", "¡Saludos! ", "" },
      bye = { "", "", " :)", " :D" },
      -- Several buffs from one player (#39): %s is every link, joined by ns.AND.
      multi = {
        "¿Me podrías dar unos buffs? (%s)",
        "Si tienes un momento: %s, por favor.",
        "¿Unos buffs para un viajero cansado? (%s)",
      },
      new = {
        "¿Me podrías dar un buff? (%s)",
        "Si tienes un segundo: %s, por favor.",
        "¿Un buff de paso? %s",
        "¿Un buff para un viajero cansado? (%s)",
        "¿Me echas un buff, por favor? %s",
      },
      replace = {
        "¿Podrías cambiar mi bendición? (mejor %s)",
        "¿Me podrías poner %s en lugar de mi bendición? Me ayuda más.",
        "Pequeño favor: ¿cambiarías mi bendición por %s?",
      },
      upgrade = {
        "¿Me podrías volver a bufear? (%s, el tuyo es de rango más alto)",
        "Tu buff es más fuerte que el mío (%s), ¿me lo renuevas?",
        "El mío es de rango bajo, ¿me pones el tuyo? (%s)",
      },
      refresh = {
        "Mi buff se acaba pronto, ¿me lo renuevas? (%s)",
        "%s se me va a acabar, ¿un rebuff, por favor?",
        "Me quedan pocos minutos de %s, ¿me renuevas el buff?",
      },
      water = {
        "¿Te sobra algo de agua? %s",
        "¿Me conjuras un poco de agua? %s",
        "¿Me pasas algo de agua? %s",
      },
      food = {
        "¿Te sobra algo de comida? %s",
        "¿Me conjuras un poco de comida? %s",
        "¿Me pasas algo de comida? %s",
      },
      items = {
        "¿Te sobra agua y comida? %s",
        "¿Me conjuras agua y comida? %s",
        "¿Me pasas agua y comida? %s",
      },
    },
    polite = { -- usted
      hello = { "¡Hola! ", "¡Saludos! ", "¡Hola, buenas! " },
      bye = { "", "", " Cuando pueda.", " Sin prisa, por supuesto." },
      multi = {
        "¿Podría darme unos buffs, por favor? (%s)",
        "Si tiene un momento: %s, por favor.",
        "¿Sería tan amable de darme unos buffs? (%s)",
      },
      new = {
        "¿Podría darme un buff, por favor? (%s)",
        "Si tiene un momento: %s, por favor.",
        "¿Sería tan amable de darme un buff? (%s)",
      },
      replace = {
        "¿Podría cambiar mi bendición, por favor? (mejor %s)",
        "¿Sería tan amable de ponerme %s en lugar de mi bendición?",
        "Su bendición es estupenda, pero %s me ayudaría más.",
      },
      upgrade = {
        "Su buff es de rango más alto que el mío. ¿Podría renovarlo? (%s)",
        "El mío es de rango bajo. ¿Podría darme el suyo? (%s)",
        "¿Sería tan amable de ponerme el suyo, que es más fuerte? (%s)",
      },
      refresh = {
        "Mi buff se acaba pronto. ¿Podría renovarlo, por favor? (%s)",
        "%s se me va a acabar. ¿Sería tan amable de renovarlo?",
        "Me quedan pocos minutos de %s. ¿Podría renovármelo?",
      },
      water = {
        "¿Podría darme un poco de agua, por favor? %s",
        "¿Sería tan amable de conjurarme agua? %s",
        "¿Le sobraría algo de agua? %s",
      },
      food = {
        "¿Podría darme un poco de comida, por favor? %s",
        "¿Sería tan amable de conjurarme comida? %s",
        "¿Le sobraría algo de comida? %s",
      },
      items = {
        "¿Podría darme agua y comida, por favor? %s",
        "¿Sería tan amable de conjurarme agua y comida? %s",
        "¿Le sobraría agua y comida? %s",
      },
    },
  },
  it = {
    casual = {
      hello = { "Ciao! ", "Ehi! ", "Salve! ", "Ciao a te! ", "" },
      bye = { "", "", " :)", " :D" },
      -- Several buffs from one player (#39): %s is every link, joined by ns.AND.
      multi = {
        "Mi daresti qualche buff? (%s)",
        "Se hai un attimo: %s, per favore.",
        "Qualche buff per un viaggiatore stanco? (%s)",
      },
      new = {
        "Mi faresti un buff? (%s)",
        "Se hai un attimo: %s, per favore.",
        "Un buff al volo? %s",
        "Un buff per un viaggiatore stanco? (%s)",
        "Mi lanceresti un buff, per favore? %s",
      },
      replace = {
        "Potresti cambiare la mia benedizione? (meglio %s)",
        "Potresti mettermi %s al posto della mia benedizione? Mi aiuta di più.",
        "Piccola richiesta: cambieresti la mia benedizione con %s?",
      },
      upgrade = {
        "Mi rifaresti il buff? (%s, il tuo è di rango più alto)",
        "Il tuo buff è più forte del mio (%s), me lo rinnovi?",
        "Il mio è di rango basso, mi daresti il tuo? (%s)",
      },
      refresh = {
        "Il mio buff sta per scadere, me lo rinnovi? (%s)",
        "%s sta per finire, un rebuff per favore?",
        "Mi restano pochi minuti di %s, mi rinnovi il buff?",
      },
      water = {
        "Hai un po' d'acqua da darmi? %s",
        "Mi evochi un po' d'acqua? %s",
        "Mi passi un po' d'acqua? %s",
      },
      food = {
        "Hai un po' di cibo da darmi? %s",
        "Mi evochi un po' di cibo? %s",
        "Mi passi un po' di cibo? %s",
      },
      items = {
        "Hai acqua e cibo da darmi? %s",
        "Mi evochi acqua e cibo? %s",
        "Mi passi acqua e cibo? %s",
      },
    },
    polite = { -- Lei
      hello = { "Salve! ", "Buongiorno! ", "Ciao! " },
      bye = { "", "", " Quando può.", " Senza fretta, s'intende." },
      multi = {
        "Potrebbe darmi qualche buff, per favore? (%s)",
        "Se ha un attimo: %s, per favore.",
        "Sarebbe così gentile da darmi qualche buff? (%s)",
      },
      new = {
        "Potrebbe farmi un buff, per favore? (%s)",
        "Se ha un attimo: %s, per favore.",
        "Sarebbe così gentile da darmi un buff? (%s)",
      },
      replace = {
        "Potrebbe cambiare la mia benedizione, per favore? (meglio %s)",
        "Sarebbe così gentile da mettermi %s al posto della mia benedizione?",
        "La Sua benedizione è ottima, ma %s mi aiuterebbe di più.",
      },
      upgrade = {
        "Il Suo buff è di rango più alto del mio. Potrebbe rinnovarlo? (%s)",
        "Il mio è di rango basso. Potrebbe darmi il Suo? (%s)",
        "Sarebbe così gentile da darmi il Suo, che è più forte? (%s)",
      },
      refresh = {
        "Il mio buff sta per scadere. Potrebbe rinnovarlo, per favore? (%s)",
        "%s sta per finire. Sarebbe così gentile da rinnovarlo?",
        "Mi restano pochi minuti di %s. Potrebbe rinnovarmelo?",
      },
      water = {
        "Potrebbe darmi un po' d'acqua, per favore? %s",
        "Le avanza un po' d'acqua? %s",
        "Sarebbe così gentile da evocarmi dell'acqua? %s",
      },
      food = {
        "Potrebbe darmi un po' di cibo, per favore? %s",
        "Le avanza un po' di cibo? %s",
        "Sarebbe così gentile da evocarmi del cibo? %s",
      },
      items = {
        "Potrebbe darmi acqua e cibo, per favore? %s",
        "Le avanzano acqua e cibo? %s",
        "Sarebbe così gentile da evocarmi acqua e cibo? %s",
      },
    },
  },
  pt = { -- Brazilian: WoW's only Portuguese client is ptBR
    casual = {
      hello = { "Oi! ", "E aí! ", "Olá! ", "Saudações! ", "" },
      bye = { "", "", " :)", " :D" },
      -- Several buffs from one player (#39): %s is every link, joined by ns.AND.
      multi = {
        "Pode me dar uns buffs? (%s)",
        "Se tiver um tempinho: %s, por favor.",
        "Uns buffs para um viajante cansado? (%s)",
      },
      new = {
        "Você poderia me dar um buff? (%s)",
        "Se tiver um segundinho: %s, por favor.",
        "Um buff de passagem? %s",
        "Um buff para um viajante cansado? (%s)",
        "Me dá um buff, por favor? %s",
      },
      replace = {
        "Você poderia trocar minha bênção? (prefiro %s)",
        "Poderia me dar %s no lugar da minha bênção? Me ajuda mais.",
        "Um pedidinho: troca minha bênção por %s?",
      },
      upgrade = {
        "Poderia me dar o buff de novo? (%s, o seu é de rank mais alto)",
        "Seu buff é mais forte que o meu (%s), pode renovar?",
        "O meu é de rank baixo, me dá o seu? (%s)",
      },
      refresh = {
        "Meu buff está quase acabando, pode renovar? (%s)",
        "%s está acabando, um rebuff por favor?",
        "Faltam poucos minutos de %s, renova o buff pra mim?",
      },
      water = {
        "Tem uma aguinha sobrando? %s",
        "Conjura uma água pra mim? %s",
        "Me arruma uma água? %s",
      },
      food = {
        "Tem uma comidinha sobrando? %s",
        "Conjura uma comida pra mim? %s",
        "Me arruma uma comida? %s",
      },
      items = {
        "Tem água e comida sobrando? %s",
        "Conjura água e comida pra mim? %s",
        "Me arruma água e comida? %s",
      },
    },
    polite = { -- você + por favor
      hello = { "Olá! ", "Saudações! ", "Olá, tudo bem? " },
      bye = { "", "", " Quando puder.", " Sem pressa, claro." },
      multi = {
        "Você poderia me dar uns buffs, por favor? (%s)",
        "Se tiver um momento: %s, por favor.",
        "Seria possível me dar uns buffs? (%s)",
      },
      new = {
        "Você poderia me dar um buff, por favor? (%s)",
        "Se tiver um momento: %s, por favor.",
        "Seria possível me dar um buff? (%s)",
      },
      replace = {
        "Você poderia trocar minha bênção, por favor? (prefiro %s)",
        "Seria possível me dar %s no lugar da minha bênção?",
        "Sua bênção é ótima, mas %s me ajudaria mais.",
      },
      upgrade = {
        "Seu buff é de rank mais alto que o meu. Poderia renovar, por favor? (%s)",
        "O meu é de rank baixo. Você poderia me dar o seu? (%s)",
        "Seria possível me dar o seu, que é mais forte? (%s)",
      },
      refresh = {
        "Meu buff está acabando. Você poderia renovar, por favor? (%s)",
        "%s está quase no fim. Seria possível renovar?",
        "Faltam poucos minutos de %s. Poderia renovar, por favor?",
      },
      water = {
        "Poderia me dar um pouco de água, por favor? %s",
        "Você se importaria de conjurar água para mim? %s",
        "Teria um pouco de água, por favor? %s",
      },
      food = {
        "Poderia me dar um pouco de comida, por favor? %s",
        "Você se importaria de conjurar comida para mim? %s",
        "Teria um pouco de comida, por favor? %s",
      },
      items = {
        "Poderia me dar água e comida, por favor? %s",
        "Poderia conjurar água e comida para mim? %s",
        "Teria água e comida, por favor? %s",
      },
    },
  },
  ru = {
    casual = {
      hello = { "Привет! ", "Здравствуй! ", "Хай! ", "Приветствую! ", "" },
      bye = { "", "", " :)", " :D" },
      -- Several buffs from one player (#39): %s is every link, joined by ns.AND.
      multi = {
        "Можешь бафнуть, пожалуйста? (%s)",
        "Если не трудно: %s, пожалуйста.",
        "Бафы для уставшего путника? (%s)",
      },
      new = {
        "Можно баф, пожалуйста? (%s)",
        "Если есть секунда: %s, пожалуйста.",
        "Не кинешь баф? %s",
        "Баф для уставшего путника? (%s)",
        "Бафнешь, пожалуйста? %s",
      },
      replace = {
        "Можешь поменять мне благословение? (лучше %s)",
        "Можно вместо моего благословения %s? Мне так полезнее.",
        "Маленькая просьба: поменяешь благословение на %s?",
      },
      upgrade = {
        "Перебафнешь, пожалуйста? (%s, у тебя ранг выше)",
        "Твой баф сильнее моего (%s), обновишь?",
        "У меня низкий ранг, можно твой? (%s)",
      },
      refresh = {
        "Мой баф скоро спадёт, обновишь? (%s)",
        "%s скоро закончится, перебафнешь, пожалуйста?",
        "Осталось всего пару минут %s, обновишь?",
      },
      water = {
        "Водички не найдётся? %s",
        "Наколдуешь воды? %s",
        "Можно у тебя воды? %s",
      },
      food = {
        "Еды не найдётся? %s",
        "Наколдуешь еды? %s",
        "Можно у тебя еды? %s",
      },
      items = {
        "Воды и еды не найдётся? %s",
        "Наколдуешь воды и еды? %s",
        "Можно у тебя воды и еды? %s",
      },
    },
    polite = { -- вы
      hello = { "Здравствуйте! ", "Добрый день! ", "Приветствую! " },
      bye = { "", "", " Когда сможете.", " Не спешите, конечно." },
      multi = {
        "Не могли бы вы меня бафнуть? (%s)",
        "Если у вас есть минутка: %s, пожалуйста.",
        "Можно попросить у вас бафы? (%s)",
      },
      new = {
        "Не могли бы вы дать мне баф? (%s)",
        "Если у вас есть минутка: %s, пожалуйста.",
        "Можно попросить у вас баф? (%s)",
      },
      replace = {
        "Не могли бы вы поменять мне благословение? (лучше %s)",
        "Можно попросить у вас %s вместо моего благословения?",
        "Ваше благословение отличное, но %s мне полезнее.",
      },
      upgrade = {
        "Ваш баф выше рангом, чем мой. Не могли бы вы обновить? (%s)",
        "У меня низкий ранг. Можно попросить ваш? (%s)",
        "Не могли бы вы перебафнуть меня? (%s, у вас ранг выше)",
      },
      refresh = {
        "Мой баф скоро спадёт. Не могли бы вы обновить? (%s)",
        "%s скоро закончится. Можно попросить вас обновить?",
        "Осталось всего пару минут %s. Не могли бы вы обновить?",
      },
      water = {
        "Не найдётся ли у вас воды? %s",
        "Не могли бы вы наколдовать мне воды? %s",
        "Можно попросить у вас воды? %s",
      },
      food = {
        "Не найдётся ли у вас еды? %s",
        "Не могли бы вы наколдовать мне еды? %s",
        "Можно попросить у вас еды? %s",
      },
      items = {
        "Не найдётся ли у вас воды и еды? %s",
        "Наколдуете мне воды и еды? %s",
        "Можно попросить у вас воды и еды? %s",
      },
    },
  },
  pl = {
    casual = {
      hello = { "Cześć! ", "Hej! ", "Witaj! ", "Siema! ", "" },
      bye = { "", "", " :)", " :D" },
      -- Several buffs from one player (#39): %s is every link, joined by ns.AND.
      multi = {
        "Możesz mnie zbuffować? (%s)",
        "Jak masz chwilę: %s, proszę.",
        "Buffy dla zmęczonego podróżnika? (%s)",
      },
      new = {
        "Dasz mi buffa? (%s)",
        "Jeśli masz chwilkę: %s, proszę.",
        "Buff w przelocie? %s",
        "Buff dla zmęczonego wędrowca? (%s)",
        "Zbuffujesz mnie, proszę? %s",
      },
      replace = {
        "Możesz zmienić moje błogosławieństwo? (wolę %s)",
        "Możesz dać mi %s zamiast mojego błogosławieństwa? Bardziej mi pomoże.",
        "Mała prośba: zamienisz moje błogosławieństwo na %s?",
      },
      upgrade = {
        "Zbuffujesz mnie jeszcze raz? (%s, twój ma wyższą rangę)",
        "Twój buff jest mocniejszy niż mój (%s), odnowisz?",
        "Mój ma niską rangę, dasz mi swój? (%s)",
      },
      refresh = {
        "Mój buff zaraz spadnie, odnowisz? (%s)",
        "%s zaraz mi się skończy, rebuff proszę?",
        "Kończy mi się %s, odnowisz buffa?",
      },
      water = {
        "Masz trochę wody na zbyciu? %s",
        "Wyczarujesz mi wodę? %s",
        "Podrzucisz mi trochę wody? %s",
      },
      food = {
        "Masz trochę jedzenia na zbyciu? %s",
        "Wyczarujesz mi jedzenie? %s",
        "Podrzucisz mi trochę jedzenia? %s",
      },
      items = {
        "Masz wodę i jedzenie na zbyciu? %s",
        "Wyczarujesz mi wodę i jedzenie? %s",
        "Podrzucisz mi wodę i jedzenie? %s",
      },
    },
    polite = { -- impersonal (no Pan/Pani: the reader's gender is unknown)
      hello = { "Dzień dobry! ", "Witam! ", "Witaj! " },
      bye = { "", "", " Gdy będzie można.", " Bez pośpiechu, oczywiście." },
      multi = {
        "Czy można prosić o kilka buffów? (%s)",
        "Jeśli jest chwila: %s, proszę.",
        "Uprzejmie proszę o kilka buffów: %s",
      },
      new = {
        "Czy można prosić o buffa? (%s)",
        "Jeśli jest chwila: %s, proszę.",
        "Uprzejmie proszę o buffa: %s",
      },
      replace = {
        "Czy można prosić o zmianę błogosławieństwa? (wolę %s)",
        "Uprzejmie proszę o %s zamiast mojego błogosławieństwa.",
        "Obecne błogosławieństwo jest świetne, ale %s bardziej mi pomoże.",
      },
      upgrade = {
        "Czy można prosić o odnowienie? (%s, ma wyższą rangę niż mój)",
        "Mój ma niską rangę. Czy można prosić o mocniejszy? (%s)",
        "Uprzejmie proszę o mocniejszą wersję: %s",
      },
      refresh = {
        "Mój buff zaraz spadnie. Czy można prosić o odnowienie? (%s)",
        "%s zaraz się skończy. Uprzejmie proszę o odnowienie.",
        "Zostało mi kilka minut %s. Czy można prosić o odnowienie?",
      },
      water = {
        "Czy można prosić o trochę wody? %s",
        "Czy znalazłoby się trochę wody? %s",
        "Uprzejmie proszę o trochę wody. %s",
      },
      food = {
        "Czy można prosić o trochę jedzenia? %s",
        "Czy znalazłoby się trochę jedzenia? %s",
        "Uprzejmie proszę o trochę jedzenia. %s",
      },
      items = {
        "Czy można prosić o wodę i jedzenie? %s",
        "Czy znalazłoby się woda i jedzenie? %s",
        "Uprzejmie proszę o wodę i jedzenie. %s",
      },
    },
  },
}

-- How each language joins several spell links (#39): "A and B", "A, B and C".
ns.AND = { en = " and ", fr = " et ", de = " und ", es = " y ", it = " e ", pt = " e ", ru = " и ", pl = " i " }

-- My level after a water or food link (#47): the mage conjures the rank I can use.
ns.LEVEL = { en = "lvl %d", fr = "niv. %d", de = "Stufe %d", es = "nivel %d", it = "liv. %d", pt = "nível %d",
  ru = "ур. %d", pl = "poz. %d" }

-- Sent in the same channel as the request, once the buff lands: one of `thanks`, then one of `bye`
-- (same shuffled bags as requests). Same tones as ns.MESSAGES.
ns.THANKS = {
  fr = {
    casual = {
      thanks = { "Merci !", "Super, merci !", "Génial, merci !", "Merci mille fois !", "Top, merci !" },
      bye = { "", " T'es au top !", " Bon jeu à toi !", " Bonne aventure !", " Bon courage !",
        " Bonne route !" },
    },
    polite = {
      thanks = { "Merci beaucoup !", "Parfait, merci !", "Merci bien !", "Je vous remercie !" },
      bye = { "", " Bonne continuation !", " Excellente journée !", " Bon jeu !" },
    },
    roleplay = {
      thanks = { "Mille mercis, l'ami !", "Toute ma gratitude !", "Je vous suis redevable !", "Merci, noble ami !" },
      bye = { "", " Que la route vous soit douce.", " Puissent nos chemins se recroiser.", " Bonne route, voyageur." },
    },
  },
  en = {
    casual = {
      thanks = { "Thanks!", "Thanks a lot!", "Cheers!", "Ty!", "Awesome, thanks!", "Thanks a bunch!" },
      bye = { "", " You're the best!", " Have a good one!", " Good luck out there!" },
    },
    polite = {
      thanks = { "Thank you!", "Much appreciated!", "Perfect, thank you!", "Thank you very much!" },
      bye = { "", " Have a great one!", " Safe travels!", " All the best!" },
    },
    roleplay = {
      thanks = { "My thanks, friend!", "You have my gratitude!", "I am in thy debt!", "Thank you kindly!" },
      bye = { "", " Safe roads, friend.", " May your path be ever clear.", " Until our paths cross again." },
    },
  },
  de = {
    casual = {
      thanks = { "Danke!", "Super, danke!", "Danke dir!" },
      bye = { "", " Du bist super!", " Noch ein schönes Spiel!", " Viel Erfolg!", " Gute Reise!" },
    },
    polite = {
      thanks = { "Vielen Dank!", "Danke schön!", "Herzlichen Dank!" },
      bye = { "", " Einen schönen Tag noch!", " Alles Gute!", " Gute Fahrt!" },
    },
  },
  es = {
    casual = {
      thanks = { "¡Gracias!", "¡Genial, gracias!", "¡Mil gracias!" },
      bye = { "", " ¡Eres un crack!", " ¡Buena suerte!", " ¡Buena aventura!", " ¡Buen viaje!" },
    },
    polite = {
      thanks = { "¡Muchas gracias!", "¡Se lo agradezco!", "¡Muy amable, gracias!" },
      bye = { "", " ¡Que tenga un buen día!", " ¡Mucha suerte!", " ¡Que le vaya bien!" },
    },
  },
  it = {
    casual = {
      thanks = { "Grazie!", "Fantastico, grazie!", "Grazie davvero!" },
      bye = { "", " Sei un grande!", " Buona avventura!", " Buon gioco!" },
    },
    polite = {
      thanks = { "Grazie mille!", "La ringrazio!", "Molto gentile, grazie!" },
      bye = { "", " Buona giornata!", " Buon viaggio!", " Tante belle cose!" },
    },
  },
  pt = {
    casual = {
      thanks = { "Valeu!", "Show, valeu!", "Valeu demais!" },
      bye = { "", " Você é demais!", " Boa sorte!", " Boa aventura!", " Bom jogo!" },
    },
    polite = {
      thanks = { "Muito obrigado!", "Agradeço muito!", "Muito gentil, obrigado!" },
      bye = { "", " Tenha um ótimo dia!", " Boa viagem!", " Tudo de bom!" },
    },
  },
  ru = {
    casual = {
      thanks = { "Спасибо!", "Отлично, спасибо!", "Спасибо большое!" },
      bye = { "", " Удачи!", " Хорошей игры!" },
    },
    polite = {
      thanks = { "Большое спасибо!", "Благодарю вас!", "Очень любезно, спасибо!" },
      bye = { "", " Хорошего дня!", " Всего доброго!", " Удачи вам!" },
    },
  },
  pl = {
    casual = {
      thanks = { "Dzięki!", "Super, dzięki!", "Dzięki bardzo!" },
      bye = { "", " Jesteś super!", " Powodzenia!", " Miłej gry!" },
    },
    polite = {
      thanks = { "Wielkie dzięki!", "Bardzo dziękuję!", "Dziękuję uprzejmie!" },
      bye = { "", " Miłego dnia!", " Wszystkiego dobrego!", " Udanej podróży!" },
    },
  },
}

-- Role play exists in English and French only (#49): elsewhere it is Polite.
for _, T in ipairs({ ns.MESSAGES, ns.THANKS }) do
  for _, l in pairs(T) do
    l.roleplay = l.roleplay or l.polite
  end
end

-- Tones offered in the settings (#49), in menu order.
ns.TONES = { { "casual", "Casual" }, { "polite", "Polite" }, { "roleplay", "Role play" } }

-- Languages offered in the settings, in menu order, each under its own name.
ns.LANGUAGES = {
  { "en", "English" }, { "fr", "Français" }, { "de", "Deutsch" }, { "es", "Español" },
  { "it", "Italiano" }, { "pt", "Português" }, { "pl", "Polski" }, { "ru", "Русский" },
}

-- Shuffle bag: each line of `list` comes out once, in random order, before the bag refills. The last
-- line of one round never opens the next, so nothing comes out twice in a row.
-- Weak keys: the bags of custom lists replaced since (a new table per save) go away.
local bags, lastPick = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })

local function pick(list)
  local bag = bags[list]
  if not bag or #bag == 0 then
    bag = {}
    for i = 1, #list do bag[i] = list[i] end
    for i = #bag, 2, -1 do
      local j = math.random(i)
      bag[i], bag[j] = bag[j], bag[i]
    end
    if #bag > 1 and bag[#bag] == lastPick[list] then bag[1], bag[#bag] = bag[#bag], bag[1] end
    bags[list] = bag
  end
  local line = table.remove(bag)
  lastPick[list] = line
  return line
end

-- The spell goes in as a clickable link: the reader gets the tooltip in their own language.
-- The link's visible text is the game's (French on a French client); in English we swap in the
-- English name. To check in game: the server could refuse a link whose text it did not write
-- (then the whisper never shows up as sent).
local function spellText(buff, lang)
  local client = GetLocale():sub(1, 2)
  local name = lang == client and C_Spell.GetSpellName(buff.id) or buff.en
  local link = C_Spell.GetSpellLink and C_Spell.GetSpellLink(buff.id)
  if not link then return name end
  return (link:gsub("%[.-%]", "[" .. name .. "]"))
end

-- ---------------------------------------------------------------- custom phrases (#20)
-- BuffDiggerDB.custom[kind] (new, replace, upgrade, refresh, thanks): whole lines the player wrote,
-- sent instead of ours while not empty, in any language. {spell} stands for the spell link
-- (requests only). BuffDiggerDB.customText[kind] keeps the box as typed, refused lines included.
ns.CUSTOM_KINDS = { "new", "replace", "upgrade", "refresh", "thanks" }
local CUSTOM_MAX = 20
local SAY_PREFIX = 12 * 2 + 3 -- "Name : " before a /say: 12 letters of up to 2 bytes each

local function custom(kind)
  local list = BuffDiggerDB and BuffDiggerDB.custom and BuffDiggerDB.custom[kind]
  return list and #list > 0 and list
end

-- Saves the lines of `text` that can be sent; returns the refused ones, as messages.
-- Typed text is never run through string.format: a % stays a %. | (WoW's chat codes) is refused.
-- The length allows for the longest link in either spelling (English or the client's language), so
-- changing "Write to players in" later can't push a line over the chat limit.
function ns.setCustom(kind, text)
  local L = ns.L
  local client, longest = GetLocale():sub(1, 2), 0
  for _, buff in pairs(ns.BUFFS) do
    longest = math.max(longest, #spellText(buff, "en"), #spellText(buff, client))
  end
  local lines, errors, n = {}, {}, 0
  for raw in (text .. "\n"):gmatch("(.-)\n") do
    n = n + 1
    local line = raw:match("^%s*(.-)%s*$")
    local spells = select(2, line:gsub("{spell}", ""))
    local over = #line + spells * (longest - #"{spell}") + SAY_PREFIX - 255
    local err
    if line == "" then -- skipped
    elseif line:find("|", 1, true) then err = L["no | (chat codes can't be typed)"]
    elseif kind == "thanks" and spells > 0 then err = L["no {spell} in a thank-you"]
    elseif kind ~= "thanks" and spells ~= 1 then err = L["needs {spell} exactly once"]
    elseif over > 0 then err = L["too long for the chat (%d over)"]:format(over)
    elseif #lines == CUSTOM_MAX then err = L["%d lines at most"]:format(CUSTOM_MAX)
    else lines[#lines + 1] = line end
    if err then errors[#errors + 1] = L["Line %d: %s"]:format(n, err) end
  end
  if text ~= BuffDiggerDB.customText[kind] or not BuffDiggerDB.custom[kind] then
    BuffDiggerDB.custom[kind] = lines -- a new table: pick() starts a fresh bag for it
    BuffDiggerDB.customText[kind] = text
  end
  return errors
end

-- The bags of one language and tone: an unknown language writes English, an unknown tone Casual.
local function toned(T, lang, tone)
  local l = T[lang] or T.en
  return l[tone] or l.casual
end

-- lang: a key of ns.MESSAGES, tone: a key of ns.TONES; anything else (an old or unknown setting)
-- writes English, in Casual.
function ns.thanks(lang, tone)
  if custom("thanks") then return pick(custom("thanks")) end
  local t = toned(ns.THANKS, lang, tone)
  return pick(t.thanks) .. pick(t.bye)
end

-- keys: one buff key, or a list of them (#39): "[A] and [B]", "[A], [B] and [C]", in our `multi`
-- lines, or in the player's own lines for `kind` (their {spell} then stands for every link).
-- Water and food (#47) get their own line after the buffs' one, never a player's own phrase:
-- "[Conjure Water] and [Conjure Food] (lvl 23)". `level`: mine, left out when nil.
local function joined(keys, lang)
  local links = {}
  for i, key in ipairs(keys) do links[i] = spellText(ns.BUFFS[key], lang) end
  local spells = links[#links]
  if #links > 1 then spells = table.concat(links, ", ", 1, #links - 1) .. ns.AND[lang] .. spells end
  return spells
end

function ns.message(kind, keys, lang, tone, class, level)
  if not ns.MESSAGES[lang] then lang = "en" end
  if type(keys) ~= "table" then keys = { keys } end
  local buffs, items = {}, {}
  for _, key in ipairs(keys) do table.insert(ns.BUFFS[key].item and items or buffs, key) end
  if items[2] == "water" then items[1], items[2] = "water", items[1] end -- the order the text says
  local m = toned(ns.MESSAGES, lang, tone)
  local itemLine = ""
  if #items > 0 then
    local part = #items > 1 and "items" or items[1]
    local what = joined(items, lang) .. (level and " (" .. ns.LEVEL[lang]:format(level) .. ")" or "")
    itemLine = pick(m[part]):format(what)
  end
  if #buffs == 0 then return pick(m.hello) .. itemLine .. pick(m.bye) end
  if itemLine ~= "" then itemLine = " " .. itemLine end
  local spells = joined(buffs, lang)
  local list = custom(kind)
  if list then -- a function replacement: a % in the link or the line can't break anything
    return (pick(list):gsub("{spell}", function() return spells end)) .. itemLine
  end
  local part = #buffs > 1 and "multi" or kind
  local own = m.byClass and m.byClass[class] -- the giver's class, in Role play
  local line = pick(own and own[part] or m[part])
  return pick(m.hello) .. line:format(spells) .. itemLine .. pick(m.bye)
end

-- Our own lines for one case, written the way the Phrases box takes them ({spell}, no hello/bye):
-- a starting point for the player.
function ns.builtIn(kind, lang, tone)
  if kind == "thanks" then return toned(ns.THANKS, lang, tone).thanks end
  local lines = {}
  for i, line in ipairs(toned(ns.MESSAGES, lang, tone)[kind]) do
    lines[i] = line:gsub("%%s", "{spell}"):gsub("%%%%", "%%")
  end
  return lines
end

-- Highest rank a player of this level can (probably) have; 0 if none yet.
function ns.rankAt(buff, level)
  local rank = 0
  for r, needed in ipairs(buff.ranks) do
    if level >= needed then rank = r end
  end
  return rank
end

-- Water or food (#47): the rank a mage of giverLevel can conjure that a player of `level` can use.
function ns.itemRank(item, giverLevel, level)
  local rank = ns.rankAt(item, giverLevel)
  while rank > 1 and item.uses[rank] > level do rank = rank - 1 end
  return rank
end

-- Rank of a buff from the value it actually gives (aura.points), or nil when the value fits no rank
-- (Forever changed the numbers: /bd log shows the real ones, #2). An exact value wins; otherwise the
-- highest rank the giver's talent can stretch that far. Where talented ranges overlap (Thorns), a
-- talented low rank can read as the next rank up.
function ns.rankOfValue(buff, value)
  for r, v in ipairs(buff.values) do
    if v == value then return r end
  end
  for r = #buff.values, 1, -1 do
    local v = buff.values[r]
    if value > v and value <= math.floor(v * (buff.talent or 1)) then return r end
  end
end
