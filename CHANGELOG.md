# Changelog

## Unreleased

- **Give buffs is on.** Pallies, priests, mages and druids: the Give buffs window (Shift+right click on the minimap button) lists who around lacks your buffs, laid out like Get buffs: one icon per buff they lack, in the order their class wants them. Click an icon to cast it on them (you get your previous target back), click the name to target them, hover an icon for the spell, its rank and who it is for. Requests look the same: the requested buff's icon, click it to cast. The *Give my buff to the next player around* key works too (it casts when you release the key). Buff Digger users who ask you get one click in your Requests window instead of a whisper. Its settings are no longer greyed out as "coming soon". In a busy city, Give buffs and Requests scroll with the mouse wheel, like Get buffs.
- **Friendly nameplates: no more false "off".** The settings and the login line no longer claim friendly nameplates are off while friendly players' plates are showing.
- **Full names in the windows.** Get buffs, Give buffs, Requests and their tooltips show a player's first and last name ("Raide Boule"), not just the first name.
- **Thanks only for what you asked.** Buff Digger thanks a player only for the buff you asked them for. Eating, drinking, a buff nobody asked for or another buff than the one you asked for no longer thanks anyone. And a buff you asked to be recast right after it landed (a stronger rank) now gets its thanks: the recast used to go unnoticed for the first minute.
- **Requests stay where you put them.** Requests from other Buff Digger users no longer pop up mid-screen: they go to the Requests window (Ctrl+right click on the minimap button, or `/bd requests`), which moves, resizes and locks like Get buffs. A count on the minimap button says how many wait, and a sound of its own rings when one arrives (*Sound when a request arrives* turns it off).
- **No more surprise whispers to Buff Digger users.** Asking another Buff Digger user sends only the silent request. If no buff comes after 30 s, Get buffs says *no answer* on their line: click one of their buffs to whisper them. In instances, and to players without the addon, the whisper goes out right away as before.
- **See who's asking.** When another Buff Digger user asks you for a buff, a big pulsing icon of that buff shows above their nameplate, so you spot them in the crowd. Only you see it, and it goes away once they have the buff, after 90 seconds, or when you click their request. New option *Marker above players who request a buff* (on by default).
- **Target from Get buffs.** Click a player's name to target them (to find them in the crowd, see their buffs, invite them); it no longer asks for a buff, the icons do. New option *Get buffs: target the player I ask*: clicking a buff icon also targets them.

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
