# FFXIMissingSpells

Tells you which spells your character still needs to learn, broken out by
magic-using job. Same idea as FFXIMissingTrust (now folded into this repo)
but for the full spell book — twelve job tabs across the top, each
listing every spell the job can learn at lv 1-99 with `-` red if missing
or `+` green if already learned.

## Install

Drop the `FFXIMissingSpells` folder into `addons\`. Then in-game:

```
//lua load FFXIMissingSpells
```

To autoload it every session, add `lua load FFXIMissingSpells` to
`scripts\init.txt`.

## Window

Press **U** to toggle the window in-game. The keybind is suppressed while
chat is open so typing the letter 'u' still works normally.

```
//ms              — toggle the window (same as the U key)
//ms show         — show the window
//ms hide         — hide the window
```

The window has two strips of tabs:

- **Title bar (top right)** — `Missing` / `Owned` / `All` filter
- **Beneath the title bar** — twelve job tabs:
  `WHM | BLM | RDM | PLD | DRK | BRD | NIN | SMN | BLU | GEO | SCH | RUN`

Each row shows `[Lv NN]  Spell Name   (Skill)`. In the All tab spells are
color-coded individually (red = missing, green = owned); in Missing /
Owned the entire list is the matching color.

**Mouse:** drag the title bar to move. Mouse-wheel scrolls the list. Up/down
arrow buttons appear on the right when there are more entries than fit on
screen. Window position, current job tab, and current mode all persist to
`data/settings.xml`.

## Chat commands

| Command | What |
|---|---|
| `//ms count [JOB]` | One-line "owned / total (missing)" summary for the given job (defaults to current tab) |
| `//ms list  [JOB]` | Print every missing spell for the job in chat |
| `//ms have  [JOB]` | Print every owned spell for the job in chat |
| `//ms find <name>` | Search every job — shows owned/missing status and which job(s) can learn it |
| `//ms <JOB>` | Quick-switch the active tab (e.g. `//ms blm`) |
| `//ms mode <missing\|owned\|all>` | Change the filter mode |
| `//ms refresh` | Re-read the spell book and redraw |
| `//ms help` | Show the help blurb |

Aliases: `//missingspells`, `//mspells`, and `//ms` all work. The original
trust-only command prefixes `//mt` and `//mtrust` are also kept as
back-compat aliases so anyone with the old commands in their scripts
keeps working.

## How it works

- Iterates `resources/spells.xml` for every spell that has
  `spell.levels[job_id]` set for the selected job tab
- Filters out trust spells (`spell.type == 'Trust'`) — those live in their
  own addon (FFXITrusts / FFXIMissingTrust if you still have it)
- Compares each spell ID against `windower.ffxi.get_spells()` — your
  actual spell book
- Sorts by level ascending, then alphabetically
- Skill column comes from `res.skills[spell.skill].en` if it's a recognized
  magic skill, otherwise falls back to `spell.type` (e.g. "Geomancy",
  "BlueMagic", "BardSong", "Ninjutsu", "SummonerPact")

## Notes per job

- **BRD** — every song the job can learn natively, regardless of whether
  it's currently slotted in your active set.
- **BLU** — every Blue Magic spell. The addon does NOT check what's in
  your set spells; missing means you haven't learned it yet at all.
- **SMN** — covers SummonerPact spells (the avatar magics like Ramuh's
  Wind Blade, Aerial Armor, etc.), not the BPs themselves.
- **NIN** — Ninjutsu spell list (Utsusemi, elemental ni / san, status
  enfeebles, Tonko, etc.).
- **GEO** — Indi-, Geo-, Bolster, Entrust, the works. Geomancy type.
- **SCH** — strategos / addendum magic. Doesn't distinguish Light Arts
  vs Dark Arts; the level number is what matters.
- **RUN** — runes themselves aren't spells, so this tab is light. Lunge,
  Swipe, Gambit, Vallation etc. show here when they're stored as spells.

## Renamed from FFXIMissingTrust

This repo started life as FFXIMissingTrust — only listed trusts. It got
expanded to handle every magic school so it could replace the
type-it-out-in-chat workflow for spell scrolls too. If you remember the
old `//mt` commands, they still work.

## Author

Jason (2026). Built for the FFXIWindower personal repo.
