local run=require 'game.run'
local data=require 'game.data'
assert(#data.arena_names==4 and #data.arena_foes==4)
for arena=1,4 do
    local s=run.new(1,arena*29,1,arena)
    s.enemies={}; s.next_spawn=999
    run.step(s,2,1,1)
    if arena==3 then assert(s.x<=140 and s.x>=-140) end
    if arena==4 then assert(s.y<=190 and s.y>=-190) end
    s.time=179.99; s.next_spawn=999
    run.step(s,0.02,0,0)
    assert(s.elite_index==2 and (function() for _,u in ipairs(s.enemies) do if u.kind==8 then return true end end end)())
    s.time=299.99; run.step(s,0.02,0,0)
    assert(s.elite_index==3 and (function() for _,u in ipairs(s.enemies) do if u.kind==10 then return true end end end)())
    s.time=539.99;run.step(s,0.02,0,0)
    assert(s.boss and s.boss.kind==6)
end
local s=run.new(1,341,1,4)
s.weapon[6]=6;s.artifact[7]=3
run.chest(s,true)
assert(s.evolved[6] and s.notice=='Последний аргумент')
local s2=run.new(1,342,1,3)
s2.weapon[7]=6;s2.artifact[8]=3
run.chest(s2,true)
assert(s2.evolved[7])
local s3=run.new(1,343,1,1)
s3.weapon[8]=6;s3.artifact[9]=3
run.chest(s3,true)
assert(s3.evolved[8])
print('Factory worlds checks passed: four arenas, bosses, chest-only evolutions')
