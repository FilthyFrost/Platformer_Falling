--[[
    Armor Bat Mechanic for Cave Fall
    A tougher bat that requires 2 stomps to kill.
    First stomp breaks the armor (sprite changes to base moth).
    Second stomp kills it normally.

    Counts as a "base bat" for void bat unlock condition.
    Designed by Gemini 3.1 Pro.
]]

local ArmorBat = {}

local TransformFX = require("mechanics.transform_fx")

local WORLD_H = 192

local function screenToLogicY(y) return WORLD_H - y end

------------------------------------------------------------
-- SPRITE DATA (designed by Gemini 3.1 Pro)
-- Heavy shell of ink black (B) + hardened blood plates (D)
------------------------------------------------------------

ArmorBat.SPRITES = {
    -- Armored frame A (7x3, iron gray shell)
    armorA = {
        "BG.R.GB",
        ".BGGGB.",
        "..BBB..",
    },
    -- Armored frame B (7x4, iron gray shell, wings tucked)
    armorB = {
        "..BGB..",
        ".BGRGB.",
        ".BGGGB.",
        "B.BBB.B",
    },
}

------------------------------------------------------------
-- INITIALIZATION
------------------------------------------------------------

function ArmorBat.load(world, levelData)
    world.armorBats = {}
    local armorBatsData = levelData.armorBats or {}
    for _, ab in ipairs(armorBatsData) do
        table.insert(world.armorBats, {
            x = ab.x,
            y = screenToLogicY(ab.y),
            hp = 2,          -- 2 hits to kill
            active = true,
            armored = true,  -- true = armored sprite, false = base moth sprite
            hoverOffset = math.random() * math.pi * 2,
            flashTimer = 0,  -- visual feedback on first hit
            -- Movement
            moveDir = ab.moveDir or "NONE",
            moveDist = ab.moveDist or 24,
            moveSpeed = ab.moveSpeed or 0.6,
            moveStartDir = ab.moveStartDir or 1,
            moveOffset = 0,
            movePhase = ab.moveStartDir or 1,
            baseX = ab.x,
            baseY = screenToLogicY(ab.y),
        })
    end
end

------------------------------------------------------------
-- COLLISION CHECK
------------------------------------------------------------

function ArmorBat.checkCollision(world, PHYSICS, PAL, createSplatter, createFeather, createDecal, logicToScreenY, playSFX)
    local p = world.player
    if not world.armorBats then return false end

    for _, ab in ipairs(world.armorBats) do
        if not ab.active or ab.transforming then goto continue end

        if math.abs(p.x - ab.x) < (PHYSICS.PLAYER_W/2 + PHYSICS.MOTH_W/2) and
           math.abs(p.y - ab.y) < (PHYSICS.PLAYER_H/2 + PHYSICS.MOTH_H/2) then
            local isFalling = (p.vy * p.gravityDir < 0)
            if isFalling then
                -- Normal bounce
                p.vy = PHYSICS.BOUNCE_POWER * p.gravityDir

                ab.hp = ab.hp - 1
                if ab.hp <= 0 then
                    -- Dead: full kill effects
                    ab.active = false
                    playSFX("stomp")
                    world.shake = 12
                    world.hitstop = 10
                    world.flash = 0.3
                    world.flashColor = PAL.BLOOD
                    for i = 1, 25 do
                        table.insert(world.particles, createSplatter(ab.x, logicToScreenY(ab.y), true))
                    end
                    for i = 1, 12 do
                        table.insert(world.feathers, createFeather(ab.x, logicToScreenY(ab.y)))
                    end
                    for i = 1, 15 do
                        table.insert(world.decals, createDecal(ab.x, logicToScreenY(ab.y), true))
                    end
                else
                    -- Armor broken: TransformFX shatter animation
                    -- (sets armored=false + transforming=true, frags, ring, cue, hitstop)
                    TransformFX.startArmorBreak(world, ab)
                end
                return true
            end
        end
        ::continue::
    end
    return false
end

------------------------------------------------------------
-- CHECK IF ALL CLEARED (for win/void-bat condition)
-- Armor bats count as "base bats" — must be killed for void unlock
------------------------------------------------------------

function ArmorBat.allCleared(world)
    if not world.armorBats then return true end
    for _, ab in ipairs(world.armorBats) do
        if ab.active then return false end
    end
    return true
end

------------------------------------------------------------
-- UPDATE (flash timer)
------------------------------------------------------------

function ArmorBat.update(world, dt)
    if not world.armorBats then return end
    for _, ab in ipairs(world.armorBats) do
        if ab.flashTimer > 0 then
            ab.flashTimer = ab.flashTimer - dt
        end
    end
end

------------------------------------------------------------
-- RENDERING
------------------------------------------------------------

function ArmorBat.draw(world, boilFrame, drawSprite, logicToScreenY, time, mothA, mothB)
    if not world.armorBats then return end

    for _, ab in ipairs(world.armorBats) do
        if not ab.active or ab.transforming then goto continue end
        local sy = logicToScreenY(ab.y)
        local floatY = math.floor(math.sin(time * 0.005 + ab.hoverOffset) * 3)
        local jitterX = boilFrame == 0 and 0 or 1

        -- Flash white briefly after armor break
        if ab.flashTimer > 0 and math.floor(ab.flashTimer * 20) % 2 == 0 then
            goto continue  -- blink off
        end

        if ab.armored then
            -- Armored sprite
            local sprite = boilFrame == 0 and ArmorBat.SPRITES.armorA or ArmorBat.SPRITES.armorB
            drawSprite(sprite, ab.x + jitterX, sy + floatY, false)
        else
            -- Broken armor: show base moth sprite
            local sprite = boilFrame == 0 and mothA or mothB
            drawSprite(sprite, ab.x + jitterX, sy + floatY, false)
        end
        ::continue::
    end
end

return ArmorBat
