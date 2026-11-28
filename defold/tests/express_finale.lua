local simulate=require "tests.bot"
local run=require "game.run"
local express=require "game.express"
local data=require "game.data"

local function reach(s,boss)
    local dx,dy=boss.x-s.x,boss.y-s.y
    local distance=math.sqrt(dx*dx+dy*dy)
    local area=(s.hero==3 and 1.22 or 1)*(1+s.artifact[3]*.07)
    local _,orbit=run.disks(s)
    local ranged={[1]=340,[6]=240*area}
    local radius={
        [2]=240*area,
        [3]=math.min(240*area,(s.evolved[3] and 175 or 76+s.weapon[3]*9)*area),
        [4]=math.min(240*area,(s.evolved[4] and 155 or 76+s.weapon[4]*9)*area),
        [5]=orbit+data.foes[6][4]+(s.evolved[5] and 22 or 16)*area,
        [7]=math.min(240*area,(s.evolved[7] and 145 or 70+s.weapon[7]*9)*area),
        [8]=240*area,
    }
    local covered=false
    for i,rank in ipairs(s.weapon) do
        if rank>0 then
            if ranged[i] and distance<ranged[i] then
                if express.projectile_limit(s.x,s.y,dx,dy)==1 then return "reachable" end
                covered=true
            elseif radius[i] and distance<radius[i] then return "reachable" end
        end
    end
    return covered and "covered" or "distant"
end

local function approach(s,mx,my)
    local boss=s.boss
    if not boss or boss.hp<=0 then return mx,my end
    local dx,dy=boss.x-s.x,boss.y-s.y
    if dx*dx+dy*dy<72^2 then return mx,my end
    local tx,ty=express.route(s.x,s.y,boss.x,boss.y,10)
    dx,dy=tx-s.x,ty-s.y
    local distance=math.max(1,math.sqrt(dx*dx+dy*dy))
    return dx/distance,dy/distance
end

print("hero,seed,policy,time,first_hit_seconds,reachable_pct,covered_pct,distant_pct,boss_hp,won")
local single=tonumber(arg and arg[1])
for hero=single or 1,single or #data.heroes do
    local seed=644+hero*3
    for _,policy in ipairs({"loot","boss"}) do
        local first_hit,total
        local ticks={reachable=0,covered=0,distant=0}
        local function measure(s)
            local boss=s.boss
            if not boss then return end
            if not total then total=0 end
            if not first_hit and boss.hp<boss.max_hp then first_hit=s.time-data.boss_at end
            if boss.hp>0 then
                local reason=reach(s,boss)
                ticks[reason]=ticks[reason]+1
                total=total+1
            end
        end
        local s=simulate(hero,seed,3,measure,policy=="boss" and approach or nil)
        local function share(reason)
            return total and string.format("%.1f",100*ticks[reason]/math.max(1,total)) or ""
        end
        print(string.format("%d,%d,%s,%.1f,%s,%s,%s,%s,%s,%s",hero,seed,policy,s.time,
            first_hit and string.format("%.2f",first_hit) or "",
            share("reachable"),share("covered"),share("distant"),
            s.boss and string.format("%.1f",math.max(0,s.boss.hp)) or "",tostring(not not s.won)))
    end
end
