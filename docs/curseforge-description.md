**Never run around begging for Fort again. Well... you still beg, but now you do it with style.**

You know the drill. You zone into Stormwind, three paladins and a priest run past, and you're spamming "BoM pls" in /say hoping somebody notices. Buff Digger puts a little icon next to every friendly player who can actually give you something you're missing. Click it and a polite whisper goes out, with the spell linked. When the buff lands, it says thanks for you.

*Alpha for WoW Forever. It works, but expect rough edges. Feedback very welcome.*

---

## How it works

Buff Digger looks at the friendly players around you, their class and their level, and works out the best buff each one can **probably** give you, given what you already have. One click asks for it. Nothing is ever sent without your click or key press.

---

## What it does

**Shows who can buff you**

- An icon next to friendly nameplates: the best buff that player can give *you*, based on your class.
- Full bright = the one you want most. Dimmed = still useful. No icon = they've got nothing for you.
- Their tooltip spells it out: *Can probably give you: Blessing of Might (rank 3, +55 attack power)*.

**Knows what you actually want**

- Warriors and rogues want Might before Wisdom. Casters want Wisdom and Arcane Intellect so they drink less. Hunters skip Might (melee AP only), and locks want Fort first for Life Tap.
- Don't agree? Reorder your class's list in the settings, or untick buffs you never want.
- A pally only keeps **one** blessing on you. Buff Digger won't ask them to swap Kings for Wisdom if you'd rather keep Kings.
- That level 15 priest's Fort is weak. Buff Digger reads the rank of the Fort you already have and will spot the level 45 priest running by.
- **Running out?** Buffs last an hour in Forever, and they always drop mid-quest. With 5 minutes left (your call, or never), the buff counts as missing again and the icon comes back.

**Asks for you, nicely**

- **Click** the icon to whisper. **Shift/Ctrl-click** to ask in /say instead.
- **Right-click** to pick the buff yourself. Collect every blessing if you want.
- **One key, no aiming:** bind *Ask the best buff around me* and it finds the right player for you. Handy when everyone's running around the bank.
- Spell links in every request, a bunch of different phrasings so you don't sound like a bot, in eight languages (English, French, German, Spanish, Italian, Portuguese, Polish, Russian).
- Won't nag. Same player, same buff? It waits (1 to 10 min, your call).
- Auto **/thank** whoever buffs you, plus a thank-you in the same channel you asked in. Manners matter.

**The Get buffs window**

- Everyone around who can buff you, and with what. One click asks.

**Stays out of your way**

- Out of combat only: everything hides when the pull starts.
- Quiet chat, and a minimap button that tells you what each click does.

---

## Getting started

1. Turn on **friendly nameplates**: one click in the Buff Digger settings, or `/bd nameplates`. That's how Buff Digger sees who's around (WoW gives addons no other list of nearby players). Your target and mouseover tooltip work without them.
2. Go somewhere busy. Icons show up next to people who can help.
3. Optional: **Key Bindings > AddOns > Buff Digger** and bind *Ask the best buff around me*.

Minimap button: left click = settings, right click = Get buffs.

**Commands:** `/bd best` (good for macros), `/bd ask` (your target), `/bd get`, `/bd config`, `/bd log` (buffs you received and what they really gave), `/bd` (diagnostic report, paste it with bug reports).

---

## Good to know

- It says **"probably"** for a reason. In Forever, spells are bought at the trainer, and no addon can see another player's spellbook. Buff Digger goes by class and level.
- **Open world and cities only.** In dungeons and raids, Blizzard locks friendly nameplates and addon chat.
- Ranks and values come from vanilla and Forever's trainer lists. If Forever changed a number, `/bd log` shows it in red: post it in the comments and it gets fixed.
- Getting Lua errors? Type `/console scriptErrors 1` once so you can see them, and post them in the comments along with the `/bd` report.

---

## Coming next

- **For pallies, priests, mages and druids: Give buffs.** A window listing who around lacks *your* buff, picked for *their* class, and one key to buff the next one. It's written, but Forever doesn't let an addon cast a spell yet, so it's switched off (greyed in the settings) until it works for real.
- **Buff Digger to Buff Digger requests:** a small pop-up instead of a whisper when the player you ask also runs Buff Digger. Same wall, same wait.
- Whatever you ask for in the comments.

Happy digging!
