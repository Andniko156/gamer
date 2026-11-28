local art = require "game.dock_bosses"
local data = require "game.data"
local run = require "game.run"
local dt = 1/60

local overseer = assert(art.skin(1,6))
local clock = assert(art.skin(1,8,180))
assert(not art.skin(1,8) and not art.skin(2,6) and not art.skin(2,8,180))
assert(#overseer.attacks==#data.boss_patterns[1])
for i,pattern in ipairs(data.boss_patterns[1]) do assert(overseer.attacks[i]==pattern) end

local function check_png(id)
    local file = assert(io.open("art/dock_bosses/"..id..".png","rb"), id)
    assert(file:read(8)=="\137PNG\r\n\26\n")
    file:close()
end

local function check_frames(skin,unit,frames)
    check_png(frames.idle)
    for i,id in ipairs(frames.move) do
        check_png(id)
        assert(art.pose(skin,unit,(i-1+.25)/skin.hz)==id)
    end
    unit.px=unit.x
    assert(art.pose(skin,unit,1)==frames.idle)
    for _,pattern in ipairs(skin.attacks) do
        local keys = frames[pattern]
        for _,id in ipairs(keys) do check_png(id) end
        unit.pattern=pattern
        unit.warning_started,unit.warning=10,12
        assert(art.pose(skin,unit,10)==keys[1])
        assert(art.pose(skin,unit,11.5)==keys[2])
        unit.warning,unit.attack_until,unit.recover_until=nil,12.23,12.8
        assert(art.pose(skin,unit,12)==keys[3])
        assert(art.pose(skin,unit,12.3)==keys[4])
        assert(art.pose(skin,unit,12.8)==frames.idle)
        unit.attack_until,unit.recover_until=nil,nil
    end
end

for _,skin in ipairs({overseer,clock}) do
    check_frames(skin,{x=8,y=0,px=0,py=0},skin.front)
    check_frames(skin,{x=8,y=0,px=0,py=0,look_rear=true},skin.rear)
end

local function encounter(kind,pattern_index)
    local s=run.new(1,41,1,1)
    s.weapon={0,0,0,0,0,0,0,0}
    s.time,s.next_crate,s.next_spawn,s.elite_index,s.invincible=542,math.huge,math.huge,10,99
    local u={kind=kind,x=0,y=-86,px=0,py=-86,hp=100,max_hp=100,
        interval=0,pattern_index=pattern_index,elite=kind==8 and 180 or nil}
    s.enemies={u}
    s.boss=kind==6 and u or {hp=0}
    return s,u
end

local function check_impact(kind,index,pattern,expected_hazard)
    local s,u=encounter(kind,index)
    local skin=art.skin(1,kind,u.elite)
    run.step(s,dt,0,0)
    assert(u.warning and u.look_rear,"enemy should aim up toward the hero")
    assert(art.pose(skin,u,s.time)==skin.rear[pattern][1])
    s.time=u.warning-dt/2
    run.step(s,dt,0,0)
    assert(art.pose(skin,u,s.time)==skin.rear[pattern][3])
    assert(s.hazards[1] and s.hazards[1].kind==expected_hazard)
    s.time=u.attack_until
    assert(art.pose(skin,u,s.time)==skin.rear[pattern][4])
end

for i,pattern in ipairs(data.boss_patterns[1]) do
    check_impact(6,i-1,pattern,pattern=="floor" and "slam" or pattern)
end
check_impact(8,nil,"slow","slow")
print("Dock bosses: 60 PNG poses present; both facings, contact timing and five attack hazards verified")
