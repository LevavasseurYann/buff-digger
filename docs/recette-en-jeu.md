# Recette en jeu — à faire par les testeurs

## Recette courte, à chaque version (10 min)

1. Copier l'addon **et** le journal (README § Développer). Relancer WoW.
2. `/console scriptErrors 1`, barres de nom alliées allumées (`/bd nameplates`), monde ouvert.
3. `/bdj clear`. Puis, hors combat, avec un buff sur soi : `/bdj probe`. Attendre « probe OK ».
4. Demander un buff à un joueur (clic sur l'icône). Quand il l'a donné : clic *Thank* sur sa ligne.
5. Faire deux combats, le second plus d'une minute après le clic *Thank*. Après chacun, aucune ligne
   *Thank* ne doit revenir (ni dans Get buffs, ni dans la fenêtre *Thanks*).
6. `/reload`, puis quitter le jeu.
7. Dire à Claude de lire le journal (`SavedVariables/BuffDiggerJournal.lua`). Résultat dans l'issue #1.

La suite de ce document est un inventaire : un test ne se joue que quand sa fonction change.

Ce que le test sans le jeu (`tests/run_smoke.py`) ne peut pas prouver : tout ce qui dépend de Blizzard
(valeurs secrètes, blocages, barres de nom, sorts lancés). Chaque test dit **qui** il faut (quelle
classe) et **ce qu'on doit voir**. Résultat à reporter dans l'issue #1 (une ligne par test : OK / KO
+ ce qu'on a vu, et le rapport `/bd` collé en entier).

**Avant de commencer** : `/console scriptErrors 1` (pour voir les erreurs Lua), barres de nom
alliées allumées (`/bd nameplates`), monde ouvert ou capitale (pas d'instance).

**Le journal de recette** (`dev/BuffDiggerJournal`, voir README § Développer) note ce qui se passe
pendant la partie. Une fois le jeu fermé, Claude lit `SavedVariables/BuffDiggerJournal.lua` et remplit
les tests qui ne demandent pas de regarder l'écran.

**`/bdj probe`** (journal installé, hors combat, avec n'importe quel buff sur soi, 2 s) : teste les API
d'auras avant, pendant et après la restriction de combat forcée (CVar `addonCombatRestrictionsForced`,
toujours remise à sa valeur d'origine). Puis `/reload` : le résultat est dans
`SavedVariables/BuffDiggerJournal.lua`, sous `BuffDiggerJournalDB.probe` (les événements bruts sous `.events`).

**L'aide-mémoire, c'est `/bd`** : chaque pari affiche `YES` / `NO` / `not seen yet`, et le premier
`YES` reste noté avec sa date (« confirmed 2026-11-08 ») d'une session à l'autre. Un testeur peut
jouer normalement puis coller `/bd` : la plupart des lignes se remplissent toutes seules.

## Demander (n'importe quelle classe, un buffeur croisé)

| # | Test | Ce qu'on doit voir | Ligne `/bd` |
|---|---|---|---|
| 1 | Clic gauche sur l'icône à côté d'une barre de nom | Le MP part, avec le lien du sort | Receive a click / Send a whisper |
| 2 | Le MP contient un lien dont le texte est le nom **anglais** (client français) | Le message apparaît bien comme envoyé ; sinon, noter le message d'erreur du serveur | Send a whisper |
| 3 | Maj+clic sur l'icône | La demande part en /dire | Talk in /say |
| 4 | Raccourcis > AddOns > Buff Digger > *Ask the best buff around me*, puis la touche | Le bon joueur est choisi, la demande part | Ask with a key binding |
| 5 | Se faire buffer après une demande, puis cliquer *Thank* sur sa ligne | Rien ne part tout seul ; sa ligne devient dorée (Get buffs, sinon fenêtre *Thanks*) ; le clic envoie `/merci` + message dans le canal de la demande | Know who put a buff on me / Send /thank |
| 42 | Sans rien demander, hors combat : manger, boire, prendre à une table de rafraîchissement, recevoir un buff spontané ; puis demander les Rois à un paladin qui me donne Puissance | Aucune ligne *Thank* ni fenêtre *Thanks* : seul le buff demandé, venant du joueur à qui je l'ai demandé, en donne une | — |
| 43 | Juste après avoir reçu un buff, demander à un joueur plus fort de le remettre (« Ton buff est plus costaud… ») ; il le relance dans la minute | Une ligne *Thank* pour lui ; clic = `/merci` **et** le message lui arrivent | Send /thank |
| 53 | Demander la Robustesse à un prêtre A ; un autre prêtre B la donne d'abord ; puis A la donne ; et, prêtre, se la lancer soi-même avec une demande ouverte | Ligne *Thank* pour A seulement, rien pour B ni pour soi. Puis `/bd` : noter la ligne *Buffs received with no identifiable giver* (si elle grimpe avec des inconnus, leurs lignes manquent) | Send /thank |
| 77 | En ville, demander un buff à un joueur dont la barre de nom clignote (foule), ou qui s'éloigne juste après avoir lancé le sort (#41) | Une ligne *Thank* à son nom complet « Prénom Nom », comme sur sa barre de nom (le nom vient de `GetPlayerInfoByGUID` : s'il arrive sans le nom de famille ou avec le royaume, aucune ligne : le noter, ce joueur en cible : `/dump GetPlayerInfoByGUID(UnitGUID("target"))`, 6ᵉ et 7ᵉ valeurs) | Know who put a buff on me |
| 19 | Avec un buff déjà sur soi, faire une demande puis se transformer (Loup fantôme, forme de druide) | Aucune ligne *Thank* | — |
| 20 | Réglages > *On nameplates* : essayer les 4 choix ; en *Every buff*, clic sur la 2e icône d'un paladin | Rien / petite icône Buff Digger / une icône / une par béné ; la demande porte sur l'icône cliquée ; survol = nom du sort et rang ; en foule, les icônes ne gênent pas le clic sur un voisin | Receive a click on that icon |
| 21 | Get buffs en ville (plus de 10 joueurs) | Plusieurs icônes par ligne, clic = ce buff, clic sur le nom = le cible (sans MP, Shift/Ctrl-clic aussi) ; la molette fait défiler, même le curseur sur une ligne ou une icône ; petites flèches haut/bas seulement quand il reste des joueurs de ce côté (clic = défile) ; le coin bas-droit agrandit la fenêtre (plus de lignes), taille et position gardées après /reload ; les flèches et le coin s'affichent bien (pas de carré vert) ; cadenas de l'en-tête : fermé = ni déplacement ni coin, ouvert = libre ; il s'affiche bien (sinon : `/dump GetFileIDFromPath("Interface\\Buttons\\LockButton-Locked-Up")`) | — |
| 22 | Get buffs, et barres de nom en *Every buff* | Toutes les icônes en pleine opacité, dans l'ordre de mes priorités ; buffs déjà sur soi en gris | — |
| 23 | Get buffs : clic sur un nom, hors instance puis en instance ; puis Réglages > *Get buffs: target the player I ask*, clic sur une icône | Le joueur devient ma cible, aucun MP ; avec l'option, l'icône le cible **et** envoie la demande ; clic droit = menu, sans ciblage ; aucune erreur « action bloquée » en entrant en combat fenêtre ouverte | — |
| 29 | Get buffs en ville, Réglages > *Get buffs: only those with something better* coché puis décoché | Coché : seuls restent les joueurs qui m'apportent un buff manquant, un rang plus fort ou un buff qui expire ; les autres disparaissent : ceux dont j'ai déjà tout, et ceux qui n'ont rien de ma liste de priorités (un mage pour un guerrier) (en moins d'une seconde). Personne d'utile : « Nobody around has anything better for you. » Décoché : ils reviennent, en fin de liste | — |
| 30 | Se faire bénir par un paladin, puis le regarder dans Get buffs et sur sa barre de nom (*Every buff*) | Sa bénédiction sur moi a un liseré doré (et est grise : je l'ai) ; survol = « They gave you this one. » ; survol d'une autre de ses bénédictions = « Replaces the Bénédiction des rois they gave you. » (nom du sort en doré) ; un autre paladin : pas de liseré ; le liseré disparaît quand la bénédiction tombe | — |

## Rang lu sur le buff (#8) et relevé des valeurs (#2) — n'importe quelle classe

| # | Test | Ce qu'on doit voir | Ligne `/bd` |
|---|---|---|---|
| 6 | Avoir un buff (Robustesse, Puissance…), faire `/reload`, puis `/bd spells` | `(on you, rank N)` avec un **chiffre**, pas `rank ?` | Read the value of my buffs |
| 7 | `/bd log` après une soirée à se faire buffer | Chaque buff reçu avec `+valeur = rank N`. **Une valeur en rouge « not in Data.lua »** : copier la ligne entière dans #2, c'est une correction de la table (ou un talent « Amélioré » du donneur : le préciser si on le sait) | — |
| 8 | Avec un buff de rang bas (donné par un bas niveau), croiser un buffeur plus haut | L'icône propose le rang supérieur (info-bulle « higher rank than yours ») | — |

## Redemander avant expiration — n'importe quelle classe

Réglage : *Ask again when a buff has less left than* (5 min par défaut ; Never pour couper).

| # | Test | Ce qu'on doit voir | Ligne `/bd` |
|---|---|---|---|
| 9 | Garder un buff jusqu'à ses 5 dernières minutes, près d'un joueur qui peut le donner | L'icône réapparaît (« yours is running out ») ; le message dit « about to wear off » | Read the time left on my buffs |
| 10 | Le joueur rafraîchit le buff | Une ligne *Thank* pour lui (une seule) | — |
| 11 | Un buffeur de **plus bas** niveau que celui qui m'a buffé | Ne propose **pas** de rafraîchir (il ferait baisser le rang) | — |

## Côté buffeur — paladin, prêtre, mage ou druide

| # | Test | Ce qu'on doit voir | Ligne `/bd` |
|---|---|---|---|
| 12 | Maj+clic droit sur le bouton de minimap : fenêtre Give buffs | Les joueurs proches sans mon buff ; **vide partout** = le jeu cache les buffs des autres (le signaler) | Read another player's buffs |
| 13 | Give buffs, comme Get buffs : une icône par buff qui lui manque (dans l'ordre de **sa** classe, 3 au plus ; paladin : rien si ma bénédiction est déjà sur lui), pas de nom de sort sur la ligne. Survol d'une icône, clic sur une icône, clic sur le nom | Info-bulle : nom du sort, mon rang, « Click: cast it. » (pas de nom : il est sur la ligne) ; clic sur l'icône : ce sort part sur ce joueur ; clic sur le nom : il devient ma cible, rien n'est lancé ; joueur trop loin : ligne et icônes grises, clic = « Too far » | Cast a buff from a Buff Digger click or key |
| 14 | Raccourcis > *Give my buff to the next player around*, puis presser la touche plusieurs fois en ville (WoW relancé : `Bindings.xml` a changé) | Le sort part au **relâchement** de la touche ; un joueur différent à chaque pression ; personne → « Nobody around lacks your buffs » | Cast a buff… |
| 15 | Même touche, cible bien plus basse que mon rang (ex. Robustesse rang 5 sur un niveau 10) | Le jeu baisse-t-il le rang tout seul, ou refuse-t-il le sort ? **Noter le message exact** | — |
| 16 | Avec un 2ᵉ joueur qui a Buff Digger : il me demande un buff | Un son (pas celui d'un MP), un chiffre sur le bouton de minimap, **aucune fenêtre ne surgit** ; Ctrl+clic droit sur le bouton : fenêtre Requests : son nom et l'icône du buff demandé (info-bulle : le sort), un clic sur l'icône lance le sort, un clic sur le nom le cible | — |
| 36 | Give buffs en ville (plus de lignes que la fenêtre) : laisser la souris sur la fenêtre 10 s (des joueurs passent), molette vers le bas, puis clic sur l'icône de la 1re et de la dernière ligne | Flèches haut/bas comme dans Get buffs ; le sort part sur le joueur **affiché** sur la ligne après défilement, pas sur celui d'avant ; pareil dans Requests avec beaucoup de demandes | Cast a buff… |

## Viser sans macro — avant de retirer `/target` + `/targetlasttarget` (bilan § 3)

Rien de tout ça n'a été vu marcher dans Forever (l'essai du 2026-11-08 date d'avant la correction
`AnyUp` : il ne compte pas). Hors combat, **une autre cible déjà choisie** avant chaque clic. Créer
le bouton de test (carré au centre de l'écran), puis lister les jetons des joueurs visibles :

```
/run B=CreateFrame("Button","BDT",UIParent,"SecureActionButtonTemplate") B:SetSize(48,48) B:SetPoint("CENTER") B:SetNormalTexture(134400) B:SetAttribute("useOnKeyDown",false) B:RegisterForClicks("AnyUp")
/run for i=1,40 do local n=UnitName("nameplate"..i) if n then print(i,n) end end
```

`N` = un numéro affiché, `Sort` = le nom exact de ton buff (langue du jeu), `Nom` = un joueur hors groupe.
Pour chaque test : le sort part-il ? sur qui ? ta cible a-t-elle changé ?

| # | Ligne à taper, puis clic sur le carré | Question |
|---|---|---|
| 31 | `/run B:SetAttribute("type","spell") B:SetAttribute("spell","Sort") B:SetAttribute("unit","nameplateN")` | Le sort part-il sur ce joueur, sans changer ma cible ? |
| 32 | `/run B:SetAttribute("spell",1243)` juste après le 31, même jeton (1243 = Robustesse rang 1, ou l'ID de ton buff) | L'ID du sort marche-t-il à la place du nom ? |
| 33 | `/run B:SetAttribute("type","target") B:SetAttribute("unit","nameplateN")` | Le joueur devient-il ma cible ? |
| 34 | `/run B:SetAttribute("type","spell") B:SetAttribute("spell","Sort") B:SetAttribute("unit","Nom")` | Un nom marche-t-il à la place du jeton ? |
| 35 | Taper dans le chat : `/cast [@Nom] Sort` | Une macro peut-elle viser un joueur hors groupe par son nom, sans le cibler ? |

## Noms à deux mots (Forever : prénom + nom, avec une espace)

Vu en jeu le 2026-11-09 : `UnitName` renvoie « Jean », « Dupont » (le nom de famille à la place
du royaume). L'addon affiche et retient « Jean Dupont », envoie les MP à « Jean-Dupont », et garde le
prénom seul pour `/target` et `/merci` (c'est ce qui a marché). Avec un joueur à prénom + nom :

| # | Test | Ce qu'on doit voir | Ligne `/bd` |
|---|---|---|---|
| 44 | Get buffs, Give buffs, Requests, info-bulles | Prénom **et** nom sur chaque ligne ; les info-bulles ne répètent pas le nom | — |
| 37 | Taper `/target Jean Dupont` dans le chat, puis `/target Jean-Dupont` | Noter lequel le cible (aucun, l'un, les deux) : si oui, les clics viseront le nom entier au lieu du prénom seul (deux « Jean » voisins ne seraient plus confondus) | — |
| 45 | Réglages > *Debug messages* coché, clic sur son icône dans Give buffs | Noter la ligne « Spell sent: … on X » : X = « Jean », « Jean-Dupont » ou « Jean Dupont » ? Puis il disparaît de Give buffs quelques secondes | Cast a buff… |
| 46 | Barres de nom alliées affichées (on voit les joueurs), taper `/run for _,c in ipairs({"nameplateShowFriends","nameplateShowFriendlyPlayers","nameplateShowAll","nameplateShowFriendlyNPCs"}) do print(c, C_CVar.GetCVar(c)) end` ; puis Réglages de Buff Digger | Noter les 4 valeurs ; Réglages : « Friendly nameplates: on », bouton *Turn on* grisé | — |
| 38 | Lui demander un buff (clic sur son icône, il n'a pas Buff Digger) | Le MP part, à lui seul (pas d'erreur « joueur introuvable ») | Send a whisper |
| 39 | Se faire buffer par lui après une demande, cliquer *Thank* | `/merci` vise bien lui, et le remerciement en MP lui arrive | Send /thank |
| 40 | S'il a Buff Digger : il me demande un buff | La demande arrive dans Requests à son nom entier, un clic sur l'icône le buffe ; l'étoile ★ Buff Digger apparaît après son nom dans Get buffs | — |
| 41 | Voit-on des noms avec un tiret (« Jean-Pierre Dupont ») ? | Noter oui / non : l'addon lit tout tiret venu du chat comme l'espace entre prénom et nom | — |

## Deux Buff Digger (2 testeurs, hors groupe, monde ouvert) — #10

| # | Test | Ce qu'on doit voir |
|---|---|---|
| 17 | A clique sur l'icône de B | Pas de MP ; demande ajoutée chez B (son, chiffre sur la minimap) ; étoile sur l'icône de B chez A |
| 18 | B ne répond pas (pas de buff) | **Aucun MP tout seul**. Au bout de 30 s, Get buffs chez A affiche « no answer: click a buff to whisper » sur la ligne de B ; un clic sur un buff de B envoie le MP, une seule fois |
| 24 | Chez B : déplacer, agrandir, verrouiller (cadenas) la fenêtre Requests, `/reload` | Même place, même taille ; le cadenas verrouille aussi Get buffs et Give buffs |
| 25 | Chez B : entrer en combat avec la fenêtre Requests ouverte | Elle disparaît, aucune erreur « action bloquée » ; elle revient après le combat. Une demande reçue en combat fait monter le chiffre de la minimap |
| 26 | Chez B : décocher *Sound when a request arrives* | Une demande arrive sans son |
| 27 | A et B en instance (donjon) : A clique sur l'icône de B | MP direct, comme avant (Blizzard bloque les messages d'addon en instance) |
| 28 | A demande un buff à B (barres de nom alliées allumées chez B) | Chez B, au-dessus de la barre de nom de A : grande icône du buff demandé, avec une lueur qui pulse, bien distincte des petites icônes ; un seul marqueur même si A redemande ; il disparaît quand A a le buff, au bout de 90 s, ou quand B clique sur la demande (rang supérieur ou rafraîchissement) ; A s'éloigne puis revient (barre de nom qui disparaît puis réapparaît) = le marqueur suit, jamais sur un autre joueur ; caché en combat ; Réglages > *Marker above players who request a buff* décoché = aucun marqueur ; le marqueur ne gêne pas le clic sur la barre de nom |

## Groupe et menu du jeu (#16, #17)

| # | Test | Ce qu'on doit voir |
|---|---|---|
| 47 | En groupe, en monde ouvert : Get buffs, Give buffs | En-tête « Group (n) » puis les membres, puis « Around » et les autres ; un membre n'apparaît qu'une fois (pas aussi dans Around) ; hors groupe, pas d'en-tête |
| 48 | Membre de groupe loin (hors des barres de nom) | Toujours listé ; dans Give buffs : grisé « (too far) », en fin de partie Group ; la touche *Give my buff…* le saute |
| 49 | En donjon (barres de nom alliées verrouillées) | Les membres apparaissent dans Get buffs et Give buffs ; un clic sur une icône de Give buffs buffe le bon membre ; si la partie Group reste vide, noter ce que dit `/bd` (identité lisible ?) |
| 50 | En raid | Tout le raid dans Group (seuls ceux qui ont quelque chose à donner ou recevoir) |
| 51 | Clic droit sur le portrait d'un paladin ciblé, puis sur un membre dans le cadre de groupe | En bas du menu : titre « Buff Digger » et ses bénédictions ; un clic envoie la demande ; aucune ligne sur soi-même ni sur un guerrier ; Réglages > *Buff requests in the game's right-click menu* décoché : plus rien, sans /reload ; aucune erreur « action bloquée » après usage, puis *Set Focus* et (chef de raid) promouvoir / exclure depuis ce même menu : marchent toujours, sans « action bloquée » |
| 52 | Get buffs avec seulement des mages / prêtres autour, puis avec un paladin ; Requests ; Give buffs en mage | Pas de vide entre les icônes et les noms ; les noms restent alignés entre eux ; avec un paladin, la colonne s'élargit et les icônes d'un mage restent collées à son nom ; rien ne bouge en faisant défiler |
| 17 | A clique sur l'icône de B | Pas de MP ; fenêtre Requests chez B ; étoile sur l'icône de B chez A |
| 18 | B ne répond pas (fenêtre Requests fermée, réglage décoché) | Un MP part chez A au bout d'une seconde et demie |

## Merci à la main (#21, #37) — n'importe quelle classe, un ou deux buffeurs croisés

Le merci ne part que d'un clic ou d'une touche, et seulement pour un buff demandé.

| # | Test | Ce qu'on doit voir |
|---|---|---|
| 54 | Demander un buff, le recevoir | Rien ne part tout seul ; une petite fenêtre *Thanks* apparaît avec le donneur (icône du buff, nom en couleur de classe) |
| 55 | Clic sur sa ligne (demande en MP, puis une autre en /dire) | `/merci` et le message partent **tout de suite**, sans autre clic, y compris en /dire ; la ligne disparaît, la fenêtre se cache si vide |
| 56 | *Retiré (#37) : un buff non demandé ne donne plus de ligne, voir 42* | — |
| 57 | Demander la Marque à un druide, qui pose Marque puis Épines | Une seule ligne, une icône (Marque) : Épines n'était pas demandée |
| 58 | Clic droit sur une ligne ; bouton fermer avec deux lignes ; attendre 5 min une ligne | Ligne retirée sans rien envoyer ; les lignes affichées vidées (un doré dans Get buffs reste) ; la ligne s'efface seule (au plus 5 s après) |
| 59 | Raccourcis > AddOns > Buff Digger > *Thank the last player who buffed me* | Fenêtre affichée : remercie sa ligne du haut ; sinon le dernier buff demandé reçu ; sans personne, « Nobody to thank right now. » |
| 60 | En donjon puis en monde ouvert, en groupe : buff de groupe (Intelligence des arcanes de groupe) puis un buff demandé | Seule la demande donne une ligne ; la fenêtre se déplace (même cadenas fermé) ; elle reste en combat |
## Mes propres phrases (#20) — n'importe quelle classe, un buffeur croisé

| # | Test | Ce qu'on doit voir |
|---|---|---|
| 61 | Réglages > *My own phrases > Edit...* ; dans *Missing buff*, écrire `Salut, un {spell} stp ?` puis *Try one (only you see it)* | La phrase s'affiche dans **mon** chat avec un lien cliquable (tooltip au survol) ; rien n'est envoyé |
| 62 | Demander un buff en MP, puis Maj+clic (en /dire) | Ma phrase part dans les deux cas, lien cliquable ; le receveur voit le tooltip |
| 63 | Taper 15 lignes dans la boîte | Le curseur reste visible en bas (la boîte défile toute seule), la molette défile ; clic dans la zone vide = la boîte prend le focus ; Échap une fois = quitte la saisie, deux fois = ferme la fenêtre |
| 64 | Taper `100% sûr {spell}`, puis `|cffff0000rouge {spell}`, puis une ligne de 250 caractères | La première part telle quelle, sans erreur Lua ; les deux autres sont refusées en rouge avec la raison (noter si un `|` tapé s'affiche doublé `||`) |
| 65 | Vider la boîte *Missing buff* ; `/reload` avec des phrases dans *Thank-you* | Retour aux phrases de Buff Digger ; après `/reload`, les phrases sont toujours là |
| 66 | Ouvrir *Edit...* et lire la fenêtre sans aide | Chaque onglet se comprend (la ligne jaune dit quand il sert), l'onglet choisi est en surbrillance (pas grisé), la boîte de saisie se voit, la ligne d'état dit si ce sont mes phrases ou celles de Buff Digger qui partent |
| 67 | Onglet vide > *Start from Buff Digger's* | La boîte se remplit des phrases de Buff Digger avec `{spell}`, modifiables ; le bouton se grise dès que la boîte n'est plus vide |

## Merci dans Get buffs, style ready check (#24)

| # | Test | Ce qu'on doit voir |
|---|---|---|
| 68 | Get buffs : clic sur une icône d'un buffeur, attendre son buff, cliquer la ligne | Attente : nom couleur de classe, bandeau ambre qui s'efface vers la droite, icône « ? » du ready check, croix. Buff reçu : bandeau doré qui clignote 2 fois, coche verte, « Thank » doré, nom jamais caché dessous. Pas de carré vert (sinon : `/dump GetFileIDFromPath("Interface\\RaidFrame\\ReadyCheck-Ready")`). Le titre de section (Group / Around) : ligne dorée, un peu plus vive qu'avant |

## Anti-relance par personnage (#38) — deux personnages du même compte

| # | Test | Ce qu'on doit voir |
|---|---|---|
| 69 | Après la mise à jour, **relancer WoW** (`.toc` modifié). Perso A : demander un buff à X. Se déconnecter, perso B : demander à X | B demande sans « Already asked ». Retour sur A (moins d'une heure) : X compte toujours comme demandé. `/dump BuffDiggerCharDB.asked` propre à chaque perso, `/dump BuffDiggerDB.asked` = nil |

## Suivi par `UNIT_AURA` updateInfo (#30) — un chaman, un prêtre croisé, le journal actif

| # | Test | Ce qu'on doit voir |
|---|---|---|
| 70 | Avoir la Robustesse d'un prêtre, lui demander une relance, puis Loup fantôme avant qu'il relance | Aucune ligne Thank. Journal : le retrait et l'ajout arrivent-ils dans **un seul** `UNIT_AURA` ou deux ? Fin (`expirationTime`) et durée lisibles sur l'aura ajoutée ? |
| 71 | Il relance ensuite la Robustesse demandée | Une ligne dorée Thank, une seule |
| 72 | En combat, il me donne le buff demandé ; attendre la fin du combat | La ligne Thank arrive à la fin du combat (ou dans les 30 s). Noter s'il était encore en vue à ce moment-là (sinon : pas de ligne, limite connue) |

## Coût des rafraîchissements en ville (#35)

| # | Test | Ce qu'on doit voir |
|---|---|---|
| 73 | `/run BuffDiggerDB.debug=true`, en capitale bondée, toutes fenêtres fermées. **Avant** (ancien comportement : une demande en attente) : `/bd selftest`, fermer Requests, `/bd perf` (remet à zéro), 60 s, `/bd perf`. **Après** (aucune demande, attendre 90 s qu'elle expire) : `/bd perf`, 60 s, `/bd perf`. Refaire avec Get buffs + Give buffs ouvertes | Noter dans l'issue #35 les ms/s de `refreshNow`, `refreshWindow`, `refreshIncoming` dans chaque cas ; `refreshIncoming` doit chuter dans « après » |

## Plusieurs buffs en une demande (#39) — un mage ou un démoniste, un prêtre 40+ croisé (ou deux testeurs)

| # | Test | Ce qu'on doit voir |
|---|---|---|
| 74 | Sans Robustesse ni Esprit divin, dans Get buffs : clic simple sur la Robustesse du prêtre. Puis (après le délai, ou un autre prêtre) Ctrl+clic sur Robustesse et Esprit divin, puis clic sur la flèche au bout de la ligne (#40) | Clic simple : une MP avec la Robustesse **seule**. Ctrl+clic : rien ne part, une coche sur chaque icône, la flèche apparaît. Flèche : **une seule** MP avec les deux liens cliquables (« [Robustesse] and [Esprit divin] »), la MP part bien (le serveur accepte deux liens) ; coches et flèche disparaissent. Maj+clic sur la flèche : en /s. Un paladin : cocher une 2ᵉ bénédiction décoche la 1ʳᵉ |
| 75 | Il lance la Robustesse seule | La ligne dorée Thank arrive. Il lance ensuite l'Esprit : toujours une seule ligne, deux icônes. Un clic *Thank* : un seul merci |
| 76 | Deux Buff Digger : le prêtre a la fenêtre Requests ouverte | Une ligne pour le mage, deux icônes ; chaque clic lance son sort, la ligne part quand les deux sont posés |

## Trier Get buffs et Give buffs (#42)

| # | Test | Ce qu'on doit voir |
|---|---|---|
| 77 | Get buffs ouverte : survoler puis cliquer la ligne « Sort: Best » en haut de la liste | La flèche ▾ s'affiche (petite flèche, pas un carré vide) ; l'infobulle dit le critère et son sens ; le menu montre 6 choix, Best coché. Choisir Level : les plus hauts niveaux d'abord, le groupe reste en tête, une ligne ambre/or reste première de sa section |
| 78 | Choisir Name dans Get buffs, Level dans Give buffs, puis `/reload` | Chaque fenêtre garde son tri, la ligne « Sort: » le dit |
| 79 | Prêtre (ou mage, druide), hors combat, en ville : Give buffs triée par Missing / fading | D'abord ceux qui n'ont aucun de mes buffs, puis celui dont mon buff expire le plus tôt. En combat : rien ne casse (fenêtre cachée), le tri revient après |
| 80 | Get buffs triée par Range, un paladin ou un prêtre proche et un autre loin (mais barre de nom visible) | Noter si le jeu distingue « à portée de sort » de « en vue » (sinon : seulement en vue / trop loin, limite connue) |
