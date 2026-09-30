-- BPU_Core.lua -- loaded on BOTH client and server, so the two sides can
-- never disagree about what a bag's capacity should be.

BPU = BPU or {}                                     -- global table, reused if already made

BPU.MODULE          = "BPU"                         -- network channel name; must match both sides
BPU.CAP_PER_UPGRADE = 8                             -- capacity added per upgrade installed
BPU.HARD_CAP        = 50                            -- engine ceiling; raising this does nothing
BPU.MAX_UPGRADES    = 6                             -- per-bag limit, also clamps a bad packet

-- Keep a full bag feeling exactly as heavy as it did before upgrading.
-- Set false to make upgrades add space only, and let the extra loot slow
-- you down the way vanilla would.
BPU.KEEP_ENCUMBRANCE = true
BPU.MAX_WEIGHT_REDUCTION = 95                       -- never let contents become weightless

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

-- The bag's weight reduction before any upgrade, captured once like the
-- capacity above. WeightReduction is a percentage: contents count toward
-- your carried weight at (100 - reduction)%.
function BPU.getBaseWeightReduction(item)
    local md = item:getModData()
    if not md.bpuBaseWR then
        local ok, wr = pcall(function() return item:getWeightReduction() end)
        md.bpuBaseWR = (ok and tonumber(wr)) or 0   -- 0 if the API isn't there
    end
    return md.bpuBaseWR
end

-- Weight reduction needed so a FULL upgraded bag feels the same as a full
-- original one.
--   felt weight = capacity x (100 - reduction)
-- Hold that product constant and solve for the new reduction. A 20-cap bag
-- at 30% feels like 14; at 50 capacity it needs 72% to still feel like 14.
function BPU.targetWeightReduction(baseCap, baseWR, newCap)
    if newCap <= baseCap then return baseWR end     -- nothing gained, nothing to offset

    local felt = baseCap * (100 - baseWR)           -- the number we're holding fixed
    local wr   = 100 - (felt / newCap)

    if wr > BPU.MAX_WEIGHT_REDUCTION then wr = BPU.MAX_WEIGHT_REDUCTION end
    if wr < baseWR then wr = baseWR end             -- never make a bag worse than stock

    return math.floor(wr + 0.5)                     -- engine wants a whole number
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

    local newCap = BPU.targetCapacity(base, count)
    item:setCapacity(newCap)

    if BPU.KEEP_ENCUMBRANCE then
        local baseWR = BPU.getBaseWeightReduction(item)
        local wr     = BPU.targetWeightReduction(base, baseWR, newCap)
        -- pcall because setWeightReduction is not confirmed on every build;
        -- a failure here must not stop the capacity change from sticking.
        local ok = pcall(function() item:setWeightReduction(wr) end)
        if not ok then
            print("[BPU] setWeightReduction unavailable; capacity applied without it")
        end
    end
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
