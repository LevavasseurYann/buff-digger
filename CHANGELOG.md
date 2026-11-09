# Changelog

## 0.4.1-alpha

- **No more thank-you for eating.** Only buffs Buff Digger knows (Fort, Kings, Mark...) get thanked: mage food, a refreshment table, heals over time and shields no longer send a /thank in dungeons.

## 0.4.0-alpha

- **Ask again before it runs out.** A buff with less than 5 minutes left (and a known rank) counts as missing: the icon comes back and the request says yours is about to wear off. Pick 2, 5 or 10 minutes, or never, in the settings. Whoever refreshes it gets thanked.
- **Ranks you already have are known.** Buff Digger reads what each buff actually gives you (+55 attack power...), so buffs you had before a /reload or from someone out of sight still get a higher-rank offer.
- **`/bd log` checks the numbers.** Each buff you receive is logged with what it really gives; a value Buff Digger doesn't know shows in red. Paste those lines in the comments: Forever may have changed a few.
- **Quieter chat.** Answers to your clicks ("already asked", "nothing better"...) show as the yellow text mid-screen and fade away. Background notes (thanks waiting, Blizzard blocks, fellow Buff Digger found) only show with *Debug messages* on. The chat keeps your `/bd` commands.
- The *Nearby* window is now called *Get buffs* (`/bd get`; `/bd nearby` still works).
- The thank-you whisper goes out a second or two after the buff lands, like someone typing. The /thank emote stays instant.
- **Give buffs and the Requests pop-up are switched off** (greyed "coming soon" in the settings): Forever doesn't let an addon cast a spell, whatever the click. Requests to Buff Digger users go out as a normal whisper or /say, right away.
- `/bd` remembers, with a date, every game feature it has seen working: paste it with bug reports.

## 0.3.0-alpha

- **Buff Digger talks to Buff Digger.** When the player you ask also has the addon, the request arrives silently: a small **Requests** window pops up on their side ("Yann wants Blessing of Might") and one click casts it. No whisper spam.
- If they don't answer within a second and a half, a normal whisper goes out instead.
- A small **star** marks players who have Buff Digger, on their icon and in the Nearby window.
- New setting: *Pop up requests from Buff Digger users* (on by default).
- `/bd selftest` sends yourself a request, to see the Requests window without a friend.
- Open world only: Blizzard blocks addon messages inside dungeons and raids.
- Minimap button tooltip lists what each click does.
- **Friendly nameplates in one click:** a button in the settings (and `/bd nameplates`). If they're off, Buff Digger says so once at login.

## 0.2.0-alpha

- **Pick the buff yourself:** right-click a nameplate icon or a Nearby line for a menu of every buff that player can give.
- **Your own priorities:** reorder your class's buffs in the settings, untick the ones you never want, reset anytime.
- **No-nag delay** is now a setting (1, 2, 5 or 10 min) and survives a /reload.
- **Thank-you messages:** once the buff lands, a thank-you goes out in the same channel as your request (lots of phrasings), on top of the /thank emote. Blizzard needs a real click for /say, so /say thanks go out with your next Buff Digger click or key.
- Thanks work even when the game can't tell who buffed you: Buff Digger matches the buff with the request you just made.
- **Cleaner settings window:** grouped sections, nothing overflows anymore.
- Smoother in crowded cities: icon updates are batched.

## 0.1.0-alpha

- First alpha: nameplate icons, smart buff requests (whisper or /say), Nearby and Give buffs windows, minimap settings.
