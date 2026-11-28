local M = {}

M.skins = {
    [1] = {name = "spider", size = 68, hz = 11},
    [2] = {name = "mechanic", size = 76, hz = 9, rear = {}, front_right = true, left_frames = {[6] = true, [7] = true}},
    [3] = {name = "boiler", size = 79, hz = 10},
    [4] = {name = "turret", size = 80, hz = 3, fixed = true},
    [5] = {name = "drone", size = 68, hz = 7},
    [7] = {name = "guard", size = 79, hz = 8, rear = {}, front_right = true, left_frames = {[6] = true}},
    [8] = {name = "clock", size = 88, hz = 8, rear = {}},
    [9] = {name = "brute", size = 94, hz = 7, rear = {}},
}

for _, skin in pairs(M.skins) do
    for frame = 0, 7 do
        skin[frame] = skin.name .. "_" .. frame
        if skin.rear then skin.rear[frame] = skin.name .. "_rear_" .. frame end
    end
end

function M.look_at(unit, dx, dy)
    local horizontal, vertical = math.abs(dx), math.abs(dy)
    if horizontal + vertical < .05 then return end
    if horizontal > math.max(.05, vertical * .1) then unit.look_right = dx > 0 end
    -- Different thresholds keep the view stable around the horizontal axis.
    unit.look_rear = dy > horizontal * (unit.look_rear and .18 or .34)
end

function M.directional_sprite(skin, unit, frame)
    if unit.look_rear then return skin.rear[frame], unit.look_right == true end
    local art_faces_right = skin.front_right == true and not skin.left_frames[frame]
    return skin[frame], (unit.look_right == true) ~= art_faces_right
end

function M.frame(skin, unit, time)
    if unit.warning then
        local windup = unit.warning - unit.warning_started
        return time - unit.warning_started < windup * .30 and 4 or 5
    elseif (unit.attack_until or 0) > time or (unit.dash_until or 0) > time then
        return 6
    elseif (unit.recover_until or 0) > time then
        return 7
    end
    local moving = math.abs(unit.x - unit.px) + math.abs(unit.y - unit.py) > .1
    if moving or skin.fixed or skin.name == "drone" then
        return math.floor(time * skin.hz + (unit.gait_phase or 0)) % 4
    end
    return 4
end

return M
