local art = require "game.express_enemies"
local data = require "game.data"
local run = require "game.run"

local dt = 1/60
local center = require("game.express").height / 2
assert(data.arena_foes[3][6]=="Главный кочегар")
assert(not art.skin(1,6) and not art.skin(2,6) and not art.skin(4,6))
local atlas_file = assert(io.open("art/express_enemies.atlas"))
local atlas = atlas_file:read("*a")
atlas_file:close()
for kind=1,10 do
    local skin = assert(art.skin(3,kind))
    for _, facing in ipairs({"front","rear"}) do
        local frames = skin[facing]
        local unit = {look_rear=facing=="rear",x=0,y=10,px=0,py=0}
        for i=0,7 do
            local path = "art/express_enemies/"..frames[i]..".png"
            assert(atlas:find('"/'..path..'"',1,true))
            local file = assert(io.open(path,"rb"))
            assert(file:read(8)=="\137PNG\r\n\26\n")
            file:close()
            if i<4 then assert(art.pose(skin,unit,(i+.25)/skin.hz)==frames[i]) end
        end
        assert(art.pose(skin,unit)==frames[0])
        unit.py=10
        assert(art.pose(skin,unit,1)==frames[0])
        unit.warning_started,unit.warning=10,11
        assert(art.pose(skin,unit,10)==frames[4])
        assert(art.pose(skin,unit,10.8)==frames[5])
        unit.warning,unit.attack_until,unit.recover_until=nil,11.23,11.8
        assert(art.pose(skin,unit,11)==frames[6])
        assert(art.pose(skin,unit,11.3)==frames[7])
    end
end

local function encounter(kind, y, pattern_index)
    local state = run.new(1,41,1,3)
    state.weapon={0,0,0,0,0,0,0,0}
    state.time,state.next_crate,state.next_spawn,state.elite_index=542,math.huge,math.huge,10
    local foe = {kind=kind,x=0,y=y,px=0,py=y,hp=100,max_hp=100,interval=0,pattern_index=pattern_index}
    state.enemies={foe}
    state.boss=kind==6 and foe or {hp=0}
    return state,foe
end

for _, offset in ipairs({-65,65}) do
    for index, pattern in ipairs(data.boss_patterns[3]) do
        local s,u = encounter(6,center+offset,index-1)
        local skin = art.skin(3,6)
        run.step(s,dt,0,0)
        assert(u.warning and u.pattern==pattern and u.look_rear==(offset<0))
        local frames = u.look_rear and skin.rear or skin.front
        assert(art.pose(skin,u,s.time)==frames[4])
        s.time=u.warning-dt/2
        run.step(s,dt,0,0)
        if pattern=="cinders" then
            assert(#s.enemy_shots==3 and s.enemy_shots[1].kind=="cinders")
            assert(art.pose(skin,u,s.time)==frames[6])
        elseif pattern=="furnace" then
            assert(s.hazards[1].kind=="fire" and s.hazards[1].half_arc==.67)
            assert(art.pose(skin,u,s.time)==frames[6])
        else
            assert(s.hazards[1].kind==(pattern=="floor" and "slam" or "summon"))
            assert(art.pose(skin,u,s.time)==frames[4])
        end
    end
end

local s,rat = encounter(2,center-14)
run.step(s,dt,0,0)
assert(s.hp<s.max_hp and rat.attack_until>s.time)
assert(art.pose(art.skin(3,2),rat,s.time)=="express_2_rear_attack_2")
local repaired,repairer = encounter(5,center-52)
local ally = {kind=3,x=0,y=center-34,px=0,py=center-34,hp=60,max_hp=100,interval=999}
repaired.enemies[2]=ally
run.step(repaired,dt,0,0)
assert(ally.hp==72 and repairer.attack_until>repaired.time)
assert(art.pose(art.skin(3,5),repairer,repaired.time)=="express_5_rear_attack_2")
print("Express enemies: 160 atlas entries, front/rear animations, four boss patterns, rat bite and repair")
