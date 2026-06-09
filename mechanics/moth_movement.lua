--[[
    Moth Movement Module for Cave Fall
    Handles periodic movement (horizontal or vertical) for all moth types.
    Each moth can have: direction (none/horizontal/vertical), distance, speed.
    Movement is ping-pong: center ± distance/2.
]]

local MothMovement = {}

-- Speed presets (pixels per frame)
MothMovement.SPEEDS = {
    SLOW = 0.3,
    MED = 0.6,
    FAST = 1.0,
}

-- Movement directions
MothMovement.DIR = {
    NONE = "NONE",
    HORIZONTAL = "HORIZONTAL",
    VERTICAL = "VERTICAL",
}

------------------------------------------------------------
-- APPLY MOVEMENT (called every frame in PLAYING state)
------------------------------------------------------------

-- Update all moths' positions based on their movement config
-- targets = world.targets (regular moths) or world.voidBats
-- Each target with movement has: moveDir, moveDist, moveSpeed, movePhase, baseX, baseY
function MothMovement.update(targets)
    if not targets then return end
    for _, t in ipairs(targets) do
        if not t.active then goto continue end
        if not t.moveDir or t.moveDir == "NONE" then goto continue end

        -- Advance phase (0 to 1 to 0, ping-pong)
        t.movePhase = t.movePhase + t.moveSpeed / (t.moveDist or 24)
        if t.movePhase > 1 then
            t.movePhase = t.movePhase - 2 * (t.movePhase - 1)
            t.moveSpeed = -t.moveSpeed  -- reverse direction
        elseif t.movePhase < 0 then
            t.movePhase = -t.movePhase
            t.moveSpeed = -t.moveSpeed  -- reverse direction
        end

        -- Apply offset from base position
        local offset = (t.movePhase - 0.5) * t.moveDist  -- -dist/2 to +dist/2
        if t.moveDir == "HORIZONTAL" then
            t.x = t.baseX + offset
        elseif t.moveDir == "VERTICAL" then
            -- In logic Y space (Y-up), vertical offset is added to Y
            t.y = t.baseY + offset
        end

        ::continue::
    end
end

------------------------------------------------------------
-- INITIALIZE MOVEMENT ON TARGETS (at level load time)
------------------------------------------------------------

-- Apply movement config from level data to spawned targets
-- batConfigs = list of {x, y, moveDir, moveDist, moveSpeed} from level data
-- targets = spawned game entities (already have x, y in logic space)
function MothMovement.applyConfig(targets, batConfigs)
    if not targets or not batConfigs then return end
    for i, t in ipairs(targets) do
        local config = batConfigs[i]
        if config and config.moveDir and config.moveDir ~= "NONE" then
            t.moveDir = config.moveDir
            t.moveDist = config.moveDist or 24
            t.moveSpeed = math.abs(config.moveSpeed or 0.6)
            t.movePhase = 0.5  -- start at center
            t.baseX = t.x
            t.baseY = t.y
        else
            t.moveDir = "NONE"
        end
    end
end

return MothMovement
