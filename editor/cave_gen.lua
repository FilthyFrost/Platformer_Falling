--[[
    Cave Generation for Cave Fall Editor
    Multi-phase grid-based algorithm (ported from HTML cave engine).
    Guarantees full connectivity via main corridor + expansion.
    Grid: 18 cols × 32 rows of 6px cells = 108×192 world.
]]

local CaveGen = {}

local WORLD_W = 108
local WORLD_H = 192
local CELL = 6
local COLS = 18
local ROWS = 32

-- Default generation parameters
CaveGen.defaults = {
    seed = 0,
    pRect = 50,     -- rectangle room probability (0-100)
    pStair = 60,    -- stair edge carving probability (0-100)
    pThumb = 40,    -- thumb bump probability (0-100)
    pIsland = 30,   -- island obstacle probability (0-100)
}

-----------------------------------------------------------
-- Stamp shapes (rasterize to ImageData at pixel level)
-----------------------------------------------------------

-- Fill a rectangle of cells starting at grid (c, r) with given size
local function fillCellRect(imageData, c, r, w, h, value)
    local rv, gv, bv, av = 1, 1, 1, 1
    if not value then rv, gv, bv, av = 0, 0, 0, 0 end
    for cy = r, r + h - 1 do
        for cx = c, c + w - 1 do
            if cx >= 0 and cx < COLS and cy >= 0 and cy < ROWS then
                local px0 = cx * CELL
                local py0 = cy * CELL
                for py = py0, py0 + CELL - 1 do
                    for px = px0, px0 + CELL - 1 do
                        if px >= 0 and px < WORLD_W and py >= 0 and py < WORLD_H then
                            imageData:setPixel(px, py, rv, gv, bv, av)
                        end
                    end
                end
            end
        end
    end
end

-- Stamp a stair (right-angle triangle) into ImageData
local function stampStair(imageData, c, r, size, dir, value)
    local rv, gv, bv, av = 1, 1, 1, 1
    if not value then rv, gv, bv, av = 0, 0, 0, 0 end
    local px0 = c * CELL
    local py0 = r * CELL
    local sizePx = size * CELL

    for py = 0, sizePx - 1 do
        for px = 0, sizePx - 1 do
            local inside = false
            if dir == "TL" then inside = (px + py < sizePx)
            elseif dir == "TR" then inside = ((sizePx - 1 - px) + py < sizePx)
            elseif dir == "BL" then inside = (px + (sizePx - 1 - py) < sizePx)
            elseif dir == "BR" then inside = ((sizePx - 1 - px) + (sizePx - 1 - py) < sizePx)
            end
            if inside then
                local wx = px0 + px
                local wy = py0 + py
                if wx >= 0 and wx < WORLD_W and wy >= 0 and wy < WORLD_H then
                    imageData:setPixel(wx, wy, rv, gv, bv, av)
                end
            end
        end
    end
end

-- Stamp a thumb (semicircle bump) into ImageData
local function stampThumb(imageData, c, r, size, dir, value)
    local rv, gv, bv, av = 1, 1, 1, 1
    if not value then rv, gv, bv, av = 0, 0, 0, 0 end
    local px0 = c * CELL
    local py0 = r * CELL
    local sizePx = size * CELL
    local radius = sizePx / 2

    for py = 0, sizePx - 1 do
        for px = 0, sizePx - 1 do
            local inside = false
            if dir == "TL" then
                -- UP bump: semicircle top + rect bottom
                local cx, cy = radius, radius
                if py >= radius then
                    inside = true  -- bottom half is full rect
                else
                    local dx = px - cx
                    local dy = py - cy
                    inside = (dx * dx + dy * dy <= radius * radius)
                end
            elseif dir == "TR" then
                -- RIGHT bump: semicircle right + rect left
                local cx, cy = sizePx - radius, radius
                if px < radius then
                    inside = true
                else
                    local dx = px - cx
                    local dy = py - cy
                    inside = (dx * dx + dy * dy <= radius * radius)
                end
            elseif dir == "BL" then
                -- DOWN bump: semicircle bottom + rect top
                local cx, cy = radius, sizePx - radius
                if py < radius then
                    inside = true
                else
                    local dx = px - cx
                    local dy = py - cy
                    inside = (dx * dx + dy * dy <= radius * radius)
                end
            elseif dir == "BR" then
                -- LEFT bump: semicircle left + rect right
                local cx, cy = radius, radius
                if px >= radius then
                    inside = true
                else
                    local dx = px - cx
                    local dy = py - cy
                    inside = (dx * dx + dy * dy <= radius * radius)
                end
            end
            if inside then
                local wx = px0 + px
                local wy = py0 + py
                if wx >= 0 and wx < WORLD_W and wy >= 0 and wy < WORLD_H then
                    imageData:setPixel(wx, wy, rv, gv, bv, av)
                end
            end
        end
    end
end

-----------------------------------------------------------
-- Public stamp API (used by editor for manual placement)
-----------------------------------------------------------

function CaveGen.stampRect(imageData, col, row, size, value)
    fillCellRect(imageData, col, row, size, size, value)
end

function CaveGen.stampStair(imageData, col, row, size, dir, value)
    stampStair(imageData, col, row, size, dir, value)
end

function CaveGen.stampThumb(imageData, col, row, size, dir, value)
    stampThumb(imageData, col, row, size, dir, value)
end

function CaveGen.stampIsland(imageData, col, row, size)
    -- White buffer (size + 2 cells, offset -1)
    fillCellRect(imageData, col - 1, row - 1, size + 2, size + 2, true)
    -- Black center
    fillCellRect(imageData, col, row, size, size, false)
end

-----------------------------------------------------------
-- Main generation algorithm (multi-phase, from HTML)
-----------------------------------------------------------

function CaveGen.generate(params)
    params = params or {}
    local p = {}
    for k, v in pairs(CaveGen.defaults) do p[k] = params[k] or v end

    local seed = p.seed ~= 0 and p.seed or os.time()
    math.randomseed(seed)

    -- Logical grid: 0 = wall (black), 1 = cave (white)
    local grid = {}
    for c = 0, COLS - 1 do
        grid[c] = {}
        for r = 0, ROWS - 1 do
            grid[c][r] = 0
        end
    end

    local function carve(c, r, w, h)
        for i = 0, w - 1 do
            for j = 0, h - 1 do
                if c + i >= 0 and c + i < COLS and r + j >= 0 and r + j < ROWS then
                    grid[c + i][r + j] = 1
                end
            end
        end
    end

    -- Phase 1: Main corridor (guaranteed connectivity spine)
    local cx = 6
    for cy = 2, ROWS - 3 do
        carve(cx, cy, 6, 4)
        local drift = math.random()
        if drift < 0.4 then cx = cx + 1
        elseif drift < 0.8 then cx = cx - 1 end
        cx = math.max(2, math.min(COLS - 8, cx))
    end

    -- Phase 2: Room expansion (only if touching existing cave)
    local numRects = math.floor(p.pRect / 100 * 25)
    for i = 1, numRects do
        local w = 4 + math.floor(math.random() * 5)
        local h = 4 + math.floor(math.random() * 5)
        local x = 2 + math.floor(math.random() * (COLS - w - 2))
        local y = 2 + math.floor(math.random() * (ROWS - h - 2))
        -- Only place if overlapping existing cave (ensures connectivity)
        local overlaps = false
        for dx = 0, w - 1 do
            for dy = 0, h - 1 do
                if grid[x + dx] and grid[x + dx][y + dy] == 1 then
                    overlaps = true
                end
            end
        end
        if overlaps then carve(x, y, w, h) end
    end

    -- Phase 3: Edge carving (stairs and thumbs at walls)
    for c = 1, COLS - 2 do
        for r = 1, ROWS - 2 do
            if grid[c][r] ~= 1 then goto continue end
            local n = (grid[c][r - 1] == 0)
            local s = (grid[c][r + 1] == 0)
            local w = (grid[c - 1][r] == 0)
            local e = (grid[c + 1][r] == 0)

            -- Stair: carve at corners where two walls meet
            local isCorner = (n and w) or (n and e) or (s and w) or (s and e)
            if isCorner and math.random() * 100 < p.pStair then
                grid[c][r] = 2  -- mark as carved
                goto continue
            end

            -- Thumb: bump on flat walls (ensure passage stays open)
            local isWall = (n and not s and not w and not e) or
                          (s and not n and not w and not e) or
                          (w and not n and not s and not e) or
                          (e and not n and not s and not w)
            if isWall and math.random() * 100 < p.pThumb then
                if w and grid[c + 1] and grid[c + 1][r] == 1 and grid[c + 2] and grid[c + 2][r] == 1 then
                    grid[c][r] = 2
                elseif e and grid[c - 1] and grid[c - 1][r] == 1 and grid[c - 2] and grid[c - 2][r] == 1 then
                    grid[c][r] = 2
                elseif n and grid[c][r + 1] == 1 and grid[c][r + 2] and grid[c][r + 2] == 1 then
                    grid[c][r] = 2
                elseif s and grid[c][r - 1] == 1 and grid[c][r - 2] and grid[c][r - 2] == 1 then
                    grid[c][r] = 2
                end
            end
            ::continue::
        end
    end

    -- Phase 4: Safe islands (black blocks in pure white areas)
    local numIslands = math.floor(p.pIsland / 100 * 12)
    for i = 1, numIslands do
        local c = 4 + math.floor(math.random() * (COLS - 8))
        local r = 4 + math.floor(math.random() * (ROWS - 8))
        -- Check 3x3 area is all pure white
        local safe = true
        for dx = -1, 1 do
            for dy = -1, 1 do
                if grid[c + dx][r + dy] ~= 1 then safe = false end
            end
        end
        if safe then
            local w = 2 + math.floor(math.random() * 3)
            local h = 2 + math.floor(math.random() * 3)
            -- Place island (mark as special)
            for dx = 0, w - 1 do
                for dy = 0, h - 1 do
                    grid[c + dx][r + dy] = 3  -- island (will render as black)
                end
            end
            -- Mark surrounding as non-island-placeable
            for dx = -1, w do
                for dy = -1, h do
                    if grid[c + dx] and grid[c + dx][r + dy] == 1 then
                        grid[c + dx][r + dy] = 4  -- used, stays white but can't get islands
                    end
                end
            end
        end
    end

    -- Phase 5: Guarantee spawn area (top-left 3×2 always open)
    carve(2, 2, 6, 4)
    -- Make sure spawn cells aren't islands
    for dx = 0, 5 do
        for dy = 0, 3 do
            if grid[2 + dx] and grid[2 + dx][2 + dy] == 3 then grid[2 + dx][2 + dy] = 1 end
        end
    end

    -- Convert grid to ImageData
    local imageData = love.image.newImageData(WORLD_W, WORLD_H)
    -- Start all black
    for py = 0, WORLD_H - 1 do
        for px = 0, WORLD_W - 1 do
            imageData:setPixel(px, py, 0, 0, 0, 0)
        end
    end

    -- Paint white cells
    for c = 0, COLS - 1 do
        for r = 0, ROWS - 1 do
            local v = grid[c][r]
            if v == 1 or v == 4 then
                -- White (cave) — fill full cell
                fillCellRect(imageData, c, r, 1, 1, true)
            elseif v == 2 then
                -- Carved cell: apply stair/thumb at pixel level
                -- Determine which direction based on neighbors
                local n = (r > 0 and grid[c][r - 1] == 0)
                local s = (r < ROWS - 1 and grid[c][r + 1] == 0)
                local w = (c > 0 and grid[c - 1][r] == 0)
                local e = (c < COLS - 1 and grid[c + 1][r] == 0)

                -- Fill cell first (white base)
                fillCellRect(imageData, c, r, 1, 1, true)
                -- Then carve the corner/edge with black
                if n and w then stampStair(imageData, c, r, 1, "TL", false)
                elseif n and e then stampStair(imageData, c, r, 1, "TR", false)
                elseif s and w then stampStair(imageData, c, r, 1, "BL", false)
                elseif s and e then stampStair(imageData, c, r, 1, "BR", false)
                elseif w then stampThumb(imageData, c, r, 1, "TR", false)
                elseif e then stampThumb(imageData, c, r, 1, "BR", false)
                elseif n then stampThumb(imageData, c, r, 1, "BL", false)
                elseif s then stampThumb(imageData, c, r, 1, "TL", false)
                end
            elseif v == 3 then
                -- Island: stays black (already 0)
            end
        end
    end

    -- Compute player start (center of spawn area)
    local playerStart = {
        x = (2 * CELL) + math.floor(6 * CELL / 2),  -- center of spawn area
        y = (2 * CELL) + math.floor(4 * CELL / 2),   -- center of spawn area
    }

    return imageData, {
        seed = seed,
        playerStart = playerStart,
    }
end

-----------------------------------------------------------
-- Utility
-----------------------------------------------------------

function CaveGen.computeFillPercent(imageData)
    local W = imageData:getWidth()
    local H = imageData:getHeight()
    local count = 0
    for y = 0, H - 1 do
        for x = 0, W - 1 do
            local _, _, _, a = imageData:getPixel(x, y)
            if a > 0.5 then count = count + 1 end
        end
    end
    return count / (W * H)
end

-- Get grid cell from world pixel
function CaveGen.worldToCell(wx, wy)
    return math.floor(wx / CELL), math.floor(wy / CELL)
end

-- Get world pixel from grid cell (top-left corner)
function CaveGen.cellToWorld(col, row)
    return col * CELL, row * CELL
end

return CaveGen
