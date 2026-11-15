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

local simulate = require "tests.bot"

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
