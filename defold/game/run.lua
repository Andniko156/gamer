local d = require "game.data"
local dock_art = require "game.dock_art"
local dock_collision = require "game.dock_collision"
local dock_enemies = require "game.dock_enemies"
local alley = require "game.alley"
local M = {}
local cos, sin, sqrt, floor, abs = math.cos, math.sin, math.sqrt, math.floor, math.abs
local min, max, ceil = math.min, math.max, math.ceil
local tau = 2 * math.pi
local separation = {}
for i,a in ipairs(d.foes) do
    separation[i]={}
    for j,b in ipairs(d.foes) do separation[i][j]=(a[4]+b[4])*.8 end
end

local function move_hero(s,x,y)
    if s.arena==1 then
        return dock_collision.move(s.dock,s.x,s.y,x-s.x,y-s.y,dock_collision.hero_radius)
    end
    if s.alley then return alley.move(s.alley,s.x,s.y,x-s.x,y-s.y,dock_collision.hero_radius) end
    if s.arena==3 then x=max(-140,min(140,x)) end
    if s.arena==4 then y=max(-155,min(155,y)) end
    return x,y
end

local function floor_position(s,x,y,radius)
    if s.dock then return dock_collision.nearby_floor(s.dock,x,y,radius) end
    if s.alley then return alley.nearby_floor(s.alley,x,y,radius) end
    return x,y
end

local function anchored(s,unit)
    return s.arena==1 and unit.kind==4
end

local function move_enemy(s,u,dx,dy)
    if anchored(s,u) then return end
    if s.arena==1 then
        local radius=dock_collision.enemy_radius
        u.x,u.y=dock_collision.move(s.dock,u.x,u.y,dx,dy,radius)
    elseif s.alley then
        u.x,u.y=alley.move(s.alley,u.x,u.y,dx,dy,dock_collision.enemy_radius)
    else
        u.x,u.y=u.x+dx,u.y+dy
    end
end

local function random(s)
    s.seed = s.seed * 48271 % 2147483647
    return s.seed / 2147483647
end

local function count(t)
    local n = 0
    for _, value in ipairs(t) do if value > 0 then n = n + 1 end end
    return n
end

local function face_target(arena,u,dx,dy)
    local skin=arena==1 and dock_enemies.skins[u.kind]
    if arena==1 and (u.kind==6 or skin and skin.rear) then dock_enemies.look_at(u,dx,dy) end
end

local function new_enemy(s, kind, x, y, elite)
    local stats = d.foes[kind]
    local hp = stats[1] * (kind == 6 and 1 or 1 + s.time / 770) * (elite and 2.5 or 1)
    return {kind=kind, x=x, y=y, hp=hp, elite=elite, max_hp=hp,
        interval=s.time+1.3+random(s)*1.6}
end

local function enter_battle(s, unit, x, y)
    x,y=floor_position(s,x,y,12)
    unit.x,unit.y,unit.px,unit.py=x,y,x,y
    unit.gait_phase=(x*.13+y*.07)%4
    face_target(s.arena,unit,s.x-x,s.y-y)
    s.enemies[#s.enemies+1]=unit
    return unit
end

local function spawn(s, kind, x, y, elite)
    return enter_battle(s,new_enemy(s,kind,x,y,elite),x,y)
end

local function ring_spawn(s, kind, distance, angle, elite)
    local x,y=s.x+distance*cos(angle),s.y+distance*sin(angle)
    if s.arena==3 then x=max(-145,min(145,x))
    elseif s.arena==4 then y=max(-165,min(165,y)) end
    return spawn(s, kind, x, y, elite)
end

local half_width=d.viewport.width/2
local lower_edge=d.viewport.height*d.viewport.hero_y
local upper_edge=d.viewport.height-lower_edge

local function wave_entry(s,kind,heading,order)
    local sideways,forward=cos(heading),sin(heading)
    local side=order%2==0 and -1 or 1
    local pad=s.view_padding
    local margin=d.enemy_entry_padding+8+random(s)*24
    if s.alley or s.arena==3 then
        -- Both corridors admit reinforcements through their far ends.
        if abs(forward)>.2 then side=forward<0 and -1 or 1 end
        local x=max(-145,min(145,s.x+sideways*42+(random(s)-.5)*230))
        local y=s.y+side*((side<0 and lower_edge or upper_edge)+pad.y+margin)
        return floor_position(s,x,y,12)
    end
    if s.dock and s.moving and abs(s.dir_x)>.5 then side=s.dir_x<0 and -1 or 1
    elseif not s.dock and abs(sideways)>.2 then side=sideways<0 and -1 or 1 end
    if s.dock and kind==4 then margin=margin-d.enemy_entry_padding+d.dock_spawn.turret_entry_padding end
    local x=s.x+side*(half_width+pad.x+margin)
    local y=s.y+forward*64+(random(s)-.5)*224
    if s.arena==4 then y=max(-165,min(165,y)) end
    if s.dock and dock_collision.blocked(s.dock,x,y,12) then
        -- An open sector boundary keeps the entry clear without pushing it into view.
        local tile=dock_art.size
        y=floor(y/tile+.5)*tile
    end
    return x,y
end

function M.new(hero, seed, doctrine, arena, view_padding)
    local hp = d.heroes[hero][3]
    arena=arena or 1
    local opening=d.spawn_waves.initial
    local s = {
        hero=hero, seed=seed % 2147483646 + 1, doctrine=doctrine or 1, hp=hp, max_hp=hp, time=0,
        x=0,y=0,px=0,py=0, dir_x=1,dir_y=0, wave=1, level=1,xp=0,need=16,kills=0,
        separation_grid={},free_buckets={},enemies={},shots={},enemy_shots={},hazards={},loot={},effects={},weapon={0,0,0,0,0,0,0,0}, artifact={0,0,0,0,0,0,0,0,0},
        evolved={},cooldown={0,0,0,0,0,0,0,0},damage={}, banned={}, rerolls=2, banishes=1,
        next_spawn=0, spawn_reserve={}, spawn_entries=0,
        elite_index=1,event_index=1, invincible=0, mode="run", slowed_until=0,
        arena=arena, view_padding=view_padding or {x=0,y=0},
        crates={}, next_crate=d.crates.first, frozen_until=0, spawned=opening,
    }
    if arena==1 then s.dock=dock_art.new(seed) end
    if arena==2 then s.alley=alley.new(seed) end
    s.weapon[hero]=1
    local angle=random(s)*tau
    for i=1,opening do
        local x,y=wave_entry(s,1,angle+i*tau/opening,i)
        spawn(s,1,x,y)
    end
    return s
end

local function hurt(s, amount)
    if s.invincible > 0 then return end
    s.hp = s.hp - amount * (s.hero==4 and 0.76 or 1) * (1-s.artifact[4]*0.07)
        * (s.arena==2 and 0.60 or s.arena==3 and 0.82 or 1)
        * (s.doctrine == 3 and 0.86 or s.doctrine == 2 and 1.10 or 1)
    s.invincible = 0.65
end

local function add_xp(s, x, y, xp)
    if #s.loot >= 190 then
        for _, item in ipairs(s.loot) do
            if item.kind=="xp" then item.xp=item.xp+xp; return end
        end
    end
    x,y=floor_position(s,x,y,4)
    s.loot[#s.loot+1]={x=x,y=y,kind="xp",xp=xp}
end

local function damage(s,u,amount,weapon)
    if u.hp <= 0 then return end
    local exposed=u.kind==6 and u.recover_until and u.recover_until>s.time
    local scaled=amount*(1+s.artifact[1]*0.08)*(s.hero==2 and 1.18 or 1)*(s.doctrine==2 and 1.12 or 1)
        *(exposed and 1.20 or 1)
    s.damage[weapon]=(s.damage[weapon] or 0)+min(u.hp,scaled)
    u.hp=u.hp-scaled
    u.flash=0.11
    if u.hp>0 then return end
    s.enemy_fell=true
    if #s.effects<25 then
        s.effects[#s.effects+1]={kind=11,x=u.x,y=u.y,r=u.kind==6 and 38 or 15,
            life=0.34,total=0.34,angle=random(s)*tau, foe=u.kind, elite=u.elite, facing_x=u.facing_x,
            look_right=u.look_right,look_rear=u.look_rear}
    end
    s.kills=s.kills+1
    local xp=math.ceil(d.foes[u.kind][5]*1.2)+(u.elite and 6 or 0)
    add_xp(s,u.x,u.y,xp)
    if u.elite or u.kind==6 or u.kind==10 then
        local x,y=floor_position(s,u.x,u.y,10)
        s.loot[#s.loot+1]={x=x,y=y,kind="chest",evolves=true}
    end
    if s.kills%31==0 and s.hp<s.max_hp then
        local x,y=floor_position(s,u.x+12,u.y,4)
        s.loot[#s.loot+1]={x=x,y=y,kind="heal"}
    end
end

local function wave_kind(s,roster)
    local kind=roster[1+floor(random(s)*#roster)]
    if s.time>=120 and random(s)<0.14 then kind=7 end
    if s.time>=240 and random(s)<0.10 then kind=8 end
    if s.time>=360 and random(s)<0.08 then kind=9 end
    return kind
end

local function rally_stragglers(s,heading,limit)
    if limit<=0 then return end
    local padding,margin=s.view_padding,d.enemy_entry_padding
    for _,u in ipairs(s.enemies) do
        local dx,dy=u.x-s.x,u.y-s.y
        local offscreen=abs(dx)>half_width+padding.x+margin
            or dy<-(lower_edge+padding.y+margin) or dy>upper_edge+padding.y+margin
        if offscreen and dx*s.dir_x+dy*s.dir_y< -60
            and u.hp>0 and not u.elite and not anchored(s,u) and u.kind~=6 and not u.warning and not u.spawn_until
            and (u.attack_until or 0)<=s.time and (u.dash_until or 0)<=s.time and (u.recover_until or 0)<=s.time
            and (u.rallied_until or 0)<=s.time then
            local x,y=wave_entry(s,u.kind,heading,limit+s.spawned)
            u.x,u.y,u.px,u.py=x,y,x,y
            u.route_until,u.route_x,u.route_field=nil,nil,nil
            u.spawn_until=s.time+d.spawn_waves.spawn_warmup
            u.rallied_until=s.time+4
            u.interval=max(u.interval,s.time+1.3)
            face_target(s.arena,u,s.x-x,s.y-y)
            limit=limit-1
            if limit==0 then return end
        end
    end
end

function M.enemy_population(s)
    return #s.enemies+#s.spawn_reserve
end

local function advance_outer_enemies(s)
    local config=d.spawn_waves
    for _,unit in ipairs(s.spawn_reserve) do
        local dx,dy=unit.x-s.x,unit.y-s.y
        local distance=sqrt(dx*dx+dy*dy)
        -- The reserve approaches until an active slot opens on the arena.
        local radius=max(config.outer_distance,min(840,distance-d.foes[unit.kind][2]*config.update_interval))
        if distance<.001 then dx,dy,distance=1,0,1 end
        unit.x,unit.y=s.x+dx*radius/distance,s.y+dy*radius/distance
    end
end

local function maintain_population(s)
    if s.next_spawn==math.huge or s.time>=d.duration or s.hp<=0 then return end
    if s.enemy_fell then
        -- Lingering weapon effects can kill enemies after the movement pass.
        for i=#s.enemies,1,-1 do
            if s.enemies[i].hp<=0 then table.remove(s.enemies,i) end
        end
        s.enemy_fell=false
    end
    local config=d.spawn_waves
    local target=ceil(config.initial*config.growth^(s.wave-1))
    local close_target=min(target,config.combat_limit)
    local vacancies=close_target-#s.enemies
    local scan=s.time>=s.next_spawn
    if scan then
        s.next_spawn=s.time+config.update_interval
        advance_outer_enemies(s)
    end
    if vacancies<=0 and not (scan and s.moving) and M.enemy_population(s)>=target then return end

    local near,turrets,drones=0,0,0
    for _,u in ipairs(s.enemies) do
        local reach=anchored(s,u) and 235 or config.nearby_range
        if (u.x-s.x)^2+(u.y-s.y)^2<=reach^2 then near=near+1 end
        if u.kind==4 then turrets=turrets+1 elseif u.kind==5 then drones=drones+1 end
    end
    local heading=s.moving and math.atan2(s.dir_y,s.dir_x) or random(s)*tau
    local roster=s.dock and s.wave==2 and d.dock_spawn.second_roster or d.waves[s.wave][4]
    local reserve=s.spawn_reserve
    for _=1,vacancies do
        local unit
        local last=#reserve
        if last>0 then
            local index=1+floor(random(s)*last)
            unit=reserve[index]
            reserve[index]=reserve[last]
            reserve[last]=nil
        end
        local kind=unit and unit.kind or wave_kind(s,roster)
        if s.wave==1 or kind==4 and turrets>=2 or kind==5 and drones>=3 then kind=1 end
        if kind==4 then turrets=turrets+1 elseif kind==5 then drones=drones+1 end
        local bearing=unit and not s.moving and math.atan2(unit.y-s.y,unit.x-s.x) or heading
        s.spawn_entries=s.spawn_entries+1
        local x,y=wave_entry(s,kind,bearing,s.spawn_entries)
        if unit then
            enter_battle(s,unit,x,y)
            unit.interval=s.time+1.3
        else
            unit=spawn(s,kind,x,y)
            s.spawned=s.spawned+1
        end
        unit.spawn_until=s.time+config.spawn_warmup
    end
    for _=M.enemy_population(s)+1,target do
        local angle=random(s)*tau
        local radius=config.outer_distance+60+random(s)*260
        local kind=wave_kind(s,roster)
        if kind==4 or kind==5 then kind=2 end
        reserve[#reserve+1]=new_enemy(s,kind,s.x+cos(angle)*radius,s.y+sin(angle)*radius)
        s.spawned=s.spawned+1
    end
    if scan and s.moving then
        rally_stragglers(s,heading,min(6,close_target-near-max(0,vacancies)))
    end
end

local function waves(s)
    s.wave=min(10,1+floor(s.time/60))
    local elite=d.elites[s.elite_index]
    if elite and s.time>=elite[1] then
        ring_spawn(s,elite[2],215,random(s)*tau,elite[1])
        s.elite_index=s.elite_index+1
        s.notice=d.arena_foes[s.arena][elite[2]].." несёт шкатулку"; s.notice_until=s.time+4
    end
    if s.time>=d.boss_at and not s.boss then
        s.boss=ring_spawn(s,6,175,random(s)*tau)
        s.notice=d.arena_foes[s.arena][6].." на арене"; s.notice_until=s.time+5
    end
    local event=d.events[s.event_index]
    if s.arena~=1 and event and s.time>=event[1] and not s.formation then
        s.formation={kind=s.event_index,x=s.x,y=s.y,angle=random(s)*tau,at=s.time+2.2}
        s.notice=event[2]; s.notice_until=s.time+4
    end
    local event_formation=s.formation
    if event_formation and s.time>=event_formation.at then
        local f=event_formation
        if f.kind%2==0 then
            for i=2,13 do
                local a=f.angle+i*tau/15
                local x,y=f.x+205*cos(a),f.y+205*sin(a)
                if s.arena==3 then x=max(-145,min(145,x)) elseif s.arena==4 then y=max(-165,min(165,y)) end
                spawn(s,(f.kind==4 and i%3==0) and 3 or 1,x,y)
            end
        else
            for line=0,(f.kind==3 and 1 or 0) do
                local a=f.angle+line*math.pi/2
                for i=-4,4 do
                    local x,y=f.x+255*cos(a)-i*25*sin(a),f.y+255*sin(a)+i*25*cos(a)
                    if s.arena==3 then x=max(-145,min(145,x)) elseif s.arena==4 then y=max(-165,min(165,y)) end
                    local u=spawn(s,2,x,y)
                    u.dash_x,u.dash_y,u.dash_until=-cos(a),-sin(a),s.time+3.8
                end
            end
        end
        s.formation=nil
        s.event_index=s.event_index+1
    end
end

local function field_crates(s,dt)
    if s.time>=s.next_crate then
        local angle=random(s)*tau
        local x,y=s.x+cos(angle)*d.crates.radius,s.y+sin(angle)*d.crates.radius
        x,y=floor_position(s,x,y,12)
        s.crates[#s.crates+1]={x=x,y=y,kind=1+floor(random(s)*3),
            expires=s.time+d.crates.lifetime}
        s.next_crate=s.next_crate+d.crates.interval
    end
    for i=#s.crates,1,-1 do
        local c=s.crates[i]
        if s.time>=c.expires then table.remove(s.crates,i)
        elseif (s.x-c.x)^2+(s.y-c.y)^2<24^2 and s.hp>0 then
            if c.kind==1 then
                s.hp=min(s.max_hp,s.hp+s.max_hp*0.22)
                s.notice="Ремкомплект · +22% здоровья"
            elseif c.kind==2 then
                for _,l in ipairs(s.loot) do
                    if l.kind=="xp" then
                        local dx,dy=l.x-s.x,l.y-s.y
                        if dx*dx+dy*dy<550^2 then l.x,l.y=s.x,s.y end
                    end
                end
                s.notice="Электромагнит · опыт рядом"
            else
                s.frozen_until=s.time+3.5
                s.notice="Холодный пар · враги замедлены"
            end
            s.notice_until=s.time+3
            table.remove(s.crates,i)
        end
    end
end

function M.vent_phase(time,offset)
    local cfg=d.vents
    local phase=(time+offset*3)%cfg.cycle
    return phase>=cfg.cycle-cfg.active and "active"
        or phase>=cfg.cycle-cfg.active-cfg.warning and "warning" or "idle"
end

function M.vent_state(s,x,y)
    if s.arena==1 then
        local col,row=floor(x/dock_art.size),floor(y/dock_art.size)
        local sector=dock_art.sector(s.dock,col,row)
        if not sector.vent then return "off" end
        return M.vent_phase(s.time,(col*7+row*11)%4),sector.x,sector.y
    end
    if not s.alley then return "off" end
    local row=floor(y/alley.height)
    local section=alley.section(s.alley,row)
    if not section.vent_x then return "off" end
    return M.vent_phase(s.time,row%4),section.vent_x,section.vent_y
end

local function vents(s)
    if s.arena~=1 and s.arena~=2 then return end
    local state,cx,cy=M.vent_state(s,s.x,s.y)
    if state=="active" and (s.x-cx)^2+(s.y-cy)^2<d.vents.radius^2 then
        hurt(s,s.arena==1 and 10 or 12)
    end
end

local function closest(s,x,y,radius,seen)
    local best,target=radius*radius,nil
    for _, u in ipairs(s.enemies) do
        local dx,dy=u.x-x,u.y-y
        local squared=dx*dx+dy*dy
        if u.hp>0 and squared<best and (not seen or not seen[u]) then target,best=u,squared end
    end
    return target
end

local function effect(s,k,x,y,r,angle)
    -- Cosmetic debris and concurrent acid zones must not suppress an attack.
    if k~="repair" or #s.effects<25 then
        local duration=(k==3 or k==7) and 0.46 or (k==4 or k==8) and 0.50
            or (k=="pendulum" or k=="pendulum_evo") and 0.48 or k=="spray" and 0.39 or 0.32
        s.effects[#s.effects+1]={kind=k,x=x,y=y,r=r,angle=angle or 0,
            life=duration,total=duration}
    end
end

function M.disks(s)
    local rank=s.weapon[5]
    if rank==0 then return 0,0 end
    return s.evolved[5] and 3 or rank>=3 and 2 or 1,
        (s.evolved[5] and 39 or rank>=2 and 35 or 30)*(1+s.artifact[3]*0.07)
end


local function attack(s,dt)
    for k, rank in ipairs(s.weapon) do
        s.cooldown[k]=s.cooldown[k]-dt
        if rank>0 and (k==5 or s.cooldown[k]<=0) then
            local area=(s.hero==3 and 1.22 or 1)*(1+s.artifact[3]*0.07)
            local evo=s.evolved[k]
            local target=closest(s,s.x,s.y,k==1 and 340 or 240*area)
            local recharge
            if k==1 and target then
                local a=math.atan2(target.y-s.y,target.x-s.x)
                effect(s,"rivet_flash",s.x,s.y,evo and 36 or 27,a)
                local amount=evo and 5 or rank>=4 and 3 or rank>=2 and 2 or 1
                for i=1,amount do
                    local aim=a+(i-(amount+1)/2)*0.12
                    s.shots[#s.shots+1]={x=s.x,y=s.y,px=s.x,py=s.y,vx=cos(aim)*445,vy=sin(aim)*445,
                        amount=evo and 54 or 21+rank*4,pierce=evo and 3 or rank>=5 and 2 or 1,hit={},life=0.78}
                end
                recharge=evo and 0.48 or rank>=3 and 0.66 or 0.74
            elseif k==2 and target then
                local used={}
                local x,y=s.x,s.y
                for _=1,evo and 7 or 2+floor(rank/2) do
                    if not target then break end
                    local dx,dy=target.x-x,target.y-y
                    effect(s,evo and 6 or 2,(x+target.x)/2,(y+target.y)/2,sqrt(dx*dx+dy*dy),math.atan2(dy,dx))
                    damage(s,target,evo and 64 or 20+rank*4,k)
                    used[target]=true
                    x,y=target.x,target.y
                    target=closest(s,x,y,108*area,used)
                end
                recharge=evo and 0.72 or 1.1-rank*0.026
            elseif (k==3 or k==4) and target then
                local radius=(evo and (k==3 and 175 or 155) or 76+rank*9)*area
                local dx,dy=target.x-s.x,target.y-s.y
                local aim=math.atan2(dy,dx)
                if dx*dx+dy*dy<=radius*radius then
                    if k==3 and dx*s.dir_x+dy*s.dir_y>sqrt(dx*dx+dy*dy)*0.7 then
                        aim=math.atan2(s.dir_y,s.dir_x)
                    end
                    local threshold=cos(evo and 1.42 or 0.85)
                    for _,u in ipairs(s.enemies) do
                        local ux,uy=u.x-s.x,u.y-s.y
                        local range=sqrt(ux*ux+uy*uy)
                        if u.hp>0 and range<=radius and (k==4 or ux*cos(aim)+uy*sin(aim)>=range*threshold) then
                            damage(s,u,evo and (k==3 and 70 or 108) or 25+rank*6,k)
                            if not u.elite and u.kind~=6 and rank>=4 then
                                if k==3 then u.slow_until=s.time+0.38
                                elseif range>0.01 and not u.warning then
                                    local force=evo and 34 or 13
                                    move_enemy(s,u,ux/range*force,uy/range*force)
                                end
                            end
                        end
                    end
                    effect(s,evo and k+4 or k,s.x,s.y,radius,aim)
                    recharge=evo and 0.64 or 1.07-rank*0.026
                end
            elseif k==5 then
                local amount,radius=M.disks(s)
                for i=1,amount do
                    local a=s.time*5+i*tau/amount
                    local x,y=s.x+cos(a)*radius,s.y+sin(a)*radius
                    local previous=(s.time-dt)*5+i*tau/amount
                    local px,py=s.px+cos(previous)*radius,s.py+sin(previous)*radius
                    local vx,vy=x-px,y-py
                    for _,u in ipairs(s.enemies) do
                        local dx,dy=u.x-px,u.y-py
                        local t=max(0,min(1,(dx*vx+dy*vy)/max(0.0001,vx*vx+vy*vy)))
                        if (not u.disk_hit_at or s.time>=u.disk_hit_at)
                            and (dx-vx*t)^2+(dy-vy*t)^2<(d.foes[u.kind][4]+(evo and 22 or 16)*area)^2 then
                            damage(s,u,evo and 49 or 20+rank*4,k)
                            u.disk_hit_at=s.time+(evo and 0.22 or 0.32)*(1-s.artifact[2]*0.06)
                        end
                    end
                end
                recharge=evo and 0.22 or 0.32
            elseif k==6 and target then
                local a=math.atan2(target.y-s.y,target.x-s.x)
                s.shots[#s.shots+1]={x=s.x,y=s.y,px=s.x,py=s.y,vx=cos(a)*585,vy=sin(a)*585,
                    amount=evo and 110 or 39+rank*10,
                    pierce=(evo and 8 or 2+floor(rank/2))+floor(s.artifact[7]/2),
                    hit={},life=0.82,weapon=6}
                effect(s,evo and "rail_evo" or "rail",s.x,s.y,32,a)
                recharge=evo and 1.35 or 1.85-rank*0.10
            elseif k==7 and target then
                local radius=(evo and 145 or 70+rank*9)*area
                for _,u in ipairs(s.enemies) do
                    if u.hp>0 and (u.x-s.x)^2+(u.y-s.y)^2<radius*radius then
                        damage(s,u,evo and 78 or 27+rank*8,k)
                        if u.kind~=6 then u.slow_until=s.time+0.65 end
                    end
                end
                local angle=math.atan2(target.y-s.y,target.x-s.x)
                effect(s,evo and "pendulum_evo" or "pendulum",s.x,s.y,radius,angle)
                recharge=(evo and 1.15 or 2.15-rank*0.12)*(1-s.artifact[8]*0.05)
            elseif k==8 and target then
                local radius=evo and 82 or 45+rank*5
                local angle=math.atan2(target.y-s.y,target.x-s.x)
                effect(s,"spray",s.x,s.y,min(115,sqrt((target.x-s.x)^2+(target.y-s.y)^2)),angle)
                local life=(evo and 4.5 or 2.4+rank*0.3)*(1+s.artifact[9]*0.09)
                s.effects[#s.effects+1]={kind=10,x=target.x,y=target.y,r=radius,
                    life=life,total=life,tick=0,evolved=evo}
                if evo then
                    for i=-1,1,2 do
                        local a=angle+i*0.85
                        s.effects[#s.effects+1]={kind=10,x=target.x+cos(a)*radius*.8,
                            y=target.y+sin(a)*radius*.8,r=radius*.59,life=life,
                            total=life,tick=0,evolved=true,delay=0.65}
                    end
                end
                recharge=evo and 2.1 or 3.1-rank*0.12
            end
            if recharge then s.cooldown[k]=recharge*(1-s.artifact[2]*0.06) end
        end
    end
end

local function shots(s,dt)
    for i=#s.shots,1,-1 do
        local p=s.shots[i]
        p.px,p.py=p.x,p.y
        local dx,dy=p.vx*dt,p.vy*dt
        p.x,p.y,p.life=p.x+dx,p.y+dy,p.life-dt
        local candidates={}
        for _,u in ipairs(s.enemies) do
            if u.hp>0 and not p.hit[u] then
                local ux,uy=u.x-p.px,u.y-p.py
                local f=max(0,min(1,(ux*dx+uy*dy)/(dx*dx+dy*dy)))
                if (ux-dx*f)^2+(uy-dy*f)^2<(d.foes[u.kind][4]+3)^2 then
                    candidates[#candidates+1]={f=f,u=u}
                end
            end
        end
        table.sort(candidates,function(a,b) return a.f<b.f end)
        for _, hit in ipairs(candidates) do
            damage(s,hit.u,p.amount,p.weapon or 1)
            if p.weapon==6 and s.evolved[6] then
                local other=closest(s,hit.u.x,hit.u.y,90,{[hit.u]=true})
                if other then
                    local dx,dy=other.x-hit.u.x,other.y-hit.u.y
                    damage(s,other,p.amount*0.35*(1+s.artifact[7]*0.10),6)
                    effect(s,6,(hit.u.x+other.x)/2,(hit.u.y+other.y)/2,sqrt(dx*dx+dy*dy),math.atan2(dy,dx))
                end
            end
            p.hit[hit.u]=true
            p.pierce=p.pierce-1
            if p.pierce==0 then break end
        end
        if p.pierce==0 or p.life<=0 then table.remove(s.shots,i) end
    end
end

local function arena_position(s,x,y)
    if s.arena==3 then x=max(-140,min(140,x)) end
    if s.arena==4 then y=max(-155,min(155,y)) end
    return x,y
end

local function hazard(s,kind,x,y,radius,delay,damage,options)
    if #s.hazards>=38 then return end
    local h=options or {}
    h.kind,h.x,h.y,h.radius=kind,x,y,radius
    h.start,h.at,h.damage=s.time,s.time+delay,damage
    s.hazards[#s.hazards+1]=h
end

local function shot(s,kind,x,y,angle,speed,width,damage,life)
    if #s.enemy_shots>=38 then return end
    s.enemy_shots[#s.enemy_shots+1]={kind=kind,x=x,y=y,px=x,py=y,
        vx=cos(angle)*speed,vy=sin(angle)*speed,radius=width,damage=damage,life=life}
end

local function spread(s,kind,x,y,angle,count,spacing,speed,width,damage)
    for i=1,count do
        shot(s,kind,x,y,angle+(i-(count+1)*.5)*spacing,speed,width,damage,1.1)
    end
end

local function summon_warning(s,x,y,angle,amount,owner,kind)
    for i=1,amount do
        local a=angle+(i-1)*tau/amount
        local sx,sy=arena_position(s,x+cos(a)*69,y+sin(a)*69)
        if s.arena==1 then sx,sy=dock_collision.nearby_floor(s.dock,sx,sy,12) end
        hazard(s,"summon",sx,sy,16,.85,0,{owner=owner, unit=kind or (s.arena==2 and 10 or 1)})
    end
end

local function boss_attack(s,u,enraged)
    local kind=u.pattern
    local a=math.atan2(u.dash_y,u.dash_x)
    local x,y=u.target_x,u.target_y
    if kind=="reactor" then
        hazard(s,"reactor",x,y,u.attack_radius,0,36,{owner=u})
    elseif kind=="disc" then
        hazard(s,"disc",x,y,u.attack_radius,0,30,{angle=a,half_arc=.92,owner=u})
    elseif kind=="floor" or kind=="bombs" or kind=="combo" then
        for i=1,kind=="combo" and 4 or 3 do
            local offset=(i-1)*30
            local sx,sy=arena_position(s,x+cos(a)*offset,y+sin(a)*offset)
            hazard(s,kind=="bombs" and "bomb" or "slam",sx,sy,33,.45+(i-1)*.34,
                enraged and 29 or 23,{owner=u})
        end
        if kind=="combo" then spread(s,"arc",u.x,u.y,a,3,.27,255,10,18) end
    elseif kind=="summon" then
        summon_warning(s,u.x,u.y,a,enraged and 4 or 3,u)
    elseif kind=="arc" or kind=="rail" then
        spread(s,kind,u.x,u.y,a,kind=="rail" and 3 or 5,kind=="rail" and .14 or .30,300,11,24)
    elseif kind=="rotor" then
        hazard(s,"rotor",x,y,43,.45,17,{owner=u, dx=cos(a),dy=sin(a), duration=2.25})
    elseif kind=="furnace" then
        hazard(s,"fire",x,y,u.attack_radius,0,32,{angle=a,half_arc=.67,owner=u,duration=.6})
    elseif kind=="storm" then
        for i=-1,1 do
            local sx,sy=arena_position(s,x+cos(a+math.pi*.5)*i*62,y+sin(a+math.pi*.5)*i*62)
            hazard(s,"shock",sx,sy,34,.4+abs(i)*.38,22,{owner=u})
        end
    end
end

local function bosses(s,u,distance,ux,uy,enraged)
    if u.warning then
        if s.time<u.warning then return end
        u.warning=nil
        boss_attack(s,u,enraged)
        u.attack_until,u.recover_until=s.time+.23,s.time+.8
    elseif u.interval<=s.time and distance<260 then
        local patterns=d.boss_patterns[s.arena]
        local index=(u.pattern_index or 0)%#patterns+1
        u.pattern_index,u.pattern=index,patterns[index]
        u.warning_started,u.warning=s.time,s.time+(enraged and 1.25 or 1.55)
        u.interval=s.time+(enraged and 4.4 or 5.3)
        local close=u.pattern=="reactor" or u.pattern=="disc" or u.pattern=="furnace" or u.pattern=="summon"
        u.target_x,u.target_y=close and u.x or s.x,close and u.y or s.y
        u.attack_radius=enraged and d.attacks.boss.enraged_radius or d.attacks.boss.radius
        u.dash_x,u.dash_y=ux,uy
    end
end

local function enemy_move(s,u,dt)
    local stats=d.foes[u.kind]
    local role=d.foe_roles[s.arena][u.kind]
    local dx,dy=s.x-u.x,s.y-u.y
    local distance=sqrt(dx*dx+dy*dy)
    local ux,uy=dx/max(.001,distance),dy/max(.001,distance)
    local speed=stats[2]*(u.slow_until and u.slow_until>s.time and .66 or 1)
        *(s.frozen_until>s.time and .35 or 1)
    local enraged=role=="boss" and u.hp<u.max_hp*.45
    if enraged then speed=speed*1.24 end
    local recovering=u.recover_until and s.time<u.recover_until
    local dashing=u.dash_until and s.time<u.dash_until
    local attack=d.role_attack[role]
    if not u.warning and not recovering and not dashing then face_target(s.arena,u,dx,dy) end
    if dashing then
        local dash_speed=attack and attack.dash and d.attacks.ram.speed or 118
        move_enemy(s,u,u.dash_x*dt*dash_speed,u.dash_y*dt*dash_speed)
    elseif not anchored(s,u) and not u.warning and not recovering and not u.spawn_until then
        local stand=role=="steam" or role=="bomb" or role=="turret" or role=="volley"
        local flank=(role=="flank" or role=="flank_volley") and distance<165 and distance>38 and .68 or 0
        if distance>(stand and 155 or stats[4]+5) then
            local sx,sy=u.x,u.y
            if s.alley then
                local tx,ty=alley.route(s.alley,u.x,u.y,s.x,s.y)
                local dx,dy=tx-u.x,ty-u.y
                local scale=min(1,dt*speed/max(.001,sqrt(dx*dx+dy*dy)))
                move_enemy(s,u,dx*scale,dy*scale)
            elseif u.route_until and u.route_until>s.time then
                local tx,ty=dock_collision.route(s,u)
                local dx,dy=tx-u.x,ty-u.y
                local length=sqrt(dx*dx+dy*dy)
                local scale=min(1,dt*speed/max(.001,length))
                move_enemy(s,u,dx*scale,dy*scale)
                if (u.x-sx)^2+(u.y-sy)^2<.001 then u.route_x=nil end
                if length>3 then u.route_until=s.time+.35 end
            else
                move_enemy(s,u,(ux-uy*flank)*dt*speed,(uy+ux*flank)*dt*speed)
            end
            if s.arena==1 and (u.x-sx)^2+(u.y-sy)^2<(dt*speed*.65)^2
                and (not u.route_until or u.route_until<=s.time) then
                u.route_until=s.time+.9
            end
        end
    end
    local moved_x=u.x-u.px
    if abs(moved_x)>.04 then u.facing_x=moved_x end
    if not u.spawn_until then
        if dashing and attack and attack.dash then
            local mx,my=u.x-u.px,u.y-u.py
            local dx,dy=s.x-u.px,s.y-u.py
            local f=max(0,min(1,(dx*mx+dy*my)/max(.0001,mx*mx+my*my)))
            if (dx-mx*f)^2+(dy-my*f)^2<(attack.width+6)^2 then hurt(s,attack.damage) end
        elseif (dashing or not attack) and distance<(stats[4]+8) then hurt(s,stats[3]) end
    end
    if u.flash then u.flash=max(0,u.flash-dt) end
    if u.spawn_until and s.time>=u.spawn_until then u.spawn_until=nil end
    if dashing or recovering or u.spawn_until then return end
    if role=="boss" then
        bosses(s,u,distance,ux,uy,enraged)
    elseif role=="repair" and u.interval<=s.time then
        u.interval=s.time+4.5
        for _,v in ipairs(s.enemies) do
            if v~=u and v.hp>0 and v.hp<v.max_hp and (v.x-u.x)^2+(v.y-u.y)^2<95^2 then
                v.hp=min(v.max_hp,v.hp+v.max_hp*.12)
                local dx,dy=v.x-u.x,v.y-u.y
                effect(s,"repair",(u.x+v.x)*.5,(u.y+v.y)*.5,sqrt(dx*dx+dy*dy),math.atan2(dy,dx))
                u.attack_until=s.time+.23
                break
            end
        end
    elseif role=="summon" and distance<215 and u.interval<=s.time then
        u.interval=s.time+9
        u.attack_until=s.time+.23
        summon_warning(s,u.x,u.y,math.atan2(uy,ux),2,u,s.arena==1 and 4 or 10)
    elseif attack and u.warning and s.time>=u.warning then
        u.warning=nil
        u.attack_until,u.recover_until=s.time+.23,s.time+attack.recovery
        if attack.dash then
            u.dash_until=s.time+d.attacks.ram.duration
            u.recover_until=u.dash_until+attack.recovery
        elseif attack.shots then
            spread(s,role,u.x,u.y,math.atan2(u.dash_y,u.dash_x),attack.shots,.24,265,attack.width,attack.damage)
        else
            hazard(s,role,u.target_x,u.target_y,attack.radius,0,attack.damage,
                {owner=u, duration=(role=="slow" or role=="magnet") and 1.1 or nil})
        end
    elseif attack and not u.warning and u.interval<=s.time and distance<attack.range then
        u.interval=s.time+attack.repeat_after
        u.warning_started,u.warning=s.time,s.time+attack.windup
        u.dash_x,u.dash_y=ux,uy
        local reach=(role=="guard" or role=="bite") and 18 or s.arena==1 and role=="slam" and 26
        u.target_x,u.target_y=reach and u.x+ux*reach or s.x,reach and u.y+uy*reach or s.y
        u.attack_radius=attack.radius
    end
end

local function enemy_attacks(s,dt)
    for i=#s.enemy_shots,1,-1 do
        local p=s.enemy_shots[i]
        p.px,p.py=p.x,p.y
        local dx,dy=p.vx*dt,p.vy*dt
        p.x,p.y,p.life=p.x+dx,p.y+dy,p.life-dt
        local ox,oy=s.x-p.px,s.y-p.py
        local f=max(0,min(1,(ox*dx+oy*dy)/max(.0001,dx*dx+dy*dy)))
        if (ox-dx*f)^2+(oy-dy*f)^2<(p.radius+6)^2 then
            hurt(s,p.damage)
            table.remove(s.enemy_shots,i)
        elseif p.life<=0 then table.remove(s.enemy_shots,i) end
    end
    for i=#s.hazards,1,-1 do
        local h=s.hazards[i]
        if s.time>=h.at then
            local age=s.time-h.at
            local duration=h.duration or .28
            if age>=duration or (h.owner and h.owner.hp<=0 and not h.fired) then
                table.remove(s.hazards,i)
            elseif h.kind=="summon" then
                local limit=d.spawn_waves.combat_limit+4
                if not h.fired and #s.enemies<limit then
                    local unit=spawn(s,h.unit,h.x,h.y)
                    unit.spawn_until=s.time+.26
                    s.spawned=s.spawned+1
                end
                h.fired=true
            else
                if h.dx then
                    h.x,h.y=arena_position(s,h.x+h.dx*dt*62,h.y+h.dy*dt*62)
                end
                local dx,dy=s.x-h.x,s.y-h.y
                local range=sqrt(dx*dx+dy*dy)
                local in_sector=not h.half_arc or dx*cos(h.angle)+dy*sin(h.angle)>=range*cos(h.half_arc)
                if range<h.radius and in_sector and (h.duration or not h.fired) then
                    if h.kind=="slow" then s.slowed_until=max(s.slowed_until,s.time+.35)
                    elseif h.kind=="magnet" then
                        if range>.01 then
                            s.x,s.y=move_hero(s,s.x-dx/range*dt*51,s.y-dy/range*dt*51)
                        end
                        for _,l in ipairs(s.loot) do
                            local lx,ly=h.x-l.x,h.y-l.y
                            if lx*lx+ly*ly<h.radius^2 then l.x,l.y=l.x+lx*dt,l.y+ly*dt end
                        end
                    else hurt(s,h.damage) end
                end
                h.fired=true
            end
        end
    end
end

local function eligible(s)
    local pool={}
    local weapons,artifacts=count(s.weapon),count(s.artifact)
    for i=1,17 do
        local rank=i<=8 and s.weapon[i] or s.artifact[i-8]
        if not s.banned[i] and rank<(i<=8 and d.weapon_max or d.artifact_max)
           and (rank>0 or (i<=8 and weapons or artifacts)<d.slots) then
            pool[#pool+1]=i
        end
    end
    return pool
end

function M.item_name(id)
    return d.weapons[id] or d.artifacts[id-8] or "Ремкомплект"
end

local function upgrade(s,id)
    if id<=8 then s.weapon[id]=s.weapon[id]+1
    elseif id<=17 then s.artifact[id-8]=s.artifact[id-8]+1
    else s.hp=min(s.max_hp,s.hp+s.max_hp*0.30) end
end

local function chest_reward(s,can_evolve)
    if can_evolve then
        for i=1,8 do
            if s.weapon[i]==d.weapon_max and s.artifact[d.evolution_artifact[i]]>=3 and not s.evolved[i] then
                return {id=i,evolved=true}
            end
        end
    end
    local current={}
    for _,id in ipairs(eligible(s)) do
        if (id<=8 and s.weapon[id] or s.artifact[id-8])>0 then current[#current+1]=id end
    end
    local id=(#current>0 and s.hp>=s.max_hp*0.45) and current[1+floor(random(s)*#current)] or 18
    return {id=id}
end

local function award_chest(s,reward)
    local id=reward.id
    if reward.evolved then
        s.evolved[id]=true
        s.notice=d.evolutions[id]
    else
        upgrade(s,id)
        s.notice="Сундук · "..M.item_name(id)
    end
    s.notice_until=s.time+4
end

function M.chest(s,can_evolve)
    award_chest(s,chest_reward(s,can_evolve))
end

local function deal(s,previous)
    local pool=eligible(s)
    for i=#pool,2,-1 do local j=1+floor(random(s)*i);pool[i],pool[j]=pool[j],pool[i] end
    local result={}
    if previous then
        local excluded={}
        for _,id in ipairs(previous) do excluded[id]=true end
        local ordered={}
        for _,id in ipairs(pool) do if not excluded[id] then ordered[#ordered+1]=id end end
        for _,id in ipairs(pool) do if excluded[id] then ordered[#ordered+1]=id end end
        pool=ordered
    else
        for _,priority in ipairs({s.hero,s.hero+8}) do
            for i,id in ipairs(pool) do
                if id==priority then result[#result+1]=id; table.remove(pool,i); break end
            end
        end
    end
    while #result<3 and #pool>0 do result[#result+1]=table.remove(pool,1) end
    if #result==0 or s.hp<s.max_hp*0.43 then result[min(3,#result+1)]=18 end
    s.options=result
end

local function level_if_ready(s)
    if s.xp<s.need then return end
    s.xp=s.xp-s.need; s.level=s.level+1
    local n=s.level-1
    s.need=floor(16+3.2*n+2.4*n^1.43+0.5)
    s.mode="level"; deal(s)
end

function M.claim_chest(s)
    if s.mode~="chest" or not s.chest_reward then return false end
    local reward=s.chest_reward
    s.chest_reward,s.mode=nil,"run"
    award_chest(s,reward)
    level_if_ready(s)
    return true
end

function M.choose(s,id,banish)
    if s.mode~="level" then return false end
    for _, option in ipairs(s.options) do
        if id==option then
            if banish then
                if id==18 or s.banishes==0 then return false end
                s.banned[id],s.banishes=true,s.banishes-1
                deal(s)
            else
                upgrade(s,id)
                s.mode="run"
            end
            return true
        end
    end
    return false
end

function M.reroll(s)
    if s.mode~="level" or s.rerolls==0 then return false end
    s.rerolls=s.rerolls-1
    deal(s,s.options)
    return true
end

function M.step(s,dt,mx,my)
    if s.mode~="run" then return end
    s.px,s.py=s.x,s.y
    s.time=min(d.duration,s.time+dt)
    local magnitude=sqrt(mx*mx+my*my)
    s.moving=magnitude>0.06
    if s.moving then
        s.dir_x,s.dir_y=mx/magnitude,my/magnitude
        local speed=d.heroes[s.hero][4]*(1+s.artifact[5]*0.06)*(s.doctrine==3 and 0.94 or 1)
            *(s.slowed_until>s.time and 0.70 or 1)
        s.x,s.y=move_hero(s,s.x+mx/max(1,magnitude)*speed*dt,s.y+my/max(1,magnitude)*speed*dt)
        s.moving=s.x~=s.px or s.y~=s.py
    end
    s.invincible=max(0,s.invincible-dt)
    field_crates(s,dt)
    vents(s)
    waves(s)
    attack(s,dt)
    shots(s,dt)
    local grid, free_buckets = s.separation_grid, s.free_buckets
    for key,bucket in pairs(grid) do
        for i=#bucket,1,-1 do bucket[i]=nil end
        free_buckets[#free_buckets+1]=bucket
        grid[key]=nil
    end
    local view_extra=max(s.view_padding.x,s.view_padding.y)
    for i=#s.enemies,1,-1 do
        local u=s.enemies[i]
        local despawn_range=(s.arena==1 and (u.kind==4 and 505 or 580) or 1100)+view_extra
        if u.hp<=0 or (not u.elite and u.kind~=6 and (s.x-u.x)^2+(s.y-u.y)^2>despawn_range^2) then
            table.remove(s.enemies,i)
        else
            u.px,u.py=u.x,u.y
            enemy_move(s,u,dt)
            if s.arena==3 then u.x=max(-150,min(150,u.x)) end
            if s.arena==4 then u.y=max(-165,min(165,u.y)) end
            local gx,gy=floor(u.x/44),floor(u.y/44)
            local spacing_by_kind=separation[u.kind]
            local key=gx*131071+gy
            for ox=-1,1 do for oy=-1,1 do
                local bucket=grid[key+ox*131071+oy]
                if bucket then for _, v in ipairs(bucket) do
                    local dx,dy=u.x-v.x,u.y-v.y
                    local squared=dx*dx+dy*dy
                    local spacing=spacing_by_kind[v.kind]
                    if squared<spacing*spacing then
                        local dist=sqrt(squared)
                        local shift=min((spacing-dist)*0.36,dt*36)
                        local x,y=dist<0.001 and shift or dx/dist*shift,dist<0.001 and 0 or dy/dist*shift
                        if u.kind~=6 and not u.warning then move_enemy(s,u,x,y) end
                        if v.kind~=6 and not v.warning then move_enemy(s,v,-x,-y) end
                    end
                end end
            end end
            local bucket=grid[key]
            if not bucket then
                bucket=table.remove(free_buckets) or {}
                grid[key]=bucket
            end
            bucket[#bucket+1]=u
        end
    end
    enemy_attacks(s,dt)
    local magnet=61+s.artifact[6]*16+(s.hero==1 and 18 or 0)+(s.doctrine==1 and 16 or 0)
    local magnet_squared=magnet*magnet
    local chest
    for i=#s.loot,1,-1 do
        local l=s.loot[i]
        local dx,dy=s.x-l.x,s.y-l.y
        local squared=dx*dx+dy*dy
        if squared<(l.kind=="chest" and 529 or 169) and s.hp>0 and (l.kind~="chest" or not chest) then
            if l.kind=="xp" then s.xp=s.xp+l.xp
            elseif l.kind=="heal" then s.hp=min(s.max_hp,s.hp+s.max_hp*0.24)
            else chest=l end
            table.remove(s.loot,i)
        elseif l.kind=="xp" and squared<magnet_squared then
            local r=sqrt(squared)
            local pull=min(r,(145+(magnet-r)*4)*dt)/max(r,0.001)
            if s.alley then l.x,l.y=alley.move(s.alley,l.x,l.y,dx*pull,dy*pull,2)
            else l.x,l.y=l.x+dx*pull,l.y+dy*pull end
        end
    end
    for i=#s.effects,1,-1 do
        local e=s.effects[i]
        if e.delay and e.delay>0 then
            e.delay=e.delay-dt
        elseif e.kind==10 then
            e.tick=e.tick-dt
            if e.tick<=0 then
                e.tick=0.35
                for _,u in ipairs(s.enemies) do
                    if u.hp>0 and (u.x-e.x)^2+(u.y-e.y)^2<e.r^2 then
                        damage(s,u,e.evolved and 17 or 8+s.weapon[8]*2,8)
                    end
                end
            end
        end
        if not e.delay or e.delay<=0 then e.life=e.life-dt end
        if e.life<=0 then table.remove(s.effects,i) end
    end
    maintain_population(s)
    if s.hp<=0 or s.time>=d.duration then s.mode="ended"; s.won=s.hp>0 and s.boss and s.boss.hp<=0
    elseif chest then
        s.chest_reward=chest_reward(s,chest.evolves)
        s.mode="chest"
    else
        level_if_ready(s)
    end
end

return M
