--[[
    Spawn Platform for Cave Fall
    A visible, physical platform where the player starts each level.

    - Only one per level
    - Player stands on it in READY state (with gravity settling)
    - Walk left/right bounded by platform edges
    - No collision during PLAYING state (player passes through)
    - Visual: dark ledge with lighter top edge (placeholder, art pass via Gemini later)
]]

local SpawnPlatform = {}

local WORLD_H = 192
local PLATFORM_THICKNESS = 4  -- visual height of the platform

local function screenToLogicY(y) return WORLD_H - y end

------------------------------------------------------------
-- INITIALIZATION
------------------------------------------------------------

function SpawnPlatform.load(world, levelData)
    local ld = levelData
    if ld.spawnPlatform then
        -- New format: use directly
        world.spawnPlatform = {
            x = ld.spawnPlatform.x,
            y = ld.spawnPlatform.y,  -- screen-space Y (top surface)
            width = ld.spawnPlatform.width,
        }
    else
        -- Backward compat: derive from old fields
        local pxMin = ld.platformXMin or 42
        local pxMax = ld.platformXMax or 66
        local py = ld.playerStart and ld.playerStart.y or 60
        world.spawnPlatform = {
            x = pxMin,
            y = py + 4,  -- platform surface slightly below player start
            width = pxMax - pxMin,
        }
    end
end

------------------------------------------------------------
-- PLAYER START POSITION (derived from platform)
------------------------------------------------------------

-- Returns screen-space {x, y} for player spawn (directly on platform surface)
function SpawnPlatform.getPlayerStart(platform)
    return {
        x = platform.x + math.floor(platform.width / 2),
        y = platform.y - 4,  -- player center 4px above surface (half player height)
    }
end

------------------------------------------------------------
-- GROUND COLLISION (READY state only)
------------------------------------------------------------

-- Check if player should be grounded on the platform
-- Returns true if player is on the platform, false otherwise
function SpawnPlatform.checkGround(world)
    local p = world.player
    local plat = world.spawnPlatform
    if not plat then return false end

    -- Player bottom edge (in screen space)
    local playerBottomScreen = WORLD_H - p.y + math.floor(p.h / 2)

    -- Check if player is horizontally within platform bounds
    if p.x < plat.x or p.x > plat.x + plat.width then
        return false
    end

    -- Check if player bottom has reached or passed platform surface
    if playerBottomScreen >= plat.y then
        return true
    end

    return false
end

-- Snap player to platform surface (call when grounding)
function SpawnPlatform.snapToSurface(world)
    local p = world.player
    local plat = world.spawnPlatform
    if not plat then return end

    -- Set player Y so bottom edge aligns with platform top
    -- In logic space: player.y = screenToLogicY(platformY) + halfHeight
    local surfaceLogicY = screenToLogicY(plat.y)
    p.y = surfaceLogicY + math.floor(p.h / 2)
    p.vy = 0
end

-- Clamp player horizontal position to platform bounds
function SpawnPlatform.clampX(world)
    local p = world.player
    local plat = world.spawnPlatform
    if not plat then return end

    if p.x < plat.x then
        p.x = plat.x
        p.vx = 0
    elseif p.x > plat.x + plat.width then
        p.x = plat.x + plat.width
        p.vx = 0
    end
end

------------------------------------------------------------
-- RENDERING (placeholder - art pass via Gemini later)
------------------------------------------------------------

function SpawnPlatform.draw(world)
    local plat = world.spawnPlatform
    if not plat then return end

    -- Platform body (dark ink)
    love.graphics.setColor(0.07, 0.07, 0.07, 0.9)
    love.graphics.rectangle("fill", plat.x, plat.y, plat.width, PLATFORM_THICKNESS)

    -- Top edge highlight (slightly lighter, 1px)
    love.graphics.setColor(0.25, 0.25, 0.23, 0.8)
    love.graphics.rectangle("fill", plat.x, plat.y, plat.width, 1)

    -- Side edges (thin vertical lines)
    love.graphics.setColor(0.07, 0.07, 0.07, 0.7)
    love.graphics.rectangle("fill", plat.x - 1, plat.y, 1, PLATFORM_THICKNESS)
    love.graphics.rectangle("fill", plat.x + plat.width, plat.y, 1, PLATFORM_THICKNESS)
end

return SpawnPlatform
