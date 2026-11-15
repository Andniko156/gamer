local d = require "game.data"
local M = {}
local cos, sin, sqrt, floor = math.cos, math.sin, math.sqrt, math.floor
local min, max = math.min, math.max
local tau = 2 * math.pi

local function random(s)
    s.seed = s.seed * 48271 % 2147483647
    return s.seed / 2147483647
end

local function count(t)
    local n = 0
    for _, value in ipairs(t) do if value > 0 then n = n + 1 end end
    return n
end

local function spawn(s, kind, x, y, elite)
    local stats = d.foes[kind]
    local hp = stats[1] * (kind == 6 and 1 or 1 + s.time / 770) * (elite and 2.5 or 1)
    local u = {kind=kind, x=x, y=y, px=x, py=y, hp=hp, elite=elite, max_hp=hp,
        interval=1.3+random(s)*1.6}
    s.enemies[#s.enemies+1] = u
    return u
end

local function ring_spawn(s, kind, distance, angle, elite)
    return spawn(s, kind, s.x + distance*cos(angle), s.y + distance*sin(angle), elite)
end

function M.new(hero, seed, doctrine, arena)
    local hp = d.heroes[hero][3]
    local s = {
        hero=hero, seed=seed % 2147483646 + 1, doctrine=doctrine or 1, hp=hp, max_hp=hp, time=0,
        x=0,y=0,px=0,py=0, dir_x=1,dir_y=0, wave=1, level=1,xp=0,need=16,kills=0,
        enemies={},shots={},loot={},effects={},weapon={0,0,0,0,0}, artifact={0,0,0,0,0,0},
        evolved={},cooldown={0,0,0,0,0},damage={}, banned={}, rerolls=2, banishes=1,
        next_spawn=1.1,elite_index=1,event_index=1, invincible=0, mode="run",
        arena=arena or 1, crates={}, next_crate=d.crates.first, frozen_until=0,
    }
    s.weapon[hero]=1
    local angle=random(s)*tau
    for i=1,22 do ring_spawn(s,1,155+(i%5)*23,angle+i*0.46) end
    return s
end

local function hurt(s, amount)
    if s.invincible > 0 then return end
    s.hp = s.hp - amount * (s.hero==4 and 0.76 or 1) * (1-s.artifact[4]*0.07)
        * (s.doctrine == 3 and 0.86 or s.doctrine == 2 and 1.10 or 1)
    s.invincible = 0.65
end

local function add_xp(s, x, y, xp)
    if #s.loot >= 190 then
        for _, item in ipairs(s.loot) do
            if item.kind=="xp" then item.xp=item.xp+xp; return end
        end
    end
    s.loot[#s.loot+1]={x=x,y=y,kind="xp",xp=xp}
end

local function damage(s,u,amount,weapon)
    if u.hp <= 0 then return end
    local scaled=amount*(1+s.artifact[1]*0.08)*(s.hero==2 and 1.18 or 1)*(s.doctrine==2 and 1.12 or 1)
    s.damage[weapon]=(s.damage[weapon] or 0)+min(u.hp,scaled)
    u.hp=u.hp-scaled
    u.flash=0.11
    if u.hp>0 then return end
    s.kills=s.kills+1
    local xp=d.foes[u.kind][5]+(u.elite and 6 or 0)
    add_xp(s,u.x,u.y,xp)
    if u.elite then s.loot[#s.loot+1]={x=u.x,y=u.y,kind="chest",evolves=u.elite>=195} end
    if s.kills%31==0 and s.hp<s.max_hp then
        s.loot[#s.loot+1]={x=u.x+12,y=u.y,kind="heal"}
    end
end

local function waves(s)
    s.wave=min(10,1+floor(s.time/60))
    local elite=d.elites[s.elite_index]
    if elite and s.time>=elite[1] then
        ring_spawn(s,elite[2],215,random(s)*tau,elite[1])
        s.elite_index=s.elite_index+1
        s.notice="Элита несёт шкатулку"; s.notice_until=s.time+4
    end
    if s.time>=d.boss_at and not s.boss then
        s.boss=ring_spawn(s,6,175,random(s)*tau)
        s.notice="Смотритель на арене"; s.notice_until=s.time+5
    end
    local event=d.events[s.event_index]
    if event and s.time>=event[1] and not s.formation then
        s.formation={kind=s.event_index,x=s.x,y=s.y,angle=random(s)*tau,at=s.time+2.2}
        s.notice=event[2]; s.notice_until=s.time+4
    end
    local event_formation=s.formation
    if event_formation and s.time>=event_formation.at then
        local f=event_formation
        if f.kind%2==0 then
            for i=2,13 do
                local a=f.angle+i*tau/15
                spawn(s,(f.kind==4 and i%3==0) and 3 or 1,f.x+205*cos(a),f.y+205*sin(a))
            end
        else
            for line=0,(f.kind==3 and 1 or 0) do
                local a=f.angle+line*math.pi/2
                for i=-4,4 do
                    local u=spawn(s,2,f.x+255*cos(a)-i*25*sin(a),f.y+255*sin(a)+i*25*cos(a))
                    u.dash_x,u.dash_y,u.dash_until=-cos(a),-sin(a),s.time+3.8
                end
            end
        end
        s.formation=nil
        s.event_index=s.event_index+1
    end
    if s.time<s.next_spawn then return end
    local w=d.waves[s.wave]
    local minute=s.time%60
    local rest=minute>=49 and minute<56
    s.next_spawn=s.time+w[3]*(rest and 1.35 or 1)
    local available=max(0,min(rest and math.ceil(w[2]/2) or w[2],64+(s.wave-1)*8-#s.enemies))
    local a=random(s)*tau
    local rams,mortars=0,0
    for _,u in ipairs(s.enemies) do
        if u.kind==4 then rams=rams+1 elseif u.kind==5 then mortars=mortars+1 end
    end
    for i=1,available do
        local kind=w[4][1+floor(random(s)*#w[4])]
        if s.time<24 or (kind==4 and rams>=7) or (kind==5 and mortars>=3) then kind=1 end
        if kind==4 then rams=rams+1 elseif kind==5 then mortars=mortars+1 end
        ring_spawn(s,kind,248+random(s)*68,a+i*0.24+(s.wave>=6 and i%2==0 and math.pi or 0))
    end
end

local function field_crates(s,dt)
    if s.time>=s.next_crate then
        local angle=random(s)*tau
        s.crates[#s.crates+1]={x=s.x+cos(angle)*d.crates.radius,
            y=s.y+sin(angle)*d.crates.radius, kind=1+floor(random(s)*3),
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

function M.vent_state(s,x,y)
    if s.arena~=2 then return "off" end
    local cfg=d.vents
    local ix=floor((x-cfg.offset)/cfg.spacing+0.5)
    local iy=floor((y-cfg.offset)/cfg.spacing+0.5)
    local cx,cy=cfg.offset+ix*cfg.spacing,cfg.offset+iy*cfg.spacing
    local phase=(s.time+((ix*7+iy*11)%4)*3)%cfg.cycle
    local state=phase>=cfg.cycle-cfg.active and "active"
        or phase>=cfg.cycle-cfg.active-cfg.warning and "warning" or "idle"
    return state,cx,cy
end

local function vents(s)
    if s.arena~=2 then return end
    local state,cx,cy=M.vent_state(s,s.x,s.y)
    if state=="active" and (s.x-cx)^2+(s.y-cy)^2<d.vents.radius^2 then
        hurt(s,12)
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
    if #s.effects<25 then
        s.effects[#s.effects+1]={kind=k,x=x,y=y,r=r,angle=angle or 0,life=0.22}
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
                    effect(s,2,(x+target.x)/2,(y+target.y)/2,sqrt(dx*dx+dy*dy),math.atan2(dy,dx))
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
                                    u.x,u.y=u.x+ux/range*force,u.y+uy/range*force
                                end
                            end
                        end
                    end
                    effect(s,k,s.x,s.y,radius,aim)
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
            damage(s,hit.u,p.amount,1)
            p.hit[hit.u]=true
            p.pierce=p.pierce-1
            if p.pierce==0 then break end
        end
        if p.pierce==0 or p.life<=0 then table.remove(s.shots,i) end
    end
end

local function enemy_move(s,u,dt)
    local stats=d.foes[u.kind]
    local dx,dy=s.x-u.x,s.y-u.y
    local distance=sqrt(dx*dx+dy*dy)
    local ux,uy=dx/max(0.001,distance),dy/max(0.001,distance)
    local speed=stats[2]*(u.slow_until and u.slow_until>s.time and 0.66 or 1)
        *(s.frozen_until>s.time and 0.35 or 1)
    local enraged=u.kind==6 and u.hp<u.max_hp*0.45
    if enraged then speed=speed*1.24 end
    local recovering=u.recover_until and s.time<u.recover_until
    local dashing=u.dash_until and s.time<u.dash_until
    if dashing then
        local dash_speed=u.kind==4 and d.attacks.ram.speed or 118
        u.x,u.y=u.x+u.dash_x*dt*dash_speed,u.y+u.dash_y*dt*dash_speed
    elseif not u.warning and not recovering and distance>(u.kind==5 and 155 or stats[4]+5) then
        u.x,u.y=u.x+ux*dt*speed,u.y+uy*dt*speed
    end
    if (s.x-u.x)^2+(s.y-u.y)^2<(stats[4]+8)^2 then hurt(s,stats[3]) end
    if u.flash then u.flash=max(0,u.flash-dt) end
    if u.kind<4 or dashing or recovering then return end
    if u.warning then
        if s.time<u.warning then return end
        u.warning=nil
        if u.kind==4 then
            u.dash_until=s.time+d.attacks.ram.duration
            u.recover_until=u.dash_until+d.attacks.ram.recovery
            return
        end
        local x,y=u.target_x,u.target_y
        local radius=u.attack_radius
        if (s.x-x)^2+(s.y-y)^2<radius*radius then hurt(s,u.kind==5 and 19 or 36) end
        effect(s,6,x,y,radius)
        u.recover_until=s.time+(u.kind==5 and d.attacks.mortar.recovery or d.attacks.boss.recovery)
    elseif u.interval<=s.time and distance<(u.kind==4 and 126 or 253) then
        local config=u.kind==4 and d.attacks.ram or u.kind==5 and d.attacks.mortar or d.attacks.boss
        u.interval=s.time+(enraged and 3.7 or 5.1)
        u.warning_started=s.time
        u.warning=s.time+config.warning
        u.target_x,u.target_y=u.kind==6 and u.x or s.x,u.kind==6 and u.y or s.y
        u.attack_radius=(enraged and config.enraged_radius) or config.radius
        u.dash_x,u.dash_y=ux,uy
    end
end

local function eligible(s)
    local pool={}
    local weapons,artifacts=count(s.weapon),count(s.artifact)
    for i=1,11 do
        local rank=i<=5 and s.weapon[i] or s.artifact[i-5]
        if not s.banned[i] and rank<(i<=5 and d.weapon_max or d.artifact_max)
           and (rank>0 or (i<=5 and weapons or artifacts)<d.slots) then
            pool[#pool+1]=i
        end
    end
    return pool
end

function M.item_name(id)
    return d.weapons[id] or d.artifacts[id-5] or "Ремкомплект"
end

local function upgrade(s,id)
    if id<=5 then s.weapon[id]=s.weapon[id]+1
    elseif id<=11 then s.artifact[id-5]=s.artifact[id-5]+1
    else s.hp=min(s.max_hp,s.hp+s.max_hp*0.30) end
end

function M.chest(s,can_evolve)
    if can_evolve then
        for i=1,5 do
            if s.weapon[i]==d.weapon_max and s.artifact[i]>=3 and not s.evolved[i] then
                s.evolved[i]=true
                s.notice=d.evolutions[i]; s.notice_until=s.time+4
                return
            end
        end
    end
    local current={}
    for _,id in ipairs(eligible(s)) do
        if (id<=5 and s.weapon[id] or s.artifact[id-5])>0 then current[#current+1]=id end
    end
    local id=(#current>0 and s.hp>=s.max_hp*0.45) and current[1+floor(random(s)*#current)] or 12
    upgrade(s,id)
    s.notice="Шкатулка · "..M.item_name(id); s.notice_until=s.time+4
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
        for _,priority in ipairs({s.hero,s.hero+5}) do
            for i,id in ipairs(pool) do
                if id==priority then result[#result+1]=id; table.remove(pool,i); break end
            end
        end
    end
    while #result<3 and #pool>0 do result[#result+1]=table.remove(pool,1) end
    if #result==0 or s.hp<s.max_hp*0.43 then result[min(3,#result+1)]=12 end
    s.options=result
end

function M.choose(s,id,banish)
    if s.mode~="level" then return false end
    for _, option in ipairs(s.options) do
        if id==option then
            if banish then
                if id==12 or s.banishes==0 then return false end
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
        s.x,s.y=s.x+mx/max(1,magnitude)*speed*dt,s.y+my/max(1,magnitude)*speed*dt
    end
    s.invincible=max(0,s.invincible-dt)
    field_crates(s,dt)
    vents(s)
    waves(s)
    attack(s,dt)
    shots(s,dt)
    local grid={}
    for i=#s.enemies,1,-1 do
        local u=s.enemies[i]
        if u.hp<=0 or (not u.elite and u.kind~=6 and (s.x-u.x)^2+(s.y-u.y)^2>1100^2) then
            table.remove(s.enemies,i)
        else
            u.px,u.py=u.x,u.y
            enemy_move(s,u,dt)
            local gx,gy=floor(u.x/44),floor(u.y/44)
            for ox=-1,1 do for oy=-1,1 do
                local bucket=grid[(gx+ox)*131071+gy+oy]
                if bucket then for _, v in ipairs(bucket) do
                    local dx,dy=u.x-v.x,u.y-v.y
                    local dist=sqrt(dx*dx+dy*dy)
                    local overlap=(d.foes[u.kind][4]+d.foes[v.kind][4])*0.8-dist
                    if overlap>0 then
                        local shift=min(overlap*0.36,dt*36)
                        local x,y=dist<0.001 and shift or dx/dist*shift,dist<0.001 and 0 or dy/dist*shift
                        if u.kind~=6 and not u.warning then u.x,u.y=u.x+x,u.y+y end
                        if v.kind~=6 and not v.warning then v.x,v.y=v.x-x,v.y-y end
                    end
                end end
            end end
            local key=gx*131071+gy
            grid[key]=grid[key] or {}
            table.insert(grid[key],u)
        end
    end
    local magnet=45+s.artifact[6]*16+(s.hero==1 and 18 or 0)+(s.doctrine==1 and 16 or 0)
    for i=#s.loot,1,-1 do
        local l=s.loot[i]
        local dx,dy=s.x-l.x,s.y-l.y
        local r=sqrt(dx*dx+dy*dy)
        if r<(l.kind=="chest" and 23 or 13) and s.hp>0 then
            if l.kind=="xp" then s.xp=s.xp+l.xp
            elseif l.kind=="heal" then s.hp=min(s.max_hp,s.hp+s.max_hp*0.24)
            else M.chest(s,l.evolves) end
            table.remove(s.loot,i)
        elseif l.kind=="xp" and r<magnet then
            local pull=min(r,(145+(magnet-r)*4)*dt)/max(r,0.001)
            l.x,l.y=l.x+dx*pull,l.y+dy*pull
        end
    end
    for i=#s.effects,1,-1 do
        local e=s.effects[i]
        e.life=e.life-dt
        if e.life<=0 then table.remove(s.effects,i) end
    end
    if s.hp<=0 or s.time>=d.duration then s.mode="ended"; s.won=s.hp>0 and s.boss and s.boss.hp<=0
    elseif s.xp>=s.need then
        s.xp=s.xp-s.need; s.level=s.level+1
        local n=s.level-1
        s.need=floor(16+3.2*n+2.4*n^1.43+0.5)
        s.mode="level"; deal(s)
    end
end

return M
