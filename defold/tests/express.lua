local express=require "game.express"
local run=require "game.run"
local radius=10
local outside_opening=express.opening/2

assert(math.abs(express.width-405.6)<.001 and math.abs(express.height-403.2)<.001)
assert(express.scenery_speed==157.5)
for section=-3,3 do
    local origin=section*3600
    local previous_left,previous_right=0,0
    for progress=0,3599 do
        local index,left,right=express.scenery_blend(origin+progress-1800,0)
        assert(index==section and left>=right and right>=0 and left<=1)
        assert(left-previous_left>=0 and left-previous_left<.002)
        assert(right-previous_right>=0 and right-previous_right<.002)
        previous_left,previous_right=left,right
    end
    assert(previous_left==1 and previous_right>.99999)
end
assert(math.abs(express.opening/(76*express.width/272)-1.4)<.001)
for row=-8,8 do
    for t=0,80 do assert(math.abs(express.sway(t/10,row))<=3.051) end
end

for row=-8,8 do
    local low=row*express.period
    local high=low+express.height
    assert(not express.blocked(0,low,radius))
    assert(not express.blocked(0,high+14,radius))
    for _,side in ipairs({-1,1}) do
        local walk=side*(outside_opening-radius-5)
        local x,y=express.move(walk,high-25,0,78,radius)
        assert(x==walk and y>high+express.gap+24)
    end
    assert(#express.car(row).props>=6)
    for _,x in ipairs({-42,0,42}) do
        local _,y=express.move(x,low+1,0,express.period,radius)
        assert(y>low+express.period,"furnishings preserve a wide clear aisle")
    end
    assert(express.blocked(outside_opening,high+14,radius))
    assert(express.blocked(outside_opening,low+12,radius))
    local x,y=express.move(0,low+100,0,express.period,radius)
    assert(x==0 and math.abs(y-low-100-express.period)<.001)
    for _,solid in ipairs(express.car(row).solids) do
        assert(express.blocked((solid[1]+solid[2])/2,low+(solid[3]+solid[4])/2,radius))
    end
    for _,dy in ipairs({10,50,100,200,express.height-10,express.height+14}) do
        local x,y=express.floor_position(express.width/2,low+dy,radius)
        assert(not express.blocked(x,y,radius))
    end
end

local s=run.new(1,43,1,3)
for _,u in ipairs(s.enemies) do
    assert(not express.blocked(u.x,u.y,12))
end
s.enemies={}
s.next_spawn,s.next_crate,s.invincible=math.huge,math.huge,1000
for _=1,240 do run.step(s,1/60,0,1) end
assert(s.y>express.period+express.height/2 and not express.blocked(s.x,s.y,radius))
print("Express: clear gangways, blocked wall panels and props, safe spawns and player travel")
