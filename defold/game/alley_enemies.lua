local frame_index = require("game.dock_enemies").frame
local patterns = require("game.data").boss_patterns[2]
local M = { atlas="alley_enemies" }
local rates = {8,11,9,8,7,7,8,9,6,9}
local skins = {}

local function sequence(prefix, action)
    local frames = {}
    for i=0,3 do frames[i]=prefix..action.."_"..i end
    return frames
end

for kind, rate in ipairs(rates) do
    local scale = kind==6 and 1.16 or 1
    local skin = {width=112*scale,height=96*scale,rise=36*scale,hz=rate,name=kind==5 and "drone" or nil}
    for _, facing in ipairs({"front","rear"}) do
        local prefix = "alley_"..kind.."_"..facing.."_"
        local frames = {move=sequence(prefix,"move"),attack=sequence(prefix,"attack")}
        if kind==6 then
            for _, pattern in ipairs(patterns) do frames[pattern]=sequence(prefix,pattern) end
        end
        skin[facing]=frames
    end
    skins[kind]=skin
end

function M.skin(arena, kind)
    if arena==2 then return skins[kind] end
end

function M.pose(skin,unit,time)
    local frames = unit.look_rear and skin.rear or skin.front
    local flipped = not unit.look_rear and unit.look_right==false
    if not time then return frames.move[0],flipped end
    local index = frame_index(skin,unit,time)
    if index<4 then return frames.move[index],flipped end
    if index==4 and not unit.warning then return frames.move[0],flipped end
    return (frames[unit.pattern] or frames.attack)[index-4],flipped
end

return M
