script.set_name("强制击杀优化版")

-- 动画配置表，便于管理和扩展
local ANIMATIONS = {
    ["body_drop"] = {
        name = "身体掉落",
        anim_dict = "script@proc@bountyhunting@lemoyneraider@bodydrop",
        anim_name = "PBL_DROPOFF",
        entity_name = "LINDSEY",
        z_offset = -2.00
    },
    ["robot_death"] = {
        name = "机器人死亡", 
        anim_dict = "script@specialped@pdcpr_crackpot_robot@ig@ig_1@ig_1",
        anim_name = "PBL_DEATH",
        entity_name = "ROBOT",
        z_offset = 0
    }
}

-- 存储动画场景，用于后续清理
local activeAnimScenes = {}

-- 创建播放动画的通用函数
local function playAnimationOnPlayer(playerIndex, animType)
    -- 检查玩家是否有效
    if not native.player.is_player_valid(playerIndex) then
        print("[错误] 玩家无效: " .. tostring(playerIndex))
        return
    end
    
    -- 获取动画配置
    local config = ANIMATIONS[animType]
    if not config then
        print("[错误] 未知动画类型: " .. tostring(animType))
        return
    end
    
    -- 获取玩家实体和位置
    local playerPed = native.player.get_player_ped(playerIndex)
    if not playerPed or playerPed == 0 then
        print("[错误] 无法获取玩家实体")
        return
    end
    
    local pos = native.entity.get_entity_coords(playerPed, false, true)
    if not pos then
        print("[错误] 无法获取玩家位置")
        return
    end
    
    -- 检查动画字典是否存在（尝试加载）
    if not native.streaming.has_anim_dict_loaded(config.anim_dict) then
        native.streaming.request_anim_dict(config.anim_dict)
        
        -- 等待动画字典加载
        local timeout = 5000 -- 5秒超时
        local startTime = native.system.get_system_time()
        while not native.streaming.has_anim_dict_loaded(config.anim_dict) do
            native.system.wait(0)
            if native.system.get_system_time() - startTime > timeout then
                print("[错误] 动画字典加载超时: " .. config.anim_dict)
                return
            end
        end
    end
    
    -- 创建动画场景
    local anim_scene = native.animscene._create_anim_scene(
        config.anim_dict, 
        16388, 
        config.anim_name,
        false, 
        true
    )
    
    if not anim_scene or anim_scene == 0 then
        print("[错误] 创建动画场景失败")
        return
    end
    
    -- 设置动画场景位置
    native.animscene.set_anim_scene_origin(
        anim_scene, 
        pos.x, 
        pos.y, 
        pos.z + config.z_offset, 
        0, 0, 0, 2
    )
    
    -- 设置动画场景实体
    native.animscene.set_anim_scene_entity(
        anim_scene, 
        config.entity_name, 
        playerPed, 
        0
    )
    
    -- 加载动画场景
    if not native.animscene.load_anim_scene(anim_scene) then
        print("[错误] 加载动画场景失败")
        native.animscene.delete_anim_scene(anim_scene)
        return
    end
    
    -- 存储动画场景用于后续清理
    local sceneId = #activeAnimScenes + 1
    activeAnimScenes[sceneId] = {
        scene = anim_scene,
        playerIndex = playerIndex,
        type = animType,
        startTime = native.system.get_system_time()
    }
    
    -- 开始动画
    native.animscene.start_anim_scene(anim_scene)
    
    print("[成功] 对玩家 " .. playerIndex .. " 播放动画: " .. config.name)
    
    -- 设置清理定时器（10秒后自动清理）
    native.system.set_timeout(function()
        if activeAnimScenes[sceneId] then
            native.animscene.delete_anim_scene(anim_scene)
            activeAnimScenes[sceneId] = nil
            print("[清理] 已清理动画场景: " .. sceneId)
        end
    end, 10000)
    
    return sceneId
end

-- 清理所有动画场景的函数
local function cleanupAllAnimations()
    for id, data in pairs(activeAnimScenes) do
        if data.scene and data.scene ~= 0 then
            native.animscene.delete_anim_scene(data.scene)
            print("[清理] 清理动画场景: " .. id .. " (玩家 " .. data.playerIndex .. ")")
        end
    end
    activeAnimScenes = {}
    print("[清理] 所有动画场景已清理")
end

-- 清理单个动画场景的函数
local function cleanupAnimation(sceneId)
    if activeAnimScenes[sceneId] then
        local scene = activeAnimScenes[sceneId].scene
        if scene and scene ~= 0 then
            native.animscene.delete_anim_scene(scene)
        end
        activeAnimScenes[sceneId] = nil
        print("[清理] 动画场景 " .. sceneId .. " 已清理")
        return true
    end
    return false
end

-- 获取当前活动动画信息
local function getActiveAnimations()
    local info = {}
    for id, data in pairs(activeAnimScenes) do
        local duration = math.floor((native.system.get_system_time() - data.startTime) / 1000)
        info[#info + 1] = {
            id = id,
            player = data.playerIndex,
            type = data.type,
            duration = duration .. "秒"
        }
    end
    return info
end

-- 创建主菜单
local mainMenu = menu.add_submenu("强制击杀系统")

-- 为每个玩家添加动画按钮
menu.player_root():add_submenu("强制击杀", {}, mainMenu)

-- 在主菜单中添加动画选项
for animType, config in pairs(ANIMATIONS) do
    mainMenu:add_action("播放" .. config.name, function()
        -- 注意：这里需要获取当前选择的玩家
        -- 根据EXO框架，你可能需要在回调中获取playerIndex
        -- 这里假设有获取当前选中玩家的方法
        local selectedPlayer = menu.get_selected_player()
        if selectedPlayer then
            playAnimationOnPlayer(selectedPlayer, animType)
        else
            print("[提示] 请先选择一个玩家")
        end
    end)
end

-- 添加管理选项
mainMenu:add_separator("管理选项")

mainMenu:add_action("查看活动动画", function()
    local activeAnims = getActiveAnimations()
    if #activeAnims == 0 then
        print("[信息] 当前没有活动动画")
    else
        print("[信息] 当前活动动画 (" .. #activeAnims .. " 个):")
        for _, anim in ipairs(activeAnims) do
            print("  ID: " .. anim.id .. " | 玩家: " .. anim.player .. 
                  " | 类型: " .. anim.type .. " | 时长: " .. anim.duration)
        end
    end
end)

mainMenu:add_action("清理所有动画", function()
    cleanupAllAnimations()
end)

mainMenu:add_action("重新加载动画字典", function()
    -- 清理已加载的动画字典
    for _, config in pairs(ANIMATIONS) do
        if native.streaming.has_anim_dict_loaded(config.anim_dict) then
            native.streaming.remove_anim_dict(config.anim_dict)
        end
    end
    print("[信息] 动画字典已清理，将在下次播放时重新加载")
end)

-- 脚本关闭时的清理
script.on_stop(function()
    cleanupAllAnimations()
    print("[脚本] 强制击杀脚本已停止")
end)

-- 保持脚本运行
script.keep_alive()

-- 自动清理过时动画的线程（每30秒检查一次）
script.register_looped("动画清理器", function()
    local currentTime = native.system.get_system_time()
    local toRemove = {}
    
    for id, data in pairs(activeAnimScenes) do
        -- 如果动画超过30秒，标记为需要清理
        if currentTime - data.startTime > 30000 then
            toRemove[#toRemove + 1] = id
        end
    end
    
    for _, id in ipairs(toRemove) do
        cleanupAnimation(id)
    end
    
    native.system.wait(30000) -- 每30秒检查一次
end)
