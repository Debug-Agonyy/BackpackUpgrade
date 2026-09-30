-- BPU_Menu.lua
-- Client side: the right-click option, the local capacity change so the
-- UI reacts instantly, and the message that tells the server to record
-- the same thing on its own copy of the bag.
--
-- Why the server message is necessary: Project Zomboid does NOT
-- synchronise item mod data between client and server automatically.
-- A client-side write lives only in this session's memory, so it is gone
-- the moment you reconnect and the server hands you its copy back.

require "BPU_Core"

-- sendClientCommand exists in two shapes depending on build:
--     sendClientCommand(player, module, command, args)
--     sendClientCommand(module, command, args)
-- We tested both on 42.21 and BOTH delivered, which is why the server log
-- printed every line twice. The 4-argument form is the one kept, since it
-- names the player explicitly instead of relying on the engine to infer it.
-- The pcall stays as a guard: if a future build removes this overload, the
-- error is swallowed instead of breaking the whole install action.
local function sendToServer(player, command, args)
    if not isClient() then return end   -- singleplayer has no server to tell

    pcall(function() sendClientCommand(player, BPU.MODULE, command, args) end)
end

local function findUpgradeItem(player)
    return player:getInventory():FindAndReturn("Base.BackpackUpgrade")
end

local function onInstallUpgrade(player, bag)
    local inv = player:getInventory()
    local upgrade = findUpgradeItem(player)
    if not upgrade then return end
    if not BPU.canUpgrade(bag) then return end

    -- Work out the new state locally first.
    local base     = BPU.getBaseCapacity(bag)
    local newCount = BPU.getUpgradeCount(bag) + 1

    local md = bag:getModData()
    md.bpuBaseCap = base
    md.bpuCount   = newCount

    BPU.applyCapacity(bag)

    -- Tell the server the ABSOLUTE new state, not "add one". If the
    -- message arrives twice, or arrives late, the result is identical.
    -- getID() is the item's unique id; the server's copy of the same
    -- item carries the same id, which is how it finds it again.
    sendToServer(player, "install", {
        itemID  = bag:getID(),
        count   = newCount,
        baseCap = base,
    })

    -- Consume the upgrade item. Ordinary inventory changes DO sync to
    -- the server on their own; it is only mod data that does not.
    inv:DoRemoveItem(upgrade)

    player:Say("Backpack upgraded. Capacity now " .. tostring(bag:getCapacity()))
end

local function onFillInventoryObjectContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)

    for _, entry in ipairs(items) do
        -- The items list is inconsistent: sometimes an InventoryItem
        -- directly, sometimes a wrapper table with an .items array when
        -- identical items are stacked. Handle both.
        local item = entry
        if not instanceof(entry, "InventoryItem") then
            item = entry.items[1]
        end

        if item and BPU.canUpgrade(item) then
            local option = context:addOption("Install Backpack Upgrade", player, onInstallUpgrade, item)

            -- Grey the option out rather than hiding it when the player
            -- has no upgrade item, so they can see the action exists.
            if not findUpgradeItem(player) then
                option.notAvailable = true
            end
            return
        end
    end
end

-- After login, rebuild capacity on every bag the player is carrying.
-- The upgrade count survived in mod data; capacity did not, because it
-- resets to the item script's value whenever the item is loaded.
--
-- OnCreatePlayer fires before the inventory has finished populating, so
-- a one-shot tick handler waits a couple of seconds before looking.
local reapplyTicks = 0
local function reapplyTick()
    reapplyTicks = reapplyTicks + 1
    if reapplyTicks < 150 then return end   -- roughly 2.5s at 60fps

    Events.OnTick.Remove(reapplyTick)

    local player = getPlayer()
    if not player then return end

    local list = player:getInventory():getItems()
    for i = 0, list:size() - 1 do
        local item = list:get(i)
        if BPU.isBackpack(item) then
            local md = item:getModData()
            print("[BPU] client reapply: " .. tostring(item:getFullType()) ..
                  " id=" .. tostring(item:getID()) ..
                  " count=" .. tostring(md.bpuCount) ..
                  " base=" .. tostring(md.bpuBaseCap) ..
                  " capacity=" .. tostring(item:getCapacity()))
            BPU.applyCapacity(item)
        end
    end

    -- Ask the server to do the same on its side, so its copy of each bag
    -- agrees about how much fits. Without this the server would still
    -- think the bag holds its original amount until someone upgrades again.
    sendToServer(player, "reapply", { ping = 1 })
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)
Events.OnCreatePlayer.Add(function()
    reapplyTicks = 0
    Events.OnTick.Add(reapplyTick)
end)
