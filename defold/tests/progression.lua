local simulate=require "tests.bot"
print("hero,seed,arena,first_level,first_ready,first_evolution,level_at_end,won")
for arena=1,2 do
    for hero=1,5 do
        for _,base in ipairs({641,1259,2027}) do
            local metrics={}
            local function observe(s)
                if s.level>=2 and not metrics.level then metrics.level=s.time end
                if not metrics.ready then
                    for i=1,5 do
                        if s.weapon[i]==6 and s.artifact[i]>=3 then metrics.ready=s.time;break end
                    end
                end
                if not metrics.evolution then
                    for i=1,5 do if s.evolved[i] then metrics.evolution=s.time;break end end
                end
            end
            local s=simulate(hero,base+hero*3,arena,observe)
            print(string.format("%d,%d,%d,%s,%s,%s,%d,%s",hero,base+hero*3,arena,
                metrics.level and string.format("%.1f",metrics.level) or "none",
                metrics.ready and string.format("%.1f",metrics.ready) or "none",
                metrics.evolution and string.format("%.1f",metrics.evolution) or "none",
                s.level,tostring(s.won or false)))
        end
    end
end
