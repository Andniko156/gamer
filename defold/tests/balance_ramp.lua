local run=require "game.run"
local data=require "game.data"
local dt=1/60

local function encounter(time,rank,evolved)
    local s=run.new(1,11,1,1)
    local u={kind=1,x=20,y=0,px=20,py=0,hp=10000,max_hp=10000,interval=9999,recover_until=9999}
    s.enemies={u}
    s.time,s.next_crate,s.next_spawn,s.elite_index=time,math.huge,math.huge,5
    s.weapon[1],s.cooldown[1],s.evolved[1]=rank or 0,9999,evolved
    s.shots={{x=0,y=0,px=0,py=0,vx=2000,vy=0,amount=100,pierce=1,hit={},life=1,weapon=1}}
    s.hazards={{kind="bomb",x=0,y=0,radius=30,at=time,damage=20}}
    run.step(s,dt,0,0)
    return 10000-u.hp,s.max_hp-s.hp
end

local function near(a,b) assert(math.abs(a-b)<1e-8) end
local early=data.balance.ramp_start-1
local late=data.balance.ramp_end
local weapon_damage=100*data.balance.weapon_damage_scale
local damage,hurt=encounter(early,6,true)
near(damage,weapon_damage)
near(hurt,20)
damage,hurt=encounter(late,6,true)
near(damage,weapon_damage*data.balance.weapon_damage_evolved)
near(hurt,20*data.balance.enemy_damage[2])
damage=encounter(late,6,false)
near(damage,weapon_damage*data.balance.weapon_damage_max_rank)
damage=encounter(late,1,false)
near(damage,weapon_damage)
for _,evolved in ipairs({false,true}) do
    for _,weapon in ipairs({3,4}) do
        local s=run.new(1,11,1,1)
        local u={kind=1,x=40,y=0,px=40,py=0,hp=10000,max_hp=10000,interval=9999}
        s.enemies,s.next_spawn={u},math.huge
        s.weapon[1],s.weapon[weapon],s.evolved[weapon]=0,6,evolved
        run.step(s,dt,0,0)
        local amount=evolved and (weapon==3 and 70 or 108) or 61
        if weapon==3 then amount=amount*.8 end
        near(s.damage[weapon],amount*data.balance.weapon_damage_scale)
    end
end
print("Balance ramp: early values, late pressure, base and evolved ranks passed")
