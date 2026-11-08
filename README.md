# Buff Digger

Addon **World of Warcraft: Forever** : voir quels joueurs croisés peuvent probablement te buffer, et le leur demander en un clic. Fiche : `docs/ideas/demande-de-buffs.md`.

## Cadrage technique (recherches du 08/11/2026 — sources surtout communautaires, à revérifier en jeu)

### Le jeu
- 3ᵉ branche de WoW, à côté de Retail (Midnight) et Classic : Azeroth vanilla 1-60 refaite, niveau max 60 **définitif**, pas d'Outreterre, pas de vol.
- Nouveautés : race Skyborne, 3 spés par classe (27), double spé à 40, sorts appris chez le maître, maîtrise d'armes à monter,
  9 nouveaux donjons, 3 raids (Onyxia…) à partir du 09/12, BG Darkspear Island, zones Zephras Isle / Riverglades / Hyjal.
- Systèmes repris du Retail : collections, transmog, HV modernisé, Edit Mode, gestionnaire de CD, **damage meter intégré**, barres de nom.
- Systèmes propres : **Legacy** (arbres de talents spéciaux + défis, récompenses de compte), **Camping** (buffs, postes d'artisanat).
- Hardcore annoncé plus tard ; feuille de route jusqu'à l'été 2027.

### Un addon Forever
- Lua 5.1 + XML, pas de `require`/`io`/`os`. Un dossier `Interface/AddOns/<Nom>/` avec un `<Nom>.toc` du même nom.
- **`## Interface: 16001`** (Classic Era = 11509, Midnight = 120105). Le numéro monte à chaque patch : vérifier en jeu
  `/dump select(4, GetBuildInfo())`.
- Suffixes reconnus : `<Nom>_Forever.toc` ou `<Nom>_Camelot.toc` (Camelot = nom de code), sinon `_Mainline.toc` partagé avec Retail.
- **API = famille Mainline (Retail 12.x)**, pas Classic : les addons Classic Era ne tournent pas tels quels.
  Utiliser `C_Spell.GetSpellInfo`, `C_Item.GetItemInfo`, etc.
- **Restrictions héritées de Midnight** (Blizzard, Discord dev UI, 15/09/2026) :
  - plus de journal de combat (`COMBAT_LOG_EVENT_UNFILTERED`) ;
  - « valeurs secrètes » : PV/puissance %, incantations des autres, contenu des auras, noms/GUID de créatures en instance → lisibles
    par l'UI, pas par le code (`issecretvalue`) ;
  - en instance : chat entrant secret, **pas de messages addon vers les autres joueurs** ;
  - intention affichée : un addon ne doit pas automatiser une décision de combat.
  - **Reste libre** : tout ce qui est hors combat (quêtes, sacs, HV, carte, métiers, collections), le cosmétique (cadres, polices,
    barres), et les infos de son propre personnage.
- Itérer : `/reload` ; erreurs Lua visibles avec `/console scriptErrors 1` (ou BugSack).

### Publier
- Plateformes : **CurseForge**, **Wago Addons**, WoWInterface, GitHub Releases.
- Standard : **BigWigsMods/packager** en GitHub Action, déclenché par un tag `vX.Y.Z` ; IDs dans le `.toc`
  (`X-Curse-Project-ID`, `X-Wago-ID`, `X-WoWI-ID`), jetons en secrets du dépôt (`CF_API_KEY`, `WAGO_API_TOKEN`, `WOWI_API_TOKEN`).
- Non confirmé : que CurseForge/Wago acceptent déjà la version 16001 à l'upload → à tester au premier envoi (upload manuel en secours).

### Sources
- [Warcraft Wiki — TOC format](https://warcraft.wiki.gg/wiki/TOC_format) · [Create a WoW AddOn in 15 Minutes](https://warcraft.wiki.gg/wiki/Getting_started_with_writing_addons)
- [Warcraft Wiki — BigWigs Packager + GitHub Actions](https://warcraft.wiki.gg/wiki/Using_the_BigWigs_Packager_with_GitHub_Actions) · [docs.wago.io](https://docs.wago.io/)
- [Blizzard — Carve a New Path with WoW: Forever](https://news.blizzard.com/en-us/article/24302093/) · [Warcraft Tavern — Overview](https://www.warcrafttavern.com/forever/guides/overview/)
- [wowforeverguides — dev guide](https://wowforeverguides.com/addons/developers) · [wowforevertierlist — restrictions](https://wowforevertierlist.com/addons/restrictions)

## Développer

L'addon est à la racine du dépôt (format attendu par le packager). Pour l'essayer en jeu :

```sh
A="/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/BuffDigger"
mkdir -p "$A/Media" && cp *.lua *.toc Bindings.xml "$A/" && cp Media/* "$A/Media/"
```

Publier : pousser un tag `vX.Y.Z` (`-alpha` / `-beta` pour ces types) ; `.github/workflows/release.yml`
envoie le zip sur CurseForge et dans les GitHub Releases.
