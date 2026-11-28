local run=require "game.run"
local bastion=require "game.bastion"
local art=require "game.bastion_enemies"
local data=require "game.data"
local dt=1/60

local s=run.new(1,647,1,4)
assert(s.x==bastion.start_x and #s.enemies==10)
assert(s.y==bastion.start_y and not bastion.blocked(s.x,s.y,10))
assert(#bastion.decks==3 and bastion.decks[2].art=="engine")
for i,deck in ipairs(bastion.decks) do
    assert(deck.bands[1]+deck.bands[2]+deck.bands[3]==bastion.base_height)
    local old_width=({207,189,193})[i]
    assert(math.abs(deck.near_edge-deck.far_edge-old_width*1.6)<1e-8)
    for _,prop in ipairs(deck.footprints) do
        local v=prop[2]
        if v>=deck.bands[1]+deck.bands[2] then v=v+deck.extension end
        assert(bastion.blocked(deck.x+prop[1],bastion.height/2-v,10))
    end
end
local stop=bastion.move(20,-47,bastion.end_x-40,0,10)
assert(math.abs(stop-bastion.end_x+20)<1e-7)
for section=1,#bastion.decks-1 do
    local deck=bastion.decks[section]
    local x=deck.x+deck.width-24
    for _,y in ipairs({-118,-40,-14}) do
        assert(math.abs(bastion.move(x,y,104,0,10)-x-104)<1e-8)
        assert(math.abs(bastion.move(x+104,y,-104,0,10)-x)<1e-8)
    end
end
local engine=bastion.decks[2]
local entry=engine.x+166
local _,wall=bastion.floor_edges(entry,10)
local x,y=bastion.move(entry,-70,0,240,10)
assert(x==entry and y<=wall-10 and y>wall-16)
local dx,dy=bastion.move(entry+12,-70,-12,240,10)
assert(math.abs(dx-entry)<1e-8 and dy<=wall-10 and not bastion.blocked(dx,dy,10))
local along,ay=bastion.move(x,y,6,0,10)
assert(along>x and ay==y)
for _,join in ipairs(bastion.joins) do
    local x=join.x+join.width/2
    local lower,upper=bastion.floor_edges(x,10)
    assert(bastion.blocked(x,upper-9,10) and bastion.blocked(x,lower+9,10))
    assert(not bastion.blocked(x,upper-10,10) and not bastion.blocked(x,lower+10,10))
    for _, direction in ipairs({-1,1}) do
        local ex,ey=x-85*direction,bastion.join_y
        local target=x+85*direction
        for _=1,160 do
            local tx,ty=bastion.route(ex,ey,target,bastion.join_y,8,0,0)
            local vx,vy=tx-ex,ty-ey
            local scale=math.min(1,2/math.max(.001,math.sqrt(vx*vx+vy*vy)))
            ex,ey=bastion.move(ex,ey,vx*scale,vy*scale,8)
            assert(not bastion.blocked(ex,ey,8))
        end
        assert(math.abs(ex-target)<1)
    end
end
for x=0,bastion.end_x,5 do
    for _,side in ipairs({-1,1}) do
        local lx,ly=bastion.floor_position(x,side*bastion.height/2,12)
        assert(not bastion.blocked(lx,ly,12))
    end
end
assert(bastion.move(24,0,-50,0,10)>=10)
assert(bastion.move(bastion.end_x-24,0,50,0,10)<=bastion.end_x-10)
for _,edge in ipairs({12,bastion.end_x-12}) do
    local side=run.new(1,911,1,4)
    side.x,side.px=edge,edge
    side.enemies={}
    side.weapon={}
    run.step(side,dt,0,0)
    assert(#side.enemies>=10)
    for _,u in ipairs(side.enemies) do
        assert(math.abs(u.x-edge)>data.viewport.width/2 or u.landing_y)
        assert(not bastion.blocked(u.x,u.landing_y or u.y,12))
    end
end
for _,kind in ipairs({1,10}) do
    local skin=art.skin(4,kind)
    local enemy={look_rear=true,sky_action_rear=true,sky_action_at=1}
    assert(art.pose(skin,enemy,1)=="bastion_"..kind.."_rear_"..skin.role.."_2")
end
for _,pattern in ipairs(data.boss_patterns[4]) do
    local skin=art.skin(4,6)
    local unit={look_rear=true,pattern=pattern,warning_started=10,warning=11.5}
    assert(art.pose(skin,unit,10.1)=="bastion_6_rear_"..pattern.."_0")
end

s.time=9*60+.5
s.elite_index,s.event_index=5,9
s.invincible=100
s.weapon={0,0,0,0,0,0,0,0}
run.step(s,dt,0,0)
assert(data.spawn_waves.combat_limit==200)
assert(#s.enemies==200 and #s.spawn_reserve==185)
assert(s.boss and math.abs(s.boss.hp-data.foes[6][1]*data.balance.boss_health*data.balance.enemy_health_scale)<1e-8)
print("Bastion: three decks, bidirectional seams, rear poses and 200 active + 185 reserve passed")
