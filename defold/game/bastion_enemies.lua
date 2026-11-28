local frame_index = require("game.dock_enemies").frame
local data = require("game.data")
local M = {
    atlas = "bastion_enemies"
}
local stage = 4
local skins = {}
local widths = {
    136,
    126,
    126,
    130,
    114,
    151,
    134,
    144,
    140,
    146
}
local shadows = {
    19,
    25,
    20,
    23,
    19,
    44,
    28,
    26,
    34,
    32
}
local rates = {
    10,
    9,
    7,
    8,
    7,
    7,
    8,
    9,
    6,
    8
}

for kind, width in ipairs(widths) do
    local skin={width=width,height=width*112/128,name="drone",rise=14,hz=rates[kind],shadow=shadows[kind]}
    local role=data.foe_roles[stage][kind]
    local actions=role=="boss" and data.boss_patterns[stage] or {role}

    for _,facing in ipairs({"front","rear"}) do
        local frames={}
        local prefix="bastion_"..kind.."_"..facing.."_"
        frames.move = {}

        for i = 0, 3 do
            frames.move[i] = prefix .. "move_" .. i
        end

        for _, action in ipairs(actions) do
            local keys = {}

            for i = 0, 3 do
                keys[i] = prefix .. action .. "_" .. i
            end

            frames[action] = keys
        end

        skin[facing] = frames
    end

    skin.role = role
    skins[kind] = skin
end

function M.skin(arena, kind)
    if arena == stage then
        return skins[kind]
    end
end

function M.pose(skin, unit, time)
    local instant = time and unit.sky_action_at and time - unit.sky_action_at

    if instant and instant >= 0 and instant < 0.34 then
        local frames = unit.sky_action_rear and skin.rear or skin.front

        return frames[skin.role][instant < 0.17 and 2 or 3]
    end

    local frames = unit.look_rear and skin.rear or skin.front

    if not time then
        return frames.move[0]
    end

    local index = frame_index(skin, unit, time)
    local attack = frames[unit.pattern or skin.role]

    if attack and index >= 4 then
        return attack[index - 4]
    end

    return frames.move[index < 4 and index or 0]
end

return M
