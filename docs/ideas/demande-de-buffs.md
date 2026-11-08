# Demande de buffs — fiche d'idée (08/11/2026)

## Problème
Quand on croise des inconnus, voir d'un coup d'œil qui peut nous donner **notre meilleur buff manquant**,
le lui demander en un geste, ne jamais relancer quelqu'un dont le buff est encore actif, et remercier.

## Direction retenue
Pour Yann d'abord, monde ouvert + villes.

- **Cœur (1 + 7)** : icône sur la barre de nom des joueurs alliés (« peut probablement te donner X ») ; clic sur l'icône
  ou macro sur la cible → MP (ou /s, au choix) ; mémo de qui a posé quoi, qui empêche de redemander tant que le buff
  tient (frein anti-relance) ; `/thank` automatique.
- **Ordre de préférence** par classe et tranche de niveau (ex. guerrier 21 : Puissance > Rois > Sagesse inutile),
  avec des valeurs par défaut que le joueur peut modifier. Le choix est automatique (meilleur buff manquant) ou manuel.
- **Options activables** :
  - (2) ligne dans l'info-bulle et sur la cible ; c'est aussi le repli si la barre de nom n'est pas décorable ;
  - (4) fenêtre « Buffeurs proches » ;
  - (5) mode buffeur : voir qui, autour, n'a pas *mon* buff.
- **Plus tard (6)** : si le buffeur a aussi l'addon, demande silencieuse entre addons et bouton « Lancer » chez lui.
- **Dernier recours (3)** : macro `/buffme` seule, si rien d'autre n'est faisable.

## Paris à valider en jeu (addon de test `BuffDigger`)
- [x] La barre de nom d'un joueur allié se décore en monde ouvert (08/11). Reste à vérifier : un clic sur l'icône y est reçu.
- [x] La classe et le niveau d'un joueur croisé sont lisibles (08/11).
- [x] L'info-bulle d'un joueur accepte une ligne de plus (08/11).
- [x] Les anciens identifiants de sort existent dans Forever, sauf Salut (1038), Lumière (19977) et
      Sanctuaire (20911), absents (08/11).
- [ ] Le jeu dit qui a posé un buff sur moi, et `/thank` part tout seul.
- [ ] Les buffs **d'un autre** joueur sont lisibles (indispensable au mode buffeur, 5).
- [ ] Le MP part sur un clic ou une macro, et le /s sur un clic.
- [ ] Les buffs de Forever existent sous leurs anciens identifiants de sort (classes retravaillées). Sinon, relever
      les vrais identifiants en se faisant buffer.

Limite connue : on ne sait jamais si un joueur **a appris** un sort (Forever les fait acheter chez le maître) ni
quels talents il a pris. L'icône dit « probablement », jamais « peut ».

## Hors V1
- Donjons et raids : Blizzard y verrouille les barres de nom alliées et les messages envoyés par les addons.
- Demande en /s sans clic : bloqué par Blizzard hors instance depuis 2019.
- Panneau d'options graphique : des commandes `/` suffisent au premier utilisateur.
- Publication CurseForge/Wago : après usage personnel.

## Questions ouvertes
- Nom de l'addon.
- Message par défaut (« Salut ! Une Bénédiction de puissance stp ? Merci »).
- Délai entre deux demandes au même joueur.
