--[[
    Cave Fall - "CARMINE REQUIEM" Edition
    White Gothic / Parchment + Ink + Blood aesthetic
    Ported from HTML reference: 美术参考1.html
]]

------------------------------------------------------------
-- CONSTANTS
------------------------------------------------------------
local WORLD_W = 108
local WORLD_H = 192

local PHYSICS = {
    GRAVITY      = -0.05,
    JUMP_POWER   =  1.5,
    BOUNCE_POWER =  1.5,
    MAX_FALL_SPEED = 2.2,
    MOVE_ACCEL   = 0.12,
    MAX_SPEED_X  = 1.2,
    FRICTION     = 0.87,
}

-- Carmine Requiem palette
local PAL = {
    PAPER      = {0xea/255, 0xdd/255, 0xcf/255},  -- aged parchment
    PAPER_DIM  = {0xdb/255, 0xce/255, 0xbe/255},  -- slightly darker paper
    INK        = {0x11/255, 0x11/255, 0x11/255},  -- pure ink black
    FADE       = {0x8b/255, 0x8b/255, 0x83/255},  -- faded ink gray
    BLOOD      = {0xc8/255, 0x10/255, 0x2e/255},  -- arterial blood red
    BLOOD_DARK = {0x7a/255, 0x00/255, 0x10/255},  -- dried dark blood
}

-- Sprite data (from HTML reference - Ink Knight & Weeping Moth)
local SPRITE_DATA = {
    -- Player idle frame 1 (9x8)
    playerIdle1 = {
        ".B.....B.",
        ".BB...BB.",
        "..BBBBB..",
        ".BWWWRWB.",
        ".BWWWWWB.",
        ".BBBBBBB.",
        "..B...B..",
        "..B...B..",
    },
    -- Player idle frame 2 (boil)
    playerIdle2 = {
        ".B.....B.",
        ".BB...BB.",
        "..BBBBB..",
        ".BWWWRWB.",
        ".BWWWWWB.",
        "..BBBBB..",
        ".B.....B.",
        ".B.....B.",
    },
    -- Player jump
    playerJump = {
        "..B...B..",
        "..BB.BB..",
        "...BBB...",
        "..BWWRB..",
        ".BWWWWWB.",
        ".BBBBBBB.",
        "...B.B...",
        "...B.B...",
    },
    -- Moth frame A (wings spread, 11x6)
    mothA = {
        "BB.......BB",
        "BWB.....BWB",
        ".BWB...BWB.",
        "..BWWWWWB..",
        "...BWWRB...",
        "....BBB....",
    },
    -- Moth frame B (wings folded, dripping, 11x7)
    mothB = {
        "...........",
        "....BBB....",
        "...BWWRB...",
        "..BWWWWWB..",
        ".BBWBWBWBB.",
        "B.B.....B.B",
        ".....R.....",
    },
}

local STATE = {
    MENU    = "MENU",
    MENU_TRANSITION = "MENU_TRANSITION",
    READY   = "READY",
    PLAYING = "PLAYING",
    DEAD    = "DEAD",
    REWINDING = "REWINDING",
    TRANSITION_OUT = "TRANSITION_OUT",
    TRANSITION_IN  = "TRANSITION_IN",
    GAME_CLEAR = "GAME_CLEAR",
}

-- Menu system
local MenuSystem = {
    fallingLines = {},
    fallingDrops = {},
    titleTime = 0,
    hoveredButton = nil,
    transTimer = 0,
    menuOffsetY = 0,
    blackDropY = -WORLD_H,
    transText = "",
    transTextAlpha = 0,
    -- Settings panel
    showSettings = false,
    settingsSlideY = 100,  -- slide-in offset (100 = hidden below, 0 = visible)
    settingsTransTimer = 0,
    -- Settings values
    volume = 80,        -- 0-100
    shakeEnabled = 2,   -- 0=off, 1=weak, 2=on
}

local MENU_PAL = {
    PAPER    = {0xf4/255, 0xf1/255, 0xea/255},
    PENCIL   = {0x2c/255, 0x2c/255, 0x2c/255},
    PENCIL_L = {0x7a/255, 0x7a/255, 0x7a/255},
    RED      = {0xd1/255, 0x34/255, 0x38/255},
}

-- Fonts (loaded in love.load)
local menuFontLarge = nil   -- title "坠落"
local menuFontMed = nil     -- buttons
local menuFontSmall = nil   -- hints
local menuFontEn = nil      -- "FALL" english subtitle

local function initMenuBackground()
    MenuSystem.fallingLines = {}
    MenuSystem.fallingDrops = {}
    for i = 1, 15 do
        table.insert(MenuSystem.fallingLines, {
            x = math.random() * WORLD_W,
            y = math.random() * WORLD_H,
            length = math.random() * 30 + 15,
            speed = math.random() * 1.5 + 0.5,
            wobble = math.random() * math.pi * 2,
            wobbleSpeed = math.random() * 0.08 + 0.03,
            jitter = {(math.random()-0.5)*3, (math.random()-0.5)*3, (math.random()-0.5)*3, (math.random()-0.5)*3},
        })
    end
    for i = 1, 5 do
        table.insert(MenuSystem.fallingDrops, {
            x = math.random() * WORLD_W,
            y = math.random() * WORLD_H,
            radius = math.random() * 2 + 1,
            speed = math.random() * 3 + 2,
        })
    end
end

local function updateMenuBackground(dt)
    for _, line in ipairs(MenuSystem.fallingLines) do
        line.y = line.y + line.speed
        line.wobble = line.wobble + line.wobbleSpeed
        if line.y > WORLD_H + 30 then
            line.y = -30
            line.x = math.random() * WORLD_W
        end
    end
    for _, drop in ipairs(MenuSystem.fallingDrops) do
        drop.y = drop.y + drop.speed
        if drop.y > WORLD_H + 10 then
            drop.y = -10
            drop.x = math.random() * WORLD_W
        end
    end
    MenuSystem.titleTime = MenuSystem.titleTime + dt
end

local function drawMenuBackground()
    -- Paper background (don't clear fully - allow slight trail for falling items)
    love.graphics.setColor(MENU_PAL.PAPER[1], MENU_PAL.PAPER[2], MENU_PAL.PAPER[3], 1)
    love.graphics.rectangle("fill", 0, 0, WORLD_W, WORLD_H)

    -- Falling scribble lines (pencil gray, light)
    love.graphics.setColor(MENU_PAL.PENCIL_L[1], MENU_PAL.PENCIL_L[2], MENU_PAL.PENCIL_L[3], 0.25)
    love.graphics.setLineWidth(1)
    for _, line in ipairs(MenuSystem.fallingLines) do
        local cx = line.x + math.sin(line.wobble) * 4
        local segLen = line.length / 4
        for i = 1, 3 do
            love.graphics.line(
                cx + line.jitter[i], line.y - (i-1)*segLen,
                cx + line.jitter[i+1], line.y - i*segLen)
        end
    end

    -- Falling ink drops (heavier, darker)
    love.graphics.setColor(MENU_PAL.PENCIL[1], MENU_PAL.PENCIL[2], MENU_PAL.PENCIL[3], 0.6)
    for _, drop in ipairs(MenuSystem.fallingDrops) do
        local stretch = 1 + drop.speed * 0.1
        love.graphics.ellipse("fill", drop.x, drop.y, drop.radius, drop.radius * stretch)
    end

    -- Vignette (pencil shading at edges)
    for i = 0, 12 do
        local a = 0.12 * (1 - i/12)
        love.graphics.setColor(MENU_PAL.PENCIL[1], MENU_PAL.PENCIL[2], MENU_PAL.PENCIL[3], a)
        love.graphics.rectangle("fill", 0, i, WORLD_W, 1)
        love.graphics.rectangle("fill", 0, WORLD_H-1-i, WORLD_W, 1)
        love.graphics.rectangle("fill", i, 0, 1, WORLD_H)
        love.graphics.rectangle("fill", WORLD_W-1-i, 0, 1, WORLD_H)
    end
end

local menuButtons = {
    {text = "\231\187\167\231\187\173\230\184\184\230\136\143", action = "continue", primary = true},   -- 继续游戏
    {text = "\230\150\176\230\184\184\230\136\143", action = "new", primary = false},           -- 新游戏
    {text = "\232\174\190\231\189\174", action = "settings", primary = false},               -- 设置
}

local function drawMenu()
    local offsetY = MenuSystem.menuOffsetY

    -- Title float + slight rotation
    local floatY = math.sin(MenuSystem.titleTime * 1.0) * 4
    local titleY = WORLD_H * 0.22 + floatY + offsetY
    local titleX = WORLD_W / 2

    -- Draw title "坠落" with push/rotation
    love.graphics.push()
    love.graphics.translate(titleX, titleY)
    love.graphics.rotate(math.rad(-3))  -- slight tilt like reference

    -- Shadow layer
    if menuFontLarge then love.graphics.setFont(menuFontLarge) end
    love.graphics.setColor(MENU_PAL.PENCIL_L)
    love.graphics.printf("\229\157\160\232\144\189", -40 + 1, 1, 80, "center")  -- 坠落 shadow
    -- Main title
    love.graphics.setColor(MENU_PAL.PENCIL)
    love.graphics.printf("\229\157\160\232\144\189", -40, 0, 80, "center")  -- 坠落

    -- "FALL" in red, small, offset to bottom-right, rotated more
    if menuFontSmall then love.graphics.setFont(menuFontSmall) end
    love.graphics.setColor(MENU_PAL.RED)
    love.graphics.push()
    love.graphics.translate(28, 18)
    love.graphics.rotate(math.rad(-8))
    love.graphics.print("FALL", 0, 0)
    love.graphics.pop()

    -- Hand-drawn underline (thick, slightly wavy)
    love.graphics.setColor(MENU_PAL.PENCIL)
    love.graphics.setLineWidth(3)
    love.graphics.line(-35, 22, 35, 23)
    love.graphics.line(-33, 23, 33, 24)

    love.graphics.pop()

    -- Menu buttons
    if menuFontMed then love.graphics.setFont(menuFontMed) end
    local btnStartY = WORLD_H * 0.52 + offsetY
    for i, btn in ipairs(menuButtons) do
        local by = btnStartY + (i - 1) * 22
        local isHovered = (MenuSystem.hoveredButton == i)

        -- ALL buttons always show border (so user can see them)
        local borderColor = btn.primary and MENU_PAL.RED or MENU_PAL.PENCIL
        local borderAlpha = isHovered and 0.9 or (btn.primary and 0.5 or 0.3)
        local lineW = isHovered and 2.0 or 1.5
        love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderAlpha)
        love.graphics.setLineWidth(lineW)
        local bx = WORLD_W/2 - 32
        local bw = 64
        local bh = 16
        -- Irregular hand-drawn rectangle
        love.graphics.line(bx-2, by-1, bx+bw+2, by-2)
        love.graphics.line(bx+bw+2, by-2, bx+bw+3, by+bh+1)
        love.graphics.line(bx+bw+3, by+bh+1, bx-1, by+bh+2)
        love.graphics.line(bx-1, by+bh+2, bx-2, by-1)

        -- Hover: slight scale effect (shift text)
        local textOffsetX = isHovered and 1 or 0

        -- Button text
        if isHovered then
            love.graphics.setColor(MENU_PAL.RED)
        else
            love.graphics.setColor(MENU_PAL.PENCIL)
        end
        love.graphics.printf(btn.text, textOffsetX, by + 2, WORLD_W, "center")
    end

end

-- Settings panel
local settingsButtons = {
    {text = "\228\184\187\233\159\179\233\135\143", y = 0, type = "volume"},        -- 主音量
    {text = "\231\148\187\233\157\162\233\156\135\229\138\168", y = 0, type = "shake"},     -- 画面震动
    {text = "\232\191\148\229\155\158\228\184\187\231\149\140\233\157\162", y = 0, type = "back"},  -- 返回主界面
}

local function drawSettings()
    local slideY = MenuSystem.settingsSlideY

    -- Semi-transparent paper background for settings panel
    love.graphics.setColor(MENU_PAL.PAPER[1], MENU_PAL.PAPER[2], MENU_PAL.PAPER[3], 0.92)
    love.graphics.rectangle("fill", 0, slideY, WORLD_W, WORLD_H)

    -- Title "Settings"
    if menuFontMed then love.graphics.setFont(menuFontMed) end
    love.graphics.setColor(MENU_PAL.PENCIL)
    love.graphics.printf("Settings", 0, 25 + slideY, WORLD_W, "center")

    -- Dashed line under title
    love.graphics.setColor(MENU_PAL.PENCIL_L)
    love.graphics.setLineWidth(1)
    for x = 15, WORLD_W - 15, 6 do
        love.graphics.line(x, 40 + slideY, x + 3, 40 + slideY)
    end

    -- Volume setting
    local volY = 55 + slideY
    love.graphics.setColor(MENU_PAL.PENCIL)
    if menuFontSmall then love.graphics.setFont(menuFontSmall) end
    love.graphics.print("\228\184\187\233\159\179\233\135\143", 12, volY)  -- 主音量

    -- Volume value display
    local volText = MenuSystem.volume == 0 and "\233\157\153\233\159\179" or (MenuSystem.volume .. "%")  -- 静音 or XX%
    love.graphics.setColor(MENU_PAL.RED)
    love.graphics.printf(volText, 0, volY, WORLD_W - 12, "right")

    -- Volume bar
    love.graphics.setColor(MENU_PAL.PENCIL_L)
    love.graphics.rectangle("fill", 12, volY + 14, WORLD_W - 24, 4)
    -- Fill bar
    love.graphics.setColor(MENU_PAL.PENCIL)
    local fillW = (WORLD_W - 24) * MenuSystem.volume / 100
    love.graphics.rectangle("fill", 12, volY + 14, fillW, 4)
    -- Thumb
    love.graphics.setColor(MENU_PAL.PAPER)
    love.graphics.circle("fill", 12 + fillW, volY + 16, 5)
    love.graphics.setColor(MENU_PAL.PENCIL)
    love.graphics.circle("line", 12 + fillW, volY + 16, 5)

    -- Shake setting
    local shakeY = 95 + slideY
    love.graphics.setColor(MENU_PAL.PENCIL)
    love.graphics.print("\231\148\187\233\157\162\233\156\135\229\138\168", 12, shakeY)  -- 画面震动

    local shakeTexts = {"\229\133\179", "\229\190\174\229\188\177", "\229\188\128"}  -- 关, 微弱, 开
    love.graphics.setColor(MENU_PAL.RED)
    love.graphics.printf(shakeTexts[MenuSystem.shakeEnabled + 1], 0, shakeY, WORLD_W - 12, "right")

    -- Shake 3-position indicator
    love.graphics.setColor(MENU_PAL.PENCIL_L)
    love.graphics.rectangle("fill", 12, shakeY + 14, WORLD_W - 24, 4)
    -- Current position marker
    local shakeX = 12 + (WORLD_W - 24) * MenuSystem.shakeEnabled / 2
    love.graphics.setColor(MENU_PAL.PAPER)
    love.graphics.circle("fill", shakeX, shakeY + 16, 5)
    love.graphics.setColor(MENU_PAL.PENCIL)
    love.graphics.circle("line", shakeX, shakeY + 16, 5)

    -- Description text
    love.graphics.setColor(MENU_PAL.PENCIL_L)
    love.graphics.printf("\229\143\151\229\135\187\230\151\182\231\148\187\233\157\162\228\188\154\230\138\150\229\138\168", 12, shakeY + 26, WORLD_W - 24, "left")  -- 受击时画面会抖动

    -- Back button
    local backY = 145 + slideY
    local isBackHovered = (MenuSystem.hoveredButton == 10)  -- special ID for settings back
    if isBackHovered then
        love.graphics.setColor(MENU_PAL.RED)
    else
        love.graphics.setColor(MENU_PAL.PENCIL)
    end
    -- Border
    love.graphics.setLineWidth(1.5)
    local bx = WORLD_W/2 - 35
    love.graphics.line(bx, backY, bx+70, backY-1)
    love.graphics.line(bx+70, backY-1, bx+71, backY+14)
    love.graphics.line(bx+71, backY+14, bx-1, backY+15)
    love.graphics.line(bx-1, backY+15, bx, backY)
    -- Text
    if menuFontSmall then love.graphics.setFont(menuFontSmall) end
    love.graphics.printf("\232\191\148\229\155\158\228\184\187\231\149\140\233\157\162", 0, backY + 3, WORLD_W, "center")  -- 返回主界面
end

local function handleSettingsClick(gx, gy)
    local slideY = MenuSystem.settingsSlideY

    -- Volume bar click (y = 55+14 to 55+22, relative to slideY)
    local volBarY = 55 + 14 + slideY
    if gy >= volBarY - 4 and gy <= volBarY + 8 then
        local barX = gx - 12
        local barW = WORLD_W - 24
        if barX >= 0 and barX <= barW then
            MenuSystem.volume = math.floor(barX / barW * 100)
            MenuSystem.volume = math.max(0, math.min(100, MenuSystem.volume))
            return true
        end
    end

    -- Shake bar click (y = 95+14 to 95+22)
    local shakeBarY = 95 + 14 + slideY
    if gy >= shakeBarY - 4 and gy <= shakeBarY + 8 then
        local barX = gx - 12
        local barW = WORLD_W - 24
        if barX >= 0 and barX <= barW then
            local pos = barX / barW
            if pos < 0.33 then MenuSystem.shakeEnabled = 0
            elseif pos < 0.66 then MenuSystem.shakeEnabled = 1
            else MenuSystem.shakeEnabled = 2 end
            return true
        end
    end

    -- Back button (y = 145 to 145+15)
    local backY = 145 + slideY
    if gy >= backY - 2 and gy <= backY + 17 and gx >= 15 and gx <= WORLD_W - 15 then
        -- Close settings, go back to menu
        MenuSystem.showSettings = false
        return true
    end

    return false
end

local function updateSettingsHover(gx, gy)
    local slideY = MenuSystem.settingsSlideY
    local backY = 145 + slideY
    if gy >= backY - 2 and gy <= backY + 17 and gx >= 15 and gx <= WORLD_W - 15 then
        MenuSystem.hoveredButton = 10  -- back button ID
    end
end

local function drawMenuTransition()
    if MenuSystem.blackDropY > -WORLD_H then
        love.graphics.setColor(MENU_PAL.PENCIL)
        love.graphics.rectangle("fill", 0, MenuSystem.blackDropY, WORLD_W, WORLD_H)

        if MenuSystem.transTextAlpha > 0 then
            if menuFontMed then love.graphics.setFont(menuFontMed) end
            love.graphics.setColor(MENU_PAL.PAPER[1], MENU_PAL.PAPER[2], MENU_PAL.PAPER[3], MenuSystem.transTextAlpha)
            love.graphics.printf(MenuSystem.transText, 0, MenuSystem.blackDropY + WORLD_H * 0.45, WORLD_W, "center")
        end
    end
end

local actions = { moveLeft = false, moveRight = false, jump = false }

------------------------------------------------------------
-- LEVEL DATA
------------------------------------------------------------
local levels = require("levels")

------------------------------------------------------------
-- CAVE MAP (bitmap collision + stencil)
------------------------------------------------------------
local caveMapData = {}

local function loadCaveMap(levelNum)
    if caveMapData[levelNum] then return end
    local ld = levels[levelNum]
    local stencilData = love.image.newImageData(ld.stencilFile)
    local stencilImg = love.graphics.newImage(stencilData)
    stencilImg:setFilter("nearest", "nearest")
    caveMapData[levelNum] = {
        stencilData = stencilData,
        stencilImage = stencilImg,
        edgePoints = nil,  -- computed lazily
        thorns = nil,      -- computed lazily
    }
end

local function isInsideCave(levelNum, screenX, screenY)
    local data = caveMapData[levelNum]
    if not data then return false end
    local x = math.floor(screenX)
    local y = math.floor(screenY)
    if x < 0 or x >= WORLD_W or y < 0 or y >= WORLD_H then return false end
    local _, _, _, a = data.stencilData:getPixel(x, y)
    return a > 0.5
end

-- Edge detection: find boundary pixels for thorns
local function computeEdgePoints(levelNum)
    local data = caveMapData[levelNum]
    if data.edgePoints then return data.edgePoints end

    local edges = {}
    local imgData = data.stencilData
    for y = 1, WORLD_H - 2 do
        for x = 1, WORLD_W - 2 do
            local _, _, _, a = imgData:getPixel(x, y)
            if a > 0.5 then
                -- Check if any neighbor is outside cave
                local isEdge = false
                for _, d in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
                    local _, _, _, na = imgData:getPixel(x+d[1], y+d[2])
                    if na < 0.5 then isEdge = true; break end
                end
                if isEdge then
                    table.insert(edges, {x = x, y = y})
                end
            end
        end
    end
    data.edgePoints = edges
    return edges
end

-- Generate thorns from edge points
local function computeThorns(levelNum)
    local data = caveMapData[levelNum]
    if data.thorns then return data.thorns end

    local edges = computeEdgePoints(levelNum)
    local thorns = {}

    -- Sample every Nth edge point and create a thorn
    for i = 1, #edges, 6 do
        if math.random() > 0.4 then
            local ep = edges[i]
            -- Compute inward normal (approximate: toward center of cave)
            local cx, cy = WORLD_W/2, WORLD_H/2
            local dx = cx - ep.x
            local dy = cy - ep.y
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist > 0 then
                dx = dx / dist
                dy = dy / dist
            end
            table.insert(thorns, {
                x = ep.x, y = ep.y,
                nx = dx, ny = dy,
                len = math.random() * 4 + 2,
            })
        end
    end
    data.thorns = thorns
    return thorns
end

------------------------------------------------------------
-- UTILITY
------------------------------------------------------------
local function logicToScreenY(y) return WORLD_H - y end
local function screenToLogicY(y) return WORLD_H - y end

-- Draw pixel sprite from string array
local function drawSprite(spriteArray, sx, sy, flipX)
    local h = #spriteArray
    local w = #spriteArray[1]
    for i = 1, h do
        for j = 1, w do
            local char = spriteArray[i]:sub(j, j)
            local color = nil
            if char == 'B' then color = PAL.INK
            elseif char == 'W' then color = PAL.PAPER
            elseif char == 'R' then color = PAL.BLOOD
            elseif char == 'G' then color = PAL.FADE
            elseif char == 'D' then color = PAL.BLOOD_DARK
            end
            if color then
                love.graphics.setColor(color)
                local px = flipX and (sx + w - j - w/2) or (sx + (j-1) - w/2)
                love.graphics.rectangle("fill", px, sy + (i-1) - h/2, 1.1, 1.1)
            end
        end
    end
end

------------------------------------------------------------
-- ENTITY FACTORIES
------------------------------------------------------------
local function createPlayer(sx, sy)
    return {
        x = sx, y = screenToLogicY(sy),
        w = 9, h = 8,
        vx = 0, vy = 0,
        squash = 1.0, stretch = 1.0,
        grounded = true,
        facingRight = true,
    }
end

local function createMoth(sx, sy)
    return {
        x = sx, y = screenToLogicY(sy),
        w = 11, h = 7,
        active = true,
        hoverOffset = math.random() * math.pi * 2,
    }
end

local function createSpore()
    return { x = math.random() * WORLD_W, y = math.random() * WORLD_H, vx = (math.random()-0.5)*0.05, vy = math.random()*0.1+0.02 }
end

-- Ink/Blood splatter particle
local function createSplatter(x, y, isBlood)
    local ang = math.random() * math.pi * 2
    local spd = math.random() * 3 + 1
    return {
        x = x, y = y,
        vx = math.cos(ang) * spd,
        vy = math.sin(ang) * spd,
        life = 1.0,
        decay = math.random() * 0.04 + 0.02,
        color = isBlood and (math.random() > 0.5 and PAL.BLOOD or PAL.BLOOD_DARK) or PAL.INK,
        size = math.random() > 0.6 and 2 or 1,
        isBlood = isBlood,
    }
end

-- Feather particle (white, floaty)
local function createFeather(x, y)
    return {
        x = x, y = y, baseX = x,
        vy = math.random() * -1.5 - 0.5,
        life = 1.0,
        decay = math.random() * 0.015 + 0.008,
        time = math.random() * 100,
    }
end

-- Persistent decal (blood/ink stain)
local function createDecal(x, y, isBlood)
    return {
        x = x + (math.random() - 0.5) * 16,
        y = y + (math.random() - 0.5) * 16,
        w = math.random() > 0.7 and 2 or 1,
        h = math.random() > 0.7 and 2 or 1,
        color = isBlood and (math.random() > 0.5 and PAL.BLOOD or PAL.BLOOD_DARK) or PAL.INK,
    }
end

-- Crosshatch trail (ink ghost)
local function createGhost(x, y)
    return { x = x, y = y, life = 1.0 }
end

------------------------------------------------------------
-- AUDIO
------------------------------------------------------------
local SFX = {}
local function playSFX(name)
    if SFX[name] then
        SFX[name]:stop()
        SFX[name]:play()
    end
end

------------------------------------------------------------
-- GAME LOGIC
------------------------------------------------------------
local GameLogic = {}

function GameLogic.createWorld()
    local world = {
        state = STATE.MENU,
        currentLevel = 1,
        player = nil,
        targets = {},
        particles = {},  -- splatters
        feathers = {},
        ghosts = {},     -- crosshatch trails
        decals = {},     -- permanent stains
        spores = {},
        shake = 0, flash = 0, flashColor = PAL.BLOOD,
        hitstop = 0,     -- freeze frames
        time = 0,
        frame = 0,
        boilFrame = 0,   -- 0 or 1 for hand-drawn jitter
        transition = { timer = 0, duration = 0.5, radius = 0, phase = nil },
        -- Death rewind system
        playerHistory = {},   -- recorded {x, y} per frame while airborne
        rewindIndex = 0,      -- current playback position during rewind
        rewindSpeed = 4,      -- frames to skip per update (controls rewind speed)
    }
    for i = 1, 15 do table.insert(world.spores, createSpore()) end
    for i = 1, #levels do loadCaveMap(i) end
    GameLogic.loadLevel(world, 1)
    return world
end

function GameLogic.loadLevel(world, n)
    local ld = levels[n]
    if not ld then return end
    world.currentLevel = n
    world.player = createPlayer(ld.playerStart.x, ld.playerStart.y)
    world.targets = {}
    for _, b in ipairs(ld.bats) do table.insert(world.targets, createMoth(b.x, b.y)) end
    world.particles = {}
    world.feathers = {}
    world.ghosts = {}
    world.playerHistory = {}
    world.rewindIndex = 0
    -- Keep some decals for "history" but cap
    if #world.decals > 40 then
        local keep = {}
        for i = #world.decals - 40, #world.decals do
            if world.decals[i] then table.insert(keep, world.decals[i]) end
        end
        world.decals = keep
    end
    world.shake = 0
    world.flash = 0
    world.hitstop = 0
    -- Pre-compute thorns for this level
    computeThorns(n)
end

function GameLogic.resetLevel(world)
    world.state = STATE.READY
    GameLogic.loadLevel(world, world.currentLevel)
end

function GameLogic.startJump(world)
    if world.state == STATE.DEAD then GameLogic.resetLevel(world); return end
    if world.state == STATE.GAME_CLEAR then return end
    if world.state ~= STATE.READY then return end
    world.state = STATE.PLAYING
    playSFX("jump")
    local p = world.player
    p.grounded = false
    p.vy = PHYSICS.JUMP_POWER
    -- Jump ink spray
    for i = 1, 6 do
        table.insert(world.particles, createSplatter(p.x, p.y - 3, false))
    end
end

function GameLogic.triggerDead(world)
    world.state = STATE.DEAD
    playSFX("death")
    world.shake = 15
    world.hitstop = 20  -- after hitstop ends, will transition to REWINDING
    world.flash = 0.5
    world.flashColor = PAL.BLOOD
    local p = world.player
    -- Massive ink + blood explosion
    for i = 1, 40 do
        table.insert(world.particles, createSplatter(p.x, p.y, math.random() > 0.3))
    end
    -- Permanent death stains
    for i = 1, 25 do
        table.insert(world.decals, createDecal(p.x, logicToScreenY(p.y), true))
    end
end

function GameLogic.startRewind(world)
    playSFX("rewind")
    world.state = STATE.REWINDING
    world.rewindIndex = #world.playerHistory
    world.rewindTimer = 0
    world.rewindOverlay = 0.4  -- dark red overlay opacity
    world.particles = {}
    world.feathers = {}
    -- Build the rewind trail (sampled path points for the visible blood-line)
    world.rewindTrail = {}
    for i = 1, #world.playerHistory, 3 do
        local r = world.playerHistory[i]
        table.insert(world.rewindTrail, {x = r.x, y = logicToScreenY(r.y)})
    end
    -- Moths hidden during rewind, will flicker back
    for _, t in ipairs(world.targets) do t.active = false end
    world.mothFlicker = 0
end

function GameLogic.updateRewind(world)
    world.rewindTimer = world.rewindTimer + 1

    if world.rewindIndex <= 1 then
        -- Rewind complete, reset level
        world.rewindOverlay = 0
        world.rewindTrail = nil
        GameLogic.resetLevel(world)
        return
    end

    -- Easing: start slow, end slightly faster (gentle ease-in)
    local totalFrames = #world.playerHistory
    local progress = 1.0 - (world.rewindIndex / totalFrames)  -- 0.0 → 1.0
    local speed = math.floor(1 + progress * 3)  -- 1 at start → 4 at end

    world.rewindIndex = world.rewindIndex - speed
    if world.rewindIndex < 1 then world.rewindIndex = 1 end

    local record = world.playerHistory[world.rewindIndex]
    if record then
        world.player.x = record.x
        world.player.y = record.y
        -- Dense ghost trails EVERY frame during rewind
        table.insert(world.ghosts, createGhost(record.x, logicToScreenY(record.y)))
        -- Blood drip particles along the path
        if world.rewindTimer % 3 == 0 then
            table.insert(world.particles, createSplatter(record.x, record.y, true))
        end
    end

    -- Moths flicker back near the end (last 30%)
    local rewindProgress = world.rewindIndex / totalFrames
    if rewindProgress < 0.3 then
        world.mothFlicker = world.mothFlicker + 1
        -- Flicker: alternate visible/hidden every 4 frames
        local visible = (world.mothFlicker % 8) < 4
        for _, t in ipairs(world.targets) do
            t.active = visible
        end
    end

    -- Fade out overlay as rewind completes
    world.rewindOverlay = 0.4 * rewindProgress
end

function GameLogic.triggerWin(world)
    playSFX("win")
    if world.currentLevel >= #levels then
        world.state = STATE.GAME_CLEAR
        world.flash = 0.4
        world.flashColor = PAL.PAPER
    else
        playSFX("transition")
        world.state = STATE.TRANSITION_OUT
        world.transition.timer = 0
        world.transition.phase = "out"
        world.transition.radius = math.sqrt(WORLD_W^2 + WORLD_H^2)/2
    end
end

function GameLogic.checkCollisions(world)
    local p = world.player
    local sx, sy = p.x, logicToScreenY(p.y)
    if not isInsideCave(world.currentLevel, sx, sy) then
        if p.vy > 0 then
            p.vy = 0
            for i = 1, 10 do
                local testY = logicToScreenY(p.y - i)
                if isInsideCave(world.currentLevel, p.x, testY) then
                    p.y = p.y - i; break
                end
            end
        else
            GameLogic.triggerDead(world)
        end
        return
    end

    local allCleared = true
    for _, t in ipairs(world.targets) do
        if not t.active then goto continue end
        allCleared = false
        if math.abs(p.x - t.x) < (p.w/2 + t.w/2 + 2) and
           math.abs(p.y - t.y) < (p.h/2 + t.h/2 + 2) then
            if p.vy < 0 then
                p.vy = PHYSICS.BOUNCE_POWER
                t.active = false
                playSFX("stomp")
                -- Gothic impact: hitstop + shake
                world.shake = 12
                world.hitstop = 10
                world.flash = 0.3
                world.flashColor = PAL.BLOOD
                -- Blood splatters
                for i = 1, 25 do
                    table.insert(world.particles, createSplatter(t.x, logicToScreenY(t.y), true))
                end
                -- Feathers
                for i = 1, 12 do
                    table.insert(world.feathers, createFeather(t.x, logicToScreenY(t.y)))
                end
                -- Permanent blood decals
                for i = 1, 15 do
                    table.insert(world.decals, createDecal(t.x, logicToScreenY(t.y), true))
                end
            end
        end
        ::continue::
    end
    if allCleared and world.state == STATE.PLAYING then GameLogic.triggerWin(world) end
end

function GameLogic.updatePlayerGrounded(world)
    local p = world.player
    local ld = levels[world.currentLevel]
    if actions.moveLeft then p.vx = p.vx - PHYSICS.MOVE_ACCEL; p.facingRight = false end
    if actions.moveRight then p.vx = p.vx + PHYSICS.MOVE_ACCEL; p.facingRight = true end
    p.vx = p.vx * PHYSICS.FRICTION
    if p.vx > PHYSICS.MAX_SPEED_X then p.vx = PHYSICS.MAX_SPEED_X end
    if p.vx < -PHYSICS.MAX_SPEED_X then p.vx = -PHYSICS.MAX_SPEED_X end
    local newX = p.x + p.vx
    if newX < ld.platformXMin then newX = ld.platformXMin; p.vx = 0
    elseif newX > ld.platformXMax then newX = ld.platformXMax; p.vx = 0 end
    p.x = newX
    p.vy = 0
end

function GameLogic.updatePlayerAirborne(world)
    local p = world.player
    if actions.moveLeft then p.vx = p.vx - PHYSICS.MOVE_ACCEL; p.facingRight = false end
    if actions.moveRight then p.vx = p.vx + PHYSICS.MOVE_ACCEL; p.facingRight = true end
    p.vx = p.vx * PHYSICS.FRICTION
    if p.vx > PHYSICS.MAX_SPEED_X then p.vx = PHYSICS.MAX_SPEED_X end
    if p.vx < -PHYSICS.MAX_SPEED_X then p.vx = -PHYSICS.MAX_SPEED_X end
    p.x = p.x + p.vx
    p.vy = p.vy + PHYSICS.GRAVITY
    if p.vy < -PHYSICS.MAX_FALL_SPEED then p.vy = -PHYSICS.MAX_FALL_SPEED end
    p.y = p.y + p.vy

    -- Record position for death rewind
    table.insert(world.playerHistory, {x = p.x, y = p.y})

    -- Ink ghost trails when moving fast
    if (math.abs(p.vx) > 0.8 or math.abs(p.vy) > 0.8) and world.frame % 3 == 0 then
        table.insert(world.ghosts, createGhost(p.x, logicToScreenY(p.y)))
    end
    -- Occasional ink drip
    if math.random() < 0.08 then
        table.insert(world.particles, createSplatter(p.x, p.y - 2, false))
    end
end

function GameLogic.updatePlayer(world)
    if world.player.grounded then
        GameLogic.updatePlayerGrounded(world)
    else
        GameLogic.updatePlayerAirborne(world)
    end
end

function GameLogic.update(world, dt)
    world.time = world.time + dt * 1000
    world.frame = world.frame + 1
    -- Boil animation: switch frame every 8 frames
    if world.frame % 8 == 0 then
        world.boilFrame = world.boilFrame == 0 and 1 or 0
    end

    -- Menu states
    if world.state == STATE.MENU then
        updateMenuBackground(dt)
        return
    end

    if world.state == STATE.MENU_TRANSITION then
        updateMenuBackground(dt)
        MenuSystem.transTimer = MenuSystem.transTimer + dt

        -- Phase 1 (0-0.2s): invert flash + shake
        if MenuSystem.transTimer < 0.2 then
            menuInvertTimer = 1.0
            menuIsFalling = true
        -- Phase 2 (0.2-0.8s): menu flies up violently
        elseif MenuSystem.transTimer < 0.8 then
            local p = (MenuSystem.transTimer - 0.2) / 0.6
            local ep = 1 - (1 - p) * (1 - p) * (1 - p)
            MenuSystem.menuOffsetY = -150 * ep
        -- Phase 3 (0.8-1.2s): humor text appears
        elseif MenuSystem.transTimer < 1.2 then
            MenuSystem.menuOffsetY = -150
            menuHumorAlpha = 1.0
        -- Phase 4 (1.2-2.5s): hold, background keeps falling fast
        elseif MenuSystem.transTimer < 2.5 then
            menuHumorAlpha = math.max(0, menuHumorAlpha - dt * 0.8)
        -- Phase 5 (2.5+): start game
        else
            menuHumorAlpha = 0
            menuIsFalling = false
            MenuSystem.menuOffsetY = 0
            world.state = STATE.READY
        end
        return
    end

    -- Hitstop: freeze everything
    if world.hitstop > 0 then
        world.hitstop = world.hitstop - 1
        -- When hitstop ends after death, start rewind
        if world.hitstop == 0 and world.state == STATE.DEAD then
            GameLogic.startRewind(world)
        end
        return
    end

    -- Rewind state: play back player path in reverse
    if world.state == STATE.REWINDING then
        GameLogic.updateRewind(world)
        -- Still update ghosts during rewind for visual
        for i = #world.ghosts, 1, -1 do
            world.ghosts[i].life = world.ghosts[i].life - 0.1
            if world.ghosts[i].life <= 0 then table.remove(world.ghosts, i) end
        end
        return
    end

    -- Transitions
    if world.state == STATE.TRANSITION_OUT or world.state == STATE.TRANSITION_IN then
        local t = world.transition
        t.timer = t.timer + dt
        local maxR = math.sqrt(WORLD_W^2 + WORLD_H^2)/2
        if t.phase == "out" then
            if t.timer / t.duration >= 1 then
                t.phase = "in"; t.timer = 0
                GameLogic.loadLevel(world, world.currentLevel + 1)
                world.state = STATE.TRANSITION_IN
            else
                t.radius = maxR * (1 - t.timer / t.duration)
            end
        elseif t.phase == "in" then
            if t.timer / t.duration >= 1 then
                world.state = STATE.READY; t.phase = nil
            else
                t.radius = maxR * (t.timer / t.duration)
            end
        end
        return
    end

    if world.shake > 0 then world.shake = world.shake * 0.82 end
    if world.shake < 0.5 then world.shake = 0 end
    if world.flash > 0 then world.flash = world.flash - 0.03 end

    -- Update particles
    for i = #world.particles, 1, -1 do
        local p = world.particles[i]
        p.x = p.x + p.vx; p.y = p.y + p.vy
        p.vy = p.vy + 0.06 * 0.6  -- gravity on particles (screen space)
        p.life = p.life - p.decay
        if p.life <= 0 then table.remove(world.particles, i) end
    end
    -- Feathers
    for i = #world.feathers, 1, -1 do
        local f = world.feathers[i]
        f.time = f.time + 0.1
        f.vy = f.vy + 0.05
        if f.vy > 1.0 then f.vy = 1.0 end
        f.y = f.y + f.vy
        f.x = f.baseX + math.sin(f.time) * 6
        f.life = f.life - f.decay
        if f.life <= 0 then table.remove(world.feathers, i) end
    end
    -- Ghosts
    for i = #world.ghosts, 1, -1 do
        world.ghosts[i].life = world.ghosts[i].life - 0.1
        if world.ghosts[i].life <= 0 then table.remove(world.ghosts, i) end
    end
    -- Spores
    for _, s in ipairs(world.spores) do
        s.x = s.x + s.vx; s.y = s.y + s.vy
        if s.y > WORLD_H then s.y = 0 end
        if s.x < 0 then s.x = WORLD_W end; if s.x > WORLD_W then s.x = 0 end
    end

    -- Actions
    if actions.jump then
        if world.state == STATE.READY or world.state == STATE.DEAD then
            GameLogic.startJump(world)
        end
        actions.jump = false
    end

    if world.state == STATE.READY then
        GameLogic.updatePlayerGrounded(world)
    elseif world.state == STATE.PLAYING then
        GameLogic.updatePlayer(world)
        GameLogic.checkCollisions(world)
    end
end

------------------------------------------------------------
-- RENDER
------------------------------------------------------------
local GameRender = {}
local renderState = { scale = 1, offsetX = 0, offsetY = 0, uiPulse = 0, invertTimer = 0 }

function GameRender.init()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.graphics.setLineStyle("rough")
end

function GameRender.resize()
    local w, h = love.graphics.getDimensions()
    renderState.scale = math.min(w / WORLD_W, h / WORLD_H)
    renderState.offsetX = (w - WORLD_W * renderState.scale) / 2
    renderState.offsetY = (h - WORLD_H * renderState.scale) / 2
end

-- Off-screen canvas for cave interior (created once)
local caveInteriorCanvas = nil

function GameRender.drawCave(world)
    local data = caveMapData[world.currentLevel]
    if not data then return end

    -- Create canvas if needed
    if not caveInteriorCanvas then
        caveInteriorCanvas = love.graphics.newCanvas(WORLD_W, WORLD_H)
        caveInteriorCanvas:setFilter("nearest", "nearest")
    end

    -- Step 1: Render cave interior content to off-screen canvas
    love.graphics.setCanvas(caveInteriorCanvas)
    love.graphics.clear(0, 0, 0, 0)  -- transparent background
    love.graphics.push()
    love.graphics.origin()  -- reset transform for canvas drawing

    -- Paper base
    love.graphics.setColor(PAL.PAPER_DIM)
    love.graphics.rectangle("fill", 0, 0, WORLD_W, WORLD_H)

    -- Crosshatch pattern
    love.graphics.setColor(PAL.FADE[1], PAL.FADE[2], PAL.FADE[3], 0.4)
    love.graphics.setLineWidth(1)
    for i = -20, WORLD_W + 40, 12 do
        love.graphics.line(i, 0, i - 50, WORLD_H)
        love.graphics.line(i, 0, i + 50, WORLD_H)
    end
    for i = 0, WORLD_H, 12 do
        love.graphics.line(0, i, WORLD_W, i)
    end

    -- Permanent decals
    for _, d in ipairs(world.decals) do
        love.graphics.setColor(d.color)
        love.graphics.rectangle("fill", math.floor(d.x), math.floor(d.y), d.w, d.h)
    end

    -- Floating spores
    for _, s in ipairs(world.spores) do
        local sy = logicToScreenY(s.y)
        love.graphics.setColor(PAL.FADE[1], PAL.FADE[2], PAL.FADE[3], 0.3)
        love.graphics.rectangle("fill", s.x, sy, 1, 1)
    end

    love.graphics.pop()
    love.graphics.setCanvas()  -- back to main screen

    -- Step 2: Fill screen with pure black (the void/ink)
    love.graphics.setColor(PAL.INK)
    love.graphics.rectangle("fill", 0, 0, WORLD_W, WORLD_H)

    -- Step 3: Use stencil to composite cave interior canvas ONLY where cave exists
    love.graphics.stencil(function()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(data.stencilImage, 0, 0)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(caveInteriorCanvas, 0, 0)

    love.graphics.setStencilTest()

    -- Step 4: Thick 3px ink border
    local edges = computeEdgePoints(world.currentLevel)
    love.graphics.setColor(PAL.INK)
    for i = 1, #edges do
        local ep = edges[i]
        love.graphics.rectangle("fill", ep.x - 1, ep.y - 1, 3, 3)
    end

    -- Step 5: Thorns along edges
    local thorns = computeThorns(world.currentLevel)
    love.graphics.setColor(PAL.INK)
    for _, t in ipairs(thorns) do
        local wind = math.sin(world.time * 0.003 + t.y) * 1.5
        love.graphics.polygon("fill",
            t.x, t.y,
            t.x + t.nx * t.len + wind, t.y + t.ny * t.len,
            t.x + t.ny * 2, t.y - t.nx * 2)
    end
end

function GameRender.drawGhosts(world)
    love.graphics.setColor(PAL.FADE)
    for _, g in ipairs(world.ghosts) do
        if g.life <= 0 then goto c end
        love.graphics.setColor(PAL.FADE[1], PAL.FADE[2], PAL.FADE[3], g.life * 0.5)
        love.graphics.rectangle("fill", math.floor(g.x) - 2, math.floor(g.y), 1, 3)
        love.graphics.rectangle("fill", math.floor(g.x) + 2, math.floor(g.y) - 2, 1, 3)
        ::c::
    end
end

function GameRender.drawMoths(world)
    for _, t in ipairs(world.targets) do
        if not t.active then goto c end
        local sy = logicToScreenY(t.y)
        local floatY = math.floor(math.sin(world.time * 0.005 + t.hoverOffset) * 3)
        local sprite = world.boilFrame == 0 and SPRITE_DATA.mothA or SPRITE_DATA.mothB
        -- Add boil jitter
        local jitterX = world.boilFrame == 0 and 0 or 1
        drawSprite(sprite, t.x + jitterX, sy + floatY, false)
        ::c::
    end
end

function GameRender.drawPlayer(world)
    if world.state == STATE.DEAD then return end  -- hidden during hitstop, visible during rewind
    local p = world.player
    local sy = logicToScreenY(p.y)

    -- During rewind: flicker semi-transparent with red tint
    if world.state == STATE.REWINDING then
        local flicker = (world.frame % 4 < 2) and 0.8 or 0.4
        love.graphics.setColor(PAL.BLOOD[1], PAL.BLOOD[2], PAL.BLOOD[3], flicker)
        love.graphics.rectangle("fill", math.floor(p.x) - 4, math.floor(sy) - 4, 9, 8)
        return
    end

    -- Select sprite based on state
    local sprite
    if not p.grounded and math.abs(p.vy) > 0.3 then
        sprite = SPRITE_DATA.playerJump
    else
        sprite = world.boilFrame == 0 and SPRITE_DATA.playerIdle1 or SPRITE_DATA.playerIdle2
    end

    -- Boil jitter
    local jitterX = world.boilFrame == 0 and 0 or 1
    drawSprite(sprite, math.floor(p.x) + jitterX, math.floor(sy), not p.facingRight)
end

function GameRender.drawParticles(world)
    -- Splatters
    for _, p in ipairs(world.particles) do
        if p.life <= 0 then goto c end
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], p.life)
        love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), p.size, p.size)
        ::c::
    end
    -- Feathers (white, visible against dark ink background)
    for _, f in ipairs(world.feathers) do
        if f.life <= 0 then goto c end
        love.graphics.setColor(PAL.PAPER[1], PAL.PAPER[2], PAL.PAPER[3], f.life)
        love.graphics.rectangle("fill", math.floor(f.x), math.floor(f.y), 2, 1)
        love.graphics.rectangle("fill", math.floor(f.x) + 1, math.floor(f.y) - 1, 1, 1)
        ::c::
    end
end

function GameRender.drawRewind(world)
    if world.state ~= STATE.REWINDING then return end
    if not world.rewindTrail then return end

    -- Draw blood-red path line (the full trajectory visible)
    love.graphics.setColor(PAL.BLOOD[1], PAL.BLOOD[2], PAL.BLOOD[3], 0.7)
    love.graphics.setLineWidth(1.5)
    for i = 2, #world.rewindTrail do
        local a = world.rewindTrail[i-1]
        local b = world.rewindTrail[i]
        love.graphics.line(a.x, a.y, b.x, b.y)
    end

    -- Draw dark red overlay (time anomaly atmosphere)
    if world.rewindOverlay and world.rewindOverlay > 0 then
        love.graphics.setColor(PAL.BLOOD_DARK[1], PAL.BLOOD_DARK[2], PAL.BLOOD_DARK[3], world.rewindOverlay)
        love.graphics.rectangle("fill", 0, 0, WORLD_W, WORLD_H)
    end
end

function GameRender.drawFlash(world)
    if world.flash > 0 then
        local c = world.flashColor
        love.graphics.setColor(c[1], c[2], c[3], world.flash * 0.4)
        love.graphics.rectangle("fill", 0, 0, WORLD_W, WORLD_H)
    end
end

function GameRender.drawTransition(world)
    if world.state ~= STATE.TRANSITION_OUT and world.state ~= STATE.TRANSITION_IN then return end
    love.graphics.stencil(function()
        love.graphics.circle("fill", WORLD_W/2, WORLD_H/2, world.transition.radius)
    end, "replace", 1)
    love.graphics.setStencilTest("equal", 0)
    love.graphics.setColor(PAL.INK)
    love.graphics.rectangle("fill", 0, 0, WORLD_W, WORLD_H)
    love.graphics.setStencilTest()
end

function GameRender.drawUI(world, dt)
    -- No UI overlay - removed per user request
end

-- Forward declaration
local startMenuTransition

-- Menu rendering state
local menuDragging = nil
local menuBgScrollY = 0
local menuIsFalling = false
local menuHumorText = ""
local menuHumorAlpha = 0
local menuInvertTimer = 0

-- Menu fonts (loaded in love.load)
local menuFontGothic = nil  -- Pirata One for "FALL"

local function drawMenuNative(dt)
    local sw, sh = love.graphics.getDimensions()
    local frameW = math.min(sw, sh * 9/16)
    local frameH = frameW * 16/9
    local frameX = (sw - frameW) / 2
    local frameY = (sh - frameH) / 2

    -- Virtual pixel scale (HTML uses 120x213 virtual canvas)
    local VW, VH = 120, 213
    local px = frameW / VW  -- pixel scale factor

    local boilFrame = math.floor(MenuSystem.titleTime * 8) % 2
    local boilOff = boilFrame  -- 0 or 1 pixel offset for boil effect

    -- Update scroll
    local fallSpeed = menuIsFalling and 8 or 0.8
    menuBgScrollY = menuBgScrollY + fallSpeed

    love.graphics.clear(0.02, 0.02, 0.02)

    -- Paper background
    love.graphics.setColor(MENU_PAL.PAPER)
    love.graphics.rectangle("fill", frameX, frameY, frameW, frameH)

    -- === CANVAS LAYER: pixel-art background at virtual resolution ===

    -- 1. Scrolling hatch lines (1px wide, 30px tall, every 15px, alpha 0.4)
    love.graphics.setColor(PAL.FADE[1], PAL.FADE[2], PAL.FADE[3], 0.4)
    for x = 5, VW, 15 do
        -- First layer
        local y1 = (x * 13 + menuBgScrollY) % (VH + 50) - 50
        love.graphics.rectangle("fill", frameX + x*px, frameY + y1*px, px, 30*px)
        -- Second layer (offset, different speed)
        local y2 = (x * 7 + menuBgScrollY * 1.5) % (VH + 50) - 50
        love.graphics.rectangle("fill", frameX + (x+3)*px, frameY + y2*px, px, 20*px)
    end

    -- 2. Ink walls (left and right edges, 4-5px wide, scrolling + boil jitter)
    love.graphics.setColor(MENU_PAL.PENCIL)
    for y = 0, VH, 4 do
        local offset = ((y + menuBgScrollY) % 10 < 5) and 1 or 0
        local wallWidth = 4 + offset + boilOff
        love.graphics.rectangle("fill", frameX, frameY + y*px, wallWidth*px, 4*px)
        love.graphics.rectangle("fill", frameX + frameW - (4 + offset + boilOff)*px, frameY + y*px, (5)*px, 4*px)
    end

    -- 3. Background moths (actual sprites flying upward)
    for i = 1, math.min(2, #MenuSystem.fallingDrops) do
        local m = MenuSystem.fallingDrops[i]
        local mx = frameX + (m.x / WORLD_W) * frameW + math.sin(MenuSystem.titleTime * 3 + i*50) * 2*px
        local my = frameY + (m.y / WORLD_H) * frameH
        -- Draw moth sprite using SPRITE_DATA
        local sprite = boilFrame == 0 and SPRITE_DATA.mothA or SPRITE_DATA.mothB
        local h = #sprite
        local w = #sprite[1]
        for row = 1, h do
            for col = 1, w do
                local ch = sprite[row]:sub(col, col)
                local color = nil
                if ch == 'B' then color = MENU_PAL.PENCIL
                elseif ch == 'W' then color = MENU_PAL.PAPER
                elseif ch == 'R' then color = MENU_PAL.RED
                end
                if color then
                    love.graphics.setColor(color)
                    love.graphics.rectangle("fill", mx + (col-1)*px, my + (row-1)*px, px, px)
                end
            end
        end
    end

    -- 4. Falling knight (center, 60% down, boil jitter)
    local knightY = frameY + frameH * 0.6 + math.sin(MenuSystem.titleTime * 2) * 2*px
    local knightX = frameX + frameW/2 - 4*px + boilOff*px
    local knightSprite = SPRITE_DATA.playerJump
    for row = 1, #knightSprite do
        for col = 1, #knightSprite[1] do
            local ch = knightSprite[row]:sub(col, col)
            local color = nil
            if ch == 'B' then color = MENU_PAL.PENCIL
            elseif ch == 'W' then color = MENU_PAL.PAPER
            elseif ch == 'R' then color = MENU_PAL.RED
            end
            if color then
                love.graphics.setColor(color)
                love.graphics.rectangle("fill", knightX + (col-1)*px, knightY + (row-1)*px, px, px)
            end
        end
    end

    -- Speed trail above knight when falling fast
    if menuIsFalling then
        love.graphics.setColor(PAL.FADE[1], PAL.FADE[2], PAL.FADE[3], 0.5)
        love.graphics.rectangle("fill", knightX + 2*px, knightY - 10*px, 4*px, 8*px)
    end

    -- 5. Heavy vignette (matching HTML: transparent at 40%, ink 0.8 at edges)
    for i = 0, 50 do
        local a = 0.5 * (1 - i/50) * (1 - i/50)  -- quadratic falloff, much heavier
        love.graphics.setColor(MENU_PAL.PENCIL[1], MENU_PAL.PENCIL[2], MENU_PAL.PENCIL[3], a)
        love.graphics.rectangle("fill", frameX, frameY + i, frameW, 1)
        love.graphics.rectangle("fill", frameX, frameY + frameH - 1 - i, frameW, 1)
        love.graphics.rectangle("fill", frameX + i, frameY, 1, frameH)
        love.graphics.rectangle("fill", frameX + frameW - 1 - i, frameY, 1, frameH)
    end

    -- === UI LAYER (native resolution, on top of canvas) ===
    local offsetY = MenuSystem.menuOffsetY * (frameH / WORLD_H)

    if MenuSystem.showSettings then
        -- Settings panel background
        love.graphics.setColor(MENU_PAL.PAPER[1], MENU_PAL.PAPER[2], MENU_PAL.PAPER[3], 0.95)
        love.graphics.rectangle("fill", frameX, frameY, frameW, frameH)

        -- Title "CONFIG" in gothic
        love.graphics.setFont(menuFontGothic or menuFontLarge)
        love.graphics.setColor(MENU_PAL.PENCIL)
        love.graphics.printf("CONFIG", frameX, frameY + frameH*0.06, frameW, "center")

        -- Divider
        love.graphics.setLineWidth(2)
        love.graphics.line(frameX + frameW*0.1, frameY + frameH*0.15, frameX + frameW*0.9, frameY + frameH*0.15)

        -- Volume
        love.graphics.setFont(menuFontMed)
        local volY = frameY + frameH * 0.20
        love.graphics.setColor(MENU_PAL.PENCIL)
        love.graphics.print("\228\184\187\233\159\179\233\135\143", frameX + frameW*0.1, volY)
        love.graphics.setColor(MENU_PAL.RED)
        love.graphics.printf(tostring(MenuSystem.volume), frameX, volY, frameW*0.9, "right")

        love.graphics.setFont(menuFontSmall)
        love.graphics.setColor(MENU_PAL.RED)
        love.graphics.rectangle("fill", frameX + frameW*0.1, volY + frameH*0.045, 2, frameH*0.025)
        love.graphics.setColor(MENU_PAL.PENCIL_L)
        love.graphics.print("\230\142\167\229\136\182\229\133\168\229\177\128\233\159\179\230\149\136\227\128\130", frameX + frameW*0.12, volY + frameH*0.045)

        local barX = frameX + frameW * 0.1
        local barW = frameW * 0.8
        local barY = volY + frameH * 0.09
        love.graphics.setColor(MENU_PAL.PENCIL)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(barX, barY, barX + barW, barY)
        local thumbX = barX + barW * MenuSystem.volume / 100
        love.graphics.rectangle("fill", thumbX - 3, barY - 8, 6, 16)
        MenuSystem.volBarBounds = {x = barX, y = barY - 12, w = barW, h = 24}

        -- Shake
        local shakeY = frameY + frameH * 0.38
        love.graphics.setFont(menuFontMed)
        love.graphics.setColor(MENU_PAL.PENCIL)
        love.graphics.print("\231\148\187\233\157\162\233\156\135\229\138\168", frameX + frameW*0.1, shakeY)
        love.graphics.setColor(MENU_PAL.RED)
        love.graphics.printf(tostring(MenuSystem.shakeEnabled * 50), frameX, shakeY, frameW*0.9, "right")

        love.graphics.setFont(menuFontSmall)
        love.graphics.setColor(MENU_PAL.RED)
        love.graphics.rectangle("fill", frameX + frameW*0.1, shakeY + frameH*0.045, 2, frameH*0.025)
        love.graphics.setColor(MENU_PAL.PENCIL_L)
        love.graphics.print("\229\143\151\229\135\187\230\151\182\229\177\143\229\185\149\230\153\131\229\138\168\227\128\130\230\153\149 3D \231\142\169\229\174\182\229\138\161\229\191\133\232\176\131\228\189\142\227\128\130", frameX + frameW*0.12, shakeY + frameH*0.045)

        local sBarY = shakeY + frameH * 0.09
        love.graphics.setColor(MENU_PAL.PENCIL)
        love.graphics.line(barX, sBarY, barX + barW, sBarY)
        local sThumbX = barX + barW * MenuSystem.shakeEnabled / 2
        love.graphics.rectangle("fill", sThumbX - 3, sBarY - 8, 6, 16)
        MenuSystem.shakeBarBounds = {x = barX, y = sBarY - 12, w = barW, h = 24}

        -- Back button
        local backY = frameY + frameH * 0.56
        local isBackHovered = (MenuSystem.hoveredButton == 10)
        love.graphics.setFont(menuFontMed)
        if isBackHovered then
            love.graphics.setColor(MENU_PAL.RED)
        else
            love.graphics.setColor(MENU_PAL.PENCIL)
        end
        love.graphics.printf("\232\191\148\229\155\158\230\183\177\230\184\138", frameX, backY, frameW, "center")
        if isBackHovered then
            love.graphics.setColor(MENU_PAL.RED[1], MENU_PAL.RED[2], MENU_PAL.RED[3], 0.6)
            love.graphics.setLineWidth(frameH * 0.006)
            love.graphics.line(frameX + frameW*0.3, backY + frameH*0.018, frameX + frameW*0.7, backY + frameH*0.016)
        end
        MenuSystem.backBtnBounds = {x = frameX + frameW*0.2, y = backY - 5, w = frameW*0.6, h = frameH*0.05}

    else
        -- === MAIN MENU ===
        -- Title "FALL" with Pirata One gothic font + shadows
        local titleY = frameY + frameH * 0.15 + offsetY + boilOff
        love.graphics.setFont(menuFontGothic or menuFontLarge)

        -- Shadow: paper color offset
        love.graphics.setColor(MENU_PAL.PAPER)
        love.graphics.printf("FALL", frameX + 2, titleY + 2, frameW, "center")
        -- Shadow: blood color deeper offset
        love.graphics.setColor(MENU_PAL.RED[1], MENU_PAL.RED[2], MENU_PAL.RED[3], 0.9)
        love.graphics.printf("FALL", frameX + 4, titleY + 4, frameW, "center")
        -- Main ink title
        love.graphics.setColor(MENU_PAL.PENCIL)
        love.graphics.printf("FALL", frameX + boilOff, titleY, frameW, "center")

        -- Chinese subtitle "坠落" (smaller, dark red, spaced, below title)
        love.graphics.setFont(menuFontMed)
        love.graphics.setColor(MENU_PAL.RED[1]*0.6, 0, MENU_PAL.RED[3]*0.3, 1)
        local cnY = titleY + frameH * 0.10
        love.graphics.printf("\229\157\160    \232\144\189", frameX + boilOff, cnY, frameW, "center")

        -- Thin line under "坠落" (2px height, 80% width of text area, pure ink)
        love.graphics.setColor(MENU_PAL.PENCIL)
        love.graphics.setLineWidth(1.5)
        local lineW = frameW * 0.25
        local lineCX = frameX + frameW/2
        love.graphics.line(lineCX - lineW, cnY + frameH*0.04, lineCX + lineW, cnY + frameH*0.04)

        -- Buttons (STKaiti style, letter-spacing, ink-strike hover)
        MenuSystem.btnBounds = {}
        local btnTexts = {"\231\187\167\231\187\173\230\184\184\230\136\143", "\230\150\176\230\184\184\230\136\143", "\232\174\190\231\189\174\233\157\162\230\157\191"}
        local btnStartY = frameY + frameH * 0.38 + offsetY

        love.graphics.setFont(menuFontMed)
        for i = 1, 3 do
            local by = btnStartY + (i-1) * frameH * 0.07
            local btnW = frameW * 0.6
            local btnH = frameH * 0.05
            local bx = frameX + (frameW - btnW) / 2
            local isHovered = (MenuSystem.hoveredButton == i)

            MenuSystem.btnBounds[i] = {x = bx, y = by, w = btnW, h = btnH}

            -- Boil offset on text
            local tBoil = boilOff * (isHovered and 2 or 1)

            -- Text color
            if isHovered then
                love.graphics.setColor(MENU_PAL.RED[1]*0.6, 0, MENU_PAL.RED[3]*0.3, 1)
            else
                love.graphics.setColor(MENU_PAL.PENCIL)
            end
            love.graphics.printf(btnTexts[i], frameX + tBoil, by, frameW, "center")

            -- Hover: red ink strike-through from left to right
            if isHovered then
                love.graphics.setColor(MENU_PAL.RED[1], MENU_PAL.RED[2], MENU_PAL.RED[3], 0.7)
                love.graphics.setLineWidth(frameH * 0.008)
                love.graphics.line(bx, by + btnH*0.55, bx + btnW, by + btnH*0.52)
            end
        end
    end

    -- Humor text overlay
    if menuHumorAlpha > 0 then
        love.graphics.setFont(menuFontGothic or menuFontLarge)
        -- Shadow
        love.graphics.setColor(MENU_PAL.PENCIL[1], MENU_PAL.PENCIL[2], MENU_PAL.PENCIL[3], menuHumorAlpha * 0.8)
        love.graphics.printf(menuHumorText, frameX + 3, frameY + frameH*0.38 + 3, frameW, "center")
        -- Main
        love.graphics.setColor(MENU_PAL.RED[1], MENU_PAL.RED[2], MENU_PAL.RED[3], menuHumorAlpha)
        love.graphics.printf(menuHumorText, frameX, frameY + frameH*0.38, frameW, "center")
    end

    -- Invert flash
    if menuInvertTimer > 0 then
        love.graphics.setBlendMode("subtract")
        love.graphics.setColor(1, 1, 1, menuInvertTimer * 0.6)
        love.graphics.rectangle("fill", frameX, frameY, frameW, frameH)
        love.graphics.setBlendMode("alpha")
        menuInvertTimer = menuInvertTimer - dt * 3
    end
end

-- Native resolution menu click handler (uses screen pixel coords directly)
local function handleMenuClickNative(sx, sy)
    if gameWorld.state ~= STATE.MENU then return false end

    if MenuSystem.showSettings then
        -- Check volume bar
        local vb = MenuSystem.volBarBounds
        if vb and sy >= vb.y and sy <= vb.y + vb.h and sx >= vb.x and sx <= vb.x + vb.w then
            menuDragging = "volume"
            MenuSystem.volume = math.floor(((sx - vb.x) / vb.w) * 100)
            MenuSystem.volume = math.max(0, math.min(100, MenuSystem.volume))
            return true
        end
        -- Check shake bar
        local sb = MenuSystem.shakeBarBounds
        if sb and sy >= sb.y and sy <= sb.y + sb.h and sx >= sb.x and sx <= sb.x + sb.w then
            menuDragging = "shake"
            local pos = (sx - sb.x) / sb.w
            MenuSystem.shakeEnabled = pos < 0.33 and 0 or (pos < 0.66 and 1 or 2)
            return true
        end
        -- Check back button
        local bb = MenuSystem.backBtnBounds
        if bb and sx >= bb.x and sx <= bb.x + bb.w and sy >= bb.y and sy <= bb.y + bb.h then
            MenuSystem.showSettings = false
            return true
        end
        return false
    end

    -- Main menu buttons
    if MenuSystem.btnBounds then
        for i, bounds in ipairs(MenuSystem.btnBounds) do
            if sx >= bounds.x and sx <= bounds.x + bounds.w and
               sy >= bounds.y and sy <= bounds.y + bounds.h then
                if i == 1 or i == 2 then
                    startMenuTransition()
                elseif i == 3 then
                    MenuSystem.showSettings = true
                    MenuSystem.settingsSlideY = 0
                end
                return true
            end
        end
    end
    return false
end

-- Native hover detection
local function handleMenuHoverNative(sx, sy)
    MenuSystem.hoveredButton = nil

    if MenuSystem.showSettings then
        local bb = MenuSystem.backBtnBounds
        if bb and sx >= bb.x and sx <= bb.x + bb.w and sy >= bb.y and sy <= bb.y + bb.h then
            MenuSystem.hoveredButton = 10
        end
    else
        if MenuSystem.btnBounds then
            for i, bounds in ipairs(MenuSystem.btnBounds) do
                if sx >= bounds.x and sx <= bounds.x + bounds.w and
                   sy >= bounds.y and sy <= bounds.y + bounds.h then
                    MenuSystem.hoveredButton = i
                    break
                end
            end
        end
    end
end

function GameRender.draw(world, dt)
    -- Menu states: render at NATIVE screen resolution (no pixel scaling)
    if world.state == STATE.MENU or world.state == STATE.MENU_TRANSITION then
        drawMenuNative(dt)
        return
    end

    -- Handle invert timer for hitstop visual
    if renderState.invertTimer > 0 then
        renderState.invertTimer = renderState.invertTimer - dt
    end

    love.graphics.clear(PAL.INK)
    love.graphics.push()

    -- Screen shake (integer pixels)
    if world.shake > 0 then
        love.graphics.translate(
            math.floor((math.random()-0.5) * world.shake) * renderState.scale,
            math.floor((math.random()-0.5) * world.shake) * renderState.scale)
    end

    love.graphics.translate(renderState.offsetX, renderState.offsetY)
    love.graphics.scale(renderState.scale, renderState.scale)

    GameRender.drawCave(world)
    GameRender.drawGhosts(world)
    GameRender.drawMoths(world)
    GameRender.drawPlayer(world)
    GameRender.drawParticles(world)
    GameRender.drawRewind(world)
    GameRender.drawFlash(world)
    GameRender.drawTransition(world)

    love.graphics.pop()
    GameRender.drawUI(world, dt)
end

------------------------------------------------------------
-- LOVE2D CALLBACKS
------------------------------------------------------------
gameWorld = nil

-- Sound effects
-- (playSFX moved earlier in file)

function love.load()
    GameRender.init()
    GameRender.resize()

    -- Load fonts
    local cnFontPath = "fonts/PingFang.ttc"
    local gothicPath = "fonts/PirataOne.ttf"
    if love.filesystem.getInfo(cnFontPath) then
        menuFontLarge = love.graphics.newFont(cnFontPath, 52)
        menuFontMed = love.graphics.newFont(cnFontPath, 24)
        menuFontSmall = love.graphics.newFont(cnFontPath, 14)
    else
        menuFontLarge = love.graphics.newFont(52)
        menuFontMed = love.graphics.newFont(24)
        menuFontSmall = love.graphics.newFont(14)
    end
    if love.filesystem.getInfo(gothicPath) then
        menuFontGothic = love.graphics.newFont(gothicPath, 72)
    else
        menuFontGothic = menuFontLarge  -- fallback
    end

    -- Load sound effects
    local soundFiles = {"jump", "stomp", "death", "win", "hover", "menu_click", "rewind", "transition"}
    for _, name in ipairs(soundFiles) do
        local path = "sounds/" .. name .. ".wav"
        if love.filesystem.getInfo(path) then
            SFX[name] = love.audio.newSource(path, "static")
        end
    end

    initMenuBackground()
    gameWorld = GameLogic.createWorld()
end

function love.resize() GameRender.resize() end

function love.update(dt)
    actions.moveLeft = love.keyboard.isDown("left") or love.keyboard.isDown("a")
    actions.moveRight = love.keyboard.isDown("right") or love.keyboard.isDown("d")
    GameLogic.update(gameWorld, dt)
end

function love.draw()
    GameRender.draw(gameWorld, love.timer.getDelta())
end

startMenuTransition = function()
    if gameWorld.state ~= STATE.MENU then return end
    playSFX("menu_click")
    gameWorld.state = STATE.MENU_TRANSITION
    MenuSystem.transTimer = 0
    MenuSystem.menuOffsetY = 0
    MenuSystem.blackDropY = -WORLD_H
    MenuSystem.transTextAlpha = 0
    menuInvertTimer = 1.0
    menuIsFalling = true
    -- Dark humor text (matching HTML reference)
    local jokes = {
        "\230\137\167\229\191\181\228\184\141\230\129\175...",      -- 执念不息...
        "\230\139\165\230\138\177\230\183\177\230\184\138...",      -- 拥抱深渊...
        "\229\149\138\229\149\138\229\149\138\229\149\138\229\149\138...",  -- 啊啊啊啊啊...
        "\228\189\160\232\191\152\228\184\141\230\173\187\229\191\131\229\149\138\239\188\159",  -- 你还不死心啊？
    }
    menuHumorText = jokes[math.random(#jokes)]
end

-- Convert screen pixel coords to game logical coords
local function screenToGame(sx, sy)
    local gx = (sx - renderState.offsetX) / renderState.scale
    local gy = (sy - renderState.offsetY) / renderState.scale
    return gx, gy
end

-- Check which menu button was clicked (returns action string or nil)
local function getMenuButtonAt(gx, gy)
    local btnStartY = WORLD_H * 0.52
    for i, btn in ipairs(menuButtons) do
        local by = btnStartY + (i - 1) * 22
        -- Button hitbox: full width centered, 18px tall
        if gy >= by - 2 and gy <= by + 16 and gx >= 10 and gx <= WORLD_W - 10 then
            return btn.action
        end
    end
    return nil
end

-- Handle menu click
local function handleMenuClick(screenX, screenY)
    if gameWorld.state ~= STATE.MENU then return false end
    local gx, gy = screenToGame(screenX, screenY)

    -- If settings panel is open, handle settings clicks
    if MenuSystem.showSettings then
        return handleSettingsClick(gx, gy)
    end

    -- Main menu buttons
    local action = getMenuButtonAt(gx, gy)
    if action == "continue" or action == "new" then
        startMenuTransition()
        return true
    elseif action == "settings" then
        MenuSystem.showSettings = true
        MenuSystem.settingsSlideY = 0  -- panel fully visible
        return true
    end
    return false
end

function love.keypressed(key)
    if key == "escape" then love.event.quit() end

    -- Menu: keyboard shortcuts
    if gameWorld.state == STATE.MENU then
        if key == "return" then
            startMenuTransition()  -- Enter starts game
        end
        return
    end

    if key == "space" or key == "up" or key == "w" then actions.jump = true end
    if key == "n" then GameLogic.triggerWin(gameWorld) end
    if key == "p" and gameWorld.currentLevel > 1 then
        GameLogic.loadLevel(gameWorld, gameWorld.currentLevel - 1)
        gameWorld.state = STATE.READY
    end
end

function love.mousepressed(x, y, btn)
    if btn == 1 then
        if gameWorld.state == STATE.MENU then
            handleMenuClickNative(x, y)
            return
        elseif gameWorld.state == STATE.READY or gameWorld.state == STATE.DEAD then
            actions.jump = true
        elseif gameWorld.state == STATE.PLAYING then
            if x < love.graphics.getWidth()/2 then actions.moveLeft = true
            else actions.moveRight = true end
        end
    end
end

function love.mousemoved(x, y)
    if gameWorld.state == STATE.MENU then
        local prevHover = MenuSystem.hoveredButton
        handleMenuHoverNative(x, y)
        -- Play hover sound when entering a new button
        if MenuSystem.hoveredButton and MenuSystem.hoveredButton ~= prevHover then
            playSFX("hover")
        end
        -- Handle dragging sliders
        if menuDragging == "volume" and MenuSystem.volBarBounds then
            local vb = MenuSystem.volBarBounds
            MenuSystem.volume = math.floor(((x - vb.x) / vb.w) * 100)
            MenuSystem.volume = math.max(0, math.min(100, MenuSystem.volume))
        elseif menuDragging == "shake" and MenuSystem.shakeBarBounds then
            local sb = MenuSystem.shakeBarBounds
            local pos = (x - sb.x) / sb.w
            MenuSystem.shakeEnabled = pos < 0.33 and 0 or (pos < 0.66 and 1 or 2)
        end
    end
end

function love.mousereleased(x, y, btn)
    if btn == 1 then
        menuDragging = nil  -- stop any slider drag
        if gameWorld.state ~= STATE.MENU then
            if x < love.graphics.getWidth()/2 then actions.moveLeft = false
            else actions.moveRight = false end
        end
    end
end

function love.touchpressed(id, x, y)
    if gameWorld.state == STATE.MENU then
        handleMenuClickNative(x, y)
        return
    elseif gameWorld.state == STATE.READY or gameWorld.state == STATE.DEAD then
        actions.jump = true
    elseif gameWorld.state == STATE.PLAYING then
        if x < love.graphics.getWidth()/2 then actions.moveLeft = true
        else actions.moveRight = true end
    end
end

function love.touchreleased()
    actions.moveLeft = false
    actions.moveRight = false
    for _, tid in ipairs(love.touch.getTouches()) do
        local tx = love.touch.getPosition(tid)
        if tx < love.graphics.getWidth()/2 then actions.moveLeft = true
        else actions.moveRight = true end
    end
end
