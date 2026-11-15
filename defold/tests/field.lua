local run=require "game.run"
local dt=1/60
local function empty(arena)
    local s=run.new(1,19,1,arena)
    s.enemies={};s.next_spawn=math.huge;s.next_crate=math.huge
    return s
end
do
    local s=empty(1)
    s.time=35-dt
    s.next_crate=35
    run.step(s,dt,0,0)
    assert(#s.crates==1 and s.crates[1].expires>s.time)
    local c=s.crates[1]
    assert(math.abs(math.sqrt(c.x*c.x+c.y*c.y)-165)<0.01)
    s.next_crate=math.huge;s.time=c.expires
    run.step(s,dt,0,0)
    assert(#s.crates==0,"abandoned crates expire")
end
do
    local s=empty(1)
    s.hp=35;s.crates={{x=0,y=0,kind=1,expires=90}}
    run.step(s,dt,0,0)
    assert(s.hp==57 and #s.crates==0,"repair crate")
end
do
    local s=empty(1)
    s.loot={{kind="xp",x=400,y=0,xp=4},{kind="xp",x=700,y=0,xp=8},
        {kind="chest",x=100,y=0}}
    s.crates={{x=0,y=0,kind=2,expires=90}}
    run.step(s,dt,0,0)
    assert(s.xp==4 and s.loot[1].x==700 and s.loot[2].kind=="chest",
        "magnet takes nearby XP only and preserves distant drops and chests")
end
do
    local s=empty(1)
    s.crates={{x=0,y=0,kind=3,expires=90}}
    run.step(s,dt,0,0)
    assert(s.frozen_until>s.time+3 and #s.crates==0)
end
do
    local s=empty(2)
    s.x,s.y=140,140
    s.time=10.5
    assert(run.vent_state(s,s.x,s.y)=="warning")
    run.step(s,dt,0,0)
    assert(s.hp==s.max_hp,"warning cannot deal damage")
    s.time=11;s.invincible=0
    assert(run.vent_state(s,s.x,s.y)=="active")
    run.step(s,dt,0,0)
    assert(math.abs(s.hp-(s.max_hp-7.2))<0.001,"active vent deals one contact hit")
    run.step(s,dt,0,0)
    assert(math.abs(s.hp-(s.max_hp-7.2))<0.001,"invulnerability limits vent contact damage")
    s.x,s.y=220,140;s.invincible=0
    run.step(s,dt,0,0)
    assert(math.abs(s.hp-(s.max_hp-7.2))<0.001,"walking out of vent range avoids damage")
    assert(run.vent_state(empty(3),140,140)=="off")
end
print("Field checks passed: timed crates, three rewards, vent warnings, escape")
