# BuffDaddy (v0.2)

A WoW 1.12.1 (vanilla, SuperWoW-enabled) addon that watches your
solo/group/raid roster and tells you what important buffs are missing.
It never casts anything - purely a checker/reminder.

Hard dependencies: **ClassicAPI** (aura reading, `C_Timer`) and **SuperWoW**
(assumed present, not currently used directly by name but the environment
this addon is built for). No fallback code paths exist for missing ClassicAPI.

Read this file first when picking up work in a new conversation. New session
notes get added at the bottom, above "Known risk areas / things to verify".

---

## What it does, in one paragraph

Every 10 seconds by default (adjustable, or off entirely - see the minimap
dropdown), BuffDaddy scans whoever is relevant - just you if solo, your
party if grouped, your raid if in a raid - and checks a fixed list of buffs
against who's actually present. A small movable window always shows a
3-line summary. Left-click the minimap button to show/hide that window,
shift-left-click for an instant silent refresh, or alt-left-click for a
full report: a colored raid chat post listing what's missing, plus private
whispers to anyone missing a personal (self-only) buff.

---

## The window lines

A small light-blue **"BuffDaddy"** title sits inside the window, top-left
(`BuffDaddyWindowTitle` in `BuffDaddy.xml`), then:

```
Groupbuffs Y/X
Selfbuffs A/B
Buffs below D min C
```

- `X` = total expected group-buff-instances this check (every applicable
  non-personal buff x every player who needs it, given who's actually
  present/online). `Y` = how many of those are currently found. Line is
  **green** if `Y == X`, **red** if anything is missing.
- `B` = total expected personal (self-only) buff-instances. `A` = how many
  of those are currently found. Same green/red rule as line 1.
- `D` = the running-out threshold in minutes (`BuffDaddy.RUNNING_OUT_THRESHOLD`
  in `BuffDaddy.lua`, adjustable in-game via the minimap dropdown ->
  "Buffs-below threshold"). `C` = how many *found* buffs have less than
  `D` minutes left. **Green** if `C == 0`, **red** otherwise.

### Line 4+: optional "Display players" list

Below line 3, the window can optionally list exactly *who's* missing (or
running out), grouped by buff. The list itself is **always built** every
check now (no separate master switch anymore) - the only thing controlling
whether you actually see it is:

- **Window: expand playername display** - show/hide for the list, off by
  default, also available as a button next to Update/Print
  (`BuffDaddyExpandButton`).

When it's on, each missing or expiring buff gets its own block:

```
"Buffname"
-- Player1, Player2, Player3
-- Player4 (5 min)
```

- The buff name line is colored in that buff's class (the class that
  provides it, e.g. Priest for Power Word: Fortitude; for self buffs,
  the class of the player who needs it, e.g. Mage for Mage Armor).
- Each row starts with a white `--` marker, then up to 3 player names,
  comma-separated, each colored in their own class.
- If **Output: display expiring Buffs too** is also on, a player whose
  buff is found but running low gets a grey `" (X min)"` suffix after
  their name, where `X` is minutes left - only shown once they're under
  the expiring threshold, same threshold as line 3.
- Both group buffs and self (personal) buffs are listed this way, group
  buffs first.

The window automatically resizes (width and height) to fit this list,
and shrinks back down to its normal size when the list is hidden/empty -
see `BuffDaddy.Output.ResizeWindow` in `BuffDaddy_Output.lua`. Whatever
size you've manually set on `BuffDaddyWindow` in `BuffDaddy.xml` is
remembered as the "collapsed" size it always returns to (captured once
at login).

A buff only counts as "expiring" if its remaining time is a real positive
number under the threshold. If the client ever reports a nonsense negative
remaining time (seen after someone ported away - e.g. `-9000` even though
they actually had 40 minutes left, most likely a stale aura entry from
another region of memory), that buff is now treated as fine/found instead
of expiring - see `BuffDaddy_Check.lua`.

The window's background is fully transparent - only the border and the
colored text are visible.

---

## Manual adjustment guide (window size & text position)

Everything about the output window's *base* size and the position of its
text lines lives in **one place**: the `BuffDaddyWindow` block near the
top of `BuffDaddy.xml`. "Base" because as of the "Display players" list,
`BuffDaddy.Output.ResizeWindow` (in `BuffDaddy_Output.lua`) DOES grow the
window beyond this when that list is shown - see "Line 4+" above - but it
always shrinks back down to exactly the width/height you set here the
moment the list is off/hidden. So this is still the one place to control
the window's normal, collapsed appearance.

**Important client quirk, confirmed in-game via `/script` + `GetPoint()`
dumps:** this client does NOT apply `x`/`y` written as plain attributes on
`<Anchor>` (e.g. `<Anchor point="X" x="1" y="2"/>` silently becomes offset
`0,0` even though the file says otherwise) - it needs the offset as a
nested `<Offset x="1" y="2"/>` tag inside the `<Anchor>` instead. Every
anchor below already uses the working `<Offset>` form - keep using that
form for any future position edits in this file, not the attribute form.
(`<Size x="..." y="..."/>` attributes on the Frame itself are unaffected
and work fine as plain attributes - it's only `<Anchor>` that needs this.)

| To change...                          | Edit this line in `BuffDaddy.xml`                                              | What the numbers mean |
|----------------------------------------|----------------------------------------------------------------------------------|------------------------|
| Window width/height                   | `<Size x="170" y="55"/>`                                                        | `x` = width in pixels, `y` = height in pixels. This is the **collapsed** size - grows automatically when the Display players list is shown, see "Line 4+" above. |
| Where the window sits on screen        | `<Anchor point="CENTER" x="0" y="200"/>`                                          | `x`/`y` = offset in pixels from the screen's center point. Positive `y` = higher up the screen. (This one anchor is on the window itself, not a text line, and screen-position anchors like this one have tested fine as plain attributes - only the text lines below needed the `<Offset>` fix.) |
| Title text position                    | `BuffDaddyWindowTitle`'s `<Offset x="14" y="-12"/>`                              | `x`/`y` = offset in pixels from the window's own top-left corner. Positive `x` = further right, more negative `y` = further down. |
| Line 1 ("Groupbuffs") position          | `BuffDaddyWindowLine1`'s `<Offset x="14" y="-34"/>`                              | Same rule - offset from the window's top-left corner. |
| Line 2 ("Selfbuffs") position          | `BuffDaddyWindowLine2`'s `<Offset x="14" y="-54"/>`                              | Same rule. |
| Line 3 ("Buffs below...") position     | `BuffDaddyWindowLine3`'s `<Offset x="14" y="-74"/>`                              | Same rule. |
| Line 4+ ("Display players" list) position | `BuffDaddyWindowPlayerList`'s `<Offset x="5" y="-41"/>`                        | Same rule. Holds the whole player list as one block of text with line breaks built in - see "Line 4+" above. |

Each line's anchor is independent - it's measured from the window's
corner, not from the line above it. So moving Line 2 can never drag Line 3
out of place, and you can change any one line without needing to touch
the others.

The title's text/color are set from `BuffDaddyWindow`'s own `OnLoad` (not
the title FontString's own `OnLoad`) - see "Known risk areas" #6 for why.
If you ever add a 4th line or another label, give it code that runs on
load, remember it needs to live on a real `Frame`'s `OnLoad`, not a
`FontString`'s.

After editing, save the file and **fully close and relaunch the WoW
client** (not just `/reload`) - addon file edits made while WoW is
running aren't always picked up until a real restart.

If a value still doesn't seem to take effect after a full relaunch and a
correct-looking edit, don't assume the number is wrong - get real data
first. In-game, type (no addon required):
```
/script local p,rt,rp,x,y=BuffDaddyWindowLine1:GetPoint();DEFAULT_CHAT_FRAME:AddMessage(tostring(p)..","..tostring(rt and rt:GetName())..","..tostring(rp)..","..tostring(x)..","..tostring(y))
```
(swap `BuffDaddyWindowLine1` for whichever FontString you're checking) -
this prints the position the client is *actually* using, straight from
its own memory, which is how the `<Offset>` quirk above was found in the
first place.

---

## Roster rules

- Solo -> just you.
- In a group (not raid) -> you + up to 4 party members.
- In a raid -> you + up to 39 raid members.
- Only classes actually present **and online** are checked. If every member
  of a class is offline, that class is treated as not present at all
  (its buffs are skipped, and it can't provide buffs to others).
- **Paladins are fully skipped** - not checked as players, don't provide
  buffs. See `BuffDaddy_SkippedClasses` in `BuffDaddy_Definitions.lua`.
- It doesn't matter what class *you* are - e.g. a Warrior raid leader still
  gets reminded which Mage is missing Mage Armor, even though Warriors have
  nothing of their own to check.
- Range/visibility doesn't matter - buffs are read regardless of distance.

---

## Buff definitions (`BuffDaddy_Definitions.lua`)

This is the file to edit when buff names change or a new buff needs adding.
Each entry in `BuffDaddy_Definitions` is a table:

| Field          | Meaning |
|----------------|---------|
| `name`         | Display name used in whispers / raid chat. |
| `buffNames`    | List of exact aura names to match (any one = found). Buffs that share names across sources (e.g. multiple ranks, or unrelated buffs with the same name) are handled with `tooltipCheck`. |
| `tooltipCheck` | (optional) Required substring in the aura's tooltip body text, used only when the name alone is ambiguous. Whitespace is collapsed before matching, so stray double-spaces don't break it. |
| `needsClass`   | The class that must be present (online, non-Paladin) for this buff to be checked at all. |
| `appliesTo`    | Who needs it: `"everyone"`, `"manaUsers"`, `"selfMage"`/`"selfHunter"`/`"selfWarlock"`/`"selfPriest"`/`"selfShaman"`, or `"druids"` (only paired with `groupCheck`). |
| `personal`     | `true` = whispered when missing, never shown in the raid chat "Missing:" list. `false` = opposite. |
| `optional`     | `true` = only checked when turned on via the minimap left-click dropdown. Always starts **off** on login (not saved). |
| `groupCheck`   | `true` = special "one person covers everyone" handling (currently only Emerald Blessing). |

Mana-user classes (`BuffDaddy_ManaUserClasses`): Mage, Priest, Warlock,
Shaman, Druid, Hunter. Non-mana: Warrior, Rogue. Paladins are excluded
entirely regardless of mana.

### Emerald Blessing - special case

- Disabled (default) -> completely ignored, not counted anywhere.
- Enabled + at least one Druid has it -> treated as satisfied for
  **everyone online**, contributes to X and Y equally, no "Missing:" line.
- Enabled + no Druid has it -> counts as 1 missing instance **per online
  roster member** (e.g. 30 online = 30 missing), gets a normal
  "Missing: Emerald Blessing from Druid on 30 Players" line, **plus** an
  extra line: `Raid is missing Emerald Blessing!` (green).
- Only checked at all if a Druid is present, same as any other buff.

---

## Output formatting

Every raid-chat line and every whisper starts with a **black `>>> `**
prefix, so people don't mistake it for a normal chat message.

**Raid chat report** (sent to RAID if in a raid, PARTY if grouped, or
printed to your own chat frame if solo):

1. `>>> ` (black) `BUFFCHECK` (light blue) `Y/X Groupbuffs` (green/red)
   ` | ` `A/B Selfbuffs` (green/red). If **Output: display expiring Buffs
   too** is on, a third segment is appended: ` | ` `C Buffs below D min`
   (green/red). If that toggle is off, this segment is left out entirely
   (rather than always showing a misleading "0 Buffs below"). This line's
   code is deliberately built with the fewest possible color-code bytes
   (no redundant color resets, no separate " - " segment) - see the
   comment above `BuildSummaryLine` in `BuffDaddy_Output.lua` and "Known
   risk areas" #8 for why.
2. One line per missing non-personal buff: `Missing` (white) ` "<name>"`
   (name in grey) ` from <Class>` (white) ` on <q> Players` (or, with
   Detailed output on, the actual player names instead - see below).
   - Immediately followed by the green `Raid is missing Emerald Blessing!`
     line, only when that specific buff is the one missing.
3. If any personal buffs are missing, one extra line flagging that
   whispers went out.

**Whispers** (one per missing personal buff per player, sent every time,
no spam limiting for now): `>>> ` (black) `You are ` (white) `missing`
(red) ` your ` (white) `<name>` (in the recipient's own class color) `!`
(white)

---

## Minimap button

- **Left-click**: shows/hides the small output window.
- **Shift-left-click**: instant check, updates the small window only. No
  chat, no whispers.
- **Alt-left-click**: instant check first (so data is always fresh), then
  posts the raid chat report and sends whispers - same as clicking the
  optional Print button (see below).
- **Right-click**: opens the options dropdown, which has two sections:

  **Window/behavior options** (top of the dropdown, saved between
  sessions - see "Settings persistence" below), grouped by prefix -
  "Window: ..." entries first, then "Output: ..." entries:
  - **Window: Clickthrough** - when on, the window ignores mouse
    clicks entirely (they pass through to whatever is behind it); it also
    can't be dragged while this is on. (There is no separate "Lock"
    option - Clickthrough already covers not being able to drag it.)
  - **Window: expand playername display** - show/hide (off by default) for
    the window's line 4+ per-buff missing/expiring player list (see
    "Line 4+" earlier in this file), which is always built regardless of
    this setting. Mirrored by the **Expand button**
    (`BuffDaddyExpandButton`), shown/hidden by the same "Window: show
    quick access buttons" toggle as Update/Print (see below). Both the
    dropdown entry and the button call the same
    `BuffDaddy.Minimap.ToggleExpand()`.
  - **Window: show quick access buttons** - shows/hides small "Print",
    "Update" and "Expand" buttons INSIDE the output window's top-left
    corner, left-to-right: Expand, Update, Print
    (`BuffDaddyExpandButton`/`BuffDaddyUpdateButton`/`BuffDaddyPrintButton`
    in `BuffDaddy.xml`, all three toggled together by
    `BuffDaddy.Output.SetPrintButtonShown`). They sit on top of the
    title/line text when shown - that's expected, they're meant to be
    toggled on briefly, not left on. "Print" does the
    same thing as Alt-left-click (instant check + raid report + whispers).
    "Update" is the quiet version - same as Shift-left-click, refreshes
    the window only, no chat/whispers. "Expand" shows/hides the player
    list, same as the "Window: expand playername display" toggle above.
  - **Window: Autoupdate intervall** (submenu, indented under the Window
    section) - how often the window silently
    auto-refreshes: 1/2/5/10 seconds, or "Never" to turn auto-refresh off.
  - **Output: Detailed (Playernames)** - when on, every "Missing:" line in the raid chat
    report lists the actual missing players by name (each in their own
    class color) instead of just a count. Capped at 5 names per line -
    past that it shows "(and more...!)" in red instead of listing
    everyone.
  - **Output: display expiring Buffs too** - when OFF (default), remaining buff duration is
    ignored entirely - a buff only counts as found or missing, running-out
    time plays no part anywhere, and the raid chat summary line's
    " | C Buffs below D min" segment is left out entirely. When ON, buffs
    with less than the expiring threshold left count towards window line 3
    and that summary segment (which now appears). If **Output: Detailed
    (Playernames)** is also on, expiring players get folded straight into
    that buff's "Missing:" line instead of a separate list - their name
    gets a white " (expiring)" tag after it. With Detailed output off,
    expiring buffs only ever show up as the plain count on window line 3 -
    no names. Also feeds the window's playername display list (independent
    of Detailed output) - see the two "Window: ...playername display"
    options above.
  - **Output: expiring buff remaining time threshhold** (submenu,
    indented under the Output section) - the running-out threshold shown
    on window line 3: 5/8/10/12/15 minutes.

  A divider line separates the above from:

  **Optional buffs** - a short explanation, plus the optional buffs list -
  Priest entries first, then Druid entries, each colored in its class
  color (no more "(Priest)"/"(Druid)" text suffix - the color alone tells
  you which class, see `dropdownClass` in `BuffDaddy_Definitions.lua`):
  - **Shadow Protection**, **Emerald Blessing** - simple on/off ticks,
    same as before.
  - **Inner Fire**, **Enlighten**, **Thorns** - instead of a tick, these
    open a submenu listing individual online raid/group members (Priests
    for Inner Fire/Enlighten; Warriors + Druids for Thorns) that you tick
    by name. Only ticked players are ever checked for that buff. If
    nobody online matches, the submenu shows "No priest found" / "No
    druid found" instead of names. This (and the Update interval /
    Buffs-below threshold submenus) is forced to open on the **left**
    side of the dropdown - see the `DropDownList2` hook near the top of
    `BuffDaddy_Minimap.lua`.
  Every tick here (including per-player ticks in the Inner Fire/Enlighten/
  Thorns submenus) is saved between sessions too - see "Settings
  persistence" below. Enlighten's real aura name is "Enlighten Dummy" -
  the display name "Enlighten" is just cosmetic (see `buffNames` vs
  `name` in `BuffDaddy_Definitions.lua`).

Hovering the minimap button (without clicking) shows a tooltip that spells
out all four click behaviors above.

---

## Settings persistence

Every option in the dropdown - both the Window/Output toggles and the
Optional buffs list (including per-player ticks in the Inner Fire/
Enlighten/Thorns submenus) - is remembered between sessions. Nothing
resets on login/relog any more.

This works via a single SavedVariable, `BuffDaddyDB` (declared in
`BuffDaddy.toc`), managed from `BuffDaddy.lua`:

- `BuffDaddy.LoadSettings()` runs on `ADDON_LOADED` (before `PLAYER_LOGIN`)
  and copies every saved value out of `BuffDaddyDB` into the matching
  `BuffDaddy.*` field, so the rest of the addon keeps reading/writing
  `BuffDaddy.*` exactly like before - it just happens to now be backed by
  disk. The very first time the addon ever loads (no `BuffDaddyDB` yet),
  it's created from the plain defaults still set at the top of
  `BuffDaddy.lua`.
- `BuffDaddy.OptionalEnabled` and `BuffDaddy.OptionalTargets` (the two
  table-shaped settings) are pointed at the *same* table as
  `BuffDaddyDB.OptionalEnabled`/`OptionalTargets` after loading - so
  ticking an optional buff or a targeted player writes straight into the
  saved table with no extra step.
- Every other (plain true/false or number) setting is written back to
  `BuffDaddyDB` by `BuffDaddy.SaveSettings()`, called right after that
  setting changes (see the dropdown `func` callbacks in
  `BuffDaddy_Minimap.lua`) and again at `PLAYER_LOGOUT` as a safety net.
- Which fields count as "plain" settings is the `SAVED_VALUE_FIELDS` list
  near the top of `BuffDaddy.lua` - add a new field there (plus a default
  value above it) if a future toggle also needs to persist.

If you ever want to reset everything back to defaults, delete
`BuffDaddyDB` from your `WTF\Account\...\SavedVariables\BuffDaddy.lua`
file (or just delete that whole file) and relog.

---

## File layout & load order

Load order is fixed in `BuffDaddy.toc` and matters - each file only uses
things defined by files loaded before it. Every file has a comment block
at the top stating its dependencies.

1. `BuffDaddy_Definitions.lua` - pure data, no dependencies.
2. `BuffDaddy.lua` - creates the `BuffDaddy` namespace/sub-tables, constants
   (`RUNNING_OUT_THRESHOLD`, `AUTO_REFRESH_INTERVAL`), the hidden scan
   tooltip, `LoadSettings`/`SaveSettings` (see "Settings persistence"),
   and the `ADDON_LOADED`/`PLAYER_LOGIN`/`PLAYER_LOGOUT` handler that loads
   settings, applies them to the window/buttons, and starts the
   10-second ticker.
3. `BuffDaddy_Roster.lua` - `BuffDaddy.Roster.GetRoster()`.
4. `BuffDaddy_Check.lua` - all the matching/counting logic,
   `BuffDaddy.Check.RunCheck(announce)` is the main entry point.
5. `BuffDaddy_Output.lua` - `UpdateWindow`, `SendRaidReport`, `SendWhispers`.
6. `BuffDaddy_Minimap.lua` - click handling + dropdown population.
7. `BuffDaddy.xml` - the window frame, minimap button, and dropdown frame.
   Loaded last since its `OnLoad`/`OnClick` scripts call Lua functions that
   must already exist.

`BuffDaddyDB` (a SavedVariable, see `BuffDaddy.toc`) persists every option
state between sessions - see "Settings persistence" below. Nothing else
is saved (no per-character data beyond your own option choices).

---

## Known risk areas / things to verify in-game

1. **`C_UnitAuras.GetUnitAuras(unit, "HELPFUL")` return shape** - the code
   in `BuffDaddy_Check.lua` (`GetUnitAuraList`) assumes it returns an array
   of tables with `.name`, `.duration`, `.expirationTime`, and `.index`
   fields. This hasn't been confirmed against ClassicAPI's actual behavior
   yet. If buffs aren't being detected at all, check this function first -
   it's the single place this assumption lives, so it's a one-function fix
   if the real shape differs.
2. **Tooltip scanning font string names** - `AuraTooltipContains` assumes
   the hidden tooltip's line font strings are named
   `BuffDaddyScanTooltipTextLeft1`, `...Left2`, etc. (standard
   `GameTooltipTemplate` naming). Worth a quick in-game check if
   `tooltipCheck` buffs (currently just Shadow Protection) misbehave.
3. **`RAID_CLASS_COLORS`** - assumed to exist as a global with `.r/.g/.b`
   per class token, standard in vanilla FrameXML. Falls back to white if
   missing.
4. **Window size is dynamic again, on purpose (2nd time around)** -
   `BuffDaddy.Output.ResizeWindow` was previously deleted entirely (see
   the "Removed auto-resize entirely" session below) after the first
   attempt caused problems, but was reintroduced to support the "Display
   players" list, since that content's length varies a lot. This time it
   only ever adds to a *base* size captured once from `BuffDaddy.xml` at
   login (`BuffDaddy.WindowBaseWidth`/`WindowBaseHeight`, set in
   `BuffDaddyWindow`'s `OnLoad`) - it never overwrites what's in the XML
   file itself, and always returns to exactly that base size when the
   list is off/hidden. If the window seems to grow/shrink unexpectedly,
   check `BuffDaddy.Output.ResizeWindow` first. The extra height is only
   an estimate (`PLAYER_LIST_LINE_HEIGHT`/`_TOP_GAP`/`_WIDTH_BONUS`
   constants in `BuffDaddy_Output.lua`), tuned by eye, not measured text -
   if it looks off in-game, adjust those three numbers.
5. **`<Anchor>` offsets must use the nested `<Offset x="" y=""/>` form, not plain `x`/`y` attributes** - confirmed in-game (see "Manual adjustment guide"). `<Size>` attributes are unaffected. If a future edit adds a new anchor anywhere in `BuffDaddy.xml` and the position doesn't move, check this first before assuming the number is wrong.
6. **`FontString` elements don't fire `<Scripts><OnLoad>` on this client** - only real `Frame`-type widgets (Button, Frame, etc.) do. This is why `BuffDaddyWindowTitle` used to end up with no text at all (`GetText()` returned `nil` even though `IsShown()` was true) - its own `OnLoad` calling `this:SetText(...)` silently never ran. Fixed by moving that call to `BuffDaddyWindow`'s `OnLoad` instead, referencing `BuffDaddyWindowTitle` by name. Any future FontString that needs to run code on load needs the same treatment - put the code on its parent Frame's `OnLoad`, not its own.
7. **Left-opening submenu hook** - `DropDownList2` is repositioned by
   hooking its `OnShow` script (see `BuffDaddy_Minimap.lua`), overriding
   wherever Blizzard's own code would have placed it. Assumes
   `DropDownList1`/`DropDownList2` already exist as globals by the time
   BuffDaddy's Lua files load (true for the client's own core UI, but
   worth a quick in-game check - if the Inner Fire/Enlighten/Thorns/
   Update interval/Buffs-below threshold submenu doesn't open at all, or
   opens on the right, check this hook first).

---

## Session log

- **Initial build**: full addon created from spec - roster gathering,
  buff/tooltip matching, Emerald Blessing special case, colored raid
  report + whispers, minimap button + dropdown, 10-second auto-refresh
  window. Not yet tested in-game.
- **Targeted per-player optional buffs**: renamed Shadow Protection ->
  "Shadow Protection (Priest)", Emerald Blessing -> "Emerald Blessing
  (Druid)", Inner Fire -> "Inner Fire (Priest)". Added two new optional
  buffs, "Enlighten (Priest)" (real aura name "Enlighten Dummy") and
  "Thorns (Druid)". Reordered the dropdown so Priest entries come first,
  then Druid entries, and every entry is now colored in its class color.
  Inner Fire, Enlighten and Thorns changed from simple on/off ticks to a
  new "targeted" def type: clicking them opens a submenu listing matching
  online raid/group members (Priests for the two Priest buffs; Warriors +
  Druids for Thorns) that you tick individually - only ticked players are
  checked. New `def.targeted` / `targetClasses` / `noneFoundText` fields
  in `BuffDaddy_Definitions.lua`, new `appliesTo = "selectedTargets"`
  case in `BuffDaddy_Check.lua`, new `BuffDaddy.OptionalTargets` session
  table in `BuffDaddy.lua`, and a second dropdown level in
  `BuffDaddy_Minimap.lua`. All Lua files re-validated with `luac5.1 -p`.
- **UI/behavior overhaul**: dropped the " (Priest)"/" (Druid)" suffix from
  the 5 optional buff display names (`BuffDaddy_Definitions.lua`) - class
  color in the dropdown already conveys this, so the suffix was just
  noise, especially doubled up in chat/whisper text. Forced the
  Inner Fire/Enlighten/Thorns (and new Update interval/Buffs-below
  threshold) submenu to always open on the dropdown's left side via a
  `DropDownList2` `OnShow` hook in `BuffDaddy_Minimap.lua`. Output window:
  background is now fully transparent (dropped `bgFile` from the XML
  Backdrop, border-only), text anchor nudged from (10,-10) to (16,-16) so
  it clears the border, and the window now resizes itself automatically
  to fit its text (`BuffDaddy.Output.ResizeWindow`). Rewrote the 3 window
  lines to "Raidbuffs Y/X" / "Selfbuffs A/B" / "Buffs below D min C", each
  independently colored green/red. Added a new top section to the
  dropdown (Clickthrough, Lock, Show Print button, Update interval
  submenu, Buffs-below threshold submenu, then a divider) - all new
  session-only state lives in `BuffDaddy.lua`
  (`WindowLocked`/`WindowClickthrough`/`ShowPrintButton`), with the
  window's mouse/EnableMouse handling in `BuffDaddy_Output.lua` and a new
  `BuffDaddyPrintButton` (anchored just outside the window's right edge)
  in `BuffDaddy.xml`. `BuffDaddy.AUTO_REFRESH_INTERVAL` is now adjustable
  live via the dropdown (0/"Never" stops the ticker); added
  `BuffDaddy.RestartAutoRefresh()` so changing it takes effect immediately
  instead of only at login. Removed the old "Right-click:.../Shift-right-
  click:..." explanation lines from the dropdown itself - that
  explanation now lives in a GameTooltip on minimap button hover
  (`BuffDaddy.Minimap.OnEnter`/`OnLeave`). Minimap button clicks
  remapped: left-click now shows/hides the window, shift-left-click does
  the silent check, alt-left-click does check+report+whispers, and
  right-click opens the dropdown (previously left-click opened the
  dropdown and right-click/shift-right-click did the checks). All Lua
  files re-validated with `luac5.1 -p`, XML re-validated with
  `xml.dom.minidom`, and a widget-name cross-reference check confirmed no
  orphaned names between the XML and the Lua files.
- **Group-check reliability fix + Detailed output + dropdown cleanup**:
  - Fixed the bug where the rainbow `BUFFCHECK` summary line sometimes
    didn't print at all in a group/raid while the `Missing:` lines still
    came through - vanilla can silently drop a chat line when several
    `SendChatMessage` calls fire in the same instant. `BuffDaddy_Output.lua`
    now sends the summary line, each `Missing:` line, the self-buff notice,
    and each whisper one at a time, `CHAT_LINE_DELAY` (0.2s) apart, via
    `C_Timer.After`, instead of firing them all in one go.
  - Also fixed a smaller, unrelated bug found while in there: the black
    `>>> ` prefix was being built but never actually attached to the
    `BUFFCHECK` summary line - it's now prepended like every other line.
  - Removed **Lock output window** - redundant with Clickthrough, since a
    clickthrough window already can't be dragged. `BuffDaddy.WindowLocked`
    removed from `BuffDaddy.lua`; `OnWindowMouseDown` in
    `BuffDaddy_Output.lua` simplified to always allow dragging.
  - Added **Detailed output** in its place in the dropdown. When on, each
    `Missing:` line in the raid chat report lists the actual missing
    player names (each in their own class color) instead of just a count,
    capped at 5 names with a red `(and more...!)` beyond that. New
    `BuffDaddy.DetailedOutput` session flag; `HandleNormalBuff` and
    `HandleGroupCheck` in `BuffDaddy_Check.lua` now collect a `names` list
    (player name + class) on every `missingBuffs` entry; new
    `BuildMissingTail` helper in `BuffDaddy_Output.lua` picks between the
    old "on N Players" text and the new name list.
  - Fixed the dropdown text alignment for Inner Fire / Enlighten / Thorns -
    they used to sit further left than Shadow Protection / Emerald
    Blessing because `notCheckable = true` removes the checkbox's
    reserved space. Left `notCheckable` false (with `checked = false` and
    no `func`) so the checkbox space is reserved but never actually shown
    as ticked - clicking the line still just opens the submenu as before.
  - All four edited Lua files re-validated with `luac5.1 -p`.
- **Update button, title label, expiring buffs, and color cleanup**:
  - Added a second **"Update" button** (`BuffDaddyUpdateButton`) just to
    the left of Print, shown/hidden by the same "Show Print button"
    toggle. It calls `RunCheck(false)` - refreshes the window silently,
    no chat/whispers - versus Print's `RunCheck(true)`.
  - Added a small light-blue **"BuffDaddy" title** (`BuffDaddyWindowTitle`)
    anchored just above the window's top-left corner.
  - The raid chat `BUFFCHECK` summary line was sometimes not printing at
    all - traced to the per-letter rainbow color coding making that one
    line very long. Swapped `RainbowText("BUFFCHECK")` for a plain
    light-blue `BUFFCHECK` (`C_LBLUE`). `RainbowText`/`RAINBOW_COLORS` are
    left in `BuffDaddy_Output.lua`, just unused for now.
  - Recolored the `Missing:` raid chat line - `Missing` and the class name
    are now white, the buff name is grey (was orange/class-colored) -
    less visual noise, since the buff's own class association is already
    obvious from context.
  - Added a **"Check expiring"** toggle (`BuffDaddy.CheckExpiring`,
    default off). Off: remaining buff duration is ignored completely
    everywhere (`HandleNormalBuff`/`HandleGroupCheck` in
    `BuffDaddy_Check.lua` skip the remaining-time check entirely, so
    `runningOutCount` stays 0). On: works as before (feeds window line 3
    / the raid chat "Buffs below" count); if Detailed output is *also*
    on, players whose buff is about to run out get appended straight into
    that buff's existing `Missing:` line (not a separate line) with a
    white ` (expiring)` tag after their class-colored name.
  - Documented in "Known risk areas" why hand-editing `<Size>` in
    `BuffDaddy.xml` doesn't stick (`ResizeWindow` overwrites it on every
    update) and where to change window sizing instead.
  - All four edited Lua files re-validated with `luac5.1 -p`, XML
    re-validated with `xml.dom.minidom`, widget-name cross-reference
    re-checked.
- **Output window layout bug fix**: the title and the padding numbers
  didn't actually match how the window looked in-game.
  - The title (`BuffDaddyWindowTitle`) was anchored *above* the window's
    top edge instead of inside it, which is why it never visibly
    appeared - moved it inside the window, top-left corner.
  - `Line1`'s anchor in `BuffDaddy.xml` used a 40px left offset, but
    `ResizeWindow`'s old `PADDING_X` constant assumed only 20px - the
    window was being sized too narrow for where the text actually sat.
    Rebuilt the whole layout so title + all 3 lines stack directly under
    each other with one consistent set of spacing numbers, and renamed
    `ResizeWindow`'s constants (`LEFT_INSET`/`RIGHT_INSET`/`TOP_INSET`/
    `GAP`/`BOTTOM_INSET`/`TITLE_HEIGHT`/`LINE_HEIGHT`) to each name
    exactly which `<Anchor>` value in `BuffDaddy.xml` they have to match,
    so the two files can't silently drift apart again.
  - `BuffDaddy_Output.lua` and `BuffDaddy.xml` re-validated with
    `luac5.1 -p` / `xml.dom.minidom`.
- **Removed auto-resize entirely - fixed size/position rewrite**: the
  previous fix (matching anchor offsets to `ResizeWindow`'s padding
  constants) didn't resolve what the in-game window actually looked like,
  so the whole auto-resize approach was scrapped rather than patched
  further.
  - Deleted `BuffDaddy.Output.ResizeWindow` from `BuffDaddy_Output.lua`
    completely, along with its call at the end of `UpdateWindow`. Nothing
    in Lua sizes or positions the window anymore.
  - `BuffDaddyWindow` in `BuffDaddy.xml` now has a plain fixed
    `<Size x="220" y="110"/>`.
  - `BuffDaddyWindowTitle`/`Line1`/`Line2`/`Line3` are each anchored
    directly to `BuffDaddyWindow`'s own TOPLEFT corner with their own
    fixed x/y offset, instead of being chained to each other (title ->
    line1 -> line2 -> line3). Each line's position can now be read and
    changed independently, with no chain of relative offsets to trace
    through.
  - Added a new "Manual adjustment guide" section near the top of this
    README with a plain table of exactly which `BuffDaddy.xml` line to
    edit for window size, window position, and each line's text
    position, plus what the x/y numbers mean.
  - `BuffDaddy_Output.lua` re-validated with `luac5.1 -p`, `BuffDaddy.xml`
    re-validated with `xml.dom.minidom`, and a widget-name cross-reference
    against every other `.lua` file confirmed nothing else in the addon
    references `ResizeWindow` or touches `BuffDaddyWindowTitle`.
- **Real root cause found via in-game diagnostics - two client-specific quirks, not a code bug**: after the fixed-position rewrite still showed the same symptoms, stopped guessing and used `/script` + `GetPoint()` dumps (no `/dump` - `DebugTools` isn't installed) to read the client's *actual* live anchor/size/text state, since the file on disk kept turning out not to match what was rendering. That surfaced two genuine client quirks (confirmed empirically, not assumed):
  - `<Anchor>` offsets written as plain `x`/`y` attributes (e.g. `<Anchor point="X" x="1" y="2"/>`) are silently ignored by this client and always read back as `0,0` via `GetPoint()`, even though `<Size x="..." y="..."/>` attributes on the Frame itself read back correctly. Fixed by rewriting all 4 text anchors to use a nested `<Offset x="..." y="..."/>` tag inside `<Anchor>` instead - confirmed via a follow-up `GetPoint()` dump that offsets now read back correctly (`14,-34` etc, matching the file).
  - `FontString` elements don't fire `<Scripts><OnLoad>` on this client at all - only real `Frame`-type widgets do. This is why the title was truly invisible: `BuffDaddyWindowTitle:GetText()` dumped as `nil` even with `IsShown() = true` - its own `OnLoad` calling `this:SetText("BuffDaddy")` never ran, silently. Fixed by removing the title's own `OnLoad` block and moving `BuffDaddyWindowTitle:SetText(...)`/`SetTextColor(...)` into `BuffDaddyWindow`'s `OnLoad` instead (a real Frame, confirmed to fire since the minimap button and dropdown already relied on Frame-level `OnLoad` working).
  - Also restored `BuffDaddyWindow`'s `<Size>` to `220x110` (it had been hand-edited down to `120x120` during troubleshooting, too small for 3 lines of text).
  - Both new quirks documented as "Known risk areas" #5 and #6, and the "Manual adjustment guide" section rewritten to lead with the `<Offset>` requirement and to include the exact `/script` diagnostic commands to use if a future position edit doesn't seem to take effect, instead of re-guessing blind.
  - `BuffDaddy.xml` re-validated with `xml.dom.minidom`, and every change was re-fetched fresh from the live file and re-checked after writing (not just trusted from the write call) before being reported as done.
- **"Display players" window list, Expand button, dynamic resize back on purpose**:
  - Added a new optional line 4+ section to the small window: for every
    missing or (with Check expiring on) running-low buff, a class-colored
    `"Buffname"` header line followed by its missing/expiring player
    names, indented, 3 per line, each in their own class color. Expiring
    (found but low) names get a grey ` (X min)` suffix. Covers both raid
    buffs and self buffs, raid first.
  - Two new session-only toggles in `BuffDaddy.lua`:
    `BuffDaddy.ShowPlayerList` (dropdown "Display players", master switch)
    and `BuffDaddy.PlayerListExpanded` (dropdown "Expand" + new
    `BuffDaddyExpandButton`, quick show/hide) - both off by default, both
    must be on for the list to show.
  - `BuffDaddy_Check.lua`: `HandleNormalBuff` and `HandleGroupCheck` now
    also build `results.windowRaidBuffs` / `results.windowSelfBuffs`
    (per-buff `{defName, class, entries}`, entries = missing and/or
    expiring `{name, class, expiring, remainingMinutes}`) - deliberately
    separate from the existing Detailed-output-gated `missingNames`, so
    this new list works independently of that raid-chat-only toggle.
  - `BuffDaddy_Output.lua`: new `BuildPlayerListText` (turns those two
    result tables into the window text block) and `ResizeWindow` (grows
    `BuffDaddyWindow` to fit that text, shrinks back to its base size
    when hidden/empty) - wired into `UpdateWindow`. `SetPrintButtonShown`
    now also shows/hides the new Expand button alongside Update/Print.
  - `BuffDaddy.xml`: new `BuffDaddyWindowPlayerList` FontString (line 4+,
    hidden by default, anchored the same way as lines 1-3) and new
    `BuffDaddyExpandButton` (left of Update, same size/style as the
    existing buttons). `BuffDaddyWindow`'s `OnLoad` now also captures its
    starting width/height into `BuffDaddy.WindowBaseWidth`/
    `WindowBaseHeight` so `ResizeWindow` always has a "collapsed" size to
    return to - whatever size is in the XML (including any manual resize)
    is preserved as that base, nothing hardcoded.
  - `BuffDaddy_Minimap.lua`: new `BuffDaddy.Minimap.ToggleExpand()` (used
    by both the Expand button and the mirrored dropdown entry), plus the
    two new dropdown toggle lines themselves.
  - Auto-resize is back after being removed in an earlier session - this
    time it only adds on top of a captured base size and never edits the
    XML file, see "Known risk areas" #4 for the full reasoning.
  - No FontString x/y offsets or existing button sizes were changed -
    only new elements were added, reusing the existing 45x20 button size
    and the established `<Offset>` anchor pattern.
  - All four edited Lua files re-validated with `luac5.1 -p`, `BuffDaddy.xml`
    re-validated with `xml.dom.minidom` (and confirmed unescaped), and a
    widget-name cross-reference confirmed every new XML name
    (`BuffDaddyExpandButton`, `BuffDaddyWindowPlayerList`) is referenced
    correctly and nothing is orphaned.
- **Dropdown renames/reorder, "--" list markers, Groupbuffs rename, conditional expiring segment, smaller window**:
  - Renamed and regrouped the dropdown's window/behavior section by
    prefix - "Window: ..." entries together, then "Output: ..." entries
    together: `Clickthrough output window` -> **Window: Clickthrough**,
    `Display players` -> **Window: toggle playername display**,
    `Expand` -> **Window: expand playername display**, `Show Print
    button` -> **Window: show quick access buttons**, `Update interval`
    -> **Window: Autoupdate intervall**, `Detailed output` -> **Output:
    Detailed (Playernames)**, `Check expiring` -> **Output: display
    expiring Buffs too**, `Buffs-below threshold` -> **Output: expiring
    buff remaining time threshhold**. Only the display text changed - the
    underlying `BuffDaddy.ShowPlayerList`/`PlayerListExpanded`/etc. flags
    and all `func` behavior are untouched.
  - Each row of the window's "Display players" list now starts with a
    white `--` marker before the player names (`BuildPlayerGroupText` in
    `BuffDaddy_Output.lua`), instead of a plain two-space indent.
  - Renamed every user-visible "Raidbuffs" to "Groupbuffs" - window line
    1 and the raid chat summary line - plus matching code comments.
  - The raid chat summary line's " | C Buffs below D min" segment is now
    only appended when **Output: display expiring Buffs too** is on
    (`BuildSummaryLine` in `BuffDaddy_Output.lua`) - previously it always
    printed, showing a misleading "0 Buffs below" even when expiring
    wasn't being checked at all. The window's own line 3 is unaffected -
    it still always shows (as 0/green when the toggle is off).
  - Shrunk the output window's base (collapsed) size in `BuffDaddy.xml`
    from `220x110` down to `170x55` - it had a lot of empty space below
    line 3. This only changes the base/collapsed size (captured into
    `BuffDaddy.WindowBaseWidth`/`WindowBaseHeight` at login); the
    Display-players auto-grow behavior on top of it is unchanged.
  - All edited Lua files re-validated with `luac5.1 -p`, `BuffDaddy.xml`
    re-validated with `xml.dom.minidom`, and grepped the whole addon to
    confirm no leftover "Raidbuffs" mentions anywhere in code.
- **Always-on player list, indented submenu entries, buttons moved inside the window, negative-remaining-time fix, first-chat-line fix**:
  - Removed the **Window: toggle playername display** master switch
    entirely. The line 4+ missing/expiring player list is now always
    built every check, same as everything else - **Window: expand
    playername display** (and the Expand button) is the only control
    left, and it now only decides whether the list is shown, not whether
    it's built. `BuffDaddy.ShowPlayerList` removed from `BuffDaddy.lua`;
    `UpdateWindow` in `BuffDaddy_Output.lua` and the dropdown in
    `BuffDaddy_Minimap.lua` updated to match. Confirmed with a grep that
    no reference to `ShowPlayerList` is left anywhere in the addon.
  - Indented the two dropdown entries that open a submenu instead of
    toggling directly - **Window: Autoupdate intervall** and **Output:
    expiring buff remaining time threshhold** - with a few leading spaces
    in `BuffDaddy_Minimap.lua`, so they read as sub-items under their
    section rather than sitting flush with the toggle lines above them.
  - Moved the Expand/Update/Print buttons from just outside the window's
    top-right corner to **inside the window, top-left**, reading
    left-to-right Expand, Update, Print (`BuffDaddy.xml`). They now
    overlap the title/line text when shown - expected, since they're only
    meant to be toggled on briefly via "Window: show quick access
    buttons", not left on permanently. Print stays anchored to the window
    itself; Update anchors to Print, Expand anchors to Update, all using
    the nested `<Offset>` form (see "Known risk areas" #5).
  - Fixed a bug where a buff with a stale/bad `expirationTime` (seen after
    someone ported - e.g. remaining reported as `-9000` despite them
    actually having ~40 minutes left) was wrongly counted as "expiring"
    because the code only checked `remaining < threshold`, and any
    negative number is less than the threshold. `HandleNormalBuff` and
    `HandleGroupCheck` in `BuffDaddy_Check.lua` now also require
    `remaining >= 0` before treating it as expiring - a negative or huge
    value is now just treated as found/fine.
  - Investigated the report that the `BUFFCHECK` summary line sometimes
    doesn't print at all in a group. It's *not* the conditional " | C
    Buffs below D min" segment - leaving that out only makes the line
    shorter, not longer, so line length isn't the cause. Most likely
    cause: the summary line was the only one sent with **zero** delay
    (fired the instant `RunCheck(true)` runs), landing on the exact same
    game tick as whatever triggered the check (button click / keybind) -
    a second, separate way vanilla can silently drop a chat message,
    beyond the "two messages same tick" issue the staggering already
    fixed. `SendLinesStaggered` in `BuffDaddy_Output.lua` (and
    `SendWhispers`) now start at `1 * CHAT_LINE_DELAY` instead of `0`, so
    every line - including the first - gets pushed off the triggering
    tick. Worth confirming in-game; if the line still drops occasionally,
    the delay may need to be nudged up from 0.2s.
  - All four edited Lua files re-validated with `luac5.1 -p`, `BuffDaddy.xml`
    re-validated with `xml.dom.minidom`, and a widget-name cross-reference
    grep confirmed nothing is orphaned.
- **v0.2 - shortened summary line, cleanup**: the `BUFFCHECK` summary
  line was still occasionally not showing up in RAID/PARTY chat (it
  showed fine locally via the Debug button) even after the earlier
  color-reset cleanup and chat-tick staggering fixes - shortened its
  labels further (`"Groupbuffs"` -> `"Group"`, `"Selfbuffs"` -> `"Self"`,
  `"Buffs below D min"` -> `"Low Dm"`, dropped the spaces around the `|`
  separators) in `BuildSummaryLine` (`BuffDaddy_Output.lua`) to cut the
  total message length sent to `SendChatMessage`, since RAID/PARTY
  appears to have a lower effective limit than local
  `DEFAULT_CHAT_FRAME:AddMessage` printing on this server. Removed a
  stale code comment referencing the old rainbow-text feature (the
  feature itself was already gone from the code, only the comment was
  leftover). Removed the "OctoWoW" mention from this file's intro line -
  this addon targets a generic WoW 1.12.1 client/server, not any
  specific private server. `BuffDaddy_Output.lua` re-validated with
  `luac5.1 -p`.
