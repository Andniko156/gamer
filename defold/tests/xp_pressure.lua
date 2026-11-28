local run=require "game.run"
local limit=190
local dt=1/60

local function fixture()
    local s=run.new(1,33,1,4)
    s.next_spawn,s.next_crate=math.huge,math.huge
    s.weapon={0,0,0,0,0,0,0,1}
    s.cooldown[8]=1000
    return s
end

local function kill(s,x,y)
    s.enemies={{kind=1,x=x,y=y,px=x,py=y,hp=1,max_hp=1,interval=1000}}
    s.effects={{kind=10,x=x,y=y,r=12,life=.1,tick=0}}
    run.step(s,dt,0,0)
end

local s=fixture()
for i=1,limit do s.loot[i]={kind="xp",x=s.x-400-i,y=0,xp=3} end
kill(s,s.x+150,0)
local total,near=0,0
for _,item in ipairs(s.loot) do
    total=total+item.xp
    if (item.x-s.x-150)^2+item.y^2<=40^2 then near=near+item.xp end
end
assert(#s.loot==limit and total==3*limit+2)
assert(near>0,"new XP remains near the kill when the field is saturated")
for _=1,220 do kill(s,s.x+150,0) end
total=0
for _,item in ipairs(s.loot) do total=total+item.xp end
assert(#s.loot==limit and total==3*limit+221*2)
s.x=s.x+150
s.need=1000
run.step(s,dt,0,0)
assert(s.xp==3+221*2 and #s.loot==limit-1)

s=fixture()
for i=1,limit-1 do s.loot[i]={kind="xp",x=s.x-400-i,y=0,xp=3} end
s.loot[limit]={kind="chest",x=s.x+200,y=0}
kill(s,s.x+150,0)
assert(#s.loot==limit+1 and s.loot[limit].kind=="chest")
assert(s.loot[limit+1].xp==2,"chests do not count against the XP capacity")
print("XP: local drops at capacity, full value after 221 kills, collection, and separate chest capacity")
