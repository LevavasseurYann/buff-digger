# Changelog

## Unreleased

- **Pick your tone.** Settings > Requests > *Tone*, under *Write to players in*: *Casual* (the default), *Polite* or *Role play*. Casual is chatty ("hey, mind sparing me [Power Word: Fortitude]?"), Polite says please and, in languages that have one, the formal you. It sets how your requests and thank-yous read, and *Try one* and *Start from Buff Digger's* follow it. Casual is what you get after updating, with no setup, but the phrases you knew changed a little: the more careful ones moved to Polite. Your own phrases still come first, whatever the tone.
- **Role play, in English and French.** "Well met! Might I beg [Power Word: Fortitude] of thee, friend?" A neutral register that fits any race, with a touch of the giver's class for a new buff: the Light for a paladin or a priest, nature for a druid, the arcane for a mage. The thank-yous play along too.
- **Polite in all eight languages.** German, Spanish, Italian, Portuguese, Russian and Polish get their own Polite phrases (Sie, usted, Lei, вы...). Role play is written in English and French only: in the other languages it sends the Polite phrases.
- **Settings in tabs.** The settings window no longer runs down your screen: it keeps one size, with tabs under it like the Character window. *General* (nameplates, windows, how to use), *Buffs* (your priorities, and when to ask again) and *Requests & Thanks* (language, tone, thanks, requests from other users). Every setting is still there and keeps its value; a few read clearer: *Icons on nameplates*, *Buffs line in players' tooltips*, *Wait before asking the same player again*, *Send a thank-you message*, *Thank line for buffs I didn't ask for*, *Buff requests in the right-click menu*.
- **Your key bindings, in sight.** *General* lists Buff Digger's key bindings and the key each one has (or *Not bound*), and a button takes you to the game's key bindings to set them.
- **No more "Safe travels!" twice.** A thank-you never ends with the same words as the request you sent that player, in every language and tone.

## 1.3.0

- **Thank the ones who buff you unasked.** A buff you didn't ask for, from a player Buff Digger can name, now turns their Get buffs line gold too: click *Thank* to whisper them and /thank. Their own recast, or a second buff within a minute of your thanks, doesn't bring the line back, and nothing comes from a buff landed mid-fight. Buffs from your own group don't count (their rebuffs would flood a dungeon), unless you asked for them. A gift's line shows the buff you got where a request shows the ready-check tick (hover it to read which), and the *Thank the last player who buffed me* key thanks the buff you asked for before any gift. Settings > Thanks > *Thank line for buffs I didn't ask for too* turns it off.
- **No more Thanks window.** The small window that popped up mid-screen is gone: a player to thank keeps their gold line in Get buffs (grey when out of sight) for 5 minutes, even with the Group section folded, and the *Thank the last player who buffed me* key still works, even with Get buffs closed or in a fight. A crowd of gifts never pushes out the buff you asked for: the oldest gift goes first.
- Reminder: Settings > Thanks > */thank emote when I click Thank* off sends only your message, for players who find the emote too much.

## 1.2.1

- **Your faction only.** Players of the other faction no longer get Buff Digger icons on their nameplate, a Get buffs line, the tooltip line or the right-click menu lines: they can't buff you anyway.

## 1.2.0

- **A quieter look for the windows.** Settings > Display > *Window style*: *Classic* keeps the game's frame, *Minimal* drops it for a flat, see-through dark background, like the borderless skins of Details! or Skada. A minimal window also fades while your mouse is elsewhere and comes back in full under it, so Get buffs can sit on screen all the time without getting in the way. Applies to Get buffs, Give buffs, Requests and Thanks; Thanks never fades, so a Thank line stays easy to spot.
- **Swap arrows you can see.** The small circling arrows on a paladin's blessing moved to the icon's bottom left corner: under the rank number they were hidden.

## 1.1.1

- **Friendly nameplates, your way.** Many of you hide friendly nameplates, and Buff Digger needs them to see anyone. The settings now offer a look for them: *Full* (the game's bars), *Name only* (just their name, in class colour, with Buff Digger's icon next to it) or *Icons only* (no bar, no name but on your target: only Buff Digger's icons float over players). Both use the game's own settings; *Off* is there too.
- **Colours instead of words.** Get buffs no longer writes *(higher rank)*, *(running out)*, *(swap)*, *(too far)* or *(out of sight)*: a green rank number is a higher rank than yours, an orange one means yours is about to wear off, red icons are out of range, and a grey name is a player who walked out of sight (Get buffs, Give buffs, Requests). A paladin's blessing you'd rather have wears small circling arrows: asking for it replaces the one he gave you (framed in gold). Hover an icon for the words.
- **Sort Get buffs and Give buffs your way.** A red arrow sits in the title bar, top left: click it and pick Best (the usual order), Level, Range, Missing / fading, Name or Class. Get buffs puts the highest levels first (better ranks), Give buffs the lowest (who needs it most); *Missing / fading* in Give buffs shows who lacks all your buffs first, then whose buff runs out soonest. Each window remembers its own choice, even after a /reload. Your group still comes first, and in Get buffs the players you asked (amber) or have to thank (gold) stay at the top of their section.

## 1.1.0

- **Thank lines for players who just walked off.** In a crowd, nameplates come and go every half second; a buff you asked for that landed right then had no giver and no Thank line. Buff Digger now asks the game who cast it.
- **Spirit for warriors.** Divine Spirit now counts as useful to a warrior (last pick, after Thorns): Spirit speeds up health regen out of combat, your only downtime.
- **Fort and Spirit in one whisper, your pick.** A click on a buff icon asks for that buff alone. To ask a player for several at once (a priest: Fort and Divine Spirit; a druid: Mark and Thorns), Ctrl+click their icons in Get buffs to tick them, then click the arrow at the end of the line: one message, every spell linked (Shift-click the arrow for /say). They all land on the same gold Thank line, one click thanks for the lot. Paladins: ticking a second blessing unticks the first, since they don't stack.
- **Each character asks on its own.** Asking someone with one character no longer stops your alt from asking them too; settings stay shared across the account. Restart the game after updating (a /reload is not enough).
- **Thanks are always your click.** The automatic thanks are gone, and so is the *Let me click Thank* box: Buff Digger never thanks anyone on its own. When a buff you asked for lands, that player's line turns gold (Get buffs, or the *Thanks* window); click *Thank* and your /thank and message go out at once, even in /say.
- **Only what you asked for.** A buff you didn't ask for no longer gets a gold Thank line, and the *Thank the last player who buffed me* key only thanks buffs you asked for. Thanking spontaneous buffs may come back once Buff Digger can tell them apart reliably.
- **Thank in /say.** Shift or Ctrl click a gold *Thank* line (Get buffs or the Thanks window) to thank in the other channel: /say instead of a whisper, or a whisper if you asked in /say. Like asking.
- **No stray thank-yous.** On a gold line in Get buffs, only the tick and *Thank* thank the player, and only the cross closes it: a click elsewhere on the line, say next to the cross, sends nothing.
- **No more Thank lines after a fight.** Players you had already thanked (group members mostly) could come back in gold on Get buffs after combat, as if they had just buffed you again. Fixed, for good this time: whenever the game hides your buffs (combat, dungeons, the moment a fight ends), Buff Digger keeps what it knew and, once it can read them again, only thanks a buff you actually asked for. A buff you asked for that lands mid-fight still gets its Thank line after the fight.
- **Buffs followed as they change.** Buff Digger now follows what the game says changed on you (a buff added, recast or gone) instead of re-reading all your buffs every time: less work in busy towns, and Ghost Wolf or a shapeshift no longer looks like a new buff, even right after you asked that player for a refresh.
- **Same first name, no mix-up.** In Give buffs, buffing "Raide Boule" no longer hides "Raide Tartempion" for a few seconds: each player is told apart by their whole name.
- **Buffs recognized right after login.** If the game hadn't loaded a spell's name yet the first time Buff Digger looked, that buff (rank, Thank line) stayed unknown until a /reload. It now looks again once the name is there.
- **Less work when nobody asks you anything.** With no request waiting and the Requests window closed, Buff Digger no longer scans the nameplates every second for it. `/bd perf` (debug mode) shows how often and how long the refreshes run.

## 1.0.0

- **Out of beta.** Buff Digger is now a regular release, so the CurseForge app offers it and keeps it up to date with its default settings, no need to opt in to betas. Same addon as 0.6.0-beta: see what each friendly player can probably give you, ask in one click or key, thank them when it lands, give your own buffs from Give buffs, and let two Buff Digger users talk to each other without a whisper.

## 0.6.0-beta

- **Follow your ask in Get buffs.** Click a buff to ask for it and that player's line stays on the list, at the top of its section, on a soft amber band with the ready check's question mark, until the buff lands or you could ask again (2 minutes by default). When their buff lands, the band flashes gold and shows the ready check tick and *Thank*: click the line to thank them, and it goes back to normal. The name keeps its class colour. A small cross at the end of the line drops it, sending nothing. A player to thank keeps their gold line even after walking out of sight, marked *(out of sight)*, until you thank them, close it with the cross, or 5 minutes pass. The *Thanks* window now only shows up when Get buffs can't show them: Get buffs closed, in combat, group folded.
- **Thank by hand is now the default**, for everyone, including if you installed 0.5.0-beta (the box was saved unticked without you choosing). Rather have it automatic? Untick *Let me click Thank* in the settings.
- **No more Thanks window out of nowhere.** A buff you didn't ask for no longer pops up the *Thanks* window: it shows gold on Get buffs if that player is there (click to thank), and the *Thank the last player who buffed me* key still works. The window is for the buffs you asked for.
- **The Thanks window stays where you put it.** Drag it by its title or any of its lines, even with the windows locked; it comes back there next time.
- **Thanks you click go out at once.** No more second or two of "typing" before the whisper when you click to thank. Automatic thanks keep that short pause.
- **Friendly nameplates: the red "off" is gone for real.** The settings, the login line and `/bd` read the setting Forever's client actually uses for friendly players' nameplates, so they no longer say *off* (in red) when you've turned them on, even with nobody around. *Turn on* and `/bd nameplates` switch on that setting too.

## 0.5.0-beta

- **Give buffs is on.** Pallies, priests, mages and druids: the Give buffs window (Shift+right click on the minimap button) lists who around lacks your buffs, laid out like Get buffs: one icon per buff they lack, in the order their class wants them. Click an icon to cast it on them (you get your previous target back), click the name to target them, hover an icon for the spell and its rank. Requests look the same: the requested buff's icon, click it to cast. The *Give my buff to the next player around* key works too (it casts when you release the key). Buff Digger users who ask you get one click in your Requests window instead of a whisper. Its settings are no longer greyed out as "coming soon". In a busy city, Give buffs and Requests scroll with the mouse wheel, like Get buffs.
- **Your group first.** In a party or a raid, Get buffs, Give buffs and Requests list your group under a *Group* header, then everyone else under *Around*. Members show up even without their nameplate (far away, or in a dungeon where friendly nameplates are locked); a player out of range shows *(too far)* and red buff icons, like an action button out of range, in Give buffs and Requests; in Get buffs, a member out of sight (another zone, the other end of the world) shows the same, and Buff Digger never asks them: it tells you instead of whispering them. The *Ask the best buff around me* key looks at your group too. Each header has a thin gold line, and the [-] on *Group* folds your group away in that window, remembered for next time ([+] brings it back). Out of a group, nothing changes.
- **Ask from the game's own menu.** Right click a player's portrait (target, party or raid frame): a *Buff Digger* section lists the buffs they can give you, one click asks, like the Get buffs menu. Option *Buff requests in the game's right-click menu* (on by default).
- **Thank by hand.** New option *Let me click Thank (no automatic thanks)*: Buff Digger no longer thanks anyone on its own. Whoever just buffed you, asked or not, shows up for two minutes in a small *Thanks* window instead: click their line to thank them (emote and message, as ticked, sent at once, even in /say), right-click to skip it. In a dungeon or raid, only the buffs you asked for show up. A key (Key Bindings > AddOns > Buff Digger) thanks the last one. A player who renews a buff they had already given you doesn't count, and one you just thanked doesn't come back for a minute.
- **Your own phrases.** In the settings, *My own phrases > Edit...*: write your own requests and thank-yous, one per line, for each case (missing buff, swap blessing, better rank, running out, thank-you), in any language. `{spell}` is where the spell link goes. Once you've written some for a case, Buff Digger uses yours instead of its own; empty the box to get them back. Lines that can't be sent (no `{spell}`, too long for the chat) are refused with the reason, *Start from Buff Digger's* copies ours into the box to edit, and *Try one* shows one in your chat without sending anything.
- **Requests that don't sound like a bot.** Each request is now put together from a greeting, the ask and a sign-off, with hundreds of combinations per language, and every variant comes out once before any comes back: ask ten players in a row and they all read differently. Thank-yous mix the same way.
- **See who's asking.** When another Buff Digger user asks you for a buff, a big pulsing icon of that buff shows above their nameplate, so you spot them in the crowd. Only you see it, and it goes away once they have the buff, after 90 seconds, or when you click their request. New option *Marker above players who request a buff* (on by default).
- **Target from Get buffs.** Click a player's name to target them (to find them in the crowd, see their buffs, invite them); it no longer asks for a buff, the icons do. New option *Get buffs: target the player I ask*: clicking a buff icon also targets them.
- **Thanks only for what you asked, from who you asked.** Buff Digger thanks a player only when the buff you asked them for comes from them. No more thank-you for eating or drinking, a buff nobody asked for, another buff than the one you asked for, your own buff, a buff from someone else, or a buff whose caster the game doesn't name (it used to guess the player you had asked, who sometimes gave nothing). If someone else beats them to it, the player you asked still gets thanked when their buff lands (as long as the game shows its time left).
- **No more "thanks" in the request.** The thank-you comes on its own once the buff lands, so asking no longer thanks you in advance.
- **Full names in the windows.** Get buffs, Give buffs, Requests and their tooltips show a player's first and last name ("Raide Boule"), not just the first name.
- **No more surprise whispers to Buff Digger users.** Asking another Buff Digger user sends only the silent request. If no buff comes after 30 s, Get buffs says *no answer* on their line: click one of their buffs to whisper them. In instances, and to players without the addon, the whisper goes out right away as before.
- **Shorter tooltips.** Icon tooltips in the windows and on nameplates no longer repeat the player's name (it's on the line already), and the right-click menus are titled *Buff Digger*.
- **No more gap before names.** The icon column is only as wide as the most buffs anyone on the list gives, and icons sit right against the name: a mage's or a priest's line no longer leaves two empty slots, and names stay lined up.
- **Friendly nameplates: no more false "off".** The settings and the login line no longer claim friendly nameplates are off while friendly players' plates are showing.
- **Requests stay where you put them.** Requests from other Buff Digger users no longer pop up mid-screen: they go to the Requests window (Ctrl+right click on the minimap button, or `/bd requests`), which moves, resizes and locks like Get buffs. A count on the minimap button says how many wait, and a sound of its own rings when one arrives (*Sound when a request arrives* turns it off).

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
