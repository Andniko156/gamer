local simulate=require "tests.bot"
for arena=1,4 do
    local wins=0
    for hero=1,5 do
        local s=simulate(hero,644+hero*3,arena)
        assert(s.mode=="ended" and s.time<=600 and s.kills>0)
        if s.won then wins=wins+1 end
        print(string.format("arena=%d hero=%d time=%.1f won=%s crates=%d",
            arena,hero,s.time,tostring(s.won),#s.crates))
    end
    assert(wins>=1,"each arena should permit at least one complete bot win")
end
