local M = {size = 300, preload = 180}

-- Coordinates are relative to the center of the floor markings. Solid bounds
-- describe the bases at floor level, so tall objects can overlap the hero visually.
local groups = {
    repair = {
        sprites = {
            {"repair_marks", 0, 0, 174, 98, "inlays"},
            {"workbench", -22, 7, 86, 54},
            {"breaker_cabinet", 42, 16, 36, 73},
        },
        solid = { -3, -9, 61, 17 },
    },
    pump = {
        sprites = {
            {"pump_marks", 0, 0, 174, 86, "inlays"},
            {"floor_duct", 11, -9, 36, 13, "inlays"},
            {"drain_grate", 47, -9, 54, 31, "inlays"},
            {"pump_station", -25, 3, 73, 54},
        },
        solid = { -25, -9, 31, 16 },
    },
    steam = {
        sprites = {
            {"steam_marks", 0, 0, 103, 103, "inlays"},
            {"steam_vent", 0, 0, 38, 38, "inlays"},
            {"pressure_gauge", 44, 13, 23, 55},
        },
        solid = { 44, -10, 9, 6 },
    },
    cargo = {
        sprites = {
            {"cargo_marks", 0, 0, 173, 79, "inlays"},
            {"tool_cart", -35, 3, 65, 50},
            {"crate_pallet", 36, 0, 64, 42},
        },
        solid = { 0, -7, 63, 15 },
    },
}
local opening = {groups.repair, groups.pump, groups.steam, groups.cargo}
local scattered = {groups.pump, groups.steam, groups.cargo}
local size, floor = M.size, math.floor
local prime, cache_width = 2147483647, 16
local floors = {"steel_floor_0", "steel_floor_1", "steel_floor_2", "steel_floor_3"}

-- A separate seed for each coordinate keeps generation independent of camera
-- direction and of random rolls for waves, loot and upgrades.
local function sector_random(seed, col, row)
    local n = (seed + (col % prime) * 4093 + (row % prime) * 65521) % prime
    n = (n * 48271 + 1) % prime
    return (n * 27617 + floor(n / 997)) % prime
end

function M.new(seed)
    local order = sector_random(seed % prime, 0, 0) % 8
    return {seed = seed % prime, order = order, sectors = {}}
end

function M.sector(map, col, row)
    local index = (col % cache_width) * cache_width + row % cache_width + 1
    local sector = map.sectors[index]
    if sector and sector.col == col and sector.row == row then return sector end
    local n = sector_random(map.seed, col, row)
    local group
    local x, y = 101 + n % 99, 76 + floor(n / 128) % 149
    if col >= -1 and col <= 0 and row >= -1 and row <= 0 then
        local axis = (row + 1) * 2 + col + 1
        group = opening[((map.order % 4) + (map.order < 4 and axis or axis * 3)) % 4 + 1]
        x = 119 + n % 67
    else
        -- Two adjacent workstations share a baseline when this bay is selected.
        local bay = sector_random(map.seed, floor(col / 4), row)
        local first = floor(bay / 8) % 3
        local slot = col % 4 - first
        if bay % 4 == 0 and (slot == 0 or slot == 1) then
            group, x, y = groups.repair, 162 - 24 * slot, 97 + floor(bay / 32) % 109
        elseif n % 10 < 6 then
            group = scattered[floor(n / 16) % #scattered + 1]
        end
    end
    x, y = col * size + x, row * size + y
    sector = {}
    sector.col, sector.row, sector.group, sector.x, sector.y = col, row, group, x, y
    sector.floor = floors[floor(n / 8192) % #floors + 1]
    sector.vent = group == groups.steam
    if group then
        local b = group.solid
        sector.cx, sector.cy, sector.w, sector.h = x + b[1], y + b[2], b[3], b[4]
    end
    map.sectors[index] = sector
    return sector
end

function M.draw_sector(map, col, row, draw)
    local x, y = col * size, row * size
    local sector = M.sector(map, col, row)
    draw(sector.floor, x + size / 2, y + size / 2, size + 1, size + 1, "floor")
    if col % 4 == 0 then
        draw("service_lane", x, y + size / 2, 19, size + 1, "inlays")
    end
    local group, gx, gy = sector.group, sector.x, sector.y
    if group then
        for _, sprite in ipairs(group.sprites) do
            draw(sprite[1], gx + sprite[2], gy + sprite[3], sprite[4], sprite[5], sprite[6] or "fixtures")
        end
    end
end

return M
