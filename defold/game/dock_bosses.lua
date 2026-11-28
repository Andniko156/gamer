local M = {}
local clock_scale = 88 * 1.17 / 80
local overseer = {size=165, foot_drop=49.5, center_above_foot=49.5, hz=7,
    attacks={"reactor", "disc", "floor", "summon"}}
local clock = {size=96*clock_scale, foot_drop=11, center_above_foot=25*clock_scale, hz=8,
    attacks={"slow"}, mirror=true}

local function define_frames(skin, name)
    for _, facing in ipairs({"front", "rear"}) do
        local prefix = "dock_" .. name .. "_" .. facing .. "_"
        local frames = {idle=prefix .. "idle", move={}}
        for step=1,4 do frames.move[step]=prefix .. "move_" .. step end
        for _, attack in ipairs(skin.attacks) do
            frames[attack]={}
            for step=1,4 do frames[attack][step]=prefix .. attack .. "_" .. step end
        end
        skin[facing]=frames
    end
end

define_frames(overseer, "overseer")
define_frames(clock, "clock_elite")

function M.skin(arena, kind, elite)
    if arena~=1 then return end
    if kind==6 then return overseer end
    if kind==8 and elite then return clock end
end

local function aim(skin, unit)
    if unit.look_rear then return skin.rear, skin.mirror and unit.look_right==true end
    return skin.front, skin.mirror and unit.look_right==true
end

function M.idle(skin, unit)
    local frames, flipped = aim(skin, unit)
    return frames.idle, flipped
end

function M.pose(skin, unit, time)
    local frames, flipped = aim(skin, unit)
    local attack = frames[unit.pattern or "slow"]
    if attack then
        -- The contact pose begins on the same simulation tick as the hit or field.
        if unit.warning then
            local second = unit.warning_started+(unit.warning-unit.warning_started)*.55
            return attack[time>=second and 2 or 1], flipped
        end
        if (unit.attack_until or 0)>time then return attack[3], flipped end
        if (unit.recover_until or 0)>time then return attack[4], flipped end
    end
    if math.abs(unit.x-unit.px)+math.abs(unit.y-unit.py)>.1 then
        local step = math.floor(time*skin.hz+(unit.gait_phase or 0))%4+1
        return frames.move[step], flipped
    end
    return frames.idle, flipped
end

return M
