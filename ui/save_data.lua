--[[
    SaveData + RunTimer for Cave Fall
    - Persistence via love.filesystem (key=value text file)
    - furthest: highest unlocked level (clear N -> unlock N+1)
    - bestTime: best full-run speedrun time (level 1 -> 36 in one session)
    - volume / shake: settings synced with in-game settings panel
    Transcribed from prototypes/ui_prototype.html (approved design)
]]

local SaveData = {}

SaveData.FILE = "cavefall_save.txt"
SaveData.totalLevels = 36

SaveData.data = {
    furthest = 1,
    bestTime = nil,   -- seconds, nil = no record
    volume = 80,      -- 0-100
    shake = 2,        -- 0=off, 1=weak, 2=on
}

function SaveData.init(totalLevels)
    SaveData.totalLevels = totalLevels or 36
end

function SaveData.load()
    if not love.filesystem.getInfo(SaveData.FILE) then return end
    local content = love.filesystem.read(SaveData.FILE)
    if not content then return end
    for line in content:gmatch("[^\r\n]+") do
        local k, v = line:match("^([%w_]+)%s*=%s*(.+)$")
        if k == "furthest" then
            SaveData.data.furthest = math.max(1, math.min(SaveData.totalLevels, tonumber(v) or 1))
        elseif k == "bestTime" then
            SaveData.data.bestTime = tonumber(v)
        elseif k == "volume" then
            SaveData.data.volume = math.max(0, math.min(100, tonumber(v) or 80))
        elseif k == "shake" then
            SaveData.data.shake = math.max(0, math.min(2, math.floor(tonumber(v) or 2)))
        end
    end
end

function SaveData.save()
    local lines = {
        "furthest=" .. SaveData.data.furthest,
        "volume=" .. SaveData.data.volume,
        "shake=" .. SaveData.data.shake,
    }
    if SaveData.data.bestTime then
        table.insert(lines, string.format("bestTime=%.3f", SaveData.data.bestTime))
    end
    love.filesystem.write(SaveData.FILE, table.concat(lines, "\n"))
end

-- Called when level `level` is cleared: unlock level+1
function SaveData.markCleared(level)
    if level + 1 > SaveData.data.furthest then
        SaveData.data.furthest = math.min(level + 1, SaveData.totalLevels)
        SaveData.save()
    end
end

-- Returns true if this is a new record
function SaveData.submitTime(t)
    if SaveData.data.bestTime == nil or t < SaveData.data.bestTime then
        SaveData.data.bestTime = t
        SaveData.save()
        return true
    end
    return false
end

function SaveData.resetProgress()
    SaveData.data.furthest = 1
    SaveData.data.bestTime = nil
    SaveData.save()
end

------------------------------------------------------------
-- RunTimer: wall-clock run timer (includes death/rewind),
-- paused while the pause menu is open.
-- fullRun = started at level 1 and never returned to menu.
------------------------------------------------------------
local RunTimer = {
    time = 0,
    running = false,
    fullRun = false,
}

function RunTimer.startRun(fromLevel1)
    RunTimer.time = 0
    RunTimer.running = true
    RunTimer.fullRun = fromLevel1 and true or false
end

function RunTimer.update(dt)
    if RunTimer.running then
        RunTimer.time = RunTimer.time + dt
    end
end

function RunTimer.stop()
    RunTimer.running = false
end

function RunTimer.breakFullRun()
    RunTimer.fullRun = false
end

function RunTimer.fmt(t)
    t = math.max(0, t or 0)
    local m = math.floor(t / 60)
    local s = math.floor(t % 60)
    local d = math.floor((t % 1) * 10)
    return string.format("%02d:%02d.%d", m, s, d)
end

SaveData.RunTimer = RunTimer

return SaveData
