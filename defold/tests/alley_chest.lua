local run=require "game.run"
local alley=require "game.alley"
local dt=1/60

for seed=1,20 do
    local s=run.new(1,seed,1,2,{x=0,y=87})
    local map=s.alley
    for _,u in ipairs(s.enemies) do
        assert(math.abs(u.y)>540 and not alley.blocked(map,u.x,u.y,12))
    end
    for row=-12,12 do
        local section=alley.section(map,row)
        local y=section.y+120
        assert(not alley.blocked(map,section.center,y,12))
        local x=alley.move(map,section.center,y,900,0,10)
        assert(x<=section.right-10 and not alley.blocked(map,x,y,10))
        if section.wide then
            local bypass=section.island+section.side*72
            local bx,by=alley.move(map,bypass,section.y+45,0,160,10)
            assert(bx==bypass and math.abs(by-(section.y+205))<.001,"arch has a complete bypass")
        end
        local next_section=alley.section(map,row+1)
        local mid=(section.center+next_section.center)*.5
        local _,next_y=alley.move(map,mid,section.y+200,0,85,10)
        assert(next_y>section.y+alley.height,"the street connects at every seam")
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

print("Alley and chest: floor, walls, seams, bypass, offscreen spawning, paused rewards and one claim passed")
