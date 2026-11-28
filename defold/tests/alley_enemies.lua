local art=require "game.alley_enemies"
local data=require "game.data"
local run=require "game.run"

local file=assert(io.open("art/alley_enemies/poses.tilesource"))
local source=file:read("*a")
file:close()
for kind=1,10 do
    local skin=assert(art.skin(2,kind))
    for _,facing in ipairs({"front","rear"}) do
        local u={x=4,y=0,px=0,py=0,look_rear=facing=="rear",look_right=false}
        local idle,flip=art.pose(skin,u)
        assert(idle==skin[facing].move[0] and flip==(facing=="front"))
        for i=0,3 do
            assert(art.pose(skin,u,(i+.2)/skin.hz)==skin[facing].move[i])
        end
        for _,action in ipairs(kind==6 and data.boss_patterns[2] or {"attack"}) do
            u.pattern=kind==6 and action or nil
            local frames=skin[facing][action]
            for i=0,3 do assert(source:find('id: "'..frames[i]..'"',1,true)) end
            u.warning_started,u.warning=10,11
            assert(art.pose(skin,u,10)==frames[0] and art.pose(skin,u,10.8)==frames[1])
            u.warning,u.attack_until,u.recover_until=nil,11.23,11.8
            assert(art.pose(skin,u,11)==frames[2] and art.pose(skin,u,11.4)==frames[3])
        end
    end
end
local s=run.new(1,43,1,2)
for _,u in ipairs(s.enemies) do
    assert(u.look_rear~=nil)
end
assert(not art.skin(3,6))
print("Alley enemies: all kinds, two facings and four conductor attack patterns")
