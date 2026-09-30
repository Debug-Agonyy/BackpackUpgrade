# Backpack Upgrade

A Project Zomboid **Build 42** mod that raises the carrying capacity of any backworn bag with a craftable upgrade kit.

Works in multiplayer, and the upgrade survives relogs.

## What it does

- Craft a **Backpack Upgrade** from a needle, a ripped sheet and one spare bag.
- Right-click any back-worn bag → **Install Backpack Upgrade**.
- Each install adds **+8 capacity**, up to 6 per bag, capped at 50.
- Works on all 56 vanilla back-worn bags. Held bags, purses and fanny packs are excluded.

A Normal Hiking Bag goes 20 → 28 → 36 → 44 → 50.

## Recipe

| Input | Consumed |
|---|---|
| Needle *(Needle, Bone, Brass or Forged)* | No — tool only |
| Ripped Sheets ×1 | Yes |
| Any one back-worn bag | Yes |

No skill requirement and no workstation. Listed under Tailoring in the crafting window.

## Requirements

Project Zomboid Build 42. Tested on 42.21. Not compatible with Build 41.

## Installation

Copy the `BackpackUpgrade` folder into `%USERPROFILE%\Zomboid\mods\` and enable it in the Mods menu.

**Dedicated server:** copy the same folder to `<instance>/Zomboid/mods/`, add `\BackpackUpgrade` to the server's `Mods=` line, and restart. The server and every client need identical copies.

## Settings

Top of `42/media/lua/shared/BPU_Core.lua`:

```lua
BPU.CAP_PER_UPGRADE = 8    -- capacity added per install
BPU.MAX_UPGRADES    = 6    -- installs allowed per bag
BPU.HARD_CAP        = 50   -- engine ceiling, raising this does nothing
BPU.KEEP_ENCUMBRANCE = true    -- false = upgrades add space only
```

## License

MIT
