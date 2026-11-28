local art = require "game.dock_art"

local M = {hero_radius = 10, enemy_radius = 8}
local size = art.size
local floor, ceil, abs = math.floor, math.ceil, math.abs
local min, max = math.min, math.max

local function obstacle(map, x, y, radius)
    local cell = art.sector(map, floor(x / size), floor(y / size))
    if not cell.group then return end
    local cx, cy, w, h = cell.cx, cell.cy, cell.w, cell.h
    local dx = max(0, abs(x - cx) - w)
    local dy = max(0, abs(y - cy) - h)
    if dx * dx + dy * dy < radius * radius then return cx, cy, w, h end
end

function M.blocked(map, x, y, radius)
    return obstacle(map, x, y, radius) ~= nil
end

function M.move(map, x, y, dx, dy, radius)
    local steps = max(1, ceil(max(abs(dx), abs(dy)) / 6))
    dx, dy = dx / steps, dy / steps
    for _ = 1, steps do
        local nx, ny = x + dx, y + dy
        if not M.blocked(map, nx, ny, radius) then
            x, y = nx, ny
        else
            if not M.blocked(map, nx, y, radius) then x = nx end
            if not M.blocked(map, x, ny, radius) then y = ny end
        end
    end
    return x, y
end

function M.nearby_floor(map, x, y, radius)
    local cx, cy, w, h = obstacle(map, x, y, radius)
    if not cx then return x, y end
    if w - abs(x - cx) < h - abs(y - cy) then
        return cx + (x < cx and -1 or 1) * (w + radius + 1), y
    end
    return x, cy + (y < cy and -1 or 1) * (h + radius + 1)
end

function M.route(s, unit)
    local x, y = unit.x, unit.y
    if unit.route_x and (unit.route_x - x)^2 + (unit.route_y - y)^2 > 4 then
        return unit.route_x, unit.route_y
    end
    local dx, dy = s.x - x, s.y - y
    local distance = math.sqrt(dx * dx + dy * dy)
    local radius = M.enemy_radius
    for step = 4, min(distance, 44), 4 do
        local cx, cy, w, h = obstacle(s.dock, x + dx * step / distance, y + dy * step / distance, radius)
        if cx then
            local pad = radius + 4
            if abs(dx) >= abs(dy) then
                unit.route_x = x
                unit.route_y = cy + (y < cy and -1 or 1) * (h + pad)
            else
                unit.route_x = cx + (x < cx and -1 or 1) * (w + pad)
                unit.route_y = y
            end
            return unit.route_x, unit.route_y
        end
    end
    unit.route_x = nil
    return s.x, s.y
end

return M
