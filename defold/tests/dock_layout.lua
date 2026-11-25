local art = require "game.dock_art"
local collision = require "game.dock_collision"
local run = require "game.run"
local size = art.size
local vent_radius = require("game.data").vents.radius
local signatures, stations, scattered = {}, 0, 0
for seed=1,200 do
    local s = run.new(1,seed,1,1)
    local map, replay = s.dock, art.new(seed)
    local opening = {}
    for col=-1,0 do for row=-1,0 do
        opening[art.sector(map,col,row).group] = true
    end end
    local kinds = 0
    for _ in pairs(opening) do kinds = kinds+1 end
    assert(kinds==4 and not collision.blocked(map,0,0,collision.hero_radius))
    for _,enemy in ipairs(s.enemies) do
        assert(not collision.blocked(map,enemy.x,enemy.y,12))
    end
    local signature = {}
    for row=-8,8 do for col=-8,8 do
        local cell = art.sector(map,col,row)
        art.sector(replay,col+16,row) -- Evict the same cache slot before revisiting.
        local other = art.sector(replay,col,row)
        assert(cell.group==other.group and cell.x==other.x and cell.y==other.y and cell.floor==other.floor)
        if cell.group then
            -- Objects and live vents leave the connecting lanes along sector borders open.
            local x,y = cell.cx-col*size, cell.cy-row*size
            assert(x-cell.w>28 and x+cell.w<size-28 and y-cell.h>28 and y+cell.h<size-28)
            if cell.vent then
                local vx,vy = cell.x-col*size, cell.y-row*size
                assert(vx>vent_radius+28 and vx<size-vent_radius-28 and vy>vent_radius+28 and vy<size-vent_radius-28)
            end
            if col < 8 then
                local next_cell = art.sector(map,col+1,row)
                if next_cell.group and cell.y==next_cell.y and next_cell.group==cell.group then
                    if cell.group.sprites[1][1]=="repair_marks" then stations=stations+1
                    else scattered=scattered+1 end
                end
            end
        end
        signature[#signature+1] = cell.x..","..cell.y..","..(cell.group and cell.group.sprites[1][1] or "floor")
    end end
    local key = table.concat(signature,";")
    assert(not signatures[key], "duplicate dock layout for seeds "..seed.." and "..tostring(signatures[key]))
    signatures[key] = seed
end
assert(stations>200 and scattered*10<stations, "only workstation bays should regularly line up")
print(string.format("Dock layout: 200 distinct reproducible maps, %d aligned station pairs, %d incidental alignments",stations,scattered))
