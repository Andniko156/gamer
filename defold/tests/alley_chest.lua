local run=require "game.run"
local alley=require "game.alley"
local dt=1/60

assert(math.abs(alley.wall*2-312*1.3)<.0001)
assert(math.abs(alley.road_edge*2-290*1.3)<.0001)

local house_sizes={}
for _,kind in ipairs({"workshop","pump","loading"}) do
    local png=assert(io.open("art/alley_buildings/house_"..kind..".png","rb"))
    local header=png:read(24)
    png:close()
    local function dimension(offset)
        local a,b,c,d=header:byte(offset,offset+3)
        return ((a*256+b)*256+c)*256+d
    end
    house_sizes[kind]={w=dimension(17),h=dimension(21)}
end

for seed=1,20 do
    local s=run.new(1,seed,1,2,{x=0,y=87})
    local map=s.alley
    for _,u in ipairs(s.enemies) do
        assert(math.abs(u.y)>540 and not alley.blocked(map,u.x,u.y,12))
    end
    for row=-12,12 do
        local section=alley.section(map,row)
        assert(section.houses[1].passage.south~=section.houses[2].passage.south)
        for i,house in ipairs(section.houses) do
            local next_house=alley.section(map,row+1).houses[i]
            local side,p=house.side,house.passage
            local gate_y=(p.south+p.north)*.5
            local image=house_sizes[house.kind]
            assert(house.w==image.w*.5 and house.h==image.h*.5 and house.front==side*alley.road_edge)
            assert(math.abs(house.front)+house.w>=p.stop-10+216,
                "the complete sprite reaches the far edge of the portrait viewport")
            assert(p.south==house.base+house.h and p.north==next_house.base)
            local lamp=house.lamp
            assert(lamp.y>p.south and lamp.y+60.3<p.north,"lamp silhouette fits between houses")
            assert(lamp.x*side+6<p.gate_depth-6,"lamp is clear of the gate")
            assert(lamp.variant==1 or lamp.variant==2)
            assert(not alley.blocked(map,0,lamp.y,10))
            for _,radius in ipairs({8,10}) do
                assert(alley.blocked(map,side*p.wall,house.base+house.h*.5,radius))
                local x=alley.move(map,(p.wall-26)*side,gate_y,90*side,0,radius)
                assert(side*x>p.wall and side*x<=p.stop-radius)
                assert(alley.blocked(map,side*p.gate_depth,gate_y,radius))
                for _,near_post in ipairs({p.south+radius+1,p.north-radius-1}) do
                    local dx,dy=alley.move(map,(p.wall-21)*side,gate_y,90*side,near_post-gate_y,radius)
                    assert(side*dx<=p.stop-radius and not alley.blocked(map,dx,dy,radius))
                    local out=alley.move(map,dx,dy,-80*side,0,radius)
                    assert(side*out<p.wall-26)
                end
            end
            if house.kind=="pump" then
                assert(section.vent_x==side*(alley.road_edge+40) and section.vent_y==house.base+13.5)
                local x=alley.nearby_floor(map,section.vent_x,section.vent_y,10)
                assert(math.abs(section.vent_x-x)<43)
            end
        end
        for _,x in ipairs({-169,0,169}) do
            local _,next_y=alley.move(map,x,section.y+200,0,150,10)
            assert(next_y>section.y+alley.height,"the street connects at every seam")
        end
    end
end

local function empty()
    local s=run.new(1,17,1,2)
    s.enemies,s.loot={},{}
    s.next_spawn,s.next_crate,s.invincible=math.huge,math.huge,1000
    return s
end

do
    local s=empty()
    s.weapon[7],s.artifact[8]=6,3
    s.xp=s.need
    s.loot={{x=0,y=0,kind="chest",evolves=true},{x=0,y=0,kind="chest",evolves=true}}
    run.step(s,dt,0,0)
    assert(s.mode=="chest" and s.chest_reward.id==7 and s.chest_reward.evolved)
    assert(not s.evolved[7] and #s.loot==1)
    local time=s.time
    run.step(s,1,0,0)
    assert(s.time==time and not s.evolved[7])
    assert(run.claim_chest(s) and s.evolved[7] and s.mode=="level" and s.level==2)
    assert(not run.claim_chest(s))
    assert(run.choose(s,s.options[1]))
    run.step(s,dt,0,0)
    assert(s.mode=="chest" and #s.loot==0 and not s.chest_reward.evolved)
    assert(run.claim_chest(s) and s.mode=="run")
end

do
    local s=empty()
    s.weapon[1]=1
    s.loot={{x=0,y=0,kind="chest"}}
    run.step(s,dt,0,0)
    assert(s.chest_reward.id==1 and not s.chest_reward.evolved and s.weapon[1]==1)
    assert(run.claim_chest(s) and s.weapon[1]==2 and not run.claim_chest(s))
    s.hp=20
    s.loot={{x=0,y=0,kind="chest"}}
    run.step(s,dt,0,0)
    assert(s.chest_reward.id==18 and s.hp==20)
    assert(run.claim_chest(s) and s.hp==50)
end

print("Alley and chest: continuous road, house ends, both gated recesses, offscreen spawning, paused rewards and one claim passed")
