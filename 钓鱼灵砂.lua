--[=====[
[[SND Metadata]]
author: poi0827
version: 1.1.4
description: >
  此脚本基于钓鱼橙票脚本修改，在钓灵砂鱼的基础上实现了自动修理精炼精选

  使用状态机模式重构，尝试修复未检测到幻卡对局室的问题
  
  作者修改的其他脚本：https://github.com/poi0827/SNDScripts/

  注意事项：

  ①如果需要自动吃药的话请安装潘多拉

  ②请开启DR自动防警惕，不需要填额外文本指令

  ③请自行修改钓场点位，避免模型重叠

  ④因为tp插件暂不可用，请自行传送至目标地图再启动脚本

plugin_dependencies:
- vnavmesh
- DailyRoutines
configs:
  FishingAddon:
    default: 1
    description: 选择钓鱼插件，0为Autohook，1为空天姬
    type: string
  FishingAetheryte:
    default: 哈努聚落
    description: 钓场的以太之光名字
    type: string
  FishingZoneID:
    default: 1188
    description: 钓场区域ID
    type: string
  UnmountPositionX:
    default: -3.9108598
    description: 下坐骑位置X坐标
    type: string
  UnmountPositionY:
    default: 24.658663
    description: 下坐骑位置Y坐标
    type: string
  UnmountPositionZ:
    default: 27.425825
    description: 下坐骑位置Z坐标
    type: string
  FishingPositionX:
    default: 3.2094617
    description: 钓鱼位置X坐标
    type: string
  FishingPositionY:
    default: 25.3077
    description: 钓鱼位置Y坐标
    type: string
  FishingPositionZ:
    default: 19.545511
    description: 钓鱼位置Z坐标
    type: string
  TargetFish:
    default: Purple Palate
    description: 目标鱼名称
    type: string
  CollectibleItemId:
    default: 46249
    description: 目标鱼ID
    type: string
  FishingBaitId:
    default: 43858
    description: 使用的鱼饵ID
    type: string
  NumInventoryFreeSlotThreshold:
    default: 5
    description: 当背包剩余空间小于该值时将停止钓鱼并精选灵砂
    type: string
  DoExtract:
    default: true
    description: 是否自动精炼
    type: string
  DoRepair:
    default: true
    description: 是否自动修理
    type: string
  MedicineToUse:
    default: 极精炼药
    description: 吃什么药（不想使用请留空）
    type: string
  RepairAmount:
    default: 50
    description: 修理阈值
    type: string
  DebugMode:
    default: 1
    description: DEBUG模式
    type: string

[[End Metadata]]
--]=====]

import("System.Numerics")

-- 状态定义 - 添加TRIPLE_TRIAD状态
local STATE = {
    INIT = 0,
    CHECK_PLUGINS = 1,
    SWITCH_TO_FISHER = 2,
    DISMOUNT = 3,
    TELEPORT = 4,
    NAVIGATE_TO_UNMOUNT = 5,
    NAVIGATE_TO_FISHING = 6,
    USE_MEDICINE = 7,        -- 移动到寻路之后
    CHECK_BAIT = 8,          -- 移动到寻路之后
    START_FISHING = 9,
    FISHING = 10,
    STOP_FISHING = 11,
    CHECK_INVENTORY = 12,
    REPAIR = 13,
    EXTRACT_MATERIA = 14,
    AETHERIA = 15,
    TRIPLE_TRIAD = 16,       -- 新增：幻卡对局室状态
    ERROR = 99
}

-- 状态机变量
local currentState = STATE.INIT
local lastState = STATE.INIT
local stateStartTime = 0
local stateTimeout = 120 -- 状态超时时间（秒）
local retryCount = 0
local maxRetries = 3

-- 获取配置
FishingAddon = tonumber(Config.Get("FishingAddon")) or 0

-- 钓场配置
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
CollectibleItemId = tonumber(Config.Get("CollectibleItemId")) or 46249
FishingBaitId = tonumber(Config.Get("FishingBaitId")) or 0

-- 通用配置
IntervalRate = tonumber(Config.Get("IntervalRate")) or 0.2
NumInventoryFreeSlotThreshold = tonumber(Config.Get("NumInventoryFreeSlotThreshold"))
DoExtract = Config.Get("DoExtract")
DoRepair = Config.Get("DoRepair")
MedicineToUse = Config.Get("MedicineToUse")
RepairAmount = tonumber(Config.Get("RepairAmount"))
DebugMode = tonumber(Config.Get("DebugMode"))

-- 根据选择的钓鱼插件设置相应的命令
if FishingAddon == 1 then
    -- 空天姬模式
    StartFishingCommand1 = function()
        return "/e 大鱼（红蛆）拍【？46249】23~！！=不撒饵、收藏品、引诱=专一【紫舌尖】"
    end
    StartFishingCommand2 = ""
    StopFishingCommand1 = "/e 停止"
    StopFishingCommand2 = "/ac 中断"
else
    -- Autohook模式（默认）
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
    lastState = currentState
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
        
            if retryCount >= maxRetries  then
                ChangeState(STATE.ERROR)
                return true
            else
            DebugLog("重试状态: " .. currentState .. " (" .. retryCount .. "/" .. maxRetries .. ")")
            stateStartTime = os.clock() -- 重置超时计时器
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

-- 状态检测函数
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

function GetItemCount(itemId)
    return Inventory.GetItemCount(itemId)
end

function GetInventoryFreeSlotCount()
    return Inventory.GetFreeInventorySlots()
end

function IsPlayerAvailable()
    return Player and Player.Available
end

function IsInZone(zoneId)
    return Svc.ClientState.TerritoryType == zoneId
end

-- 检查并切换到捕鱼人职业
function CheckAndSwitchToFisher()
    local currentJobId = Player.Job.Id
    if currentJobId == 18 then return true end
    
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
        
        return Player.Job.Id == 18
    else
        yield("/echo 未找到捕鱼人装备套装")
        return false
    end
end

-- 检查并更换鱼饵
function CheckAndChangeBait()
    if FishingBaitId == nil or FishingBaitId == 0 then
        DebugLog("未设置鱼饵ID，跳过鱼饵检查")
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
            return false
        end
    end
    
    -- 检查鱼饵数量
    local baitCount = GetItemCount(FishingBaitId)
    if baitCount == 0 then
        yield("/echo 鱼饵数量为0，脚本停止")
        return false
    end
    
    DebugLog("当前鱼饵数量: " .. baitCount)
    return true
end

-- 使用药品
function UseMedicine()
    if not MedicineToUse or MedicineToUse == "" then
        DebugLog("配置中未设置药品名称，跳过使用药品")
        return true
    end
    
    -- 检查是否已有强化药状态
    if HasStatus(49) then
        DebugLog("已检测到强化药状态，跳过使用")
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
    
    return HasStatus(49)
end

-- 下坐骑
function Dismount()
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
    return not Svc.Condition[77] and not Svc.Condition[4]
end

-- 停止钓鱼
function StopFishing()
    DebugLog("停止钓鱼")
    
    if Svc.Condition[6] or Svc.Condition[42] or Svc.Condition[27] or Svc.Condition[51] then
        DebugLog("等待下次上钩后停止")
        yield("/echo 下次上钩后停止钓鱼")
        
        local startTime = os.time()
        while not Svc.Condition[42] and os.time() - startTime < 60 do
            yield("/wait " .. IntervalRate)
        end
        
        if Svc.Condition[42] then
            yield(StopFishingCommand1)
            yield("/wait " .. IntervalRate)
            
            local timeout_start = os.clock()
            while (Svc.Condition[6] or Svc.Condition[42]) and os.clock() - timeout_start < 10 do
                yield("/wait " .. IntervalRate)
                yield(StopFishingCommand2)
            end
        end
    else    
        yield(StopFishingCommand1)
        yield("/wait " .. IntervalRate)
        yield(StopFishingCommand2)
        yield("/wait " .. IntervalRate * 5)
    end
    
    DebugLog("钓鱼已停止")
    return not Svc.Condition[6] and not Svc.Condition[42]
end

-- 开始钓鱼
function StartFishing()
    DebugLog("开始钓鱼")
    
    if type(StartFishingCommand1) == "function" then
        yield(StartFishingCommand1())
    else
        yield(StartFishingCommand1)
    end
    
    yield("/wait " .. IntervalRate)
    yield(StartFishingCommand2)
    yield("/wait " .. IntervalRate*10) --加一个延迟
    DebugLog("钓鱼已开始")
    return true
end

-- 修理装备
function Repair()
    DebugLog("尝试修理装备")
    
    IPC.vnavmesh.Stop()
    Dismount()
    
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
        return true
    else
        DebugLog("修理界面打开失败")
        return false
    end
end

-- 精炼魔晶石
function ExtractMateria()
    DebugLog("尝试精炼魔晶石")
    
    IPC.vnavmesh.Stop()
    Dismount()
    
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
        return true
    else
        DebugLog("精炼界面打开失败")
        return false
    end
end

-- 精选灵砂
function Aetheria()
    DebugLog("尝试精选灵砂")
    
    IPC.vnavmesh.Stop()
    Dismount()
    
    -- 打开精选界面
    yield("/gaction 精选")
    
    local timeout_start = os.clock()
    while not Addons.GetAddon("PurifyItemSelector").Ready and os.clock() - timeout_start < 30 do
        yield("/wait " .. IntervalRate)
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
            return true
        else
            DebugLog("精选结果界面打开失败")
            return false
        end
    else
        DebugLog("精选界面打开失败")
        return false
    end
end

-- 插件检查函数
function CheckPlugins()
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
            return false
        end
    end
    
    DebugLog("插件检查完成")
    return true
end

-- 状态机主循环
function StateMachineLoop()
    if CheckStateTimeout() then
        yield("/echo 状态机超时，重新尝试")
        ChangeState(STATE.TELEPORT)
    end
    if IsInZone(579) then
        DebugLog("检测到进入幻卡对局室，停止钓鱼")
        ChangeState(STATE.TRIPLE_TRIAD)
    end
    -- 状态处理
    if currentState == STATE.INIT then
        DebugLog("脚本初始化")
        ChangeState(STATE.CHECK_PLUGINS)
        
    elseif currentState == STATE.CHECK_PLUGINS then
        if CheckPlugins() then
            ChangeState(STATE.SWITCH_TO_FISHER)
        else
            ChangeState(STATE.ERROR)
        end
        
    elseif currentState == STATE.SWITCH_TO_FISHER then
        if CheckAndSwitchToFisher() then
            ChangeState(STATE.DISMOUNT)
        else
            ChangeState(STATE.ERROR)
        end
        
    elseif currentState == STATE.DISMOUNT then
        if Dismount() then
            ChangeState(STATE.TELEPORT)  -- 直接跳转到传送，跳过USE_MEDICINE和CHECK_BAIT
        else
            ChangeState(STATE.ERROR)
        end
        
    elseif currentState == STATE.TELEPORT then
        if IsInZone(FishingZoneID) then
            ChangeState(STATE.NAVIGATE_TO_UNMOUNT)
        else
            DebugLog("不在钓鱼区域，尝试传送")
            yield("/tp " .. FishingAetheryte)
            yield("/wait " .. IntervalRate * 5)
            
            -- 等待传送完成
            local timeout_start = os.clock()
            while not IsInZone(FishingZoneID) and os.clock() - timeout_start < 30 do
                yield("/wait " .. IntervalRate * 5)
            end
            
            if IsInZone(FishingZoneID) then
                ChangeState(STATE.NAVIGATE_TO_UNMOUNT)
            else
                DebugLog("传送失败")
                retryCount = retryCount + 1
                if retryCount >= maxRetries then
                    ChangeState(STATE.ERROR)
                end
            end
        end
        
    elseif currentState == STATE.NAVIGATE_TO_UNMOUNT then
        local distance = GetDistanceToPoint(UnmountPosition.x, UnmountPosition.y, UnmountPosition.z)
        DebugLog("距离下坐骑位置: " .. distance)
        
        if distance <= 11 then
            ChangeState(STATE.NAVIGATE_TO_FISHING)
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
                Dismount()
                
                if IPC.vnavmesh.IsReady() and not IPC.vnavmesh.IsRunning() then
                    IPC.vnavmesh.PathfindAndMoveTo(Vector3(UnmountPosition.x, UnmountPosition.y, UnmountPosition.z), false)
                end
            end
            
            -- 等待导航完成
            yield("/wait " .. IntervalRate * 5)
        end
        
    elseif currentState == STATE.NAVIGATE_TO_FISHING then
        local distance = GetDistanceToPoint(FishingPosition.x, FishingPosition.y, FishingPosition.z)
        DebugLog("距离钓鱼位置: " .. distance)
        
        if distance <= 1 then
            ChangeState(STATE.CHECK_INVENTORY)  -- 移动到钓点后检查状态
        else
            Dismount()
            
            if IPC.vnavmesh.IsReady() and not IPC.vnavmesh.IsRunning() then
                IPC.vnavmesh.PathfindAndMoveTo(Vector3(FishingPosition.x, FishingPosition.y, FishingPosition.z), false)
            end
            
            -- 等待导航完成
            yield("/wait " .. IntervalRate * 5)
        end
        
    -- 新增：幻卡对局室状态处理
    elseif currentState == STATE.TRIPLE_TRIAD then
        DebugLog("检测到进入幻卡对局室，等待返回钓鱼区域")
        
        -- 等待直到返回钓鱼区域
        while IsInZone(579) do
            yield("/wait " .. IntervalRate * 5)
        end
        
        DebugLog("已返回钓鱼区域，重新准备钓鱼")
        ChangeState(STATE.USE_MEDICINE)  -- 返回后重新使用药品和检查鱼饵
        
    elseif currentState == STATE.USE_MEDICINE then
        IPC.vnavmesh.Stop()--停止可能存在的寻路状态
        if  Svc.Condition[6] or  Svc.Condition[42] then
            DebugLog("检测到钓鱼状态，退出钓鱼状态")
            StopFishing()
        else
            if UseMedicine() then
                ChangeState(STATE.CHECK_BAIT)
            else
                ChangeState(STATE.CHECK_BAIT) -- 即使药品使用失败也继续
            end
        end
        
    elseif currentState == STATE.CHECK_BAIT then
        if CheckAndChangeBait() then
            ChangeState(STATE.START_FISHING)
        else
            ChangeState(STATE.ERROR)
        end
        
    elseif currentState == STATE.START_FISHING then
        if StartFishing() then
            ChangeState(STATE.FISHING)
            reCount = 0
        else
            ChangeState(STATE.ERROR)
        end
        
    elseif currentState == STATE.FISHING then
    -- 检查是否进入幻卡对局室 (区域ID: 579)
    if IsInZone(579) then
        DebugLog("检测到进入幻卡对局室，停止钓鱼")
        ChangeState(STATE.TRIPLE_TRIAD)
        return true
    end
    
    -- 检查是否不在钓鱼状态（Condition 6: 钓鱼中，Condition 42: 等待上钩）
    if not Svc.Condition[6] and not Svc.Condition[42] then
        if reCount < 3 then
            reCount = reCount + 1
            yield("/wait " .. IntervalRate * 20) --等待四秒
        else
            DebugLog("检测到不在钓鱼状态，重新开始流程")
            ChangeState(STATE.TELEPORT)
            return true
        end
    end
    
    -- 检查是否需要停止钓鱼
    local freeSlots = GetInventoryFreeSlotCount()
    DebugLog("背包空格: " .. freeSlots)
    
    if freeSlots < NumInventoryFreeSlotThreshold or 
       NeedsRepair(RepairAmount) or 
       CanExtractMateria() then
        ChangeState(STATE._FISHINGSTOP)
    else
        -- 检查鱼饵数量
        if GetItemCount(FishingBaitId) == 0 then
            yield("/echo 鱼饵数量为0，脚本停止")
            ChangeState(STATE.ERROR)
        else
            -- 继续钓鱼
            yield("/wait " .. IntervalRate * 10)
        end
    end
        
    elseif currentState == STATE.STOP_FISHING then
        if StopFishing() then
            ChangeState(STATE.CHECK_INVENTORY)
        else
            ChangeState(STATE.ERROR)
        end
        
    elseif currentState == STATE.CHECK_INVENTORY then
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
        
    elseif currentState == STATE.REPAIR then
        if Repair() then
            ChangeState(STATE.CHECK_INVENTORY) -- 返回检查其他需求
        else
            ChangeState(STATE.CHECK_INVENTORY)
        end
        
    elseif currentState == STATE.EXTRACT_MATERIA then
        if ExtractMateria() then
            ChangeState(STATE.CHECK_INVENTORY) -- 返回检查其他需求
        else
            ChangeState(STATE.CHECK_INVENTORY)
        end
        
    elseif currentState == STATE.AETHERIA then
        if Aetheria() then
            ChangeState(STATE.CHECK_INVENTORY) -- 返回检查其他需求
        else
           ChangeState(STATE.CHECK_INVENTORY)
        end
        
    elseif currentState == STATE.ERROR then
        yield("/echo 脚本遇到错误,重新尝试")
        ChangeState(STATE.TELEPORT)
    end
    
    return true
end

-- 脚本入口点
DebugLog("脚本启动 - 状态机模式")
yield("/echo 开始自动钓收藏品")

-- 初始化状态机
currentState = STATE.INIT
stateStartTime = os.clock()

-- 主循环
while StateMachineLoop() do
    yield("/wait " .. IntervalRate)
end
