--[[
    LevelSelect — paginated scattered level cards
    blood-wax seal ✓ (cleared) / pencil-hatch lock (locked) / red pulse (current)
    Transcribed from prototypes/ui_prototype.html (approved, overlap-fixed layout)
]]

local LevelSelect = {}

local S
local deps = {}  -- { Sketch, SaveData, playSFX, onPick(n), onBack() }

LevelSelect.PER_PAGE = 8
LevelSelect.page = 0
LevelSelect.shakeLock = 0
LevelSelect.shakeLockId = -1
LevelSelect.pageAnim = 1
LevelSelect.pageDir = 1

function LevelSelect.init(d)
    deps = d
    S = d.Sketch
end

function LevelSelect.totalPages()
    return math.ceil(deps.SaveData.totalLevels / LevelSelect.PER_PAGE)
end

function LevelSelect.enter()
    LevelSelect.page = math.floor((deps.SaveData.data.furthest - 1) / LevelSelect.PER_PAGE)
    LevelSelect.page = math.max(0, math.min(LevelSelect.totalPages() - 1, LevelSelect.page))
    LevelSelect.pageAnim = 1
    LevelSelect.shakeLock = 0
end

function LevelSelect.flip(dir)
    local np = LevelSelect.page + dir
    if np < 0 or np >= LevelSelect.totalPages() then return end
    LevelSelect.page = np
    LevelSelect.pageDir = dir > 0 and 1 or -1
    LevelSelect.pageAnim = 0
    deps.playSFX("page")
end

local function clickLevel(n)
    if n > deps.SaveData.data.furthest then
        LevelSelect.shakeLock = 0.45
        LevelSelect.shakeLockId = n
        deps.playSFX("locked")
        return
    end
    deps.playSFX("click")
    deps.onPick(n)
end

function LevelSelect.draw(dt)
    local W, H = S.W, S.H
    local MPAL, PAL = S.MPAL, S.PAL
    local SaveData = deps.SaveData
    local TOTAL = SaveData.totalLevels
    local now = S.time

    S.drawPaper(true)
    S.drawDust(dt)
    if LevelSelect.shakeLock > 0 then LevelSelect.shakeLock = LevelSelect.shakeLock - dt end
    LevelSelect.pageAnim = math.min(1, LevelSelect.pageAnim + dt * 4.5)

    -- title (slight tilt)
    love.graphics.push()
    local tX, tY = S.ox + W / 2 * S.s, S.oy + 17 * S.s
    love.graphics.translate(tX, tY)
    love.graphics.rotate(math.rad(-1.2))
    love.graphics.translate(-tX, -tY)
    S.text("选择关卡", W / 2 + 0.5, 17.5, 42, MPAL.PENCIL_L, "center", 1, true)
    S.text("选择关卡", W / 2, 17, 42, MPAL.PENCIL, "center", 1, true)
    love.graphics.pop()
    S.line(24, 27, W - 24, 27.5, MPAL.PENCIL_L, 0.55, 1.4, 450)
    if not (LevelSelect.shakeLock > 0.05) then
        S.text("已通关 " .. (SaveData.data.furthest - 1) .. " / " .. TOTAL,
            W / 2, 33, 15, MPAL.PENCIL_L, "center", 0.8)
    end

    local page = LevelSelect.page
    local furthest = SaveData.data.furthest
    local cellW, cellH, gapX, gapY = 40, 23, 9, 5
    local gridX = (W - cellW * 2 - gapX) / 2
    local gridY = 39
    local slide = (1 - S.easeOutCubic(LevelSelect.pageAnim)) * 26 * LevelSelect.pageDir
    local fade = S.easeOutCubic(LevelSelect.pageAnim)

    for i = 0, LevelSelect.PER_PAGE - 1 do
        local n = page * LevelSelect.PER_PAGE + i + 1
        if n > TOTAL then break end
        local col = i % 2
        local row = math.floor(i / 2)
        local x = gridX + col * (cellW + gapX) - slide
        local y = gridY + row * (cellH + gapY)
        local locked = n > furthest
        local cleared = n < furthest
        local current = n == furthest
        if locked and LevelSelect.shakeLockId == n and LevelSelect.shakeLock > 0 then
            x = x + math.sin(LevelSelect.shakeLock * 55) * 1.6
        end
        local hov = (not locked) and S.isHover(x, y, cellW, cellH)
        local key = "lv" .. n
        local ht = S.hoverT[key] or 0
        ht = ht + ((hov and 1 or 0) - ht) * math.min(1, S.dt * 13)
        S.hoverT[key] = ht
        if hov and not S.lastHover[key] then deps.playSFX("tick") end
        S.lastHover[key] = hov

        -- scattered feel: fixed tilt per card; hover lifts/scales
        love.graphics.push()
        local rot = (S.hashN(n * 17.3) * 2 - 1) * 1.5
        local cx2 = S.ox + (x + cellW / 2) * S.s
        local cy2 = S.oy + (y + cellH / 2) * S.s
        love.graphics.translate(cx2, cy2 - ht * 4 * S.s / 4)
        love.graphics.rotate(math.rad(rot * (1 - ht * 0.6)))
        love.graphics.scale(1 + ht * 0.05, 1 + ht * 0.05)
        love.graphics.translate(-cx2, -cy2)

        if locked then
            -- locked: grey card + pencil hatching + lock
            S.px(x, y, cellW, cellH, MPAL.PENCIL_L, 0.08 * fade)
            love.graphics.setColor(MPAL.PENCIL_L[1], MPAL.PENCIL_L[2], MPAL.PENCIL_L[3], 0.5 * fade)
            love.graphics.setLineWidth(math.max(0.8, S.s / 4))
            for hx = -cellH, cellW - 1, 5 do
                local sx1 = x + math.max(0, hx)
                local sy1 = y + math.max(0, -hx)
                local ex1 = x + math.min(cellW, hx + cellH)
                local ey1 = y + math.min(cellH, cellH - math.max(0, hx + cellH - cellW))
                love.graphics.line(S.ox + sx1 * S.s, S.oy + sy1 * S.s, S.ox + ex1 * S.s, S.oy + ey1 * S.s)
            end
            love.graphics.setColor(1, 1, 1, 1)
            S.rect(x, y, cellW, cellH, MPAL.PENCIL_L, 0.4 * fade, 1.2, S.sid(key))
            S.text(tostring(n), x + cellW / 2 - 6, y + cellH / 2 + 0.5, 30, MPAL.PENCIL_L, "center", 0.5 * fade)
            -- lock
            local lx, ly = x + cellW / 2 + 9, y + cellH / 2 + 1
            S.px(lx - 3.5, ly - 1.5, 7, 6, MPAL.PENCIL_L, 0.75 * fade)
            S.px(lx - 1, ly + 0.5, 2, 2.4, MPAL.PAPER, 0.8 * fade)
            love.graphics.setColor(MPAL.PENCIL_L[1], MPAL.PENCIL_L[2], MPAL.PENCIL_L[3], 0.75 * fade)
            love.graphics.setLineWidth(2.2 * S.s / 4)
            love.graphics.arc("line", "open", S.ox + lx * S.s, S.oy + (ly - 2) * S.s, 2.2 * S.s, math.pi, math.pi * 2)
            love.graphics.setColor(1, 1, 1, 1)
        else
            -- playable card: paper card + shadow
            if ht > 0.03 then
                love.graphics.setColor(25 / 255, 20 / 255, 15 / 255, 0.22 * ht * fade)
                love.graphics.rectangle("fill", S.ox + (x + 1) * S.s, S.oy + (y + 2) * S.s, cellW * S.s, cellH * S.s)
                love.graphics.setColor(1, 1, 1, 1)
            end
            S.px(x, y, cellW, cellH, S.CARD, 0.65 * fade)
            if current then
                local pulse = 0.55 + math.sin(now * 4) * 0.25
                S.blob(x + cellW / 2, y + cellH / 2, (cellW / 2 + 4) * 0.62, PAL.BLOOD,
                    (0.06 + 0.04 * math.sin(now * 4)) * fade, S.sid(key) + 9)
                S.rect(x, y, cellW, cellH, MPAL.RED, (hov and 0.95 or pulse) * fade,
                    hov and 2.6 or 2.1, S.sid(key))
                S.text("当前", x + cellW - 8, y + 4.5, 13, MPAL.RED, "center", 0.9 * fade)
            else
                S.rect(x, y, cellW, cellH, MPAL.PENCIL, (hov and 0.9 or 0.42) * fade,
                    hov and 2 or 1.4, S.sid(key))
            end
            S.text(tostring(n), x + cellW / 2 + (cleared and -5 or 0), y + cellH / 2 + 0.5, 33,
                (hov or current) and MPAL.RED or MPAL.PENCIL, "center", fade, current)
            if cleared then
                -- blood wax seal ✓
                local sx2, sy3 = x + cellW / 2 + 9, y + cellH / 2
                S.blob(sx2, sy3, 4.6, PAL.BLOOD, 0.85 * fade, S.sid(key) + 5)
                S.blob(sx2 - 1, sy3 - 1, 1.4, S.HILITE, 0.45 * fade, S.sid(key) + 6)
                love.graphics.setColor(MPAL.PAPER[1], MPAL.PAPER[2], MPAL.PAPER[3], 0.95 * fade)
                love.graphics.setLineWidth(2.4 * S.s / 4)
                love.graphics.setLineJoin("none")
                love.graphics.line(
                    S.ox + (sx2 - 2.2) * S.s, S.oy + sy3 * S.s,
                    S.ox + (sx2 - 0.6) * S.s, S.oy + (sy3 + 1.8) * S.s,
                    S.ox + (sx2 + 2.6) * S.s, S.oy + (sy3 - 2.2) * S.s)
                love.graphics.setColor(1, 1, 1, 1)
            end
        end
        love.graphics.pop()
        S.addClick(key, x, y, cellW, cellH, function() clickLevel(n) end)
    end

    -- locked tooltip
    if LevelSelect.shakeLock > 0.05 and LevelSelect.shakeLockId > 0 then
        local a = math.min(1, LevelSelect.shakeLock * 4)
        S.text("通关第 " .. (LevelSelect.shakeLockId - 1) .. " 关后解锁",
            W / 2, 33, 15, MPAL.RED, "center", a * 0.9)
    end

    -- pagination: triangle arrows + page dots
    local py = gridY + 4 * (cellH + gapY) + 4
    local tp = LevelSelect.totalPages()
    local function arrowBtn(id, dir, ax)
        local en = (dir < 0) and page > 0 or (dir > 0) and page < tp - 1
        local hov = en and S.isHover(ax, py - 3, 16, 14)
        local bounce = hov and math.sin(now * 8) * 0.8 or 0
        local cx = ax + 8 + bounce * dir
        local cy = py + 4
        local col = en and (hov and MPAL.RED or MPAL.PENCIL) or MPAL.PENCIL_L
        love.graphics.setColor(col[1], col[2], col[3], en and 1 or 0.22)
        local d = dir < 0 and -1 or 1
        love.graphics.polygon("fill",
            S.ox + (cx + d * 2.8) * S.s, S.oy + cy * S.s,
            S.ox + (cx - d * 1.8) * S.s, S.oy + (cy - 3.4) * S.s,
            S.ox + (cx - d * 1.8) * S.s, S.oy + (cy + 3.4) * S.s)
        love.graphics.setColor(1, 1, 1, 1)
        if en then
            S.addClick(id, ax, py - 3, 16, 14, function() LevelSelect.flip(dir) end)
        end
        if hov and not S.lastHover[id] then deps.playSFX("tick") end
        S.lastHover[id] = hov
    end
    arrowBtn("pgL", -1, W / 2 - 36)
    arrowBtn("pgR", 1, W / 2 + 20)
    S.text((page + 1) .. " / " .. tp, W / 2, py + 4, 24, MPAL.PENCIL, "center", 1, false, true)
    for i = 0, tp - 1 do
        local dotX = W / 2 + (i - (tp - 1) / 2) * 7
        if i == page then
            S.blob(dotX, py + 13, 1.8, PAL.BLOOD, 0.9, 460 + i)
        else
            S.px(dotX - 0.8, py + 12.3, 1.6, 1.6, MPAL.PENCIL_L, 0.45)
            S.addClick("dot" .. i, dotX - 3, py + 10, 6, 6, function()
                LevelSelect.flip(i - LevelSelect.page)
            end)
        end
    end

    S.button("lsback", W / 2 - 32, H - 18, 64, 14, "返 回", false, function()
        deps.onBack()
    end, 24)
end

return LevelSelect
