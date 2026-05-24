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

The Unity Concord variants (e.g. `Yoran-Oran` vs `Yoran-Oran (UC)`) are
separate spells and listed independently — each one is its own spell ID
that must be learned separately.

## Visual style

The window uses the same blue border, dark title bar, and tab styling as
GSUI so the two addons feel like part of the same family.

## Author

Jason (2026). Built for the FFXIWindower personal repo.
