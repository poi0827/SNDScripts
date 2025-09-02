--[=====[
[[SND Metadata]]
author: Ahernika (原版作者) || poi0827 && deepseek (迁移至新版SND)
version: 1.1.5
description: >
  FisherAutoScrips：https://github.com/poi0827/SNDScripts/edit/main/FisherAutoScrips.lua 

  注意事项：

  ①如果需要自动吃药的话请安装潘多拉

  ②请开启DR自动防警惕

  ③兼容空天姬，需要在DR防警惕中写入额外文本命令 /e ktjys 佐戈秃鹰 (如果目标为佐戈秃鹰,灵岩之剑同理)

  ④请自行修改钓场点位，避免模型重叠

  ⑤兼容钓鱼紫票，请自行修改钓场
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
  FishingAetheryte:
    default: 胡萨塔伊驿镇
    description: 离钓场最近的以太之光名字
    type: string
  FishingZoneID:
    default: 1190
    description: 钓鱼区域ID
    type: string
  UnmountPositionX:
    default: -255.00215
    description: 下坐骑位置X坐标
    type: string
  UnmountPositionY:
    default: -43.69279
    description: 下坐骑位置Y坐标
    type: string
  UnmountPositionZ:
    default: 650.05786
    description: 下坐骑位置Z坐标
    type: string
  FishingPositionX:
    default: -260.50952
    description: 钓场位置X坐标
    type: string
  FishingPositionY:
    default: -44.57518
    description: 钓场位置Y坐标
    type: string
  FishingPositionZ:
    default: 654.30914
    description: 钓场位置Z坐标
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
  FishingBaitId:
    default: 43857
    description: 使用的鱼饵ID
    type: string
  DebugMode:
    default: 0
    description: DEBUG模式
    type: string

[[End Metadata]]
--]=====]

import("System.Numerics")

-- 获取配置
FishingAddon = tonumber(Config.Get("FishingAddon")) or 0
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
IntervalRate = tonumber(Config.Get("IntervalRate")) or 0.2
NumInventoryFreeSlotThreshold = tonumber(Config.Get("NumInventoryFreeSlotThreshold"))
DoExtract = Config.Get("DoExtract")
DoRepair = Config.Get("DoRepair")
MedicineToUse = Config.Get("MedicineToUse")
RepairAmount = tonumber(Config.Get("RepairAmount"))
MinItemsBeforeTurnins = tonumber(Config.Get("MinItemsBeforeTurnins")) or 1
ScripOvercapLimit = tonumber(Config.Get("ScripOvercapLimit"))
FishingBaitId = tonumber(Config.Get("FishingBaitId")) or 0
DebugMode = tonumber(Config.Get("DebugMode"))

-- 根据选择的钓鱼插件设置相应的命令
if FishingAddon == 1 then
    -- 空天姬模式
    StartFishingCommand1 = "/e ktjys 佐戈秃鹰"
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
    { 4, 1, 0, 20, 33914 },   -- 紫票用于兑换 (默认为高级强心剂) 蜻蜓为4, 6, 0, 5, 33914
}

CollectibleItemTable = { -- 用于提交的收藏品列表
    -- 橙票收藏品
    { 6, 43761, 10, 41785 }, -- 佐戈秃鹰
    -- 紫票收藏品
    { 28, 36473, 10, 33914 }, -- 灵岩之剑
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
    if FishingBaitId == nil or FishingBaitId == 0 then
        DebugLog("未设置鱼饵ID，跳过鱼饵检查")
        return true
    end
    
    -- 检查当前鱼饵
    local currentBait = Player.FishingBait
    if currentBait ~= FishingBaitId then
        DebugLog("当前鱼饵与配置不同，更换鱼饵")
        yield("/pdr bait " .. tostring(FishingBaitId))  -- 确保转换为字符串
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
    local medicine = Config.Get("MedicineToUse")
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

function RepairExtractCheck()
    DebugLog("开始检查修理和精炼")
    
    -- 确保玩家可用
    if not IsPlayerAvailable() then
        DebugLog("玩家不可用，跳过修理和精炼检查")
        return
    end
    
    -- 修理装备
    if DoRepair == "true" then
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
                -- 这里注释掉了修理过程的判断
                while Svc.Condition[39] do -- 39 = Repairing condition
                     yield("/wait " .. IntervalRate * 10)
                     if os.clock() - timeout_start > 60 then
                         DebugLog("修理过程超时")
                         break
                     end
                end
                yield("/wait " .. IntervalRate * 15)  -- 让修理过程持续30秒
                yield("/callback Repair true -1")
                
                DebugLog("修理完成")
            end,
            catch(function(err)
                DebugLog("修理过程中出错: " .. tostring(err))
            end)
        }
    else
        DebugLog("不需要修理装备")
    end
    
    -- 精炼魔晶石
    if DoExtract == "true" then
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
                    -- 这里注释掉了精炼过程的判断
                     while Svc.Condition[39] do
                         yield("/wait " .. IntervalRate * 30)
                         if os.clock() - timeout_start > 60 then
                             DebugLog("精炼过程超时")
                             break
                         end
                     end
                    
                    yield("/wait " .. IntervalRate * 15)  -- 让精炼过程持续30秒
                end
                
                yield("/wait " .. IntervalRate * 10)
                yield("/callback Materialize true -1")
                DebugLog("精炼魔晶石完成")
            end,
            catch(function(err)
                DebugLog("精炼过程中出错: " .. tostring(err))
            end)
        }
    else
        DebugLog("不需要精炼魔晶石")
    end
end



function CollectableAppraiser()
    DebugLog("开始提交收藏品")
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
            local scrip_item_number_to_buy = math.min(scrips_owned // collectible_scrip_price, 99)
            local scrips_to_use = scrip_item_number_to_buy * collectible_scrip_price
            
            DebugLog("购买数量: " .. scrip_item_number_to_buy)
            DebugLog("使用票据: " .. scrips_to_use)
            
            yield("/callback InclusionShop true 14 " .. scrip_exchange_item_to_buy_row .. " " .. scrip_item_number_to_buy)
            yield("/wait " .. IntervalRate * 5)
            
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
        repeat  
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
    
    -- 如果不在钓鱼区域，尝试传送
    if not IsInZone(FishingZoneID) then
        DebugLog("不在钓鱼区域，尝试传送")
        
        -- 等待直到可以传送
        while Svc.Condition[27] or Svc.Condition[45] or Svc.Condition[51] do
            yield("/wait " .. IntervalRate * 5)
        end
        
        DebugLog("执行传送")
        yield("/tp " .. FishingAetheryte)
        
        -- 等待传送完成
        local timeout_start = os.clock()
        repeat
            yield("/wait " .. IntervalRate * 5)
            if os.clock() - timeout_start > 30 then -- 30秒超时
                DebugLog("传送超时，重新尝试")
                yield("/tp " .. FishingAetheryte)
                timeout_start = os.clock() -- 重置超时计时器
            end
        until IsInZone(FishingZoneID) and 
              not Svc.Condition[27] and  -- 27 = Casting condition
              not Svc.Condition[45] and  -- 45 = BetweenAreas condition
              not Svc.Condition[51]      -- 51 = Occupied condition
    end
    
    DebugLog("继续钓鱼 - 步骤2: 检查距离")
    local distance = GetDistanceToPoint(UnmountPosition.x, UnmountPosition.y, UnmountPosition.z)
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
            DebugLog("导航前往下坐骑位置")
            IPC.vnavmesh.PathfindAndMoveTo(Vector3(UnmountPosition.x, UnmountPosition.y, UnmountPosition.z), true)
            
            -- 等待导航完成且距离小于1
            local timeout_start = os.clock()
            while IPC.vnavmesh.IsRunning() or GetDistanceToPoint(UnmountPosition.x, UnmountPosition.y, UnmountPosition.z) > 1 do
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
    local fishing_distance = GetDistanceToPoint(FishingPosition.x, FishingPosition.y, FishingPosition.z)
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
            IPC.vnavmesh.PathfindAndMoveTo(Vector3(FishingPosition.x, FishingPosition.y, FishingPosition.z), false)
            
            -- 等待导航完成且距离小于1
            local timeout_start = os.clock()
            while IPC.vnavmesh.IsRunning() or GetDistanceToPoint(FishingPosition.x, FishingPosition.y, FishingPosition.z) > 1 do
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
    
    DebugLog("继续钓鱼 - 步骤5: 开始钓鱼")
    yield(StartFishingCommand1)
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
    
    -- 等待直到背包空间不足或需要修理
    while i_count >= NumInventoryFreeSlotThreshold or NeedsRepair(RepairAmount) or CanExtractMateria() do
        yield("/wait " .. IntervalRate * 200)
        
        -- 检查鱼饵数量
        if GetItemCount(FishingBaitId) == 0 then
            yield("/echo 鱼饵数量为0，脚本停止")
            StopMain = true
            return
        end

        i_count = GetInventoryFreeSlotCount()
        DebugLog("检查背包空格: " .. i_count)
    end

    -- 等待完成最后的钓鱼状态
    if Svc.Condition[6] or Svc.Condition[42] then
        DebugLog("等待钓鱼状态结束")
        yield("/wait " .. IntervalRate * 24)
    end

    yield("/echo 停止钓鱼，执行其他任务")
    yield("/echo 正在检查食药, 精制魔晶石, 修理装备并提交收藏品")
    
    StopFishing()
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
    local requiredPlugins = {"Lifestream", "vnavmesh", "TeleporterPlugin", "PandorasBox"}
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

-- 添加错误处理
local success, err = pcall(function()
    if CheckPlugins() then
        DebugLog("所有插件已安装")
        
        -- 检查并切换到捕鱼人职业
        if not CheckAndSwitchToFisher() then
            return
        end
        
        -- 检查并更换鱼饵
        if not CheckAndChangeBait() then
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

