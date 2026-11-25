local art = require "game.dock_art"

local M = {}
local floor = math.floor
local size, margin = art.size, art.preload
local white = vmath.vector4(1, 1, 1, 1)

function M.new(width, height)
    local root = gui.new_box_node(vmath.vector3(), vmath.vector3())
    gui.set_enabled(root, false)
    return {root = root, width = width, height = height, columns = {}, free = {}}
end

function M.hide(stream)
    gui.set_enabled(stream.root, false)
    stream.visible = false
end

local function load_sector(stream, col, row)
    local nodes = table.remove(stream.free) or {}
    local used = 0
    art.draw_sector(stream.map, col, row, function(id, x, y, w, h, layer)
        used = used + 1
        local node = nodes[used]
        if not node then
            node = gui.new_box_node(vmath.vector3(), vmath.vector3())
            gui.set_size_mode(node, gui.SIZE_MODE_MANUAL)
            gui.set_parent(node, stream.root, false)
            gui.set_texture(node, "dock_sectors")
            gui.set_color(node, white)
            nodes[used] = node
        end
        gui.set_enabled(node, true)
        gui.set_position(node, vmath.vector3(x, y, 0))
        gui.set_size(node, vmath.vector3(w, h, 0))
        gui.set_layer(node, layer)
        gui.play_flipbook(node, id)
    end)
    return nodes
end

function M.update(stream, map, left, bottom)
    local changed_map = stream.map ~= map
    if not changed_map and stream.left == left and stream.bottom == bottom and stream.visible then return end
    gui.set_position(stream.root, vmath.vector3(-left, -bottom, 0))
    stream.map, stream.left, stream.bottom = map, left, bottom
    local c0, r0 = floor((left - margin) / size), floor((bottom - margin) / size)
    local c1 = floor((left + stream.width + margin) / size)
    local r1 = floor((bottom + stream.height + margin) / size)
    if changed_map or stream.c0 ~= c0 or stream.c1 ~= c1 or stream.r0 ~= r0 or stream.r1 ~= r1 then
        local columns, free = stream.columns, stream.free
        for col, rows in pairs(columns) do
            for row, nodes in pairs(rows) do
                if changed_map or col < c0 or col > c1 or row < r0 or row > r1 then
                    for _, node in ipairs(nodes) do gui.set_enabled(node, false) end
                    free[#free + 1] = nodes
                    rows[row] = nil
                end
            end
            if next(rows) == nil then columns[col] = nil end
        end
        for col = c0, c1 do
            local rows = columns[col] or {}
            columns[col] = rows
            for row = r0, r1 do
                if not rows[row] then rows[row] = load_sector(stream, col, row) end
            end
        end
        stream.c0, stream.c1, stream.r0, stream.r1 = c0, c1, r0, r1
    end
    if not stream.visible then
        gui.set_enabled(stream.root, true)
        stream.visible = true
    end
end

return M
