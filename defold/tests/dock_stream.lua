local art = require "game.dock_art"
local size = art.size
local map = art.new(17)
local width, height = 432, 768
local nodes, texture_changes = 0, 0
vmath = {
    vector3 = function(x, y) return {x=x or 0,y=y or 0} end,
    vector4 = function() return {} end,
}
gui = {
    new_box_node = function()
        nodes = nodes+1
        return {enabled=true}
    end,
    set_enabled = function(n, enabled) n.enabled=enabled end,
    set_parent = function(n, parent) n.parent=parent end,
    set_position = function(n, p) n.pos=p end,
    set_size = function(n, s) n.size=s end,
    set_layer = function(n, layer) n.layer=layer end,
    set_size_mode = function() end,
    set_texture = function() end,
    set_color = function() end,
    play_flipbook = function(n, id) n.id=id; texture_changes=texture_changes+1 end,
}
local dock_stream = require "game.dock_stream"
local stream = dock_stream.new(width,height)

local function check(x,y)
    dock_stream.update(stream,map,x,y)
    assert(stream.root.enabled and stream.root.pos.x == -x and stream.root.pos.y == -y)
    -- All sectors touching the visible bounds or the read-ahead margin have a
    -- complete floor tile, including when moving through negative coordinates.
    for col=math.floor((x-180)/size),math.floor((x+width+180)/size) do
        for row=math.floor((y-180)/size),math.floor((y+height+180)/size) do
            local floor = stream.columns[col][row][1]
            assert(floor.enabled and floor.parent == stream.root and floor.layer == "floor")
            assert(floor.id == art.sector(map,col,row).floor)
            assert(floor.pos.x == (col+.5)*size and floor.pos.y == (row+.5)*size)
            assert(floor.size.x > size and floor.size.y > size)
        end
    end
end

check(-216,-361)
local first = stream.columns[0][0][1]
local initial_changes = texture_changes
check(-215,-360)
assert(texture_changes == initial_changes, "scrolling within the loaded area must not touch the atlas")
assert(stream.columns[0][0][1] == first)
for i=1,1500 do check(i*33,-i*29) end
for i=1500,1,-1 do check(-i*29,i*31) end
check(-216,-361)
local old_map = map
local previous_changes = texture_changes
map = art.new(641)
check(-216,-361)
assert(stream.map ~= old_map and texture_changes > previous_changes)
assert(nodes <= 1+20*6, "GUI nodes must be reused as the map scrolls")
dock_stream.hide(stream)
assert(not stream.root.enabled)
check(-216,-361)
print("Dock streaming: complete floor past all four edges, stable atlas use and bounded GUI pool passed")
