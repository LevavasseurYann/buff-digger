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
-- a French client on an English-speaking realm must still write in English. The spell name comes from
-- the game when the client speaks the chosen language, from `en` above otherwise (a French client only
-- knows French names, and an English one cannot write German names).
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
    refresh = {
      "Salut ! Mon buff s'arrête bientôt, tu pourrais me le remettre ? (%s) Merci :)",
      "Hello ! %s va tomber sur moi, un petit rebuff stp ? Merci !",
      "Coucou, possible de me rafraîchir %s avant qu'il expire ? Merci d'avance !",
      "Salut ! Plus que quelques minutes de %s, tu me le remets stp ? Merci :)",
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
    refresh = {
      "Hi! My %s is about to wear off, could you refresh it? Thanks :)",
      "Hey! Mind topping up my %s before it drops? Much appreciated!",
      "Hello! Only a few minutes left on my %s, could I get a fresh one? Thank you!",
      "Hi! Could you refresh my %s please? It's running out. Thanks!",
    },
  },
  de = {
    -- Like French: the spell goes in brackets or after a colon, no article to agree with.
    new = {
      "Hallo! Hättest du einen Buff für mich? (%s) Danke :)",
      "Hey! Wenn du kurz Zeit hast: %s bitte. Vielen Dank!",
      "Hi! Könnte ich einen Buff bekommen? %s Danke dir!",
      "Grüß dich! Ein kleiner Buff für einen müden Reisenden? (%s) Danke :)",
      "Hallo! Über %s würde ich mich sehr freuen. Danke!",
    },
    replace = {
      "Hallo! Könntest du meinen Segen tauschen? (lieber %s) Danke :)",
      "Hey, danke für den Segen! Könntest du mir stattdessen %s geben? Das hilft mir mehr :)",
      "Hi! Kleine Bitte: könntest du meinen Segen gegen %s tauschen? Danke!",
    },
    upgrade = {
      "Hallo! Dein Buff ist einen Rang höher als meiner: %s bitte? Danke :)",
      "Hey! Dein Buff ist stärker als meiner (%s), magst du nachbuffen? Danke!",
      "Hi! Meiner hat nur einen niedrigen Rang. Nochmal buffen? (%s) Danke im Voraus!",
    },
    refresh = {
      "Hallo! Mein Buff läuft gleich aus, könntest du nachbuffen? (%s) Danke :)",
      "Hey! %s läuft bei mir bald ab, einmal erneuern bitte? Danke!",
      "Hi! Nur noch ein paar Minuten %s übrig, kurz nachbuffen bitte? Danke!",
    },
  },
  es = {
    new = {
      "¡Hola! ¿Me podrías dar un buff? (%s) ¡Gracias! :)",
      "¡Buenas! Si tienes un segundo: %s, por favor. ¡Muchas gracias!",
      "¡Hola! ¿Un buff de paso? %s ¡Gracias de antemano!",
      "¡Saludos! ¿Un buff para un viajero cansado? (%s) ¡Gracias!",
    },
    replace = {
      "¡Hola! ¿Podrías cambiar mi bendición? (mejor %s) ¡Gracias! :)",
      "¡Gracias por la bendición! ¿Me podrías poner %s en su lugar? Me ayuda más :)",
      "¡Buenas! Pequeño favor: ¿cambiarías mi bendición por %s? ¡Gracias!",
    },
    upgrade = {
      "¡Hola! ¿Me podrías volver a bufear? (%s, el tuyo es de rango más alto) ¡Gracias! :)",
      "¡Buenas! Tu buff es más fuerte que el mío (%s), ¿me lo renuevas? ¡Gracias!",
      "¡Hola! El mío es de rango bajo, ¿me pones el tuyo? (%s) ¡Gracias de antemano!",
    },
    refresh = {
      "¡Hola! Mi buff se acaba pronto, ¿me lo renuevas? (%s) ¡Gracias! :)",
      "¡Buenas! %s se me va a acabar, ¿un rebuff, por favor? ¡Gracias!",
      "¡Hola! Me quedan pocos minutos de %s, ¿me renuevas el buff? ¡Gracias!",
    },
  },
  it = {
    new = {
      "Ciao! Mi faresti un buff? (%s) Grazie :)",
      "Ehi! Se hai un attimo: %s, per favore. Grazie mille!",
      "Ciao! Un buff al volo? %s Grazie in anticipo!",
      "Salve, amico! Un buff per un viaggiatore stanco? (%s) Grazie!",
    },
    replace = {
      "Ciao! Potresti cambiare la mia benedizione? (meglio %s) Grazie :)",
      "Grazie per la benedizione! Potresti mettermi %s al suo posto? Mi aiuta di più :)",
      "Ehi, piccola richiesta: cambieresti la mia benedizione con %s? Grazie!",
    },
    upgrade = {
      "Ciao! Mi rifaresti il buff? (%s, il tuo è di rango più alto) Grazie :)",
      "Ehi! Il tuo buff è più forte del mio (%s), me lo rinnovi? Grazie!",
      "Ciao! Il mio è di rango basso, mi daresti il tuo? (%s) Grazie in anticipo!",
    },
    refresh = {
      "Ciao! Il mio buff sta per scadere, me lo rinnovi? (%s) Grazie :)",
      "Ehi! %s sta per finire, un rebuff per favore? Grazie!",
      "Ciao! Mi restano pochi minuti di %s, mi rinnovi il buff? Grazie!",
    },
  },
  pt = {
    new = {
      "Olá! Podias dar-me um buff? (%s) Obrigado :)",
      "Ei! Se tiveres um segundo: %s, por favor. Muito obrigado!",
      "Olá! Um buff de passagem? %s Obrigado desde já!",
      "Saudações! Um buff para um viajante cansado? (%s) Obrigado!",
    },
    replace = {
      "Olá! Podias trocar a minha bênção? (prefiro %s) Obrigado :)",
      "Obrigado pela bênção! Podias pôr-me %s no lugar dela? Ajuda-me mais :)",
      "Ei, pequeno pedido: trocavas a minha bênção por %s? Obrigado!",
    },
    upgrade = {
      "Olá! Podias voltar a dar-me o buff? (%s, o teu é de rank mais alto) Obrigado :)",
      "Ei! O teu buff é mais forte que o meu (%s), podes renová-lo? Obrigado!",
      "Olá! O meu é de rank baixo, davas-me o teu? (%s) Obrigado desde já!",
    },
    refresh = {
      "Olá! O meu buff está quase a acabar, podes renová-lo? (%s) Obrigado :)",
      "Ei! %s está a acabar, um rebuff por favor? Obrigado!",
      "Olá! Faltam poucos minutos de %s, renovas-me o buff? Obrigado!",
    },
  },
  ru = {
    new = {
      "Привет! Можно баф, пожалуйста? (%s) Спасибо :)",
      "Привет! Если есть секунда: %s, пожалуйста. Большое спасибо!",
      "Здравствуй! Не кинешь баф? %s Заранее спасибо!",
      "Приветствую, друг! Баф для уставшего путника? (%s) Спасибо!",
    },
    replace = {
      "Привет! Можешь поменять мне благословение? (лучше %s) Спасибо :)",
      "Спасибо за благословение! Можно вместо него %s? Мне так полезнее :)",
      "Привет, маленькая просьба: поменяешь благословение на %s? Спасибо!",
    },
    upgrade = {
      "Привет! Перебафнешь, пожалуйста? (%s, у тебя ранг выше) Спасибо :)",
      "Привет! Твой баф сильнее моего (%s), обновишь? Спасибо!",
      "Привет! У меня низкий ранг, можно твой? (%s) Заранее спасибо!",
    },
    refresh = {
      "Привет! Мой баф скоро спадёт, обновишь? (%s) Спасибо :)",
      "Привет! %s скоро закончится, перебафнешь, пожалуйста? Спасибо!",
      "Привет! %s осталось всего пару минут, обновишь? Спасибо!",
    },
  },
  pl = {
    new = {
      "Cześć! Dasz mi buffa? (%s) Dzięki :)",
      "Hej! Jeśli masz chwilkę: %s, proszę. Wielkie dzięki!",
      "Cześć! Buff w przelocie? %s Z góry dzięki!",
      "Witaj, przyjacielu! Buff dla zmęczonego wędrowca? (%s) Dzięki!",
    },
    replace = {
      "Cześć! Możesz zmienić moje błogosławieństwo? (wolę %s) Dzięki :)",
      "Dzięki za błogosławieństwo! Możesz dać mi zamiast niego %s? Bardziej mi pomoże :)",
      "Hej, mała prośba: zamienisz moje błogosławieństwo na %s? Dzięki!",
    },
    upgrade = {
      "Cześć! Zbuffujesz mnie jeszcze raz? (%s, twój ma wyższą rangę) Dzięki :)",
      "Hej! Twój buff jest mocniejszy niż mój (%s), odnowisz? Dzięki!",
      "Cześć! Mój ma niską rangę, dasz mi swój? (%s) Z góry dzięki!",
    },
    refresh = {
      "Cześć! Mój buff zaraz spadnie, odnowisz? (%s) Dzięki :)",
      "Hej! %s zaraz mi się skończy, rebuff proszę? Dzięki!",
      "Cześć! Kończy mi się %s, odnowisz buffa? Dzięki!",
    },
  },
}

-- Sent in the same channel as the request, once the buff lands.
ns.THANKS = {
  fr = {
    "Merci beaucoup ! :)",
    "Merci, t'es au top !",
    "Super, merci ! Bon jeu à toi !",
    "Merci ! Que la Lumière te garde :)",
    "Génial, merci beaucoup !",
    "Merci pour le buff, bonne aventure !",
  },
  en = {
    "Thanks a lot! :)",
    "Thank you, you're the best!",
    "Cheers, much appreciated!",
    "Thanks! Have a great one!",
    "Awesome, thank you!",
    "Thanks for the buff, good luck out there!",
  },
  de = { "Vielen Dank! :)", "Danke, du bist super!", "Danke schön, noch ein schönes Spiel!",
    "Danke für den Buff, viel Erfolg!", "Super, vielen Dank!" },
  es = { "¡Muchas gracias! :)", "¡Gracias, eres un crack!", "¡Genial, gracias!",
    "¡Gracias por el buff, buena suerte!", "¡Gracias! ¡Buena aventura!" },
  it = { "Grazie mille! :)", "Grazie, sei un grande!", "Fantastico, grazie!",
    "Grazie per il buff, buona avventura!", "Grazie! Buon gioco!" },
  pt = { "Muito obrigado! :)", "Obrigado, és o maior!", "Fixe, obrigado!",
    "Obrigado pelo buff, boa sorte!", "Obrigado! Boa aventura!" },
  ru = { "Большое спасибо! :)", "Спасибо огромное!", "Отлично, спасибо!",
    "Спасибо за баф, удачи!", "Спасибо! Хорошей игры!" },
  pl = { "Wielkie dzięki! :)", "Dzięki, jesteś super!", "Super, dzięki!",
    "Dzięki za buffa, powodzenia!", "Dzięki! Miłej gry!" },
}

-- Languages offered in the settings, in menu order, each under its own name.
ns.LANGUAGES = {
  { "en", "English" }, { "fr", "Français" }, { "de", "Deutsch" }, { "es", "Español" },
  { "it", "Italiano" }, { "pt", "Português" }, { "pl", "Polski" }, { "ru", "Русский" },
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
local function spellText(buff, lang)
  local client = GetLocale():sub(1, 2)
  local name = lang == client and C_Spell.GetSpellName(buff.id) or buff.en
  local link = C_Spell.GetSpellLink and C_Spell.GetSpellLink(buff.id)
  if not link then return name end
  return (link:gsub("%[.-%]", "[" .. name .. "]"))
end

-- lang: a key of ns.MESSAGES; anything else (an old or unknown setting) writes English.
function ns.thanks(lang)
  return pick(ns.THANKS[lang] or ns.THANKS.en)
end

function ns.message(kind, key, lang)
  if not ns.MESSAGES[lang] then lang = "en" end
  return pick(ns.MESSAGES[lang][kind]):format(spellText(ns.BUFFS[key], lang))
end

-- Highest rank a player of this level can (probably) have; 0 if none yet.
function ns.rankAt(buff, level)
  local rank = 0
  for r, needed in ipairs(buff.ranks) do
    if level >= needed then rank = r end
  end
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
