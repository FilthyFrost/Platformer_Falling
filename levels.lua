--[[
    Level Data for Cave Fall (v5)
    Includes platform walkable bounds.
    All coordinates in SCREEN SPACE (Y-down), 108x192
]]

local levels = {}

levels[1] = {
    stencilFile = "maps/level_1_stencil.png",
    textureFile = "maps/level_1_texture.png",
    playerStart = {x = 22, y = 74},
    platformXMin = 9,
    platformXMax = 33,
    bats = {
        {x = 68, y = 68},
        {x = 84, y = 111},
        {x = 46, y = 133},
    },
}

levels[2] = {
    stencilFile = "maps/level_2_stencil.png",
    textureFile = "maps/level_2_texture.png",
    playerStart = {x = 89, y = 72},
    platformXMin = 75,
    platformXMax = 94,
    bats = {
        {x = 56, y = 73},
        {x = 25, y = 74},
        {x = 56, y = 126},
    },
}

levels[3] = {
    stencilFile = "maps/level_3_stencil.png",
    textureFile = "maps/level_3_texture.png",
    playerStart = {x = 31, y = 59},
    platformXMin = 20,
    platformXMax = 42,
    bats = {
        {x = 55, y = 76},
        {x = 33, y = 122},
        {x = 55, y = 155},
    },
}

levels[4] = {
    stencilFile = "maps/level_4_stencil.png",
    textureFile = "maps/level_4_texture.png",
    playerStart = {x = 55, y = 70},
    platformXMin = 46,
    platformXMax = 97,
    bats = {
        {x = 80, y = 72},
        {x = 56, y = 126},
        {x = 76, y = 150},
    },
}

levels[5] = {
    stencilFile = "maps/level_5_stencil.png",
    textureFile = "maps/level_5_texture.png",
    playerStart = {x = 28, y = 51},
    platformXMin = 13,
    platformXMax = 36,
    bats = {
        {x = 81, y = 66},
        {x = 33, y = 101},
        {x = 54, y = 153},
    },
}

levels[6] = {
    stencilFile = "maps/level_6_stencil.png",
    textureFile = "maps/level_6_texture.png",
    playerStart = {x = 21, y = 70},
    platformXMin = 13,
    platformXMax = 30,
    bats = {
        {x = 93, y = 91},
        {x = 21, y = 118},
        {x = 75, y = 118},
        {x = 40, y = 143},
    },
}

levels[7] = {
    stencilFile = "maps/level_7_stencil.png",
    textureFile = "maps/level_7_texture.png",
    playerStart = {x = 56, y = 46},
    platformXMin = 48,
    platformXMax = 65,
    bats = {
        {x = 37, y = 58},
        {x = 77, y = 61},
        {x = 76, y = 115},
        {x = 38, y = 117},
        {x = 75, y = 171},
        {x = 39, y = 173},
    },
}

levels[8] = {
    stencilFile = "maps/level_8_stencil.png",
    textureFile = "maps/level_8_texture.png",
    playerStart = {x = 87, y = 77},
    platformXMin = 71,
    platformXMax = 96,
    bats = {
        {x = 18, y = 90},
        {x = 55, y = 90},
        {x = 88, y = 106},
        {x = 35, y = 132},
        {x = 72, y = 134},
    },
}

levels[9] = {
    stencilFile = "maps/level_9_stencil.png",
    textureFile = "maps/level_9_texture.png",
    playerStart = {x = 22, y = 67},
    platformXMin = 14,
    platformXMax = 30,
    bats = {
        {x = 56, y = 87},
        {x = 90, y = 87},
        {x = 40, y = 104},
        {x = 24, y = 145},
        {x = 91, y = 145},
        {x = 55, y = 147},
    },
}

return levels
