-- BPU_Server.lua -- server side: the authoritative half.
-- This is the copy of the bag that gets written to disk, so this is the
-- copy whose mod data has to be right. The client's changes are only for
-- instant feedback; these are the ones that survive a reconnect.

require "BPU_Core"                                  -- shared rules (BPU table)

-- Find an item by its unique id anywhere in the player's inventory.
local function findItemById(player, itemID)
    local inv = player:getInventory()
    if not inv then return nil end

    -- The API really does spell it "Recursiv" with no trailing e.
    local ok, item = pcall(function() return inv:getItemWithIDRecursiv(itemID) end)
    if ok and item then return item end              -- found, including inside other bags

    -- Fallback for builds that only expose the flat lookup.
    local ok2, item2 = pcall(function() return inv:getItemWithID(itemID) end)
    if ok2 and item2 then return item2 end

    return nil                                       -- not carried by this player
end

-- Rebuild capacity on every upgraded bag the player carries.
-- Top level only: a bag stuffed inside another bag isn't reached, which is
-- fine because you can't wear one of those anyway.
local function reapplyAll(player)
    local inv = player:getInventory()
    if not inv then return end

    local list = inv:getItems()                      -- Java ArrayList, so 0-based
    for i = 0, list:size() - 1 do
        local item = list:get(i)
        if BPU.isBackpack(item) and BPU.getUpgradeCount(item) > 0 then
            BPU.applyCapacity(item)
        end
    end
end

-- Handle an "install" message from a client.
local function onInstall(player, args)
    if not args or not args.itemID then return end   -- malformed packet

    local item = findItemById(player, args.itemID)
    if not item then
        print("[BPU] server: no item with id " .. tostring(args.itemID) ..
              " on " .. tostring(player:getUsername()))
        return
    end

    if not BPU.isBackpack(item) then return end      -- wrong item type, ignore

    -- The count is absolute, not a delta, so handling the same message
    -- twice gives the same result. Clamp anyway -- it came off the network
    -- and the server shouldn't take a client's word for an arbitrary number.
    local count = tonumber(args.count) or 0
    if count < 0                then count = 0                end
    if count > BPU.MAX_UPGRADES then count = BPU.MAX_UPGRADES  end

    local md = item:getModData()
    md.bpuBaseCap = tonumber(args.baseCap) or BPU.getBaseCapacity(item)  -- client's reading wins
    md.bpuCount   = count

    BPU.applyCapacity(item)                          -- apply on the saved copy

    print("[BPU] server: id=" .. tostring(args.itemID) ..
          " user=" .. tostring(player:getUsername()) ..
          " count=" .. tostring(md.bpuCount) ..
          " base=" .. tostring(md.bpuBaseCap) ..
          " capacity=" .. tostring(item:getCapacity()))
end

-- Every sendClientCommand from any client lands here.
local function onClientCommand(module, command, player, args)
    if module ~= BPU.MODULE then return end          -- some other mod's traffic
    if not player then return end

    if command == "install" then
        onInstall(player, args)
    elseif command == "reapply" then                 -- sent by the client after login
        reapplyAll(player)
        print("[BPU] server: reapplied bags for " .. tostring(player:getUsername()))
    end
end

Events.OnClientCommand.Add(onClientCommand)
