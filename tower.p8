pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
--game variables
game_level = 1
game_money = 0
game_cursor = {
	x = 0,
	y = 0,
	mode = 0,
	closest_unit = 0
}

game_menu_unit = {
	bg = {0, 0, 128, 9},
	bg_clr = 0,
	name = {0, 4},
	lvl = {36, 4},
	info = {47, 4},
	btn_upgrade = {97, 1},
	btn_delete = {107, 1},
	btn_back = {117, 1},
	btn_pressed = 0,
	btn_tm = 8,
	btn_tmr = 0
}

game_unit_selected = 0

function game_menu_unit_reset()
	local gm = game_menu_unit
	gm.btn_upgrade[3] = 0
	gm.btn_delete[3] = 0
	gm.btn_back[3] = 0
end
-->8
--entities
ent_enemy = {}
ent_explosion = {}
ent_tower = {}
ent_road = {}

ent_path = {
	{{16, 0}, {16, 104}, {56, 104}, {56, 16}, {96, 16},{96, 120}},
	{{0, 64}, {64, 64}, {64, 24}, {32, 24}, {32, 0}, {96, 0}, {96, 104}, {64, 104}}
}

function ent_enemy_create(x, y, enemy_id)
	local e = {
		x = x,
		y = y,
		path_node = 1,
		hp = 100,
		dmg = 1,
		rng = 4,
		spd = 0.5,
		spd_modifier = 0,
		enemy_id = enemy_id,
		tm = 5,
		tmr = 0,
		behavior = 0,
		dir = 0,
		sprite_flip = false,
		sprites_down = {},
		sprites_left = {},
		sprites_right = {},
		sprites_up = {},
		sprite_current = 0,
		frame = 1
	}
	--initializing code based on enemy_id
	if enemy_id == 1 then
		e.sprites_down = {50, 51, 50, 51}
		e.sprites_left = {52, 53, 54, 53}
		e.sprites_right = {52, 53, 54, 53}
		e.sprites_up = {55, 56, 55, 56}
	end
	add(ent_enemy, e)
end

function ent_explosion_create(x, y, dmg, explosion_id)
	local e = {
		x = x,
		y = y,
		dmg = dmg,
		rad = 3,
		col = 7,
		tm = 5,
		tmr = 0,
		explosion_id = explosion_id
	}
	--initializing code based on explosion_id
	--muzzle flash
	if e.explosion_id == 0 then
		e.rad = 1
	end
	add(ent_explosion, e)
end

function ent_tower_create(x, y, tower_id)
	local e = {
		x = x,
		y = y,
		tower_id = tower_id,
		name = "",
		lvl = 1,
		lvl_max = 5,
		hp = 1,
		dmg = {},
		rng = 8,
		cost = {},
		tm = 20,
		tmr = 0,
		target_x = -1,
		target_y = -1,
		behavior = 0,
		sprites = {},
		sprite_current = 0,
		sprite_flip = false,
		shooter = true,
		selected = false,
		frame = 1
	}
	--initializing code based on tower_id
	--basic gun turret
	if tower_id == 1 then
		e.name = "sentry"
		e.sprites = {1, 2, 3, 4, 5}
		e.dmg = {1, 2}
		e.cost = {10, 20, 30, 40, 50}

	--magnet tower
	elseif tower_id == 2 then
		e.name = "magspire"
		e.sprites = {6, 7, 8, 9, 8, 7}
		e.frame = e.sprites[1]
		e.tm = 2
		e.dmg = {-0.25, -0.75}
		e.shooter = false
		e.cost = {10, 20, 30, 40, 50}
	--sniper cannon
	elseif tower_id == 3 then
		e.name = "railgun"
		e.sprites = {17, 18, 19, 20, 21}
		e.tm = 40
		e.dmg = {20, 22}
		e.rng = 12
		e.cost = {10, 20, 30, 40, 50}
	end
	e.sprite_current = e.sprites[1]
	add(ent_tower, e)
end

function ent_tower_get_cost(index)
	local t = ent_tower[index]
	local c
	if t.lvl + 1 <= #t.cost then
		c = t.cost[t.lvl + 1]
	else
		c = 0
	end
	return c
end


function ent_road_create(x, y, road_id)
	local e = {
		x = x,
		y = y,
		road_id = road_id,
		sprite = 49
	}
	--initializing code based on road_id
	add(ent_road, e)
end

-->8
--systems

function sys_ai_explosions()
	local ex, en
	for i = 1, #ent_explosion do
		ex = ent_explosion[i]
		for j = 1, #ent_enemy do
			en = ent_enemy[j]
			if distance_get(ex.x, ex.y, en.x, en.y) <= ex.rad + 1 then
				en.hp -= ex.dmg
				if ex.explosion_id == 1 then
					sfx(0)
				elseif ex.explosion_id == 3 then
					sfx(1)
				end
			end
		end
		ex.dmg = 0

		if ex.rad > 0 then
			ex.rad -= 0.5
		end
	end
end

function sys_ai_enemies()
	local e, px, py, distx, disty, spd
	for i = 1, #ent_enemy do
		--movement
		e = ent_enemy[i]
		px = ent_path[game_level][e.path_node][1]
		py = ent_path[game_level][e.path_node][2]
		distx = abs(e.x - px)
		disty = abs(e.y - py)
		spd = max(e.spd + e.spd_modifier, 0.1) -- makes sure enemies don't stop completely
		if e.x > px then
			e.x -= min(distx, spd)
			e.dir = 0 --left
		elseif e.x < px then
			e.x += min(distx, spd)
			e.dir = 1 --right
		end
		if e.y > py then
			e.y -= min(disty, spd)
			e.dir = 2 -- up
		elseif e.y < py then
			e.y += min(disty, spd)
			e.dir = 3 -- down
		end
		if e.x == px and e.y == py then
			if e.path_node + 1 <= #ent_path[game_level] then
				e.path_node += 1
			end
		end
		if e.spd_modifier != 0 then
			e.spd_modifier = 0
		end
	end
end

function sys_ai_towers()
	for i = 1, #ent_tower do
		local t = ent_tower[i]
		local target = 0
		local target_dist = 128
		local e

		--selection toggle (probably redundant)
		if t.selected == true and game_unit_selected != i then
			t.selected = false
		end

		--find closest enemy
		local current_dist
		if t.shooter == true then
			for j = 1, #ent_enemy do
				e = ent_enemy[j]
				current_dist = distance_get(t.x, t.y, e.x, e.y)
				if current_dist < target_dist then
					if current_dist <= t.rng then
						target = j
						target_dist = current_dist
					end
				end
			end
		elseif t.shooter == false then
		-- find all enemies within range
			for j = 1, #ent_enemy do
				e = ent_enemy[j]
				current_dist = distance_get(t.x, t.y, e.x, e.y)
				if current_dist <= t.rng then
					if t.tower_id == 2 then
						e.spd_modifier = t.dmg[t.lvl]
					end
				end
			end
		end
		if target != 0 then
			t.behavior = 1
			t.target_x = ent_enemy[target].x
			t.target_y = ent_enemy[target].y
		else
			t.behavior = 0
		end
		if t.behavior == 1 then
			if t.tmr == t.tm then
				t.tmr = 0
				--shooting bullets
				-- adjust where the bullet emerges from tower sprite
				local bx, by = 0, 0
				if t.shooter == true then
					if t.sprite_current == t.sprites[1] then
						if t.sprite_flip == false then
							bx = -4
						else
							bx = 4
						end
					elseif t.sprite_current == t.sprites[2] then
						by = 1
						if t.sprite_flip == false then
							bx = -2
						else
							bx = 2
						end
					elseif t.sprite_current == t.sprites[3] then
						by = 3
					elseif t.sprite_current == t.sprites[4] then
						by = -3
						if t.sprite_flip == false then
							bx = 3
						else
							bx = -2
						end
					elseif t.sprite_current == t.sprites[5] then
						by = -3
					end
					ent_explosion_create(t.target_x + 4, t.target_y + 4, t.dmg[t.lvl], t.tower_id)
					ent_explosion_create(t.x + 4 + bx, t.y + 4 + by, 0, 0)
				end
			else
				t.tmr += 1
			end
		end
	end
end

function sys_animate_enemies()
	for i = 1, #ent_enemy do
		local e = ent_enemy[i]
		if e.tmr > 0 then
			e.tmr -= 1
		end
		if e.tmr == 0 then
			e.tmr = e.tm
			e.frame += 1
			if e.behavior == 0 then
				if e.dir == 0 then -- left
					e.sprite_flip = true
					if e.frame > #e.sprites_left then
						e.frame = 1
					end
				elseif e.dir == 1 then -- right
					e.sprite_flip = false
					if e.frame > #e.sprites_right then
						e.frame = 1
					end
				elseif e.dir == 2 then -- up
					if e.frame > #e.sprites_up then
						e.frame = 1
					end
					if e.frame == 3 then
						e.sprite_flip = true
					else
						e.sprite_flip = false
					end
				elseif e.dir == 3 then -- down
					if e.frame > #e.sprites_down then
						e.frame = 1
					end
					if e.frame == 3 then
						e.sprite_flip = true
					else
						e.sprite_flip = false
					end
				end
			elseif e.behavior == 1 then
				-- aggressive behavior?
			end
		end
	end
end

function sys_animate_hud()
	local gm = game_menu_unit

	if gm.btn_tmr == 0 then
		if gm.btn_pressed == 1 then
			sfx(2)
		elseif gm.btn_pressed == 2 then
			sfx(3)
		end
		gm.btn_pressed = 0
	end
	if gm.btn_tmr > 0 then
		gm.btn_tmr -= 1
	end
end

function sys_animate_towers()
	local ang = 8
	for i = 1, #ent_tower do
		local t = ent_tower[i]
		if t.shooter == true then
			if t.behavior == 1 then
				if abs(t.x - t.target_x) < ang then
					if t.y > t.target_y then
						-- 12 o'clock
						t.sprite_current = t.sprites[5]
					else
						-- 6 o'clock
						t.sprite_current = t.sprites[3]
					end
				elseif t.x > t.target_x then
					if abs(t.y - t.target_y) < ang then
						-- 9 o'clock
						t.sprite_current = t.sprites[1]
						t.sprite_flip = false
					elseif t.y > t.target_y then
						--  10  o'clock
						t.sprite_current = t.sprites[4]
						t.sprite_flip = true
					elseif t.y < t.target_y then
						-- 8 o'clock
						t.sprite_current = t.sprites[2]
						t.sprite_flip = false
					end
				elseif t.x < t.target_x then
					if abs(t.y - t.target_y) < ang then
						-- 3 o'clock
						t.sprite_current = t.sprites[1]
						t.sprite_flip = true
					elseif t.y > t.target_y then
						-- 2 o'clock
						t.sprite_current = t.sprites[4]
						t.sprite_flip = false
					elseif t.y < t.target_y then
						-- 4 o'clock
						t.sprite_current = t.sprites[2]
						t.sprite_flip = true
					end
				end
			end
		elseif t.shooter == false then
			if t.tmr < t.tm then
				t.tmr += 1
			elseif t.tmr == t.tm then
				t.frame += 1
				t.tmr = 0
			end
			if t.frame > #t.sprites then
				t.frame = 1
			end
			t.sprite_current = t.sprites[t.frame]
		end
	end
end

function sys_delete_enemies()
	if #ent_enemy > 0 then
		for i = #ent_enemy, 1, -1 do
			if ent_enemy[i].hp < 1 then
				deli(ent_enemy, i)
			end
		end
	end
end

function sys_delete_explosions()
	if #ent_explosion> 0 then
		for i = #ent_explosion, 1, -1 do
			if ent_explosion[i].rad == 0 then
				deli(ent_explosion, i)
			end
		end
	end
end

function sys_delete_towers()
	if #ent_tower> 0 then
		for i = #ent_tower, 1, -1 do
			if ent_tower[i].hp == 0 then
				if ent_tower[i].selected == true then
					game_unit_selected = 0
				end
				deli(ent_tower, i)
			end
		end
	end
end

function sys_draw_cursor()
	if game_cursor.mode == 0 then
		spr(35, game_cursor.x, game_cursor.y)
	else
		spr(36, game_cursor.x, game_cursor.y)
	end
end

function sys_draw_explosions()
	local e
	for i = 1, #ent_explosion do
		e = ent_explosion[i]
		if e.explosion_id == 0 then --muzzle flash
			circfill(e.x - e.rad, e.y - e.rad, e.rad + 1, e.col)
		else
			circfill(e.x - e.rad, e.y - e.rad, e.rad + 1, 10)
			circfill(e.x - e.rad, e.y - e.rad, e.rad, e.col)
		end
	end
end

function sys_draw_enemies()
	local e
	for i = 1, #ent_enemy do
		e = ent_enemy[i]
		if e.dir == 0 then
			spr(e.sprites_left[e.frame], e.x, e.y, 1, 1, e.sprite_flip)
		elseif e.dir == 1 then
			spr(e.sprites_right[e.frame], e.x, e.y, 1, 1, e.sprite_flip)
		elseif e.dir == 2 then
			spr(e.sprites_up[e.frame], e.x, e.y, 1, 1, e.sprite_flip)
		elseif e.dir == 3 then
			spr(e.sprites_down[e.frame], e.x, e.y, 1, 1, e.sprite_flip)
		end

	end
end

function sys_draw_hud()
	--unit select menu options
	local gm = game_menu_unit
	local n = 0
	if game_unit_selected != 0 then
		rectfill(gm.bg[1], gm.bg[2], gm.bg[3], gm.bg[4], gm.bg_clr)
		print(ent_tower[game_unit_selected].name, gm.name[1], gm.name[2], 7)
		print(ent_tower[game_unit_selected].lvl, gm.lvl[1], gm.lvl[2], 7)
		--	print("🅾️options ❎exit", 56, 0, 7)
		if gm.btn_pressed == 1 then n = 1 else n = 0 end
		spr(37, gm.btn_upgrade[1], gm.btn_upgrade[2] + n)
		if gm.btn_pressed == 2 then n = 1 else n = 0 end
		spr(38, gm.btn_delete[1], gm.btn_delete[2] + n)
		if gm.btn_pressed == 3 then n = 1 else n = 0 end
		spr(39, gm.btn_back[1], gm.btn_back[2] + n)

		if cursor_is_hovering(gm.btn_upgrade, 8, 8) then
			print("upgrade:$"..ent_tower_get_cost(game_unit_selected), gm.info[1], gm.info[2], 7)
		elseif cursor_is_hovering(gm.btn_delete, 8, 8) then
			print("delete unit", gm.info[1], gm.info[2], 7)
		elseif cursor_is_hovering(gm.btn_back, 8, 8) then
			print("exit", gm.info[1], gm.info[2], 7)
		end
	end
end

function sys_draw_road()
	local r
	for i = 1, #ent_road do
		r = ent_road[i]
		spr(r.sprite, r.x, r.y)
	end
end

function sys_draw_towers()
	local t
	for i = 1, #ent_tower do
		t = ent_tower[i]
		spr(t.sprite_current, t.x, t.y, 1, 1, t.sprite_flip, false)
		if t.selected == true then
			rect(t.x - 1, t.y - 1, t.x + 8, t.y + 8, 7)
		end
	end
end

function sys_initialize_road()
	local px1, py1, py1, py2
	for i = 1, #ent_path[game_level] - 1 do
		px1 = ent_path[game_level][i][1]
		py1 = ent_path[game_level][i][2]
		px2 = ent_path[game_level][i + 1][1]
		py2 = ent_path[game_level][i + 1][2]
		if px1 != px2 then
			for j = min(px1, px2), max(px1, px2), 8 do
				ent_road_create(j, py1, 1)
			end
		elseif py1 != py2 then
			for j = min(py1, py2), max(py1, py2), 8 do
				ent_road_create(px1, j, 1)
			end
		end
	end
end

function sys_get_cursor()
	--mouse coords
	game_cursor.x = stat(32)
	game_cursor.y = stat(33)

	local gc = game_cursor
	local closest_dist = 5
	local this_dist = 0
	local t
	gc.closest_unit = 0
	for i = 1, #ent_tower do
		t = ent_tower[i]
		--find the nearest unit
		if abs(t.x - gc.x < 4) and abs(t.y - gc.y < 4) then
			this_dist = distance_get(t.x, t.y, gc.x, gc.y)
			if this_dist < closest_dist then
				closest_dist = this_dist
				gc.closest_unit = i
			end
		end
	end
	-- units found near cursor
	if gc.closest_unit != 0 then
		gc.mode = 1
		if stat(34) == 1 then
			ent_tower[game_cursor.closest_unit].selected = true
			game_unit_selected = game_cursor.closest_unit
		end
	elseif gc.closest_unit == 0 then
		gc.mode = 0
		if stat(34) == 1 and not cursor_is_in_hud() then
			--clicking outside of the selected unit deselects it
			game_unit_selected = 0
			--game_menu_unit_reset()
		end
	end
end

function sys_get_hud()
	local gm = game_menu_unit
	if game_unit_selected != 0 then
		if stat(34) == 1 and gm.btn_pressed == 0 then
			if cursor_is_hovering(gm.btn_upgrade, 8, 8) then
				gm.btn_pressed = 1
				gm.btn_tmr = gm.btn_tm
			elseif cursor_is_hovering(gm.btn_delete, 8, 8) then
				gm.btn_pressed = 2
				gm.btn_tmr = gm.btn_tm
			elseif cursor_is_hovering(gm.btn_back, 8, 8) then
				gm.btn_pressed = 3
				game_unit_selected = 0
				gm.btn_tmr = gm.btn_tm
			end
		end
	end
end

-->8
--helper functions
function cursor_is_hovering(button, bw, bh)
	if (game_cursor.x + 4) > button[1] and (game_cursor.x + 4) < button[1] + bw
		and (game_cursor.y + 4) > button[2] and (game_cursor.y + 4) < button[2] + bh then
		return true
	else
		return false
	end
end

function cursor_is_in_hud()
	local gm =  game_menu_unit
	if (game_cursor.x + 4) > gm.bg[1] and (game_cursor.x + 4) < gm.bg[3]
		and (game_cursor.y + 4) > gm.bg[2] and (game_cursor.y + 4) < gm.bg[4] then
		return true
	else
		return false
	end
end
function distance_get(x1, y1, x2, y2)
	return sqrt((abs(x1 - x2) * 2) + (abs(y1 - y2)) * 2)
end

-->8
--main loop
function _init()
	palt(15, true)
	palt(0, false)
	--mouse control
	poke(0x5F2D, 1)

	sys_initialize_road()
	ent_tower_create(24, 32, 3)
	ent_tower_create(24, 40, 2)
	ent_tower_create(32, 96, 1)
	ent_tower_create(88, 24, 3)

	ent_enemy_create(16, 0, 1)
	ent_enemy_create(16, 24, 1)
	ent_enemy_create(16, 32, 1)
end

function _update()
	sys_get_cursor()
	sys_get_hud()
	sys_ai_towers()
	sys_ai_enemies()
	sys_ai_explosions()
	sys_animate_towers()
	sys_animate_enemies()
	sys_animate_hud()
	sys_delete_enemies()
	sys_delete_explosions()
	sys_delete_towers()
end

function _draw()
	cls()
	rectfill(0, 0, 128, 128, 5)
	spr(32, 24, 24)
	spr(32, 40, 32)
	spr(32, 32, 40)
	sys_draw_road()
	sys_draw_enemies()
	sys_draw_towers()
	sys_draw_explosions()
	sys_draw_hud()
	sys_draw_cursor()
end
__gfx__
00000000fffffffffffffffffffffffffffff00ffff00fffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000
00000000f0000ffffff00ffffff00ffffff00660ff0660ff00ffff00f00ff00fff0000fffff00ffffff00ffffff00fff00000000000000000000000000000000
00700700066690ffff0990ffff0990ffff099dd0ff0990ff020ff020f020020fff0220fffff00fffff0670ffff0770ff00000000000000000000000000000000
000770000ddd90fff06690ffff0660ffff099d0fff0990ff0d0000d0f0d00d0fff0dd0fffff00fffff0660ffff0770ff00000000000000000000000000000000
00077000f00990fff0dd90ffff0dd0ffff0990ffff0990ff0ddd0dd0f0dddd0fff0dd0fffff00fffff0dd0ffff0aa0ff00000000000000000000000000000000
00700700fff00ffffff00ffffff00ffffff00ffffff00ffff000000fff0000fffff00ffffff00ffffff00ffffff00fff00000000000000000000000000000000
00000000f099990ff099990ff099990ff099990ff099990ff099990ff099990ff099990ff099990ff009900ff009900f00000000000000000000000000000000
00000000090000900900009009000090090000900900009009000090090000900900009009000090099009900990099000000000000000000000000000000000
ffffffffffffffffffffffffffffffffffffff0ffff00fff00000000000000000000000000000000000000000000000000000000000000000000000000000000
ff0000ffffffffffffff000ffff00fffffff00d0ff0dd0ff00000000000000000000000000000000000000000000000000000000000000000000000000000000
f0eeee0f0000000ffff0000fff0000ffff000d50ff0dd0ff00000000000000000000000000000000000000000000000000000000000000000000000000000000
0e8888e00ddd000fff0dd00fff0000fff000050fff0000ff00000000000000000000000000000000000000000000000000000000000000000000000000000000
08288280f000000ff0dd50ffff0dd0fff00000ffff0000ff00000000000000000000000000000000000000000000000000000000000000000000000000000000
f002200ffff00ffff0550fffff0dd0ffff000fffff0000ff00000000000000000000000000000000000000000000000000000000000000000000000000000000
f020020fff0990ffff0990ffff0550ffff0990ffff0990ff00000000000000000000000000000000000000000000000000000000000000000000000000000000
ff0ff0fff090090ff090090ff090090ff090090ff090090f00000000000000000000000000000000000000000000000000000000000000000000000000000000
fff0ffffff000ffffffff0fffff77fff77ffff77ffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000
ff0d0fffff04000ff0fff0ffffffffff7ffffff7ffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000
ff0d50ffff04040ff0fff0fffff77ffffffffffffff3bffffefffefffff7ffff0000000000000000000000000000000000000000000000000000000000000000
f0dd50ffff04040ff0fff0ff7f7ff7f7ffffffffff333bffffef88ffff77ffff0000000000000000000000000000000000000000000000000000000000000000
f0d5550fff022220f0fff0ff7f7ff7f7fffffffff33ff3bffff8effff67766ff0000000000000000000000000000000000000000000000000000000000000000
0dd5d50ff0244440f0f000fffff77ffffffffffff3f3bf3fffff8effff67ff6f0000000000000000000000000000000000000000000000000000000000000000
0d5dd5500240404002002200ffffffff7ffffff7ff3ffbffff8ff8effff6ff7f0000000000000000000000000000000000000000000000000000000000000000
dddddd550444444004444440fff77fff77ffff77f3ffffbff8ffff8ffffff7ff0000000000000000000000000000000000000000000000000000000000000000
ffffffff11111111ffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000
ff0000ff11111111ff0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff0000ff00000000000000000000000000000000000000000000000000000000
f011110f11111111f0eeee0ff0eeee0ff0eeee0ff0eeee0ff0eeee0ff0eeee0ff0eeee0f00000000000000000000000000000000000000000000000000000000
01000010111dd1110e8888e00e8888e00e8888e00e8888e00e8888e00e8888e00e8888e000000000000000000000000000000000000000000000000000000000
10000001111dd1110828828008288280088288200882882008828820088888800888888000000000000000000000000000000000000000000000000000000000
f000000f11111111f002200ff002200ff000220ff000220ff000220ff022220ff022220f00000000000000000000000000000000000000000000000000000000
ff0000ff11111111f020080ff020020fff0800ffff8200ffff0200fff022220ff022220f00000000000000000000000000000000000000000000000000000000
ffffffff11111111fffff8fffffffffffff8ffffff8ffffffffff8ffff0fffffffffffff00000000000000000000000000000000000000000000000000000000
__sfx__
00010000154501b450134400e430084200341000410002000140009450144500b4500545000450004000240001400004000050000000000000100001000030000400003000000000100001000010000100003000
000100002b450244501c450184501345011450104500e4500b4500a450084500645004450014500045000450004000140001400014000142001450054500445002400044000c4000340001400004000040000400
000600001b03027030237001d1001f000250001900017000150001400012000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000600002703022030250000f000020000f0000f00017000150001400012000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
