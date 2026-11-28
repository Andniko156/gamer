local M = {
    gap = 56,
    height = 352,
    insert_height = 76,
    join_inset = 17,
    opening = 112,
    rail = 16,
    width = 288
}
M.period = M.width + M.gap
M.start_x = M.period + M.width / 2
M.insert_top = (M.height - M.insert_height) / 2
local abs = math.abs
local floor = math.floor
local max = math.max
local min = math.min
local decks = {
    {
        floor = "deck_wood",

        props = {
            {
                "cargo_pipe",
                115,
                38,
                124,
                24,
                12
            },
            {
                "crate_stack",
                69,
                78,
                48,
                44,
                43,
                15,
                11
            },
            {
                "pressure_barrel",
                116,
                80,
                32,
                42,
                41,
                10,
                10
            },
            {
                "rope_winch",
                165,
                74,
                48,
                34,
                33,
                15,
                8
            }
        }
    },
    {
        floor = "deck_steel",
        machinery = true,


        props = {
            {
                "cargo_pipe",
                144,
                31,
                222,
                28,
                14
            },
            {
                "engine_tank",
                56,
                79,
                46,
                99,
                97,
                15,
                16
            },
            {
                "engine_tank",
                232,
                79,
                46,
                99,
                97,
                15,
                16
            },
            {
                "engine_wheel",
                144,
                100,
                122,
                128,
                126,
                49,
                22
            },
            {
                "steam_grate",
                56,
                111,
                53,
                30,
                15
            },
            {
                "steam_grate",
                232,
                111,
                53,
                30,
                15
            },
            {
                "burner_grate",
                144,
                303,
                112,
                37,
                18
            }
        },
        vents = {
            {
                56,
                2
            },
            {
                232,
                2
            }
        }
    },
    {

        floor = "deck_wood",

        props = {
            {
                "cargo_pipe",
                134,
                38,
                131,
                24,
                12
            },
            {
                "helm_wheel",
                79,
                82,
                42,
                65,
                63,
                14,
                9
            },
            {
                "helm_console",
                139,
                79,
                62,
                54,
                53,
                20,
                12
            },
            {
                "pennant",
                194,
                83,
                34,
                61,
                59
            },
            {
                "maintenance_hatch",
                232,
                285,
                40,
                30,
                15
            }
        },
        console_glow = {
            139,
            54
        }
    }
}

for _, deck in ipairs(decks) do
    deck.solids = {}

    for _, p in ipairs(deck.props) do
        local _, x, y, _, _, _, half_width, depth = unpack(p)

        if half_width then
            y = M.height / 2 - y
            deck.solids[#deck.solids + 1] = {
                x - half_width,
                x + half_width,
                y - 2,
                y + depth
            }
        end
    end
end

function M.deck(section)
    return decks[section % #decks + 1]
end

function M.blocked(x, y, radius)
    if abs(y) + radius > M.height / 2 - M.rail then
        return true
    end

    for section = floor((x - radius) / M.period), floor((x + radius) / M.period) do
        local z = x - section * M.period

        for _, box in ipairs(M.deck(section).solids) do
            local dx = max(0, box[1] - z, z - box[2])
            local dy = max(0, box[3] - y, y - box[4])

            if dx * dx + dy * dy < radius * radius then
                return true
            end
        end
    end

    return false
end

function M.floor_position(x, y, radius)
    local limit = M.height / 2 - M.rail - radius
    y = max(-limit, min(limit, y))

    return x, not M.blocked(x, y, radius) and y or 0
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
    local section = floor(x / M.period)
    local z = x - section * M.period
    local dx = tx - x
    local dy = ty - y
    local target_z = tx % M.period
    local same_deck = section == floor(tx / M.period) and z < M.width and target_z < M.width
    local clearance = M.opening / 2 - radius - 4

    if same_deck or clearance < abs(ty) then
        local ux = dx - dy * flank
        local uy = dy + dx * flank
        local distance = math.sqrt(ux * ux + uy * uy)
        local ahead = min(26, distance) / max(0.001, distance)

        if not M.blocked(x + ux * ahead, y + uy * ahead, radius) then
            return x + ux, y + uy
        end
    end

    lane = max(-clearance, min(clearance, lane or 0))

    if same_deck then
        lane = 0
    end

    if M.width <= target_z and abs(dx) < M.gap then
        lane = max(-clearance, min(clearance, ty))
    end

    local error = lane - y
    local approach = M.width <= z or min(z, M.width - z) < 36

    if clearance < abs(y) or (approach or same_deck) and abs(error) > 6 then
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
