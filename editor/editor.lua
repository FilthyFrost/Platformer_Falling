--[[
    Cave Fall Map Editor - Core Module
    Handles: state machine, canvas editing, input, undo/redo,
    entity placement, save/load, play test integration.
]]

local CaveGen = require("editor.cave_gen")
local json = require("editor.json")
local EditorUI = nil  -- loaded after init (circular dep avoidance)

local Editor = {}

------------------------------------------------------------
-- CONSTANTS
------------------------------------------------------------
local WORLD_W = 108
local WORLD_H = 192
local PANEL_X = 432
local PANEL_W = 368
local WINDOW_W = 800
local WINDOW_H = 854

-- View (zoom/pan) — computed dynamically via getCanvasOrigin()

-- Editor sub-states
local MODE = {
    DRAW = "DRAW",
    ENTITY = "ENTITY",
    LEVELS = "LEVELS",
}

-- Draw tools
local TOOL = {
    PEN = "PEN",
    ERASER = "ERASER",
    FILL = "FILL",
    LINE = "LINE",
    RECT = "RECT",
}

------------------------------------------------------------
-- STATE
------------------------------------------------------------
local state = {
    mode = MODE.DRAW,
    tool = TOOL.PEN,
    brushSize = 3,
    isPlayTesting = false,

    -- Canvas (the stencil being edited)
    canvas = nil,         -- love ImageData (108x192)
    displayImage = nil,   -- love Image (GPU texture for rendering)

    -- Entities
    playerStart = {x = 54, y = 60},
    platformXMin = 42,
    platformXMax = 66,
    bats = {},  -- list of {x=, y=}
    airWalls = {},  -- list of {x=, y=} invisible blockers (12px grid)
    voidBats = {},  -- list of {x=, y=}
    mirrorLines = {},  -- list of {x=, y=, length=}
    entitySubMode = "BAT",  -- "BAT" | "VOID_BAT" | "MIRROR_LINE" | "PLATFORM"

    -- Entity interaction
    selectedEntity = nil,  -- {type="bat"|"player"|"platform_*"|"mirrorLine_*", index=N}
    dragging = false,
    dragOffset = {x = 0, y = 0},

    -- Drawing state
    painting = false,
    paintButton = 0,  -- 1=paint, 2=erase
    lastPaintPos = nil,  -- {x, y} for line drawing

    -- Undo/Redo
    undoStack = {},
    redoStack = {},
    maxUndo = 50,

    -- File state
    currentMapName = "untitled",
    dirty = false,  -- has unsaved changes

    -- UI state
    showGrid = true,
    showGeneratePanel = false,
    generateParams = {
        seed = 0,
        pRect = 50,
        pStair = 60,
        pThumb = 40,
        pIsland = 30,
    },

    -- Level manager
    showLevelManager = false,
    levelSlots = {},  -- ordered list of map names assigned to levels

    -- Map list (loaded from editor_maps/)
    savedMaps = {},  -- list of {name=, path=}

    -- Game references (set via init)
    gameRefs = nil,

    -- View (zoom / pan)
    viewScale = 4,        -- pixels per world pixel (2-10)
    viewOffsetX = 0,      -- world-space X offset (pan)
    viewOffsetY = 0,      -- world-space Y offset (pan)
    panning = false,      -- middle mouse or space+drag active
    panStartX = 0,
    panStartY = 0,
    panStartOffX = 0,
    panStartOffY = 0,
    showHitboxes = true,  -- show collision body rectangles

    -- Cursor
    cursorWorldX = 0,
    cursorWorldY = 0,
    cursorInCanvas = false,

    -- Cell Stamp sub-mode
    drawSubMode = "FREE",           -- "FREE" | "CELL_STAMP"
    cellMode = "DIG",               -- "DIG" (white/cave) | "BUILD" (black/wall)
    cellStamp = "RECT",             -- "RECT" | "STAIR" | "THUMB" | "ISLAND"
    cellDir = "TL",                 -- "TL" | "TR" | "BL" | "BR"
    cellSize = 1,                   -- 1-4 cell multiplier
}

------------------------------------------------------------
-- INITIALIZATION
------------------------------------------------------------

function Editor.init(refs)
    state.gameRefs = refs
    -- Create blank canvas
    state.canvas = love.image.newImageData(WORLD_W, WORLD_H)
    Editor.rebuildDisplayImage()
    -- Load UI module
    EditorUI = require("editor.editor_ui")
    EditorUI.init(state, MODE, TOOL)
    -- Scan saved maps
    Editor.scanSavedMaps()
end

function Editor.enter()
    state.isPlayTesting = false
    state.mode = MODE.DRAW
    love.window.setMode(WINDOW_W, WINDOW_H, {resizable = true})
end

function Editor.exit()
    love.window.setMode(480, 854, {resizable = true})
end

------------------------------------------------------------
-- CANVAS MANAGEMENT
------------------------------------------------------------

function Editor.rebuildDisplayImage()
    if state.displayImage then state.displayImage:release() end
    state.displayImage = love.graphics.newImage(state.canvas)
    state.displayImage:setFilter("nearest", "nearest")
    -- Mark caches as needing recalc
    if EditorUI and EditorUI.markFillDirty then
        EditorUI.markFillDirty()
    end
    edgeCacheDirty = true
end

function Editor.clearCanvas()
    Editor.pushUndo()
    state.canvas = love.image.newImageData(WORLD_W, WORLD_H)
    Editor.rebuildDisplayImage()
    state.bats = {}
    state.mirrorLines = {}
    state.voidBats = {}
    state.playerStart = {x = 54, y = 60}
    state.platformXMin = 42
    state.platformXMax = 66
    state.dirty = true
end

function Editor.generateCave()
    Editor.pushUndo()
    local params = {
        seed = state.generateParams.seed,
        pRect = state.generateParams.pRect,
        pStair = state.generateParams.pStair,
        pThumb = state.generateParams.pThumb,
        pIsland = state.generateParams.pIsland,
    }
    local imageData, info = CaveGen.generate(params)
    state.canvas = imageData
    Editor.rebuildDisplayImage()
    state.playerStart = info.playerStart
    state.bats = {}
    state.dirty = true
    state.generateParams.seed = info.seed
end

------------------------------------------------------------
-- UNDO / REDO
------------------------------------------------------------

function Editor.pushUndo()
    local snapshot = love.image.newImageData(WORLD_W, WORLD_H)
    snapshot:paste(state.canvas, 0, 0, 0, 0, WORLD_W, WORLD_H)
    table.insert(state.undoStack, snapshot)
    if #state.undoStack > state.maxUndo then
        table.remove(state.undoStack, 1)
    end
    state.redoStack = {}
end

function Editor.undo()
    if #state.undoStack == 0 then return end
    -- Save current to redo
    local redoSnap = love.image.newImageData(WORLD_W, WORLD_H)
    redoSnap:paste(state.canvas, 0, 0, 0, 0, WORLD_W, WORLD_H)
    table.insert(state.redoStack, redoSnap)
    -- Restore from undo
    local snapshot = table.remove(state.undoStack)
    state.canvas:paste(snapshot, 0, 0, 0, 0, WORLD_W, WORLD_H)
    Editor.rebuildDisplayImage()
    state.dirty = true
end

function Editor.redo()
    if #state.redoStack == 0 then return end
    -- Save current to undo (without clearing redo)
    local undoSnap = love.image.newImageData(WORLD_W, WORLD_H)
    undoSnap:paste(state.canvas, 0, 0, 0, 0, WORLD_W, WORLD_H)
    table.insert(state.undoStack, undoSnap)
    -- Restore from redo
    local snapshot = table.remove(state.redoStack)
    state.canvas:paste(snapshot, 0, 0, 0, 0, WORLD_W, WORLD_H)
    Editor.rebuildDisplayImage()
    state.dirty = true
end

------------------------------------------------------------
-- CELL STAMP HELPERS
------------------------------------------------------------

local CELL = 6
local COLS = 18
local ROWS = 32

local function cellStampApply(wx, wy)
    local col = math.floor(wx / CELL)
    local row = math.floor(wy / CELL)
    if col < 0 or col >= COLS or row < 0 or row >= ROWS then return end

    Editor.pushUndo()
    local CaveGen = require("editor.cave_gen")
    local size = state.cellSize
    local value = (state.cellMode == "DIG")  -- true=white(cave), false=black(wall)

    if state.cellStamp == "RECT" then
        CaveGen.stampRect(state.canvas, col, row, size, value)
    elseif state.cellStamp == "STAIR" then
        CaveGen.stampStair(state.canvas, col, row, size, state.cellDir, value)
    elseif state.cellStamp == "THUMB" then
        CaveGen.stampThumb(state.canvas, col, row, size, state.cellDir, value)
    elseif state.cellStamp == "ISLAND" then
        CaveGen.stampIsland(state.canvas, col, row, size)
    end

    Editor.rebuildDisplayImage()
    state.dirty = true
end

------------------------------------------------------------
-- DRAWING TOOLS
------------------------------------------------------------

-- Paint a circle of pixels at (wx, wy) in world coords
local function paintCircle(wx, wy, radius, value)
    local r, g, b, a
    if value then
        r, g, b, a = 1, 1, 1, 1
    else
        r, g, b, a = 0, 0, 0, 0
    end
    for dy = -radius, radius do
        for dx = -radius, radius do
            if dx * dx + dy * dy <= radius * radius then
                local px, py = wx + dx, wy + dy
                if px >= 0 and px < WORLD_W and py >= 0 and py < WORLD_H then
                    state.canvas:setPixel(px, py, r, g, b, a)
                end
            end
        end
    end
end

-- Bresenham line between two points, painting at each step
local function paintLine(x0, y0, x1, y1, radius, value)
    local dx = math.abs(x1 - x0)
    local dy = math.abs(y1 - y0)
    local sx = x0 < x1 and 1 or -1
    local sy = y0 < y1 and 1 or -1
    local err = dx - dy
    while true do
        paintCircle(x0, y0, radius, value)
        if x0 == x1 and y0 == y1 then break end
        local e2 = 2 * err
        if e2 > -dy then err = err - dy; x0 = x0 + sx end
        if e2 < dx then err = err + dx; y0 = y0 + sy end
    end
end

-- Flood fill from a point
local function floodFill(startX, startY, value)
    if startX < 0 or startX >= WORLD_W or startY < 0 or startY >= WORLD_H then return end
    local _, _, _, startA = state.canvas:getPixel(startX, startY)
    local startFilled = (startA > 0.5)
    if startFilled == value then return end  -- already the target value

    local r, g, b, a
    if value then
        r, g, b, a = 1, 1, 1, 1
    else
        r, g, b, a = 0, 0, 0, 0
    end

    local queue = {{startX, startY}}
    local head = 1
    local visited = {}
    visited[startY * WORLD_W + startX] = true

    while head <= #queue do
        local pt = queue[head]
        head = head + 1
        local px, py = pt[1], pt[2]
        state.canvas:setPixel(px, py, r, g, b, a)

        for _, d in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
            local nx, ny = px + d[1], py + d[2]
            if nx >= 0 and nx < WORLD_W and ny >= 0 and ny < WORLD_H then
                local key = ny * WORLD_W + nx
                if not visited[key] then
                    local _, _, _, na = state.canvas:getPixel(nx, ny)
                    local nFilled = (na > 0.5)
                    if nFilled == startFilled then
                        visited[key] = true
                        table.insert(queue, {nx, ny})
                    end
                end
            end
        end
    end
end

------------------------------------------------------------
-- COORDINATE CONVERSION (dynamic zoom/pan)
------------------------------------------------------------

-- Compute the canvas origin on screen given current zoom/pan
local function getCanvasOrigin()
    local scale = state.viewScale
    -- Canvas area is left of PANEL_X, centered vertically
    local canvasAreaW = PANEL_X
    local canvasAreaH = WINDOW_H
    local visibleW = WORLD_W * scale
    local visibleH = WORLD_H * scale
    -- Center the view in the canvas area, then apply pan offset
    local ox = (canvasAreaW - visibleW) / 2 - state.viewOffsetX * scale
    local oy = (canvasAreaH - visibleH) / 2 - state.viewOffsetY * scale
    return ox, oy, scale
end

local function screenToWorld(sx, sy)
    local ox, oy, scale = getCanvasOrigin()
    local wx = math.floor((sx - ox) / scale)
    local wy = math.floor((sy - oy) / scale)
    return wx, wy
end

local function worldToScreen(wx, wy)
    local ox, oy, scale = getCanvasOrigin()
    return ox + wx * scale, oy + wy * scale
end

local function isInCanvas(sx, sy)
    if sx >= PANEL_X then return false end  -- in UI panel
    local wx, wy = screenToWorld(sx, sy)
    return wx >= 0 and wx < WORLD_W and wy >= 0 and wy < WORLD_H
end

------------------------------------------------------------
-- ENTITY HELPERS
------------------------------------------------------------

-- Auto-derive platform bounds: smart detection
-- "Can stand here?" = body not in wall AND has surface support within 12px below
local function derivePlatformBounds(playerX, playerY)
    local px = math.floor(playerX)
    local py = math.floor(playerY)
    if py < 0 or py >= WORLD_H then return px - 3, px + 3 end

    -- Check if player position is inside cave
    local _, _, _, a = state.canvas:getPixel(
        math.max(0, math.min(WORLD_W - 1, px)),
        math.max(0, math.min(WORLD_H - 1, py)))
    if a < 0.5 then
        return math.max(0, px - 3), math.min(WORLD_W - 1, px + 3)
    end

    -- "Can stand at X?" check: body not in wall + has ground support within 12px below
    local function canStandAt(testX)
        if testX < 0 or testX >= WORLD_W then return false end
        -- Body check: pixel at player center Y must be inside cave
        local _, _, _, bodyA = state.canvas:getPixel(testX, math.min(WORLD_H - 1, py))
        if bodyA < 0.5 then return false end  -- wall
        -- Surface support: scan Y+3 to Y+12, need at least one solid pixel below
        local hasSurface = false
        for checkY = py + 3, math.min(WORLD_H - 1, py + 12) do
            local _, _, _, belowA = state.canvas:getPixel(testX, checkY)
            if belowA > 0.5 then
                hasSurface = true
                break
            end
        end
        if not hasSurface then return false end  -- cliff/abyss
        return true
    end

    -- Expand left
    local xMin = px
    while xMin > 0 and canStandAt(xMin - 1) do
        xMin = xMin - 1
    end

    -- Expand right
    local xMax = px
    while xMax < WORLD_W - 1 and canStandAt(xMax + 1) do
        xMax = xMax + 1
    end

    return xMin, xMax
end

local function findEntityAt(wx, wy)
    -- Check player start (3px radius)
    local ps = state.playerStart
    if math.abs(wx - ps.x) < 3 and math.abs(wy - ps.y) < 3 then
        return {type = "player", index = 0}
    end
    -- Check air walls (3px radius)
    for i, aw in ipairs(state.airWalls) do
        if math.abs(wx - aw.x) < 3 and math.abs(wy - aw.y) < 3 then
            return {type = "airWall", index = i}
        end
    end
    -- Check bats (3px radius)
    for i, bat in ipairs(state.bats) do
        if math.abs(wx - bat.x) < 3 and math.abs(wy - bat.y) < 3 then
            return {type = "bat", index = i}
        end
    end
    -- Check void bats (3px radius)
    for i, vb in ipairs(state.voidBats) do
        if math.abs(wx - vb.x) < 3 and math.abs(wy - vb.y) < 3 then
            return {type = "voidBat", index = i}
        end
    end
    -- Check mirror lines (4px vertical tolerance, endpoint handles 6px)
    for i, ml in ipairs(state.mirrorLines) do
        if math.abs(wy - ml.y) < 4 and wx >= ml.x - 4 and wx <= ml.x + ml.length + 4 then
            if math.abs(wx - ml.x) < 6 then
                return {type = "mirrorLine_left", index = i}
            elseif math.abs(wx - (ml.x + ml.length)) < 6 then
                return {type = "mirrorLine_right", index = i}
            else
                return {type = "mirrorLine_body", index = i}
            end
        end
    end
    return nil
end

------------------------------------------------------------
-- FILE I/O
------------------------------------------------------------

local function getSourcePath()
    return love.filesystem.getSource()
end

local function ensureDir(path)
    os.execute('mkdir -p "' .. path .. '"')
end

function Editor.scanSavedMaps()
    state.savedMaps = {}
    local mapsDir = getSourcePath() .. "/editor_maps"
    ensureDir(mapsDir)

    -- Use love.filesystem to list (it sees the source directory)
    local items = love.filesystem.getDirectoryItems("editor_maps")
    for _, name in ipairs(items) do
        local info = love.filesystem.getInfo("editor_maps/" .. name)
        if info and info.type == "directory" then
            table.insert(state.savedMaps, {name = name, path = "editor_maps/" .. name})
        end
    end
end

function Editor.saveMap(name)
    name = name or state.currentMapName
    local basePath = getSourcePath() .. "/editor_maps/" .. name
    ensureDir(basePath)

    -- Save stencil PNG
    local fileData = state.canvas:encode("png")
    local f = io.open(basePath .. "/stencil.png", "wb")
    if f then
        f:write(fileData:getString())
        f:close()
    end

    -- Save metadata
    local meta = {
        name = name,
        playerStart = state.playerStart,
        platformXMin = state.platformXMin,
        platformXMax = state.platformXMax,
        bats = state.bats,
        airWalls = state.airWalls,
        voidBats = state.voidBats,
        mirrorLines = state.mirrorLines,
    }
    local jsonStr = json.encodePretty(meta)
    f = io.open(basePath .. "/meta.json", "w")
    if f then
        f:write(jsonStr)
        f:close()
    end

    state.currentMapName = name
    state.dirty = false
    Editor.scanSavedMaps()
end

function Editor.loadMap(name)
    local basePath = "editor_maps/" .. name

    -- Load stencil
    local stencilPath = basePath .. "/stencil.png"
    if love.filesystem.getInfo(stencilPath) then
        Editor.pushUndo()
        state.canvas = love.image.newImageData(stencilPath)
        Editor.rebuildDisplayImage()
    end

    -- Load metadata
    local metaPath = basePath .. "/meta.json"
    if love.filesystem.getInfo(metaPath) then
        local content = love.filesystem.read(metaPath)
        if content then
            local meta = json.decode(content)
            if meta.playerStart then state.playerStart = meta.playerStart end
            if meta.platformXMin then state.platformXMin = meta.platformXMin end
            if meta.platformXMax then state.platformXMax = meta.platformXMax end
            if meta.bats then state.bats = meta.bats end
            if meta.airWalls then state.airWalls = meta.airWalls end
            if meta.mirrorLines then state.mirrorLines = meta.mirrorLines end
            if meta.voidBats then state.voidBats = meta.voidBats end
        end
    end

    state.currentMapName = name
    state.dirty = false
end

-- Load external PNG file as stencil (from HTML cave generator export)
-- Uses macOS file picker to let user select any PNG from disk
function Editor.loadExternalPNG(filepath)
    local imageData = nil

    if filepath then
        -- Load from specified path using io.open (bypasses LÖVE sandbox)
        local f = io.open(filepath, "rb")
        if f then
            local data = f:read("*a")
            f:close()
            local ok, fileData = pcall(love.filesystem.newFileData, data, "import.png")
            if ok then
                local ok2, imgData = pcall(love.image.newImageData, fileData)
                if ok2 then imageData = imgData end
            end
        end
    end

    if not imageData then return false end
    if imageData:getWidth() ~= WORLD_W or imageData:getHeight() ~= WORLD_H then
        return false  -- wrong dimensions
    end

    Editor.pushUndo()

    -- Detect smiley face (spawn point marker) before cleaning
    -- Smiley pattern from HTML: left eye (cx+2,cy+8), mouth (cx+4,cy+9)+(cx+5,cy+9), right eye (cx+7,cy+8)
    local spawnFound = false
    for row = 0, 15 do
        for col = 0, 8 do
            local cx = col * 12
            local cy = row * 12
            -- Check if cell is mostly white (cave)
            if cx + 6 < WORLD_W and cy + 6 < WORLD_H then
                local _, _, _, a_center = imageData:getPixel(cx + 6, cy + 6)
                if a_center > 0.5 then
                    -- Check smiley pixels
                    local function isDark(x, y)
                        if x < 0 or x >= WORLD_W or y < 0 or y >= WORLD_H then return false end
                        local r, g, b, a = imageData:getPixel(x, y)
                        return (r + g + b) < 1.5 and a > 0.5
                    end
                    local function isLight(x, y)
                        if x < 0 or x >= WORLD_W or y < 0 or y >= WORLD_H then return false end
                        local r, g, b, a = imageData:getPixel(x, y)
                        return (r + g + b) > 1.5 and a > 0.5
                    end
                    if isDark(cx+2, cy+8) and isDark(cx+7, cy+8)
                       and isDark(cx+4, cy+9) and isDark(cx+5, cy+9)
                       and isLight(cx+3, cy+8) and isLight(cx+6, cy+8) then
                        state.playerStart = {x = cx + 6, y = cy + 6}
                        spawnFound = true
                        -- Clear smiley pixels
                        imageData:setPixel(cx+2, cy+8, 1, 1, 1, 1)
                        imageData:setPixel(cx+7, cy+8, 1, 1, 1, 1)
                        imageData:setPixel(cx+4, cy+9, 1, 1, 1, 1)
                        imageData:setPixel(cx+5, cy+9, 1, 1, 1, 1)
                        break
                    end
                end
            end
        end
        if spawnFound then break end
    end

    -- Normalize: all pixels → (1,1,1,1) or (0,0,0,0)
    for py = 0, WORLD_H - 1 do
        for px = 0, WORLD_W - 1 do
            local r, g, b, a = imageData:getPixel(px, py)
            if (r + g + b) > 1.5 then
                imageData:setPixel(px, py, 1, 1, 1, 1)
            else
                imageData:setPixel(px, py, 0, 0, 0, 0)
            end
        end
    end

    state.canvas = imageData
    Editor.rebuildDisplayImage()
    state.bats = {}
    state.dirty = true

    if not spawnFound then
        state.playerStart = {x = 30, y = 18}
    end

    return true
end

-- Open macOS file picker and import selected PNG
function Editor.openFilePicker()
    -- Use osascript to open native macOS file dialog
    local handle = io.popen('osascript -e "POSIX path of (choose file of type {\\"png\\"} with prompt \\"Select cave PNG (108x192)\\")" 2>/dev/null')
    if handle then
        local result = handle:read("*a")
        handle:close()
        -- Remove trailing newline
        result = result:gsub("%s+$", "")
        if result ~= "" then
            local success = Editor.loadExternalPNG(result)
            if not success then
                -- File failed to load (wrong size?)
                print("Import failed: PNG must be 108x192")
            end
        end
    end
end

function Editor.exportToGame()
    local refs = state.gameRefs
    if not refs then return end

    local sourcePath = getSourcePath()
    local levelSlots = state.levelSlots

    -- For each assigned level slot, copy stencil and build level data
    local levelEntries = {}
    for i, mapName in ipairs(levelSlots) do
        -- Copy stencil to maps/level_N_stencil.png
        local srcStencil = sourcePath .. "/editor_maps/" .. mapName .. "/stencil.png"
        local dstStencil = sourcePath .. "/maps/level_" .. i .. "_stencil.png"
        local srcF = io.open(srcStencil, "rb")
        if srcF then
            local data = srcF:read("*a")
            srcF:close()
            local dstF = io.open(dstStencil, "wb")
            if dstF then
                dstF:write(data)
                dstF:close()
            end
        end

        -- Read meta for this map
        local metaContent = love.filesystem.read("editor_maps/" .. mapName .. "/meta.json")
        local meta = metaContent and json.decode(metaContent) or {}
        local ps = meta.playerStart or {x = 54, y = 60}

        -- Auto-derive platform bounds from the stencil at player's Y
        local stencilPath = "editor_maps/" .. mapName .. "/stencil.png"
        local platMin, platMax = math.max(0, ps.x - 3), math.min(WORLD_W - 1, ps.x + 3)
        if love.filesystem.getInfo(stencilPath) then
            local imgData = love.image.newImageData(stencilPath)
            local py = math.floor(ps.y)
            local px = math.floor(ps.x)
            if py >= 0 and py < WORLD_H and px >= 0 and px < WORLD_W then
                local _, _, _, a = imgData:getPixel(px, py)
                if a > 0.5 then
                    platMin = px
                    while platMin > 0 do
                        local _, _, _, la = imgData:getPixel(platMin - 1, py)
                        if la < 0.5 then break end
                        platMin = platMin - 1
                    end
                    platMax = px
                    while platMax < WORLD_W - 1 do
                        local _, _, _, ra = imgData:getPixel(platMax + 1, py)
                        if ra < 0.5 then break end
                        platMax = platMax + 1
                    end
                end
            end
        end

        table.insert(levelEntries, {
            stencilFile = "maps/level_" .. i .. "_stencil.png",
            textureFile = "maps/level_" .. i .. "_texture.png",
            playerStart = ps,
            platformXMin = platMin,
            platformXMax = platMax,
            bats = meta.bats or {},
            mirrorLines = meta.mirrorLines or {},
        })
    end

    -- Generate levels.lua
    local lines = {}
    table.insert(lines, '--[[\n    Level Data for Cave Fall\n    Generated by Map Editor\n    All coordinates in SCREEN SPACE (Y-down), 108x192\n]]\n')
    table.insert(lines, "local levels = {}\n")

    for i, entry in ipairs(levelEntries) do
        table.insert(lines, "levels[" .. i .. "] = {")
        table.insert(lines, '    stencilFile = "' .. entry.stencilFile .. '",')
        table.insert(lines, '    textureFile = "' .. entry.textureFile .. '",')
        table.insert(lines, '    playerStart = {x = ' .. entry.playerStart.x .. ', y = ' .. entry.playerStart.y .. '},')
        table.insert(lines, '    platformXMin = ' .. entry.platformXMin .. ',')
        table.insert(lines, '    platformXMax = ' .. entry.platformXMax .. ',')
        table.insert(lines, '    bats = {')
        for _, bat in ipairs(entry.bats) do
            table.insert(lines, '        {x = ' .. bat.x .. ', y = ' .. bat.y .. '},')
        end
        table.insert(lines, '    },')
        if #entry.mirrorLines > 0 then
            table.insert(lines, '    mirrorLines = {')
            for _, ml in ipairs(entry.mirrorLines) do
                table.insert(lines, string.format('        {x = %d, y = %d, length = %d},', ml.x, ml.y, ml.length))
            end
            table.insert(lines, '    },')
        end
        table.insert(lines, '}\n')
    end
    table.insert(lines, "return levels\n")

    local luaContent = table.concat(lines, "\n")
    local f = io.open(sourcePath .. "/levels.lua", "w")
    if f then
        f:write(luaContent)
        f:close()
    end
end

------------------------------------------------------------
-- PLAY TEST
------------------------------------------------------------

-- Check if a world position is inside the cave (stencil alpha > 0.5)
local function isInsideStencil(wx, wy)
    if wx < 0 or wx >= WORLD_W or wy < 0 or wy >= WORLD_H then return false end
    local _, _, _, a = state.canvas:getPixel(math.floor(wx), math.floor(wy))
    return a > 0.5
end

function Editor.startPlayTest()
    local refs = state.gameRefs
    if not refs then return end


    -- Platform bounds: use air walls if placed, otherwise full width
    local autoPlatMin = 0
    local autoPlatMax = WORLD_W - 1
    -- Find air walls on the same row as player (within 12px Y range)
    for _, aw in ipairs(state.airWalls) do
        if math.abs(aw.y - state.playerStart.y) < 12 then
            -- Air wall to the left of player
            if aw.x < state.playerStart.x and aw.x > autoPlatMin then
                autoPlatMin = aw.x + 6  -- right edge of the air wall block
            end
            -- Air wall to the right of player
            if aw.x > state.playerStart.x and aw.x < autoPlatMax then
                autoPlatMax = aw.x - 6  -- left edge of the air wall block
            end
        end
    end

    -- Create temporary level at index 0
    refs.levels[0] = {
        stencilFile = nil,
        textureFile = nil,
        playerStart = {x = state.playerStart.x, y = state.playerStart.y},
        platformXMin = autoPlatMin,
        platformXMax = autoPlatMax,
        -- spawnPlatform: tell the game exactly where the platform is
        -- so it uses this directly instead of backward-compat derivation
        spawnPlatform = {
            x = autoPlatMin,
            y = state.playerStart.y + 4,
            width = autoPlatMax - autoPlatMin,
        },
        bats = {},
        voidBats = {},
        mirrorLines = {},
        airWalls = {},
    }
    for _, bat in ipairs(state.bats) do
        table.insert(refs.levels[0].bats, {x = bat.x, y = bat.y, moveDir = bat.moveDir, moveDist = bat.moveDist, moveSpeed = bat.moveSpeed})
    end
    for _, aw in ipairs(state.airWalls) do
        table.insert(refs.levels[0].airWalls, {x = aw.x, y = aw.y})
    end
    for _, vb in ipairs(state.voidBats) do
        table.insert(refs.levels[0].voidBats, {x = vb.x, y = vb.y, moveDir = vb.moveDir, moveDist = vb.moveDist, moveSpeed = vb.moveSpeed})
    end
    for _, ml in ipairs(state.mirrorLines) do
        table.insert(refs.levels[0].mirrorLines, {x = ml.x, y = ml.y, length = ml.length})
    end

    -- Inject stencil data
    local stencilImg = love.graphics.newImage(state.canvas)
    stencilImg:setFilter("nearest", "nearest")
    refs.caveMapData[0] = {
        stencilData = state.canvas,
        stencilImage = stencilImg,
        edgePoints = nil,
        thorns = nil,
    }

    -- Switch to game mode
    state.isPlayTesting = true
    love.window.setMode(480, 854, {resizable = true})

    -- Load the level using game logic
    refs.gameWorld.state = refs.STATE.READY
    refs.GameLogic.loadLevel(refs.gameWorld, 0)
end

function Editor.stopPlayTest()
    local refs = state.gameRefs
    if not refs then return end

    -- Clean up temporary level
    refs.levels[0] = nil
    refs.caveMapData[0] = nil

    -- Return to editor
    state.isPlayTesting = false
    love.window.setMode(WINDOW_W, WINDOW_H, {resizable = true})
    refs.gameWorld.state = refs.STATE.EDITOR
end

------------------------------------------------------------
-- INPUT HANDLING
------------------------------------------------------------

function Editor.keypressed(key)
    -- Global editor shortcuts
    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
        or love.keyboard.isDown("lgui") or love.keyboard.isDown("rgui")

    if state.isPlayTesting then
        if key == "escape" or key == "f5" then
            Editor.stopPlayTest()
            return true
        end
        return false  -- let game handle input
    end

    if key == "escape" then
        if state.showGeneratePanel then
            state.showGeneratePanel = false
        elseif state.showLevelManager then
            state.showLevelManager = false
        else
            -- Exit editor
            return "exit"
        end
        return true
    end

    if key == "f5" then
        Editor.startPlayTest()
        return true
    end

    if ctrl and key == "z" then
        Editor.undo()
        return true
    end
    if ctrl and key == "y" then
        Editor.redo()
        return true
    end
    if ctrl and key == "s" then
        -- Quick save (use current name, or prompt)
        if state.currentMapName ~= "untitled" then
            Editor.saveMap(state.currentMapName)
        else
            -- Use a default name with timestamp
            state.currentMapName = "map_" .. os.time()
            Editor.saveMap(state.currentMapName)
        end
        return true
    end
    if ctrl and key == "n" then
        Editor.clearCanvas()
        state.currentMapName = "untitled"
        return true
    end
    if ctrl and key == "o" then
        -- Open load dialog (reuses level manager with load mode)
        Editor.scanSavedMaps()
        state.showLevelManager = true
        return true
    end
    if ctrl and key == "l" then
        state.showLevelManager = not state.showLevelManager
        return true
    end

    if key == "tab" then
        if state.mode == MODE.DRAW then
            state.mode = MODE.ENTITY
        else
            state.mode = MODE.DRAW
        end
        return true
    end

    if key == "g" and not ctrl then
        state.showGeneratePanel = not state.showGeneratePanel
        return true
    end

    -- Draw mode shortcuts
    if state.mode == MODE.DRAW then
        -- Grid Geometry sub-mode input
        if state.drawSubMode == "CELL_STAMP" then
            -- Cell stamp shortcuts
            if key == "1" then state.cellStamp = "RECT"; return true end
            if key == "2" then state.cellStamp = "STAIR"; return true end
            if key == "3" then state.cellStamp = "THUMB"; return true end
            if key == "4" then state.cellStamp = "ISLAND"; return true end
            if key == "q" then
                -- Cycle direction backward
                local dirs = {"TL", "TR", "BR", "BL"}
                for i, d in ipairs(dirs) do
                    if d == state.cellDir then
                        state.cellDir = dirs[(i - 2) % 4 + 1]; break
                    end
                end
                return true
            end
            if key == "e" then
                -- Cycle direction forward
                local dirs = {"TL", "TR", "BR", "BL"}
                for i, d in ipairs(dirs) do
                    if d == state.cellDir then
                        state.cellDir = dirs[i % 4 + 1]; break
                    end
                end
                return true
            end
            if key == "d" then
                state.cellMode = "DIG"; return true
            end
            if key == "b" then
                state.cellMode = "BUILD"; return true
            end
        end

        -- Free Draw mode shortcuts
        if key == "b" then state.tool = TOOL.PEN; return true end
        if key == "e" then state.tool = TOOL.ERASER; return true end
        if key == "f" then state.tool = TOOL.FILL; return true end
        if key == "l" and not ctrl then state.tool = TOOL.LINE; return true end
        if key == "r" then state.tool = TOOL.RECT; return true end
        -- Brush size with number keys
        for i = 1, 8 do
            if key == tostring(i) then state.brushSize = i; return true end
        end
        -- Grid toggle
        if key == "h" then state.showGrid = not state.showGrid; return true end
    end

    return false
end

function Editor.mousepressed(x, y, button)
    if state.isPlayTesting then return false end

    -- Block all clicks when overlays are active (handled by main.lua routing)
    if state.showGeneratePanel or state.showLevelManager then
        return true
    end

    -- Middle mouse button: start panning
    if button == 3 and x < PANEL_X then
        state.panning = true
        state.panStartX = x
        state.panStartY = y
        state.panStartOffX = state.viewOffsetX
        state.panStartOffY = state.viewOffsetY
        return true
    end

    -- Space + left click: also pan
    if button == 1 and love.keyboard.isDown("space") and x < PANEL_X then
        state.panning = true
        state.panStartX = x
        state.panStartY = y
        state.panStartOffX = state.viewOffsetX
        state.panStartOffY = state.viewOffsetY
        return true
    end

    -- Check if click is in UI panel
    if x >= PANEL_X then
        if EditorUI then
            return EditorUI.mousepressed(x, y, button)
        end
        return true
    end

    -- Click is in canvas area
    if not isInCanvas(x, y) then return true end
    local wx, wy = screenToWorld(x, y)

    if state.mode == MODE.DRAW then
        -- Cell Stamp sub-mode mouse handling
        if state.drawSubMode == "CELL_STAMP" then
            if button == 1 then
                cellStampApply(wx, wy)
            elseif button == 2 then
                -- Right click: opposite mode
                local origMode = state.cellMode
                state.cellMode = (origMode == "DIG") and "BUILD" or "DIG"
                cellStampApply(wx, wy)
                state.cellMode = origMode
            end
            return true
        end

        if state.tool == TOOL.FILL then
            if button == 1 then
                Editor.pushUndo()
                floodFill(wx, wy, true)
                Editor.rebuildDisplayImage()
                state.dirty = true
            elseif button == 2 then
                Editor.pushUndo()
                floodFill(wx, wy, false)
                Editor.rebuildDisplayImage()
                state.dirty = true
            end
        elseif state.tool == TOOL.LINE then
            if button == 1 or button == 2 then
                if state.lastPaintPos then
                    Editor.pushUndo()
                    local value = (button == 1)
                    paintLine(state.lastPaintPos.x, state.lastPaintPos.y,
                              wx, wy, state.brushSize, value)
                    Editor.rebuildDisplayImage()
                    state.dirty = true
                end
                state.lastPaintPos = {x = wx, y = wy}
            end
        else
            -- PEN or ERASER: start painting
            Editor.pushUndo()
            state.painting = true
            state.paintButton = button
            local value = (button == 1)  -- left=paint, right=erase
            if state.tool == TOOL.ERASER then value = false end
            if state.tool == TOOL.PEN and button == 2 then value = false end
            paintCircle(wx, wy, state.brushSize, value)
            Editor.rebuildDisplayImage()
            state.lastPaintPos = {x = wx, y = wy}
            state.dirty = true
        end
    elseif state.mode == MODE.ENTITY then
        if button == 1 then
            -- Check if clicking on existing entity
            local entity = findEntityAt(wx, wy)
            if entity then
                state.selectedEntity = entity
                state.dragging = true
                if entity.type == "airWall" then
                    state.dragOffset.x = state.airWalls[entity.index].x - wx
                    state.dragOffset.y = state.airWalls[entity.index].y - wy
                elseif entity.type == "bat" then
                    state.dragOffset.x = state.bats[entity.index].x - wx
                    state.dragOffset.y = state.bats[entity.index].y - wy
                elseif entity.type == "player" then
                    state.dragOffset.x = state.playerStart.x - wx
                    state.dragOffset.y = state.playerStart.y - wy
                elseif entity.type == "mirrorLine_body" then
                    local ml = state.mirrorLines[entity.index]
                    state.dragOffset.x = ml.x - wx
                    state.dragOffset.y = ml.y - wy
                else
                    state.dragOffset.x = 0
                    state.dragOffset.y = 0
                end
            else
                -- Place new entity based on sub-mode
                if state.entitySubMode == "MIRROR_LINE" then
                    local snapX = math.floor(wx / 8) * 8
                    local snapY = math.floor(wy / 8) * 8
                    table.insert(state.mirrorLines, {x = snapX, y = snapY, length = 32})
                    state.dirty = true
                elseif state.entitySubMode == "AIR_WALL" then
                    table.insert(state.airWalls, {x = math.floor(wx / 6 + 0.5) * 6, y = math.floor(wy / 6 + 0.5) * 6})
                    state.dirty = true
                elseif state.entitySubMode == "BAT" then
                    table.insert(state.bats, {x = math.floor(wx / 6 + 0.5) * 6, y = math.floor(wy / 6 + 0.5) * 6, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6})
                    state.dirty = true
                elseif state.entitySubMode == "VOID_BAT" then
                    table.insert(state.voidBats, {x = wx, y = wy})
                    state.dirty = true
                end
                -- PLATFORM: always exists, can't place new ones, just drag existing
            end
        elseif button == 2 then
            -- Right click: delete entity or set player start
            local entity = findEntityAt(wx, wy)
            if entity and entity.type == "airWall" then
                table.remove(state.airWalls, entity.index)
                state.dirty = true
            elseif entity and entity.type == "bat" then
                table.remove(state.bats, entity.index)
                state.dirty = true
            elseif entity and entity.type == "voidBat" then
                table.remove(state.voidBats, entity.index)
                state.dirty = true
            elseif entity and (entity.type == "mirrorLine_body" or
                              entity.type == "mirrorLine_left" or
                              entity.type == "mirrorLine_right") then
                table.remove(state.mirrorLines, entity.index)
                state.dirty = true
            else
                -- Right click on empty = set player start (snapped to 12px grid center)
                state.playerStart = {x = math.floor(wx / 6 + 0.5) * 6, y = math.floor(wy / 6 + 0.5) * 6}
                state.dirty = true
            end
        end
    end
    return true
end

function Editor.mousemoved(x, y, dx, dy)
    if state.isPlayTesting then return false end

    -- Panning
    if state.panning then
        local scale = state.viewScale
        state.viewOffsetX = state.panStartOffX - (x - state.panStartX) / scale
        state.viewOffsetY = state.panStartOffY - (y - state.panStartY) / scale
        return true
    end

    -- Update cursor position
    if isInCanvas(x, y) then
        state.cursorWorldX, state.cursorWorldY = screenToWorld(x, y)
        state.cursorInCanvas = true
    else
        state.cursorInCanvas = false
    end

    -- UI hover
    if x >= PANEL_X and EditorUI then
        EditorUI.mousemoved(x, y)
    end



    -- Drawing
    if state.mode == MODE.DRAW and state.painting and isInCanvas(x, y) then
        local wx, wy = screenToWorld(x, y)
        local value = (state.paintButton == 1)
        if state.tool == TOOL.ERASER then value = false end
        if state.tool == TOOL.PEN and state.paintButton == 2 then value = false end

        -- Paint line from last position to current for smooth strokes
        if state.lastPaintPos then
            paintLine(state.lastPaintPos.x, state.lastPaintPos.y, wx, wy, state.brushSize, value)
        else
            paintCircle(wx, wy, state.brushSize, value)
        end
        state.lastPaintPos = {x = wx, y = wy}
        Editor.rebuildDisplayImage()
        state.dirty = true
    end

    -- Entity dragging
    if state.mode == MODE.ENTITY and state.dragging and state.selectedEntity then
        if not isInCanvas(x, y) then return true end
        local wx, wy = screenToWorld(x, y)
        local ent = state.selectedEntity
        if ent.type == "airWall" and state.airWalls[ent.index] then
            local rawX = wx + state.dragOffset.x
            local rawY = wy + state.dragOffset.y
            state.airWalls[ent.index].x = math.floor(rawX / 6 + 0.5) * 6
            state.airWalls[ent.index].y = math.floor(rawY / 6 + 0.5) * 6
        elseif ent.type == "bat" and state.bats[ent.index] then
            local rawX = wx + state.dragOffset.x
            local rawY = wy + state.dragOffset.y
            state.bats[ent.index].x = math.floor(rawX / 6 + 0.5) * 6
            state.bats[ent.index].y = math.floor(rawY / 6 + 0.5) * 6
        elseif ent.type == "voidBat" and state.voidBats and state.voidBats[ent.index] then
            state.voidBats[ent.index].x = wx + state.dragOffset.x
            state.voidBats[ent.index].y = wy + state.dragOffset.y
        elseif ent.type == "player" then
            local rawX = wx + state.dragOffset.x
            local rawY = wy + state.dragOffset.y
            state.playerStart.x = math.floor(rawX / 6 + 0.5) * 6
            state.playerStart.y = math.floor(rawY / 6 + 0.5) * 6
        elseif ent.type == "mirrorLine_body" then
            local ml = state.mirrorLines[ent.index]
            if ml then
                ml.x = math.floor((wx + state.dragOffset.x) / 8) * 8
                ml.y = math.floor((wy + state.dragOffset.y) / 8) * 8
                ml.x = math.max(0, math.min(WORLD_W - ml.length, ml.x))
                ml.y = math.max(0, math.min(WORLD_H - 1, ml.y))
            end
        elseif ent.type == "mirrorLine_left" then
            local ml = state.mirrorLines[ent.index]
            if ml then
                local newX = math.floor(wx / 8) * 8
                local rightEnd = ml.x + ml.length
                newX = math.max(0, math.min(rightEnd - 16, newX))
                ml.length = rightEnd - newX
                ml.x = newX
            end
        elseif ent.type == "mirrorLine_right" then
            local ml = state.mirrorLines[ent.index]
            if ml then
                local newRight = math.floor(wx / 8) * 8
                newRight = math.max(ml.x + 16, math.min(WORLD_W, newRight))
                ml.length = newRight - ml.x
            end
        end
        state.dirty = true
    end

    return true
end

function Editor.mousereleased(x, y, button)
    if state.isPlayTesting then return false end
    state.panning = false
    state.painting = false
    state.dragging = false
    if state.mode == MODE.DRAW and state.tool ~= TOOL.LINE then
        state.lastPaintPos = nil
    end



    if x >= PANEL_X and EditorUI then
        EditorUI.mousereleased(x, y, button)
    end
    return true
end

function Editor.wheelmoved(x, y)
    if state.isPlayTesting then return false end

    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
        or love.keyboard.isDown("lgui") or love.keyboard.isDown("rgui")

    -- Brush size: only in free draw mode WITHOUT ctrl
    if not ctrl and state.mode == MODE.DRAW and state.drawSubMode == "FREE" then
        state.brushSize = math.max(1, math.min(8, state.brushSize + y))
        return true
    end

    -- Zoom toward cursor
    local mouseX, mouseY = love.mouse.getPosition()
    if mouseX < PANEL_X then
        local oldWx, oldWy = screenToWorld(mouseX, mouseY)
        local oldScale = state.viewScale
        state.viewScale = math.max(2, math.min(10, state.viewScale + y))
        if state.viewScale ~= oldScale then
            -- Adjust pan so world point under cursor stays fixed
            local ox, oy, scale = getCanvasOrigin()
            local newScreenX = ox + oldWx * scale
            local newScreenY = oy + oldWy * scale
            state.viewOffsetX = state.viewOffsetX - (mouseX - newScreenX) / scale
            state.viewOffsetY = state.viewOffsetY - (mouseY - newScreenY) / scale
        end
        return true
    end

    return false
end

------------------------------------------------------------
-- UPDATE
------------------------------------------------------------

function Editor.update(dt)
    if state.isPlayTesting then
        -- Game handles its own update via main.lua routing
        return
    end
    -- Editor-specific updates (animations, etc.)
    if EditorUI then
        EditorUI.update(dt)
    end
end

------------------------------------------------------------
-- DRAW
------------------------------------------------------------

function Editor.draw()
    if state.isPlayTesting then
        -- Game handles its own draw
        return
    end

    love.graphics.clear(0.15, 0.15, 0.15)

    -- Clip to canvas area (left of panel)
    love.graphics.setScissor(0, 0, PANEL_X, WINDOW_H)

    local ox, oy, scale = getCanvasOrigin()

    -- Draw canvas background (dark area)
    love.graphics.setColor(0.05, 0.05, 0.05)
    love.graphics.rectangle("fill", ox, oy, WORLD_W * scale, WORLD_H * scale)

    -- Draw the stencil image (zoom-aware)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(state.displayImage, ox, oy, 0, scale, scale)

    -- Grid overlay: 12px main grid + 6px subtle subdivisions
    if state.showGrid then
        -- 6px subtle lines (subdivisions)
        love.graphics.setColor(0.4, 0.4, 0.4, 0.1)
        love.graphics.setLineWidth(1)
        for gc = 1, 17 do
            if gc % 2 ~= 0 then  -- only odd = 6px subdivisions (not on 12px boundary)
                local sx = ox + gc * 6 * scale
                love.graphics.line(sx, oy, sx, oy + WORLD_H * scale)
            end
        end
        for gr = 1, 31 do
            if gr % 2 ~= 0 then
                local sy = oy + gr * 6 * scale
                love.graphics.line(ox, sy, ox + WORLD_W * scale, sy)
            end
        end
        -- 12px main grid (brighter)
        love.graphics.setColor(0.6, 0.6, 0.6, 0.25)
        for gc = 1, 8 do  -- 9 cols at 12px
            local sx = ox + gc * 12 * scale
            love.graphics.line(sx, oy, sx, oy + WORLD_H * scale)
        end
        for gr = 1, 15 do  -- 16 rows at 12px
            local sy = oy + gr * 12 * scale
            love.graphics.line(ox, sy, ox + WORLD_W * scale, sy)
        end
        -- Border
        love.graphics.setColor(0.4, 0.6, 1.0, 0.3)
        love.graphics.rectangle("line", ox, oy, WORLD_W * scale, WORLD_H * scale)
    end

    -- Preview game's 3px edge border (so user sees what game will look like)
    if state.showHitboxes then
        Editor.drawEdgeBorderPreview(ox, oy, scale)
    end

    -- Draw entities (with collision bodies)
    Editor.drawEntities()



    -- Brush cursor preview (only in free draw mode)
    if state.cursorInCanvas and state.mode == MODE.DRAW and state.drawSubMode == "FREE" then
        local cx, cy = worldToScreen(state.cursorWorldX, state.cursorWorldY)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.setLineWidth(1)
        love.graphics.circle("line", cx + scale / 2, cy + scale / 2,
                            state.brushSize * scale)
    end

    -- Remove scissor before drawing UI
    love.graphics.setScissor()

    -- Right panel (UI)
    if EditorUI then
        EditorUI.draw()
    end

    -- Generate panel overlay
    if state.showGeneratePanel then
        Editor.drawGeneratePanel()
    end

    -- Level manager overlay
    if state.showLevelManager then
        Editor.drawLevelManager()
    end
end

-- Cached edge pixels for border preview (recomputed when canvas changes)
local cachedEdgePixels = nil
local edgeCacheDirty = true

function Editor.markEdgeCacheDirty()
    edgeCacheDirty = true
end

local function recomputeEdgeCache()
    cachedEdgePixels = {}
    for wy = 1, WORLD_H - 2 do
        for wx = 1, WORLD_W - 2 do
            local _, _, _, a = state.canvas:getPixel(wx, wy)
            if a > 0.5 then
                local isEdge = false
                local _, _, _, a1 = state.canvas:getPixel(wx-1, wy)
                if a1 < 0.5 then isEdge = true end
                if not isEdge then
                    local _, _, _, a2 = state.canvas:getPixel(wx+1, wy)
                    if a2 < 0.5 then isEdge = true end
                end
                if not isEdge then
                    local _, _, _, a3 = state.canvas:getPixel(wx, wy-1)
                    if a3 < 0.5 then isEdge = true end
                end
                if not isEdge then
                    local _, _, _, a4 = state.canvas:getPixel(wx, wy+1)
                    if a4 < 0.5 then isEdge = true end
                end
                if isEdge then
                    table.insert(cachedEdgePixels, {wx, wy})
                end
            end
        end
    end
    edgeCacheDirty = false
end

function Editor.drawEdgeBorderPreview(ox, oy, scale)
    if edgeCacheDirty or not cachedEdgePixels then
        recomputeEdgeCache()
    end
    -- Draw 3x3 dark blocks at each edge pixel (simulates game's ink border)
    love.graphics.setColor(0.08, 0.08, 0.08, 0.65)
    for _, ep in ipairs(cachedEdgePixels) do
        local sx = ox + (ep[1] - 1) * scale
        local sy = oy + (ep[2] - 1) * scale
        love.graphics.rectangle("fill", sx, sy, 3 * scale, 3 * scale)
    end
end

function Editor.drawEntities()
    local ox, oy, scale = getCanvasOrigin()

    -- Player start: crosshair + collision body (9x8)
    local psx, psy = worldToScreen(state.playerStart.x, state.playerStart.y)
    love.graphics.setColor(0, 1, 0, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.line(psx - 8, psy, psx + 8, psy)
    love.graphics.line(psx, psy - 8, psx, psy + 8)

    -- Player collision body hitbox (9x8 pixels)
    if state.showHitboxes then
        local pw, ph = 12, 12
        local hbx = ox + (state.playerStart.x - pw/2) * scale
        local hby = oy + (state.playerStart.y - ph/2) * scale
        love.graphics.setColor(0, 1, 0, 0.25)
        love.graphics.rectangle("fill", hbx, hby, pw * scale, ph * scale)
        love.graphics.setColor(0, 1, 0, 0.7)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", hbx, hby, pw * scale, ph * scale)
    end

    -- Air Walls (semi-transparent cyan blocks - invisible in game)
    for i, aw in ipairs(state.airWalls) do
        local awx, awy = worldToScreen(aw.x, aw.y)
        local isSel = state.selectedEntity and state.selectedEntity.type == "airWall"
                        and state.selectedEntity.index == i
        if isSel then
            love.graphics.setColor(1, 1, 0, 0.4)
        else
            love.graphics.setColor(0, 0.8, 1, 0.3)
        end
        love.graphics.rectangle("fill", awx - 6 * scale, awy - 6 * scale, 12 * scale, 12 * scale)
        love.graphics.setColor(0, 0.8, 1, 0.7)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", awx - 6 * scale, awy - 6 * scale, 12 * scale, 12 * scale)
        -- "X" marker
        love.graphics.line(awx - 4 * scale, awy - 4 * scale, awx + 4 * scale, awy + 4 * scale)
        love.graphics.line(awx + 4 * scale, awy - 4 * scale, awx - 4 * scale, awy + 4 * scale)
    end

    -- Bats: marker + COLLISION BODY (13x9 effective)
    for i, bat in ipairs(state.bats) do
        local bx = ox + bat.x * scale
        local by = oy + bat.y * scale
        local isSel = state.selectedEntity and state.selectedEntity.type == "bat"
                        and state.selectedEntity.index == i

        -- Collision body hitbox (11w + 2 tolerance, 7h + 2 tolerance = 13x9)
        if state.showHitboxes then
            local bw, bh = 12, 12
            local hbx = ox + (bat.x - bw/2) * scale
            local hby = oy + (bat.y - bh/2) * scale
            if isSel then
                love.graphics.setColor(1, 1, 0, 0.25)
            else
                love.graphics.setColor(1, 0.2, 0.2, 0.2)
            end
            love.graphics.rectangle("fill", hbx, hby, bw * scale, bh * scale)
            love.graphics.setColor(1, 0.3, 0.3, 0.6)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", hbx, hby, bw * scale, bh * scale)
        end

        -- Movement trajectory line
        if bat.moveDir and bat.moveDir ~= "NONE" and bat.moveDist then
            love.graphics.setColor(1, 0.8, 0, 0.5)
            love.graphics.setLineWidth(1)
            local halfDist = bat.moveDist / 2
            if bat.moveDir == "HORIZONTAL" then
                local lx = ox + (bat.x - halfDist) * scale
                local rx = ox + (bat.x + halfDist) * scale
                love.graphics.line(lx, by, rx, by)
                love.graphics.circle("fill", lx, by, 2)
                love.graphics.circle("fill", rx, by, 2)
            elseif bat.moveDir == "VERTICAL" then
                local ty = oy + (bat.y - halfDist) * scale
                local dy = oy + (bat.y + halfDist) * scale
                love.graphics.line(bx, ty, bx, dy)
                love.graphics.circle("fill", bx, ty, 2)
                love.graphics.circle("fill", bx, dy, 2)
            end
        end

        -- Center marker
        if isSel then
            love.graphics.setColor(1, 1, 0, 0.9)
        else
            love.graphics.setColor(1, 0.2, 0.2, 0.8)
        end
        love.graphics.circle("fill", bx, by, 3)
        love.graphics.line(bx - 4, by - 4, bx + 4, by + 4)
        love.graphics.line(bx + 4, by - 4, bx - 4, by + 4)
    end

    -- Void Bats (purple/gray circles with dashed outline)
    for i, vb in ipairs(state.voidBats) do
        local vx = ox + vb.x * scale
        local vy = oy + vb.y * scale
        local isSel = state.selectedEntity and state.selectedEntity.type == "voidBat"
                        and state.selectedEntity.index == i
        if isSel then
            love.graphics.setColor(1, 1, 0, 0.9)
        else
            love.graphics.setColor(0.5, 0.4, 0.7, 0.7)
        end
        love.graphics.circle("line", vx, vy, 5)
        love.graphics.circle("line", vx, vy, 3)
        love.graphics.setColor(0.5, 0.4, 0.7, 0.4)
        love.graphics.circle("fill", vx, vy, 3)
    end

    -- Mirror lines (green horizontal lines with endpoint handles)
    for i, ml in ipairs(state.mirrorLines) do
        local sx = ox + ml.x * scale
        local sy = oy + ml.y * scale
        local ex = sx + ml.length * scale
        local isSel = state.selectedEntity and
            (state.selectedEntity.type == "mirrorLine_body" or
             state.selectedEntity.type == "mirrorLine_left" or
             state.selectedEntity.type == "mirrorLine_right") and
            state.selectedEntity.index == i

        -- Line body
        if isSel then
            love.graphics.setColor(1, 1, 0, 0.9)
        else
            love.graphics.setColor(0.2, 0.85, 0.35, 0.85)
        end
        love.graphics.setLineWidth(3)
        love.graphics.line(sx, sy, ex, sy)

        -- Endpoint handles (circles)
        love.graphics.setColor(0.2, 0.85, 0.35, 1)
        love.graphics.circle("fill", sx, sy, 4)
        love.graphics.circle("fill", ex, sy, 4)

        -- Length label
        love.graphics.setColor(0.8, 0.8, 0.8, 0.7)
        love.graphics.print(tostring(ml.length), sx, sy - 14)
    end
end



function Editor.drawGeneratePanel()
    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, WINDOW_W, WINDOW_H)

    -- Panel background
    local pw, ph = 320, 280
    local px = (WINDOW_W - pw) / 2
    local py = (WINDOW_H - ph) / 2
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", px, py, pw, ph, 8)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", px, py, pw, ph, 8)

    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Generate Cave", px, py + 15, pw, "center")

    -- Parameters
    local y = py + 50
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("Rooms: " .. state.generateParams.pRect .. "%", px + 20, y)
    love.graphics.print("Stairs: " .. state.generateParams.pStair .. "%", px + 170, y)
    y = y + 25
    love.graphics.print("Thumbs: " .. state.generateParams.pThumb .. "%", px + 20, y)
    love.graphics.print("Islands: " .. state.generateParams.pIsland .. "%", px + 170, y)
    y = y + 25
    love.graphics.print("Seed: " .. (state.generateParams.seed == 0 and "Random" or tostring(state.generateParams.seed)), px + 20, y)

    -- Buttons
    y = y + 50
    -- Generate button
    love.graphics.setColor(0.2, 0.7, 0.3)
    love.graphics.rectangle("fill", px + 20, y, 130, 35, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Generate (Enter)", px + 20, y + 8, 130, "center")

    -- Cancel button
    love.graphics.setColor(0.5, 0.3, 0.3)
    love.graphics.rectangle("fill", px + 170, y, 130, 35, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Cancel (Esc)", px + 170, y + 8, 130, "center")

    -- Instructions
    y = y + 55
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.print("Up/Down: Rooms%  |  Left/Right: Islands%", px + 20, y)
    love.graphics.print("S: New seed  |  Enter: Generate", px + 20, y + 20)
end

function Editor.drawLevelManager()
    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, WINDOW_W, WINDOW_H)

    -- Panel
    local pw, ph = 400, 500
    local px = (WINDOW_W - pw) / 2
    local py = (WINDOW_H - ph) / 2
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", px, py, pw, ph, 8)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle("line", px, py, pw, ph, 8)

    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Level Manager", px, py + 15, pw, "center")

    -- Saved maps list
    local y = py + 50
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("Saved Maps:", px + 20, y)
    y = y + 25

    for i, map in ipairs(state.savedMaps) do
        -- Check if assigned to a slot
        local slotNum = nil
        for s, name in ipairs(state.levelSlots) do
            if name == map.name then slotNum = s; break end
        end

        love.graphics.setColor(0.3, 0.3, 0.35)
        love.graphics.rectangle("fill", px + 20, y, pw - 40, 25, 3)

        if slotNum then
            love.graphics.setColor(0.2, 0.8, 0.3)
            love.graphics.print("L" .. slotNum, px + 25, y + 4)
        end

        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.print(map.name, px + 55, y + 4)

        -- Load button on right side
        love.graphics.setColor(0.4, 0.5, 0.7)
        love.graphics.rectangle("fill", px + pw - 90, y + 2, 50, 21, 3)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Load", px + pw - 90, y + 5, 50, "center")

        y = y + 30
        if y > py + ph - 80 then break end
    end

    -- Level slots display
    if #state.levelSlots > 0 then
        y = y + 10
        love.graphics.setColor(0.8, 0.8, 0.2)
        love.graphics.print("Level Order:", px + 20, y)
        y = y + 20
        for i, name in ipairs(state.levelSlots) do
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.print(string.format("  %d. %s", i, name), px + 20, y)
            y = y + 18
            if y > py + ph - 80 then break end
        end
    end

    -- Instructions
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.print("Left click: Assign/Unassign level slot", px + 20, py + ph - 60)
    love.graphics.print("Ctrl+E: Export  |  Esc: Close", px + 20, py + ph - 35)
end

------------------------------------------------------------
-- GENERATE PANEL INPUT
------------------------------------------------------------

function Editor.handleGeneratePanelClick(x, y, button)
    if button ~= 1 then return false end

    local pw, ph = 320, 280
    local px = (WINDOW_W - pw) / 2
    local py = (WINDOW_H - ph) / 2

    -- Check if click is outside panel (dismiss)
    if x < px or x > px + pw or y < py or y > px + ph then
        state.showGeneratePanel = false
        return true
    end

    -- Generate button area (at py + 50 + 30*3 + 50 = py + 190)
    local btnY = py + 190
    if y >= btnY and y <= btnY + 35 then
        if x >= px + 20 and x <= px + 150 then
            -- Generate button
            Editor.generateCave()
            state.showGeneratePanel = false
            return true
        elseif x >= px + 170 and x <= px + 300 then
            -- Cancel button
            state.showGeneratePanel = false
            return true
        end
    end

    -- Fill target slider area (click to adjust)
    local fillY = py + 50
    if y >= fillY and y <= fillY + 25 then
        -- Cycle fill target
        state.generateParams.fillTarget = state.generateParams.fillTarget + 0.05
        if state.generateParams.fillTarget > 0.70 then
            state.generateParams.fillTarget = 0.20
        end
        return true
    end

    -- Smooth passes area
    local smoothY = py + 80
    if y >= smoothY and y <= smoothY + 25 then
        state.generateParams.smoothPasses = state.generateParams.smoothPasses + 1
        if state.generateParams.smoothPasses > 8 then
            state.generateParams.smoothPasses = 1
        end
        return true
    end

    -- Seed area
    local seedY = py + 110
    if y >= seedY and y <= seedY + 25 then
        state.generateParams.seed = 0  -- randomize
        return true
    end

    return true  -- consume click regardless (don't pass through overlay)
end

function Editor.handleGeneratePanelKey(key)
    if key == "escape" then
        state.showGeneratePanel = false
        return true
    end
    if key == "return" then
        Editor.generateCave()
        state.showGeneratePanel = false
        return true
    end
    if key == "up" then
        state.generateParams.pRect = math.min(100, state.generateParams.pRect + 10)
        return true
    end
    if key == "down" then
        state.generateParams.pRect = math.max(0, state.generateParams.pRect - 10)
        return true
    end
    if key == "right" then
        state.generateParams.pIsland = math.min(100, state.generateParams.pIsland + 10)
        return true
    end
    if key == "left" then
        state.generateParams.pIsland = math.max(0, state.generateParams.pIsland - 10)
        return true
    end
    if key == "s" then
        state.generateParams.seed = 0  -- 0 = will use random seed
        return true
    end
    return false
end

------------------------------------------------------------
-- LEVEL MANAGER INPUT
------------------------------------------------------------

function Editor.handleLevelManagerClick(x, y)
    local pw, ph = 400, 500
    local px = (WINDOW_W - pw) / 2
    local py = (WINDOW_H - ph) / 2

    -- Check if clicking on a map entry
    local listY = py + 75
    for i, map in ipairs(state.savedMaps) do
        if y >= listY and y <= listY + 25 then
            -- Check if clicking "Load" button (right side)
            if x >= px + pw - 90 and x <= px + pw - 40 then
                -- Load this map into editor
                Editor.loadMap(map.name)
                state.showLevelManager = false
                return true
            end
            -- Click on name: toggle level assignment
            if x >= px + 20 and x <= px + pw - 100 then
                local existingSlot = nil
                for s, name in ipairs(state.levelSlots) do
                    if name == map.name then existingSlot = s; break end
                end
                if existingSlot then
                    table.remove(state.levelSlots, existingSlot)
                else
                    table.insert(state.levelSlots, map.name)
                end
                return true
            end
        end
        listY = listY + 30
    end
    return false
end

function Editor.handleLevelManagerKey(key)
    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
        or love.keyboard.isDown("lgui") or love.keyboard.isDown("rgui")
    if key == "escape" then
        state.showLevelManager = false
        return true
    end
    if ctrl and key == "e" then
        Editor.exportToGame()
        state.showLevelManager = false
        return true
    end
    return false
end

------------------------------------------------------------
-- PUBLIC STATE ACCESSORS
------------------------------------------------------------

function Editor.getState()
    return state
end

function Editor.isPlayTesting()
    return state.isPlayTesting
end

return Editor
