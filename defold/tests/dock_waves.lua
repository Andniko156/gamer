local run = require "game.run"
local data = require "game.data"
local collision = require "game.dock_collision"
local config = data.spawn_waves
local dt = 1/60

local function unarmed(seed,arena,padding)
    local s=run.new(1,seed or 17,1,arena or 1,padding)
    s.weapon={0,0,0,0,0,0,0,0}
    s.invincible=1000
    return s
end

local function fighter(x,y)
    return {kind=2,x=x,y=y,px=x,py=y,hp=39,max_hp=39,interval=9999}
end

local s=unarmed()
assert(#s.enemies==10 and run.enemy_population(s)==10)
local side_edge=data.viewport.width/2+data.enemy_entry_padding
for _,unit in ipairs(s.enemies) do assert(math.abs(unit.x-s.x)>side_edge) end
local offscreen,visible=fighter(-340,0),fighter(-180,0)
s.enemies[1],s.enemies[2]=offscreen,visible
run.step(s,dt,1,0)
assert(offscreen.x-s.x>side_edge and offscreen.spawn_until>s.time)
assert(visible.x<s.x and not visible.spawn_until)
assert(#s.enemies==10 and s.spawned==10,"rally creates no enemies")

local minimums={10,15,23,34,51,76,114,171,257,385}
for arena=1,4 do
    s=unarmed(17,arena)
    for wave,minimum in ipairs(minimums) do
        s.time=(wave-1)*60
        run.step(s,dt,0,0)
        assert(run.enemy_population(s)==minimum,"arena "..arena..", wave "..wave.." minimum not reached")
        assert(#s.enemies>=math.min(minimum,config.combat_limit))
        local before=s.spawned
        for tick=1,80 do
            if tick%2==0 then
                s.enemies[1].hp=0
                s.enemies[2].hp=0
            end
            run.step(s,dt,.4,.1)
            assert(run.enemy_population(s)>=minimum,"casualties must be replaced on the same tick")
            -- Formations, elites and the boss are authored encounters above the ordinary cap.
            assert(#s.enemies<=config.combat_limit+(arena==1 and 4 or 22))
        end
        for _,unit in ipairs(s.enemies) do
            assert(unit.hp>0)
            if s.dock then assert(not collision.blocked(s.dock,unit.x,unit.y,collision.enemy_radius)) end
        end
        for _,unit in ipairs(s.spawn_reserve) do
            assert(unit.hp>0 and (unit.x-s.x)^2+(unit.y-s.y)^2>480^2,
                "reserve units stay beyond the active battle")
        end
        assert(s.spawned>before,"the minute does not limit total reinforcements")
    end
    assert(s.boss,"the boss appears at the start of minute ten even in a full horde")
end

s=unarmed()
s.time,s.elite_index=data.boss_at-.01,4
for i=1,config.combat_limit do s.enemies[i]=fighter(130+i,125) end
run.step(s,dt,0,0)
assert(s.boss and #s.enemies==config.combat_limit+1)
s.hazards={{kind="summon",at=s.time,unit=1,x=180,y=160}}
run.step(s,dt,0,0)
assert(#s.enemies==config.combat_limit+2 and run.enemy_population(s)>=minimums[10])

-- All ordinary reinforcements start out of view, including on wider displays.
local entrant
for seed=1,32 do
    s=unarmed(seed,1,{x=seed%2==0 and 80 or 0,y=48})
    s.x,s.y=collision.nearby_floor(s.dock,seed*13-220,seed*29-510,13)
    s.enemies={}
    run.step(s,dt,seed%2==0 and 1 or -1,0)
    assert(#s.enemies==config.initial)
    for _,unit in ipairs(s.enemies) do
        assert(math.abs(unit.x-s.x)>side_edge+s.view_padding.x)
        assert((unit.x-s.x)*(seed%2==0 and 1 or -1)>0)
        assert(not collision.blocked(s.dock,unit.x,unit.y,12))
    end
    entrant=s.enemies[1]
end
s.next_spawn=math.huge
s.enemies={entrant}
local entered=false
for _=1,600 do
    run.step(s,dt,0,0)
    assert(s.enemies[1]==entrant,"offscreen unit should approach as the same enemy")
    if math.abs(entrant.x-s.x)<data.viewport.width/2+s.view_padding.x then entered=true; break end
end
assert(entered,"offscreen unit should actually move into view")

-- Acid can kill after the ordinary movement pass. Its victim is also
-- replaced before the final presentation state for this tick.
s=unarmed()
local victim=s.enemies[1]
victim.hp=1
s.effects={{kind=10,x=victim.x,y=victim.y,r=10,life=1,tick=0}}
run.step(s,dt,0,0)
assert(s.kills==1 and #s.enemies==10)
for _,unit in ipairs(s.enemies) do assert(unit.hp>0) end

-- The train uses its longitudinal route. Other arenas use the side edges.
local function check_offscreen(s,unit)
    if s.alley or s.arena==3 then
        local dy=unit.y-s.y
        local edge=data.viewport.height*(dy<0 and data.viewport.hero_y or 1-data.viewport.hero_y)
        assert(math.abs(dy)>edge+s.view_padding.y+data.enemy_entry_padding)
        if s.arena==3 then assert(math.abs(unit.x)<=145) end
    else
        assert(math.abs(unit.x-s.x)>side_edge+s.view_padding.x)
    end
end
for arena=2,4 do
    local other=unarmed(17,arena,{x=24,y=93})
    assert(#other.enemies==10 and other.next_spawn==0 and #other.spawn_reserve==0)
    for _,unit in ipairs(other.enemies) do check_offscreen(other,unit) end
    local victim=table.remove(other.enemies)
    run.step(other,dt,0,0)
    assert(#other.enemies==10 and other.enemies[10]~=victim)
    check_offscreen(other,other.enemies[10])
end
print("Waves: minimum grows from 10 to 385, with immediate replacement and offscreen approaches on all arenas")
