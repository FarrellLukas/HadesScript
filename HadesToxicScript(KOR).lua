--[[
    BasedGTAOVerion = 1.64
]]

util.require_natives(1663599433)

local function NOTIFY(msg)
    util.toast(SCRIPT_NAME .. "\n" .. "- " .. msg)
end

NOTIFY("어서오세요 " .. SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME())
util.toast("로딩 중 기다려주세요...(1-2초)")
local response = false
local HadesVersion = 0.32
async_http.init("shorturl.at/enwy4", function(output)
    currentVer = tonumber(output)
    response = true
    if HadesVersion ~= currentVer then
        util.toast("업데이트를 받을 수 있습니다. 업데이트 진행후 다시 시작합니다.")
        menu.action(menu.my_root(), "최신 버전 업데이트", {}, "최신 버전으로 업데이트", function()
            async_http.init('shorturl.at/enwy4',function(a)
                local err = select(2,load(a))
                if err then
                    util.toast("Github 수동 업데이트 진행 오류가 발생했습니다.")
                return end
                local f = io.open(filesystem.scripts_dir()..SCRIPT_RELPATH, "wb")
                f:write(a)
                f:close()
                util.toast("스크립트 업데이트 완료 되었습니다 스크립트가 다시 시작 됩니다.")
                util.restart_script()
            end)
            async_http.dispatch()
        end)
    end
end, function() response = true end)
async_http.dispatch()
repeat 
    util.yield()
until response

--[[
-------------------------------------scriptMenu-------------------------------------
---------------------------------------------------------------------------------
]]
local self = menu.list(menu.my_root(), "셀프", {}, "")
local vehicle = menu.list(menu.my_root(), "차량", {}, "")
local online = menu.list(menu.my_root(), "온라인", {}, "")
local detections = menu.list(online, "모더 감지", {}, "모더 감지 합니다.")
local player = menu.list(menu.my_root(), "플레이어", {}, "")
local world = menu.list(menu.my_root(), "월드", {}, "")
local game = menu.list(menu.my_root(), "게임", {}, "")
local misc = menu.list(menu.my_root(), "크레딧", {}, "나를 도와주는 사람들")


--[[
    self = "셀프"
]]
local menus = {}
local function player_list(pid)
    if NETWORK.NETWORK_IS_SESSION_ACTIVE()then 
        menus[pid] = menu.list(player, players.get_name(pid), {}, "", function()
            menu.trigger_commands("hadesScripts " .. players.get_name(pid))
        end)
    end
end

local function handle_player_list(pid) -- thanks to dangerman and aaron for showing me how to delete players properly
    local ref = menus[pid]
    if not players.exists(pid) then
        if ref then
            menu.delete(ref)
            menus[pid] = nil
        end
    end
end

players.on_join(player_list)
players.on_leave(handle_player_list)
--- self END



--[[
    vehicle = "차량"
]]
player_cur_car = 0
initial_d_mode = false
initial_d_score = false
function on_user_change_vehicle(vehicle)
    if vehicle ~= 0 then
        if initial_d_mode then 
            set_vehicle_into_drift_mode(vehicle)
        end

        local deez_nuts = {}
        local num_seats = VEHICLE.GET_VEHICLE_MODEL_NUMBER_OF_SEATS(ENTITY.GET_ENTITY_MODEL(vehicle))
        for i=1, num_seats do
            if num_seats >= 2 then
                deez_nuts[#deez_nuts + 1] = tostring(i - 2)
            else
                deez_nuts[#deez_nuts + 1] = tostring(i)
            end
        end

        if true then 
            native_invoker.begin_call()
            native_invoker.push_arg_int(vehicle)
            native_invoker.end_call("76D26A22750E849E")
        end
    end
end

function initial_d_score_thread()
    util.create_thread(function()
        local drift_score = 0
        local is_drifting = false
        while true do
            if not initial_d_mode or not initial_d_score then 
                util.stop_thread()
            end
            if player_cur_car ~= 0 and PED.IS_PED_IN_ANY_VEHICLE(players.user_ped(), true) then 
                if math.abs(ENTITY.GET_ENTITY_SPEED_VECTOR(player_cur_car, true).x) > 2 then 
                    is_drifting = true
                    drift_score = drift_score + 1
                    local c = ENTITY.GET_ENTITY_COORDS(player_cur_car)
                    c.z = c.z + 0.3
                    local score_pos = world_to_screen_coords(c.x, c.y, c.z)
                    directx.draw_text(score_pos.x, score_pos.y, "DRIFT SCORE: " .. tostring(drift_score), 5, 1, {r=1, g= 0.5, b = 0.4, a = 100}, true)
                else
                    if is_drifting then
                        is_drifting = false
                        NOTIFY("TOTAL DRIFT SCORE: " .. drift_score)
                    end
                    drift_score = 0
                end
            end
            util.yield()
        end
    end)
end

-- entity ownership forcing
local function request_control_of_entity(ent)
    if not NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(ent) and util.is_session_started() then
        local netid = NETWORK.NETWORK_GET_NETWORK_ID_FROM_ENTITY(ent)
        NETWORK.SET_NETWORK_ID_CAN_MIGRATE(netid, true)
        local st_time = os.time()
        while not NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(ent) do
            -- intentionally silently fail, otherwise we are gonna spam the everloving shit out of the user
            if os.time() - st_time >= 5 then
                ls_log("Failed to request entity control in 5 seconds (entity " .. ent .. ")")
                break
            end
            NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(ent)
            util.yield()
        end
    end
end

menu.action(vehicle, "차량 방향 전환", {}, "", function(on)
    local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(PLAYER.PLAYER_ID()), true)
    if car ~= 0 then
        request_control_of_entity(car)
        local rot = ENTITY.GET_ENTITY_ROTATION(car, 0)
        local vel = ENTITY.GET_ENTITY_VELOCITY(car)
        ENTITY.SET_ENTITY_ROTATION(car, rot['x'], rot['y'], rot['z']+180, 0, true)
        ENTITY.SET_ENTITY_VELOCITY(car, -vel['x'], -vel['y'], vel['z'])
    end
end)

menu.toggle_loop(vehicle, "차량 수평 이동", {}, "오른쪽 및 왼쪽 화살표 키를 사용하여 차량을 수평 방향으로 움직일 수 있습니다.", function()
    local ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(PLAYER.PLAYER_ID())
    if PED.IS_PED_IN_ANY_VEHICLE(ped, false) then
        if player_cur_car ~= 0 then
            local rot = ENTITY.GET_ENTITY_ROTATION(player_cur_car, 0)
            if PAD.IS_CONTROL_PRESSED(175, 175) then
                ENTITY.APPLY_FORCE_TO_ENTITY(player_cur_car, 1, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0, true, true, true, false, true)
                ENTITY.SET_ENTITY_ROTATION(player_cur_car, rot['x'], rot['y'], rot['z'], 0, true)
            elseif 
                PAD.IS_CONTROL_PRESSED(174, 174) then
                ENTITY.APPLY_FORCE_TO_ENTITY(player_cur_car, 1, -1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0, true, true, true, false, true)
                ENTITY.SET_ENTITY_ROTATION(player_cur_car, rot['x'], rot['y'], rot['z'], 0, true)
            end
        end
    end
end)

local function getCurrentVehicle() 
	local player_id = PLAYER.PLAYER_ID()
	local player_ped = PLAYER.GET_PLAYER_PED(player_id)
    local player_vehicle = 0
    if (PED.IS_PED_IN_ANY_VEHICLE(player_ped)) then
        veh = PED.GET_VEHICLE_PED_IS_USING(player_ped)
        if (NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(veh)) then
            player_vehicle = veh
        end 
    end
    return player_vehicle
end

local function getHeadingOfTravel(veh) 
    local velocity = ENTITY.GET_ENTITY_VELOCITY(veh)
    local x = velocity.x
    local y = velocity.y
    local at2 = math.atan(y, x)
    return math.fmod(270.0 + math.deg(at2), 360.0)
end

local function getCurGear()
    return memory.read_byte(entities.get_user_vehicle_as_pointer() +memory.read_int(CurrentGearOffset))
end

local function setCurGear(gear)
    memory.write_byte(entities.get_user_vehicle_as_pointer() +memory.read_int(CurrentGearOffset), gear)
end

local function setNextGear(gear)
    memory.write_byte(entities.get_user_vehicle_as_pointer() +memory.read_int(NextGearOffset), gear)
end

local function wrap360(val) 
    --    this may be the same as:
    --      return math.fmod(val + 360, 360)
    --    but wierd things happen
    while (val < 0.0) do
        val = val + 360.0
    end
    while (val > 360.0) do
        val = val - 360.0
    end
    return val
end

menu.toggle_loop(vehicle, "방향 지시등", {}, "", function()
    if(PED.IS_PED_IN_ANY_VEHICLE(players.user_ped(), false)) then
        local vehicle = PED.GET_VEHICLE_PED_IS_IN(players.user_ped(), false)

        local left = PAD.IS_CONTROL_PRESSED(34, 34)
        local right = PAD.IS_CONTROL_PRESSED(35, 35)
        local rear = PAD.IS_CONTROL_PRESSED(130, 130)

        if left and not right and not rear then
            VEHICLE.SET_VEHICLE_INDICATOR_LIGHTS(vehicle, 1, true)
        elseif right and not left and not rear then
            VEHICLE.SET_VEHICLE_INDICATOR_LIGHTS(vehicle, 0, true)
        elseif rear and not left and not right then
            VEHICLE.SET_VEHICLE_INDICATOR_LIGHTS(vehicle, 1, true)
            VEHICLE.SET_VEHICLE_INDICATOR_LIGHTS(vehicle, 0, true)
        else
            VEHICLE.SET_VEHICLE_INDICATOR_LIGHTS(vehicle, 0, false)
            VEHICLE.SET_VEHICLE_INDICATOR_LIGHTS(vehicle, 1, false)
        end
    end
end)

menu.toggle_loop(vehicle, "차량 무적", {}, "대부분의 메뉴에서는 감지되지 않을 것입니다.", function()
    ENTITY.SET_ENTITY_PROOFS(entities.get_user_vehicle_as_handle(), true, true, true, true, true, 0, 0, true)
    end, function() ENTITY.SET_ENTITY_PROOFS(PED.GET_VEHICLE_PED_IS_IN(players.user(), false), false, false, false, false, false, 0, 0, false)
end)
menu.toggle_loop(vehicle, "차량 무적 해제", {}, "대부분의 메뉴에서는 감지되지 않을 것입니다.", function()
    ENTITY.SET_ENTITY_PROOFS(entities.get_user_vehicle_as_handle(), false, false, false, false, false, 0, 0, false)
    end, function() ENTITY.SET_ENTITY_PROOFS(PED.GET_VEHICLE_PED_IS_IN(players.user(), false), false, false, false, false, false, 0, 0, false)
end)

driftmodee = menu.list(vehicle, "드리프트 모드", {}, "네이티브 기반 드리프트 모드")

local gs_driftMinSpeed =10.0
local gs_driftMaxAngle = 50.0
-- local ControlVehicleAccelerate = 71
local ControlVehicleBrake = 72
local ControlVehicleDuck = 73
local ControlVehicleSelectNextWeapon = 99
-- local ControlVehicleMoveUpOnly = 61
local INPUT_FRONTEND_LS = 209
local DriftActivateKeyboard = INPUT_FRONTEND_LS

CurrentGearOffset = memory.scan("A8 02 0F 84 ? ? ? ? 0F B7 86")+11
NextGearOffset = memory.scan("A8 02 0F 84 ? ? ? ? 0F B7 86")+18

textDrawCol = {
    r = 255,
    g = 255,
    b = 255,
    a = 255
}

local function driftmod_ontick() 
    local player = players.user()
    local veh = getCurrentVehicle()   

    local inVehicle   = veh ~= 0
    local isDriving   = true

    local mps = ENTITY.GET_ENTITY_SPEED(veh)
    local mph       = mps * 2.23694
    local kmh       = mps * 3.6

    if inVehicle and isDriving and not isDrifting and not isDriftFinished then
        isDriftFinished = true
    end

    if not inVehicle or not isDriving then
        return
    end

    local driftKeyPressed = PAD.IS_CONTROL_PRESSED(2, ControlVehicleDuck) or PAD.IS_DISABLED_CONTROL_PRESSED(2, ControlVehicleDuck) or PAD.IS_CONTROL_PRESSED(0, DriftActivateKeyboard) or PAD.IS_DISABLED_CONTROL_PRESSED(0, DriftActivateKeyboard)

    if (driftKeyPressed and getCurGear(veh) > 2) then
        setCurGear(2)
        setNextGear(2)
    end
    if driftKeyPressed then
         
        if (PAD.GET_CONTROL_NORMAL(2, ControlVehicleBrake) > 0.1) then
            PAD.SET_CONTROL_VALUE_NEXT_FRAME(0, ControlVehicleBrake, 0)
            local neg = -0.3

            if (PAD.IS_CONTROL_PRESSED(2, ControlVehicleSelectNextWeapon)) then
                neg = 10
            end

            slamDatBitch(veh, neg * 1 * PAD.GET_CONTROL_NORMAL(2, ControlVehicleBrake))
        end 

        local angleOfTravel  = getHeadingOfTravel(veh)
        local angleOfHeading = ENTITY.GET_ENTITY_HEADING_FROM_EULERS(veh)
        
        local driftAngle = angleOfHeading - angleOfTravel

        if driftAngle and lastDriftAngle then
            local diff = driftAngle - lastDriftAngle

            if diff > 180.0 then
                driftAngle = driftAngle - 360.0
            end
            if diff < 180.0 then
                driftAngle = driftAngle - 360.0
            end
        end

        driftAngle     = wrap360(driftAngle)
        lastDriftAngle = driftAngle

        local zeroBasedDriftAngle = 360 - driftAngle
        if zeroBasedDriftAngle > 180 then
            zeroBasedDriftAngle = 0 - (360 - zeroBasedDriftAngle)
        end

        directx.draw_text(0,0,"Drift Angle: " .. math.floor(zeroBasedDriftAngle) .. "°", ALIGN_TOP_CENTRE,1,textDrawCol)
        local done = false
        if ((isDrifting or kmh > gs_driftMinSpeed) and (math.abs(driftAngle - 360.0) < gs_driftMaxAngle) or (driftAngle < gs_driftMaxAngle)) then
            isDrifting      = 1
            isDriftFinished = 1;  -- Doesn't get set to 0 until isDrifting is 0.

            if driftKeyPressed then
                 
                if driftKeyPressed ~= oldGripState then
                    VEHICLE.SET_VEHICLE_REDUCE_GRIP(veh, driftKeyPressed)
                    oldGripState = driftKeyPressed
                end
            end
            done = true
        end

        if not done and kmh < gs_driftMinSpeed then
            if driftKeyPressed then
                if driftKeyPressed ~= oldGripState then
                    VEHICLE.SET_VEHICLE_REDUCE_GRIP(veh, driftKeyPressed)
                    oldGripState = driftKeyPressed
                end
            end
            done = true
        end

        if not done then

            if driftKeyPressed == oldGripState then
                VEHICLE.SET_VEHICLE_REDUCE_GRIP(veh, false)
                oldGripState = 0
            end

            if math.abs(zeroBasedDriftAngle) > gs_driftMaxAngle then
                if zeroBasedDriftAngle > 0 then
                    VEHICLE.SET_VEHICLE_INDICATOR_LIGHTS(veh, 0, true)
                    VEHICLE.SET_VEHICLE_INDICATOR_LIGHTS(veh, 1, false)                 
                    util.toast("카운터 스티어링 좌측 ")                    
                    VEHICLE.SET_VEHICLE_STEER_BIAS(veh, math.rad(zeroBasedDriftAngle * 0.69))              
                else
                    VEHICLE.SET_VEHICLE_INDICATOR_LIGHTS(veh, 1, true)
                    VEHICLE.SET_VEHICLE_INDICATOR_LIGHTS(veh, 0, false)
                    util.toast("카운터 스티어링 우측")
                    VEHICLE.SET_VEHICLE_STEER_BIAS(veh, math.rad(zeroBasedDriftAngle * 0.69))      
                end
            end
		else 
			VEHICLE.SET_VEHICLE_INDICATOR_LIGHTS(veh, 0, false)
			VEHICLE.SET_VEHICLE_INDICATOR_LIGHTS(veh, 1, false)
        end
    end

    if not driftKeyPressed and prevGripState then
        isDrifting      = 0
        isDriftFinished = 0
        lastDriftAngle = 0

        if driftKeyPressed ~= oldGripState then
            VEHICLE.SET_VEHICLE_REDUCE_GRIP(veh, driftKeyPressed)
            oldGripState = driftKeyPressed
        end
    end

    prevGripState = driftKeyPressed
    if isDrifting ~= wasDrifting then
        wasDrifting     = isDrifting
        changedDrifting = true
    end
end

menu.toggle_loop(driftmodee,"드리프트 모드", {},"드리프트하려면 [ SHIFT ]",function(on)
	driftmod_ontick()
end)
driftSetings = menu.list(driftmodee, "설정", {}, "")

menu.slider(driftSetings,"최소 속도 /100", {}, "/100", 0, 10000, gs_driftMinSpeed*100, 1, function(on)
    gs_driftMinSpeed = on/100
end)

menu.slider(driftSetings,"최대 각도 /100", {}, "/100", 0, 10000,gs_driftMaxAngle*100, 1, function(on)
    gs_driftMaxAngle = on/100
end)

menu.colour(driftSetings,"텍스트 색상", {}, "", textDrawCol,true , function(newCol)
    textDrawCol = newCol
end)
--- vehicle END



--[[
    misc = "크레딧"
]]
menu.hyperlink(misc, "Coded By HADES#6368", "https://shorturl.at/dwzJO","스키드 개발이지만 사용 편의를 위해 많은 노력 중입니다.")
menu.hyperlink(misc, "Join Discord - "..SCRIPT_NAME, "https://shorturl.at/cDLTX", "버그 신고 및 사용 방법 지원")
menu.divider(misc, "--------------------------------")
menu.action(misc, "IceDoomfist#0001", {}, "루아 스크립트 개발 도움을 주는", function()end)

--- misc END

--[[
-------------------------------------players-------------------------------------
---------------------------------------------------------------------------------
]]
players.on_join(function(player_id)
    menu.divider(menu.player_root(player_id), "하데스 스크립트")

    local hadesScripts = menu.list(menu.player_root(player_id), "하데스 스크립트", {"hadesScripts"})
    menu.toggle(hadesScripts, "닌자방식 관전", { "hadesSpectate" }, "닌자 방식으로 관전 합니다.", function(on_click)
        menu.trigger_commands("spectate " .. players.get_name(player_id))
    end)

    local malicious = menu.list(hadesScripts, "악의적인")
    local trolling = menu.list(hadesScripts, "트롤링")
    local friendly = menu.list(hadesScripts, "우호적인")
    local vehicle = menu.list(hadesScripts, "차량")
    local otherc = menu.list(hadesScripts, "기타")

    local explosion = 18
    local explosion_names = {
        [0] = "소",
        [1] = "중",
        [2] = "대",
        [3] = "특대"
    }

--[[
    trolling = "트롤링"
]]
    local explode_slider = menu.slider_text(trolling, "폭발 방법", {"customexplode"}, "", explosion_names, function()
        local player_pos = players.get_position(player_id)
        FIRE.ADD_EXPLOSION(player_pos.x, player_pos.y, player_pos.z, explosion, 1, true, false, 1, false)
    end)

    util.create_tick_handler(function()
        if not players.exists(player_id) then
            return false
        end

        local index = menu.get_value(explode_slider)

        switch index do
            case 1:
                explosion = 0
                break
            case 2:
                explosion = 34
                break
            case 3:
                explosion = 82
                break
            pluto_default:
                explosion = 18
        end
    end)

    menu.action(trolling, "폭발", { "customExplosion" }, "사용자에게 폭발을 보냅니다.", function()
        local player_pos = players.get_position(player_id)
        FIRE.ADD_EXPLOSION(player_pos.x, player_pos.y, player_pos.z, explosion, 1, true, false, 1, false)
    end)

    menu.toggle_loop(trolling, "폭발 반복", {"customExplodeLoop"}, "", function()
        if players.exists(player_id) then
            local player_pos = players.get_position(player_id)
            FIRE.ADD_EXPLOSION(player_pos.x, player_pos.y, player_pos.z, explosion, 1, true, false, 1, false)
            util.yield(100)
        end
    end)

    menu.toggle(trolling, "체력 회복", {"autoHeal"}, "", function()
        menu.trigger_commands("autoheal" .. players.get_name(player_id))
    end)

    menu.toggle_loop(trolling, "아토마이저 반복", {"atomizeLoop"}, "체력 회복을 주면서 아토마이저 발사는 효과 적일 것 입니다.", function()
        if players.exists(player_id) then
            local player_pos = players.get_position(player_id)
            FIRE.ADD_EXPLOSION(player_pos.x, player_pos.y, player_pos.z - 1, 70, 1, true, false, 1, false)
            util.yield(2000)
        end
    end)

    menu.toggle_loop(trolling, "폭죽 폭발 반복", {"fireworkLoop"}, "", function()
        if players.exists(player_id) then
            local player_pos = players.get_position(player_id)
            FIRE.ADD_EXPLOSION(player_pos.x, player_pos.y, player_pos.z - 1, 38, 1, true, false, 1, false)
            util.yield(100)
        end
    end)

    menu.toggle_loop(trolling, "불기둥 반복", {"flameLoop"}, "", function()
        if players.exists(player_id) then
            local player_pos = players.get_position(player_id)
            FIRE.ADD_EXPLOSION(player_pos.x, player_pos.y, player_pos.z - 1, 12, 1, true, false, 1, false)
            util.yield(5)
        end
    end)

    menu.toggle_loop(trolling, "물기둥 반복", {"waterLoop"}, "", function()
        if players.exists(player_id) then
            local player_pos = players.get_position(player_id)
            FIRE.ADD_EXPLOSION(player_pos.x, player_pos.y, player_pos.z - 1, 13, 1, true, false, 1, false)
            util.yield(5)
        end
    end)

    menu.action(trolling, "오비탈 캐논", { "WiriOrbital" }, "WiriScript가 실행 되어있어야 합니다.", function()
        menu.trigger_commands("luaWiriScript")
        util.yield(100)
        menu.trigger_commands("luaHadesScript")
        util.yield(500)
        menu.trigger_commands("orbital" .. players.get_name(player_id))
        menu.trigger_command(trolling)
    end)
--- trolling END

--[[
    player_root = "플레이어"
]]
    menu.action(menu.player_root(player_id), "스마트 킥 및 차단", { "SmartKick" }, "스마트 킥을 하며 해당 플레이어를 차단 합니다.", function(on_click)
        local userName = players.get_name(player_id)
        util.toast("스마트 킥".." >>>> "..userName)
        NOTIFY(userName.."에게 스마트 킥을 보내고 플레이어 기록에서 차단을 합니다.")
        menu.trigger_commands("kick" .. userName)
        menu.trigger_commands("findplayer " .. userName)
        menu.trigger_commands("historyblock" .. userName)
        util.log(userName.."에게 스마트 킥을 보내고 플레이어 기록에서 차단을 합니다.")
    end)
    
    menu.toggle_loop(menu.player_root(player_id), "폭발", {}, "사용자에게 폭발을 보냅니다.", function()
        menu.trigger_commands("Explode " .. players.get_name(player_id))
    end)

    menu.toggle(menu.player_root(player_id), "관전", { "hadesSpectate" }, "닌자 방식으로 관전 합니다.", function(on_click)
        menu.trigger_commands("spectate " .. players.get_name(player_id))
    end)

    menu.action(menu.player_root(player_id), "브레이크 업", {"hadesBreakUp"}, "브레이크 업을 전송합니다. Regular버전이상 사용자만 가능합니다.", function()
        local userName = players.get_name(player_id)
        NOTIFY(userName.."에게 브레이크 업 스크립트를 보냅니다.")
        menu.trigger_commands("breakUp" .. userName)
        util.log(userName.."에게 브레이크 업 스크립트를 보냅니다.")
    end)
--- player_root END

    local last_car = 0
    -- ## MAIN TICK LOOP ## --
    while true do
        player_cur_car = entities.get_user_vehicle_as_handle()
        if last_car ~= player_cur_car and player_cur_car ~= 0 then 
            on_user_change_vehicle(player_cur_car)
            last_car = player_cur_car
        end
        util.yield()
    end
end)

util.on_stop(function ()
    NOTIFY("하데스 스크립트 종료")
end)

players.dispatch_on_join()
util.keep_running()