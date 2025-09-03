--[=====[
[[SND Metadata]]
author: Ahernika (原版作者) || poi0827 && deepseek (迁移至新版SND)
version: 1.2.1
description: >
  FisherAutoScrips：https://github.com/poi0827/SNDScripts/edit/main/FisherAutoScrips.lua 

  注意事项：

  ①如果需要自动吃药的话请安装潘多拉

  ②请开启DR自动防警惕

  ③兼容空天姬，需要在DR防警惕中写入额外文本命令 /e ktjys 佐戈秃鹰 (如果目标为佐戈秃鹰,灵岩之剑同理)

  ④请自行修改钓场点位，避免模型重叠

  ⑤兼容钓鱼紫票，请自行修改钓场

  ⑥新增根据艾欧泽亚时间自动切换钓场功能 双钓场模式建议使用空天姬，不兼容autohook（切预设太麻烦了）

plugin_dependencies:
- Lifestream
- vnavmesh
- TeleporterPlugin
- DailyRoutines
configs:
  FishingAddon:
    default: 1
    description: 选择钓鱼插件，0为Autohook，1为空天姬
    type: string
  FishingAetheryte1:
    default: 胡萨塔伊驿镇
    description: 钓场一的以太之光名字
    type: string
  FishingZoneID1:
    default: 1190
    description: 钓场一区域ID
    type: string
  UnmountPositionX1:
    default: -255.00215
    description: 钓场一下坐骑位置X坐标
    type: string
  UnmountPositionY1:
    default: -43.69279
    description: 钓场一下坐骑位置Y坐标
    type: string
  UnmountPositionZ1:
    default: 650.05786
    description: 钓场一下坐骑位置Z坐标
    type: string
  FishingPositionX1:
    default: -260.50952
    description: 钓场一位置X坐标
    type: string
  FishingPositionY1:
    default: -44.57518
    description: 钓场一位置Y坐标
    type: string
  FishingPositionZ1:
    default: 654.30914
    description: 钓场一位置Z坐标
    type: string
  TargetFish1:
    default: 佐戈秃鹰
    description: 钓场一目标鱼名称
    type: string
  FishingBaitId1:
    default: 43857
    description: 钓场一使用的鱼饵ID
    type: string
  FishingAetheryte2:
    default: 尾羽集落
    description: 钓场二的以太之光名字
    type: string
  FishingZoneID2:
    default: 398
    description: 钓场二区域ID
    type: string
  UnmountPositionX2:
    default: 454.22104
    description: 钓场二下坐骑位置X坐标
    type: string
  UnmountPositionY2:
    default: 58.429157
    description: 钓场二下坐骑位置Y坐标
    type: string
  UnmountPositionZ2:
    default: -807.5508
    description: 钓场二下坐骑位置Z坐标
    type: string
  FishingPositionX2:
    default: 453.72137
    description: 钓场二位置X坐标
    type: string
  FishingPositionY2:
    default: 58.429157
    description: 钓场二位置Y坐标
    type: string
  FishingPositionZ2:
    default: -809.5843
    description: 钓场二位置Z坐标
    type: string
  TargetFish2:
    default: 落雷鳗
    description: 钓场二目标鱼名称
    type: string
  FishingBaitId2:
    default: 12711
    description: 钓场二使用的鱼饵ID
    type: string
  EnableETTimeSwitch:
    default: true
    description: 是否启用根据艾欧泽亚时间自动切换钓场功能
    type: boolean
  ETStartHour:
    default: 22
    description: ET时间开始小时（0-23）
    type: string
  ETStartMinute:
    default: 0
    description: ET时间开始分钟（0-59）
    type: string
  ETEndHour:
    default: 03
    description: ET时间结束小时（0-24）
    type: string
  ETEndMinute:
    default: 19
    description: ET时间结束分钟（0-59）
    type: string
  ScripExchangeLocation:
    default: 游末邦
    description: 提交收藏品的大水晶名称
    type: string
  IntervalRate:
    default: 0.2
    description: 兑换时交互速度，单位为秒
    type: string
  NumInventoryFreeSlotThreshold:
    default: 5
    description: 当背包剩余空间小于该值时将停止钓鱼前往兑换票据
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
  MinItemsBeforeTurnins:
    default: 1
    description: 最少收藏品兑换数量
    type: string
  ScripOvercapLimit:
    default: 3900
    description: 橙票/紫票大于该值时停止提交收藏品，以防止溢出
    type: string
  DebugMode:
    default: 1
    description: DEBUG模式
    type: string

[[End Metadata]]
--]=====]

import("System.Numerics")

-- 获取配置
FishingAddon = tonumber(Config.Get("FishingAddon")) or 0

-- 钓场一配置
FishingAetheryte1 = Config.Get("FishingAetheryte1")
FishingZoneID1 = tonumber(Config.Get("FishingZoneID1"))
UnmountPosition1 = {
    x = tonumber(Config.Get("UnmountPositionX1")),
    y = tonumber(Config.Get("UnmountPositionY1")),
    z = tonumber(Config.Get("UnmountPositionZ1"))
}
FishingPosition1 = {
    x = tonumber(Config.Get("FishingPositionX1")),
    y = tonumber(Config.Get("FishingPositionY1")),
    z = tonumber(Config.Get("FishingPositionZ1"))
}
TargetFish1 = Config.Get("TargetFish1")
FishingBaitId1 = tonumber(Config.Get("FishingBaitId1")) or 0

-- 钓场二配置
FishingAetheryte2 = Config.Get("FishingAetheryte2")
FishingZoneID2 = tonumber(Config.Get("FishingZoneID2"))
UnmountPosition2 = {
    x = tonumber(Config.Get("UnmountPositionX2")),
    y = tonumber(Config.Get("UnmountPositionY2")),
    z = tonumber(Config.Get("UnmountPositionZ2"))
}
FishingPosition2 = {
    x = tonumber(Config.Get("FishingPositionX2")),
    y = tonumber(Config.Get("FishingPositionY2")),
    z = tonumber(Config.Get("FishingPositionZ2"))
}
TargetFish2 = Config.Get("TargetFish2")
FishingBaitId2 = tonumber(Config.Get("FishingBaitId2")) or 0

-- 时间配置
EnableETTimeSwitch = Config.Get("EnableETTimeSwitch") or false
ETStartHour = tonumber(Config.Get("ETStartHour")) or 0
ETStartMinute = tonumber(Config.Get("ETStartMinute")) or 0
ETEndHour = tonumber(Config.Get("ETEndHour")) or 24
ETEndMinute = tonumber(Config.Get("ETEndMinute")) or 0

-- 通用配置
IntervalRate = tonumber(Config.Get("IntervalRate")) or 0.2
NumInventoryFreeSlotThreshold = tonumber(Config.Get("NumInventoryFreeSlotThreshold"))
DoExtract = Config.Get("DoExtract")
DoRepair = Config.Get("DoRepair")
MedicineToUse = Config.Get("MedicineToUse")
RepairAmount = tonumber(Config.Get("RepairAmount"))
MinItemsBeforeTurnins = tonumber(Config.Get("MinItemsBeforeTurnins")) or 1
ScripOvercapLimit = tonumber(Config.Get("ScripOvercapLimit"))
DebugMode = tonumber(Config.Get("DebugMode"))

-- 根据选择的钓鱼插件设置相应的命令
if FishingAddon == 1 then
    -- 空天姬模式 - 根据当前钓场选择目标鱼
    StartFishingCommand1 = function()
        local targetFish = GetCurrentTargetFish()
        return "/e ktjys " .. targetFish
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

-- 票据兑换设置
ExchangeItemTable = {
    { 4, 8, 6, 1000, 41785 }, -- 橙票用于兑换 (默认为犎牛角笛的交换票据)
    { 4, 1, 0, 20, 33914 },   -- 紫票用于兑换 (默认为高级强心剂)
}

CollectibleItemTable = { -- 用于提交的收藏品列表
    -- 橙票收藏品
    { 6, 43761, 10, 41785 }, -- 佐戈秃鹰
    -- 紫票收藏品
    { 28, 36473, 10, 33914 }, -- 灵岩之剑
    { 87, 12828, 10, 33914 }, -- 落雷鳗
    --格式为{ 收藏品在提交界面所在行数 , 物品id , 提交职业（捕鱼人为10）, 票据id（橙票为41875，紫票为33914） }
}

-- 票据使用统计
TotalOrangeScripsUsed = 0
TotalPurpleScripsUsed = 0

MsgDelay = 10
TimeoutThreshold = 10
StopMain = false

function try(try_catch)
    local status, result = pcall(try_catch[1])
    if not status and try_catch[2] then
        try_catch[2](result)
    end
    return status, result
end

function catch(handler)
    return handler
end

-- 调试日志函数
function DebugLog(message)
    if DebugMode == 1 then
        yield("/echo [DEBUG] " .. message)
    end
end

-- 获取当前艾欧泽亚时间的小时和分钟
function GetETHourMinute()
    if Instances and Instances.Framework and Instances.Framework.EorzeaTime then
        local totalSeconds = Instances.Framework.EorzeaTime
        local totalMinutes = math.floor(totalSeconds / 60)
        local hours = math.floor(totalMinutes / 60) % 24
        local minutes = totalMinutes % 60
        return hours, minutes
    else
        DebugLog("无法获取艾欧泽亚时间")
        return 0, 0
    end
end

-- 判断是否在指定的ET时间范围内
function IsInETTimeRange()
    if  not EnableETTimeSwitch then
        DebugLog("ET时间切换功能已禁用，默认使用钓场一")
        return true
    end
    
    local currentHour, currentMinute = GetETHourMinute()
    local currentTotalMinutes = currentHour * 60 + currentMinute
    local startTotalMinutes = ETStartHour * 60 + ETStartMinute
    local endTotalMinutes = ETEndHour * 60 + ETEndMinute
    
    DebugLog(string.format("当前ET时间: %02d:%02d, 时间范围: %02d:%02d - %02d:%02d", 
                          currentHour, currentMinute, ETStartHour, ETStartMinute, ETEndHour, ETEndMinute))
    
    -- 处理跨天的时间范围
    if startTotalMinutes <= endTotalMinutes then
        -- 正常时间范围（不跨天）
        return currentTotalMinutes >= startTotalMinutes and currentTotalMinutes < endTotalMinutes
    else
        -- 跨天时间范围（例如 22:00 - 04:00）
        return currentTotalMinutes >= startTotalMinutes or currentTotalMinutes < endTotalMinutes
    end
end

-- 根据ET时间判断当前应该使用哪个钓场
function GetCurrentFishingZone()
    if not IsInETTimeRange() then
        DebugLog("当前ET时间不在范围内，使用钓场一")
        return {
            aetheryte = FishingAetheryte1,
            zoneId = FishingZoneID1,
            unmountPos = UnmountPosition1,
            fishingPos = FishingPosition1,
            targetFish = TargetFish1,
            baitId = FishingBaitId1
        }
    else
        DebugLog("当前ET时间在范围内，使用钓场二")
        return {
            aetheryte = FishingAetheryte2,
            zoneId = FishingZoneID2,
            unmountPos = UnmountPosition2,
            fishingPos = FishingPosition2,
            targetFish = TargetFish2,
            baitId = FishingBaitId2
        }
    end
end

-- 获取当前钓场的目标鱼
function GetCurrentTargetFish()
    local currentZone = GetCurrentFishingZone()
    return currentZone.targetFish
end

-- 获取当前钓场的鱼饵ID
function GetCurrentBaitId()
    local currentZone = GetCurrentFishingZone()
    return currentZone.baitId
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

    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
    return distance
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
    -- 如果不启用修理功能，直接返回 false
    if not DoRepair then
        return false
    end
    
    local needsRepair = Inventory.GetItemsInNeedOfRepairs(threshold)
    -- 检查是否有装备的耐久度低于阈值
    -- 有三件以上需要修理再修
    if needsRepair.Count > 2 then
        DebugLog("需要修理的装备数量: " .. needsRepair.Count)
        return true
    else
        return false
    end
end

function CanExtractMateria()
    -- 如果不启用精炼功能，直接返回 false
    if not DoExtract then
        return false
    end
    
    local spiritbondedItems = Inventory.GetSpiritbondedItems()
    -- 检查是否有装备可以精制魔晶石
    -- 有三件以上需要精制再进行精制
    if spiritbondedItems.Count > 2 then
        DebugLog("可以精炼的装备数量: " .. spiritbondedItems.Count)
        return true
    else
        return false
    end
end

function Repair()
    DebugLog("尝试修理装备")
    try {
        function()
            IPC.vnavmesh.Stop()
            if Svc.Condition[4] then
                DebugLog("尝试下坐骑")
                Dismount()
            end
            
            DebugLog("打开修理界面")
            local timeout_start = os.clock()
            while not Addons.GetAddon("Repair").Ready do
                yield("/gaction 修理")
                yield("/wait " .. IntervalRate * 5)
                if os.clock() - timeout_start > 30 then
                    DebugLog("修理界面打开超时")
                    return
                end
            end
            
            yield("/callback Repair true 0")
            yield("/wait " .. IntervalRate)
            
            if Addons.GetAddon("SelectYesno").Ready then
                yield("/callback SelectYesno true 0")
            end
            
            timeout_start = os.clock()
            while Svc.Condition[39] do -- 39 = Repairing condition
                 yield("/wait " .. IntervalRate * 10)
                 if os.clock() - timeout_start > 60 then
                     DebugLog("修理过程超时")
                     break
                 end
            end
            yield("/wait " .. IntervalRate * 15)  
            yield("/callback Repair true -1")
            
            DebugLog("修理完成")
        end,
        catch(function(err)
            DebugLog("修理过程中出错: " .. tostring(err))
        end)
    }
end

function ExtractMateria()
    DebugLog("尝试精炼魔晶石")
    try {
        function()
            IPC.vnavmesh.Stop()
            if Svc.Condition[4] then
                DebugLog("尝试下坐骑")
                Dismount()
            end
            
            DebugLog("打开精炼界面")
            yield("/gaction 精制魔晶石")
            
            local timeout_start = os.clock()
            while not Addons.GetAddon("Materialize").Ready do
                yield("/wait " .. IntervalRate)
                if os.clock() - timeout_start > 30 then
                    DebugLog("精炼界面打开超时")
                    return
                end
            end
            
            while CanExtractMateria(100) do
                yield("/callback Materialize true 2 0")
                yield("/wait " .. IntervalRate * 5)
                
                if Addons.GetAddon("MaterializeDialog").Ready then
                    yield("/callback MaterializeDialog true 0")
                end
                
                timeout_start = os.clock()

                 while Svc.Condition[39] do
                     yield("/wait " .. IntervalRate * 30)
                     if os.clock() - timeout_start > 60 then
                         DebugLog("精炼过程超时")
                         break
                     end
                 end
                
                yield("/wait " .. IntervalRate * 15) 
            end
            
            yield("/wait " .. IntervalRate * 10)
            yield("/callback Materialize true -1")
            DebugLog("精炼魔晶石完成")
        end,
        catch(function(err)
            DebugLog("精炼过程中出错: " .. tostring(err))
        end)
    }
end

function GetItemCount(itemId)
    return Inventory.GetItemCount(itemId)
end

function GetInventoryFreeSlotCount()
    return Inventory.GetFreeInventorySlots()
end

function IsPlayerAvailable()
    return Player.Available
end

function GetTargetName()
    return Entity.Target and Entity.Target.Name or ""
end

function ClearTarget()
    yield("/target clear")
end

function IsInZone(zoneId)
    return Svc.ClientState.TerritoryType == zoneId
end

function GetZoneID()
    return Svc.ClientState.TerritoryType
end

function TerritorySupportsMounting()
    if not IsPlayerAvailable() or Player.CanMount == nil then
        return false -- 玩家不可用或属性未定义时返回false
    end
    return Player.CanMount
end

function HasFlightUnlocked()
    if not IsPlayerAvailable() or Player.CanFly == nil then
        return false -- 玩家不可用或属性未定义时返回false
    end
    return Player.CanFly
end

-- 检查并更换鱼饵
function CheckAndChangeBait()
    local currentBaitId = GetCurrentBaitId()
    
    if currentBaitId == nil or currentBaitId == 0 then
        DebugLog("未设置当前钓场的鱼饵ID，跳过鱼饵检查")
        return true
    end
    
    -- 检查当前鱼饵
    local currentBait = Player.FishingBait
    if currentBait ~= currentBaitId then
        DebugLog("当前鱼饵与配置不同，更换鱼饵")
        yield("/pdr bait " .. tostring(currentBaitId))  -- 确保转换为字符串
        yield("/wait " .. IntervalRate * 3)
        
        -- 确认鱼饵是否更换成功
        if Player.FishingBait ~= currentBaitId then
            yield("/echo 鱼饵更换失败，请检查鱼饵ID是否正确")
            return false
        end
    end
    
    -- 检查鱼饵数量
    local baitCount = GetItemCount(currentBaitId)
    if baitCount == 0 then
        yield("/echo 鱼饵数量为0，脚本停止")
        return false
    end
    
    DebugLog("当前鱼饵数量: " .. baitCount)
    return true
end

-- 检查并切换到捕鱼人职业
function CheckAndSwitchToFisher()
    local currentJobId = Player.Job.Id
    if currentJobId == 18 then -- 捕鱼人职业ID
        DebugLog("当前已是捕鱼人职业")
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
        
        -- 尝试使用命令切换装备
        yield('/gs change "' .. fisherGearset.Name .. '"')
        yield("/wait " .. IntervalRate * 3)
        
        -- 确认是否切换成功
        if Player.Job.Id == 18 then
            DebugLog("成功切换到捕鱼人职业")
            return true
        else
            yield("/echo 切换到捕鱼人职业失败，请手动切换")
            return false
        end
    else
        yield("/echo 未找到捕鱼人装备套装，脚本停止")
        return false
    end
end

-- 恢复配置读取的药品使用脚本
function UseMedicine()
    DebugLog("开始使用药品")
    
    -- 从配置读取药品名称
    local medicine = MedicineToUse
    DebugLog("从配置获取药品名称: " .. tostring(medicine))
    
    -- 兼容无药品配置情况：直接跳过，不输出错误
    if not medicine or medicine == "" then
        DebugLog("配置中未设置药品名称，跳过使用药品")
        return
    end
    
    -- 新增：检查是否已有强化药状态（状态ID: 49）
    if HasStatus(49) then
        DebugLog("已检测到强化药状态（状态ID: 49），跳过使用")
        return
    end
    
    -- 使用/puseitem命令，无视HQ版本
    local medicineCommand = '/puseitem "' .. medicine .. '"'
    DebugLog("执行药品命令: " .. medicineCommand)
    yield(medicineCommand)
    
    -- 等待药品生效（15秒超时）
    local timeout_start = os.clock()
    local statusApplied = false
    DebugLog("等待药品效果生效...")
    repeat
        yield("/wait 1")
        if HasStatus(49) then -- 检查强化药状态（状态ID: 49）
            statusApplied = true
            break
        end
    until os.clock() - timeout_start > 15

    if statusApplied then
        DebugLog("药品效果已成功应用")
    else
        DebugLog("警告：药品命令已执行，但未检测到强化药状态（状态ID: 49）")
    end
end

function Dismount()
    DebugLog("开始下坐骑")
    
    -- 检查玩家对象是否可用
    local player = Svc.ClientState.LocalPlayer
    if not player or not player.Position then
        DebugLog("玩家不可用，无法下坐骑")
        return
    end
    
    -- 检查角色是否处于坐骑状态 (条件77 = 已上坐骑)
    if Svc.Condition[77] then
        -- 执行随机坐骑动作 (这会触发下坐骑)
        yield("/gaction 随机坐骑")
        
        -- 初始化变量用于检测角色是否在移动
        local muuv = 1  -- 移动检测标志
        
        -- 记录当前位置坐标，添加安全检查
        local muuvX, muuvY, muuvZ
        if player and player.Position then
            muuvX = player.Position.X
            muuvY = player.Position.Y
            muuvZ = player.Position.Z
        else
            DebugLog("玩家位置不可用，跳过移动检测")
            muuv = 0  -- 直接设置为已停止移动
        end
        
        -- 循环检测角色是否仍在移动
        while muuv == 1 do
            yield("/wait " .. IntervalRate * 5)
            
            -- 检查玩家和位置是否仍然可用
            if not player or not player.Position then
                DebugLog("玩家位置不可用，停止移动检测")
                break
            end
            
            -- 检查位置是否没有变化 (表示已停止移动)
            if muuvX == player.Position.X and muuvY == player.Position.Y and muuvZ == player.Position.Z then
                muuv = 0  -- 设置标志为0表示已停止移动
            end
            
            -- 更新记录的位置坐标
            muuvX = player.Position.X
            muuvY = player.Position.Y
            muuvZ = player.Position.Z
        end

        -- 如果仍然在坐骑状态 (条件77仍然为真)
        if Svc.Condition[77] then
            local random_j = 0  -- 随机偏移量，用于尝试不同位置下坐骑
            
            -- 标签: DISMOUNT_START - 下坐骑失败时的重试点
            ::DISMOUNT_START::
            
            -- 检查玩家和位置是否可用
            if not player or not player.Position then
                DebugLog("玩家位置不可用，无法生成随机位置")
                return
            end
            
            -- 生成一个随机目标位置 (在当前坐标基础上添加随机偏移)
            local land_x = player.Position.X + math.random(0, random_j)
            local land_y = player.Position.Y + math.random(0, random_j)
            local land_z = player.Position.Z + math.random(0, random_j)
            
            -- 使用vnavmesh导航到随机位置
            IPC.vnavmesh.PathfindAndMoveTo(Vector3(land_x, land_y, land_z), false)

            -- 设置超时计时器
            local timeout_start = os.clock()
            
            -- 等待导航完成
            repeat
                yield("/wait " .. IntervalRate)
                
                -- 检查是否超时
                if os.clock() - timeout_start > TimeoutThreshold then
                    DebugLog("未能导航到可下坐骑的地形，尝试前往其他位置")
                    random_j = random_j + 1  -- 增加随机偏移量
                    goto DISMOUNT_START  -- 跳回重试点
                end
            until not IPC.vnavmesh.IsRunning()  -- 直到导航停止

            -- 再次尝试下坐骑
            yield('/gaction 随机坐骑')

            -- 重置超时计时器
            timeout_start = os.clock()
            
            -- 等待直到成功下坐骑
            repeat
                yield("/wait " .. IntervalRate)
                
                -- 检查是否超时
                if os.clock() - timeout_start > TimeoutThreshold then
                    DebugLog("下坐骑失败，尝试前往其他位置")
                    random_j = random_j + 1  -- 增加随机偏移量
                    goto DISMOUNT_START  -- 跳回重试点
                end
            until not Svc.Condition[77]  -- 直到不再处于坐骑状态
        end
    end

    -- 检查角色是否处于坐骑条件 (条件4 = 坐骑条件)
    if Svc.Condition[4] then
        -- 等待一段时间
        yield("/wait " .. IntervalRate * 10)
        
        -- 执行随机坐骑动作
        yield('/gaction 随机坐骑')
        
        -- 等待直到不再处于坐骑条件
        repeat
            yield("/wait " .. IntervalRate)
        until not Svc.Condition[4]  -- 直到坐骑条件为假
    end
    
    -- 记录下坐骑完成的日志
    DebugLog("下坐骑完成")
end

function CollectableAppraiser()
    DebugLog("开始提交收藏品")
    --未打开收藏品交易界面时打开界面
    while not Addons.GetAddon("CollectablesShop").Ready do
        if GetTargetName() ~= "收藏品交易员" then
            DebugLog("寻找收藏品交易员")
            yield("/target 收藏品交易员")
        elseif not Addons.GetAddon("SelectIconString").Ready then
            DebugLog("与收藏品交易员交互")
            Entity.Target:Interact()
        else
            DebugLog("选择交互选项")
            yield("/callback SelectIconString true 0")
        end
        yield("/wait " .. IntervalRate)
    end
    
    yield("/wait " .. IntervalRate * 10)

    for _, item in ipairs(CollectibleItemTable) do
        local collectible_to_turnin_row = item[1]
        local collectible_item_id = item[2]
        local job_for_turnin = item[3]
        local turnins_scrip_type = item[4]
        
        DebugLog("提交道具: " .. collectible_item_id)
        
        -- 使用 Inventory.GetCollectableItemCount 来获取收藏品数量，minimumCollectability 默认值为 1
        if Inventory.GetCollectableItemCount(collectible_item_id, 1) > 0 then
            DebugLog("选择职业: " .. job_for_turnin)
            yield("/callback CollectablesShop true 14 " .. job_for_turnin)
            yield("/wait " .. IntervalRate)
            
            DebugLog("选择收藏品行: " .. collectible_to_turnin_row)
            yield("/callback CollectablesShop true 12 " .. collectible_to_turnin_row)
            yield("/wait " .. IntervalRate)
            
            local scrips_owned = GetItemCount(turnins_scrip_type)
            DebugLog("当前票据数量: " .. scrips_owned)
            
            while scrips_owned <= ScripOvercapLimit and Inventory.GetCollectableItemCount(collectible_item_id, 1) > 0 do
                DebugLog("提交收藏品")
                yield("/callback CollectablesShop true 15 0")
                yield("/wait " .. IntervalRate * 2)
                scrips_owned = GetItemCount(turnins_scrip_type)
                DebugLog("提交后票据数量: " .. scrips_owned)
            end
            
            yield("/wait " .. IntervalRate)
        else
            DebugLog("没有可提交的收藏品: " .. collectible_item_id)
        end
        
        yield("/wait " .. IntervalRate)
        
        if Addons.GetAddon("SelectYesno").Ready then
            DebugLog("处理确认对话框")
            yield("/callback SelectYesno true 1")
            break
        end
    end
    
    yield("/wait " .. IntervalRate)
    DebugLog("关闭收藏品界面")
    yield("/callback CollectablesShop true -1")
    
    if GetTargetName() ~= "" then
        DebugLog("清除目标")
        ClearTarget()
        yield("/wait " .. IntervalRate)
    end
end

function ScripExchange()
    DebugLog("开始兑换票据")
    local session_orange_used = 0
    local session_purple_used = 0
    
    -- 打开兑换界面
    while not Addons.GetAddon("InclusionShop").Ready do
        if GetTargetName() ~= "工票交易员" then
            DebugLog("寻找工票交易员")
            yield("/target 工票交易员")
        elseif not Addons.GetAddon("SelectIconString").Ready then
            DebugLog("与工票交易员交互")
            Entity.Target:Interact()
        else
            DebugLog("选择交互选项")
            yield("/callback SelectIconString true 0")
        end
        yield("/wait " .. IntervalRate)
    end

    yield("/wait " .. IntervalRate * 10)

    -- 打开对应目录
    for _, reward in ipairs(ExchangeItemTable) do
        local scrip_exchange_category = reward[1]
        local scrip_exchange_subcategory = reward[2]
        local scrip_exchange_item_to_buy_row = reward[3]
        local collectible_scrip_price = reward[4]
        local scrip_type = reward[5]
        
        DebugLog("兑换目录: " .. scrip_exchange_category .. ", 子目录: " .. scrip_exchange_subcategory)
        DebugLog("需要票据: " .. collectible_scrip_price)
        
        yield("/wait " .. IntervalRate * 5)
        yield("/callback InclusionShop true 12 " .. scrip_exchange_category)
        yield("/wait " .. IntervalRate)
        yield("/callback InclusionShop true 13 " .. scrip_exchange_subcategory)
        yield("/wait " .. IntervalRate)

        -- 开始兑换
        local scrips_owned = GetItemCount(scrip_type)
        DebugLog("当前票据数量: " .. scrips_owned)
        
        if scrips_owned >= collectible_scrip_price then
            local total_items_to_buy = math.floor(scrips_owned / collectible_scrip_price)
            local scrips_used = 0

            -- 计算每次兑换的数量，最多99个
            while total_items_to_buy > 0 do
                local items_to_buy = math.min(total_items_to_buy, 99) -- 每次最多兑换99个
                local scrips_to_use = items_to_buy * collectible_scrip_price
                scrips_used = scrips_used + scrips_to_use
                
                -- 执行兑换
                DebugLog("购买数量: " .. items_to_buy)
                DebugLog("使用票据: " .. scrips_to_use)
                yield("/callback InclusionShop true 14 " .. scrip_exchange_item_to_buy_row .. " " .. items_to_buy)
                yield("/wait " .. IntervalRate * 5)

                -- 如果兑换窗口已经准备好，进行确认
                if Addons.GetAddon("ShopExchangeItemDialog").Ready then
                    yield("/callback ShopExchangeItemDialog true 0")
                    yield("/wait " .. IntervalRate)
                    
                    -- 记录使用的票据数量
                    if scrip_type == 41785 then -- 橙票
                        session_orange_used = session_orange_used + scrips_to_use
                        TotalOrangeScripsUsed = TotalOrangeScripsUsed + scrips_to_use
                    elseif scrip_type == 33914 then -- 紫票
                        session_purple_used = session_purple_used + scrips_to_use
                        TotalPurpleScripsUsed = TotalPurpleScripsUsed + scrips_to_use
                    end
                end

                -- 更新剩余需要兑换的物品数量
                total_items_to_buy = total_items_to_buy - items_to_buy

            end
        else
            DebugLog("票据不足，无法兑换")
        end
    end
    
    -- 结束兑换
    yield("/wait " .. IntervalRate)
    DebugLog("关闭兑换界面")
    yield("/callback InclusionShop true -1")

    -- 输出本次兑换使用的票据数量
    if session_orange_used > 0 or session_purple_used > 0 then
        DebugLog("本次兑换使用: " .. session_orange_used .. " 橙票, " .. session_purple_used .. " 紫票")
        DebugLog("累计使用: " .. TotalOrangeScripsUsed .. " 橙票, " .. TotalPurpleScripsUsed .. " 紫票")
        
        yield("/echo [票据统计] 本次兑换使用: " .. session_orange_used .. " 橙票, " .. session_purple_used .. " 紫票")
        yield("/echo [票据统计] 累计使用: " .. TotalOrangeScripsUsed .. " 橙票, " .. TotalPurpleScripsUsed .. " 紫票")
    else
        DebugLog("本次没有兑换任何物品")
    end

    if GetTargetName() ~= "" then
        DebugLog("清除目标")
        ClearTarget()
        yield("/wait " .. IntervalRate)
    end
    return true
end


function PathToScrip()
    DebugLog("前往票据兑换地点: 游末邦")
    -- 传送至游末邦
    yield("/tp 游末邦")
    yield("/wait " .. IntervalRate * 15)
    
    -- 等待直到确认到达游末邦
    local timeout_start = os.clock()
    repeat
        yield("/wait " .. IntervalRate)
        if os.clock() - timeout_start > 60 then -- 60秒超时
            DebugLog("传送超时，重新传送")
            yield("/tp 游末邦")
            timeout_start = os.clock() -- 重置超时计时器
        end
    until (GetZoneID() == 820) and 
          not Svc.Condition[27] and  -- 27 = Casting condition
          not Svc.Condition[45] and  -- 45 = BetweenAreas condition
          not Svc.Condition[51]      -- 51 = Occupied condition
    
    -- 增加额外的等待时间，确保地图完全加载
    yield("/wait " .. IntervalRate * 20) -- 额外等待确保完全加载
    
    -- 直接导航至收藏品交易员位置 (游末邦坐标)
    DebugLog("导航至收藏品交易员位置")
    IPC.vnavmesh.PathfindAndMoveTo(Vector3(16.979, 82.050, -19.189), false)
    
    -- 等待导航完成
    local timeout_start = os.clock()
    while IPC.vnavmesh.IsRunning() do
        yield("/wait " .. IntervalRate)
        if os.clock() - timeout_start > 30 then -- 30秒超时
            DebugLog("导航超时，停止导航")
            IPC.vnavmesh.Stop()
            break
        end
    end
    
    yield("/wait " .. IntervalRate * 5) -- 导航完成后额外等待
end

function CanTurnin()
    for _, item in ipairs(CollectibleItemTable) do
        local collectible_item_id = item[2]
        if tonumber(Inventory.GetCollectableItemCount(collectible_item_id, 1)) >= tonumber(MinItemsBeforeTurnins) then
            DebugLog("可以提交收藏品: " .. collectible_item_id)
            return true
        end
    end
    DebugLog("没有足够的收藏品可以提交")
    return false
end

function CollectableAppraiserScripExchange()
    if IsPlayerAvailable() then
        PathToScrip()
        yield("/wait " .. IntervalRate * 20)
        
        -- 在提交收藏品前进行修理和精炼
        if NeedsRepair(RepairAmount) then
           Repair()
        end

        if CanExtractMateria() then
           ExtractMateria()
        end

        yield("/wait " .. IntervalRate * 10)
        
        while CanTurnin() do
            CollectableAppraiser()
            yield("/wait " .. IntervalRate * 20)
            ScripExchange()
            yield("/wait " .. IntervalRate * 20)
        end
        
        yield("/wait " .. IntervalRate * 10)
        ScripExchange()
    else
        DebugLog("玩家不可用，无法执行兑换操作")
    end
end

function StopFishing()
    DebugLog("停止钓鱼")
    yield("/wait " .. IntervalRate)
    if Svc.Condition[6] or Svc.Condition[42] or Svc.Condition[27] or Svc.Condition[51] then
        DebugLog("等待下次上钩后停止")
        yield("/echo 下次上钩后停止钓鱼")
        local startTime = os.time()
        repeat
            if os.time() - startTime > 60 then
                yield("/e 超时1分钟自动取消")
                break
            end
            yield("/wait " .. IntervalRate)
        until Svc.Condition[42] -- 42 = Fishing condition
        
        yield(StopFishingCommand1)
        yield("/wait " .. IntervalRate)
        
        repeat  
            yield("/wait " .. IntervalRate * 10)
            yield("/wait " .. IntervalRate)
            yield(StopFishingCommand2)
        until not Svc.Condition[6] and not Svc.Condition[42] 
    else    
        yield(StopFishingCommand1)
        yield("/wait " .. IntervalRate)
        yield(StopFishingCommand2)
        yield("/wait " .. IntervalRate * 10)
    end
    DebugLog("钓鱼已停止")
end

function ContinueFishing()
    DebugLog("继续钓鱼 - 步骤1: 检查区域")
    
    local currentZone = GetCurrentFishingZone()
    
    -- 如果不在钓鱼区域，尝试传送
    if not IsInZone(currentZone.zoneId) then
        DebugLog("不在钓鱼区域，尝试传送")
        
        -- 等待直到可以传送
        while Svc.Condition[27] or Svc.Condition[45] or Svc.Condition[51] do
            yield("/wait " .. IntervalRate * 5)
        end
        
        DebugLog("执行传送")
        yield("/tp " .. currentZone.aetheryte)
        
        -- 等待传送完成
        local timeout_start = os.clock()
        repeat
            yield("/wait " .. IntervalRate * 5)
            if os.clock() - timeout_start > 30 then -- 30秒超时
                DebugLog("传送超时，重新尝试")
                yield("/tp " .. currentZone.aetheryte)
                timeout_start = os.clock() -- 重置超时计时器
            end
        until IsInZone(currentZone.zoneId) and 
              not Svc.Condition[27] and  -- 27 = Casting condition
              not Svc.Condition[45] and  -- 45 = BetweenAreas condition
              not Svc.Condition[51]      -- 51 = Occupied condition
    end
    
    DebugLog("继续钓鱼 - 步骤2: 检查距离")
    local distance = GetDistanceToPoint(currentZone.unmountPos.x, currentZone.unmountPos.y, currentZone.unmountPos.z)
    DebugLog("距离下坐骑位置: " .. distance)
    
    if distance > 20 then
        DebugLog("距离下坐骑位置较远，准备导航")
        
        -- 等待vnavmesh就绪 (超时时间改为60秒)
        local timeout_start = os.clock()
        while not IPC.vnavmesh.IsReady() do
            yield("/wait " .. IntervalRate)
            if os.clock() - timeout_start > 60 then -- 60秒超时
                DebugLog("vnavmesh未就绪，跳过导航")
                break
            end
        end
        
        if IPC.vnavmesh.IsReady() then
            -- 确保在坐骑上
            if not Svc.Condition[4] and not Svc.Condition[77] then
                DebugLog("上坐骑")
                yield('/gaction 随机坐骑')
                yield("/wait " .. IntervalRate * 3)
            end
            
            -- 导航前往下坐骑位置
            while not IPC.vnavmesh.IsRunning() do
                DebugLog("路径计算器未运行，初始化导航")
                IPC.vnavmesh.PathfindAndMoveTo(Vector3(currentZone.unmountPos.x, currentZone.unmountPos.y, currentZone.unmountPos.z), true)
                
                if os.clock() - timeout_start > 30 then
                    DebugLog("错误: 导航初始化超时30秒")
                    break
                end
                yield("/wait 1")
            end
            DebugLog("路径计算器已启动")

                yield("/wait 1")
            -- 等待导航完成且距离小于1
            local timeout_start = os.clock()
            while IPC.vnavmesh.IsRunning() or GetDistanceToPoint(currentZone.unmountPos.x, currentZone.unmountPos.y, currentZone.unmountPos.z) > 1 do
                yield("/wait " .. IntervalRate)
                if os.clock() - timeout_start > 60 then -- 60秒超时
                    DebugLog("导航超时，停止导航")
                    IPC.vnavmesh.Stop()
                    break
                end
            end
        end
    else
        DebugLog("距离下坐骑位置较近，直接下坐骑")
    end
    
    DebugLog("继续钓鱼 - 步骤3: 下坐骑")
    Dismount()
    
    -- 下坐骑后增加短暂延迟
    yield("/wait " .. IntervalRate * 2)
    
    DebugLog("继续钓鱼 - 步骤4: 导航至钓鱼位置")
    local fishing_distance = GetDistanceToPoint(currentZone.fishingPos.x, currentZone.fishingPos.y, currentZone.fishingPos.z)
    if fishing_distance > 2 then
        DebugLog("距离钓鱼位置: " .. fishing_distance)
        
        -- 等待vnavmesh就绪 (超时时间改为60秒)
        local timeout_start = os.clock()
        while not IPC.vnavmesh.IsReady() do
            yield("/wait " .. IntervalRate)
            if os.clock() - timeout_start > 60 then -- 60秒超时
                DebugLog("vnavmesh未就绪，跳过导航")
                break
            end
        end
        
        if IPC.vnavmesh.IsReady() then
            IPC.vnavmesh.PathfindAndMoveTo(Vector3(currentZone.fishingPos.x, currentZone.fishingPos.y, currentZone.fishingPos.z), false)
            
            -- 等待导航完成且距离小于1
            local timeout_start = os.clock()
            while IPC.vnavmesh.IsRunning() or GetDistanceToPoint(currentZone.fishingPos.x, currentZone.fishingPos.y, currentZone.fishingPos.z) > 1 do
                yield("/wait " .. IntervalRate)
                if os.clock() - timeout_start > 30 then -- 30秒超时
                    DebugLog("导航到钓鱼位置超时，停止导航")
                    IPC.vnavmesh.Stop()
                    break
                end
            end
        end
    else
        DebugLog("已经在钓鱼位置附近")
    end
    
    DebugLog("继续钓鱼 - 步骤5: 检查并更换鱼饵")
    if not CheckAndChangeBait() then
        StopMain = true
        return
    end
    
    DebugLog("继续钓鱼 - 步骤6: 开始钓鱼")
    if type(StartFishingCommand1) == "function" then
        yield(StartFishingCommand1())
    else
        yield(StartFishingCommand1)
    end
    yield("/wait " .. IntervalRate)
    yield(StartFishingCommand2)
    DebugLog("继续钓鱼 - 完成")
end

function Main()
    DebugLog("主循环开始")
    
    -- 检查鱼饵数量
    if not CheckAndChangeBait() then
        StopMain = true
        return
    end
    
    local i_count = GetInventoryFreeSlotCount()
    DebugLog("当前背包空格: " .. i_count)
    
    -- 等待直到背包空间不足或需要修理或需要更换钓场
    while i_count >= NumInventoryFreeSlotThreshold do
        yield("/wait " .. IntervalRate * 50) --10秒检测一次
        local currentZone = GetCurrentFishingZone()
        
        -- 检查鱼饵数量
        local currentBaitId = GetCurrentBaitId()
        if GetItemCount(currentBaitId) == 0 then
            yield("/echo 鱼饵数量为0，脚本停止")
            StopMain = true
            return
        end
        
        -- 检查是否需要修理或精炼
        if NeedsRepair(RepairAmount) then
            break
        end
        if CanExtractMateria() then
            break
        end
        if not IsInZone(currentZone.zoneId) then
            yield("/echo 需要更换钓场")
            break
        end
        
        i_count = GetInventoryFreeSlotCount()
        DebugLog("检查背包空格: " .. i_count)
    end

    -- 等待完成最后的钓鱼状态
    StopFishing()
    yield("/echo 正在检查食药, 精制魔晶石, 修理装备并提交收藏品")
    
    yield("/wait " .. IntervalRate * 10)

    -- 现场任务
    yield("/wait " .. IntervalRate * 10)
    Dismount()
    yield("/wait " .. IntervalRate * 10)
    UseMedicine()
    yield("/wait " .. IntervalRate * 15)

    if NeedsRepair(RepairAmount) then
        Repair()
    end

    if CanExtractMateria() then
        ExtractMateria()
    end

    i_count = GetInventoryFreeSlotCount()
    DebugLog("处理后背包空格: " .. i_count)
    
    if i_count < NumInventoryFreeSlotThreshold then
        DebugLog("背包空间不足，前往兑换")
        yield("/echo 正在前往收藏品交易位置")
        CollectableAppraiserScripExchange()
    else
        DebugLog("背包空间充足，不需要兑换")
    end
    
    yield("/wait " .. IntervalRate * 20)
    yield("/echo 继续钓鱼")
    ContinueFishing()
end

-- 插件检查函数
function CheckPlugins()
    DebugLog("开始检查插件")
    local requiredPlugins = {"Lifestream", "vnavmesh", "TeleporterPlugin"}
    local allPluginsAvailable = true
    
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
            DebugLog("缺少插件: " .. plugin)
            allPluginsAvailable = false
        end
    end
    
    DebugLog("插件检查完成: " .. tostring(allPluginsAvailable))
    return allPluginsAvailable
end

-- 脚本入口点
DebugLog("脚本启动")
yield("/echo 开始自动钓收藏品")

-- 显示当前ET时间
local currentHour, currentMinute = GetETHourMinute()
yield("/echo [INFO] 当前艾欧泽亚时间: " .. string.format("%02d:%02d", currentHour, currentMinute))

-- 显示ET时间切换功能状态
if EnableETTimeSwitch  then
    yield("/echo [INFO] ET时间切换功能已启用")
    yield("/echo [INFO] 时间范围: " .. string.format("%02d:%02d - %02d:%02d", ETStartHour, ETStartMinute, ETEndHour, ETEndMinute))
else
    yield("/echo [INFO] ET时间切换功能已禁用，始终使用钓场一")
end

-- 添加错误处理
local success, err = pcall(function()
    if CheckPlugins() then
        DebugLog("所有插件已安装")
        
        -- 检查并切换到捕鱼人职业
        if not CheckAndSwitchToFisher() then
            return
        end
        
        Dismount()
        yield("/wait " .. IntervalRate * 10)
        
        UseMedicine()
        yield("/wait " .. IntervalRate * 10)
        
        local i_count = GetInventoryFreeSlotCount()
        DebugLog("初始背包空格: " .. i_count)
        
        if i_count < tonumber(NumInventoryFreeSlotThreshold) and CanTurnin() then
            DebugLog("初始检查需要兑换")
            yield("/echo 前往提交收藏品并兑换")
            CollectableAppraiserScripExchange()
            yield("/wait " .. IntervalRate * 30)
        else
            DebugLog("初始检查不需要兑换")
        end

        ContinueFishing()
        
        -- 主循环
        DebugLog("进入主循环")
        while not StopMain do
            yield("/echo 开始钓鱼")
            yield("/wait " .. IntervalRate)
            Main()
            yield("/wait " .. IntervalRate)
        end
    else
        DebugLog("插件检查失败")
        yield("/echo 请安装对应插件")
    end
end)

if not success then
    DebugLog("脚本执行出错: " .. tostring(err))
    yield("/echo 脚本执行出错: " .. tostring(err))
end
