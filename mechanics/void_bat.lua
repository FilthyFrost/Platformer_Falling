--[[
    Void Bat Mechanic for Cave Fall
    A ghostly moth that the player passes through (no collision).
    Becomes a normal bat only after ALL base bats are cleared.

    - Void state: no collision, ethereal appearance (gray/fragmented)
    - Once all base bats are dead: all void bats materialize into normal bats
    - Player must then stomp them to clear the level
    - Designed by Gemini 3.1 Pro (pixel art consistent with Carmine Requiem aesthetic)
]]

local VoidBat = {}

local WORLD_H = 192
local function screenToLogicY(y) return WORLD_H - y end

------------------------------------------------------------
-- SPRITE DATA (designed by Gemini 3.1 Pro)
-- G=faded gray, W=parchment, D=dark blood, .=transparent
-- Ethereal/fragmented silhouette, recognizable as moth
------------------------------------------------------------

VoidBat.SPRITES = {
    -- Void frame A (wings spread, 6x3)
    voidA = {
        "G.DWD.G",
        ".GWWWG.",
        "..GGG..",
    },
    -- Void frame B (wings folded, 6x4)
    voidB = {
        "..GG..",
        ".GWDG.",
        ".GWWG.",
        "G.GG.G",
    },
}

------------------------------------------------------------
-- INITIALIZATION
------------------------------------------------------------

function VoidBat.load(world, levelData)
    world.voidBats = {}
    local voidBatsData = levelData.voidBats or {}
    for _, vb in ipairs(voidBatsData) do
        table.insert(world.voidBats, {
            x = vb.x,
            y = screenToLogicY(vb.y),
            w = 6, h = 6,
            void = true,      -- true = ethereal (no collision), false = materialized
            active = true,    -- false = killed
            hoverOffset = math.random() * math.pi * 2,
        })
    end
end

------------------------------------------------------------
-- CHECK MATERIALIZATION
-- Call after a base bat is stomped to see if void bats should materialize
------------------------------------------------------------

function VoidBat.checkMaterialize(world)
    if not world.voidBats or #world.voidBats == 0 then return false end

    -- Check if ALL base bats (normal targets) are inactive
    local allBaseCleared = true
    for _, t in ipairs(world.targets) do
        if t.active then
            allBaseCleared = false
            break
        end
    end

    if not allBaseCleared then return false end

    -- Check if any void bat is still in void state
    local materialized = false
    for _, vb in ipairs(world.voidBats) do
        if vb.void and vb.active then
            vb.void = false  -- materialize!
            materialized = true
        end
    end

    return materialized
end

------------------------------------------------------------
-- CHECK IF ALL CLEARED (for win condition)
------------------------------------------------------------

function VoidBat.allCleared(world)
    if not world.voidBats then return true end
    for _, vb in ipairs(world.voidBats) do
        if vb.active then return false end
    end
    return true
end

------------------------------------------------------------
-- COLLISION CHECK (only for materialized void bats)
-- Returns true if a stomp occurred
------------------------------------------------------------

function VoidBat.checkCollision(world, PHYSICS, PAL, createSplatter, createFeather, createDecal, logicToScreenY, playSFX)
    local p = world.player
    if not world.voidBats then return false end

    for _, vb in ipairs(world.voidBats) do
        if not vb.active or vb.void then goto continue end

        if math.abs(p.x - vb.x) < 6 and
           math.abs(p.y - vb.y) < 6 then
            local isFalling = (p.vy * p.gravityDir < 0)
            if isFalling then
                p.vy = PHYSICS.BOUNCE_POWER * p.gravityDir
                vb.active = false
                playSFX("stomp")
                world.shake = 12
                world.hitstop = 10
                world.flash = 0.3
                world.flashColor = PAL.BLOOD
                for i = 1, 25 do
                    table.insert(world.particles, createSplatter(vb.x, logicToScreenY(vb.y), true))
                end
                for i = 1, 12 do
                    table.insert(world.feathers, createFeather(vb.x, logicToScreenY(vb.y)))
                end
                for i = 1, 15 do
                    table.insert(world.decals, createDecal(vb.x, logicToScreenY(vb.y), true))
                end
                return true
            end
        end
        ::continue::
    end
    return false
end

------------------------------------------------------------
-- RENDERING
------------------------------------------------------------

function VoidBat.draw(world, boilFrame, drawSprite, logicToScreenY, time)
    if not world.voidBats then return end

    for _, vb in ipairs(world.voidBats) do
        if not vb.active then goto continue end
        local sy = logicToScreenY(vb.y)
        local floatY = math.floor(math.sin(time * 0.005 + vb.hoverOffset) * 3)

        if vb.void then
            -- Void state: use ghostly sprites
            local sprite = boilFrame == 0 and VoidBat.SPRITES.voidA or VoidBat.SPRITES.voidB
            local jitterX = boilFrame == 0 and 0 or 1
            drawSprite(sprite, vb.x + jitterX, sy + floatY, false)
        else
            -- Materialized: use normal moth sprites (from SPRITE_DATA in main.lua)
            -- This is handled by passing the sprites from main
            local sprite = boilFrame == 0 and VoidBat.SPRITES.materializedA or VoidBat.SPRITES.materializedB
            if sprite then
                local jitterX = boilFrame == 0 and 0 or 1
                drawSprite(sprite, vb.x + jitterX, sy + floatY, false)
            end
        end
        ::continue::
    end
end

-- Set materialized sprites (called from main.lua to pass SPRITE_DATA.mothA/B)
function VoidBat.setMaterializedSprites(mothA, mothB)
    VoidBat.SPRITES.materializedA = mothA
    VoidBat.SPRITES.materializedB = mothB
end

return VoidBat
