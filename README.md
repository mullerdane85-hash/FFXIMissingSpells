# FFXIMissingTrust

Tells you which trust magic spells your character still needs to learn —
both in chat and in a draggable GSUI-style window.

## Install

Drop the `FFXIMissingTrust` folder into `addons\`. Then in-game:

```
//lua load FFXIMissingTrust
```

To autoload it every session, add `lua load FFXIMissingTrust` to
`scripts\init.txt`.

## Window

Press **U** to toggle the window in-game. The keybind is suppressed while
chat is open so typing the letter 'u' still works normally.

```
//mt              — toggle the window (same as the U key)
//mt show         — show the window
//mt hide         — hide the window
```

The window has three tabs along the top:

| Tab | What it shows |
|---|---|
| **Missing** | Trusts the character has NOT learned |
| **Owned** | Trusts the character HAS learned |
| **All** | Every trust in the game, colored by status |

**Mouse:** drag the title bar to move. Mouse-wheel scrolls the list. Up/down
arrow buttons appear on the right when there are more entries than fit on
screen. Position and current tab are saved to `data/settings.xml`.

## Chat commands (still work alongside the window)

| Command | What |
|---|---|
| `//mt count` | One-line "owned / total (missing)" summary in chat |
| `//mt list` | Print every missing trust in chat |
| `//mt have` | Print every owned trust in chat |
| `//mt find <name>` | Show owned/missing status for trusts whose name matches |
| `//mt refresh` | Re-read spell book and redraw the window |
| `//mt help` | Show this help |

Aliases: `//missingtrust` and `//mtrust` both work. Short forms `t`, `w`, `s`,
`l`, `h`, `f`, `r` work for toggle/show/count/list/have/find/refresh.

## How it works

- Iterates `resources/spells.xml` for every spell with `type == 'Trust'`
- Compares each spell ID against `windower.ffxi.get_spells()` — the
  character's actual spell book
- Anything in the master list that's NOT in the spell book is missing
- Each trust is annotated with its in-combat job (SMN, WHM, PLD, etc.)
  from a hardcoded table at the top of `FFXIMissingTrust.lua`. FFXI's
  spell data doesn't expose this directly, so the table is editable —
  fix any wrong entries and submit a PR.

**Unity Concord (UC) trusts are excluded** from every view. They're awarded
via Unity rank with their respective UC leader, not via ciphers / quests /
the normal trust-acquisition path — so they don't belong in a "what do I
still need" list. The filter lives in `is_unity_concord()` at the top of
the Data section; remove the call from `all_trusts()` if you want them
back.

## Trust → job table + battle role/style

Two editable Lua tables at the top of `FFXIMissingTrust.lua`:

- **`JOB_BY_TRUST`** — combat job tag (SMN, WHM, PLD, etc.). Entries
  showing `[?]` were ones I wasn't 100% sure of (the five `AA*` Ark Angel
  trusts in particular).
- **`DESC_BY_TRUST`** — short `Role: style` descriptor. Role is one of
  Tank / Healer / Support / Caster / Ranged / Melee / Special (BG-Wiki's
  trust categorization). Style is a 3-7 word note about what makes that
  trust useful.

Both tables are alphabetical and easy to update. Fix any wrong entries,
`//lua reload FFXIMissingTrust`, and push the change so it lands for
everyone.

## Visual style

The window uses the same blue border, dark title bar, and tab styling as
GSUI so the two addons feel like part of the same family.

## Author

Jason (2026). Built for the FFXIWindower personal repo.
