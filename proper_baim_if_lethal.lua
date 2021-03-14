-- local variables for API functions. any changes to the line below will be lost on re-generation
local client_create_interface, client_set_event_callback, entity_hitbox_position, plist_set, require, ui_new_checkbox, pairs, error = client.create_interface, client.set_event_callback, entity.hitbox_position, plist.set, require, ui.new_checkbox, pairs, error

local bit = require('bit')
local ffi = require('ffi')
local vector = require('vector')

--variables
local entity_get_local_player = entity.get_local_player
local entity_get_player_weapon = entity.get_player_weapon
local entity_get_player_resource = entity.get_player_resource
local client_trace_bullet = client.trace_bullet

local entity_is_enemy = entity.is_enemy

local entity_get_prop = entity.get_prop
local entity_get_bounding_box = entity.get_bounding_box
local entity_get_player_name = entity.get_player_name
local entity_get_classname = entity.get_classname

local globals_tickcount = globals.tickcount
local globals_maxplayers = globals.maxplayers
local table_insert = table.insert
local math_min = math.min
local ui_get = ui.get

--ui
local ui_force_baim_if_lethal = ui_new_checkbox("LUA", "A", "Force Baim if Lethal")

--entry
local baim_hitboxes = {3,4,5,6} --im using only stomach, lowerchest,chest,upperchest i don't use pelvis since it's an innacurate hitbox due to many reasons but u can use it if u want
--index for pelvis = 2

local function trace_damage(ent, localplayer)	
	if ent == nil then return end
	
    local leyeposx, leyeposy, leyeposz = client.eye_position()
	if leyeposz == nil then return end

    local final_damage = 0
    for k,v in pairs(baim_hitboxes) do
        local endHitbox = vector(entity_hitbox_position(ent, v))
	    local ___, dmg = client_trace_bullet(localplayer, leyeposx, leyeposy, leyeposz, endHitbox.x, endHitbox.y, endHitbox.z, true)
	
	    if ( dmg > final_damage) then --if we can hit body hitboxes i use this in case of head only visible / legs etc so we don't break our aimbot
            final_damage = dmg
        end
	end
    
    return final_damage -- return our final dmg if we can hit their body 
end

--ignore this 
ffi.cdef[[
  typedef struct {
    float x;
    float y;
    float z;
  } Vector;

  typedef uintptr_t (__thiscall* GetClientEntity_4242425_t)(void*, int);
]]

local ffi_EntListPointer = ffi.cast("void***", client_create_interface("client.dll", "VClientEntityList003")) or error("Failed to find VClientEntityList003!")
local ffi_GetClientEntFN = ffi.cast("GetClientEntity_4242425_t", ffi_EntListPointer[0][3])

local ffi_helpers = {
    get_entity_address = function(entity_index)
        local addr = ffi_GetClientEntFN(ffi_EntListPointer, entity_index)
        return addr
    end
}
--ignore this ^

  
local function get_entities(enemy_only, alive_only)
	local enemy_only = enemy_only ~= nil and enemy_only or false
    local alive_only = alive_only ~= nil and alive_only or true
    
    local result = {}

    local me = entity_get_local_player()
    local player_resource = entity_get_player_resource()
    
	for player = 1, globals_maxplayers() do
		if entity_get_prop(player_resource, 'm_bConnected', player) == 1 then
            local is_enemy, is_alive = true, true
            
			if enemy_only and not entity_is_enemy(player) then is_enemy = false end
			if is_enemy then
				if alive_only and entity_get_prop(player_resource, 'm_bAlive', player) ~= 1 then is_alive = false end
				if is_alive then table_insert(result, player) end
			end
		end
	end

	return result
end
local function rbot_run_hitscan()

    if ( not ui_get(ui_force_baim_if_lethal) ) then return end 

    local me = entity_get_local_player()
    local player_resource = entity_get_player_resource()

	local observer_mode = entity_get_prop(me, "m_iObserverMode")
	local active_players = {}

	if (observer_mode == 0 or observer_mode == 1 or observer_mode == 2 or observer_mode == 6) then
		active_players = get_entities(true, true)
	elseif (observer_mode == 4 or observer_mode == 5) then
		local all_players = get_entities(false, true)
		local observer_target = entity_get_prop(me, "m_hObserverTarget")
		local observer_target_team = entity_get_prop(observer_target, "m_iTeamNum")

		for test_player = 1, #all_players do
			if (
				observer_target_team ~= entity_get_prop(all_players[test_player], "m_iTeamNum") and
				all_players[test_player ] ~= me
			) then
				table_insert(active_players, all_players[test_player])
			end
		end
	end

    if #active_players == 0 then
        return
    end

    local weapon = entity_get_player_weapon(me)

    if ( weapon == nil ) then return end 

    for i=1, #active_players do
        local player = active_players[i]
   
        if ( player == nil ) then return end 
           
        local target_health = entity_get_prop(player, "m_iHealth") 

        if ( target_health <= 0 ) then return end 
        local is_lethal = trace_damage(player, me) >= target_health

        if (is_lethal) then 
            --print("[RBOT] lethal target found!")
            plist_set(player, "Override prefer body aim", "Force")
        else 
            plist_set(player, "Override prefer body aim", "-")
        end
    end
end

client_set_event_callback("run_command", rbot_run_hitscan)
