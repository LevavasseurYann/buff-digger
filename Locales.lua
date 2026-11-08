-- Buff Digger: interface translations (#9).
-- The English text is the key: a string missing from a translation simply shows in English.
-- Messages sent to OTHER players are not here: they follow the "Messages to players in French"
-- setting (Data.lua, ns.MESSAGES), not the client language.

local _, ns = ...

local L = setmetatable({}, { __index = function(_, key) return key end })
ns.L = L

if GetLocale() ~= "frFR" then return end

-- Chat feedback
L["No player targeted."] = "Aucun joueur ciblé."
L["%s has nothing better for you right now."] = "%s n'a rien de mieux pour toi en ce moment."
L["Already asked %s %d s ago, give them a moment."] = "Déjà demandé à %s il y a %d s, laisse-lui un moment."
L["Nobody around can give you anything better right now."] = "Personne autour ne peut te donner mieux en ce moment."
L["No buff received from another player yet."] = "Aucun buff reçu d'un autre joueur pour l'instant."
L["The game's menu is not available."] = "Le menu du jeu n'est pas disponible."
L["%s is no longer around."] = "%s n'est plus dans les parages."

-- Tooltip
L["Can probably give you: %s (rank %d, +%s %s)"] = "Peut probablement te donner : %s (rang %d, +%s %s)"
L[" — replaces their blessing"] = " — remplace sa bénédiction"
L[" — higher rank than yours"] = " — rang plus haut que le tien"
L[" — your top pick"] = " — ton premier choix"

-- Stats (Data.lua)
L["attack power"] = "puissance d'attaque"
L["mana per 5 sec"] = "mana toutes les 5 s"
L["% all stats"] = "% à toutes les caractéristiques"
L["intellect"] = "intelligence"
L["stamina"] = "endurance"
L["spirit"] = "esprit"
L["shadow resistance"] = "résistance à l'Ombre"
L["armor (+ stats from rank 2)"] = "armure (+ caractéristiques dès le rang 2)"
L["damage to attackers"] = "dégâts aux attaquants"

-- Settings
L["Icon next to players' health bar"] = "Icône à côté de la barre de vie des joueurs"
L["Line in players' tooltip"] = "Ligne dans l'info-bulle des joueurs"
L["Nearby window (who can buff me)"] = "Fenêtre Autour (qui peut me buffer)"
L["Give buffs window (who lacks my buffs)"] = "Fenêtre Donner (à qui manquent mes buffs)"
L["Automatic /thank when someone buffs me"] = "/merci automatique quand on me buffe"
L["Ask in /say by default (not whisper)"] = "Demander en /dire par défaut (pas en MP)"
L["Messages to players in French"] = "Messages aux joueurs en français"
L["Debug messages in chat"] = "Messages de diagnostic dans le chat"
L["Wait before asking the same player again: %s"] = "Attendre avant de redemander au même joueur : %s"
L["%d min"] = "%d min"
L["My buff priorities (%s)"] = "Mes priorités de buffs (%s)"
L["Tick what you want, best first. Unticked = never asked."] = "Coche ce que tu veux, le meilleur en haut. Décoché = jamais demandé."
L["Reset"] = "Réinitialiser"
L["Right-click an icon or a Nearby line: pick the buff yourself."] = "Clic droit sur une icône ou une ligne Autour : choisir le buff toi-même."
L["Shift/Ctrl-click: /say instead of whisper (or the reverse)."] = "Maj/Ctrl+clic : /dire au lieu du MP (ou l'inverse)."
L["Minimap: right click = Nearby, Shift+right click = Give buffs."] = "Minimap : clic droit = Autour, Maj+clic droit = Donner."
L["Key Bindings > AddOns > Buff Digger: one key asks the best buff around you."] = "Raccourcis > AddOns > Buff Digger : une touche demande le meilleur buff autour de toi."
L["Friendly nameplates must be on."] = "Les barres de nom alliées doivent être affichées."

-- Windows
L["Buff Digger — Nearby"] = "Buff Digger — Autour"
L["Buff Digger — Give buffs"] = "Buff Digger — Donner"
L[" (swap)"] = " (échange)"
L[" (higher rank)"] = " (rang supérieur)"
L["Nobody around can buff you better right now.\n(Friendly nameplates on?)"] = "Personne autour ne peut te buffer mieux.\n(Barres de nom alliées affichées ?)"
L["You know no buff to give (paladin, priest, mage or druid)."] = "Tu ne connais aucun buff à donner (paladin, prêtre, mage ou druide)."
L["Everyone around has your buffs.\n(Friendly nameplates on?)"] = "Tout le monde autour a tes buffs.\n(Barres de nom alliées affichées ?)"
L["Ask %s for:"] = "Demander à %s :"
L[" (you have it)"] = " (tu l'as)"

-- Key bindings
L["Ask the best buff around me"] = "Demander le meilleur buff autour de moi"
L["Ask my target for a buff"] = "Demander un buff à ma cible"
L["Show / hide the Nearby window"] = "Afficher / masquer la fenêtre Autour"
L["Show / hide the Give buffs window"] = "Afficher / masquer la fenêtre Donner"
