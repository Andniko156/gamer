local run = require "game.run"
local data = require "game.data"
local dt = 1/60
local disk_damage = 24*data.balance.weapon_damage_scale

local function arena(hero,kind,x,y,stage)
    local s=run.new(hero,5,1,stage)
    s.enemies,s.weapon={}, {0,0,0,0,0}
    s.next_spawn=math.huge
    if stage==4 then x,y=s.x+x,s.y+y end
    local u={kind=kind,x=x,y=y,px=x,py=y,hp=10000,max_hp=10000,interval=0}
    s.enemies={u}
    return s,u
end

-- A disk crossing between the old 0.32-second damage ticks must still hit.
do
    local s,u=arena(5,1,0,30)
    s.weapon[5]=1
    for _=1,15 do run.step(s,dt,0,0) end
    assert((s.damage[5] or 0)==disk_damage,"disk must hit once while sweeping past target")
    run.step(s,dt,0,0)
    assert(s.damage[5]==disk_damage,"contact must not apply damage every simulation tick")
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
    assert(amounts[1]==disk_damage and amounts[2]==2*disk_damage,"cooldown artifact must affect disk hits")
end

-- The slowest hero can leave a mortar's locked zone before impact.
do
    local s,u=arena(4,5,155,0,4)
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
    local s,u=arena(4,3,100,0)
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
    local s,u=arena(4,3,100,0)
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
-- The turret fires a projectile along the locked direction, allowing sidesteps.
do
    local s,u=arena(4,4,125,0)
    run.step(s,dt,0,0)
    local deadline=u.warning
    assert(deadline and u.dash_x==-1)
    while s.time<deadline+dt do run.step(s,dt,0,1) end
    assert(#s.enemy_shots==1 and s.enemy_shots[1].vx<0 and s.hp==s.max_hp)
end

-- Every arena boss cycles through its four documented attack families.
for stage=1,4 do
    local history={}
    for index,expected in ipairs(data.boss_patterns[stage]) do
        local s,u=arena(4,6,115,0,stage)
        u.y,u.py=s.y,s.y
        u.pattern_index,u.interval=index-1,0
        run.step(s,dt,0,0)
        assert(u.warning and u.pattern==expected and not history[u.pattern])
        history[u.pattern]=true
        s.time=u.warning-dt*.5
        run.step(s,dt,0,0)
        assert(not u.warning and u.attack_until>s.time)
        assert(#s.hazards+#s.enemy_shots>0)
    end
end

-- Each new weapon emits its attack effect. The evolved acid cloud spreads
-- to two visible zones which start dealing damage only after the spreading delay.
for weapon,kind in pairs({[6]="rail",[7]="pendulum",[8]="spray"}) do
    local s=arena(1,1,90,0)
    s.weapon={0,0,0,0,0,6,6,6}
    for i=6,8 do if i~=weapon then s.weapon[i]=0 end end
    s.evolved[weapon]=true
    run.step(s,dt,0,0)
    if weapon==8 then
        assert(s.effects[1].kind==kind and s.effects[2].kind==10)
        assert(s.effects[3].delay>0 and s.effects[4].delay>0)
    else
        assert(s.effects[1].kind==kind.."_evo")
    end
end

-- Crowds must not make weapon effects disappear when cosmetic debris fills
-- the old limit; even a starting shot should leave a visible muzzle flash.
do
    local s=arena(1,1,58,0)
    s.weapon[1]=1
    for i=1,25 do s.effects[i]={kind=11,life=.3,total=.3} end
    run.step(s,dt,0,0)
    assert(s.effects[26].kind=="rivet_flash")
    local opening=run.new(1,9)
    assert(opening.enemies[1].hp==data.foes[1][1]*data.balance.enemy_health_scale)
end
print("Combat checks passed: weapons, projectiles, locked telegraphs, boss cycles, recovery, inventory")
