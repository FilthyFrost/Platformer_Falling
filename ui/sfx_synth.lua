--[[
    Procedural SFX synthesis for Cave Fall UI
    Transcribed from the WebAudio synth in prototypes/ui_prototype.html:
    tick / page / locked / shatter / mater / stamp
    (other SFX use the existing wav files)
]]

local SfxSynth = {}

local RATE = 22050

-- Exponential envelope: 0 -> peak in 8ms -> ~0 at dur
local function env(t, peak, dur)
    if t < 0 or t > dur then return 0 end
    if t < 0.008 then
        return peak * (t / 0.008)
    end
    local k = math.log(0.0001 / peak)
    return peak * math.exp(k * (t - 0.008) / math.max(0.001, dur - 0.008))
end

-- Add an oscillator sweep into buffer
-- type: "sine" | "square" | "triangle"
local function addOsc(buf, n, oscType, f0, f1, t0, dur, peak)
    local phase = 0
    local i0 = math.max(0, math.floor(t0 * RATE))
    local i1 = math.min(n - 1, math.floor((t0 + dur) * RATE))
    local lnRatio = (f1 and f1 > 0) and math.log(f1 / f0) or nil
    for i = i0, i1 do
        local t = i / RATE - t0
        local f = f0
        if lnRatio then f = f0 * math.exp(lnRatio * (t / dur)) end
        phase = phase + 2 * math.pi * f / RATE
        local s
        if oscType == "square" then
            s = math.sin(phase) >= 0 and 1 or -1
        elseif oscType == "triangle" then
            s = 2 / math.pi * math.asin(math.sin(phase))
        else
            s = math.sin(phase)
        end
        buf[i] = (buf[i] or 0) + s * env(t, peak, dur)
    end
end

-- Add bandpass-filtered noise (biquad, Q=0.8)
local function addHiss(buf, n, t0, dur, peak, freq)
    local w0 = 2 * math.pi * freq / RATE
    local Q = 0.8
    local alpha = math.sin(w0) / (2 * Q)
    local b0, b2 = alpha, -alpha
    local a0 = 1 + alpha
    local a1 = -2 * math.cos(w0)
    local a2 = 1 - alpha
    local x1, x2, y1, y2 = 0, 0, 0, 0
    local i0 = math.max(0, math.floor(t0 * RATE))
    local i1 = math.min(n - 1, math.floor((t0 + dur) * RATE))
    for i = i0, i1 do
        local t = i / RATE - t0
        local x = math.random() * 2 - 1
        local y = (b0 * x + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1 = x1, x
        y2, y1 = y1, y
        buf[i] = (buf[i] or 0) + y * env(t, peak, dur)
    end
end

local function build(totalDur, fn)
    local n = math.floor(RATE * totalDur)
    local buf = {}
    fn(buf, n)
    local data = love.sound.newSoundData(n, RATE, 16, 1)
    for i = 0, n - 1 do
        local s = buf[i] or 0
        if s > 1 then s = 1 elseif s < -1 then s = -1 end
        data:setSample(i, s)
    end
    return love.audio.newSource(data, "static")
end

function SfxSynth.generate()
    local out = {}

    -- tick: tiny dry click on hover
    out.tick = build(0.04, function(buf, n)
        addOsc(buf, n, "square", 1900, nil, 0, 0.018, 0.12)
    end)

    -- page: paper flip (two layered hiss bursts)
    out.page = build(0.25, function(buf, n)
        addHiss(buf, n, 0, 0.16, 0.45, 2200)
        addHiss(buf, n, 0.03, 0.12, 0.28, 3500)
    end)

    -- locked: dull low thud (locked level)
    out.locked = build(0.18, function(buf, n)
        addOsc(buf, n, "sine", 90, 60, 0, 0.12, 0.7)
    end)

    -- shatter: armor break (4 detuned square pings + hiss)
    out.shatter = build(0.25, function(buf, n)
        for i = 0, 3 do
            addOsc(buf, n, "square", 700 + i * 420, 300, i * 0.012, 0.07, 0.18)
        end
        addHiss(buf, n, 0, 0.14, 0.5, 3000)
    end)

    -- mater: void materialize (rising sine + late shimmer)
    out.mater = build(0.55, function(buf, n)
        addOsc(buf, n, "sine", 180, 720, 0, 0.45, 0.45)
        addHiss(buf, n, 0.25, 0.25, 0.2, 5000)
    end)

    -- stamp: record stamp slam (deep thump + paper slap)
    out.stamp = build(0.25, function(buf, n)
        addOsc(buf, n, "sine", 70, 40, 0, 0.18, 0.95)
        addHiss(buf, n, 0, 0.05, 0.4, 700)
    end)

    return out
end

return SfxSynth
