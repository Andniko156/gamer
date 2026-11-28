local dock = require "game.dock_enemies"
local run = require "game.run"
local data = require "game.data"

local function check_png(id)
    local file = assert(io.open("art/dock_enemies/"..id..".png","rb"))
    assert(file:read(8) == "\137PNG\r\n\26\n")
    file:close()
end

local count = 0
for id,skin in pairs(dock.skins) do
    count = count + 1
    assert(data.arena_foes[1][id] and data.role_attack[data.foe_roles[1][id]])
    for i = 0,7 do
        check_png(skin[i])
        if skin.rear then check_png(skin.rear[i]) end
    end
    local unit = {x=2,y=0,px=1,py=0,gait_phase=0}
    for i = 0,3 do assert(dock.frame(skin,unit,(i+.1)/skin.hz) == i) end
    unit.warning_started,unit.warning = 4,5
    assert(dock.frame(skin,unit,4.1) == 4)
    assert(dock.frame(skin,unit,4.7) == 5)
    unit.warning,unit.attack_until,unit.recover_until = nil,5.23,5.5
    assert(dock.frame(skin,unit,5.1) == 6)
    assert(dock.frame(skin,unit,5.3) == 7)
end
assert(count == 8)

local dt = 1/60
local biped_count = 0
for id,skin in pairs(dock.skins) do
    if skin.rear then
        biped_count = biped_count + 1
        local pursuit = run.new(1,12,1,1)
        local u = {kind=id,x=0,y=0,px=0,py=0,hp=10000,max_hp=10000,interval=math.huge}
        pursuit.enemies,pursuit.weapon,pursuit.next_spawn = {u},{0,0,0,0,0,0,0,0},math.huge
        for _,corner in ipairs({{-60,-80,false,false},{60,-80,true,false},
            {-60,80,false,true},{60,80,true,true}}) do
            pursuit.x,pursuit.y = corner[1],corner[2]
            run.step(pursuit,dt,0,0)
            assert(u.look_right == corner[3] and u.look_rear == corner[4])
            local art,flip = dock.directional_sprite(skin,u,0)
            if u.look_rear then
                assert(art == skin.rear[0] and flip == u.look_right)
            else
                local points_right = skin.front_right == true
                assert(art == skin[0] and flip == (u.look_right ~= points_right))
            end
        end
        local facing_right = u.look_right
        u.warning_started,u.warning,u.dash_x,u.dash_y = pursuit.time,pursuit.time+1,1,1
        u.interval = pursuit.time+10
        u.target_x,u.target_y,u.attack_radius = pursuit.x,pursuit.y,20
        pursuit.x,pursuit.y = -60,-80
        run.step(pursuit,dt,0,0)
        assert(u.look_rear and u.look_right == facing_right,"windup must keep the original attack facing")
        u.warning,u.recover_until = nil,pursuit.time+1
        run.step(pursuit,dt,0,0)
        assert(u.look_rear and u.look_right == facing_right,"recovery must keep the original attack facing")
        u.recover_until = nil
        run.step(pursuit,dt,0,0)
        assert(not u.look_rear and not u.look_right,"pursuit must follow the hero after recovery")
    end
end
assert(biped_count == 4)

local s = run.new(1,12,1,1)
local turret = {kind=4,x=170,y=0,px=170,py=0,hp=10000,max_hp=10000,interval=0}
local drone = {kind=5,x=111,y=0,px=111,py=0,hp=10000,max_hp=10000,interval=0}
s.enemies,s.weapon,s.next_spawn = {turret,drone},{0,0,0,0,0,0,0,0},math.huge
for _ = 1,60 do run.step(s,dt,0,0) end
assert(turret.x == 170 and turret.y == 0 and #s.enemy_shots > 0)
assert(drone.dash_until and drone.x < 111)
print("Dock enemies: 96 PNG frames, four directional pursuits, locked attacks, stationary turret and diving drone passed")
