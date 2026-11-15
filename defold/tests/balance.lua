-- Reproducible regression sample, not a human playtest or difficulty guarantee.
local simulate=require "tests.bot"
print("hero,seed,seconds,kills,level,won")
for hero=1,5 do
    for _,base in ipairs({641,1259,2027,4093,7919}) do
        local seed=base+hero*3
        local s=simulate(hero,seed)
        print(string.format("%d,%d,%.1f,%d,%d,%s",hero,seed,s.time,s.kills,s.level,tostring(s.won or false)))
    end
end
