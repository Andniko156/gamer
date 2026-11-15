local run = require "game.run"
local data = require "game.data"
local dt = 1/60

local function arena(hero,kind,x,y)
    local s=run.new(hero,5)
    s.enemies,s.weapon={}, {0,0,0,0,0}
    s.next_spawn=math.huge
    local u={kind=kind,x=x,y=y,px=x,py=y,hp=10000,max_hp=10000,interval=0}
    s.enemies={u}
    return s,u
end

-- A disk crossing between the old 0.32-second damage ticks must still hit.
do
    local s,u=arena(5,1,0,30)
    s.weapon[5]=1
    for _=1,15 do run.step(s,dt,0,0) end
    assert((s.damage[5] or 0)==24,"disk must hit once while sweeping past target")
    run.step(s,dt,0,0)
    assert(s.damage[5]==24,"contact must not apply damage every simulation tick")
end

-- Cooldown artifacts still accelerate repeat disk hits after the sweep fix.
do
    local amounts={}
    for _,rank in ipairs({0,5}) do
        local s=arena(5,3,0,0)
        s.weapon[5]=1;s.artifact[2]=rank
        for _=1,16 do run.step(s,dt,0,0) end
        amounts[#amounts+1]=s.damage[5]
    end
    assert(amounts[1]==24 and amounts[2]==48,"cooldown artifact must affect disk hits")
end

-- The slowest hero can leave a mortar's locked zone before impact.
do
    local s,u=arena(4,5,155,0)
    run.step(s,dt,0,0)
    local tx,ty,deadline=u.target_x,u.target_y,u.warning
    assert(deadline-s.time>=1.4)
    while s.time<deadline+dt do run.step(s,dt,0,1) end
    assert(u.target_x==tx and u.target_y==ty,"mortar must not track after warning")
    assert(s.hp==s.max_hp,"walking out of the warning should avoid damage")
    local x,y=u.x,u.y
    run.step(s,dt,0,0)
    assert(u.x==x and u.y==y,"mortar recovery must stop movement")
end

-- The target radius does not grow mid-warning when a boss becomes enraged.
do
    local s,u=arena(1,6,110,0)
    run.step(s,dt,0,0)
    assert(u.attack_radius==data.attacks.boss.radius)
    local deadline=u.warning
    u.hp=u.max_hp*0.4
    while s.time<deadline+dt do run.step(s,dt,0,0) end
    assert(s.hp==s.max_hp,"damage must match the radius shown at attack start")
    assert(u.attack_radius==96)
    u.interval=s.time
    s.time=u.recover_until+dt
    run.step(s,dt,0,0)
    assert(u.attack_radius==120,"the NEXT attack should use the enraged radius")
end

-- Ram direction stays locked; a slow hero can sidestep and punish recovery.
do
    local s,u=arena(4,4,100,0)
    run.step(s,dt,0,0)
    local dx,dy,deadline=u.dash_x,u.dash_y,u.warning
    while s.time<deadline+data.attacks.ram.duration+dt do run.step(s,dt,0,1) end
    assert(u.dash_x==dx and u.dash_y==dy)
    assert(s.hp==s.max_hp,"sidestepping a ram must avoid damage")
    local x,y=u.x,u.y
    run.step(s,dt,0,0)
    assert(u.x==x and u.y==y and not u.warning,"ram must recover before moving again")
end

-- Crowds cannot push a charging ram away from its shown attack origin.
do
    local s,u=arena(4,4,100,0)
    run.step(s,dt,0,0)
    local x,y=u.x,u.y
    s.enemies[2]={kind=3,x=x,y=y,px=x,py=y,hp=100,max_hp=100,interval=999}
    run.step(s,dt,0,0)
    assert(u.x==x and u.y==y)
end

-- Level choices respect full inventories, even when all their ranks are capped.
do
    local s=run.new(1,9)
    s.weapon={6,6,6,6,0,0,0,0};s.artifact={5,5,5,5,0,0,0,0,0}
    s.xp=s.need
    run.step(s,dt,0,0)
    assert(#s.options==1 and s.options[1]==18)
    assert(run.choose(s,18))
    assert(s.weapon[5]==0 and s.artifact[5]==0 and s.artifact[6]==0)
end
print("Combat checks passed: disk sweep, cooldown, fixed telegraphs, escape, recovery, slots")
