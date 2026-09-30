-- BPU_Core.lua
-- Shared = loaded on BOTH the client and the server. The rules of the
-- upgrade system live here so the two sides can never disagree about
-- what a bag's capacity is supposed to be.

BPU = BPU or {}

BPU.MODULE          = "BPU"   -- network module name, must match on both sides
BPU.CAP_PER_UPGRADE = 8       -- capacity added per upgrade installed
BPU.HARD_CAP        = 50      -- engine ceiling; measured, not guessed
BPU.MAX_UPGRADES    = 6       -- safety stop, also clamps a bad network message

-- Is this something worn on the back?
-- canBeEquipped() returns a slot string like "base:back". Held bags,
-- purses and fanny packs return something else, and non-container items
-- do not have the method at all, hence the pcall guard.
function BPU.isBackpack(item)
    if not item then return false end
    if not instanceof(item, "InventoryContainer") then return false end

    local ok, slot = pcall(function() return item:canBeEquipped() end)
    if not ok or not slot then return false end

    return string.find(tostring(slot), "back") ~= nil
end

-- The bag's capacity before any of our upgrades.
-- Captured the first time we touch a bag so every later calculation
-- starts from the original number instead of compounding on top of an
-- already-modified one.
function BPU.getBaseCapacity(item)
    local md = item:getModData()
    if not md.bpuBaseCap then
        md.bpuBaseCap = item:getCapacity()
    end
    return md.bpuBaseCap
end

function BPU.getUpgradeCount(item)
    local md = item:getModData()
    return md.bpuCount or 0
end

-- What capacity SHOULD this bag have, given its base and upgrade count?
-- math.min is the clamp: +8 each, but never past the engine ceiling.
-- A 20-capacity hiking bag goes 28, 36, 44, then 50 rather than 52.
function BPU.targetCapacity(base, count)
    if count <= 0 then return base end
    return math.min(base + (BPU.CAP_PER_UPGRADE * count), BPU.HARD_CAP)
end

-- Write the calculated capacity onto the item.
-- Called after an install AND on login, because capacity is a runtime
-- value that resets to the item script's number every time the item is
-- loaded. The upgrade COUNT is what persists; capacity is rebuilt from it.
function BPU.applyCapacity(item)
    if not BPU.isBackpack(item) then return end

    local base  = BPU.getBaseCapacity(item)
    local count = BPU.getUpgradeCount(item)
    if count <= 0 then return end

    item:setCapacity(BPU.targetCapacity(base, count))
end

-- Can this bag take another upgrade? False once it is at the ceiling,
-- so the menu option disappears instead of wasting the player's item.
function BPU.canUpgrade(item)
    if not BPU.isBackpack(item) then return false end

    local base    = BPU.getBaseCapacity(item)
    local count   = BPU.getUpgradeCount(item)
    local current = BPU.targetCapacity(base, count)

    return current < BPU.HARD_CAP and count < BPU.MAX_UPGRADES
end
