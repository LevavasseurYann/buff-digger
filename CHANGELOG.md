# Changelog

## Unreleased

- **Your own phrases.** Write your own requests and thank-yous, one per line, for each case (new buff, swap blessing, higher rank, running out, thank-you), in any language. `{spell}` is where the spell link goes. Once you've written some for a case, Buff Digger uses yours instead of its own; empty the box to get them back. Lines that can't be sent (no `{spell}`, too long for the chat) are refused with the reason.
- **Requests that don't sound like a bot.** Each request is now put together from a greeting, the ask and a sign-off, with hundreds of combinations per language, and every variant comes out once before any comes back: ask ten players in a row and they all read differently. Thank-yous mix the same way.
- **No more "thanks" in the request.** The thank-you comes on its own once the buff lands, so asking no longer thanks you in advance.
- **Thanks only for what you asked, from who you asked.** Buff Digger thanks a player only when the buff you asked them for comes from them. No more thank-you for eating or drinking, a buff nobody asked for, another buff than the one you asked for, your own buff, a buff from someone else, or a buff whose caster the game doesn't name (it used to guess the player you had asked, who sometimes gave nothing). If someone else beats them to it, the player you asked still gets thanked when their buff lands (as long as the game shows its time left).

## 0.4.3-beta

- **See which blessing a paladin gave you.** A paladin can keep only one blessing on you: ask for another and it replaces the first. The blessing a paladin put on you now has a gold frame, in Get buffs and on nameplates, and hovering their other blessings says which one it would replace.
- **Hide who has nothing for you.** New option *Get buffs: only those with something better*: players with nothing you want leave the Get buffs list: no buff from your priority list that you lack, no higher rank, nothing running out. A mage disappears for a warrior, a paladin whose blessings you all have too, so a busy city only shows who can actually help. Off by default.

## 0.4.2-beta

- **Clearer buff icons.** Every icon is fully visible now, in your priority order; buffs you already have are greyed out, like spells you can't use (Get buffs, and nameplates on *Every buff*).

## 0.4.1-alpha

- **Pick the buff yourself.** Get buffs now shows every buff a player can give, side by side (a paladin: Might, Kings, Wisdom); click one to ask for that one, click the name for Buff Digger's pick. Hover an icon for the spell and rank. Same on nameplates with *Every buff*.
- **Nameplates your way.** *On nameplates*: Nothing, Small icon (just "this one can buff you"), Best buff (as before) or Every buff.
- **Get buffs scrolls, resizes and locks.** In a crowd, the mouse wheel (or the small arrows) shows everyone; those who can give you something you lack come first. Drag the bottom-right corner to make it as big as you like; the padlock in its title bar keeps it in place.
- **No more thank-you for eating.** Only buffs Buff Digger knows (Fort, Kings, Mark...) get thanked: mage food, a refreshment table, heals over time and shields no longer send a /thank in dungeons.
- **No more thank-you for a shapeshift.** Going Ghost Wolf (or any form) right after asking could thank the player you asked although they gave nothing: a buff you already had looked brand new. Also, a giver whose class can't cast that buff is no longer thanked for it.

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
