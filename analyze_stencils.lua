local levels = require("levels")

-- Simple image data loader
local function analyzeStencil(levelNum)
    local ld = levels[levelNum]
    local stencilData = love.image.newImageData(ld.stencilFile)
    
    local w, h = stencilData:getDimensions()
    local insideCount = 0
    local totalPixels = w * h
    
    -- Count pixels with alpha > 0.5 (inside cave)
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local _, _, _, a = stencilData:getPixel(x, y)
            if a > 0.5 then
                insideCount = insideCount + 1
            end
        end
    end
    
    local percentage = (insideCount / totalPixels) * 100
    
    print(string.format("Level %d: %.1f%% inside (alpha > 0.5), %d/%d pixels", 
        levelNum, percentage, insideCount, totalPixels))
    
    return percentage
end

-- Analyze all levels
for i = 1, 9 do
    analyzeStencil(i)
end
