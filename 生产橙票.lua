--[=====[
[[SND Metadata]]
author: 'pot0to (https://ko-fi.com/pot0to) || Maintainer: Minnu (https://ko-fi.com/minnuverse) || Contributor: Ice, Allison'
version: 2.0.6
description: >
  Crafter Scrips - Script for Crafting & Turning In

  7.3还未测试
  
  添加了进部队房的选项，需要进房子的话要自己在lifestream中设置一下

  增加了游末邦作为票据兑换的城市

  工票交易只有高浓缩炼金药经过测试是没问题的，其他需要自己测试一下

  材料需要自行准备

  自动雇员和军队模块都没经过测试

plugin_dependencies:
- Artisan
- Lifestream
- vnavmesh
configs:
  CrafterClass:
    default: 烹调师
    description: Select the crafting class to use for turn-ins and crafting tasks.
    type: string
  ScripColor:
    default: Purple
    description: Type of scrip to use for crafting / purchases (Orange, Purple).
    type: string
  ArtisanListId:
    default: 1
    description: Id of Artisan list for crafting all the intermediate materials (eg black star, claro walnut lumber, etc.).
    type: string
  ItemToBuy:
    default: 石匠研磨剂
    description: Name of the item to purchase using scrips.
    type: string
  HomeCommand:
    default: fc
    description: 填写Inn或Home或fc 选择在制作时进入旅馆、个人房、部队房
    type: string
  HubCity:
    default: 游末邦
    description: Main city to use as a hub for turn-ins and purchases.
    type: string
  Potion:
    default: true
    description: Use Potion (Supports only Superior Spiritbond Potion <hq>)
    type: boolean
  Retainers:
    default: false
    description: Automatically interact with retainers for ventures.
    type: boolean
  GrandCompanyTurnIn:
    default: false
    description: Do Grand Company TurnIns.
    type: boolean
  MinInventoryFreeSlots:
    default: 5
    description: Minimum free inventory slots required to start crafting or turn-ins.
    type: number
  SkystellToolsUnlocked:
    default: 1
    description: Have you unlocked skysteel tools?是否已经解锁了天钢工具材料的兑换，是填1，否填0
    type: number
  DebugMode:
    default: 0
    description: Enable debug mode (0 = off, 1 = on)
    type: number

[[End Metadata]]
--]=====]

--[[

********************************************************************************
*                    Crafter Scrips (Solution Nine Patch 7.3)                  *
*                                Version 2.0.6                                 *
********************************************************************************

Created by: pot0to (https://ko-fi.com/pot0to)
Updated by: Minnu, Ice, Allison

Crafts orange scrip item matching whatever class you're on, turns it in, buys
stuff, repeat.

    -> 2.0.6    Added debug mode for better script state tracking
    -> 2.0.5    Updated config and Made `HobCity` a dropdown selectable
    -> 2.0.4    Add config for home, add config for Skystell Tools Unlock, Made `Home Command` a dropdown selectable
    -> 2.0.3    Updated to SND 13.41 (fixed the config settings)
    -> 2.0.2    Updated for Patch 7.3
    -> 2.0.1    Fixed Potions
    -> 2.0.0    Updated to SND v2
    -> 0.5.7    Add nil checks and logging to mats and crystals check
                Added max purchase quantity check
                Fixed purple scrip selector for turn in
                Wait while Artisan Endurance is active, click menus once for
                    scrip exchange
                Fixes for some stuff
                Fixed Deliveroo interrupt
                Fixed name of Artful Afflatus Ring
                Added feature to purchase items that can only be bought one at a
                    time, such as gear
                Fixed purple scrip turn ins (credit: Telain)
                Added purple scrips, fixed /li inn
                Added HQ item count to out of materials check, continue turn in
                    items after dumping scrips
                Fixed up some bugs
                Fixed out of crystals check if recipe only needs one type of
                    crystal, added option to select what you want to buy with
                    scrips
                Added check for ArtisanX crafting
                Fixed some bugs with stop condition
                Stops script when you're out of mats
                Fixed some bugs related to /li inn

********************************************************************************
*                               Required Plugins                               *
********************************************************************************

1. SND
2. Artisan
3. Vnavmesh
4. Optional: Lifestream (for hiding in inn)

--------------------------------------------------------------------------------------------------------------------------------------------------------------
]]

--#region Settings

--[[
********************************************************************************
*                                   Settings                                   *
********************************************************************************

]]

import("System.Numerics")

CrafterClass                = Config.Get("CrafterClass")
ScripColor                  = Config.Get("ScripColor")
ArtisanListId               = Config.Get("ArtisanListId")
ItemToBuy                   = Config.Get("ItemToBuy")
HomeCommand                 = Config.Get("HomeCommand")
HubCity                     = Config.Get("HubCity")
Potion                      = Config.Get("Potion")
Retainers                   = Config.Get("Retainers")
GrandCompanyTurnIn          = Config.Get("GrandCompanyTurnIn")
MinInventoryFreeSlots       = Config.Get("MinInventoryFreeSlots")
SkystellToolsUnlocked       = Config.Get("SkystellToolsUnlocked")
DebugMode                   = Config.Get("DebugMode")

-- Debug logging function
function DebugLog(message)
    if DebugMode == 1 then
        yield("/echo [DEBUG] " .. message)
    end
end

-- IMPORTANT: Your scrip exchange list may be different depending on whether
-- you've unlocked Skystell tools. Please make sure the menu item #s match what
-- you have in game.
ScripExchangeItems = {
    {
        itemName        = "石匠研磨剂",
        categoryMenu    = 1,
        subcategoryMenu = 9 + SkystellToolsUnlocked,
        listIndex       = 0,
        price           = 500
    },
    {
        itemName        = "高浓缩炼金药",
        categoryMenu    = 1,
        subcategoryMenu = 10 + SkystellToolsUnlocked,
        listIndex       = 5,
        price           = 125
    },
    {
        itemName        = "名匠魔晶石拾贰型",
        categoryMenu    = 2,
        subcategoryMenu = 2,
        listIndex       = 0,
        price           = 500
    },
    {
        itemName        = "魔匠魔晶石拾贰型",
        categoryMenu    = 2,
        subcategoryMenu = 2,
        listIndex       = 1,
        price           = 500
    },
    {
        itemName        = "巨匠魔晶石拾贰型",
        categoryMenu    = 2,
        subcategoryMenu = 2,
        listIndex       = 2,
        price           = 500
    },
    {
        itemName        = "名匠魔晶石拾壹型",
        categoryMenu    = 2,
        subcategoryMenu = 1,
        listIndex       = 0,
        price           = 250
    },
    {
        itemName        = "魔匠魔晶石拾壹型",
        categoryMenu    = 2,
        subcategoryMenu = 1,
        listIndex       = 1,
        price           = 250
    },
    {
        itemName        = "巨匠魔晶石拾壹型",
        categoryMenu    = 2,
        subcategoryMenu = 1,
        listIndex       = 2,
        price           = 250
    },
    {
        itemName        = "灵感巧匠戒指",
        categoryMenu    = 0,
        subcategoryMenu = 10,
        listIndex       = 24,
        price           = 75,
        oneAtATime      = true
    }
}

--#endregion Settings

--[[
********************************************************************************
*            Code: Don't touch this unless you know what you're doing          *
********************************************************************************
]]

OrangeCrafterScripId = 41784

OrangeScripRecipes = {
    {
        className  = "刻木匠",
        classId    = 8,
        itemName   = "Rarefied Claro Walnut Fishing Rod",
        itemId     = 44190,
        recipeId   = 35787
    },
    {
        className  = "锻铁匠",
        classId    = 9,
        itemName   = "Rarefied Ra'Kaznar Round Knife",
        itemId     = 44196,
        recipeId   = 35793
    },
    {
        className  = "铸甲匠",
        classId    = 10,
        itemName   = "Rarefied Ra'Kaznar Ring",
        itemId     = 44202,
        recipeId   = 35799
    },
    {
        className  = "雕金匠",
        classId    = 11,
        itemName   = "Rarefied Black Star Earrings",
        itemId     = 44208,
        recipeId   = 35805
    },
    {
        className  = "制革匠",
        classId    = 12,
        itemName   = "Rarefied Gargantuaskin Hat",
        itemId     = 44214,
        recipeId   = 35817
    },
    {
        className  = "裁衣匠",
        classId    = 13,
        itemName   = "Rarefied Thunderyard Silk Culottes",
        itemId     = 44220,
        recipeId   = 35817
    },
    {
        className  = "炼金术士",
        classId    = 14,
        itemName   = "Rarefied Claro Walnut Flat Brush",
        itemId     = 44226,
        recipeId   = 35823
    },
    {
        className  = "烹调师",
        classId    = 15,
        itemName   = "Rarefied Tacos de Carne Asada",
        itemId     = 44232,
        recipeId   = 35829
    }
}

PurpleCrafterScripId = 33913

PurpleScripRecipes = {
    {
        className  = "刻木匠",
        classId    = 8,
        itemName   = "Rarefied Claro Walnut Grinding Wheel",
        itemId     = 44189,
        recipeId   = 35786
    },
    {
        className  = "锻铁匠",
        classId    = 9,
        itemName   = "Rarefied Ra'Kaznar War Scythe",
        itemId     = 44195,
        recipeId   = 35792
    },
    {
        className  = "铸甲匠",
        classId    = 10,
        itemName   = "Rarefied Ra'Kaznar Greaves",
        itemId     = 44201,
        recipeId   = 35798
    },
    {
        className  = "雕金匠",
        classId    = 11,
        itemName   = "Rarefied Ra'Kaznar Orrery",
        itemId     = 44207,
        recipeId   = 35804
    },
    {
        className  = "制革匠",
        classId    = 12,
        itemName   = "Rarefied Gargantuaskin Trouser",
        itemId     = 44213,
        recipeId   = 35816
    },
    {
        className  = "裁衣匠",
        classId    = 13,
        itemName   = "Rarefied Thunderyards Silk Gloves",
        itemId     = 44219,
        recipeId   = 35816
    },
    {
        className  = "炼金术士",
        classId    = 14,
        itemName   = "Rarefied Gemdraught of Vitality",
        itemId     = 44225,
        recipeId   = 35822
    },
    {
        className  = "烹调师",
        classId    = 15,
        itemName   = "Rarefied Stuffed Peppers",
        itemId     = 44231,
        recipeId   = 35828
    }
}

HubCities = {
    {
        zoneName = "Limsa",
        zoneId = 129,
        aethernet = {
            aethernetZoneId = 129,
            aethernetName   = "Hawkers' Alley",
            x = -213.61108, y = 16.739136, z = 51.80432
        },
        retainerBell  = { x = -124.703, y = 18, z = 19.887, requiresAethernet = false },
        scripExchange = { x = -258.52585, y = 16.2, z = 40.65883, requiresAethernet = true }
    },
    {
        zoneName = "Gridania",
        zoneId = 132,
        aethernet = {
            aethernetZoneId = 133,
            aethernetName   = "Leatherworkers' Guild & Shaded Bower",
            x = 131.9447, y = 4.714966, z = -29.800903
        },
        retainerBell  = { x = 168.72, y = 15.5, z = -100.06, requiresAethernet = true },
        scripExchange = { x = 142.15, y = 13.74, z = -105.39, requiresAethernet = true }
    },
    {
        zoneName = "Ul'dah",
        zoneId = 130,
        aethernet = {
            aethernetZoneId = 131,
            aethernetName   = "Sapphire Avenue Exchange",
            x = 101, y = 9, z = -112
        },
        retainerBell  = { x = 146.760, y = 4, z = -42.992, requiresAethernet = true },
        scripExchange = { x = 147.73, y = 4, z = -18.19, requiresAethernet = true }
    },
    {
        zoneName = "Solution Nine",
        zoneId = 1186,
        aethernet = {
            aethernetZoneId = 1186,
            aethernetName   = "Nexus Arcade",
            x = -161, y = -1, z = 21
        },
        retainerBell  = { x = -152.465, y = 0.660, z = -13.557, requiresAethernet = true },
        scripExchange = { x = -158.019, y = 0.922, z = -37.884, requiresAethernet = true }
    },
    {
        zoneName = "游末邦",
        zoneId = 820,
        aethernet = {
            aethernetZoneId = 820,
            aethernetName   = "游末邦",
            x = 2.2500746, y = 82, z = -0.35018417  -- 需要填写实际的以太之光坐标
        },
        retainerBell  = { x = 7.343, y = 82.050, z = 30.518, requiresAethernet = false },
        scripExchange = { x = 16.979, y = 82.050, z = -19.189, requiresAethernet = false }
    }
}

ClassList = {
    crp = { classId =  8, className = "刻木匠"      },
    bsm = { classId = 14, className = "锻铁匠"     },
    arm = { classId = 13, className = "铸甲匠"        },
    gsm = { classId = 16, className = "雕金匠"      },
    ltw = { classId = 12, className = "制革匠"  },
    wvr = { classId = 13, className = "裁衣匠"         },
    alc = { classId = 14, className = "炼金术士"      },
    cul = { classId = 15, className = "烹调师"     }
}

CharacterCondition = {
    craftingMode                        =  5,
    casting                             = 27,
    occupiedInQuestEvent                = 32,
    occupiedMateriaExtractionAndRepair  = 39,
    executingCraftingSkill              = 40,
    craftingModeIdle                    = 41,
    betweenAreas                        = 45,
    occupiedSummoningBell               = 50,
    beingMoved                          = 70
}

function GetTargetName()
    return Entity.Target and Entity.Target.Name or ""
end


function TeleportTo(aetheryteName)
    DebugLog("Teleporting to: " .. aetheryteName)
    yield("/li tp "..aetheryteName)
    yield("/wait 1") -- wait for casting to begin
    while Svc.Condition[CharacterCondition.casting] do
        DebugLog("Casting teleport...")
        yield("/wait 1")
    end
    yield("/wait 1") -- wait for that microsecond in between the cast finishing and the transition beginning
    while Svc.Condition[CharacterCondition.betweenAreas] do
        DebugLog("Teleporting...")
        yield("/wait 1")
    end
    yield("/wait 1")
end

function GetDistanceToPoint(dX, dY, dZ)
    DebugLog(string.format("Calculating distance to point (%.2f, %.2f, %.2f)", dX, dY, dZ))
    local player = Svc.ClientState.LocalPlayer
    if not player or not player.Position then
        DebugLog("Player position not available")
        return math.huge
    end

    local px = player.Position.X
    local py = player.Position.Y
    local pz = player.Position.Z

    local dx = dX - px
    local dy = dY - py
    local dz = dZ - pz

    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
    DebugLog(string.format("Distance to point: %.2f", distance))
    return distance
end

function GetDistanceToTarget()
    if not Entity or not Entity.Player then
        DebugLog("Entity or Player not available")
        return nil
    end

    if not Entity.Target then
        DebugLog("No target available")
        return nil
    end

    -- Retrieve positions
    local playerPos = Entity.Player.Position
    local targetPos = Entity.Target.Position

    -- Calculate the distance manually using Euclidean formula
    local dx = playerPos.X - targetPos.X
    local dy = playerPos.Y - targetPos.Y
    local dz = playerPos.Z - targetPos.Z

    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
    DebugLog(string.format("Distance to target: %.2f", distance))
    return distance
end

function DistanceBetween(px1, py1, pz1, px2, py2, pz2)
    local dx = px2 - px1
    local dy = py2 - py1
    local dz = pz2 - pz1

    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
    DebugLog(string.format("Distance between points: %.2f", distance))
    return distance
end

function HasStatusId(targetId)
    DebugLog("Checking for status ID: " .. targetId)
    local statusList = Player.Status

    if not statusList then
        DebugLog("Status list not available")
        return false
    end

    for i = 0, statusList.Count - 1 do
        local status = statusList:get_Item(i)

        if status and status.StatusId == targetId then
            DebugLog("Status found: " .. targetId)
            return true
        end
    end

    DebugLog("Status not found: " .. targetId)
    return false
end

function OutOfCrystals()
    DebugLog("Checking if out of crystals")
    local crystalsRequired1 = tonumber(Addons.GetAddon("RecipeNote"):GetNode(1, 57, 83, 2).Text)
    local crystalsInInventory1 = tonumber(Addons.GetAddon("RecipeNote"):GetNode(1, 57, 83, 3).Text)
    if crystalsRequired1 ~= nil and crystalsInInventory1 ~= nil and crystalsRequired1 > crystalsInInventory1 then
        DebugLog("Out of first crystal type")
        return true
    end

    local crystalsRequired2 = tonumber(Addons.GetAddon("RecipeNote"):GetNode(1, 57, 82, 2).Text)
    local crystalsInInventory2 = tonumber(Addons.GetAddon("RecipeNote"):GetNode(1, 57, 82, 3).Text)
    if crystalsRequired2 ~= nil and crystalsInInventory2 ~= nil and crystalsRequired2> crystalsInInventory2 then
        DebugLog("Out of second crystal type")
        return true
    end

    DebugLog("Crystals available")
    return false
end

function OutOfMaterials()
    DebugLog("Checking if out of materials")
    while not Addons.GetAddon("RecipeNote").Ready do
        DebugLog("RecipeNote not ready, waiting...")
        yield("/wait 0.1")
    end

    for i = 0, 5 do
        local materialCountNQ = Addons.GetAddon("RecipeNote"):GetNode(1, 57, 88, 89 + i, 10, 12).Text
        local materialCountHQ = Addons.GetAddon("RecipeNote"):GetNode(1, 57, 88, 89 + i, 13, 15).Text
        local materialRequirement = Addons.GetAddon("RecipeNote"):GetNode(1, 57, 88, 89 + i, 4).Text
        if materialCountNQ ~= "" and materialCountHQ ~= "" and materialRequirement ~= "" and
            materialCountNQ ~= nil and materialCountHQ ~= nil and materialRequirement ~= nil
        then
            DebugLog(string.format("Material %d: NQ=%s, HQ=%s, Required=%s", i, materialCountNQ, materialCountHQ, materialRequirement))
            if tonumber(materialCountNQ) + tonumber(materialCountHQ) < tonumber(materialRequirement) then
                DebugLog("Out of material: " .. i)
                return true
            end
        end
    end

    DebugLog("Regular mats available. Checking crystals.")

    if OutOfCrystals() then
        DebugLog("Out of crystals. Stopping script.")
        yield("/echo [CraftersScrips] Out of crystals. Stopping script.")
        StopFlag = true
        return true
    end

    DebugLog("All mats and crystals available.")
    return false
end

function HasPlugin(name)
    DebugLog("Checking for plugin: " .. name)
    for plugin in luanet.each(Svc.PluginInterface.InstalledPlugins) do
        if plugin.InternalName == name and plugin.IsLoaded then
            DebugLog("Plugin found: " .. name)
            return true
        end
    end

    DebugLog("Plugin not found: " .. name)
    return false
end

function Crafting()
    DebugLog("Entering Crafting state")
        if IPC.Lifestream.IsBusy() or Svc.Condition[CharacterCondition.occupiedInQuestEvent] then
            DebugLog("Lifestream busy or occupied in quest event")
            yield("/wait 1")
            return
        elseif not AtInn and HomeCommand == "Inn" then
            DebugLog("Moving to Inn")
            IPC.Lifestream.ExecuteCommand(HomeCommand)
            while IPC.Lifestream.IsBusy() do
                DebugLog("Waiting for Lifestream to finish")
                yield("/wait 1")
            end
            AtInn = true
            return
        elseif not  AtHome  and (HomeCommand == "Home" or HomeCommand == "fc") then
            DebugLog("Moving to Home/fc")
            IPC.Lifestream.ExecuteCommand(HomeCommand)
            while IPC.Lifestream.IsBusy() do
                DebugLog("Waiting for Lifestream to finish")
                yield("/wait 1")
            end
            AtHome = true
            return
        end
    local slots = Inventory.GetFreeInventorySlots()
    DebugLog("Free inventory slots: " .. (slots or "nil"))
    if IPC.Artisan.GetEnduranceStatus() then
        DebugLog("Artisan endurance active")
        return
    elseif slots == nil then
        DebugLog("GetFreeInventorySlots() is nil")
        yield("/echo [CraftersScrips] GetFreeInventorySlots() is nil. WHYYY???")
    elseif not Dalamud.Log("[CraftersScrips] Check Artisan running") and (IPC.Artisan.IsListRunning() and not IPC.Artisan.IsListPaused()) or Addons.GetAddon("Synthesis").Ready then
        DebugLog("Artisan running or Synthesis ready")
        yield("/wait 1")
    elseif not Dalamud.Log("[CraftersScrips] Check slots count") and slots <= MinInventoryFreeSlots then
        DebugLog("Out of inventory space")
        Dalamud.Log("[CraftersScrips] Out of inventory space")
        if Addons.GetAddon("RecipeNote").Ready then
            yield("/callback RecipeNote true -1")
        elseif not Svc.Condition[CharacterCondition.craftingMode] then
            State = CharacterState.turnIn
            DebugLog("State Change: TurnIn")
            Dalamud.Log("[CraftersScrips] State Change: TurnIn")
        end
    elseif not Dalamud.Log("[CraftersScrips] Check out of materials") and Addons.GetAddon("RecipeNote").Ready and OutOfMaterials() then
        DebugLog("Out of materials")
        Dalamud.Log("[CraftersScrips] Out of materials")
        if not StopFlag then
            if slots > MinInventoryFreeSlots and (ArtisanTimeoutStartTime == 0) then
                DebugLog("Attempting to craft intermediate materials")
                Dalamud.Log("[CraftersScrips] Attempting to craft intermediate materials")
                yield("/artisan lists "..ArtisanListId.." start")
                ArtisanTimeoutStartTime = os.clock()
            elseif Inventory.GetCollectableItemCount(ItemId, 1) > 0 then
                DebugLog("Turning In")
                Dalamud.Log("[CraftersScrips] Turning In")
                yield("/callback RecipeNote true -1")
                State = CharacterState.turnIn
                DebugLog("State Change: TurnIn")
                Dalamud.Log("[CraftersScrips] State Change: TurnIn")
            elseif os.clock() - ArtisanTimeoutStartTime > 5 then
                DebugLog("Artisan not starting, StopFlag = true")
                Dalamud.Log("[CraftersScrips] Artisan not starting, StopFlag = true")
                -- if artisan has not entered crafting mode within 15s of being called,
                -- then you're probably out of mats so just stop the script
                yield("/echo [CraftersScrips] Artisan took too long to start. Are you out of intermediate mat materials?")
                StopFlag = true
            end
        end
    elseif not Dalamud.Log("[CraftersScrips] Check new Artisan craft") and not Addons.GetAddon("Synthesis").Ready then -- Svc.Condition[CharacterCondition.craftingMode] then
        DebugLog("Attempting to craft "..(slots - MinInventoryFreeSlots).." of recipe #"..RecipeId)
        Dalamud.Log("[CraftersScrips] Attempting to craft "..(slots - MinInventoryFreeSlots).." of recipe #"..RecipeId)
        ArtisanTimeoutStartTime = 0
        IPC.Artisan.CraftItem(RecipeId, slots - MinInventoryFreeSlots)
        yield("/wait 5")
    else
        DebugLog("Else condition hit")
        Dalamud.Log("[CraftersScrips] Else condition hit")
    end
end

function GoToHubCity()
    DebugLog("Entering GoToHubCity state")
    if not Player.Available then
        DebugLog("Player not available")
        yield("/wait 1")
    elseif  Svc.ClientState.TerritoryType ~= SelectedHubCity.zoneId then
        DebugLog("Teleporting to hub city")
        TeleportTo(SelectedHubCity.aetheryte)
    else
        State = CharacterState.ready
        DebugLog("State Change: Ready")
        Dalamud.Log("[CraftersScrips] State Change: Ready")
    end
end

function TurnIn()
    DebugLog("Entering TurnIn state")
    AtInn = false
    AtHome = false
    INHOME = false
        if Inventory.GetCollectableItemCount(ItemId, 1) == 0 or Inventory.GetItemCount(CrafterScripId) >= 3800 then
            DebugLog("No collectables or scrips full")
            if Addons.GetAddon("CollectablesShop").Ready then
                yield("/callback CollectablesShop true -1")
            else
                State = CharacterState.ready
                DebugLog("State Change: Ready")
                Dalamud.Log("[CraftersScrips] State Change: Ready")
            end
        elseif (Svc.ClientState.TerritoryType ~= SelectedHubCity.zoneId) and
            (not SelectedHubCity.scripExchange.requiresAethernet or 
            (SelectedHubCity.scripExchange.requiresAethernet and 
            Svc.ClientState.TerritoryType ~= SelectedHubCity.aethernet.aethernetZoneId))
        then
            State = CharacterState.goToHubCity
            DebugLog("State Change: GoToHubCity")
            Dalamud.Log("[CraftersScrips] State Change: GoToHubCity")
        elseif SelectedHubCity.scripExchange.requiresAethernet and (not Svc.ClientState.TerritoryType == SelectedHubCity.aethernet.aethernetZoneId or
            GetDistanceToPoint(SelectedHubCity.scripExchange.x, SelectedHubCity.scripExchange.y, SelectedHubCity.scripExchange.z) > DistanceBetween(SelectedHubCity.aethernet.x, SelectedHubCity.aethernet.y, SelectedHubCity.aethernet.z, SelectedHubCity.scripExchange.x, SelectedHubCity.scripExchange.y, SelectedHubCity.scripExchange.z) + 10) then
            DebugLog("Using aethernet to reach scrip exchange")
            if not IPC.Lifestream.IsBusy() and not Player.IsBusy then
                DebugLog("Executing Lifestream command: " .. SelectedHubCity.aethernet.aethernetName)
                IPC.Lifestream.ExecuteCommand(SelectedHubCity.aethernet.aethernetName)
                yield("/wait 1")
            end
            yield("/wait 3")
        elseif Addons.GetAddon("TelepotTown").Ready then
            DebugLog("TelepotTown open")
            yield("/callback TelepotTown false -1")
        elseif GetDistanceToPoint(SelectedHubCity.scripExchange.x, SelectedHubCity.scripExchange.y, SelectedHubCity.scripExchange.z) > 1 then
            DebugLog("Moving to scrip exchange")
            if not IPC.vnavmesh.PathfindInProgress() and not IPC.vnavmesh.IsRunning() then
                DebugLog("Starting pathfinding to scrip exchange")
                IPC.vnavmesh.PathfindAndMoveTo(Vector3(SelectedHubCity.scripExchange.x, SelectedHubCity.scripExchange.y, SelectedHubCity.scripExchange.z), false)
            end
        else
            DebugLog("At scrip exchange location")
            if IPC.vnavmesh.PathfindInProgress() or IPC.vnavmesh.IsRunning() then
                DebugLog("Stopping pathfinding")
                IPC.vnavmesh.Stop()
            end

            if not Addons.GetAddon("CollectablesShop").Ready then
                DebugLog("Targeting 收藏品交易员")
                local appraiser = Entity.GetEntityByName("收藏品交易员")
                if appraiser then
                    appraiser:SetAsTarget()
                    appraiser:Interact()
                end
            else
                if ScripColor == "Purple" then
                    DebugLog("Selecting purple scrip item")
                    yield("/callback CollectablesShop true 12 1")
                    yield("/wait 0.5")
                end
                DebugLog("Selecting orange scrip item")
                yield("/callback CollectablesShop true 15 0")
                yield("/wait 1")
            end
        end
end

SelectTurnInPage = false
function ScripExchange()
    DebugLog("Entering ScripExchange state")
    if Inventory.GetItemCount(CrafterScripId) < SelectedItemToBuy.price or Inventory.GetFreeInventorySlots() <= MinInventoryFreeSlots then
        DebugLog("Not enough scrips or inventory full")
        if Addons.GetAddon("InclusionShop").Ready then
            yield("/callback InclusionShop true -1")
        elseif Inventory.GetCollectableItemCount(ItemId, 1) > 0 and Inventory.GetItemCount(CrafterScripId) < 3800 then
            SelectTurnInPage = false
            State = CharacterState.turnIn
            DebugLog("State Change: TurnIn")
            Dalamud.Log("[CraftersScrips] State Change: TurnIn")
        elseif Inventory.GetFreeInventorySlots() <= MinInventoryFreeSlots then
            SelectTurnInPage = false
            State = CharacterState.gcTurnIn
            DebugLog("State Change: GCTurnIn")
            Dalamud.Log("[CraftersScrips] State Change: GCTurnIn")
        else
            SelectTurnInPage = false
            State = CharacterState.ready
            DebugLog("State Change: Ready")
            Dalamud.Log("[CraftersScrips] State Change: Ready")
        end
    elseif  Svc.ClientState.TerritoryType ~= SelectedHubCity.zoneId and
        (not SelectedHubCity.scripExchange.requiresAethernet or (SelectedHubCity.scripExchange.requiresAethernet and not Svc.ClientState.TerritoryType == SelectedHubCity.aethernet.aethernetZoneId))
    then
        SelectTurnInPage = false
        State = CharacterState.goToHubCity
        DebugLog("State Change: GoToHubCity")
        Dalamud.Log("[CraftersScrips] State Change: GoToHubCity")
    elseif SelectedHubCity.scripExchange.requiresAethernet and (not Svc.ClientState.TerritoryType == SelectedHubCity.aethernet.aethernetZoneId or
        GetDistanceToPoint(SelectedHubCity.scripExchange.x, SelectedHubCity.scripExchange.y, SelectedHubCity.scripExchange.z) > DistanceBetween(SelectedHubCity.aethernet.x, SelectedHubCity.aethernet.y, SelectedHubCity.aethernet.z, SelectedHubCity.scripExchange.x, SelectedHubCity.scripExchange.y, SelectedHubCity.scripExchange.z) + 10) then
        DebugLog("Using aethernet to reach scrip exchange")
        if not IPC.Lifestream.IsBusy() then
            IPC.Lifestream.ExecuteCommand(SelectedHubCity.aethernet.aethernetName)
        end
        yield("/wait 3")
    elseif Addons.GetAddon("TelepotTown").Ready then
        DebugLog("TelepotTown open")
        yield("/callback TelepotTown true -1")
    elseif GetDistanceToPoint(SelectedHubCity.scripExchange.x, SelectedHubCity.scripExchange.y, SelectedHubCity.scripExchange.z) > 1 then
        DebugLog("Moving to scrip exchange")
        if not IPC.vnavmesh.PathfindInProgress() and not IPC.vnavmesh.IsRunning() then
            DebugLog("Starting pathfinding to scrip exchange")
            yield("/wait 3")
            IPC.vnavmesh.PathfindAndMoveTo(Vector3(SelectedHubCity.scripExchange.x, SelectedHubCity.scripExchange.y, SelectedHubCity.scripExchange.z), false)
        end
    elseif Addons.GetAddon("ShopExchangeItemDialog").Ready then
        DebugLog("ShopExchangeItemDialog open")
        yield("/callback ShopExchangeItemDialog true 0")
        yield("/wait 1")
    elseif Addons.GetAddon("SelectIconString").Ready then
        DebugLog("SelectIconString open")
        yield("/callback SelectIconString true 0")
    elseif Addons.GetAddon("InclusionShop").Ready then
        DebugLog("InclusionShop open, free slots: "..Inventory.GetFreeInventorySlots())

        if not SelectTurnInPage then
            DebugLog("Selecting category: "..SelectedItemToBuy.categoryMenu)
            yield("/callback InclusionShop true 12 "..SelectedItemToBuy.categoryMenu)   
            yield("/wait 1")
            DebugLog("Selecting subcategory: "..SelectedItemToBuy.subcategoryMenu)
            yield("/callback InclusionShop true 13 "..SelectedItemToBuy.subcategoryMenu)
            yield("/wait 1")
            SelectTurnInPage = true
        end
        local qty = 1
        if not SelectedItemToBuy.oneAtATime then
            qty = math.min(Inventory.GetItemCount(CrafterScripId)//SelectedItemToBuy.price, 99)
            DebugLog("Calculated quantity: "..qty)
        end
        DebugLog("Selecting item at index: "..SelectedItemToBuy.listIndex)
        yield("/callback InclusionShop true 14 "..SelectedItemToBuy.listIndex.." "..qty)
        yield("/wait 1")
    else
        DebugLog("Targeting 工票交易员")
        local scripExchange = Entity.GetEntityByName("工票交易员")
        if scripExchange then
            scripExchange:SetAsTarget()
            scripExchange:Interact()
        end
    end
end

function ProcessRetainers()
    DebugLog("Entering ProcessRetainers state")
    CurrentRetainer = nil

    DebugLog("Handling retainers...")
    if not Dalamud.Log("[CraftersScrips] check retainers ready") and not IPC.AutoRetainer.AreAnyRetainersAvailableForCurrentChara() or Inventory.GetFreeInventorySlots() <= 1 then
        DebugLog("No retainers available or inventory full")
        if Addons.GetAddon("RetainerList").Ready then
            yield("/callback RetainerList true -1")
        elseif not Svc.Condition[CharacterCondition.occupiedSummoningBell] then
            State = CharacterState.ready
            DebugLog("State Change: Ready")
            Dalamud.Log("[CraftersScrips] State Change: Ready")
        end
    else
        DebugLog("Retainers available")
        local summoningBell = Entity.GetEntityByName("Summoning Bell")
        if summoningBell then
            summoningBell:SetAsTarget()
        end
        yield("/wait 1")

        if summoningBell then
            if GetDistanceToTarget() > 5 then
                DebugLog("Moving to summoning bell")
                if not IPC.vnavmesh.IsRunning() and not IPC.vnavmesh.PathfindInProgress() then
                    IPC.vnavmesh.PathfindAndMoveTo(Vector3(Entity.Target.Position.X, Entity.Target.Position.Y, Entity.Target.Position.Z), false)
                end
            else
                DebugLog("At summoning bell")
                if IPC.vnavmesh.IsRunning() or IPC.vnavmesh.PathfindInProgress() then
                    IPC.vnavmesh.Stop()
                end
                if not Svc.Condition[CharacterCondition.occupiedSummoningBell] then
                    DebugLog("Interacting with summoning bell")
                    summoningBell:Interact()
                elseif Addons.GetAddon("RetainerList").Ready then
                    DebugLog("Processing retainers")
                    yield("/ays e")
                    if Echo == "All" then
                        yield("/echo [CraftersScrips] Processing retainers")
                    end
                    yield("/wait 1")
                end
            end
        elseif not Dalamud.Log("[CraftersScrips] is in hub city zone?") and not Svc.ClientState.TerritoryType == SelectedHubCity.zoneId and
            (not SelectedHubCity.scripExchange.requiresAethernet or (SelectedHubCity.scripExchange.requiresAethernet and not Svc.ClientState.TerritoryType == SelectedHubCity.aethernet.aethernetZoneId))
        then
            DebugLog("Teleporting to hub city")
            TeleportTo(SelectedHubCity.aetheryte)
        elseif not Dalamud.Log("[CraftersScrips] use aethernet?") and
            SelectedHubCity.retainerBell.requiresAethernet and (not Svc.ClientState.TerritoryType == SelectedHubCity.aethernet.aethernetZoneId or
            (GetDistanceToPoint(SelectedHubCity.retainerBell.x, SelectedHubCity.retainerBell.y, SelectedHubCity.retainerBell.z) > (DistanceBetween(SelectedHubCity.aethernet.x, SelectedHubCity.aethernet.y, SelectedHubCity.aethernet.z, SelectedHubCity.retainerBell.x, SelectedHubCity.retainerBell.y, SelectedHubCity.retainerBell.z) + 10)))
        then
            DebugLog("Using aethernet to reach retainer bell")
            if not IPC.Lifestream.IsBusy() then
                IPC.Lifestream.ExecuteCommand(SelectedHubCity.aethernet.aethernetName)
            end
            yield("/wait 3")
        elseif not Dalamud.Log("[CraftersScrips] Close teleport town") and Addons.GetAddon("TelepotTown").Ready then
            DebugLog("TeleportTown open")
            yield("/callback TelepotTown false -1")
        elseif not Dalamud.Log("[CraftersScrips] Move to summoning bell") and GetDistanceToPoint(SelectedHubCity.retainerBell.x, SelectedHubCity.retainerBell.y, SelectedHubCity.retainerBell.z) > 1 then
            DebugLog("Moving to retainer bell")
            if not IPC.vnavmesh.PathfindInProgress() and not  IPC.vnavmesh.IsRunning() then
                DebugLog("Starting pathfinding to retainer bell")
                IPC.vnavmesh.PathfindAndMoveTo(Vector3(SelectedHubCity.retainerBell.x, SelectedHubCity.retainerBell.y, SelectedHubCity.retainerBell.z), false)
            end
        elseif IPC.vnavmesh.PathfindInProgress() or IPC.vnavmesh.IsRunning() then
            DebugLog("Pathfinding in progress")
            return
        elseif not Entity.Target or Entity.Target.Name ~= "Summoning Bell" then
            DebugLog("Targeting summoning bell")
            if summoningBell then
                summoningBell:SetAsTarget()
            end
            return
        elseif not Svc.Condition[CharacterCondition.occupiedSummoningBell] then
            DebugLog("Interacting with summoning bell")
            if summoningBell then
                summoningBell:Interact()
            end
        elseif Addons.GetAddon("RetainerList").Ready then
            DebugLog("Enqueuing retainer initiation")
            IPC.AutoRetainer.EnqueueInitiation()
            if Echo == "All" then
                yield("/echo [CraftersScrips] Processing retainers")
            end
            yield("/wait 1")
        end
    end
end

local deliveroo = false
function ExecuteGrandCompanyTurnIn()
    DebugLog("Entering ExecuteGrandCompanyTurnIn state")
    if IPC.Deliveroo.IsTurnInRunning() then
        DebugLog("Deliveroo turn-in already running")
        return
    elseif Inventory.GetFreeInventorySlots() <= MinInventoryFreeSlots and not deliveroo then
        DebugLog("Starting GC turn-in")
        IPC.Lifestream.ExecuteCommand("gc")
        repeat
            yield("/wait 1")
        until not IPC.Lifestream.IsBusy()
        yield("/wait 1")
        yield("/deliveroo enable")
        yield("/wait 1")
        deliveroo = true
    else
        State = CharacterState.ready
        DebugLog("State Change: Ready")
        Dalamud.Log("[CraftersScrips] State Change: Ready")
        deliveroo = false
    end
end

function PotionCheck()
    DebugLog("Checking potion status")
    if not HasStatusId(49) and Potion then
        DebugLog("Using potion")
        local potion = Inventory.GetHqItemCount(27960)

        if potion > 0 then
            Inventory.GetInventoryItem(27960):Use()
        else
            DebugLog("HQ Potion not found in inventory")
            LogDebug("[CraftersScrips] [PotionCheck] HQ Potion not found in inventory.")
        end
    else
        DebugLog("Potion not needed or already active")
    end
end

function Ready()
    DebugLog("Entering Ready state")
    PotionCheck()

    if not Player.Available then
        DebugLog("Player not available")
        -- do nothing
    elseif Retainers and IPC.AutoRetainer.AreAnyRetainersAvailableForCurrentChara() and Inventory.GetFreeInventorySlots() > 1 then
        State = CharacterState.processRetainers
        DebugLog("State Change: ProcessingRetainers")
        Dalamud.Log("[CraftersScrips] State Change: ProcessingRetainers")
    elseif Inventory.GetItemCount(CrafterScripId) >= 3800 then
        State = CharacterState.scripExchange
        DebugLog("State Change: ScripExchange")
        Dalamud.Log("[CraftersScrips] State Change: ScripExchange")
    elseif Inventory.GetFreeInventorySlots() <= MinInventoryFreeSlots and Inventory.GetCollectableItemCount(ItemId, 1) > 0 then
        State = CharacterState.turnIn
        DebugLog("State Change: TurnIn")
        Dalamud.Log("[CraftersScrips] State Change: TurnIn")
    elseif GrandCompanyTurnIn and Inventory.GetFreeInventorySlots() <= MinInventoryFreeSlots then
        State = CharacterState.gcTurnIn
        DebugLog("State Change: GCTurnIn")
        Dalamud.Log("[CraftersScrips] State Change: GCTurnIn")
    else
        State = CharacterState.crafting
        DebugLog("State Change: Crafting")
        Dalamud.Log("[CraftersScrips] State Change: Crafting")
    end
end

CharacterState =
{
    ready            = Ready,
    crafting         = Crafting,
    goToHubCity      = GoToHubCity,
    turnIn           = TurnIn,
    scripExchange    = ScripExchange,
    processRetainers = ProcessRetainers,
    gcTurnIn         = ExecuteGrandCompanyTurnIn
}

StopFlag = false

RequiredPlugins = {
    "Artisan",
    "vnavmesh"
}
-- add optional plugins
if HomeCommand == "Inn" or HomeCommand == "Home"or HomeCommand == "fc"then
    table.insert(RequiredPlugins, "Lifestream")
end
if Retainers then
    table.insert(RequiredPlugins, "AutoRetainer")
end
if GrandCompanyTurnIn then
    table.insert(RequiredPlugins, "Deliveroo")
end

for _, plugin in ipairs(RequiredPlugins) do
    if not HasPlugin(plugin) then
        yield("/e [CraftersScrips] Missing required plugin: "..plugin.."! Stopping script. Please install the required plugin and try again.")
        StopFlag = true
    end
end

local classId = 0
for _, class in pairs(ClassList) do
    if CrafterClass == class.className then
        classId = class.classId
    end
end

if classId == 0 then
    yield("/echo [CraftersScrips] Could not find crafter class: " .. CrafterClass)
    StopFlag = true
end

if ScripColor == "Orange" then
    CrafterScripId = OrangeCrafterScripId
    ScripRecipes = OrangeScripRecipes
elseif ScripColor == "Purple" then
    CrafterScripId = PurpleCrafterScripId
    ScripRecipes = PurpleScripRecipes
else
    yield("/echo [CraftersScrips] Cannot recognize crafter scrip color: "..ScripColor)
    StopFlag = true
end

ItemId = 0
RecipeId = 0
for _, data in ipairs(ScripRecipes) do
    if data.classId == classId then
        ItemId = data.itemId
        RecipeId = data.recipeId
    end
end

for _, item in ipairs(ScripExchangeItems) do
    if item.itemName == ItemToBuy then
        SelectedItemToBuy = item
    end
end

if SelectedItemToBuy == nil then
    yield("/echo [CraftersScrips] Could not find "..ItemToBuy.." on the list of scrip exchange items.")
    StopFlag = true
end

for _, city in ipairs(HubCities) do
    if city.zoneName == HubCity then
        SelectedHubCity = city
        SelectedHubCity.aetheryte = Excel.GetRow("TerritoryType", city.zoneId).Aetheryte.PlaceName.Name
    end
end

if SelectedHubCity == nil then
    yield("/echo [CraftersScrips] Could not find hub city: " .. HubCity)
    StopFlag = true
end

DebugLog("Script starting with configuration:")
DebugLog("CrafterClass: " .. CrafterClass)
DebugLog("ScripColor: " .. ScripColor)
DebugLog("ItemToBuy: " .. ItemToBuy)
DebugLog("HubCity: " .. HubCity)
DebugLog("DebugMode: " .. DebugMode)

local Inn = Svc.ClientState.TerritoryType
if Inn == 177 or Inn == 178 or Inn == 179 or Inn == 1205 then
    AtInn = true
else
    AtInn = false
end

if not AtInn and HomeCommand == "Inn" then
    IPC.Lifestream.ExecuteCommand(HomeCommand)
    DebugLog("Moving to Inn")
    AtInn = true
elseif not AtHome and (HomeCommand == "Home" or HomeCommand == "fc") then
    IPC.Lifestream.ExecuteCommand(HomeCommand)
    DebugLog("Moving Home")
    AtHome = true
elseif not AtInn and Svc.ClientState.TerritoryType ~= 1186 then
    IPC.Lifestream.ExecuteCommand("Nexus Arcade")
    DebugLog("Moving to Solution Nine")
end

yield("/wait 1")
while IPC.Lifestream.IsBusy() or Player.IsBusy or Svc.Condition[CharacterCondition.casting] do
    DebugLog("Waiting for Lifestream/Player to be ready")
    yield("/wait 1")
end

ArtisanTimeoutStartTime = 0
DebugLog("Script start")

State = CharacterState.ready

while not StopFlag do
    DebugLog("Current state: " .. tostring(State))
    if not (
        Svc.Condition[CharacterCondition.casting] or
        Svc.Condition[CharacterCondition.betweenAreas] or
        Svc.Condition[CharacterCondition.beingMoved] or
        Svc.Condition[CharacterCondition.occupiedMateriaExtractionAndRepair] or
        IPC.Lifestream.IsBusy())
    then
        State()
    end
    yield("/wait 0.1")
end
