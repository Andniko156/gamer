local run=require "game.run"
local bastion=require "game.bastion"
local art=require "game.bastion_enemies"
local data=require "game.data"
local dt=1/60

local s=run.new(1,647,1,4)
assert(s.x==bastion.start_x and #s.enemies==10)
local names={}
for row=0,2 do names[bastion.deck(row).props[2][1]]=true end
assert(names.crate_stack and names.engine_tank and names.helm_wheel)
for offset=-1,1 do
    local x=offset*bastion.period+bastion.width-24
    for _,y in ipairs({-118,0,118}) do
        assert(math.abs(bastion.move(x,y,104,0,10)-x-104)<1e-8)
        assert(math.abs(bastion.move(x+104,y,-104,0,10)-x)<1e-8)
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
assert(s.boss and math.abs(s.boss.hp-data.foes[6][1]*data.balance.boss_health)<1e-8)
print("Bastion: three decks, bidirectional seams, rear poses and 200 active + 185 reserve passed")
