--[[
    Mirror Line Mechanic for Cave Fall
    A horizontal gravity-inversion line that creates simple harmonic oscillation.
    Reference: "Sulka" by Kultisti (https://kultisti.itch.io/sulka)

    Behavior:
    - Player crosses the line → gravity inverts, velocity preserved
    - Player sprite flips upside-down
    - Creates natural sine-wave oscillation (fast at line, slow at extremes)
    - Player exits by moving horizontally past line endpoints
    - After exit: current gravity state persists
]]

local MirrorLine = {}

local WORLD_H = 192

local function screenToLogicY(y) return WORLD_H - y end

------------------------------------------------------------
-- INITIALIZATION
------------------------------------------------------------

function MirrorLine.load(world, levelData)
    world.mirrorLines = {}
    local lines = levelData.mirrorLines or {}
    for _, ml in ipairs(lines) do
        table.insert(world.mirrorLines, {
            x = ml.x,
            y = ml.y,                         -- screen-space Y
            logicY = screenToLogicY(ml.y),    -- logic-space Y for physics
            length = ml.length,
            -- Visual state
            pulseTimer = 0,
            pulseIntensity = 0,
        })
    end
end

------------------------------------------------------------
-- CROSSING DETECTION
------------------------------------------------------------

function MirrorLine.checkCrossing(world)
    local p = world.player
    if not p or p.grounded then return false end

    -- Previous position (before this frame's velocity was applied)
    local prevY = p.y - p.vy
    local crossed = false

    for _, ml in ipairs(world.mirrorLines) do
        local lineLogicY = ml.logicY

        -- Check horizontal bounds: player center X must be within line
        if p.x >= ml.x and p.x <= ml.x + ml.length then
            -- Determine which side of the line the player is on
            -- Use >= to prevent double-trigger at exact boundary
            local prevSide = (prevY >= lineLogicY) and 1 or -1
            local currSide = (p.y >= lineLogicY) and 1 or -1

            if prevSide ~= currSide then
                -- CROSSING: invert gravity, preserve velocity
                p.gravityDir = -p.gravityDir
                crossed = true
                -- Trigger pulse VFX
                ml.pulseTimer = 1.0
                ml.pulseIntensity = math.min(1.0, math.abs(p.vy) / 2.0)
            end
        end
    end

    return crossed
end

------------------------------------------------------------
-- UPDATE (visual animations)
------------------------------------------------------------

function MirrorLine.update(world, dt)
    if not world.mirrorLines then return end
    for _, ml in ipairs(world.mirrorLines) do
        if ml.pulseTimer > 0 then
            ml.pulseTimer = ml.pulseTimer - dt * 3
            if ml.pulseTimer < 0 then ml.pulseTimer = 0 end
        end
    end
end

------------------------------------------------------------
-- RENDERING (placeholder - art pass will be done via Gemini)
------------------------------------------------------------

function MirrorLine.draw(world)
    if not world.mirrorLines then return end

    for _, ml in ipairs(world.mirrorLines) do
        local gridSize = 4
        local baseAlpha = 0.7
        local pulse = ml.pulseTimer * ml.pulseIntensity

        -- Base color: green squares
        local r, g, b = 0.55, 0.85, 0.35
        local alpha = baseAlpha + pulse * 0.3

        -- Draw green squares in a row
        love.graphics.setColor(r, g, b, alpha)
        for px = ml.x, ml.x + ml.length - gridSize, gridSize do
            love.graphics.rectangle("fill", px + 0.5, ml.y - 1, gridSize - 1, 3)
        end

        -- Pulse glow effect on crossing
        if ml.pulseTimer > 0 then
            love.graphics.setColor(r, g, b, pulse * 0.4)
            love.graphics.rectangle("fill", ml.x, ml.y - 3, ml.length, 7)
        end
    end
end

return MirrorLine
