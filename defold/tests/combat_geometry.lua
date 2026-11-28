local run=require "game.run"
local data=require "game.data"
local express=require "game.express"
local dt=1/60

local function blank(arena,x,y,time)
    local s=run.new(1,17,1,arena)
    s.x,s.px,s.y,s.py=x,x,y,y
    s.time=time or 0
    s.enemies,s.loot={},{}
    s.weapon={0,0,0,0,0,0,0,0}
    s.next_spawn,s.next_crate=math.huge,math.huge
    return s
end

local function foe(x,y,hp,kind)
    return {kind=kind or 1,x=x,px=x,y=y,py=y,hp=hp,max_hp=hp,interval=9999,recover_until=9999}
end

local function fired(x,y,vx,vy,amount,pierce,weapon)
    return {x=x,px=x,y=y,py=y,vx=vx,vy=vy,amount=amount,pierce=pierce,hit={},life=1,weapon=weapon}
end

for _,direction in ipairs({1,-1}) do
    for _,x in ipairs({0,100}) do
        local y1,y2=express.height-45,express.period+45
        if direction<0 then y1,y2=y2,y1 end
        local s=blank(3,x,y1)
        local u=foe(x,y2,100)
        s.enemies={u}
        s.shots={fired(x,y1,0,direction*445,25,1,1)}
        s.enemy_shots={{x=x,y=y2,px=x,py=y2,vx=0,vy=-direction*265,radius=10,damage=20,life=1}}
        for _=1,42 do run.step(s,dt,0,0) end
        assert(u.hp==(x==0 and 75 or 100) and #s.shots==0,"hero shot must respect the end wall")
        assert(math.abs(s.hp-(x==0 and 100-20*data.balance.arena_damage[3]*data.balance.enemy_damage[1] or 100))<1e-6 and #s.enemy_shots==0,"enemy shot must respect the end wall")
    end
end

do
    local x,y=100,express.height-45
    local s=blank(3,x,y)
    local covered=foe(x,express.period+45,100)
    local open=foe(-25,y-40,100)
    -- Bring the covered target closer. Direct-fire weapons still aim at the
    -- farther visible enemy; the coil can jump to an enemy behind cover.
    open.x,open.px,open.y,open.py=-85,-85,y-45,y-45
    s.enemies={covered,open}
    s.weapon[1]=1
    run.step(s,dt,0,0)
    assert(#s.shots==1 and s.shots[1].vx<0 and s.shots[1].vy<0)
    s.weapon[1],s.weapon[2]=0,1
    run.step(s,dt,0,0)
    assert(covered.hp<100,"chain attacks keep their area rules")
end

do
    local s=blank(4,0,0)
    local a,b,c=foe(1,0,300),foe(4,7,10),foe(9,50,300)
    s.enemies={a,b,c}
    s.evolved[6]=true
    local p=fired(0,0,585,0,110,8,6)
    s.shots={p}
    run.step(s,dt,0,0)
    local arcs=0
    for _,e in ipairs(s.effects) do if e.kind==6 then arcs=arcs+1 end end
    assert(a.hp==190 and b.hp<=0 and c.hp==300 and p.pierce==7 and arcs==1)
end

local function saturated_cast(index)
    local s=blank(4,0,0,115)
    local boss=foe(130,0,3330,6)
    boss.recover_until=nil; boss.interval=0; boss.pattern_index=index-1
    s.enemies={boss}
    for i=1,38 do
        s.hazards[i]={x=500+i,y=100,radius=20,kind="shock",at=180}
        s.enemy_shots[i]={x=500+i,y=100,px=500+i,py=100,vx=0,vy=1,radius=10,damage=1,life=5}
    end
    run.step(s,dt,0,0)
    assert(boss.warning and boss.cast)
    local cast,deadline=boss.cast,boss.warning
    s.time=deadline-dt/2
    run.step(s,dt,0,0)
    assert(boss.attack_until>s.time and not boss.cast)
    return s,cast,deadline
end

do
    local s,cast,deadline=saturated_cast(2)
    assert(#cast.zones==3 and #s.hazards==41)
    for i,h in ipairs(cast.zones) do
        assert(s.hazards[38+i]==h and h.radius==34)
        assert(math.abs(h.at-deadline-(i==2 and .4 or .78))<1e-9)
        assert(h.order==(i==2 and 1 or 2))
    end
    s.time=deadline+.4-dt*1.1
    run.step(s,dt,0,0)
    assert(s.hp==s.max_hp)
    run.step(s,dt,0,0)
    local p=s.pressure
    local multipliers=data.balance.enemy_damage
    local damage=22*(multipliers[1]+(multipliers[2]-multipliers[1])*p)
    assert(math.abs(s.hp-(s.max_hp-damage))<1e-8)
end

do
    local s,cast=saturated_cast(1)
    assert(cast.volley.count==5 and #s.enemy_shots==43)
end

do
    local s=blank(1,0,0)
    s.weapon[5],s.evolved[5]=6,true
    for _,rank in ipairs({0,5}) do
        s.artifact[3]=rank
        local count,radius=run.disks(s)
        assert(count==3 and math.abs(radius-(rank==0 and 39 or 52.65))<1e-9)
        for i=1,count do
            local x,y=run.disk_offset(s.time,i,count,radius)
            assert(math.abs(x*x+y*y-radius*radius)<1e-9)
        end
    end
end
print("Combat geometry: two-way train cover, direct aim, chain damage, rail pierce, boss reserves and shared orbit passed")
