
local autorun_walkspeed = 1.25
local autorun_walktime = 2
local autorun_acceltime = 4
local autorun_ratio = 2

local function solid(pos)
	local node = core.get_node(pos)
	local def = core.registered_items[node.name]
	if not def then return true end
	return def.liquidtype == "none" and def.walkable
end

local hurttime = {}
core.register_on_player_hpchange(function(player, hp_change, reason)
	if not core.settings:get("enable_damage") then return end
	hurttime[player:get_player_name()] = core.get_gametime()
end)

local data = {
	autoruntime = {},
	speed = {},
	sneaking = {},
	time = 0
}

core.register_on_mods_loaded(function()
	data.time = core.get_gametime()
end)

core.register_globalstep(function(dtime)
	if data.time then
		data.time = data.time + dtime
	else
		data.time = core.get_gametime()
	end

	for _,player in pairs(core.get_connected_players()) do
		local ctl = player:get_player_control()
		local name = player:get_player_name()

		if ctl.sneak ~= data.sneaking[name] then
			data.sneaking[name] = ctl.sneak

			local stepheight
			if ctl.sneak then
				stepheight = 0.0001
			else
				stepheight = 1.1
			end

			player:set_properties({stepheight = stepheight})
		end

		local walking = ctl.up and not ctl.down
		if (not walking) and ctl.jump and (not ctl.sneak) then
			local ppos = player:get_pos()
			local def = core.registered_nodes[core.get_node(ppos).name]
			walking = def and (def.climbable or def.liquidtype ~= "none")
			if not walking then
				ppos.y = ppos.y + 1
				def = core.registered_nodes[core.get_node(ppos).name]
				walking = def and (def.climbable or def.liquidtype ~= "none")
			end
		end

		if walking and ctl.sneak then
			local pos = player:get_pos()
			if not solid(pos) then
				pos.y = pos.y - 1
				walking = not solid(pos)
			end
		end

		local speed = autorun_walkspeed
		local max = autorun_walkspeed * autorun_ratio
		if walking and data.autoruntime[name] then
			local ht = hurttime[name]
			if ht and ht > data.autoruntime[name] then data.autoruntime[name] = ht end
			local t = data.time - data.autoruntime[name] - autorun_walktime
			if t > math.pi * autorun_acceltime then
				speed = max
			elseif t > 0 then
				local hr = (autorun_ratio - 1) / 2
				speed = autorun_walkspeed * (1 + hr + hr * math.sin(t / autorun_acceltime - math.pi / 2))
			end
		else
			data.autoruntime[name] = data.time
		end
		local oldspeed = data.speed[name] or 0

		if oldspeed > speed or oldspeed < (speed - 0.05)
		or (speed == max and oldspeed ~= max) then
			data.speed[name] = speed
			player:set_physics_override({ speed = speed })
		end

		--core.log("SPD: "..data.speed[name].." | TIME: "..data.time)
	end
end)
