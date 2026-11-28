local M = {
    gap = 56,
    base_height = 352,
    insert_height = 76 * 1.60,
    join_inset = 17,
    opening = 112 * 1.60,
    actor_foot_offset = 56 * 22 / 48,
    join_y = -40,
    start_y = -26
}
local abs = math.abs
local max = math.max
local min = math.min

-- Each compartment uses four aligned art layers. Furniture footprints are
-- measured at floor contact, in local coordinates from the far railing.
M.decks = {
    {
        art = "cargo", width = 684, bands = {161, 89, 102, 97},
        far_edge = 134, near_edge = 341,
        footprints = {
            {114, 151, 47, 20}, {221, 146, 25, 18},
            {348, 158, 83, 22}, {461, 151, 21, 16}, {554, 158, 43, 25},
            {159, 325, 66, 34}, {371, 340, 29, 21}, {515, 339, 92, 32}
        }
    },
    {
        art = "engine", width = 800, bands = {214, 75, 63, 79},
        far_edge = 153, near_edge = 342,
        footprints = {
            {54, 170, 29, 22}, {125, 168, 27, 19},
            {225, 178, 40, 25}, {400, 173, 91, 22},
            {578, 178, 42, 25}, {675, 170, 35, 22}, {755, 169, 34, 23},
            {126, 342, 55, 30}, {398, 340, 47, 35}, {672, 339, 59, 31}
        },
        vents = {{229, 58}, {583, 58}}
    },
    {
        art = "command", width = 464, bands = {165, 73, 114, 81},
        far_edge = 147, near_edge = 340,
        footprints = {
            {48, 165, 37, 24}, {130, 173, 32, 22}, {264, 175, 28, 20},
            {271, 339, 77, 48}, {381, 319, 20, 34}
        }
    }
}

local right = 0
local max_extension = 0
for _, deck in ipairs(M.decks) do
    deck.extension = (deck.near_edge - deck.far_edge) * .60
    max_extension = max(max_extension, deck.extension)
end
M.height = M.base_height + max_extension
M.insert_top = (M.height - M.insert_height) / 2 - M.join_y
for _, deck in ipairs(M.decks) do
    deck.x = right
    right = deck.x + deck.width + M.gap
    deck.solids = {}
    deck.near_edge = deck.near_edge + deck.extension
    for _, prop in ipairs(deck.footprints) do
        local x, v, half_width, depth = unpack(prop)
        if v >= deck.bands[1] + deck.bands[2] then v = v + deck.extension end
        local y = M.height / 2 - v
        deck.solids[#deck.solids + 1] = {x - half_width, x + half_width, y - 2, y + depth}
    end
end
M.end_x = right - M.gap
M.start_x = M.decks[2].x + M.decks[2].width / 2
M.joins = {}
local floor_regions = {}
for i = 1, #M.decks - 1 do
    local left, right_deck = M.decks[i], M.decks[i + 1]
    M.joins[i] = {
        x = left.x + left.width,
        width = M.gap,
        far_edge = max(left.far_edge, right_deck.far_edge),
        near_edge = min(left.near_edge, right_deck.near_edge)
    }
    floor_regions[#floor_regions + 1] = left
    floor_regions[#floor_regions + 1] = M.joins[i]
end
floor_regions[#floor_regions + 1] = M.decks[#M.decks]

local function deck_at(x)
    for i = #M.decks, 2, -1 do
        if x >= M.decks[i].x then return M.decks[i] end
    end
    return M.decks[1]
end

function M.floor_edges(x, radius)
    local far, near = 0, M.height
    for _, region in ipairs(floor_regions) do
        if region.x > x + radius then break end
        if x - radius <= region.x + region.width then
            far, near = max(far, region.far_edge), min(near, region.near_edge)
        end
    end
    return M.height / 2 - near, M.height / 2 - far
end

function M.blocked(x, y, radius)
    if x - radius < 0 or x + radius > M.end_x then
        return true
    end
    local lower, upper = M.floor_edges(x, radius)
    if y - radius < lower or y + radius > upper then
        return true
    end

    for _, deck in ipairs(M.decks) do
        local z = x - deck.x
        if z + radius >= 0 and z - radius <= deck.width then
            for _, box in ipairs(deck.solids) do
                local dx = max(0, box[1] - z, z - box[2])
                local dy = max(0, box[3] - y, y - box[4])

                if dx * dx + dy * dy < radius * radius then
                    return true
                end
            end
        end
    end

    return false
end

function M.floor_position(x, y, radius)
    x = max(radius, min(M.end_x - radius, x))
    local lower, upper = M.floor_edges(x, radius)
    y = max(lower + radius, min(upper - radius, y))

    return x, not M.blocked(x, y, radius) and y or M.start_y
end

function M.move(x, y, dx, dy, radius)
    local steps = max(1, math.ceil(max(abs(dx), abs(dy)) / 6))
    dy = dy / steps
    dx = dx / steps

    for _ = 1, steps do
        local nx = x + dx
        local ny = y + dy

        if not M.blocked(nx, ny, radius) then
            y = ny
            x = nx
        else
            if not M.blocked(nx, y, radius) then
                x = nx
            end

            if not M.blocked(x, ny, radius) then
                y = ny
            end
        end
    end

    return x, y
end

function M.route(x, y, tx, ty, radius, flank, lane)
    local deck = deck_at(x)
    local target_deck = deck_at(tx)
    local z = x - deck.x
    local dx = tx - x
    local dy = ty - y
    local target_z = tx - target_deck.x
    local same_deck = deck == target_deck and z < deck.width and target_z < deck.width
    local clearance = M.opening / 2 - radius - 4

    if same_deck or clearance < abs(ty - M.join_y) then
        local ux = dx - dy * flank
        local uy = dy + dx * flank
        local distance = math.sqrt(ux * ux + uy * uy)
        local ahead = min(26, distance) / max(0.001, distance)

        if not M.blocked(x + ux * ahead, y + uy * ahead, radius) then
            return x + ux, y + uy
        end
    end

    local low, high = M.join_y - clearance, M.join_y + clearance
    lane = max(low, min(high, M.join_y + (lane or 0)))

    if same_deck then
        lane = M.join_y
    end

    if target_deck.width <= target_z and abs(dx) < M.gap then
        lane = max(low, min(high, ty))
    end

    local error = lane - y
    local approach = deck.width <= z or min(z, deck.width - z) < 36

    if clearance < abs(y - M.join_y) or (approach or same_deck) and abs(error) > 6 then
        local step = max(-18, min(18, error))

        if not M.blocked(x, y + step, radius) then
            return x, lane
        end

        local direction = dx < 0 and -1 or 1

        for _, sign in ipairs({
            direction,
            -direction
        }) do
            for distance = 2, 108, 2 do
                local a = x + sign * distance

                if M.blocked(a, y, radius) then
                    break
                end

                if not M.blocked(a, y + step, radius) and not M.blocked(a, y + step * 2, radius) then
                    return a, y
                end
            end
        end

        return x, y
    end

    return tx, lane
end

return M
