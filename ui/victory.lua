--[[
    Victory — full-clear screen
    count-up time settle + NEW RECORD stamp slam + falling feathers + blood drips
    Speedrun time only for fullRun (level 1 -> 36 continuous session)
    Transcribed from prototypes/ui_prototype.html (approved design)
]]

local Victory = {}

local S
local deps = {}  -- { Sketch, SaveData, RunTimer, playSFX, onBack(), setShake(mag) }

Victory.t = 0
Victory.showTime = false
Victory.finalTime = 0
Victory.newRecord = false
Victory.stamped = false
Victory.feathers = {}
Victory.drips = {}

function Victory.init(d)
    deps = d
    S = d.Sketch
end

function Victory.enter()
    local RunTimer = deps.RunTimer
    Victory.t = 0
    Victory.stamped = false
    Victory.showTime = RunTimer.fullRun
    Victory.finalTime = RunTimer.time
    RunTimer.stop()
    Victory.newRecord = Victory.showTime and deps.SaveData.submitTime(Victory.finalTime) or false
    Victory.feathers = {}
    for _ = 1, 18 do
        table.insert(Victory.feathers, {
            x = math.random() * S.W, y = math.random() * S.H - S.H,
            vy = 3 + math.random() * 7, ph = math.random() * 6.28,
            amp = 3 + math.random() * 7, r = math.random() * 6.28,
            depth = math.random() < 0.5 and 0.4 or 1,
        })
    end
    Victory.drips = {}
    for _ = 1, 4 do
        table.insert(Victory.drips, {
            x = 14 + math.random() * (S.W - 28), len = 0,
            max = 14 + math.random() * 26, sp = 2.5 + math.random() * 4,
        })
    end
    deps.playSFX("win")
end

local function update(dt)
    Victory.t = Victory.t + dt
    for _, f in ipairs(Victory.feathers) do
        f.y = f.y + f.vy * f.depth * dt
        f.ph = f.ph + dt * 2
        f.r = f.r + dt * 0.8
        if f.y > S.H + 10 then
            f.y = -10
            f.x = math.random() * S.W
        end
    end
    for _, d in ipairs(Victory.drips) do
        if d.len < d.max then d.len = d.len + d.sp * dt end
    end
end

local function drawFeather(f, alpha)
    local fx2 = f.x + math.sin(f.ph) * f.amp
    love.graphics.push()
    love.graphics.translate(S.ox + fx2 * S.s, S.oy + f.y * S.s)
    love.graphics.rotate(math.sin(f.r) * 0.8)
    love.graphics.setColor(S.PAL.INK[1], S.PAL.INK[2], S.PAL.INK[3], alpha)
    love.graphics.rectangle("fill", -1.3 * S.s, -0.5 * S.s, 2.6 * S.s, S.s)
    love.graphics.rectangle("fill", -0.4 * S.s, -1 * S.s, 0.8 * S.s, 2 * S.s)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

function Victory.draw(dt)
    update(dt)
    local t = Victory.t
    local W, H = S.W, S.H
    local MPAL, PAL = S.MPAL, S.PAL
    local RunTimer = deps.RunTimer

    S.drawPaper(true)
    S.drawDust(dt)

    -- background feathers
    for _, f in ipairs(Victory.feathers) do
        if f.depth < 1 then drawFeather(f, 0.18) end
    end
    -- blood drips from top
    for _, d in ipairs(Victory.drips) do
        love.graphics.setColor(PAL.BLOOD[1], PAL.BLOOD[2], PAL.BLOOD[3], 0.4)
        love.graphics.setLineWidth(2.2 * S.s / 4)
        love.graphics.line(S.ox + d.x * S.s, S.oy, S.ox + d.x * S.s, S.oy + d.len * S.s)
        love.graphics.setColor(1, 1, 1, 1)
        S.blob(d.x, d.len, 1.6, PAL.BLOOD, 0.5, 600 + math.floor(d.x))
    end

    -- title: 恭喜通关 (fade-in + blood underline sweep)
    local a1 = math.min(1, t / 0.8)
    love.graphics.push()
    local tX = S.ox + W / 2 * S.s
    local tY = S.oy + (H * 0.24 + math.sin(S.time) * 1.5) * S.s
    love.graphics.translate(tX, tY)
    love.graphics.rotate(math.rad(-2))
    S.drawInkSplat(a1 * 0.85)
    love.graphics.translate(-tX, -tY)
    local cy = (tY - S.oy) / S.s
    S.text("恭喜通关", W / 2 + 1, cy + 1.25, 62, { 44 / 255, 44 / 255, 44 / 255 }, "center", a1 * 0.18, true)
    S.text("恭喜通关", W / 2 + 0.5, cy + 0.5, 62, MPAL.PENCIL_L, "center", a1, true)
    S.text("恭喜通关", W / 2, cy, 62, MPAL.PENCIL, "center", a1, true)
    if t > 0.5 then
        local lw2 = S.easeOutCubic((t - 0.5) / 0.5)
        S.line(W / 2 - 10 * lw2, cy + 3.5, W / 2 + 10 * lw2, cy + 3.75, PAL.BLOOD, 0.85, 3, 610)
    end
    love.graphics.pop()

    local a2 = S.clamp01((t - 1.0) / 0.6)
    S.text("—— 三十六层洞穴 · 尽抵深渊 ——", W / 2, H * 0.385, 16, MPAL.PENCIL_L, "center", a2 * 0.8)

    if Victory.showTime then
        local a3 = S.clamp01((t - 1.3) / 0.5)
        S.text("通关用时", W / 2, H * 0.475, 21, MPAL.PENCIL, "center", a3)
        -- count-up settle
        local cntP = S.easeOutCubic(S.clamp01((t - 1.5) / 1.3))
        local shown = Victory.finalTime * cntP
        S.text(RunTimer.fmt(shown), W / 2, H * 0.545, 46, PAL.BLOOD, "center", a3, true, true)
        if cntP >= 1 and Victory.newRecord then
            -- NEW RECORD stamp slam
            local st = S.clamp01((t - 2.9) / 0.16)
            if st > 0 and not Victory.stamped then
                Victory.stamped = true
                if deps.setShake then deps.setShake(7) end
                deps.playSFX("stamp")
            end
            if st > 0 then
                local sc = 1 + (1 - S.easeOutCubic(st)) * 2.2
                love.graphics.push()
                love.graphics.translate(S.ox + (W / 2 + 33) * S.s, S.oy + H * 0.50 * S.s)
                love.graphics.rotate(math.rad(14))
                love.graphics.scale(sc, sc)
                love.graphics.translate(-(S.ox + (W / 2 + 33) * S.s), -(S.oy + H * 0.50 * S.s))
                local scx, scy = W / 2 + 33, H * 0.50
                S.blob(scx, scy, 11.5, PAL.BLOOD, 0.14 * st, 611)
                S.roughCircle(scx, scy, 11, MPAL.RED, st, 2.2, 612, 24)
                S.text("新纪录", scx, scy - 1, 22, MPAL.RED, "center", st, true)
                S.text("NEW", scx, scy + 2, 22, MPAL.RED, "center", st, true)
                love.graphics.pop()
            end
        elseif cntP >= 1 and deps.SaveData.data.bestTime and not Victory.newRecord then
            S.text("最佳纪录  " .. RunTimer.fmt(deps.SaveData.data.bestTime), W / 2, H * 0.615, 15,
                MPAL.PENCIL_L, "center", 0.85, false, true)
        end
    else
        local a3 = S.clamp01((t - 1.3) / 0.5)
        S.text("从第 1 关一口气通关", W / 2, H * 0.50, 16, MPAL.PENCIL_L, "center", a3 * 0.75)
        S.text("即可记录速通时间", W / 2, H * 0.55, 16, MPAL.PENCIL_L, "center", a3 * 0.75)
    end

    -- foreground feathers
    for _, f in ipairs(Victory.feathers) do
        if f.depth >= 1 then drawFeather(f, 0.4) end
    end

    if t > 2.0 then
        S.button("v_menu", W / 2 - 36, H * 0.78, 72, 17, "返回主菜单", true, function()
            deps.onBack()
        end, 26)
    end
end

return Victory
