--[[
    PauseUI — in-game pause button / HUD / pause overlay
    + shared settings panel (menu & pause) + reset-confirm dialog
    Transcribed from prototypes/ui_prototype.html (approved design)
]]

local PauseUI = {}

local S          -- Sketch
local deps = {}  -- { Sketch, SaveData, RunTimer, playSFX, onReturnToMenu, applyVolume, previewShake, sprites }

PauseUI.open = false
PauseUI.settingsOpen = false      -- settings inside pause overlay
PauseUI.slide = 0
PauseUI.menuSettingsOpen = false  -- settings inside main menu
PauseUI.resetConfirm = false
PauseUI.dragVol = false

local BAR_X, BAR_W = 20, 60

function PauseUI.init(d)
    deps = d
    S = d.Sketch
end

function PauseUI.toggle()
    PauseUI.open = not PauseUI.open
    deps.playSFX(PauseUI.open and "page" or "click")
    if not PauseUI.open then PauseUI.settingsOpen = false end
end

function PauseUI.close()
    PauseUI.open = false
    PauseUI.settingsOpen = false
end

function PauseUI.update(dt)
    PauseUI.slide = PauseUI.slide + ((PauseUI.open and 1 or 0) - PauseUI.slide) * math.min(1, dt * 13)
    if PauseUI.dragVol then
        if love.mouse.isDown(1) then
            local v = math.floor(S.clamp01((S.mx - BAR_X) / BAR_W) * 20 + 0.5) * 5
            if v ~= deps.SaveData.data.volume then
                deps.SaveData.data.volume = v
                deps.SaveData.save()
                if deps.applyVolume then deps.applyVolume() end
            end
        else
            PauseUI.dragVol = false
        end
    end
end

------------------------------------------------------------
-- helpers
------------------------------------------------------------
local function pushRotate(cx, cy, deg)
    love.graphics.push()
    local X, Y = S.ox + cx * S.s, S.oy + cy * S.s
    love.graphics.translate(X, Y)
    love.graphics.rotate(math.rad(deg))
    love.graphics.translate(-X, -Y)
end

local function polyFill(worldVerts, col, alpha)
    local pts = {}
    for i = 1, #worldVerts, 2 do
        pts[#pts + 1] = S.ox + worldVerts[i] * S.s
        pts[#pts + 1] = S.oy + worldVerts[i + 1] * S.s
    end
    love.graphics.setColor(col[1], col[2], col[3], alpha)
    local ok, tris = pcall(love.math.triangulate, pts)
    if ok then
        for _, t in ipairs(tris) do love.graphics.polygon("fill", t) end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

------------------------------------------------------------
-- HUD: timer tag (top-right) + LV + pause button (top-left)
------------------------------------------------------------
function PauseUI.drawHUD(level)
    local W = S.W
    local RunTimer = deps.RunTimer
    local MPAL, PAL = S.MPAL, S.PAL

    -- timer paper tag
    local tw = 26
    S.px(W - tw - 3, 2, tw + 1, 9, S.CARD, 0.75)
    S.rect(W - tw - 3, 2, tw + 1, 9, RunTimer.fullRun and MPAL.RED or MPAL.PENCIL_L, 0.5, 1.2, 550)
    S.text(RunTimer.fmt(RunTimer.time), W - 4, 6.8, 17,
        RunTimer.fullRun and PAL.BLOOD or PAL.FADE, "right", 1, true, true)
    if RunTimer.fullRun then
        S.text("速通", W - tw - 9, 6.8, 12, PAL.BLOOD, "center", 0.6 + math.sin(S.time * 3) * 0.2)
    end
    S.text("LV." .. level, W / 2, 7, 17, PAL.FADE, "center", 0.85, false, true)

    -- pause button: boiling hand-drawn circle + bars + ink-fill hover
    local pbx, pby, pbs = 4, 3, 11
    local phov = S.isHover(pbx, pby, pbs, pbs) and not PauseUI.open
    local pt = S.hoverT["pause"] or 0
    pt = pt + ((phov and 1 or 0) - pt) * math.min(1, S.dt * 13)
    S.hoverT["pause"] = pt
    if phov and not S.lastHover["pause"] then deps.playSFX("tick") end
    S.lastHover["pause"] = phov

    local pcx, pcy = pbx + pbs / 2, pby + pbs / 2
    if pt > 0.03 then
        S.blob(pcx, pcy, (pbs / 2) * 0.92 * S.easeOutCubic(pt), PAL.INK, 0.85 * pt, 551)
    end
    S.roughCircle(pcx, pcy, pbs / 2 - 0.5, phov and MPAL.RED or PAL.INK,
        phov and 0.95 or 0.5, phov and 2.4 or 1.6, 552)
    local ic = pt > 0.45 and MPAL.PAPER or (phov and MPAL.RED or PAL.INK)
    S.px(pbx + 3.4, pby + 3.5, 1.4, 4.2, ic, phov and 1 or 0.7)
    S.px(pbx + 6.2, pby + 3.5, 1.4, 4.2, ic, phov and 1 or 0.7)
    if not PauseUI.open then
        S.addClick("pausebtn", pbx, pby, pbs, pbs, function()
            PauseUI.toggle()
        end)
    end
end

------------------------------------------------------------
-- Pause overlay
------------------------------------------------------------
function PauseUI.drawOverlay()
    local sl = PauseUI.slide
    if sl <= 0.01 and not PauseUI.open then return end
    local W, H = S.W, S.H
    S.px(0, 0, W, H, S.PAL.INK, 0.55 * sl)
    if not PauseUI.open then return end
    S.addClick("pauseblock", 0, 0, W, H, function() end)
    if PauseUI.settingsOpen then
        PauseUI.drawSettingsPanel(false)
        return
    end

    local MPAL = S.MPAL
    local pw, ph = 78, 100
    local pxx = (W - pw) / 2
    local pyy = (H - ph) / 2 + (1 - S.easeOutBack(sl)) * 26

    pushRotate(W / 2, pyy + ph / 2, -0.8)
    -- shadow
    love.graphics.setColor(8 / 255, 6 / 255, 4 / 255, 0.45 * sl)
    love.graphics.rectangle("fill", S.ox + (pxx + 2) * S.s, S.oy + (pyy + 2.5) * S.s, pw * S.s, ph * S.s)
    -- paper with torn top edge
    local verts = { pxx, pyy + 2 }
    for i = 0, 12 do
        verts[#verts + 1] = pxx + pw * i / 12
        verts[#verts + 1] = pyy + 1 + S.jr(560, i) * 1.4
    end
    verts[#verts + 1] = pxx + pw; verts[#verts + 1] = pyy + ph
    verts[#verts + 1] = pxx;      verts[#verts + 1] = pyy + ph
    polyFill(verts, MPAL.PAPER, 0.97 * sl)
    S.rect(pxx, pyy + 1, pw, ph - 1, MPAL.PENCIL, 0.7 * sl, 1.8, 561)

    S.text("暂 停", W / 2, pyy + 15, 38, MPAL.PENCIL, "center", sl, true)
    S.line(pxx + 12, pyy + 24, pxx + pw - 12, pyy + 24.5, MPAL.PENCIL_L, 0.5 * sl, 1.3, 562)
    S.text("— 计时已暂停 —", W / 2, pyy + 31, 14, MPAL.PENCIL_L, "center", 0.7 * sl)

    S.button("p_resume", pxx + 9, pyy + 38, pw - 18, 15, "继续游戏", true, function()
        PauseUI.toggle()
    end, 24)
    S.button("p_set", pxx + 9, pyy + 58, pw - 18, 15, "设 置", false, function()
        PauseUI.settingsOpen = true
        deps.playSFX("page")
    end, 24)
    S.button("p_menu", pxx + 9, pyy + 78, pw - 18, 15, "返回主界面", false, function()
        deps.onReturnToMenu()
    end, 24)
    love.graphics.pop()
end

------------------------------------------------------------
-- Settings panel (shared menu / pause; reset only from menu)
------------------------------------------------------------
function PauseUI.drawSettingsPanel(fromMenu)
    local W, H = S.W, S.H
    local MPAL, PAL = S.MPAL, S.PAL
    local SaveData = deps.SaveData

    S.px(0, 0, W, H, MPAL.PAPER, 0.96)
    S.drawPaper(true, 0.5)
    S.drawDust(S.dt)

    S.text("设 置", W / 2, 26, 42, MPAL.PENCIL, "center", 1, true)
    if deps.sprites and deps.sprites.mothA then
        local boil = S.boilF % 2 == 1
        S.sprite(boil and deps.sprites.mothB or deps.sprites.mothA, W / 2 - 30, 26, 0.5)
        S.sprite(boil and deps.sprites.mothA or deps.sprites.mothB, W / 2 + 30, 26, 0.5)
    end
    S.line(20, 37, W - 20, 37.5, MPAL.PENCIL_L, 0.55, 1.4, 420)

    -- volume slider
    local vy = 56
    S.text("主音量", 20, vy, 24, MPAL.PENCIL, "left")
    local barY = vy + 10
    S.line(BAR_X, barY + 1, BAR_X + BAR_W, barY + 1, MPAL.PENCIL_L, 0.5, 2, 421)
    local frac = SaveData.data.volume / 100
    if frac > 0 then
        love.graphics.setColor(PAL.BLOOD[1], PAL.BLOOD[2], PAL.BLOOD[3], 0.85)
        love.graphics.setLineWidth(3.5 * S.s / 4)
        love.graphics.setLineStyle("smooth")
        love.graphics.line(S.ox + BAR_X * S.s, S.oy + (barY + 1) * S.s,
            S.ox + (BAR_X + BAR_W * frac) * S.s, S.oy + (barY + 1) * S.s)
        love.graphics.setColor(1, 1, 1, 1)
    end
    local knobX = BAR_X + BAR_W * frac
    local knobHov = S.isHover(knobX - 4, barY - 4, 8, 10) or PauseUI.dragVol
    S.blob(knobX, barY + 1, knobHov and 4.2 or 3.4, PAL.BLOOD, 1, 422)       -- blood wax knob
    S.blob(knobX - 0.8, barY + 0.2, 1.1, S.HILITE, 0.7, 423)                  -- highlight
    S.text(tostring(SaveData.data.volume), W - 16, barY + 1, 24, MPAL.PENCIL, "right", 1, false, true)
    S.addClick("volbar", BAR_X - 4, barY - 6, BAR_W + 8, 14, function()
        PauseUI.dragVol = true
        SaveData.data.volume = math.floor(S.clamp01((S.mx - BAR_X) / BAR_W) * 20 + 0.5) * 5
        SaveData.save()
        if deps.applyVolume then deps.applyVolume() end
    end)

    -- shake: three stamp options
    local sy2 = 92
    S.text("画面震动", 20, sy2, 24, MPAL.PENCIL, "left")
    local labels = { "关", "弱", "开" }
    for i = 0, 2 do
        local ox2 = 56 + i * 17
        local sel = SaveData.data.shake == i
        local hov = S.isHover(ox2 - 6.5, sy2 - 6, 13, 12)
        if sel then
            S.blob(ox2, sy2 + 0.3, 6.4, PAL.BLOOD, 0.13, 425 + i)
            S.rect(ox2 - 6, sy2 - 5.5, 12, 11, MPAL.RED, 0.9, 2, 430 + i)
        elseif hov then
            S.rect(ox2 - 6, sy2 - 5.5, 12, 11, MPAL.PENCIL, 0.5, 1.4, 430 + i)
        end
        S.text(labels[i + 1], ox2, sy2 + 0.5, 24,
            sel and MPAL.RED or (hov and MPAL.PENCIL or MPAL.PENCIL_L), "center", 1, sel)
        S.addClick("shake" .. i, ox2 - 6.5, sy2 - 6, 13, 12, function()
            SaveData.data.shake = i
            SaveData.save()
            deps.playSFX("click")
            if i > 0 and deps.previewShake then deps.previewShake(i == 1 and 4 or 8) end
        end)
    end

    -- reset progress (menu only, confirm)
    if fromMenu then
        local ry = 122
        S.button("resetbtn", W / 2 - 32, ry, 64, 14, "重置进度", false, function()
            PauseUI.resetConfirm = true
        end, 22)
        S.text("当前进度  第 " .. SaveData.data.furthest .. " 关", W / 2, ry + 21, 16, MPAL.PENCIL_L)
        if SaveData.data.bestTime then
            S.text("最佳纪录  " .. deps.RunTimer.fmt(SaveData.data.bestTime), W / 2, ry + 29, 15,
                MPAL.PENCIL_L, "center", 0.85, false, true)
        end
    end

    S.button("setback", W / 2 - 32, H - 32, 64, 16, "返 回", true, function()
        if fromMenu then
            PauseUI.menuSettingsOpen = false
        else
            PauseUI.settingsOpen = false
        end
    end)

    if fromMenu and PauseUI.resetConfirm then
        PauseUI.drawConfirmDialog("确认重置全部进度？", "该操作无法撤销", function()
            SaveData.resetProgress()
            PauseUI.resetConfirm = false
            deps.playSFX("stamp")
        end, function()
            PauseUI.resetConfirm = false
        end)
    end
end

function PauseUI.drawConfirmDialog(title, sub, onYes, onNo)
    local W, H = S.W, S.H
    local MPAL = S.MPAL
    S.px(0, 0, W, H, S.PAL.INK, 0.55)
    S.addClick("dlgblock", 0, 0, W, H, function() end)
    local dx, dy = 11, 68
    local dw, dh = W - 22, 54
    pushRotate(W / 2, dy + dh / 2, -0.7)
    love.graphics.setColor(20 / 255, 16 / 255, 12 / 255, 0.4)
    love.graphics.rectangle("fill", S.ox + (dx + 1.5) * S.s, S.oy + (dy + 2) * S.s, dw * S.s, dh * S.s)
    love.graphics.setColor(1, 1, 1, 1)
    S.px(dx, dy, dw, dh, MPAL.PAPER, 1)
    S.rect(dx, dy, dw, dh, MPAL.PENCIL, 0.85, 2, 440)
    S.text(title, W / 2, dy + 13, 25, MPAL.PENCIL, "center", 1, true)
    S.text(sub, W / 2, dy + 24, 16, MPAL.RED)
    S.button("dlgno", dx + 6, dy + dh - 18, (dw - 18) / 2, 13, "取 消", false, onNo, 20)
    S.button("dlgyes", dx + dw / 2 + 3, dy + dh - 18, (dw - 18) / 2, 13, "确认重置", true, onYes, 20)
    love.graphics.pop()
end

return PauseUI
