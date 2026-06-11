--[[
    Cave Fall Map Editor - UI Panel
    Right-side panel with tools, buttons, and status info.
]]

local EditorUI = {}

local state = nil
local MODE = nil
local TOOL = nil
local EditorRef = nil  -- reference to editor module (set after init)

-- Layout constants
local PANEL_X = 432
local PANEL_W = 368
local PANEL_Y = 0
local PANEL_H = 854
local PADDING = 15
local BTN_H = 30
local BTN_GAP = 6

-- Colors
local C = {
    BG = {0.18, 0.18, 0.20},
    HEADER = {0.25, 0.25, 0.28},
    BTN = {0.28, 0.28, 0.32},
    BTN_HOVER = {0.35, 0.35, 0.40},
    BTN_ACTIVE = {0.45, 0.55, 0.65},
    TEXT = {0.9, 0.9, 0.9},
    TEXT_DIM = {0.6, 0.6, 0.6},
    ACCENT = {0.3, 0.75, 0.5},
    WARN = {0.9, 0.7, 0.2},
    DANGER = {0.9, 0.3, 0.3},
    SEPARATOR = {0.3, 0.3, 0.33},
}

-- UI state
local hoveredBtn = nil
local buttons = {}  -- rebuilt each frame
local sliderDragging = nil

-- Fonts
local fontTitle = nil
local fontNormal = nil
local fontSmall = nil

function EditorUI.init(editorState, modeEnum, toolEnum)
    state = editorState
    MODE = modeEnum
    TOOL = toolEnum
    EditorRef = require("editor.editor")
    -- Panel scroll
    EditorUI.scrollY = 0
    EditorUI.maxScrollY = 0
    EditorUI.panelDragging = false
    EditorUI.panelDragStartY = 0
    EditorUI.panelDragStartScroll = 0

    -- Create fonts (use default LÖVE font at different sizes)
    fontTitle = love.graphics.newFont(16)
    fontNormal = love.graphics.newFont(13)
    fontSmall = love.graphics.newFont(11)
end

function EditorUI.update(dt)
    -- Nothing time-dependent yet
end

function EditorUI.wheelmoved(y)
    if EditorUI.maxScrollY > 0 then
        EditorUI.scrollY = EditorUI.scrollY - y * 20
        EditorUI.scrollY = math.max(0, math.min(EditorUI.maxScrollY, EditorUI.scrollY))
        return true
    end
    return false
end

------------------------------------------------------------
-- DRAWING
------------------------------------------------------------

function EditorUI.draw()
    buttons = {}  -- clear button list each frame

    -- Panel background
    love.graphics.setColor(C.BG)
    love.graphics.rectangle("fill", PANEL_X, 0, PANEL_W, PANEL_H)

    -- Separator line
    love.graphics.setColor(C.SEPARATOR)
    love.graphics.setLineWidth(2)
    love.graphics.line(PANEL_X, 0, PANEL_X, PANEL_H)

    local y = PADDING

    -- Header: Mode tabs
    y = drawModeTabs(y)
    y = y + 10

    -- Separator
    love.graphics.setColor(C.SEPARATOR)
    love.graphics.line(PANEL_X + PADDING, y, PANEL_X + PANEL_W - PADDING, y)
    y = y + 10

    -- Apply panel scroll offset
    local scrollStartY = y
    y = y - EditorUI.scrollY

    -- Clip panel content
    love.graphics.setScissor(PANEL_X, scrollStartY, PANEL_W, PANEL_H - scrollStartY - 35)

    -- Mode-specific content
    if state.mode == MODE.DRAW then
        y = drawDrawTools(y)
    elseif state.mode == MODE.ENTITY then
        y = drawEntityTools(y)
    end

    -- Separator before info
    y = y + 10
    love.graphics.setColor(C.SEPARATOR)
    love.graphics.line(PANEL_X + PADDING, y, PANEL_X + PANEL_W - PADDING, y)
    y = y + 10

    -- File operations
    y = drawFileSection(y)

    -- Physics panel
    y = y + 10
    love.graphics.setColor(C.SEPARATOR)
    love.graphics.line(PANEL_X + PADDING, y, PANEL_X + PANEL_W - PADDING, y)
    y = y + 10
    y = drawPhysicsPanel(y)

    -- End scrollable content - compute overflow
    love.graphics.setScissor()
    local contentBottom = y + EditorUI.scrollY
    local visibleHeight = PANEL_H - 120 - 35
    EditorUI.maxScrollY = math.max(0, contentBottom - 120 - visibleHeight)

    -- Status bar at bottom
    drawScrollbar()
    drawStatusBar()
end

local function drawButton(x, y, w, h, text, isActive, id)
    local btn = {x = x, y = y, w = w, h = h, id = id}
    table.insert(buttons, btn)

    local isHovered = (hoveredBtn == id)
    if isActive then
        love.graphics.setColor(C.BTN_ACTIVE)
    elseif isHovered then
        love.graphics.setColor(C.BTN_HOVER)
    else
        love.graphics.setColor(C.BTN)
    end
    love.graphics.rectangle("fill", x, y, w, h, 4)

    if isActive then
        love.graphics.setColor(C.ACCENT)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, w, h, 4)
    end

    love.graphics.setColor(isActive and C.TEXT or (isHovered and C.TEXT or C.TEXT_DIM))
    love.graphics.setFont(fontNormal)
    love.graphics.printf(text, x, y + (h - 13) / 2, w, "center")

    return btn
end

function drawModeTabs(y)
    local tabW = (PANEL_W - PADDING * 2 - BTN_GAP) / 2
    local x = PANEL_X + PADDING

    drawButton(x, y, tabW, BTN_H, "Draw", state.mode == MODE.DRAW, "mode_draw")
    drawButton(x + tabW + BTN_GAP, y, tabW, BTN_H, "Entity", state.mode == MODE.ENTITY, "mode_entity")

    y = y + BTN_H + BTN_GAP

    -- Play test button (full width, green accent)
    local ptBtn = {x = x, y = y, w = PANEL_W - PADDING * 2, h = BTN_H + 4, id = "playtest"}
    table.insert(buttons, ptBtn)
    love.graphics.setColor(0.15, 0.45, 0.25)
    love.graphics.rectangle("fill", ptBtn.x, ptBtn.y, ptBtn.w, ptBtn.h, 4)
    if hoveredBtn == "playtest" then
        love.graphics.setColor(C.ACCENT)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", ptBtn.x, ptBtn.y, ptBtn.w, ptBtn.h, 4)
    end
    love.graphics.setColor(C.TEXT)
    love.graphics.setFont(fontNormal)
    love.graphics.printf("Play Test (F5)", ptBtn.x, ptBtn.y + 8, ptBtn.w, "center")

    return y + ptBtn.h + BTN_GAP
end

function drawDrawTools(y)
    local x = PANEL_X + PADDING
    local fullW = PANEL_W - PADDING * 2
    local btnW = (fullW - BTN_GAP) / 2

    -- Sub-mode toggle: Free Draw | Grid Geom
    drawButton(x, y, btnW, BTN_H, "Free Draw", state.drawSubMode == "FREE", "submode_free")
    drawButton(x + btnW + BTN_GAP, y, btnW, BTN_H, "Cell Stamp", state.drawSubMode == "CELL_STAMP", "submode_cell")
    y = y + BTN_H + BTN_GAP + 4

    -- Separator
    love.graphics.setColor(C.SEPARATOR)
    love.graphics.line(x, y, x + fullW, y)
    y = y + 8

    if state.drawSubMode == "CELL_STAMP" then
        return drawCellStampTools(y)
    end

    -- === Free Draw mode content ===

    -- Section title
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(C.TEXT)
    love.graphics.print("Tools", x, y)
    y = y + 24

    -- Tool buttons (2 per row)
    local tools = {
        {name = "Pen (B)", id = "tool_pen", tool = TOOL.PEN},
        {name = "Eraser (E)", id = "tool_eraser", tool = TOOL.ERASER},
        {name = "Fill (F)", id = "tool_fill", tool = TOOL.FILL},
        {name = "Line (L)", id = "tool_line", tool = TOOL.LINE},
    }
    for i, t in ipairs(tools) do
        local col = ((i - 1) % 2)
        local row = math.floor((i - 1) / 2)
        local bx = x + col * (btnW + BTN_GAP)
        local by = y + row * (BTN_H + BTN_GAP)
        drawButton(bx, by, btnW, BTN_H, t.name, state.tool == t.tool, t.id)
    end
    y = y + math.ceil(#tools / 2) * (BTN_H + BTN_GAP) + 10

    -- Brush size slider
    love.graphics.setFont(fontNormal)
    love.graphics.setColor(C.TEXT)
    love.graphics.print("Brush Size: " .. state.brushSize, x, y)
    y = y + 20

    -- Slider track
    local sliderX = x
    local sliderW = fullW
    local sliderY = y + 4
    love.graphics.setColor(C.BTN)
    love.graphics.rectangle("fill", sliderX, sliderY, sliderW, 6, 3)

    -- Slider fill
    local fillFrac = (state.brushSize - 1) / 7
    love.graphics.setColor(C.ACCENT)
    love.graphics.rectangle("fill", sliderX, sliderY, sliderW * fillFrac, 6, 3)

    -- Slider thumb
    local thumbX = sliderX + sliderW * fillFrac
    love.graphics.setColor(C.TEXT)
    love.graphics.circle("fill", thumbX, sliderY + 3, 8)

    -- Store slider bounds for interaction
    local sliderBtn = {x = sliderX, y = sliderY - 8, w = sliderW, h = 20, id = "brush_slider"}
    table.insert(buttons, sliderBtn)

    y = y + 30

    -- Generate button
    drawButton(x, y, fullW, BTN_H + 4, "Generate Cave (G)", false, "generate")
    y = y + BTN_H + BTN_GAP + 4

    -- Clear button
    drawButton(x, y, fullW, BTN_H, "Clear All (Ctrl+N)", false, "clear")
    y = y + BTN_H + BTN_GAP

    -- Grid toggle
    drawButton(x, y, fullW, BTN_H, "Grid: " .. (state.showGrid and "ON" or "OFF") .. " (H)", state.showGrid, "grid_toggle")
    y = y + BTN_H + BTN_GAP

    return y
end

function drawCellStampTools(y)
    local x = PANEL_X + PADDING
    local fullW = PANEL_W - PADDING * 2
    local btnW = (fullW - BTN_GAP) / 2

    -- Mode toggle: DIG / BUILD
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(C.TEXT)
    love.graphics.print("Mode", x, y)
    y = y + 22
    drawButton(x, y, btnW, BTN_H, "DIG (D)", state.cellMode == "DIG", "cell_dig")
    drawButton(x + btnW + BTN_GAP, y, btnW, BTN_H, "BUILD (B)", state.cellMode == "BUILD", "cell_build")
    y = y + BTN_H + BTN_GAP + 8

    -- Stamp type selector
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(C.TEXT)
    love.graphics.print("Stamps", x, y)
    y = y + 22

    local stamps = {
        {name = "Rect (1)", id = "cell_rect"},
        {name = "Stair (2)", id = "cell_stair"},
        {name = "Thumb (3)", id = "cell_thumb"},
        {name = "Island (4)", id = "cell_island"},
    }
    for i, s in ipairs(stamps) do
        local col = ((i - 1) % 2)
        local row = math.floor((i - 1) / 2)
        local bx = x + col * (btnW + BTN_GAP)
        local by = y + row * (BTN_H + BTN_GAP)
        local stampName = s.id:gsub("cell_", ""):upper()
        local isActive = (state.cellStamp == stampName)
        drawButton(bx, by, btnW, BTN_H, s.name, isActive, s.id)
    end
    y = y + 2 * (BTN_H + BTN_GAP) + 8

    -- Direction (only for stair/thumb)
    if state.cellStamp == "STAIR" or state.cellStamp == "THUMB" then
        love.graphics.setFont(fontNormal)
        love.graphics.setColor(C.TEXT)
        love.graphics.print("Direction (Q/E):", x, y)
        y = y + 20
        local dirs = {
            {name = "TL", id = "cell_dir_tl"},
            {name = "TR", id = "cell_dir_tr"},
            {name = "BL", id = "cell_dir_bl"},
            {name = "BR", id = "cell_dir_br"},
        }
        local dirW = (fullW - BTN_GAP * 3) / 4
        for i, d in ipairs(dirs) do
            local bx = x + (i-1) * (dirW + BTN_GAP)
            drawButton(bx, y, dirW, BTN_H, d.name, state.cellDir == d.name, d.id)
        end
        y = y + BTN_H + BTN_GAP + 4
    end

    -- Size selector
    love.graphics.setFont(fontNormal)
    love.graphics.setColor(C.TEXT)
    love.graphics.print("Size: " .. state.cellSize .. "x (" .. state.cellSize * 12 .. "px)", x, y)
    y = y + 20
    local sizeW = (fullW - BTN_GAP * 3) / 4
    for i = 1, 4 do
        local bx = x + (i-1) * (sizeW + BTN_GAP)
        drawButton(bx, y, sizeW, BTN_H, i .. "x", state.cellSize == i, "cell_size_" .. i)
    end
    y = y + BTN_H + BTN_GAP + 10

    -- Separator
    love.graphics.setColor(C.SEPARATOR)
    love.graphics.line(x, y, x + fullW, y)
    y = y + 8

    -- Generate and Clear
    drawButton(x, y, fullW, BTN_H + 4, "Generate Cave (G)", false, "generate")
    y = y + BTN_H + BTN_GAP + 4
    drawButton(x, y, fullW, BTN_H, "Clear All (Ctrl+N)", false, "clear")
    y = y + BTN_H + BTN_GAP

    return y
end

function drawEntityTools(y)
    local x = PANEL_X + PADDING
    local fullW = PANEL_W - PADDING * 2
    local btnW = (fullW - BTN_GAP) / 2

    -- Entity sub-mode selector
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(C.TEXT)
    love.graphics.print("Place Mode", x, y)
    y = y + 22

    local btn4W = (fullW - BTN_GAP * 3) / 4
    drawButton(x, y, btn4W, BTN_H, "Moth", state.entitySubMode == "BAT", "entity_bat")
    drawButton(x + (btn4W + BTN_GAP), y, btn4W, BTN_H, "Void", state.entitySubMode == "VOID_BAT", "entity_void_bat")
    drawButton(x + (btn4W + BTN_GAP) * 2, y, btn4W, BTN_H, "Jump", state.entitySubMode == "JUMP_BAT", "entity_jump_bat")
    drawButton(x + (btn4W + BTN_GAP) * 3, y, btn4W, BTN_H, "Armor", state.entitySubMode == "ARMOR_BAT", "entity_armor_bat")
    y = y + BTN_H + BTN_GAP
    local btn3W = (fullW - BTN_GAP * 2) / 3
    drawButton(x, y, btn3W, BTN_H, "Mirror", state.entitySubMode == "MIRROR_LINE", "entity_mirror")
    drawButton(x + (btn3W + BTN_GAP), y, btn3W, BTN_H, "Wall", state.entitySubMode == "AIR_WALL", "entity_airwall")
    drawButton(x + (btn3W + BTN_GAP) * 2, y, btn3W, BTN_H, "Safe", state.entitySubMode == "SAFE_ZONE", "entity_safe_zone")
    y = y + BTN_H + BTN_GAP + 6

    -- Instructions
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(C.TEXT_DIM)
    if state.entitySubMode == "MIRROR_LINE" then
        love.graphics.printf("Left click: Place mirror line\nDrag body: Move (grid-snap)\nDrag endpoint: Resize\nRight click: Delete", x, y, fullW, "left")
    else
        love.graphics.printf("Left click: Place moth\nRight click: Set player start\nDrag: Move entity\nRight click on moth: Delete", x, y, fullW, "left")
    end
    y = y + 60

    -- Player start info
    love.graphics.setFont(fontNormal)
    love.graphics.setColor(C.ACCENT)
    love.graphics.print("Player Start:", x, y)
    love.graphics.setColor(C.TEXT)
    love.graphics.print(string.format("(%d, %d)", state.playerStart.x, state.playerStart.y), x + 100, y)
    y = y + 22

    -- Bat count
    love.graphics.setColor(C.ACCENT)
    love.graphics.print("Moths:", x, y)
    love.graphics.setColor(C.TEXT)
    love.graphics.print(tostring(#state.bats), x + 60, y)
    y = y + 20

    -- Bat list
    love.graphics.setFont(fontSmall)
    for i, bat in ipairs(state.bats) do
        local selected = state.selectedEntity and state.selectedEntity.type == "bat"
                        and state.selectedEntity.index == i
        if selected then
            love.graphics.setColor(C.WARN)
        else
            love.graphics.setColor(C.TEXT_DIM)
        end
        love.graphics.print(string.format("  #%d: (%d, %d)", i, bat.x, bat.y), x, y)
        y = y + 16
        if y > PANEL_H - 280 then
            love.graphics.print("  ...", x, y)
            y = y + 16
            break
        end
    end

    -- Selected moth movement properties
    local selBat = nil
    if state.selectedEntity and state.selectedEntity.type == "bat" and state.bats[state.selectedEntity.index] then
        selBat = state.bats[state.selectedEntity.index]
    elseif state.selectedEntity and state.selectedEntity.type == "voidBat" and state.voidBats and state.voidBats[state.selectedEntity.index] then
        selBat = state.voidBats[state.selectedEntity.index]
    elseif state.selectedEntity and state.selectedEntity.type == "jumpBat" and state.jumpBats and state.jumpBats[state.selectedEntity.index] then
        selBat = state.jumpBats[state.selectedEntity.index]
    elseif state.selectedEntity and state.selectedEntity.type == "armorBat" and state.armorBats and state.armorBats[state.selectedEntity.index] then
        selBat = state.armorBats[state.selectedEntity.index]
    end

    if selBat then
        y = y + 8
        love.graphics.setColor(C.SEPARATOR)
        love.graphics.line(x, y, x + fullW, y)
        y = y + 8

        love.graphics.setFont(fontNormal)
        love.graphics.setColor(C.ACCENT)
        love.graphics.print("Movement:", x, y)
        y = y + 20

        -- Direction buttons
        local dirW = (fullW - BTN_GAP * 2) / 3
        local curDir = selBat.moveDir or "NONE"
        drawButton(x, y, dirW, BTN_H, "None", curDir == "NONE", "move_none")
        drawButton(x + dirW + BTN_GAP, y, dirW, BTN_H, "Horiz", curDir == "HORIZONTAL", "move_horiz")
        drawButton(x + (dirW + BTN_GAP) * 2, y, dirW, BTN_H, "Vert", curDir == "VERTICAL", "move_vert")
        y = y + BTN_H + BTN_GAP

        -- Speed buttons
        love.graphics.setColor(C.TEXT_DIM)
        love.graphics.print("Speed:", x, y)
        y = y + 18
        local spdW = (fullW - BTN_GAP * 2) / 3
        local curSpd = selBat.moveSpeed or 0.6
        drawButton(x, y, spdW, BTN_H, "Slow", math.abs(curSpd - 0.3) < 0.1, "move_slow")
        drawButton(x + spdW + BTN_GAP, y, spdW, BTN_H, "Med", math.abs(curSpd - 0.6) < 0.1, "move_med")
        drawButton(x + (spdW + BTN_GAP) * 2, y, spdW, BTN_H, "Fast", math.abs(curSpd - 1.0) < 0.1, "move_fast")
        y = y + BTN_H + BTN_GAP

        -- Start direction toggle
        love.graphics.setColor(C.TEXT_DIM)
        love.graphics.print("Start Dir:", x, y)
        y = y + 18
        local startDir = (selBat.moveStartDir or 1)
        local dirLabel1, dirLabel2
        if curDir == "VERTICAL" then
            dirLabel1, dirLabel2 = "Up First", "Down First"
        else
            dirLabel1, dirLabel2 = "Left First", "Right First"
        end
        local sdW = (fullW - BTN_GAP) / 2
        drawButton(x, y, sdW, BTN_H, dirLabel1, startDir == 1, "move_startdir_pos")
        drawButton(x + sdW + BTN_GAP, y, sdW, BTN_H, dirLabel2, startDir == -1, "move_startdir_neg")
        y = y + BTN_H + BTN_GAP

        -- Distance display + buttons
        love.graphics.setColor(C.TEXT_DIM)
        love.graphics.print("Distance: " .. tostring(selBat.moveDist or 24) .. "px", x, y)
        y = y + 18
        local distW = (fullW - BTN_GAP * 3) / 4
        drawButton(x, y, distW, BTN_H, "12", (selBat.moveDist or 24) == 12, "move_dist_12")
        drawButton(x + distW + BTN_GAP, y, distW, BTN_H, "24", (selBat.moveDist or 24) == 24, "move_dist_24")
        drawButton(x + (distW + BTN_GAP) * 2, y, distW, BTN_H, "36", (selBat.moveDist or 24) == 36, "move_dist_36")
        drawButton(x + (distW + BTN_GAP) * 3, y, distW, BTN_H, "48", (selBat.moveDist or 24) == 48, "move_dist_48")
        y = y + BTN_H + BTN_GAP + 4
    end

    -- Mirror Lines section
    y = y + 10
    love.graphics.setFont(fontNormal)
    love.graphics.setColor(C.ACCENT)
    love.graphics.print("Mirror Lines:", x, y)
    love.graphics.setColor(C.TEXT)
    love.graphics.print(tostring(#state.mirrorLines), x + 110, y)
    y = y + 20

    love.graphics.setFont(fontSmall)
    for i, ml in ipairs(state.mirrorLines) do
        local selected = state.selectedEntity and
            (state.selectedEntity.type == "mirrorLine_body" or
             state.selectedEntity.type == "mirrorLine_left" or
             state.selectedEntity.type == "mirrorLine_right") and
            state.selectedEntity.index == i
        if selected then
            love.graphics.setColor(C.WARN)
        else
            love.graphics.setColor(C.TEXT_DIM)
        end
        love.graphics.print(string.format("  #%d: (%d,%d) len=%d", i, ml.x, ml.y, ml.length), x, y)
        y = y + 16
        if y > PANEL_H - 200 then
            love.graphics.print("  ...", x, y)
            break
        end
    end

    return y
end

function drawFileSection(y)
    local x = PANEL_X + PADDING
    local fullW = PANEL_W - PADDING * 2

    love.graphics.setFont(fontTitle)
    love.graphics.setColor(C.TEXT)
    love.graphics.print("File", x, y)
    y = y + 24

    local btnW = (fullW - BTN_GAP * 2) / 3
    drawButton(x, y, btnW, BTN_H, "Save", false, "save")
    drawButton(x + btnW + BTN_GAP, y, btnW, BTN_H, "Load", false, "load")
    drawButton(x + (btnW + BTN_GAP) * 2, y, btnW, BTN_H, "Levels", false, "levels")
    y = y + BTN_H + BTN_GAP

    -- Import external PNG (from HTML cave generator)
    drawButton(x, y, fullW, BTN_H, "Import PNG (from HTML)", false, "import_png")
    y = y + BTN_H + BTN_GAP

    -- Map name
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(C.TEXT_DIM)
    local nameStr = state.currentMapName .. (state.dirty and " *" or "")
    love.graphics.print("Map: " .. nameStr, x, y)
    y = y + 20

    return y
end

function drawPhysicsPanel(y)
    local x = PANEL_X + PADDING
    local fullW = PANEL_W - PADDING * 2

    love.graphics.setFont(fontTitle)
    love.graphics.setColor(C.TEXT)
    love.graphics.print("Physics", x, y)
    y = y + 22

    love.graphics.setFont(fontSmall)
    local params = {
        {key = "gravity", label = "Gravity", min = 0.01, max = 0.15, step = 0.01},
        {key = "jumpPower", label = "Jump Power", min = 0.5, max = 3.0, step = 0.1},
        {key = "bouncePower", label = "Bounce", min = 0.5, max = 3.0, step = 0.1},
        {key = "maxFallSpeed", label = "Max Fall", min = 1.0, max = 5.0, step = 0.1},
        {key = "moveAccel", label = "Move Accel", min = 0.02, max = 0.3, step = 0.02},
        {key = "maxSpeedX", label = "Max Speed X", min = 0.3, max = 2.5, step = 0.1},
        {key = "friction", label = "Friction", min = 0.5, max = 0.98, step = 0.01},
        {key = "playerW", label = "Player W", min = 4, max = 24, step = 2},
        {key = "playerH", label = "Player H", min = 4, max = 24, step = 2},
        {key = "mothW", label = "Moth W", min = 4, max = 24, step = 2},
        {key = "mothH", label = "Moth H", min = 4, max = 24, step = 2},
    }

    for _, p in ipairs(params) do
        local val = state.physics[p.key]
        love.graphics.setColor(C.TEXT_DIM)
        love.graphics.print(p.label .. ":", x, y)
        love.graphics.setColor(C.TEXT)
        love.graphics.print(string.format("%.2f", val), x + 90, y)
        y = y + 14

        -- Slider track
        local sliderY = y + 2
        local frac = (val - p.min) / (p.max - p.min)
        frac = math.max(0, math.min(1, frac))

        love.graphics.setColor(C.BTN)
        love.graphics.rectangle("fill", x, sliderY, fullW, 6, 3)
        love.graphics.setColor(C.ACCENT)
        love.graphics.rectangle("fill", x, sliderY, fullW * frac, 6, 3)

        -- Slider thumb
        local thumbX = x + fullW * frac
        love.graphics.setColor(C.TEXT)
        love.graphics.circle("fill", thumbX, sliderY + 3, 5)

        -- Store slider bounds for click handling
        local btn = {x = x, y = sliderY - 4, w = fullW, h = 14, id = "phys_" .. p.key}
        table.insert(buttons, btn)

        y = y + 18
    end

    
    -- Export/Import Physics buttons
    y = y + 10
    local phBtnW = (fullW - BTN_GAP) / 2
    drawButton(x, y, phBtnW, BTN_H, "Export", false, "phys_export")
    drawButton(x + phBtnW + BTN_GAP, y, phBtnW, BTN_H, "Import", false, "phys_import")
    y = y + BTN_H + BTN_GAP

return y
end

-- Cached fill percentage (recomputed only when dirty)
local cachedFillPct = 0
local fillDirtyFlag = true

function EditorUI.markFillDirty()
    fillDirtyFlag = true
end

function drawScrollbar()
    -- Draw scrollbar on right edge of panel if content overflows
    if EditorUI.maxScrollY <= 0 then return end
    local trackX = PANEL_X + PANEL_W - 8
    local trackY = 120  -- below toolbar
    local trackH = PANEL_H - 120 - 40
    local thumbRatio = trackH / (trackH + EditorUI.maxScrollY)
    local thumbH = math.max(20, trackH * thumbRatio)
    local thumbY = trackY + (EditorUI.scrollY / EditorUI.maxScrollY) * (trackH - thumbH)

    -- Track
    love.graphics.setColor(0.2, 0.2, 0.2, 0.5)
    love.graphics.rectangle("fill", trackX, trackY, 6, trackH, 3)
    -- Thumb
    love.graphics.setColor(0.5, 0.5, 0.5, 0.7)
    love.graphics.rectangle("fill", trackX, thumbY, 6, thumbH, 3)
end

function drawStatusBar()
    local y = PANEL_H - 35
    love.graphics.setColor(C.HEADER)
    love.graphics.rectangle("fill", PANEL_X, y, PANEL_W, 35)

    love.graphics.setFont(fontSmall)
    love.graphics.setColor(C.TEXT_DIM)
    local x = PANEL_X + PADDING

    -- Cursor position
    if state.cursorInCanvas then
        love.graphics.print(string.format("Pos: %d, %d", state.cursorWorldX, state.cursorWorldY), x, y + 10)
    else
        love.graphics.print("Pos: --", x, y + 10)
    end

    -- Fill percentage (cached, update only when canvas changes)
    if fillDirtyFlag and state.canvas then
        local count = 0
        for py = 0, 191 do
            for px = 0, 107 do
                local _, _, _, a = state.canvas:getPixel(px, py)
                if a > 0.5 then count = count + 1 end
            end
        end
        cachedFillPct = count / (108 * 192) * 100
        fillDirtyFlag = false
    end
    love.graphics.print(string.format("Fill: %.0f%%", cachedFillPct), x + 100, y + 10)

    -- Undo count
    love.graphics.print(string.format("Undo: %d/%d", #state.undoStack, state.maxUndo), x + 190, y + 10)
end

------------------------------------------------------------
-- INPUT
------------------------------------------------------------

function EditorUI.mousepressed(x, y, button)
    if button ~= 1 then return false end

    -- Scrollbar drag (right 12px of panel)
    if x >= PANEL_X + PANEL_W - 12 and EditorUI.maxScrollY > 0 then
        EditorUI.panelDragging = true
        EditorUI.panelDragStartY = y
        EditorUI.panelDragStartScroll = EditorUI.scrollY
        return true
    end

    for _, btn in ipairs(buttons) do
        if x >= btn.x and x <= btn.x + btn.w
           and y >= btn.y and y <= btn.y + btn.h then
            return EditorUI.handleButtonClick(btn.id, x)
        end
    end
    return false
end

function EditorUI.mousemoved(x, y)
    -- Panel scroll dragging
    if EditorUI.panelDragging then
        local dy = y - EditorUI.panelDragStartY
        EditorUI.scrollY = EditorUI.panelDragStartScroll + dy
        EditorUI.scrollY = math.max(0, math.min(EditorUI.maxScrollY, EditorUI.scrollY))
        return
    end

    hoveredBtn = nil
    for _, btn in ipairs(buttons) do
        if x >= btn.x and x <= btn.x + btn.w
           and y >= btn.y and y <= btn.y + btn.h then
            hoveredBtn = btn.id
            break
        end
    end

    -- Handle slider dragging
    if sliderDragging and sliderDragging:sub(1, 5) == "phys_" then
        local key = sliderDragging:sub(6)
        local params = {
            gravity = {min = 0.01, max = 0.15},
            jumpPower = {min = 0.5, max = 3.0},
            bouncePower = {min = 0.5, max = 3.0},
            maxFallSpeed = {min = 1.0, max = 5.0},
            moveAccel = {min = 0.02, max = 0.3},
            maxSpeedX = {min = 0.3, max = 2.5},
            friction = {min = 0.5, max = 0.98},
            playerW = {min = 4, max = 24},
            playerH = {min = 4, max = 24},
            mothW = {min = 4, max = 24},
            mothH = {min = 4, max = 24},
        }
        local p = params[key]
        if p then
            local sliderX = PANEL_X + PADDING
            local sliderW = PANEL_W - PADDING * 2
            local frac = math.max(0, math.min(1, (x - sliderX) / sliderW))
            state.physics[key] = p.min + frac * (p.max - p.min)
        end
    elseif sliderDragging == "brush_slider" then
        local sliderX = PANEL_X + PADDING
        local sliderW = PANEL_W - PADDING * 2
        local frac = math.max(0, math.min(1, (x - sliderX) / sliderW))
        state.brushSize = math.floor(frac * 7) + 1
    end
end

function EditorUI.mousereleased(x, y, button)
    -- Auto-save physics when done dragging a physics slider
    if sliderDragging and sliderDragging:sub(1, 5) == "phys_" then
        EditorRef.exportPhysics()
    end
    sliderDragging = nil
    EditorUI.panelDragging = false
end

function EditorUI.handleButtonClick(id, clickX)
    -- Mode tabs
    if id == "mode_draw" then state.mode = MODE.DRAW; return true end
    if id == "mode_entity" then state.mode = MODE.ENTITY; return true end

    -- Entity sub-mode
    if id == "entity_bat" then state.entitySubMode = "BAT"; return true end
    if id == "entity_void_bat" then state.entitySubMode = "VOID_BAT"; return true end
    if id == "entity_jump_bat" then state.entitySubMode = "JUMP_BAT"; return true end
    if id == "entity_armor_bat" then state.entitySubMode = "ARMOR_BAT"; return true end
    if id == "entity_mirror" then state.entitySubMode = "MIRROR_LINE"; return true end
    if id == "entity_airwall" then state.entitySubMode = "AIR_WALL"; return true end
    if id == "entity_safe_zone" then state.entitySubMode = "SAFE_ZONE"; return true end

    -- Movement property buttons (affect selected bat/voidBat)
    local function getSelectedMoth()
        if not state.selectedEntity then return nil end
        if state.selectedEntity.type == "bat" and state.bats[state.selectedEntity.index] then
            return state.bats[state.selectedEntity.index]
        elseif state.selectedEntity.type == "voidBat" and state.voidBats and state.voidBats[state.selectedEntity.index] then
            return state.voidBats[state.selectedEntity.index]
        elseif state.selectedEntity.type == "jumpBat" and state.jumpBats and state.jumpBats[state.selectedEntity.index] then
            return state.jumpBats[state.selectedEntity.index]
        elseif state.selectedEntity.type == "armorBat" and state.armorBats and state.armorBats[state.selectedEntity.index] then
            return state.armorBats[state.selectedEntity.index]
        end
        return nil
    end
    if id == "move_none" then local m = getSelectedMoth(); if m then m.moveDir = "NONE" end; return true end
    if id == "move_horiz" then local m = getSelectedMoth(); if m then m.moveDir = "HORIZONTAL" end; return true end
    if id == "move_vert" then local m = getSelectedMoth(); if m then m.moveDir = "VERTICAL" end; return true end
    if id == "move_slow" then local m = getSelectedMoth(); if m then m.moveSpeed = 0.3 end; return true end
    if id == "move_med" then local m = getSelectedMoth(); if m then m.moveSpeed = 0.6 end; return true end
    if id == "move_fast" then local m = getSelectedMoth(); if m then m.moveSpeed = 1.0 end; return true end
    if id == "move_startdir_pos" then local m = getSelectedMoth(); if m then m.moveStartDir = 1 end; return true end
    if id == "move_startdir_neg" then local m = getSelectedMoth(); if m then m.moveStartDir = -1 end; return true end
    if id == "move_dist_12" then local m = getSelectedMoth(); if m then m.moveDist = 12 end; return true end
    if id == "move_dist_24" then local m = getSelectedMoth(); if m then m.moveDist = 24 end; return true end
    if id == "move_dist_36" then local m = getSelectedMoth(); if m then m.moveDist = 36 end; return true end
    if id == "move_dist_48" then local m = getSelectedMoth(); if m then m.moveDist = 48 end; return true end


    -- Play test
    if id == "playtest" then
        EditorRef.startPlayTest()
        return true
    end

    -- Draw sub-mode toggle
    if id == "submode_free" then
        if state.gridShape then state.gridShape = nil end  -- cancel active shape
        state.drawSubMode = "FREE"
        return true
    end
    if id == "submode_cell" then
        state.drawSubMode = "CELL_STAMP"
        return true
    end

    -- Cell Stamp mode
    if id == "cell_dig" then state.cellMode = "DIG"; return true end
    if id == "cell_build" then state.cellMode = "BUILD"; return true end

    -- Cell Stamp type
    if id == "cell_rect" then state.cellStamp = "RECT"; return true end
    if id == "cell_stair" then state.cellStamp = "STAIR"; return true end
    if id == "cell_thumb" then state.cellStamp = "THUMB"; return true end
    if id == "cell_island" then state.cellStamp = "ISLAND"; return true end

    -- Cell Stamp direction
    if id == "cell_dir_tl" then state.cellDir = "TL"; return true end
    if id == "cell_dir_tr" then state.cellDir = "TR"; return true end
    if id == "cell_dir_bl" then state.cellDir = "BL"; return true end
    if id == "cell_dir_br" then state.cellDir = "BR"; return true end

    -- Cell Stamp size
    for i = 1, 4 do
        if id == "cell_size_" .. i then state.cellSize = i; return true end
    end

    -- Tools
    if id == "tool_pen" then state.tool = TOOL.PEN; return true end
    if id == "tool_eraser" then state.tool = TOOL.ERASER; return true end
    if id == "tool_fill" then state.tool = TOOL.FILL; return true end
    if id == "tool_line" then state.tool = TOOL.LINE; return true end

    -- Physics export/import
    if id == "phys_export" then
        EditorRef.exportPhysics()
        return true
    end
    if id == "phys_import" then
        EditorRef.importPhysics()
        return true
    end

    -- Physics sliders
    if id and id:sub(1, 5) == "phys_" then
        local key = id:sub(6)
        local params = {
            gravity = {min = 0.01, max = 0.15},
            jumpPower = {min = 0.5, max = 3.0},
            bouncePower = {min = 0.5, max = 3.0},
            maxFallSpeed = {min = 1.0, max = 5.0},
            moveAccel = {min = 0.02, max = 0.3},
            maxSpeedX = {min = 0.3, max = 2.5},
            friction = {min = 0.5, max = 0.98},
            playerW = {min = 4, max = 24},
            playerH = {min = 4, max = 24},
            mothW = {min = 4, max = 24},
            mothH = {min = 4, max = 24},
        }
        local p = params[key]
        if p then
            sliderDragging = id
            local sliderX = PANEL_X + PADDING
            local sliderW = PANEL_W - PADDING * 2
            local frac = math.max(0, math.min(1, (clickX - sliderX) / sliderW))
            state.physics[key] = p.min + frac * (p.max - p.min)
            EditorRef.exportPhysics()  -- auto-save
        end
        return true
    end

    -- Brush slider
    if id == "brush_slider" then
        sliderDragging = "brush_slider"
        local sliderX = PANEL_X + PADDING
        local sliderW = PANEL_W - PADDING * 2
        local frac = math.max(0, math.min(1, (clickX - sliderX) / sliderW))
        state.brushSize = math.floor(frac * 7) + 1
        return true
    end

    -- Generate
    if id == "generate" then
        state.showGeneratePanel = true
        return true
    end

    -- Clear
    if id == "clear" then
        EditorRef.clearCanvas()
        return true
    end

    -- Grid toggle
    if id == "grid_toggle" then
        state.showGrid = not state.showGrid
        return true
    end

    -- File operations
    if id == "save" then
        if state.currentMapName == "untitled" then
            state.currentMapName = "map_" .. os.time()
        end
        EditorRef.saveMap(state.currentMapName)
        return true
    end
    if id == "load" then
        -- Open a simple load dialog (show saved maps, click to load)
        state.showLevelManager = true  -- reuse level manager for now
        return true
    end
    if id == "import_png" then
        -- Open macOS file picker to select PNG
        EditorRef.openFilePicker()
        return true
    end
    if id == "levels" then
        state.showLevelManager = not state.showLevelManager
        return true
    end

    return false
end

return EditorUI
