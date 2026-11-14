local run = require "game.run"

local function assert_evolution()
    local s = run.new(1, 8)
    s.weapon[1], s.artifact[1] = 6, 3
    run.chest(s, false)
    assert(not s.evolved[1])
    run.chest(s, true)
    assert(s.evolved[1])
end

local function assert_build_controls()
    local s = run.new(1, 6)
    s.xp = s.need
    run.step(s, 1/60, 0, 0)
    assert(s.mode == "level" and #s.options == 3)
    assert(run.reroll(s) and s.rerolls == 1)
    local removed = s.options[1]
    assert(run.choose(s, removed, true))
    for _, option in ipairs(s.options) do assert(option ~= removed) end
    assert(run.choose(s, s.options[1], false) and s.mode == "run")
end

local function assert_timeline()
    local s = run.new(1, 24)
    s.time = 87.99
    run.step(s, 1/60, 0, 0)
    assert(s.formation and s.formation.kind == 1)
    s.time = s.formation.at
    run.step(s, 1/60, 0, 0)
    local swarm = 0
    for _, u in ipairs(s.enemies) do if u.dash_until then swarm = swarm + 1 end end
    assert(swarm == 9)
    s.time = 539.999
    run.step(s, 1/60, 0, 0)
    assert(s.boss and s.boss.hp > 0)
    s.boss.hp, s.time = 0, 599.999
    run.step(s, 1/60, 0, 0)
    assert(s.mode == "ended" and s.won and s.time == 600)
end

local function simulate(hero, seed)
    local s = run.new(hero, seed)
    assert(#s.enemies == 10)
    for _=1,36050 do
        if s.mode=="ended" then return s end
        if s.mode=="level" then
            local selected=s.options[1]
            for _, id in ipairs(s.options) do
                if id==12 and s.hp<s.max_hp*0.42 then selected=id;break end
            end
            run.choose(s,selected)
        end
        local mx,my=0,0
        local best=math.huge
        for _, l in ipairs(s.loot) do
            local dx,dy=l.x-s.x,l.y-s.y
            local weight=l.kind=="chest" and 0.35 or l.kind=="heal" and (s.hp<s.max_hp*0.6 and 0.45 or 3) or 1
            local score=(dx*dx+dy*dy)*weight
            if score<best then
                local n=math.max(1,math.sqrt(dx*dx+dy*dy))
                mx,my,best=dx/n,dy/n,score
            end
        end
        for _, u in ipairs(s.enemies) do
            local dx,dy=s.x-u.x,s.y-u.y
            local range=math.sqrt(dx*dx+dy*dy)
            local safe=u.warning and u.kind==6 and 137 or 49
            if range<safe then
                local weight=2.3*(1-range/safe)/math.max(1,range)
                mx,my=mx+dx*weight,my+dy*weight
            end
        end
        run.step(s,1/60,mx,my)
    end
    error("run did not finish")
end

assert_evolution()
assert_build_controls()
assert_timeline()
local wins=0
for hero=1,5 do
    local s=simulate(hero,641+hero*3)
    assert(s.kills>0 and s.level>1)
    if s.won then wins=wins+1 end
    print(string.format("hero=%d time=%.1f kills=%d level=%d won=%s",hero,s.time,s.kills,s.level,tostring(s.won)))
end
assert(wins>0)
print("Smoke checks passed")
