# Buff Digger

**Stop guessing who can buff you. Buff Digger shows it, and asks for you, politely.**

You're running through Stormwind and a paladin jogs past. Can they give you Blessing of Might? Do you already have a better one? Did you ask that same paladin two minutes ago? Buff Digger answers all of that at a glance, then sends a friendly request in one click or one key press.

> ⚠️ **Alpha.** Built for World of Warcraft: Forever (1.60.1). Some features still need testing in game (see *Known limitations*). Feedback in the comments is very welcome!

---

## ✨ Features

### 🔍 See who can buff you
- **An icon next to friendly players' health bars** shows the best buff that player can *probably* give you.
  - Full brightness: the buff you want most right now.
  - Dimmed: still useful, just not your top pick.
  - No icon: they have nothing better for you.
- **One line in the player's tooltip** spells it out: *"Can probably give you: Blessing of Might (rank 3, +55 attack power) — your top pick"*.

### 🧠 A smart choice, not just a list
For every player around you, Buff Digger works out what you should ask for:
1. **A buff you're missing**, following your class's priorities (Might before Wisdom for a warrior, Wisdom and Intellect first for a mage, no Might for a hunter's bow…).
2. **A better blessing.** A paladin only keeps one blessing on you, so Buff Digger asks them to *swap* only if the new one is worth more to you.
3. **A higher rank.** A level 40 priest's Fortitude beats the one a level 15 priest gave you.

Ranks and training levels follow WoW Forever's trainers. Kings is a trainer spell at level 20, and Salvation and Light are gone.

### 💬 Ask in one click, or one key
- **Click the icon**, or a line in the *Nearby* window, to send a whisper.
- **Shift or Ctrl + click** sends it in **/say** instead. The setting swaps which one is the default.
- **One key binding, no aiming:** *Ask the best buff around me* picks the best player nearby for you. Great when everyone is running around.
- Requests include a **clickable spell link**, so the other player sees the spell in their own language.
- **Lots of different phrasings**, picked at random, so you never sound like a bot.
- **Messages in English or French**, whatever your client language.
- **No nagging:** Buff Digger won't ask the same player again for 2 minutes.

### 🙏 Say thanks
- An **automatic /thank** goes to whoever buffs you. You can turn it off.

### 📋 Two handy windows
- **Nearby: who can buff me.** Every friendly player around you who can give you something, with the buff and its rank. One click asks.
- **Give buffs: who needs MY buffs.** For paladins, priests, mages and druids: players around you who are missing one of your buffs, chosen by *their* class (Might for the warrior, Wisdom for the mage). **One click casts it on them.**

### 🤫 Quiet and out of your way
- **Out of combat only.** Icons and windows hide when combat starts and come back afterwards.
- **Your chat stays clean.** Diagnostics only show when you ask for them.
- **A minimap button:**
  - left click opens the settings;
  - right click opens *Nearby*;
  - Shift + right click opens *Give buffs*;
  - drag it to move it.

---

## 🚀 Getting started

1. **Turn on friendly nameplates**: Options › Nameplates. Buff Digger finds the players around you through their nameplates.
2. Walk around a city or a busy zone, and icons appear next to players who can help.
3. *Optional:* set a key in **Key Bindings › AddOns › Buff Digger › Ask the best buff around me**.

### Commands
| Command | What it does |
|---|---|
| `/bd best` | Ask the best buff around you (handy in a macro) |
| `/bd ask` | Ask your current target |
| `/bd nearby` | Show / hide the Nearby window |
| `/bd give` | Show / hide the Give buffs window |
| `/bd config` | Open the settings |
| `/bd` | Diagnostic report (useful when reporting a bug) |

---

## ⚠️ Known limitations

- **"Probably", never "for sure."** In Forever, spells are bought from the trainer and the game doesn't tell other players which ones you know. Buff Digger guesses from class and level only.
- **Open world and cities only.** Inside dungeons and raids, Blizzard locks friendly nameplates and addon communication.
- **Friendly nameplates must be on**, or Buff Digger can't see anyone.
- **The Give buffs window** depends on the game letting addons read other players' buffs. If it doesn't, the window stays empty instead of guessing.

---

## 🗺️ Planned
- Pick the buff yourself instead of letting Buff Digger choose.
- Change your class's buff priorities in the settings.
- Interface in French and English.
- Silent requests between two Buff Digger users, with a "Cast" button on the buffer's side.

---

## 💡 Feedback
Found a bug, or a buff priority you disagree with? Leave a comment, and include the output of `/bd` if something looks off. Buff Digger is in its early days: every report helps!
