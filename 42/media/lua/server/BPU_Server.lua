-- BPU_Server.lua
-- Server side: the authoritative half. This is the copy of the bag that
-- gets written to disk, so this is the copy whose mod data actually has
-- to be right. Everything the client does is for responsiveness; this is
-- what survives a reconnect.

require "BPU_Core"

-- Find an item by its unique id anywhere in the player's inventory,
-- including inside other bags. The API spells the recursive version
-- "Recursiv" (no trailing e); older builds may only have the flat one,
-- so try the recursive form first and fall back.
local function findItemById(player, itemID)
    local inv = player:getInventory()
    if not inv then return nil end

    local ok, item = pcall(function() return inv:getItemWithIDRecursiv(itemID) end)
    if ok and item then return item end

    local ok2, item2 = pcall(function() return inv:getItemWithID(itemID) end)
    if ok2 and item2 then return item2 end

    return nil
end

-- Walk every bag the player is carrying and rebuild its capacity from
-- the stored upgrade count. Used on login and after an install.
local function reapplyAll(player)
    local inv = player:getInventory()
    if not inv then return end

    local list = inv:getItems()
    for i = 0, list:size() - 1 do
        local item = list:get(i)
        if BPU.isBackpack(item) and BPU.getUpgradeCount(item) > 0 then
            BPU.applyCapacity(item)
        end
    end
end

local function onInstall(player, args)
    if not args or not args.itemID then return end

    local item = findItemById(player, args.itemID)
    if not item then
        print("[BPU] server: no item with id " .. tostring(args.itemID) ..
              " on " .. tostring(player:getUsername()))
        return
    end

    if not BPU.isBackpack(item) then return end

    -- The client sends the absolute new count, not a delta, so this is
    -- safe to run twice. Clamp it anyway: the value came off the network
    -- and the server should not take a client's word for an arbitrary
    -- number.
    local count = tonumber(args.count) or 0
    if count < 0 then count = 0 end
    if count > BPU.MAX_UPGRADES then count = BPU.MAX_UPGRADES end

    local md = item:getModData()

    -- Prefer the base capacity the client captured, so both sides agree
    -- even if another mod has since altered the item script.
    md.bpuBaseCap = tonumber(args.baseCap) or BPU.getBaseCapacity(item)
    md.bpuCount   = count

    BPU.applyCapacity(item)

    print("[BPU] server: id=" .. tostring(args.itemID) ..
          " user=" .. tostring(player:getUsername()) ..
          " count=" .. tostring(md.bpuCount) ..
          " base=" .. tostring(md.bpuBaseCap) ..
          " capacity=" .. tostring(item:getCapacity()))
end

local function onClientCommand(module, command, player, args)
    if module ~= BPU.MODULE then return end
    if not player then return end

    if command == "install" then
        onInstall(player, args)
    elseif command == "reapply" then
        reapplyAll(player)
        print("[BPU] server: reapplied bags for " .. tostring(player:getUsername()))
    end
end

Events.OnClientCommand.Add(onClientCommand)
