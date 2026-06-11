--[[
    Sketch — hand-drawn UI primitives for Cave Fall
    Transcribed from prototypes/ui_prototype.html (approved Steam-grade art)

    Coordinate system: "world" UI coords (108 x 192), mapped to screen via
    a frame transform (ox, oy, s) set each frame with Sketch.beginFrame().
    All sizes (font px, line widths, jitters) are specified in "prototype
    pixels" (world * 4) and scaled by s/4 so the look matches at any window size.

    Features:
    - Deterministic line boil (8fps jitter): jr(id, k)
    - Double-stroke sketch lines with overshoot rects
    - Rough ink blobs / rough-edged ink fills
    - Hand-drawn buttons with ink-fill hover sweep + sfx
    - Per-frame clickable registry (Sketch.click)
    - Procedural paper textures + title ink splat
    - Floating dust ambience
]]

local Sketch = {}

------------------------------------------------------------
-- PALETTES
------------------------------------------------------------
local function hex(h)
    return { tonumber(h:sub(2, 3), 16) / 255, tonumber(h:sub(4, 5), 16) / 255, tonumber(h:sub(6, 7), 16) / 255 }
end

Sketch.PAL = {
    PAPER = hex("#eaddcf"), PAPER_DIM = hex("#dbcebe"), INK = hex("#111111"),
    FADE = hex("#8b8b83"), BLOOD = hex("#c8102e"), BLOOD_DARK = hex("#7a0010"),
}
Sketch.MPAL = {
    PAPER = hex("#f4f1ea"), PENCIL = hex("#2c2c2c"), PENCIL_L = hex("#7a7a7a"), RED = hex("#d13438"),
}
Sketch.CARD = hex("#fbf8f2")
Sketch.HILITE = hex("#e8607a")
Sketch.WHITE = { 1, 1, 1 }

------------------------------------------------------------
-- STATE
------------------------------------------------------------
Sketch.W, Sketch.H = 108, 192
Sketch.time = 0
Sketch.dt = 0.016
Sketch.boilF = 0
Sketch.ox, Sketch.oy, Sketch.s = 0, 0, 4
Sketch.mx, Sketch.my = -999, -999       -- mouse in world coords
Sketch.clickables = {}
Sketch.hoverT = {}
Sketch.lastHover = {}
Sketch.playSFX = function() end
Sketch.fontPath = nil

local fontCache = {}   -- [key] = Font

function Sketch.init(opts)
    opts = opts or {}
    Sketch.fontPath = opts.fontPath
    Sketch.playSFX = opts.playSFX or Sketch.playSFX
end

function Sketch.update(dt)
    Sketch.dt = math.min(0.05, dt)
    Sketch.time = Sketch.time + Sketch.dt
    Sketch.boilF = math.floor(Sketch.time * 8) % 1000
end

-- Set frame transform + clear clickables + refresh mouse world coords
function Sketch.beginFrame(ox, oy, s)
    Sketch.ox, Sketch.oy, Sketch.s = ox, oy, s
    Sketch.clickables = {}
    local mx, my = love.mouse.getPosition()
    Sketch.mx = (mx - ox) / s
    Sketch.my = (my - oy) / s
end

------------------------------------------------------------
-- MATH HELPERS
------------------------------------------------------------
function Sketch.clamp01(t) return math.max(0, math.min(1, t)) end
function Sketch.easeOutCubic(t) return 1 - (1 - Sketch.clamp01(t)) ^ 3 end
function Sketch.easeInOut(t)
    t = Sketch.clamp01(t)
    if t < 0.5 then return 2 * t * t end
    return 1 - ((-2 * t + 2) ^ 2) / 2
end
function Sketch.easeOutBack(t)
    t = Sketch.clamp01(t)
    local c = 1.70158
    return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
end

function Sketch.hashN(n)
    local x = math.sin(n) * 43758.5453
    return x - math.floor(x)
end

local sidCache = {}
function Sketch.sid(str)
    local v = sidCache[str]
    if v then return v end
    local h = 0
    for i = 1, #str do h = (h * 31 + str:byte(i)) % 9973 end
    sidCache[str] = h
    return h
end

-- Deterministic boil jitter in -1..1
function Sketch.jr(id, k)
    return Sketch.hashN(id * 127.1 + k * 311.7 + Sketch.boilF * 74.7) * 2 - 1
end

------------------------------------------------------------
-- FONTS / TEXT
------------------------------------------------------------
local function getFont(px, mono)
    px = math.max(6, math.floor(px + 0.5))
    local key = (mono and "m" or "c") .. px
    local f = fontCache[key]
    if not f then
        if not mono and Sketch.fontPath and love.filesystem.getInfo(Sketch.fontPath) then
            f = love.graphics.newFont(Sketch.fontPath, px)
        else
            f = love.graphics.newFont(px)
        end
        fontCache[key] = f
    end
    return f
end

local function setCol(col, alpha)
    love.graphics.setColor(col[1], col[2], col[3], alpha == nil and 1 or alpha)
end

-- str at world (x,y), size in prototype px, align: "left"|"center"|"right"
function Sketch.text(str, x, y, size, col, align, alpha, bold, mono)
    local s = Sketch.s
    local font = getFont(size * s / 4, mono)
    love.graphics.setFont(font)
    local X = Sketch.ox + x * s
    local Y = Sketch.oy + y * s - font:getHeight() / 2
    local w = font:getWidth(str)
    if align == "center" or align == nil then X = X - w / 2
    elseif align == "right" then X = X - w end
    setCol(col, alpha)
    love.graphics.print(str, math.floor(X), math.floor(Y))
    if bold then
        love.graphics.print(str, math.floor(X) + math.max(1, math.floor(s / 6)), math.floor(Y))
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Sketch.textWidth(str, size, mono)
    local font = getFont(size * Sketch.s / 4, mono)
    return font:getWidth(str) / Sketch.s   -- world units
end

------------------------------------------------------------
-- PRIMITIVES
------------------------------------------------------------
-- Filled rect in world coords
function Sketch.px(x, y, w, h, col, alpha)
    local s = Sketch.s
    setCol(col, alpha)
    love.graphics.rectangle("fill", Sketch.ox + x * s, Sketch.oy + y * s, w * s, h * s)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Double-stroke wobbly line, SCREEN pixel coords
function Sketch.lineScreen(X1, Y1, X2, Y2, col, alpha, lw, id)
    local s4 = Sketch.s / 4
    for p = 0, 1 do
        local function j(k) return Sketch.jr(id + p * 7.3, k) * 1.7 * s4 end
        local mx = (X1 + X2) / 2 + j(1) * 1.6
        local my = (Y1 + Y2) / 2 + j(2) * 1.6
        local ax, ay = X1 + j(3), Y1 + j(4)
        local bx, by = X2 + j(5), Y2 + j(6)
        setCol(col, alpha * (p == 1 and 0.4 or 1))
        love.graphics.setLineWidth(math.max(0.8, lw * s4 * (p == 1 and 0.65 or 1)))
        -- quadratic bezier sampled at 8 segments
        local pts = {}
        for i = 0, 8 do
            local t = i / 8
            local u = 1 - t
            pts[#pts + 1] = u * u * ax + 2 * u * t * mx + t * t * bx
            pts[#pts + 1] = u * u * ay + 2 * u * t * my + t * t * by
        end
        love.graphics.line(pts)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Wobbly line in world coords
function Sketch.line(x1, y1, x2, y2, col, alpha, lw, id)
    local ox, oy, s = Sketch.ox, Sketch.oy, Sketch.s
    Sketch.lineScreen(ox + x1 * s, oy + y1 * s, ox + x2 * s, oy + y2 * s, col, alpha, lw, id)
end

-- Hand-drawn rect with stroke overshoot, world coords
function Sketch.rect(x, y, w, h, col, alpha, lw, id)
    local ox, oy, s = Sketch.ox, Sketch.oy, Sketch.s
    local X, Y = ox + x * s, oy + y * s
    local W2, H2 = w * s, h * s
    local o = 3 * s / 4
    local pxl = s / 4
    Sketch.lineScreen(X - o, Y, X + W2 + o * 0.6, Y - pxl, col, alpha, lw, id + 1)
    Sketch.lineScreen(X + W2 + pxl, Y - o * 0.6, X + W2, Y + H2 + o, col, alpha, lw, id + 2)
    Sketch.lineScreen(X + W2 + o, Y + H2 + pxl, X - o * 0.6, Y + H2, col, alpha, lw, id + 3)
    Sketch.lineScreen(X - pxl, Y + H2 + o * 0.6, X, Y - o, col, alpha, lw, id + 4)
end

-- Rough ink blob, world coords + world radius
function Sketch.blob(cx, cy, r, col, alpha, id)
    if r <= 0 then return end
    local ox, oy, s = Sketch.ox, Sketch.oy, Sketch.s
    local CX, CY, R = ox + cx * s, oy + cy * s, r * s
    local verts = {}
    local N = 26
    for i = 0, N - 1 do
        local a = i / N * math.pi * 2
        local rr = R * (1 + Sketch.jr(id or 1, i) * 0.07)
        verts[#verts + 1] = CX + math.cos(a) * rr
        verts[#verts + 1] = CY + math.sin(a) * rr
    end
    setCol(col, alpha)
    local ok, tris = pcall(love.math.triangulate, verts)
    if ok then
        for _, t in ipairs(tris) do love.graphics.polygon("fill", t) end
    else
        love.graphics.circle("fill", CX, CY, R)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Ink fill with rough right edge (hover ink sweep), world coords
function Sketch.fillRect(x, y, w, h, col, alpha, id)
    if w <= 0.3 then return end
    local ox, oy, s = Sketch.ox, Sketch.oy, Sketch.s
    local X, Y = ox + x * s, oy + y * s
    local W2, H2 = w * s, h * s
    local s4 = s / 4
    local verts = {
        X, Y,
        X + W2 + Sketch.jr(id, 1) * 3 * s4, Y,
        X + W2 + Sketch.jr(id, 2) * 4 * s4, Y + H2 * 0.5,
        X + W2 + Sketch.jr(id, 3) * 3 * s4, Y + H2,
        X, Y + H2,
    }
    setCol(col, alpha)
    local ok, tris = pcall(love.math.triangulate, verts)
    if ok then
        for _, t in ipairs(tris) do love.graphics.polygon("fill", t) end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Boiling hand-drawn circle outline, world coords
function Sketch.roughCircle(cx, cy, r, col, alpha, lw, id, segments)
    local ox, oy, s = Sketch.ox, Sketch.oy, Sketch.s
    local CX, CY = ox + cx * s, oy + cy * s
    local N = segments or 22
    local pts = {}
    for i = 0, N do
        local a = i / N * math.pi * 2
        local rr = r * s + Sketch.jr(id, i % N) * 1.5 * s / 4
        pts[#pts + 1] = CX + math.cos(a) * rr
        pts[#pts + 1] = CY + math.sin(a) * rr
    end
    setCol(col, alpha)
    love.graphics.setLineWidth(math.max(0.8, lw * s / 4))
    love.graphics.line(pts)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Pixel sprite (string rows, chars BWRGD), world coords centered
local SPRITE_COLOR = nil
function Sketch.sprite(rows, x, y, alpha, overrideCol)
    if not SPRITE_COLOR then
        SPRITE_COLOR = {
            B = Sketch.PAL.INK, W = hex("#f7f2e6"), R = Sketch.PAL.BLOOD,
            G = Sketch.PAL.FADE, D = Sketch.PAL.BLOOD_DARK,
        }
    end
    local s = Sketch.s
    local w, h = #rows[1], #rows
    local ox0 = math.floor(x - w / 2 + 0.5)
    local oy0 = math.floor(y - h / 2 + 0.5)
    local a = alpha == nil and 1 or alpha
    local cell = math.ceil(s)
    for r = 1, h do
        local row = rows[r]
        for c = 1, #row do
            local ch = row:sub(c, c)
            if ch ~= "." then
                local col = overrideCol or SPRITE_COLOR[ch] or Sketch.PAL.INK
                love.graphics.setColor(col[1], col[2], col[3], a)
                love.graphics.rectangle("fill",
                    math.floor(Sketch.ox + (ox0 + c - 1) * s),
                    math.floor(Sketch.oy + (oy0 + r - 1) * s), cell, cell)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

------------------------------------------------------------
-- CLICKABLES + BUTTON
------------------------------------------------------------
function Sketch.addClick(id, x, y, w, h, cb)
    table.insert(Sketch.clickables, { id = id, x = x, y = y, w = w, h = h, cb = cb })
end

function Sketch.isHover(x, y, w, h)
    return Sketch.mx >= x and Sketch.mx <= x + w and Sketch.my >= y and Sketch.my <= y + h
end

-- Process a screen-pixel click; returns true if consumed
function Sketch.click(sx, sy)
    local gx = (sx - Sketch.ox) / Sketch.s
    local gy = (sy - Sketch.oy) / Sketch.s
    for i = #Sketch.clickables, 1, -1 do
        local c = Sketch.clickables[i]
        if gx >= c.x and gx <= c.x + c.w and gy >= c.y and gy <= c.y + c.h then
            c.cb()
            return true
        end
    end
    return false
end

-- Hand-drawn button with ink-fill hover sweep
function Sketch.button(id, x, y, w, h, label, primary, cb, fontSize)
    local MPAL, PAL = Sketch.MPAL, Sketch.PAL
    local hov = Sketch.isHover(x, y, w, h)
    local key = "b_" .. id
    local t = Sketch.hoverT[key] or 0
    t = t + ((hov and 1 or 0) - t) * math.min(1, Sketch.dt * 13)
    Sketch.hoverT[key] = t
    if hov and not Sketch.lastHover[key] then Sketch.playSFX("tick") end
    Sketch.lastHover[key] = hov

    local col = primary and MPAL.RED or MPAL.PENCIL
    -- lifted shadow
    if t > 0.03 then
        love.graphics.setColor(30 / 255, 24 / 255, 18 / 255, 0.18 * t)
        local s = Sketch.s
        love.graphics.rectangle("fill", Sketch.ox + (x + 1) * s, Sketch.oy + (y + 1.5) * s, w * s, h * s)
    end
    -- ink fill sweep
    local fillW = w * Sketch.easeOutCubic(t)
    Sketch.fillRect(x, y, fillW, h, primary and PAL.BLOOD or MPAL.PENCIL,
        0.92 * math.min(1, t * 1.6), Sketch.sid(key))
    -- boiling border
    Sketch.rect(x, y, w, h, col, hov and 0.95 or (primary and 0.6 or 0.4), hov and 2.2 or 1.5, Sketch.sid(key))
    -- label (flips to paper white when ink covers it)
    local tc = t > 0.45 and MPAL.PAPER or (primary and MPAL.RED or MPAL.PENCIL)
    Sketch.text(label, x + w / 2 + t * 0.6, y + h / 2 + 0.5, fontSize or 26, tc, "center", 1, primary)
    Sketch.addClick(id, x, y, w, h, function()
        Sketch.playSFX("click")
        cb()
    end)
    return hov
end

------------------------------------------------------------
-- PAPER TEXTURES (generated once)
------------------------------------------------------------
local function makePaper(base)
    local PW, PH = 432, 768
    -- grain via ImageData
    local grain = love.image.newImageData(PW, PH)
    grain:mapPixel(function()
        local n = (math.random() - 0.5) * 13 / 255
        if n >= 0 then return 1, 1, 1, n else return 0, 0, 0, -n end
    end)
    local grainImg = love.graphics.newImage(grain)

    local canvas = love.graphics.newCanvas(PW, PH)
    canvas:setFilter("linear", "linear")
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(base[1], base[2], base[3], 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(grainImg, 0, 0)
    -- paper fibers
    love.graphics.setColor(120 / 255, 108 / 255, 90 / 255, 0.08)
    love.graphics.setLineWidth(1)
    for _ = 1, 150 do
        local x, y = math.random() * PW, math.random() * PH
        local a, l = math.random() * 6.28, 4 + math.random() * 11
        love.graphics.line(x, y, x + math.cos(a) * l, y + math.sin(a) * l)
    end
    -- aged stains (approximated radial gradients)
    for _ = 1, 6 do
        local x, y = math.random() * PW, math.random() * PH
        local r = 30 + math.random() * 80
        for i = 10, 1, -1 do
            love.graphics.setColor(150 / 255, 128 / 255, 96 / 255, 0.0065)
            love.graphics.circle("fill", x, y, r * i / 10)
        end
    end
    -- vignette (rect borders, quadratic falloff)
    for i = 0, 60 do
        local a = 0.25 * (1 - i / 60) ^ 2
        love.graphics.setColor(28 / 255, 22 / 255, 16 / 255, a)
        love.graphics.rectangle("fill", 0, i, PW, 1)
        love.graphics.rectangle("fill", 0, PH - 1 - i, PW, 1)
        love.graphics.rectangle("fill", i, 0, 1, PH)
        love.graphics.rectangle("fill", PW - 1 - i, 0, 1, PH)
    end
    love.graphics.setCanvas()
    love.graphics.pop()
    return canvas
end

local function makeInkSplat()
    local c = love.graphics.newCanvas(280, 200)
    c:setFilter("linear", "linear")
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setCanvas(c)
    love.graphics.clear(0, 0, 0, 0)
    for _ = 1, 26 do
        local a = math.random() * 6.28
        local r = math.random() * math.random() * 95
        local x = 140 + math.cos(a) * r * 1.3
        local y = 100 + math.sin(a) * r * 0.7
        local sz = (1 - r / 110) * (4 + math.random() * 12)
        love.graphics.setColor(44 / 255, 44 / 255, 44 / 255, 0.05 + math.random() * 0.06)
        love.graphics.circle("fill", x, y, math.max(0.5, sz))
    end
    for _ = 1, 14 do
        love.graphics.setColor(44 / 255, 44 / 255, 44 / 255, 0.10 + math.random() * 0.12)
        love.graphics.circle("fill", 20 + math.random() * 240, 20 + math.random() * 160, 0.8 + math.random() * 1.8)
    end
    love.graphics.setCanvas()
    love.graphics.pop()
    return c
end

local paperMenu, paperGame, inkSplat = nil, nil, nil

function Sketch.ensureTextures()
    if not paperMenu then
        paperMenu = makePaper(Sketch.MPAL.PAPER)
        paperGame = makePaper(Sketch.PAL.PAPER)
        inkSplat = makeInkSplat()
    end
end

-- Draw paper covering the frame
function Sketch.drawPaper(menuStyle, alpha)
    Sketch.ensureTextures()
    local s = Sketch.s
    love.graphics.setColor(1, 1, 1, alpha or 1)
    love.graphics.draw(menuStyle and paperMenu or paperGame, Sketch.ox, Sketch.oy, 0,
        Sketch.W * s / 432, Sketch.H * s / 768)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw ink splat centered at current origin (use inside push/translate), screen scale
function Sketch.drawInkSplat(alpha)
    Sketch.ensureTextures()
    local k = Sketch.s / 4
    love.graphics.setColor(1, 1, 1, alpha or 0.9)
    love.graphics.draw(inkSplat, -140 * k, -88 * k, 0, k, k)
    love.graphics.setColor(1, 1, 1, 1)
end

------------------------------------------------------------
-- DUST AMBIENCE
------------------------------------------------------------
local dust = nil
function Sketch.drawDust(dt)
    if not dust then
        dust = {}
        for _ = 1, 26 do
            table.insert(dust, {
                x = math.random() * Sketch.W, y = math.random() * Sketch.H,
                vy = -(1.2 + math.random() * 2), ph = math.random() * 6.28,
                a = 0.05 + math.random() * 0.08, sz = math.random() < 0.7 and 1 or 1.5,
            })
        end
    end
    for _, d in ipairs(dust) do
        d.y = d.y + d.vy * dt
        d.ph = d.ph + dt * 1.2
        if d.y < -3 then d.y = Sketch.H + 3; d.x = math.random() * Sketch.W end
        Sketch.px(d.x + math.sin(d.ph) * 3, d.y, d.sz, d.sz, Sketch.MPAL.PENCIL,
            d.a * (0.7 + math.sin(d.ph * 1.7) * 0.3))
    end
end

return Sketch
