--[=====[
[[SND Metadata]]
author: Ahernika (原版作者) || poi0827 && deepseek (迁移至新版SND)
version: 1.3.2
description: >
  仓库：https://github.com/poi0827/SNDScripts/

  请自行设置DR防警惕，该脚本没有防警惕功能

  注意事项：

  ①如果需要自动吃药的话请安装潘多拉

  ②请开启DR自动防警惕

  ③兼容空天姬，需要在DR防警惕中写入额外文本命令 /e ktjys 目标鱼名称

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
    description: 以太之光名字
    type: string
  FishingZoneID:
    default: 1190
    description: 区域ID
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
    description: 钓鱼位置X坐标
    type: string
  FishingPositionY:
    default: -44.57518
    description: 钓鱼位置Y坐标
    type: string
  FishingPositionZ:
    default: 654.30914
    description: 钓鱼位置Z坐标
    type: string
  TargetFish:
    default: 佐戈秃鹰
    description: 目标鱼名称
    type: string
  FishingBaitId:
    default: 43857
    description: 使用的鱼饵ID
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

-- 票据兑换设置
ExchangeItemTable = {
    { 4, 8, 1, 5, 41785 }, -- 橙票用于兑换 (默认为犎牛角笛的交换票据)
    { 4, 1, 0, 20, 33914 },   -- 紫票用于兑换 (默认为高级强心剂)
    --4 6 0 5    33914 蜻蜓 
    --4 3 3 1    33914 残暴水蛭
    --4 1 0 20   33914 高级强心剂
    --4 8 1 5    41875 红蛆
    --4 8 6 1000 41875 牛票
    --格式为{ 主分类 , 副分类 , 第n个道具, 单个价格, 票据id（橙票为41875，紫票为33914） } 
}

CollectibleItemTable = { -- 用于提交的收藏品列表
    -- 橙票收藏品
    { 6, 43761, 10, 41785 }, -- 佐戈秃鹰
    -- 紫票收藏品
    { 28, 36473, 10, 33914 }, -- 灵岩之剑
    { 87, 12828, 10, 33914 }, -- 落雷鳗
    --格式为{ 收藏品在提交界面所在行数 , 物品id , 提交职业（捕鱼人为10）, 票据id（橙票为41875，紫票为33914） }
}

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
FishingBaitId = tonumber(Config.Get("FishingBaitId")) or 0

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
    -- 空天姬模式
    StartFishingCommand1 = function()
        return "/e ktjys " .. TargetFish
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

-- 票据使用统计
TotalOrangeScripsUsed = 0
TotalPurpleScripsUsed = 0

MsgDelay = 10
TimeoutThreshold = 10
StopMain = false

-- 定义状态机的状态
local States = {
    INIT = "INIT",
    CHECK_PLUGINS = "CHECK_PLUGINS",
    CHECK_JOB = "CHECK_JOB",
    USE_MEDICINE = "USE_MEDICINE",
    CHECK_INVENTORY = "CHECK_INVENTORY",
    TRAVEL_TO_FISHING = "TRAVEL_TO_FISHING",
    FISHING = "FISHING",
    STOP_FISHING = "STOP_FISHING",
    REPAIR_EXTRACT = "REPAIR_EXTRACT",
    TRAVEL_TO_EXCHANGE = "TRAVEL_TO_EXCHANGE",
    EXCHANGE = "EXCHANGE",
    ERROR = "ERROR",
    COMPLETED = "COMPLETED"
}

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
        return false
    end
    return Player.CanMount
end

function HasFlightUnlocked()
    if not IsPlayerAvailable() or Player.CanFly == nil then
        return false
    end
    return Player.CanFly
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
    if not DoRepair then
        return false
    end
    
    local needsRepair = Inventory.GetItemsInNeedOfRepairs(threshold)
    if needsRepair.Count > 2 then
        DebugLog("需要修理的装备数量: " .. needsRepair.Count)
        return true
    else
        return false
    end
end

function CanExtractMateria()
    if not DoExtract then
        return false
    end
    
    local spiritbondedItems = Inventory.GetSpiritbondedItems()
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
            while Svc.Condition[39] do
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

-- 检查并更换鱼饵
function CheckAndChangeBait()
    if FishingBaitId == nil or FishingBaitId == 0 then
        DebugLog("未设置鱼饵ID，跳过鱼饵检查")
        return true
    end
    
    local currentBait = Player.FishingBait
    if currentBait ~= FishingBaitId then
        DebugLog("当前鱼饵与配置不同，更换鱼饵")
        yield("/pdr bait " .. tostring(FishingBaitId))
        yield("/wait " .. IntervalRate * 3)
        
        if Player.FishingBait ~= FishingBaitId then
            yield("/echo 鱼饵更换失败，请检查鱼饵ID是否正确")
            return false
        end
    end
    
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
    if currentJobId == 18 then
        DebugLog("当前已是捕鱼人职业")
        return true
    end
    
    DebugLog("当前不是捕鱼人职业，尝试切换到捕鱼人装备")
    
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

-- 使用药品
function UseMedicine()
    DebugLog("开始使用药品")
    
    local medicine = MedicineToUse
    DebugLog("从配置获取药品名称: " .. tostring(medicine))
    
    if not medicine or medicine == "" then
        DebugLog("配置中未设置药品名称，跳过使用药品")
        return
    end
    
    if HasStatus(49) then
        DebugLog("已检测到强化药状态，跳过使用")
        return
    end
    
    local medicineCommand = '/puseitem "' .. medicine .. '"'
    DebugLog("执行药品命令: " .. medicineCommand)
    yield(medicineCommand)
    
    local timeout_start = os.clock()
    local statusApplied = false
    DebugLog("等待药品效果生效...")
    repeat
        yield("/wait 1")
        if HasStatus(49) then
            statusApplied = true
            break
        end
    until os.clock() - timeout_start > 15

    if statusApplied then
        DebugLog("药品效果已成功应用")
    else
        DebugLog("警告：药品命令已执行，但未检测到强化药状态")
    end
end

function Dismount()
    DebugLog("开始下坐骑")
    
    local player = Svc.ClientState.LocalPlayer
    if not player or not player.Position then
        DebugLog("玩家不可用，无法下坐骑")
        return
    end
    
    if Svc.Condition[77] then
        yield("/gaction 随机坐骑")
        
        local muuv = 1
        local muuvX, muuvY, muuvZ
        if player and player.Position then
            muuvX = player.Position.X
            muuvY = player.Position.Y
            muuvZ = player.Position.Z
        else
            DebugLog("玩家位置不可用，跳过移动检测")
            muuv = 0
        end
        
        while muuv == 1 do
            yield("/wait " .. IntervalRate * 5)
            
            if not player or not player.Position then
                DebugLog("玩家位置不可用，停止移动检测")
                break
            end
            
            if muuvX == player.Position.X and muuvY == player.Position.Y and muuvZ == player.Position.Z then
                muuv = 0
            end
            
            muuvX = player.Position.X
            muuvY = player.Position.Y
            muuvZ = player.Position.Z
        end

        if Svc.Condition[77] then
            local random_j = 0
            
            ::DISMOUNT_START::
            
            if not player or not player.Position then
                DebugLog("玩家位置不可用，无法生成随机位置")
                return
            end
            
            local land_x = player.Position.X + math.random(0, random_j)
            local land_y = player.Position.Y + math.random(0, random_j)
            local land_z = player.Position.Z + math.random(0, random_j)
            
            IPC.vnavmesh.PathfindAndMoveTo(Vector3(land_x, land_y, land_z), false)

            local timeout_start = os.clock()
            
            repeat
                yield("/wait " .. IntervalRate)
                
                if os.clock() - timeout_start > TimeoutThreshold then
                    DebugLog("未能导航到可下坐骑的地形，尝试前往其他位置")
                    random_j = random_j + 1
                    goto DISMOUNT_START
                end
            until not IPC.vnavmesh.IsRunning()

            yield('/gaction 随机坐骑')

            timeout_start = os.clock()
            
            repeat
                yield("/wait " .. IntervalRate)
                
                if os.clock() - timeout_start > TimeoutThreshold then
                    DebugLog("下坐骑失败，尝试前往其他位置")
                    random_j = random_j + 1
                    goto DISMOUNT_START
                end
            until not Svc.Condition[77]
        end
    end

    if Svc.Condition[4] then
        yield("/wait " .. IntervalRate * 10)
        yield('/gaction 随机坐骑')
        
        repeat
            yield("/wait " .. IntervalRate)
        until not Svc.Condition[4]
    end
    
    DebugLog("下坐骑完成")
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

        local scrips_owned = GetItemCount(scrip_type)
        DebugLog("当前票据数量: " .. scrips_owned)
        
        if scrips_owned >= collectible_scrip_price then
            local total_items_to_buy = math.floor(scrips_owned / collectible_scrip_price)
            local scrips_used = 0

            while total_items_to_buy > 0 do
                local items_to_buy = math.min(total_items_to_buy, 99)
                local scrips_to_use = items_to_buy * collectible_scrip_price
                scrips_used = scrips_used + scrips_to_use
                
                DebugLog("购买数量: " .. items_to_buy)
                DebugLog("使用票据: " .. scrips_to_use)
                yield("/callback InclusionShop true 14 " .. scrip_exchange_item_to_buy_row .. " " .. items_to_buy)
                yield("/wait " .. IntervalRate * 5)

                if Addons.GetAddon("ShopExchangeItemDialog").Ready then
                    yield("/callback ShopExchangeItemDialog true 0")
                    yield("/wait " .. IntervalRate)
                    
                    if scrip_type == 41785 then
                        session_orange_used = session_orange_used + scrips_to_use
                        TotalOrangeScripsUsed = TotalOrangeScripsUsed + scrips_to_use
                    elseif scrip_type == 33914 then
                        session_purple_used = session_purple_used + scrips_to_use
                        TotalPurpleScripsUsed = TotalPurpleScripsUsed + scrips_to_use
                    end
                end

                total_items_to_buy = total_items_to_buy - items_to_buy
            end
        else
            DebugLog("票据不足，无法兑换")
        end
    end
    
    yield("/wait " .. IntervalRate)
    DebugLog("关闭兑换界面")
    yield("/callback InclusionShop true -1")

    if session_orange_used > 0 or session_purple_used > 0 then
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
    yield("/tp 游末邦")
    yield("/wait " .. IntervalRate * 15)
    
    local timeout_start = os.clock()
    repeat
        yield("/wait " .. IntervalRate)
        if os.clock() - timeout_start > 60 then
            DebugLog("传送超时，重新传送")
            yield("/tp 游末邦")
            timeout_start = os.clock()
        end
    until (GetZoneID() == 820) and 
          not Svc.Condition[27] and
          not Svc.Condition[45] and
          not Svc.Condition[51]
    
    yield("/wait " .. IntervalRate * 20)
    
    DebugLog("导航至收藏品交易员位置")
    IPC.vnavmesh.PathfindAndMoveTo(Vector3(16.979, 82.050, -19.189), false)
    
    local timeout_start = os.clock()
    while IPC.vnavmesh.IsRunning() do
        yield("/wait " .. IntervalRate)
        if os.clock() - timeout_start > 30 then
            DebugLog("导航超时，停止导航")
            IPC.vnavmesh.Stop()
            break
        end
    end
    
    yield("/wait " .. IntervalRate * 5)
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
        until Svc.Condition[42]
        
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
    
    if not IsInZone(FishingZoneID) then
        DebugLog("不在钓鱼区域，尝试传送")
        
        while Svc.Condition[27] or Svc.Condition[45] or Svc.Condition[51] do
            yield("/wait " .. IntervalRate * 5)
        end
        
        DebugLog("执行传送")
        yield("/tp " .. FishingAetheryte)
        
        local timeout_start = os.clock()
        repeat
            yield("/wait " .. IntervalRate * 5)
            if os.clock() - timeout_start > 30 then
                DebugLog("传送超时，重新尝试")
                yield("/tp " .. FishingAetheryte)
                timeout_start = os.clock()
            end
        until IsInZone(FishingZoneID) and 
              not Svc.Condition[27] and
              not Svc.Condition[45] and
              not Svc.Condition[51]
    end
    
    DebugLog("继续钓鱼 - 步骤2: 检查距离")
    local distance = GetDistanceToPoint(UnmountPosition.x, UnmountPosition.y, UnmountPosition.z)
    DebugLog("距离下坐骑位置: " .. distance)
    
    if distance > 20 then
        DebugLog("距离下坐骑位置较远，准备导航")
        
        local timeout_start = os.clock()
        while not IPC.vnavmesh.IsReady() do
            yield("/wait " .. IntervalRate)
            if os.clock() - timeout_start > 60 then
                DebugLog("vnavmesh未就绪，跳过导航")
                break
            end
        end
        
        if IPC.vnavmesh.IsReady() then
            if not Svc.Condition[4] and not Svc.Condition[77] then
                DebugLog("上坐骑")
                yield('/gaction 随机坐骑')
                yield("/wait " .. IntervalRate * 3)
            end
            
            while not IPC.vnavmesh.IsRunning() do
                DebugLog("路径计算器未运行，初始化导航")
                IPC.vnavmesh.PathfindAndMoveTo(Vector3(UnmountPosition.x, UnmountPosition.y, UnmountPosition.z), true)
                
                if os.clock() - timeout_start > 30 then
                    DebugLog("错误: 导航初始化超时30秒")
                    break
                end
                yield("/wait 1")
            end
            DebugLog("路径计算器已启动")

            yield("/wait 1")
            local timeout_start = os.clock()
            while IPC.vnavmesh.IsRunning() or GetDistanceToPoint(UnmountPosition.x, UnmountPosition.y, UnmountPosition.z) > 1 do
                yield("/wait " .. IntervalRate)
                if os.clock() - timeout_start > 60 then
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
    
    yield("/wait " .. IntervalRate * 2)
    
    DebugLog("继续钓鱼 - 步骤4: 导航至钓鱼位置")
    local fishing_distance = GetDistanceToPoint(FishingPosition.x, FishingPosition.y, FishingPosition.z)
    if fishing_distance > 2 then
        DebugLog("距离钓鱼位置: " .. fishing_distance)
        
        local timeout_start = os.clock()
        while not IPC.vnavmesh.IsReady() do
            yield("/wait " .. IntervalRate)
            if os.clock() - timeout_start > 60 then
                DebugLog("vnavmesh未就绪，跳过导航")
                break
            end
        end
        
        if IPC.vnavmesh.IsReady() then
            IPC.vnavmesh.PathfindAndMoveTo(Vector3(FishingPosition.x, FishingPosition.y, FishingPosition.z), false)
            
            local timeout_start = os.clock()
            while IPC.vnavmesh.IsRunning() or GetDistanceToPoint(FishingPosition.x, FishingPosition.y, FishingPosition.z) > 1 do
                yield("/wait " .. IntervalRate)
                if os.clock() - timeout_start > 30 then
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

-- 插件检查函数
function CheckPlugins()
    DebugLog("开始检查插件")
    local requiredPlugins = {"Lifestream", "vnavmesh", "TeleporterPlugin", "DailyRoutines"}
    
    if MedicineToUse ~= nil and MedicineToUse ~= "" then
        table.insert(requiredPlugins, "PandorasBox")
    end
    
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
            allPluginsAvailable = false
        end
    end
    
    DebugLog("插件检查完成: " .. tostring(allPluginsAvailable))
    return allPluginsAvailable
end

-- 状态机类
FisherStateMachine = {}
FisherStateMachine.__index = FisherStateMachine

function FisherStateMachine.new()
    local self = setmetatable({}, FisherStateMachine)
    self:Reset()
    return self
end

function FisherStateMachine:Reset()
    self.state = States.INIT
    self.previousState = nil
    self.stateStartTime = os.clock()
    self.stateTimeout = 300
    self.attempts = 0
    self.maxAttempts = 3
    self.stopRequested = false
    self.errorMessage = ""
    self.lastCheckTime = 0
    self.checkInterval = 10
end

function FisherStateMachine:TransitionTo(newState)
    DebugLog("状态转换: " .. tostring(self.state) .. " -> " .. tostring(newState))
    self.previousState = self.state
    self.state = newState
    self.stateStartTime = os.clock()
    self.attempts = 0
end

function FisherStateMachine:HandleError(message)
    self.errorMessage = message
    DebugLog("错误: " .. message)
    self:TransitionTo(States.ERROR)
end

function FisherStateMachine:ShouldTimeout()
    return os.clock() - self.stateStartTime > self.stateTimeout
end

function FisherStateMachine:Execute()
    if self.stopRequested then
        DebugLog("状态机已停止")
        return false
    end

    if self:ShouldTimeout() then
        self:HandleError("状态 " .. self.state .. " 超时")
        return true
    end

    local continue = true
    local success, err = pcall(function()
        if self.state == States.INIT then
            continue = self:State_INIT()
        elseif self.state == States.CHECK_PLUGINS then
            continue = self:State_CHECK_PLUGINS()
        elseif self.state == States.CHECK_JOB then
            continue = self:State_CHECK_JOB()
        elseif self.state == States.USE_MEDICINE then
            continue = self:State_USE_MEDICINE()
        elseif self.state == States.CHECK_INVENTORY then
            continue = self:State_CHECK_INVENTORY()
        elseif self.state == States.TRAVEL_TO_FISHING then
            continue = self:State_TRAVEL_TO_FISHING()
        elseif self.state == States.FISHING then
            continue = self:State_FISHING()
        elseif self.state == States.STOP_FISHING then
            continue = self:State_STOP_FISHING()
        elseif self.state == States.REPAIR_EXTRACT then
            continue = self:State_REPAIR_EXTRACT()
        elseif self.state == States.TRAVEL_TO_EXCHANGE then
            continue = self:State_TRAVEL_TO_EXCHANGE()
        elseif self.state == States.EXCHANGE then
            continue = self:State_EXCHANGE()
        elseif self.state == States.ERROR then
            continue = self:State_ERROR()
        elseif self.state == States.COMPLETED then
            continue = self:State_COMPLETED()
        end
    end)

    if not success then
        self:HandleError("状态 " .. self.state .. " 执行错误: " .. tostring(err))
    end

    return continue
end

-- 各个状态的处理函数
function FisherStateMachine:State_INIT()
    DebugLog("初始化状态")
    self:TransitionTo(States.CHECK_PLUGINS)
    return true
end

function FisherStateMachine:State_CHECK_PLUGINS()
    DebugLog("检查插件状态")
    if CheckPlugins() then
        self:TransitionTo(States.CHECK_JOB)
    else
        self:HandleError("插件检查失败，请安装所需插件")
    end
    return true
end

function FisherStateMachine:State_CHECK_JOB()
    DebugLog("检查职业状态")
    if CheckAndSwitchToFisher() then
        Dismount()
        yield("/wait " .. IntervalRate * 10)
        self:TransitionTo(States.USE_MEDICINE)
    else
        self:HandleError("切换到捕鱼人职业失败")
    end
    return true
end

function FisherStateMachine:State_USE_MEDICINE()
    DebugLog("使用药品状态")
    UseMedicine()
    yield("/wait " .. IntervalRate * 10)
    self:TransitionTo(States.CHECK_INVENTORY)
    return true
end

function FisherStateMachine:State_CHECK_INVENTORY()
    DebugLog("检查背包状态")
    local i_count = GetInventoryFreeSlotCount()
    DebugLog("初始背包空格: " .. i_count)
    
    if i_count < tonumber(NumInventoryFreeSlotThreshold) and CanTurnin() then
        DebugLog("需要兑换，前往兑换状态")
        self:TransitionTo(States.TRAVEL_TO_EXCHANGE)
    else
        DebugLog("不需要兑换，前往钓鱼状态")
        self:TransitionTo(States.TRAVEL_TO_FISHING)
    end
    return true
end

function FisherStateMachine:State_TRAVEL_TO_FISHING()
    DebugLog("前往钓鱼点状态")
    ContinueFishing()
    self:TransitionTo(States.FISHING)
    return true
end

function FisherStateMachine:State_FISHING()
    DebugLog("钓鱼状态")
    
    local currentTime = os.clock()
    if currentTime - self.lastCheckTime >= self.checkInterval then
        self.lastCheckTime = currentTime
                
        if NeedsRepair(RepairAmount) or CanExtractMateria() then
            DebugLog("需要修理或精炼，停止钓鱼")
            self:TransitionTo(States.STOP_FISHING)
            return true
        end
        
        local i_count = GetInventoryFreeSlotCount()
        DebugLog("当前背包空格: " .. i_count)
        
        if i_count < NumInventoryFreeSlotThreshold then
            DebugLog("背包已满，停止钓鱼")
            self:TransitionTo(States.STOP_FISHING)
            return true
        end
        
        if not IsInZone(FishingZoneID) then
            DebugLog("不在钓鱼区域，停止钓鱼")
            self:TransitionTo(States.STOP_FISHING)
            return true
        end
    end
    
    yield("/wait " .. IntervalRate)
    return true
end

function FisherStateMachine:State_STOP_FISHING()
    DebugLog("停止钓鱼状态")
    StopFishing()
    yield("/wait " .. IntervalRate * 10)
    
    if NeedsRepair(RepairAmount) or CanExtractMateria() then
        self:TransitionTo(States.REPAIR_EXTRACT)
    else
        self:TransitionTo(States.CHECK_INVENTORY)
    end
    return true
end

function FisherStateMachine:State_REPAIR_EXTRACT()
    DebugLog("修理和精炼状态")
    
    if NeedsRepair(RepairAmount) then
        Repair()
        yield("/wait " .. IntervalRate * 10)
    end

    if CanExtractMateria() then
        ExtractMateria()
        yield("/wait " .. IntervalRate * 10)
    end
    
    self:TransitionTo(States.CHECK_INVENTORY)
    return true
end

function FisherStateMachine:State_TRAVEL_TO_EXCHANGE()
    DebugLog("前往兑换点状态")
    PathToScrip()
    yield("/wait " .. IntervalRate * 20)
    self:TransitionTo(States.EXCHANGE)
    return true
end

function FisherStateMachine:State_EXCHANGE()
    DebugLog("兑换状态")
    
    while CanTurnin() do
        CollectableAppraiser()
        yield("/wait " .. IntervalRate * 20)
        ScripExchange()
        yield("/wait " .. IntervalRate * 20)
    end
    
    yield("/wait " .. IntervalRate * 10)
    ScripExchange()
    yield("/wait " .. IntervalRate * 20)
    
    self:TransitionTo(States.TRAVEL_TO_FISHING)
    return true
end

function FisherStateMachine:State_ERROR()
    DebugLog("错误状态: " .. self.errorMessage)
    yield("/echo 错误: " .. self.errorMessage)
    
    local currentZoneId = GetZoneID()
    DebugLog("当前地图ID: " .. tostring(currentZoneId))
    
    if currentZoneId == 820 then
        DebugLog("当前在游末邦，重新初始化脚本")
        yield("/echo 在游末邦检测到错误，重新初始化脚本")
        self:TransitionTo(States.INIT)
        return true
    end
    
    if currentZoneId == FishingZoneID then
        DebugLog("当前在钓鱼地图，跳转到停止钓鱼状态")
        yield("/echo 在钓鱼地图检测到错误，停止钓鱼")
        self:TransitionTo(States.STOP_FISHING)
        return true
    end
    
    self.attempts = self.attempts + 1
    if self.attempts < self.maxAttempts then
        yield("/wait " .. IntervalRate * 10)
        yield("/echo 尝试恢复，第 " .. self.attempts .. " 次尝试")
        self:TransitionTo(self.previousState or States.INIT)
    else
        yield("/echo 错误恢复尝试次数过多，停止脚本")
        self.stopRequested = true
    end
    return true
end

function FisherStateMachine:State_COMPLETED()
    DebugLog("完成状态")
    yield("/echo 脚本完成")
    self.stopRequested = true
    return false
end

-- 创建状态机实例
local stateMachine = FisherStateMachine.new()

-- 主循环
DebugLog("脚本启动 - 状态机模式") 
while stateMachine:Execute() do
    yield("/wait " .. IntervalRate)
end

yield("/echo 脚本结束")

