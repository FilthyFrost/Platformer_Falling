--[[
    TransformFX — bat transformation animations (subtle, local-only)
    - Armor break: shatter fragments + white blink + small blood ring (around bat only)
    - Void materialize: converging particles + ghost->moth crossfade (around bat only)
    No screen-wide flashes / dims / text cues — keeps tense gameplay readable.
    Bats are invincible / non-interactive while transforming (bat.transforming flag).

    World-space drawing happens inside the scaled 108x192 transform (screen Y-down).
]]

local TransformFX = {}

TransformFX.list = {}

local deps = {}  -- { PAL, WORLD_W, logicToScreenY, playSFX, Sketch, mothA, mothB, voidA, voidB }

function TransformFX.init(d)
    deps = d
end

function TransformFX.reset()
    TransformFX.list = {}
end

local function batScreenY(bat)
    return deps.logicToScreenY(bat.y)
end

------------------------------------------------------------
-- TRIGGERS
------------------------------------------------------------
-- First armor hit: armor visually breaks, bat blinks white, frags fly
function TransformFX.startArmorBreak(world, ab)
    local PAL = deps.PAL
    ab.transforming = true
    ab.armored = false
    ab.flashTimer = 0
    local fy = batScreenY(ab)
    local frags = {}
    for _ = 1, 12 do
        local a = math.random() * 6.28
        local sp = 28 + math.random() * 40
        table.insert(frags, {
            x = ab.x, y = fy,
            vx = math.cos(a) * sp, vy = math.sin(a) * sp - 22,
            rot = math.random() * 6.28,
            c = math.random() < 0.7 and PAL.FADE or PAL.INK,
            sz = math.random() < 0.5 and 1 or 1.8,
        })
    end
    table.insert(TransformFX.list, { kind = "armor", bat = ab, t = 0, dur = 0.28, frags = frags })
    world.hitstop = 3
    world.shake = math.max(world.shake, 4)
    deps.playSFX("shatter")
end

-- All base bats cleared: void bats materialize with a quick stagger
function TransformFX.startVoidMaterialize(world, bats)
    local PAL = deps.PAL
    deps.playSFX("mater")
    for i, vb in ipairs(bats) do
        vb.transforming = true
        local conv = {}
        for _ = 1, 14 do
            table.insert(conv, {
                a = math.random() * 6.28,
                r = 12 + math.random() * 8,
                c = math.random() < 0.6 and PAL.FADE or PAL.BLOOD_DARK,
            })
        end
        table.insert(TransformFX.list, { kind = "void", bat = vb, t = -(i - 1) * 0.05, dur = 0.3, conv = conv })
    end
end

------------------------------------------------------------
-- UPDATE
------------------------------------------------------------
function TransformFX.update(world, dt)
    for i = #TransformFX.list, 1, -1 do
        local fx = TransformFX.list[i]
        fx.t = fx.t + dt
        if fx.kind == "armor" then
            for _, f in ipairs(fx.frags) do
                f.x = f.x + f.vx * dt
                f.y = f.y + f.vy * dt
                f.vy = f.vy + 170 * dt
                f.rot = f.rot + dt * 9
            end
        end
        if fx.t >= fx.dur then
            fx.bat.transforming = false
            if fx.kind == "void" then
                fx.bat.void = false
            end
            table.remove(TransformFX.list, i)
        end
    end
end

function TransformFX.isTransforming(bat)
    return bat.transforming == true
end

------------------------------------------------------------
-- WORLD-SPACE DRAWING (inside scaled 108x192 transform)
------------------------------------------------------------
-- Sprite drawing with alpha + optional override color (for blink/crossfade)
local function drawSpriteA(spriteArray, sx, sy, alpha, overrideCol)
    local PAL = deps.PAL
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
                if overrideCol then color = overrideCol end
                love.graphics.setColor(color[1], color[2], color[3], alpha or 1)
                love.graphics.rectangle("fill", sx + (j - 1) - w / 2, sy + (i - 1) - h / 2, 1.1, 1.1)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw all transforming bats + their particles (after the bat modules)
function TransformFX.drawBats(world)
    local PAL = deps.PAL
    local boil = world.boilFrame
    for _, fx in ipairs(TransformFX.list) do
        local b = fx.bat
        local fy = batScreenY(b) + math.floor(math.sin(world.time * 0.005 + (b.hoverOffset or 0)) * 3)
        local jitterX = boil == 0 and 0 or 1

        if fx.kind == "void" then
            if fx.t > 0 then
                local pr = math.min(1, fx.t / fx.dur)
                -- converging particles (rotating inward spiral)
                for _, c in ipairs(fx.conv) do
                    local rr = c.r * (1 - pr)
                    love.graphics.setColor(c.c[1], c.c[2], c.c[3], 0.4 + pr * 0.5)
                    love.graphics.rectangle("fill",
                        b.x + math.cos(c.a + pr * 2.2) * rr,
                        fy + math.sin(c.a + pr * 2.2) * rr, 1, 1)
                end
                love.graphics.setColor(1, 1, 1, 1)
                -- ghost sprite solidifying
                local voidSpr = boil == 0 and deps.voidA or deps.voidB
                drawSpriteA(voidSpr, b.x, fy, 0.35 + pr * 0.5)
                -- moth crossfade in
                if pr > 0.8 then
                    local mothSpr = boil == 0 and deps.mothA or deps.mothB
                    drawSpriteA(mothSpr, b.x, fy, (pr - 0.8) / 0.2)
                end
                -- white flash ring
                if pr > 0.72 then
                    love.graphics.setColor(1, 1, 1, math.min(1, (1 - pr) * 2.6))
                    love.graphics.setLineWidth(0.6)
                    love.graphics.circle("line", b.x, fy, (pr - 0.7) * 14)
                    love.graphics.setColor(1, 1, 1, 1)
                end
            else
                -- stagger wait: still a plain ghost
                local voidSpr = boil == 0 and deps.voidA or deps.voidB
                drawSpriteA(voidSpr, b.x + jitterX, fy, 1)
            end
        elseif fx.kind == "armor" then
            -- blinking moth (white strobing)
            local blink = math.floor(fx.t * 22) % 2 == 0
            local mothSpr = boil == 0 and deps.mothA or deps.mothB
            drawSpriteA(mothSpr, b.x, fy, 1, blink and { 1, 1, 1 } or nil)
            -- shatter fragments
            for _, f in ipairs(fx.frags) do
                love.graphics.push()
                love.graphics.translate(f.x, f.y)
                love.graphics.rotate(f.rot)
                love.graphics.setColor(f.c[1], f.c[2], f.c[3], math.max(0, 1 - fx.t / fx.dur))
                love.graphics.rectangle("fill", -f.sz / 2, -f.sz / 2, f.sz, f.sz)
                love.graphics.pop()
            end
            love.graphics.setColor(1, 1, 1, 1)
            -- expanding blood ring
            local pr = fx.t / fx.dur
            love.graphics.setColor(PAL.BLOOD[1], PAL.BLOOD[2], PAL.BLOOD[3], math.max(0, 0.85 - pr))
            love.graphics.setLineWidth(0.6)
            love.graphics.circle("line", b.x, fy, pr * 15)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end

return TransformFX
