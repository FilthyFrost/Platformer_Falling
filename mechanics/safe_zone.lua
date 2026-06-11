--[[
    Safe Zone Mechanic for Cave Fall
    An invisible rectangular area where stencil-boundary collision
    does NOT kill the player — only pushes them back (vy=0).

    Same editor interaction as Air Wall (12px block, 6px grid snap).
]]

local SafeZone = {}

local WORLD_H = 192
local ZONE_HALF_SIZE = 6  -- half of 12px block

local function screenToLogicY(y) return WORLD_H - y end

------------------------------------------------------------
-- INITIALIZATION
------------------------------------------------------------

function SafeZone.load(world, levelData)
    world.safeZones = {}
    local zones = levelData.safeZones or {}
    for _, sz in ipairs(zones) do
        table.insert(world.safeZones, {
            x = sz.x,                          -- screen-space center X
            screenY = sz.y,                    -- screen-space center Y
            logicY = screenToLogicY(sz.y),     -- logic-space center Y
        })
    end
end

------------------------------------------------------------
-- CHECK IF PLAYER IS IN A SAFE ZONE
-- Called from checkCollisions when player is outside stencil
-- Returns true if player should be protected (push back, don't die)
------------------------------------------------------------

function SafeZone.isPlayerSafe(world)
    local p = world.player
    if not world.safeZones then return false end

    local playerScreenY = WORLD_H - p.y

    for _, sz in ipairs(world.safeZones) do
        -- Check if player center is within the 12x12 zone
        if math.abs(p.x - sz.x) <= ZONE_HALF_SIZE and
           math.abs(playerScreenY - sz.screenY) <= ZONE_HALF_SIZE then
            return true
        end
    end
    return false
end

------------------------------------------------------------
-- RENDERING (in-game: invisible. Only visible in editor.)
------------------------------------------------------------

function SafeZone.draw(world)
    -- Safe zones are invisible during gameplay (by design)
end

return SafeZone
