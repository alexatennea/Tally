# Tally

A small WoW addon whose main job is telling you how long until your next level, based on the XP you've earned this session. It can also show your professions, gold and honor.

The panel shows:
- **Time to level**: remaining XP ÷ your XP rate over the chosen rate window
- **XP bar**: XP to go, % through the level and kills to level, with rested XP shown in purple
- **Session**: XP gained this session, and XP per hour over the rate window
- **Professions** (optional): a bar per primary and/or secondary profession with current/max rank
- **Gold** (optional): current gold, gained or lost this session, and gold per hour
- **Honor** (optional): PvP rank progress, today's honorable kills and this week's honor

Hover it for session time, session average, kills and rested XP.

## Display styles

- **Floating panel** (default): a small box you can drag anywhere.
- **Bar across the top** or **bottom**: everything on one line across the edge of the screen, with a thin XP progress line (and rested XP) along its inner edge.

Switch in options or with `/tally panel`, `/tally bar` (top) and `/tally bottom`.

In bar mode, default UI frames that sit under the bar are moved out of its way: the minimap cluster, buffs and so on move down for a top bar; the action bars, micro menu, bags and XP/reputation bars move up for a bottom bar. They're put back when you switch to the panel or hide the bar. While Edit Mode is open they go back to their real positions so you can edit them. Turn this off with "Move other UI out of the way of the bar" in options.

## Sessions

The session is saved per character, so it carries on through `/reload` and short logouts (time logged out isn't counted). It resets on its own after 30 minutes without gaining XP, or if you were logged out for more than 30 minutes. `/tally reset` resets it by hand.

**Rate window**: the XP rate (and so the time to level) uses only the last 5 min, 10 min (default), 30 min or 1 hour of XP gains, or the whole session. A short window reacts quickly to changes in pace; a long one is steadier.

**Kills to level**: remaining XP ÷ the average XP of your last 5 kills, read from the "<mob> dies, you gain N experience" messages.

## Minimap button

- **Left-click**: show or hide the panel
- **Right-click**: open options
- **Drag**: move it around the minimap edge

## Options

Open with `/tally`, the minimap button, or Options → AddOns → Tally. Choose the rate window and display style, toggle kills to level, professions (primary/secondary), gold, honor, the minimap button and the panel lock, or reset the session.

## Commands

| Command | Effect |
| --- | --- |
| `/tally` | Open options |
| `/tally reset` | Restart the session (rates and ETA) |
| `/tally lock` | Toggle dragging |
| `/tally show` / `hide` / `toggle` | Show or hide the panel or bar |
| `/tally panel` / `bar` / `bottom` | Switch display style |
| `/tally center` | Move the panel back to the middle of the screen |

## Deploying

```bash
./deploy.sh
```

Copies the `.toc`/`.lua`/`.xml` files into the classic beta `Interface/AddOns/Tally`. Set `WOW_ADDONS` to deploy somewhere else. Then `/reload` in game; a newly added file needs a full client restart.
