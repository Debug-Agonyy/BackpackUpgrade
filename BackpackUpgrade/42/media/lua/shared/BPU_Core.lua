-- BPU_Core.lua -- loaded on BOTH client and server, so the two sides can
-- never disagree about what a bag's capacity should be.

BPU = BPU or {}                                     -- global table, reused if already made

BPU.MODULE          = "BPU"                         -- network channel name; must match both sides
BPU.CAP_PER_UPGRADE = 8                             -- capacity added per upgrade installed
BPU.HARD_CAP        = 50                            -- engine ceiling; raising this does nothing
BPU.MAX_UPGRADES    = 6                             -- per-bag limit, also clamps a bad packet

-- True only for containers worn on the back.
function BPU.isBackpack(item)
    if not item then return false end
    if not instanceof(item, "InventoryContainer") then return false end  -- not a container

    -- canBeEquipped() returns a slot string like "base:back".
    -- pcall because non-wearable containers throw instead of returning nil.
    local ok, slot = pcall(function() return item:canBeEquipped() end)
    if not ok or not slot then return false end

    return string.find(tostring(slot), "back") ~= nil                    -- excludes bags, purses
end

-- The bag's capacity before any upgrade. Captured once, then reused, so
-- later maths never compounds on an already-modified number.
function BPU.getBaseCapacity(item)
    local md = item:getModData()                    -- per-item storage, saved with the item
    if not md.bpuBaseCap then
        md.bpuBaseCap = item:getCapacity()          -- first time we've seen this bag
    end
    return md.bpuBaseCap
end

-- How many upgrades are installed. Absent means zero.
function BPU.getUpgradeCount(item)
    local md = item:getModData()
    return md.bpuCount or 0
end

-- What the capacity SHOULD be. math.min is the clamp: +8 each, never past
-- the ceiling, so 44 upgrades to 50 rather than 52.
function BPU.targetCapacity(base, count)
    if count <= 0 then return base end
    return math.min(base + (BPU.CAP_PER_UPGRADE * count), BPU.HARD_CAP)
end

-- Write the calculated capacity onto the item.
-- Called after an install AND after login, because capacity is a runtime
-- value that resets to the item script's number every time an item loads.
-- The COUNT is what persists; capacity is rebuilt from it.
function BPU.applyCapacity(item)
    if not BPU.isBackpack(item) then return end

    local base  = BPU.getBaseCapacity(item)
    local count = BPU.getUpgradeCount(item)
    if count <= 0 then return end                   -- untouched bag, leave it alone

    item:setCapacity(BPU.targetCapacity(base, count))
end

-- Can this bag take another upgrade? Drives whether the menu option shows.
function BPU.canUpgrade(item)
    if not BPU.isBackpack(item) then return false end

    local base    = BPU.getBaseCapacity(item)
    local count   = BPU.getUpgradeCount(item)
    local current = BPU.targetCapacity(base, count) -- where it stands right now

    return current < BPU.HARD_CAP                   -- room left under the ceiling
       and count   < BPU.MAX_UPGRADES               -- and under the per-bag limit
end
