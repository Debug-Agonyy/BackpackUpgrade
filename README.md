# Backpack Upgrade

A Project Zomboid **Build 42** mod that lets you craft an upgrade kit and install it into any back-worn bag to raise its carrying capacity.

Built for multiplayer, and the capacity change survives relogs — which is the part most capacity mods get wrong.

---

## What it does

- Craft a **Backpack Upgrade** from a needle, a ripped sheet and one spare bag.
- Right-click any back-worn bag → **Install Backpack Upgrade**.
- Each install adds **+8 capacity**, up to **6 installs** per bag.
- Capacity is clamped at **50**, the engine's hard ceiling. A bag at 44 upgrades to 50, not 52 — the excess is never wasted silently, the option simply disappears once the bag is maxed.
- Works on all 56 vanilla back-worn bags. Held bags, purses and fanny packs are deliberately excluded.

| Bag | Base | After upgrades |
|---|---|---|
| Normal Hiking Bag | 20 | 28 → 36 → 44 → 50 |
| Big Hiking Bag | 25 | 33 → 41 → 49 → 50 |
| Schoolbag | 15 | 23 → 31 → 39 → 47 → 50 |

## Requirements

Project Zomboid Build 42 (developed and tested on 42.21). Not compatible with Build 41.

## Installation

**Manual:**

1. Download or clone this repository.
2. Copy the `BackpackUpgrade` folder into `%USERPROFILE%\Zomboid\mods\`.
3. Enable **Backpack Upgrade** in the game's Mods menu.

**Dedicated server:** copy the same folder to `<instance>/Zomboid/mods/`, then add `\BackpackUpgrade` to the server's `Mods=` line and restart. Both the server and every connecting client need identical copies, or the Lua checksum kick will reject them.

## The recipe

| Input | Consumed |
|---|---|
| Needle *(Needle, Bone, Brass or Forged)* | No — tool only |
| Ripped Sheets ×1 | Yes |
| Any one back-worn bag | Yes |

No skill requirement, no workstation, no magazine to find. Listed under Tailoring in the crafting window.

## How it works

Capacity is a runtime value in Project Zomboid — it resets to the item script's number every time an item loads. So the mod does **not** store capacity. It stores an upgrade *count* in the item's mod data and rebuilds capacity from that count on every load.

```
media/lua/shared/BPU_Core.lua    rules shared by both sides: what counts as a
                                 backpack, base capacity, the clamp arithmetic
media/lua/client/BPU_Menu.lua    the right-click option, the local capacity
                                 change for instant UI feedback, and the message
                                 to the server
media/lua/server/BPU_Server.lua  the authoritative write; this is the copy that
                                 gets saved to disk
```

The client/server split is load-bearing, not decoration. **Project Zomboid does not synchronise item mod data between client and server.** A client-side write lives only in that session's memory and is gone the moment you reconnect and the server hands its own copy back. So the client sends `sendClientCommand`, the server handles it in `OnClientCommand`, and the server writes the mod data itself.

The message carries an **absolute** count rather than "add one", so a duplicated or late-arriving packet produces exactly the same result as a single one.

## Configuration

All three knobs are at the top of `42/media/lua/shared/BPU_Core.lua`:

```lua
BPU.CAP_PER_UPGRADE = 8    -- capacity added per install
BPU.HARD_CAP        = 50   -- engine ceiling; raising this does nothing
BPU.MAX_UPGRADES    = 6    -- installs allowed per bag
```

## Notes on Build 42 that cost me time

Recorded here because none of it is documented clearly anywhere public:

- **The container capacity ceiling is 50, not 49.** Every mod page repeats 49. Requesting 60 and watching the engine clamp the result proves otherwise.
- **Runtime `setCapacity()` works on 42.21 multiplayer.** Several popular capacity mods fail on B42 and are assumed to be impossible; they aren't.
- **The back-worn test is `canBeEquipped()` returning `base:back`.** `getBodyLocation()` returns nil and `getCanBeEquipped()` throws.
- **Item scripts use `ItemType = base:normal` in B42.** The B41 `Type = Normal` throws a `NullPointerException` in `Item.InstanceItem`.
- **Script files do not tolerate comments.** A `/* */` block aborts parsing for the whole file — and takes the rest of the mod's scripts with it. Comments belong in the Lua.
- **B42 needs `mod.info` in two places:** the mod root *and* inside the `42/` version folder. Without the second one you get `required mod not found`.

## License

MIT
