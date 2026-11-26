local pose_frame = require("game.dock_enemies").frame

local M = {}
local skins = {}
local widths = {100, 100, 104, 100, 98, 128, 106, 102, 114, 104}
local rates = {8, 11, 7, 8, 9, 7, 7, 9, 6, 7}

for kind, width in ipairs(widths) do
    local scale = width / 128
    local skin = {width=width, height=112*scale, rise=40*scale, hz=rates[kind]}
    for _, facing in ipairs({"front", "rear"}) do
        local prefix = "express_" .. kind .. "_" .. facing .. "_"
        local frames = {}
        for i=0,3 do
            frames[i] = prefix .. "move_" .. i
            frames[i+4] = prefix .. "attack_" .. i
        end
        skin[facing] = frames
    end
    skins[kind] = skin
end

function M.skin(arena, kind)
    if arena==3 then return skins[kind] end
end

function M.pose(skin, unit, time)
    local frames = unit.look_rear and skin.rear or skin.front
    if not time then return frames[0] end
    local index = pose_frame(skin,unit,time)
    local pattern = unit.pattern
    -- The cinder sweep poses suit both coal attacks. The other boss windups
    -- use the unlit ready pose with their own floor and summon telegraphs.
    if index==4 and not unit.warning then
        index = 0
    elseif pattern and index>=4 and pattern~="furnace" and pattern~="cinders" then
        index = index==7 and 0 or 4
    end
    return frames[index]
end

return M
