local run = require "game.run"

local function simulate(hero, seed, arena)
    local s = run.new(hero, seed, nil, arena)
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

return simulate
