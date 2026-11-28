local art = require "game.dock_art"
local collision = require "game.dock_collision"
local run = require "game.run"
local spawn_waves = require("game.data").spawn_waves
local radius, dt = collision.hero_radius, 1/60
local seed = 41

local function empty_run()
    local s = run.new(1, seed, 1, 1)
    s.enemies, s.weapon = {}, {0,0,0,0,0,0,0,0}
    s.next_spawn, s.next_crate = math.huge, math.huge
    return s
end

local s = empty_run()
local map = s.dock
local pump, vent_col, vent_row
local sprites = {}
for col=-1,0 do for row=-1,0 do
    local sector = art.sector(map,col,row)
    art.draw_sector(map,col,row,function(id,x,y,_,_,layer)
        sprites[id] = layer
        if layer=="fixtures" or id=="drain_grate" or id=="steam_vent" then
            assert(collision.blocked(map,x,y-8,radius) == (layer=="fixtures"), id)
        end
        if id=="pump_station" then pump=sector end
    end)
    if sector.vent then vent_col,vent_row=col,row end
end end
for _,id in ipairs({"repair_marks","pump_marks","steam_marks","cargo_marks"}) do
    assert(sprites[id]=="inlays",id)
end
for _,id in ipairs({"workbench","breaker_cabinet","pump_station","tool_cart","crate_pallet"}) do
    assert(sprites[id]=="fixtures",id)
end
assert(not collision.blocked(map,0,0,radius))

local left = pump.cx-pump.w-radius
local x,y = collision.move(map,left-8,pump.cy,pump.w*2+30,0,radius)
assert(x > left-10 and x <= left and y == pump.cy)
x,y = collision.move(map,x,y,0,45,radius)
x,y = collision.move(map,x,y,pump.w*2+40,0,radius)
assert(x > pump.cx+pump.w and y == pump.cy+45)

-- The axes stay traversable far outside the original viewport.
x,y = collision.move(map,0,0,5800,0,radius)
assert(x > 5799.99 and y == 0)
x,y = collision.move(map,x,y,-11600,0,radius)
assert(x < -5799.99 and y == 0)
x,y = collision.move(map,0,0,0,-5800,radius)
assert(x == 0 and y < -5799.99)

local vent = art.sector(map,vent_col,vent_row)
local phase_offset = ((vent_col*7+vent_row*11)%4)*3
s.time = 22.5-phase_offset
assert(run.vent_state(s,vent.x,vent.y)=="warning")
s.time = 23-phase_offset
local state,wx,wy = run.vent_state(s,vent.x,vent.y)
assert(state=="active" and wx==vent.x and wy==vent.y)
assert(run.vent_state(s,pump.cx,pump.cy)=="off")
s.x,s.y = vent.x,vent.y
run.step(s,dt,0,0)
assert(s.hp < s.max_hp)

local opening = run.new(1,42,1,1)
assert(#opening.enemies == spawn_waves.initial)
for _,unit in ipairs(opening.enemies) do
    assert(not collision.blocked(opening.dock,unit.x,unit.y,12))
end
opening.time = 60 - dt/2
run.step(opening,dt,0,0)
assert(#opening.enemies == 15)

-- A chasing enemy goes around the pump instead of getting pinned at its edge.
local chase = empty_run()
chase.x,chase.y = pump.cx+pump.w+55,pump.cy
chase.px,chase.py = chase.x,chase.y
local ex = pump.cx-pump.w-55
local enemy = {kind=1,x=ex,y=pump.cy,px=ex,py=pump.cy,hp=35,max_hp=35,interval=99}
chase.enemies = {enemy}
for _ = 1,420 do
    run.step(chase,dt,0,0)
    assert(not collision.blocked(chase.dock,enemy.x,enemy.y,collision.enemy_radius))
end
assert(enemy.x > pump.cx+pump.w+15, string.format("enemy pinned at %.2f,%.2f",enemy.x,enemy.y))
print("Dock: grouped props, walkable drain, open passages, steam, spawns and enemy detours passed")
