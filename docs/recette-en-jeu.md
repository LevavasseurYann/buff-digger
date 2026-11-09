# Recette en jeu — à faire par les testeurs

Ce que le test sans le jeu (`tests/run_smoke.py`) ne peut pas prouver : tout ce qui dépend de Blizzard
(valeurs secrètes, blocages, barres de nom, sorts lancés). Chaque test dit **qui** il faut (quelle
classe) et **ce qu'on doit voir**. Résultat à reporter dans l'issue #1 (une ligne par test : OK / KO
+ ce qu'on a vu, et le rapport `/bd` collé en entier).

**Avant de commencer** : `/console scriptErrors 1` (pour voir les erreurs Lua), barres de nom
alliées allumées (`/bd nameplates`), monde ouvert ou capitale (pas d'instance).

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
| 5 | Se faire buffer après une demande | `/merci` + message de remerciement dans le même canal | Know who put a buff on me / Automatic /thank |
| 19 | Avec un buff déjà sur soi, faire une demande puis se transformer (Loup fantôme, forme de druide) | Personne n'est remercié | — |
| 20 | Réglages > *On nameplates* : essayer les 4 choix ; en *Every buff*, clic sur la 2e icône d'un paladin | Rien / petite icône Buff Digger / une icône / une par béné ; la demande porte sur l'icône cliquée ; survol = nom du sort et rang ; en foule, les icônes ne gênent pas le clic sur un voisin | Receive a click on that icon |
| 21 | Get buffs en ville (plus de 10 joueurs) | Plusieurs icônes par ligne, clic = ce buff, clic sur le nom = le cible (sans MP, Shift/Ctrl-clic aussi) ; la molette fait défiler, même le curseur sur une ligne ou une icône ; petites flèches haut/bas seulement quand il reste des joueurs de ce côté (clic = défile) ; le coin bas-droit agrandit la fenêtre (plus de lignes), taille et position gardées après /reload ; les flèches et le coin s'affichent bien (pas de carré vert) ; cadenas de l'en-tête : fermé = ni déplacement ni coin, ouvert = libre ; il s'affiche bien (sinon : `/dump GetFileIDFromPath("Interface\\Buttons\\LockButton-Locked-Up")`) | — |
| 22 | Get buffs, et barres de nom en *Every buff* | Toutes les icônes en pleine opacité, dans l'ordre de mes priorités ; buffs déjà sur soi en gris | — |
| 23 | Get buffs : clic sur un nom, hors instance puis en instance ; puis Réglages > *Get buffs: target the player I ask*, clic sur une icône | Le joueur devient ma cible, aucun MP ; avec l'option, l'icône le cible **et** envoie la demande ; clic droit = menu, sans ciblage ; aucune erreur « action bloquée » en entrant en combat fenêtre ouverte | — |

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
| 10 | Le joueur rafraîchit le buff | Il est remercié (une seule fois) | — |
| 11 | Un buffeur de **plus bas** niveau que celui qui m'a buffé | Ne propose **pas** de rafraîchir (il ferait baisser le rang) | — |

## Côté buffeur — paladin, prêtre, mage ou druide

| # | Test | Ce qu'on doit voir | Ligne `/bd` |
|---|---|---|---|
| 12 | Maj+clic droit sur le bouton de minimap : fenêtre Give buffs | Les joueurs proches sans mon buff ; **vide partout** = le jeu cache les buffs des autres (le signaler) | Read another player's buffs |
| 13 | Clic sur une ligne Give buffs | Le sort part sur ce joueur | Cast a buff from a Buff Digger click or key |
| 14 | Raccourcis > *Give my buff to the next player around*, puis presser la touche plusieurs fois en ville (WoW relancé : `Bindings.xml` a changé) | Le sort part au **relâchement** de la touche ; un joueur différent à chaque pression ; personne → « Nobody around lacks your buffs » | Cast a buff… |
| 15 | Même touche, cible bien plus basse que mon rang (ex. Robustesse rang 5 sur un niveau 10) | Le jeu baisse-t-il le rang tout seul, ou refuse-t-il le sort ? **Noter le message exact** | — |
| 16 | Avec un 2ᵉ joueur qui a Buff Digger : il me demande un buff | Un son (pas celui d'un MP), un chiffre sur le bouton de minimap, **aucune fenêtre ne surgit** ; Ctrl+clic droit sur le bouton : fenêtre Requests, un clic lance le sort | — |

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
