--[=====[
[[SND Metadata]]
author: poi0827
version: 1.1.6
description: >
  此脚本基于钓鱼橙票脚本修改，在钓灵砂鱼的基础上实现了自动修理精炼精选，支持其他灵砂鱼，请自行修改

  v1.1.6尝试修复无法精选收藏品的问题

  v1.1.5精简代码

  v1.1.4使用状态机模式重构，尝试修复未检测到幻卡对局室的问题

  作者修改的其他脚本：https://github.com/poi0827/SNDScripts/

  注意事项：

  ①如果需要自动吃药的话请安装潘多拉

  ②请开启DR自动防警惕，不需要填额外文本指令

  ③请自行修改钓场点位，避免模型重叠

plugin_dependencies:
- vnavmesh
- DailyRoutines
- TeleporterPlugin
configs:
  FishingAddon:
    default: 1
    description: 选择钓鱼插件，0为Autohook，1为MissFisher
    type: int
  FishingAetheryte:
    default: 哈努聚落
    description: 钓场的以太之光名字
  FishingZoneID:
    default: 1188
    description: 钓场区域ID
    type: int
  UnmountPositionX:
    default: -3.9108598
    description: 下坐骑位置X坐标
    type: float
  UnmountPositionY:
    default: 24.658663
    description: 下坐骑位置Y坐标
    type: float
  UnmountPositionZ:
    default: 27.425825
    description: 下坐骑位置Z坐标
    type: float
  FishingPositionX:
    default: 3.2094617
    description: 钓鱼位置X坐标
    type: float
  FishingPositionY:
    default: 25.3077
    description: 钓鱼位置Y坐标
    type: float
  FishingPositionZ:
    default: 19.545511
    description: 钓鱼位置Z坐标
    type: float
  TargetFish:
    default: 紫舌尖
    description: 目标鱼名称
  CollectibleItemId:
    default: 46249
    description: 目标鱼ID
    type: int
  FishingBaitId:
    default: 43858
    description: 使用的鱼饵ID
    type: int
  NumInventoryFreeSlotThreshold:
    default: 5
    description: 当背包剩余空间小于该值时将停止钓鱼并精选灵砂
    type: int
  DoExtract:
    default: true
    description: 是否自动精炼
    type: bool
  DoRepair:
    default: true
    description: 是否自动修理
    type: bool
  MedicineToUse:
    default: 极精炼药
    description: 吃什么药（不想使用请留空）
  RepairAmount:
    default: 50
    description: 修理阈值
    type: int
  DebugMode:
    default: 1
    description: DEBUG模式
    type: int
  IntervalRate:
    default: 0.2
    description: 脚本执行间隔速率（秒）
    type: float

[[End Metadata]]
--]=====]

import("System.Numerics")

-- 状态定义
local STATE = {
    INIT = 0,
    CHECK_PLUGINS = 1,
    SWITCH_TO_FISHER = 2,
    DISMOUNT = 3,
    TELEPORT = 4,
    NAVIGATE_TO_UNMOUNT = 5,
    NAVIGATE_TO_FISHING = 6,
    USE_MEDICINE = 7,
    CHECK_BAIT = 8,
    START_FISHING = 9,
    FISHING = 10,
    STOP_FISHING = 11,
    CHECK_INVENTORY = 12,
    REPAIR = 13,
    EXTRACT_MATERIA = 14,
    AETHERIA = 15,
    TRIPLE_TRIAD = 16,
    ERROR = 99
}

-- 状态机变量
local currentState = STATE.INIT
local stateStartTime = 0
local stateTimeout = 120
local retryCount = 0
local maxRetries = 3
local reCount = 0

-- 获取配置
FishingAddon = tonumber(Config.Get("FishingAddon"))
FishingAetheryte = Config.Get("FishingAetheryte")
FishingZoneID = tonumber(Config.Get("FishingZoneID"))
UnmountPosition = {
    x = tonumber(Config.Get("UnmountPositionX")),
    y = tonumber(Config.Get("UnmountPositionY")),
    z = tonumber(Config.Get("UnmountPositionZ"))
}
FishingPosition = {
    x = tonumber(Config.Get("FishingPositionX")),
    y = tonumber(Config.Get("FishingPositionY")),
    z = tonumber(Config.Get("FishingPositionZ"))
}
TargetFish = Config.Get("TargetFish")
CollectibleItemId = tonumber(Config.Get("CollectibleItemId"))
FishingBaitId = tonumber(Config.Get("FishingBaitId"))
IntervalRate = tonumber(Config.Get("IntervalRate"))
NumInventoryFreeSlotThreshold = tonumber(Config.Get("NumInventoryFreeSlotThreshold"))
DoExtract = Config.Get("DoExtract")
DoRepair = Config.Get("DoRepair")
MedicineToUse = Config.Get("MedicineToUse")
RepairAmount = tonumber(Config.Get("RepairAmount"))
DebugMode = tonumber(Config.Get("DebugMode"))

-- 根据选择的钓鱼插件设置相应的命令
if FishingAddon == 1 then
    StartFishingCommand1 = function()
        return "/mf preset 紫舌尖"
    end
    StartFishingCommand2 = ""
    StopFishingCommand1 = "/e 停止"
    StopFishingCommand2 = "/ac 中断"
else
    StartFishingCommand1 = "/ahon"
    StartFishingCommand2 = "/ac 抛竿"
    StopFishingCommand1 = "/ahoff"
    StopFishingCommand2 = "/ac 中断"
end

-- 调试日志函数
function DebugLog(message)
    if DebugMode == 1 then
        yield("/echo [DEBUG] " .. message)
    end
end

-- 状态转换函数
function ChangeState(newState)
    DebugLog("状态转换: " .. currentState .. " -> " .. newState)
    currentState = newState
    stateStartTime = os.clock()
    retryCount = 0
end

-- 状态超时检查
function CheckStateTimeout()
    if currentState ~= STATE.FISHING then   
        if os.clock() - stateStartTime > stateTimeout then
            DebugLog("状态超时: " .. currentState)
            retryCount = retryCount + 1
        
            if retryCount >= maxRetries then
                ChangeState(STATE.ERROR)
                return true
            else
                DebugLog("重试状态: " .. currentState .. " (" .. retryCount .. "/" .. maxRetries .. ")")
                stateStartTime = os.clock()
            end
        end
    end
    return false
end

-- 辅助函数
function GetDistanceToPoint(dX, dY, dZ)
    local player = Svc.ClientState.LocalPlayer
    if not player or not player.Position then
        return math.huge
    end

    local px = player.Position.X
    local py = player.Position.Y
    local pz = player.Position.Z

    local dx = dX - px
    local dy = dY - py
    local dz = dZ - pz

    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function HasStatus(statusId)
    local statusList = Player.Status
    if not statusList then return false end

    for i = 0, statusList.Count - 1 do
        local status = statusList:get_Item(i)
        if status and status.StatusId == statusId then
            return true
        end
    end
    return false
end

function NeedsRepair(threshold)
    if not DoRepair then return false end
    
    local needsRepair = Inventory.GetItemsInNeedOfRepairs(threshold)
    return needsRepair.Count > 2
end

function CanExtractMateria()
    if not DoExtract then return false end
    
    local spiritbondedItems = Inventory.GetSpiritbondedItems()
    return spiritbondedItems.Count > 2
end

function CanAetheria()
    return Inventory.GetCollectableItemCount(CollectibleItemId, 1) > 0
end

-- 状态处理函数
function HandleState_INIT()
    DebugLog("脚本初始化")
    ChangeState(STATE.CHECK_PLUGINS)
    return true
end

function HandleState_CHECK_PLUGINS()
    DebugLog("开始检查插件")
    
    local requiredPlugins = { "vnavmesh", "DailyRoutines" }
    if MedicineToUse ~= nil and MedicineToUse ~= "" then
        table.insert(requiredPlugins, "PandorasBox")
    end
    
    for _, plugin in ipairs(requiredPlugins) do
        local found = false
        
        for installedPlugin in luanet.each(Svc.PluginInterface.InstalledPlugins) do
            if installedPlugin.InternalName == plugin and installedPlugin.IsLoaded then
                found = true
                break
            end
        end
        
        if not found then
            yield("/echo 请安装插件: " .. plugin)
            ChangeState(STATE.ERROR)
            return false
        end
    end
    
    DebugLog("插件检查完成")
    ChangeState(STATE.SWITCH_TO_FISHER)
    return true
end

function HandleState_SWITCH_TO_FISHER()
    local currentJobId = Player.Job.Id
    if currentJobId == 18 then 
        ChangeState(STATE.DISMOUNT)
        return true
    end
    
    DebugLog("当前不是捕鱼人职业，尝试切换到捕鱼人装备")
    
    -- 查找捕鱼人装备套装
    local fisherGearset = nil
    for _, gearset in ipairs(Player.Gearsets) do
        if gearset.IsValid and gearset.ClassJob == 18 then
            fisherGearset = gearset
            break
        end
    end
    
    if fisherGearset then
        DebugLog("找到捕鱼人装备套装: " .. fisherGearset.Name)
        yield('/gs change "' .. fisherGearset.Name .. '"')
        yield("/wait " .. IntervalRate * 3)
        
        if Player.Job.Id == 18 then
            ChangeState(STATE.DISMOUNT)
            return true
        else
            yield("/echo 切换捕鱼人职业失败")
            ChangeState(STATE.ERROR)
            return false
        end
    else
        yield("/echo 未找到捕鱼人装备套装")
        ChangeState(STATE.ERROR)
        return false
    end
end

function HandleState_DISMOUNT()
    -- 检查角色是否处于坐骑状态
    if Svc.Condition[77] or Svc.Condition[4] then
        yield("/gaction 随机坐骑")
        yield("/wait " .. IntervalRate * 5)
        
        -- 等待下坐骑完成
        local timeout_start = os.clock()
        while (Svc.Condition[77] or Svc.Condition[4]) and os.clock() - timeout_start < 10 do
            yield("/wait " .. IntervalRate)
        end
    end
    
    DebugLog("下坐骑完成")
    ChangeState(STATE.TELEPORT)
    return not Svc.Condition[77] and not Svc.Condition[4]
end

function HandleState_TELEPORT()
    if Svc.ClientState.TerritoryType == FishingZoneID then
        ChangeState(STATE.NAVIGATE_TO_UNMOUNT)
        return true
    else
        DebugLog("不在钓鱼区域，尝试传送")
        yield("/tp " .. FishingAetheryte)
        yield("/wait " .. IntervalRate * 5)
        
        -- 等待传送完成
        local timeout_start = os.clock()
        while Svc.ClientState.TerritoryType ~= FishingZoneID and os.clock() - timeout_start < 30 do
            yield("/wait " .. IntervalRate * 5)
        end
        
        if Svc.ClientState.TerritoryType == FishingZoneID then
            ChangeState(STATE.NAVIGATE_TO_UNMOUNT)
            return true
        else
            DebugLog("传送失败")
            retryCount = retryCount + 1
            if retryCount >= maxRetries then
                ChangeState(STATE.ERROR)
                return false
            end
            return true
        end
    end
end

function HandleState_NAVIGATE_TO_UNMOUNT()
    local distance = GetDistanceToPoint(UnmountPosition.x, UnmountPosition.y, UnmountPosition.z)
    DebugLog("距离下坐骑位置: " .. distance)
    
    if distance <= 11 then
        ChangeState(STATE.NAVIGATE_TO_FISHING)
        return true
    else
        if distance > 20 then
            -- 需要上坐骑
            if not Svc.Condition[4] and not Svc.Condition[77] then
                yield('/gaction 随机坐骑')
                yield("/wait " .. IntervalRate * 3)
            end
            
            -- 使用vnavmesh导航
            if IPC.vnavmesh.IsReady() and not IPC.vnavmesh.IsRunning() then
                IPC.vnavmesh.PathfindAndMoveTo(Vector3(UnmountPosition.x, UnmountPosition.y, UnmountPosition.z), true)
            end
        else
            -- 近距离直接下坐骑走过去
            if Svc.Condition[77] or Svc.Condition[4] then
                yield("/gaction 随机坐骑")
                yield("/wait " .. IntervalRate * 3)
            end
            
            if IPC.vnavmesh.IsReady() and not IPC.vnavmesh.IsRunning() then
                IPC.vnavmesh.PathfindAndMoveTo(Vector3(UnmountPosition.x, UnmountPosition.y, UnmountPosition.z), false)
            end
        end
        
        -- 等待导航完成
        yield("/wait " .. IntervalRate * 5)
        return true
    end
end

function HandleState_NAVIGATE_TO_FISHING()
    local distance = GetDistanceToPoint(FishingPosition.x, FishingPosition.y, FishingPosition.z)
    DebugLog("距离钓鱼位置: " .. distance)
    
    if distance <= 1 then
        ChangeState(STATE.USE_MEDICINE)
        return true
    else
        -- 确保下坐骑
        if Svc.Condition[77] or Svc.Condition[4] then
            yield("/gaction 随机坐骑")
            yield("/wait " .. IntervalRate * 3)
        end
        
        if IPC.vnavmesh.IsReady() and not IPC.vnavmesh.IsRunning() then
            IPC.vnavmesh.PathfindAndMoveTo(Vector3(FishingPosition.x, FishingPosition.y, FishingPosition.z), false)
        end
        
        -- 等待导航完成
        yield("/wait " .. IntervalRate * 5)
        return true
    end
end

function HandleState_USE_MEDICINE()
    IPC.vnavmesh.Stop() -- 停止可能存在的寻路状态
    
    -- 检查是否已有强化药状态
    if HasStatus(49) then
        DebugLog("已检测到强化药状态，跳过使用")
        ChangeState(STATE.CHECK_BAIT)
        return true
    end
    
    if not MedicineToUse or MedicineToUse == "" then
        DebugLog("配置中未设置药品名称，跳过使用药品")
        ChangeState(STATE.CHECK_BAIT)
        return true
    end
    
    -- 使用药品
    local medicineCommand = '/puseitem "' .. MedicineToUse .. '"'
    DebugLog("执行药品命令: " .. medicineCommand)
    yield(medicineCommand)
    
    -- 等待药品生效
    local timeout_start = os.clock()
    while not HasStatus(49) and os.clock() - timeout_start < 15 do
        yield("/wait 1")
    end
    
    ChangeState(STATE.CHECK_BAIT)
    return true
end

function HandleState_CHECK_BAIT()
    if FishingBaitId == nil or FishingBaitId == 0 then
        DebugLog("未设置鱼饵ID，跳过鱼饵检查")
        ChangeState(STATE.START_FISHING)
        return true
    end
    
    -- 检查当前鱼饵
    local currentBait = Player.FishingBait
    if currentBait ~= FishingBaitId then
        DebugLog("当前鱼饵与配置不同，更换鱼饵")
        yield("/pdr bait " .. tostring(FishingBaitId))
        yield("/wait " .. IntervalRate * 3)
        
        -- 确认鱼饵是否更换成功
        if Player.FishingBait ~= FishingBaitId then
            yield("/echo 鱼饵更换失败，请检查鱼饵ID是否正确")
            ChangeState(STATE.ERROR)
            return false
        end
    end
    
    -- 检查鱼饵数量
    local baitCount = Inventory.GetItemCount(FishingBaitId)
    if baitCount == 0 then
        yield("/echo 鱼饵数量为0，脚本停止")
        ChangeState(STATE.ERROR)
        return false
    end
    
    DebugLog("当前鱼饵数量: " .. baitCount)
    ChangeState(STATE.START_FISHING)
    return true
end

function HandleState_START_FISHING()
    DebugLog("开始钓鱼")
    
    if type(StartFishingCommand1) == "function" then
        yield(StartFishingCommand1())
    else
        yield(StartFishingCommand1)
    end
    
    yield("/wait " .. IntervalRate)
    yield(StartFishingCommand2)
    yield("/wait " .. IntervalRate * 10) -- 加一个延迟
    
    DebugLog("钓鱼已开始")
    ChangeState(STATE.FISHING)
    reCount = 0
    return true
end

function HandleState_FISHING()
    -- 检查是否进入幻卡对局室 (区域ID: 579)
    if Svc.ClientState.TerritoryType == 579 then
        DebugLog("检测到进入幻卡对局室，停止钓鱼")
        ChangeState(STATE.TRIPLE_TRIAD)
        return true
    end
    
    -- 检查是否不在钓鱼状态
    if not Svc.Condition[6] and not Svc.Condition[42] then
        if reCount < 3 then
            reCount = reCount + 1
            yield("/wait " .. IntervalRate * 20) -- 等待四秒
        else
            DebugLog("检测到不在钓鱼状态，重新开始流程")
            ChangeState(STATE.TELEPORT)
            return true
        end
    end
    
    -- 检查是否需要停止钓鱼
    local freeSlots = Inventory.GetFreeInventorySlots()
    DebugLog("背包空格: " .. freeSlots)
    
    if freeSlots < NumInventoryFreeSlotThreshold or 
       NeedsRepair(RepairAmount) or 
       CanExtractMateria() then
        ChangeState(STATE.STOP_FISHING)
    else
        -- 检查鱼饵数量
        if Inventory.GetItemCount(FishingBaitId) == 0 then
            yield("/echo 鱼饵数量为0，脚本停止")
            ChangeState(STATE.ERROR)
        else
            -- 继续钓鱼
            yield("/wait " .. IntervalRate * 10)
        end
    end
    return true
end

function HandleState_STOP_FISHING()
    DebugLog("停止钓鱼")
    yield(StopFishingCommand1)
    yield("/wait " .. IntervalRate * 10)
    yield(StopFishingCommand2)
    yield("/wait " .. IntervalRate * 10)
    
    DebugLog("钓鱼已停止")
    ChangeState(STATE.CHECK_INVENTORY)
    return not Svc.Condition[6] and not Svc.Condition[42]
end

function HandleState_CHECK_INVENTORY()
    -- 检查需要执行哪些操作
    local needsRepair = NeedsRepair(RepairAmount)
    local canExtract = CanExtractMateria()
    local canAetheria = CanAetheria()
    
    DebugLog("检查需求 - 修理:" .. tostring(needsRepair) .. 
            " 精炼:" .. tostring(canExtract) .. 
            " 精选:" .. tostring(canAetheria))
    
    if needsRepair then
        ChangeState(STATE.REPAIR)
    elseif canExtract then
        ChangeState(STATE.EXTRACT_MATERIA)
    elseif canAetheria then
        ChangeState(STATE.AETHERIA)
    else
        -- 没有需要处理的操作，返回钓鱼
        ChangeState(STATE.USE_MEDICINE)
    end
    return true
end

function HandleState_REPAIR()
    DebugLog("尝试修理装备")
    
    IPC.vnavmesh.Stop()
    
    -- 确保下坐骑
    if Svc.Condition[77] or Svc.Condition[4] then
        yield("/gaction 随机坐骑")
        yield("/wait " .. IntervalRate * 3)
    end
    
    -- 打开修理界面
    local timeout_start = os.clock()
    while not Addons.GetAddon("Repair").Ready and os.clock() - timeout_start < 30 do
        yield("/gaction 修理")
        yield("/wait " .. IntervalRate * 5)
    end
    
    if Addons.GetAddon("Repair").Ready then
        yield("/callback Repair true 0")
        yield("/wait " .. IntervalRate)
        
        if Addons.GetAddon("SelectYesno").Ready then
            yield("/callback SelectYesno true 0")
        end
        
        -- 等待修理完成
        timeout_start = os.clock()
        while Svc.Condition[39] and os.clock() - timeout_start < 60 do
            yield("/wait " .. IntervalRate * 5)
        end
        
        yield("/wait " .. IntervalRate * 5)
        yield("/callback Repair true -1")
        
        DebugLog("修理完成")
        ChangeState(STATE.CHECK_INVENTORY)
        return true
    else
        DebugLog("修理界面打开失败")
        ChangeState(STATE.CHECK_INVENTORY)
        return false
    end
end

function HandleState_EXTRACT_MATERIA()
    DebugLog("尝试精炼魔晶石")
    
    IPC.vnavmesh.Stop()
    
    -- 确保下坐骑
    if Svc.Condition[77] or Svc.Condition[4] then
        yield("/gaction 随机坐骑")
        yield("/wait " .. IntervalRate * 3)
    end
    
    -- 打开精炼界面
    yield("/gaction 精制魔晶石")
    
    local timeout_start = os.clock()
    while not Addons.GetAddon("Materialize").Ready and os.clock() - timeout_start < 30 do
        yield("/wait " .. IntervalRate)
    end
    
    if Addons.GetAddon("Materialize").Ready then
        while CanExtractMateria() do
            yield("/callback Materialize true 2 0")
            yield("/wait " .. IntervalRate * 5)
            
            if Addons.GetAddon("MaterializeDialog").Ready then
                yield("/callback MaterializeDialog true 0")
            end
            
            -- 等待精炼完成
            timeout_start = os.clock()
            while Svc.Condition[39] and os.clock() - timeout_start < 60 do
                yield("/wait " .. IntervalRate * 5)
            end
        end
        
        yield("/wait " .. IntervalRate * 5)
        yield("/callback Materialize true -1")
        
        DebugLog("精炼魔晶石完成")
        ChangeState(STATE.CHECK_INVENTORY)
        return true
    else
        DebugLog("精炼界面打开失败")
        ChangeState(STATE.CHECK_INVENTORY)
        return false
    end
end

function HandleState_AETHERIA()
    DebugLog("尝试精选灵砂")
    
    IPC.vnavmesh.Stop()
    
    -- 确保下坐骑
    if Svc.Condition[77] or Svc.Condition[4] then
        yield("/gaction 随机坐骑")
        yield("/wait " .. IntervalRate * 3)
    end
    
    -- 打开精选界面
    
    local timeout_start = os.clock()
    while not Addons.GetAddon("PurifyItemSelector").Ready and os.clock() - timeout_start < 30 do
        yield("/gaction 精选")
        yield("/wait " .. IntervalRate * 5)
    end
    
    if Addons.GetAddon("PurifyItemSelector").Ready then
        yield("/callback PurifyItemSelector true 12 0")
        yield("/wait " .. IntervalRate * 5)
        
        timeout_start = os.clock()
        while not Addons.GetAddon("PurifyResult").Ready and os.clock() - timeout_start < 30 do
            yield("/wait " .. IntervalRate)
        end
        
        if Addons.GetAddon("PurifyResult").Ready then
            yield("/callback PurifyResult true 0")
            
            -- 等待精选完成
            timeout_start = os.clock()
            while CanAetheria() do
                yield("/wait " .. IntervalRate * 5)
            end
            
            yield("/wait " .. IntervalRate * 5)
            yield("/callback PurifyAutoDialog true 0")
            
            DebugLog("灵砂精选完成")
            ChangeState(STATE.CHECK_INVENTORY)
            yield("/gaction 精选")--关闭精选界面
            return true
        else
            DebugLog("精选结果界面打开失败")
            ChangeState(STATE.CHECK_INVENTORY)
            return false
        end
    else
        DebugLog("精选界面打开失败")
        ChangeState(STATE.CHECK_INVENTORY)
        return false
    end
end

function HandleState_TRIPLE_TRIAD()
    DebugLog("检测到进入幻卡对局室，等待返回钓鱼区域")
    
    -- 等待直到返回钓鱼区域
    while Svc.ClientState.TerritoryType == 579 do
        yield("/wait " .. IntervalRate * 5)
    end
    
    DebugLog("已返回钓鱼区域，重新准备钓鱼")
    yield("/wait " .. IntervalRate * 30) --等待过图
    ChangeState(STATE.USE_MEDICINE)
    return true
end

function HandleState_ERROR()
    -- 检查是否在钓鱼状态
    if Svc.Condition[6] or Svc.Condition[42] then
        DebugLog("错误状态中检测到钓鱼状态，尝试停止钓鱼")
        ChangeState(STATE.STOP_FISHING)
    -- 检查是否在幻卡对局室
    elseif Svc.ClientState.TerritoryType == 579 then
        DebugLog("错误状态中检测到幻卡对局室，等待退出")
        ChangeState(STATE.TRIPLE_TRIAD)
    else
        DebugLog("错误状态，尝试重新传送")
        ChangeState(STATE.TELEPORT)
    end
    return true
end

-- 状态处理映射表
local StateHandlers = {
    [STATE.INIT] = HandleState_INIT,
    [STATE.CHECK_PLUGINS] = HandleState_CHECK_PLUGINS,
    [STATE.SWITCH_TO_FISHER] = HandleState_SWITCH_TO_FISHER,
    [STATE.DISMOUNT] = HandleState_DISMOUNT,
    [STATE.TELEPORT] = HandleState_TELEPORT,
    [STATE.NAVIGATE_TO_UNMOUNT] = HandleState_NAVIGATE_TO_UNMOUNT,
    [STATE.NAVIGATE_TO_FISHING] = HandleState_NAVIGATE_TO_FISHING,
    [STATE.USE_MEDICINE] = HandleState_USE_MEDICINE,
    [STATE.CHECK_BAIT] = HandleState_CHECK_BAIT,
    [STATE.START_FISHING] = HandleState_START_FISHING,
    [STATE.FISHING] = HandleState_FISHING,
    [STATE.STOP_FISHING] = HandleState_STOP_FISHING,
    [STATE.CHECK_INVENTORY] = HandleState_CHECK_INVENTORY,
    [STATE.REPAIR] = HandleState_REPAIR,
    [STATE.EXTRACT_MATERIA] = HandleState_EXTRACT_MATERIA,
    [STATE.AETHERIA] = HandleState_AETHERIA,
    [STATE.TRIPLE_TRIAD] = HandleState_TRIPLE_TRIAD,
    [STATE.ERROR] = HandleState_ERROR
}

-- 脚本入口点
DebugLog("脚本启动 - 状态机模式")
yield("/echo 开始自动钓收藏品")

-- 初始化状态机
currentState = STATE.INIT
stateStartTime = os.clock()

-- 主循环
while true do
    if CheckStateTimeout() then
        yield("/wait " .. IntervalRate)
    end
    
    -- 执行当前状态的处理函数
    local handler = StateHandlers[currentState]
    if handler then
        local success, result = pcall(handler)
        if not success then
            DebugLog("状态处理错误: " .. tostring(result))
            ChangeState(STATE.ERROR)
        end
    else
        DebugLog("未找到状态处理函数: " .. currentState)
        ChangeState(STATE.ERROR)
    end
    
    yield("/wait " .. IntervalRate)
end


