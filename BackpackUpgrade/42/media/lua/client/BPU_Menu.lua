-- BPU_Menu.lua -- client side: right-click option, instant UI feedback,
-- and the message that tells the server to record the same change.

require "BPU_Core"                                  -- pulls in the shared rules (BPU table)

-- Send a command to the server. Client-only: singleplayer has no server.
local function sendToServer(player, command, args)
    if not isClient() then return end               -- singleplayer, nobody to tell
    -- pcall guards against this overload vanishing in a future build
    pcall(function() sendClientCommand(player, BPU.MODULE, command, args) end)
end

-- First upgrade item found anywhere in the player's inventory, or nil.
local function findUpgradeItem(player)
    return player:getInventory():FindAndReturn("Base.BackpackUpgrade")
end

-- Runs when the player clicks the context-menu option.
local function onInstallUpgrade(player, bag)
    local inv     = player:getInventory()           -- needed later to consume the item
    local upgrade = findUpgradeItem(player)         -- the kit being spent
    if not upgrade then return end                  -- nothing to install
    if not BPU.canUpgrade(bag) then return end      -- already at the cap

    local base     = BPU.getBaseCapacity(bag)       -- capacity before any upgrades
    local newCount = BPU.getUpgradeCount(bag) + 1   -- absolute new count, not a delta

    local md = bag:getModData()                     -- per-item storage that persists
    md.bpuBaseCap = base                            -- remember the original number
    md.bpuCount   = newCount                        -- remember how many are installed

    BPU.applyCapacity(bag)                          -- apply locally so the UI updates now

    -- Mod data does NOT sync to the server on its own, so tell it explicitly.
    -- Absolute values mean a duplicated packet changes nothing.
    sendToServer(player, "install", {
        itemID  = bag:getID(),                      -- same id identifies the server's copy
        count   = newCount,
        baseCap = base,
    })

    inv:DoRemoveItem(upgrade)                       -- consume the kit (this DOES sync)
    player:Say("Backpack upgraded. Capacity now " .. tostring(bag:getCapacity()))
end

-- Builds the right-click menu entry when the player clicks an inventory item.
local function onFillInventoryObjectContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)     -- who opened the menu

    for _, entry in ipairs(items) do
        local item = entry                          -- usually an InventoryItem...
        if not instanceof(entry, "InventoryItem") then
            item = entry.items[1]                   -- ...but a wrapper table when stacked
        end

        if item and BPU.canUpgrade(item) then       -- a bag with room for another upgrade
            local option = context:addOption("Install Backpack Upgrade", player, onInstallUpgrade, item)

            if not findUpgradeItem(player) then     -- no kit on hand
                option.notAvailable = true          -- grey it out instead of hiding it
            end
            return                                  -- one option per menu, stop here
        end
    end
end

-- Capacity is a runtime value that resets to the item script's number on
-- every load, so it has to be rebuilt from the stored count after login.
local reapplyTicks = 0                              -- frame counter for the delay below

local function reapplyTick()
    reapplyTicks = reapplyTicks + 1
    if reapplyTicks < 150 then return end           -- wait ~2.5s; inventory isn't ready at login

    Events.OnTick.Remove(reapplyTick)               -- one-shot, unhook immediately

    local player = getPlayer()
    if not player then return end

    local list = player:getInventory():getItems()   -- Java ArrayList, so 0-based
    for i = 0, list:size() - 1 do
        local item = list:get(i)
        if BPU.isBackpack(item) then
            local md = item:getModData()
            print("[BPU] client reapply: " .. tostring(item:getFullType()) ..
                  " id=" .. tostring(item:getID()) ..
                  " count=" .. tostring(md.bpuCount) ..
                  " base=" .. tostring(md.bpuBaseCap) ..
                  " capacity=" .. tostring(item:getCapacity()))
            BPU.applyCapacity(item)                 -- rebuild capacity from the stored count
        end
    end

    sendToServer(player, "reapply", { ping = 1 })   -- have the server rebuild its copies too
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)
Events.OnCreatePlayer.Add(function()
    reapplyTicks = 0                                -- reset in case of a second spawn
    Events.OnTick.Add(reapplyTick)
end)
