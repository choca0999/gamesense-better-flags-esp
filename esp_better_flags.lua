local success, surface = pcall(require, 'gamesense/surface')

if not success then
    error('\n\n - Surface library is required \n - https://gamesense.pub/forums/viewtopic.php?id=18793\n')
end

-- Initialization
local icon_font = surface.create_font('AstriumWep', 14, 500, {0x010}, {0x080})
local icon_font2 = surface.create_font('AstriumWep', 11, 500, {0x010}, {0x080})
local text_font = surface.create_font('Verdana', 10, 700, {0x010}, {0x080})
local text_font2 = surface.create_font('Verdana', 9, 500, {0x010}, {0x080})
local duck_font = surface.create_font('Animals 2', 14, 500, {0x010}, {0x080})
-- Plugin elements
local refer = { 'Visuals', 'Player ESP' }

local flag_list = { 'hk', 'scoped', "defuser", "c4", "hit", "fd ( animal )", "fd ( text )" }

local duck_ticks = { }
local menu = {
    team = ui.reference('Visuals', 'Player ESP', 'Teammates'),

    flags = ui.new_multiselect(refer[1], refer[2], 'flags', flag_list),
}

-- Local variables & functions
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


local surface_measure_text = surface.measure_text
local surface_draw_text = surface.draw_text
local surface_draw_filled_rect = surface.draw_filled_rect

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
local function can_enemy_hit_us(ent, ent2)	
	if ent == nil then return end
	
	local origin_x, origin_y, origin_z = entity_get_prop(ent, "m_vecOrigin")
	if origin_z == nil then return end

    local lorigin_x, lorigin_y, lorigin_z = entity_get_prop(ent2, "m_vecOrigin")
	if lorigin_z == nil then return end
	
	local ___, dmg = client_trace_bullet(ent, origin_x, origin_y, origin_z, lorigin_x, lorigin_y, lorigin_z, true)
	

	local damage = dmg ~= nil and dmg > 0
	
	return damage
end
client.set_event_callback('paint', function()
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

    for i=1, #active_players do
        local player = active_players[i]
        local x1, y1, x2, y2, a_multiplier = entity_get_bounding_box(c, player)

        if x1 ~= nil and a_multiplier > 0 then
            local center = x1 + (x2-x1)/2
            local should_draw_hitflag = false 
            local pflags = ui_get(menu.flags)
            local weapon = entity_get_player_weapon(player)
            local wpn_id = entity_get_prop(weapon, "m_iItemDefinitionIndex")
            local enemy_origin_x, enemy_origin_y, enemy_origin_z = entity_get_prop(enemy, "m_vecOrigin")
            local local_origin_x, local_origin_y, local_origin_z = entity_get_prop(me, "m_vecOrigin")
           

            if #pflags ~= 0 then
                local offset = 0

                local m_iPlayerC4 = entity_get_prop(player_resource, 'm_iPlayerC4')
              

                -- { 'fake', 'delay', 'helm', 'scoped', 'blind', 'duck', 'bomb', 'host', 'pin', 'vulnerable' }

                for j=1, #pflags do
                    local flag = pflags[j]

                    if flag == 'hk' then
                        local helm, kev = 
                            entity_get_prop(player, 'm_bHasHelmet') == 1, 
                            entity_get_prop(player, 'm_ArmorValue') ~= 0

                        if helm or kev then
                            local text = helm and 'p' or (kev and 'q' or '')
                            if ( helm and not kev) then 
                                surface_draw_text(x2 + 6, y1 + (offset * 10) - 2, 255, 255, 255, a_multiplier*255, icon_font, text)
                                offset = offset + 1.4
                            else if ( kev ) then 
                                surface_draw_text(x2 + 6, y1 + (offset * 10) - 2, 255, 255, 255, a_multiplier*255, icon_font, text)
                                offset = offset + 1.4
                            else if ( entity_get_prop(player, 'm_ArmorValue') <= 50) then 
                                surface_draw_text(x2 + 6, y1 + (offset * 10) - 2, 255, 255, 255, a_multiplier*255, icon_font, "q")
                                offset = offset + 1.4
                            end end end
                        end           
                    end
                    if flag == 'scoped' and weapon ~= nil then
                        local wpn_name = entity_get_classname(weapon)
                        local zoom_lvl = entity_get_prop(weapon, 'm_zoomLevel')

                        if wpn_name ~= nil and zoom_lvl ~= 0 and (wpn_name:lower():match("ssg08") or wpn_name:lower():match("awp") or wpn_name:lower():match("scar20") or wpn_name:lower():match("g3sg1")) then
                            surface_draw_text(x2 + 6, y1 + (offset * 10) - 2, 30, 120, 235, a_multiplier*255, icon_font2, 's')
                            offset = offset + 1.4
                        end
                    end
                    if flag == 'defuser' and weapon ~= nil then
                        local has_defuser = entity_get_prop(player, 'm_bHasDefuser')

                        if has_defuser ~= 0  then
                            surface_draw_text(x2 + 6, y1 + (offset * 10) - 2, 255, 0, 0, a_multiplier*255, icon_font, 'r')
                            offset = offset + 1.4
                        end
                    end
                    if flag == 'c4' and wpn_id == 49 then
                        surface_draw_text(x2 + 6, y1 + (offset * 10) - 2, 100, 100, 100, a_multiplier*255, icon_font, 'o')
                        offset = offset + 1.4         
                    end
                  
                    if flag == 'hit' and can_enemy_hit_us(player, me) then
                        surface_draw_text(x2 + 6, y1 + (offset * 10) - 2, 255, 100, 0, a_multiplier*255, text_font, '(!)')
                        offset = offset + 1.4         
                    end
                    local draw_fd = false
                    local toBits = function(num) local t = { }; while num > 0 do rest = math.fmod(num,2); t[#t+1] = rest; num = (num-rest) / 2 end return t end

                        local duck_amt = entity_get_prop(player, 'm_flDuckAmount')
                        local duck_speed = entity_get_prop(player, 'm_flDuckSpeed')
                        local m_fFlags = entity_get_prop(player, 'm_fFlags')

                        if duck_ticks == nil then
                            duck_ticks = { }
                        end

                        if duck_ticks[player] == nil then duck_ticks[player] = 0 end
                        if duck_speed ~= nil and duck_amt ~= nil then
                            if duck_speed == 8 and duck_amt <= 0.9 and duck_amt > 0.01 and toBits(m_fFlags)[1] == 1 then
                                if storedTick ~= globals_tickcount() then
                                    duck_ticks[player] = duck_ticks[player] + 1
                                    storedTick = globals_tickcount()
                                end
            
                                if duck_ticks[player] >= 5 then 
                                    draw_fd = true                       
                                end
                            else
                                duck_ticks[player] = 0
                            end
                        end

                    if flag == 'fd ( animal )' and draw_fd then
                         surface_draw_text(x2 + 2, y1 + (offset * 10) - 2, 255, 255, 255, a_multiplier*255, duck_font, 'A')
                         offset = offset + 1
                    else if flag == 'fd ( text )' and draw_fd then
                        surface_draw_text(x2 + 2, y1 + (offset * 10) - 2, 255, 255, 255, a_multiplier*255, text_font, 'FD')
                        offset = offset + 1
                    end end
                end
            end
        end
    end 
end)
