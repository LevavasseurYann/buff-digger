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
--
-- A request is built from three parts: hello .. ask .. bye (hello ends with a space, bye starts with
-- one; "" means "none"). Each part is drawn from a shuffled bag: every line comes out once before any
-- comes back, so a dozen asks in a row never read like a bot. %s (only in the asks) is the spell link.
-- No "thanks" in a request: the thank-you comes on its own once the buff lands (ns.THANKS).
ns.MESSAGES = {
  fr = {
    -- The spell goes in brackets or after a colon: French needs ta/ton/tes depending on the spell.
    hello = { "Salut ! ", "Hello ! ", "Coucou ! ", "Yo ! ", "Bonjour ! ", "Hey ! ", "Salut toi ! ", "" },
    bye = { "", "", " :)", " :D", " Bonne aventure !", " Bon jeu !", " Bonne route !" },
    new = {
      "Tu pourrais me buff stp ? (%s)",
      "Un petit buff en passant ? %s",
      "Je peux te gratter un buff ? (%s)",
      "Si t'as deux secondes : %s stp.",
      "Tu me ferais l'honneur d'un buff ? %s",
      "Je ne dirais pas non à un buff : %s",
      "Possible d'avoir un buff stp ? (%s)",
      "Un buff pour un voyageur fatigué ? (%s)",
      "Tu me lancerais un buff stp ? %s",
      "Ça te dit de me buff ? (%s)",
    },
    replace = {
      "Tu pourrais changer ma bénédiction stp ? (%s plutôt)",
      "Tu pourrais me mettre une autre béné ? (%s)",
      "Petite requête : tu pourrais échanger ma bénédiction contre celle-ci ? %s",
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
      "Possible de me rafraîchir ce buff avant qu'il expire ? (%s)",
      "Plus que quelques minutes de buff, tu me le remets stp ? (%s)",
      "Mon buff est presque fini, un petit rebuff ? %s",
    },
  },
  en = {
    hello = { "Hi! ", "Hey! ", "Hello! ", "Hey there! ", "Heya! ", "Greetings! ", "Hi there! ", "Yo! ", "" },
    bye = { "", "", " :)", " :D", " Have a good one!", " Good luck out there!", " Safe travels!" },
    new = {
      "Could I get %s please?",
      "Mind sparing me %s?",
      "Any chance of %s?",
      "Would you be so kind as to toss me %s?",
      "If you've got a sec, %s would be amazing.",
      "%s for a weary traveler?",
      "I'd love %s if you don't mind.",
      "Mind hooking me up with %s?",
      "Could you throw %s my way?",
      "Would you mind casting %s on me?",
    },
    replace = {
      "Could you swap my blessing for %s please?",
      "Would you mind switching my blessing to %s?",
      "Your blessing is great, but %s would suit me even better.",
      "Could you make my blessing %s instead?",
      "Any chance of %s instead of this blessing? It helps me more.",
    },
    upgrade = {
      "Could I get your %s please? Yours is a higher rank.",
      "Your %s is stronger than mine, would you mind recasting it?",
      "Your rank of %s would be a real treat.",
      "Mine's a low rank, could I get your %s?",
      "Mind overwriting my %s? Yours is a higher rank.",
    },
    refresh = {
      "My %s is about to wear off, could you refresh it?",
      "Mind topping up my %s before it drops?",
      "Only a few minutes left on my %s, could I get a fresh one?",
      "Could you refresh my %s please? It's running out.",
      "My %s is fading, a quick recast?",
    },
  },
  de = {
    -- Like French: the spell goes in brackets or after a colon, no article to agree with.
    hello = { "Hallo! ", "Hey! ", "Hi! ", "Grüß dich! ", "Moin! ", "Servus! ", "" },
    bye = { "", "", " :)", " Viel Erfolg noch!", " Gute Reise!" },
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
  },
  es = {
    hello = { "¡Hola! ", "¡Buenas! ", "¡Hey! ", "¡Saludos! ", "" },
    bye = { "", "", " :)", " ¡Buena suerte!", " ¡Buen viaje!" },
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
  },
  it = {
    hello = { "Ciao! ", "Ehi! ", "Salve! ", "Ciao a te! ", "" },
    bye = { "", "", " :)", " Buona avventura!", " Buon gioco!" },
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
  },
  pt = { -- Brazilian: WoW's only Portuguese client is ptBR
    hello = { "Oi! ", "E aí! ", "Olá! ", "Saudações! ", "" },
    bye = { "", "", " :)", " Boa aventura!", " Bom jogo!" },
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
  },
  ru = {
    hello = { "Привет! ", "Здравствуй! ", "Хай! ", "Приветствую! ", "" },
    bye = { "", "", " :)", " Удачи!", " Хорошей игры!" },
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
  },
  pl = {
    hello = { "Cześć! ", "Hej! ", "Witaj! ", "Siema! ", "" },
    bye = { "", "", " :)", " Powodzenia!", " Miłej gry!" },
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
  },
}

-- Sent in the same channel as the request, once the buff lands: one of `thanks`, then one of `bye`
-- (same shuffled bags as requests).
ns.THANKS = {
  fr = {
    thanks = { "Merci !", "Merci beaucoup !", "Super, merci !", "Génial, merci !", "Merci pour le buff !",
      "Top, merci !", "Parfait, merci !", "Merci bien !" },
    bye = { "", " :)", " :D", " T'es au top !", " Bon jeu à toi !", " Bonne aventure !",
      " Que la Lumière te garde !", " Bonne route !" },
  },
  en = {
    thanks = { "Thanks!", "Thank you!", "Thanks a lot!", "Cheers!", "Much appreciated!", "Ty!",
      "Awesome, thanks!", "Thanks for the buff!", "Perfect, thank you!" },
    bye = { "", " :)", " :D", " You're the best!", " Have a great one!", " Good luck out there!",
      " Safe travels!" },
  },
  de = {
    thanks = { "Danke!", "Vielen Dank!", "Danke schön!", "Super, danke!", "Danke für den Buff!" },
    bye = { "", " :)", " Du bist super!", " Noch ein schönes Spiel!", " Viel Erfolg!" },
  },
  es = {
    thanks = { "¡Gracias!", "¡Muchas gracias!", "¡Genial, gracias!", "¡Gracias por el buff!" },
    bye = { "", " :)", " ¡Eres un crack!", " ¡Buena suerte!", " ¡Buena aventura!" },
  },
  it = {
    thanks = { "Grazie!", "Grazie mille!", "Fantastico, grazie!", "Grazie per il buff!" },
    bye = { "", " :)", " Sei un grande!", " Buona avventura!", " Buon gioco!" },
  },
  pt = {
    thanks = { "Valeu!", "Muito obrigado!", "Show, valeu!", "Obrigado pelo buff!" },
    bye = { "", " :)", " Você é demais!", " Boa sorte!", " Boa aventura!" },
  },
  ru = {
    thanks = { "Спасибо!", "Большое спасибо!", "Отлично, спасибо!", "Спасибо за баф!" },
    bye = { "", " :)", " Удачи!", " Хорошей игры!" },
  },
  pl = {
    thanks = { "Dzięki!", "Wielkie dzięki!", "Super, dzięki!", "Dzięki za buffa!" },
    bye = { "", " :)", " Jesteś super!", " Powodzenia!", " Miłej gry!" },
  },
}

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

-- lang: a key of ns.MESSAGES; anything else (an old or unknown setting) writes English.
function ns.thanks(lang)
  if custom("thanks") then return pick(custom("thanks")) end
  local t = ns.THANKS[lang] or ns.THANKS.en
  return pick(t.thanks) .. pick(t.bye)
end

function ns.message(kind, key, lang)
  if not ns.MESSAGES[lang] then lang = "en" end
  local list = custom(kind)
  if list then -- a function replacement: a % in the link or the line can't break anything
    return (pick(list):gsub("{spell}", function() return spellText(ns.BUFFS[key], lang) end))
  end
  local m = ns.MESSAGES[lang]
  return pick(m.hello) .. pick(m[kind]):format(spellText(ns.BUFFS[key], lang)) .. pick(m.bye)
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
