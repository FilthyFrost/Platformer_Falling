--[[
    Jump Bat Mechanic for Cave Fall
    A bat that gives 3x bounce power when stomped.
    Behaves like a normal bat (dies on stomp, counts for win condition)
    but provides a much stronger bounce.

    Designed by Gemini 3.1 Pro (pixel art consistent with Carmine Requiem aesthetic)
]]

local JumpBat = {}

local WORLD_H = 192
local BOUNCE_MULTIPLIER = 2

local function screenToLogicY(y) return WORLD_H - y end

------------------------------------------------------------
-- SPRITE DATA (designed by Gemini 3.1 Pro)
-- Red-heavy design conveys explosive spring energy
------------------------------------------------------------

JumpBat.SPRITES = {
    -- Jump bat frame A (7x4)
    jumpA = {
        "R.BDB.R",
        ".BRRRB.",
        ".BWRWB.",
        "..BBB..",
    },
    -- Jump bat frame B (7x3)
    jumpB = {
        "..BDB..",
        "BRRRRRB",
        ".BWRWB.",
    },
}

------------------------------------------------------------
-- INITIALIZATION
------------------------------------------------------------

function JumpBat.load(world, levelData)
    world.jumpBats = {}
    local jumpBatsData = levelData.jumpBats or {}
    for _, jb in ipairs(jumpBatsData) do
        table.insert(world.jumpBats, {
            x = jb.x,
            y = screenToLogicY(jb.y),
            active = true,
            hoverOffset = math.random() * math.pi * 2,
            -- Movement (same system as base bats)
            moveDir = jb.moveDir or "NONE",
            moveDist = jb.moveDist or 24,
            moveSpeed = jb.moveSpeed or 0.6,
            moveStartDir = jb.moveStartDir or 1,
            moveOffset = 0,
            movePhase = jb.moveStartDir or 1,
            baseX = jb.x,
            baseY = screenToLogicY(jb.y),
        })
    end
end

------------------------------------------------------------
-- COLLISION CHECK
------------------------------------------------------------

function JumpBat.checkCollision(world, PHYSICS, PAL, createSplatter, createFeather, createDecal, logicToScreenY, playSFX)
    local p = world.player
    if not world.jumpBats then return false end

    for _, jb in ipairs(world.jumpBats) do
        if not jb.active then goto continue end

        if math.abs(p.x - jb.x) < (PHYSICS.PLAYER_W/2 + PHYSICS.MOTH_W/2) and
           math.abs(p.y - jb.y) < (PHYSICS.PLAYER_H/2 + PHYSICS.MOTH_H/2) then
            local isFalling = (p.vy * p.gravityDir < 0)
            if isFalling then
                -- 3x bounce power!
                p.vy = PHYSICS.BOUNCE_POWER * BOUNCE_MULTIPLIER * p.gravityDir
                jb.active = false
                playSFX("stomp")
                world.shake = 16
                world.hitstop = 12
                world.flash = 0.4
                world.flashColor = PAL.BLOOD
                for i = 1, 30 do
                    table.insert(world.particles, createSplatter(jb.x, logicToScreenY(jb.y), true))
                end
                for i = 1, 15 do
                    table.insert(world.feathers, createFeather(jb.x, logicToScreenY(jb.y)))
                end
                for i = 1, 20 do
                    table.insert(world.decals, createDecal(jb.x, logicToScreenY(jb.y), true))
                end
                return true
            end
        end
        ::continue::
    end
    return false
end

------------------------------------------------------------
-- CHECK IF ALL CLEARED (for win condition)
------------------------------------------------------------

function JumpBat.allCleared(world)
    if not world.jumpBats then return true end
    for _, jb in ipairs(world.jumpBats) do
        if jb.active then return false end
    end
    return true
end

------------------------------------------------------------
-- RENDERING
------------------------------------------------------------

function JumpBat.draw(world, boilFrame, drawSprite, logicToScreenY, time)
    if not world.jumpBats then return end

    for _, jb in ipairs(world.jumpBats) do
        if not jb.active then goto continue end
        local sy = logicToScreenY(jb.y)
        local floatY = math.floor(math.sin(time * 0.007 + jb.hoverOffset) * 2)
        local sprite = boilFrame == 0 and JumpBat.SPRITES.jumpA or JumpBat.SPRITES.jumpB
        local jitterX = boilFrame == 0 and 0 or 1
        drawSprite(sprite, jb.x + jitterX, sy + floatY, false)
        ::continue::
    end
end

return JumpBat
