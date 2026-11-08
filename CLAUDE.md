# Buff Digger — addon WoW: Forever

Montre sur les barres de nom alliées quel buff un joueur peut probablement te donner, le demande
en un clic ou une touche (MP ou /s), remercie, et fait dialoguer deux Buff Digger entre eux.
Yann parle français ; **le code, l'interface et la page CurseForge sont en anglais**. Les messages
envoyés aux autres joueurs sont en anglais (réglage pour le français).

## Repères
- Jeu : WoW Forever, client 1.60.1, `## Interface: 16001`, Lua 5.1, **API Mainline (Midnight)**,
  pas Classic. Restrictions héritées de Midnight : pas de journal de combat, valeurs « secrètes »
  (`issecretvalue`), pas de messages d'addon en instance, /s hors instance = vrai clic obligatoire.
- `C_NamePlate.GetNamePlates()` ne liste pas les joueurs alliés dans Forever : on suit
  `NAME_PLATE_UNIT_ADDED/REMOVED` (`shownPlates`). Sans barres de nom alliées, l'addon ne voit
  personne (aucune autre API) → bouton « Turn on » et `/bd nameplates`.
- Fichiers, chargés dans cet ordre : `Locales.lua` (L passthrough, anglais seul), `Data.lua`
  (buffs, rangs Forever, préférences par classe, phrases), `BuffDigger.lua` (logique, arbre de
  décision, demandes, remerciements, barres de nom, `/bd`), `UI.lua` (minimap, réglages, Nearby,
  Give buffs, menu clic droit), `Comm.lua` (messages d'addon entre deux Buff Digger, fenêtre
  Requests). `Bindings.xml` : raccourcis.
- Le suivi est dans les issues GitHub (`gh issue list`) ; idée et paris : `docs/ideas/demande-de-buffs.md`.

## Vérifier
- Test sans le jeu (fausse API WoW + scénarios) : `uv run --no-project -q --with lupa python -I tests/run_smoke.py`.
  Il ne remplace pas le jeu : tout ce qui touche à Blizzard (secrets, blocages, barres de nom) se
  confirme en jeu, par Yann.
- Installer en jeu : voir README § Développer (copie vers `_forever_\Interface\AddOns\BuffDigger`).
  Nouveau fichier ou `.toc` modifié → relancer WoW (`/reload` ne suffit pas).
- Chaque lot de changements : relecture par un sous-agent `agent-skills:code-reviewer`, puis
  vérifier chaque constat avant de corriger.

## Publier
- Un tag `vX.Y.Z-alpha` (ou `-beta`, ou sans suffixe) poussé sur GitHub → le webhook CurseForge
  (projet 1792062) construit et publie le zip ; le workflow `release.yml` crée la Release GitHub.
  **Ne pas créer le secret `CF_API_KEY`** : ce serait un double envoi. Le tag est posé sur demande de Yann.
- Mettre à jour `CHANGELOG.md` (anglais, lu par CurseForge) avant le tag.
- Description CurseForge : `docs/curseforge-description.md`. L'éditeur CurseForge ne lit pas le
  Markdown : générer une page HTML (module `markdown`) que Yann copie-colle depuis son navigateur.
  Ton : joueur à joueur, jargon assumé (Fort, BoM, pally), pas d'emojis, comme Questie / Details!.
- Logo : `docs/logo.png` ; icône en jeu : `Media/icon.tga` (64×64, rond). Pas d'art Blizzard copié.
- Commits : messages en français, l'e-mail est l'adresse noreply GitHub (dépôt public).
