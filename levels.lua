--[[
    Level Data for Cave Fall
    Generated from editor_maps
    All coordinates in SCREEN SPACE (Y-down), 108x192
]]

local levels = {}

levels[1] = {
    stencilFile = "maps/level_1_stencil.png",
    textureFile = "maps/level_1_texture.png",
    playerStart = {x = 18, y = 78},
    platformXMin = 12,
    platformXMax = 24,
    bats = {
        {x = 90, y = 90, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 66, y = 90, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
    },
    voidBats = {
    },
    mirrorLines = {
    },
    airWalls = {
        {x = 30, y = 78},
        {x = 6, y = 78},
    },
    spawnPlatform = {x = 12, y = 82, width = 12},
}

levels[2] = {
    stencilFile = "maps/level_2_stencil.png",
    textureFile = "maps/level_2_texture.png",
    playerStart = {x = 30, y = 42},
    platformXMin = 12,
    platformXMax = 36,
    bats = {
        {x = 54, y = 78, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 78, y = 150, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 54, y = 126, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
    },
    voidBats = {
    },
    mirrorLines = {
    },
    airWalls = {
        {x = 42, y = 42},
        {x = 6, y = 42},
    },
    spawnPlatform = {x = 12, y = 46, width = 24},
}

levels[3] = {
    stencilFile = "maps/level_3_stencil.png",
    textureFile = "maps/level_3_texture.png",
    playerStart = {x = 42, y = 30},
    platformXMin = 0,
    platformXMax = 107,
    bats = {
        {x = 60, y = 102, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 24, y = 102, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 60, y = 48, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 24, y = 48, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 60, y = 162, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 24, y = 162, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
    },
    voidBats = {
    },
    mirrorLines = {
    },
    airWalls = {
        {x = 42, y = 30},
    },
    spawnPlatform = {x = 0, y = 34, width = 107},
}

levels[4] = {
    stencilFile = "maps/level_4_stencil.png",
    textureFile = "maps/level_4_texture.png",
    playerStart = {x = 30, y = 48},
    platformXMin = 12,
    platformXMax = 36,
    bats = {
        {x = 30, y = 114, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 78, y = 60, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 72, y = 150, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 54, y = 132, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
    },
    voidBats = {
    },
    mirrorLines = {
    },
    airWalls = {
        {x = 42, y = 48},
        {x = 6, y = 48},
    },
    spawnPlatform = {x = 12, y = 52, width = 24},
}

levels[5] = {
    stencilFile = "maps/level_5_stencil.png",
    textureFile = "maps/level_5_texture.png",
    playerStart = {x = 18, y = 18},
    platformXMin = 0,
    platformXMax = 36,
    bats = {
        {x = 30, y = 138, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 54, y = 138, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 78, y = 138, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
    },
    voidBats = {
    },
    mirrorLines = {
    },
    airWalls = {
        {x = 42, y = 18},
    },
    spawnPlatform = {x = 0, y = 22, width = 36},
}

levels[6] = {
    stencilFile = "maps/level_6_stencil.png",
    textureFile = "maps/level_6_texture.png",
    playerStart = {x = 18, y = 30},
    platformXMin = 0,
    platformXMax = 48,
    bats = {
        {x = 66, y = 90, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 90, y = 90, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 18, y = 138, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 42, y = 150, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 66, y = 150, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 90, y = 174, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
    },
    voidBats = {
    },
    mirrorLines = {
    },
    airWalls = {
        {x = 54, y = 30},
    },
    spawnPlatform = {x = 0, y = 34, width = 48},
}

levels[7] = {
    stencilFile = "maps/level_7_stencil.png",
    textureFile = "maps/level_7_texture.png",
    playerStart = {x = 18, y = 30},
    platformXMin = 0,
    platformXMax = 24,
    bats = {
        {x = 42, y = 54, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 66, y = 54, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 90, y = 126, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 54, y = 126, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 84, y = 168, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 24, y = 132, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
    },
    voidBats = {
    },
    mirrorLines = {
    },
    airWalls = {
        {x = 30, y = 36},
        {x = 30, y = 24},
    },
    spawnPlatform = {x = 0, y = 34, width = 24},
}

levels[8] = {
    stencilFile = "maps/level_8_stencil.png",
    textureFile = "maps/level_8_texture.png",
    playerStart = {x = 54, y = 42},
    platformXMin = 0,
    platformXMax = 107,
    bats = {
        {x = 90, y = 54, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 18, y = 78, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 30, y = 174, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 78, y = 174, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 66, y = 42, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
    },
    voidBats = {
    },
    mirrorLines = {
    },
    airWalls = {
    },
    spawnPlatform = {x = 0, y = 46, width = 107},
}

levels[9] = {
    stencilFile = "maps/level_9_stencil.png",
    textureFile = "maps/level_9_texture.png",
    playerStart = {x = 18, y = 66},
    platformXMin = 0,
    platformXMax = 36,
    bats = {
        {x = 60, y = 78, moveDir = "HORIZONTAL", moveDist = 48, moveSpeed = 0.3, moveStartDir = -1},
        {x = 60, y = 108, moveDir = "HORIZONTAL", moveDist = 48, moveSpeed = 0.3, moveStartDir = 1},
        {x = 78, y = 126, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
    },
    voidBats = {
    },
    mirrorLines = {
    },
    airWalls = {
        {x = 42, y = 66},
    },
    spawnPlatform = {x = 0, y = 70, width = 36},
}

levels[10] = {
    stencilFile = "maps/level_10_stencil.png",
    textureFile = "maps/level_10_texture.png",
    playerStart = {x = 42, y = 66},
    platformXMin = 36,
    platformXMax = 48,
    bats = {
        {x = 54, y = 102, moveDir = "HORIZONTAL", moveDist = 36, moveSpeed = 0.3, moveStartDir = -1},
        {x = 78, y = 126, moveDir = "VERTICAL", moveDist = 36, moveSpeed = 0.6, moveStartDir = 1},
    },
    voidBats = {
    },
    mirrorLines = {
    },
    airWalls = {
        {x = 54, y = 66},
        {x = 30, y = 66},
    },
    spawnPlatform = {x = 36, y = 70, width = 12},
}

levels[11] = {
    stencilFile = "maps/level_11_stencil.png",
    textureFile = "maps/level_11_texture.png",
    playerStart = {x = 54, y = 72},
    platformXMin = 48,
    platformXMax = 60,
    bats = {
        {x = 66, y = 84, moveDir = "VERTICAL", moveDist = 36, moveSpeed = 0.3, moveStartDir = -1},
        {x = 90, y = 84, moveDir = "VERTICAL", moveDist = 48, moveSpeed = 0.3, moveStartDir = 1},
        {x = 18, y = 84, moveDir = "VERTICAL", moveDist = 36, moveSpeed = 0.3, moveStartDir = -1},
        {x = 42, y = 84, moveDir = "VERTICAL", moveDist = 48, moveSpeed = 0.3, moveStartDir = 1},
    },
    voidBats = {
    },
    mirrorLines = {
    },
    airWalls = {
        {x = 42, y = 72},
        {x = 66, y = 72},
    },
    spawnPlatform = {x = 48, y = 76, width = 12},
}

levels[12] = {
    stencilFile = "maps/level_12_stencil.png",
    textureFile = "maps/level_12_texture.png",
    playerStart = {x = 18, y = 66},
    platformXMin = 0,
    platformXMax = 24,
    bats = {
        {x = 18, y = 114, moveDir = "VERTICAL", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 60, y = 78, moveDir = "HORIZONTAL", moveDist = 36, moveSpeed = 0.3, moveStartDir = 1},
        {x = 60, y = 156, moveDir = "HORIZONTAL", moveDist = 36, moveSpeed = 0.3, moveStartDir = -1},
        {x = 60, y = 180, moveDir = "HORIZONTAL", moveDist = 36, moveSpeed = 0.3, moveStartDir = 1},
        {x = 48, y = 126, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
    },
    voidBats = {
    },
    mirrorLines = {
    },
    airWalls = {
        {x = 30, y = 66},
    },
    spawnPlatform = {x = 0, y = 70, width = 24},
}

levels[13] = {
    stencilFile = "maps/level_13_stencil.png",
    textureFile = "maps/level_13_texture.png",
    playerStart = {x = 30, y = 42},
    platformXMin = 0,
    platformXMax = 36,
    bats = {
        {x = 84, y = 72, moveDir = "HORIZONTAL", moveDist = 24, moveSpeed = 0.3, moveStartDir = -1},
        {x = 48, y = 72, moveDir = "VERTICAL", moveDist = 36, moveSpeed = 0.3, moveStartDir = 1},
        {x = 66, y = 114, moveDir = "HORIZONTAL", moveDist = 24, moveSpeed = 0.6, moveStartDir = -1},
        {x = 78, y = 186, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
    },
    voidBats = {
    },
    mirrorLines = {
    },
    airWalls = {
        {x = 42, y = 42},
    },
    spawnPlatform = {x = 0, y = 46, width = 36},
}

levels[14] = {
    stencilFile = "maps/level_14_stencil.png",
    textureFile = "maps/level_14_texture.png",
    playerStart = {x = 30, y = 90},
    platformXMin = 0,
    platformXMax = 48,
    bats = {
        {x = 60, y = 102, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 96, y = 102, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
    },
    voidBats = {
        {x = 78, y = 126, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
        {x = 42, y = 126, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
    },
    mirrorLines = {
    },
    airWalls = {
        {x = 54, y = 90},
    },
    spawnPlatform = {x = 0, y = 94, width = 48},
}

levels[15] = {
    stencilFile = "maps/level_15_stencil.png",
    textureFile = "maps/level_15_texture.png",
    playerStart = {x = 30, y = 90},
    platformXMin = 0,
    platformXMax = 48,
    bats = {
        {x = 60, y = 102, moveDir = "NONE", moveDist = 24, moveSpeed = 0.3, moveStartDir = 1},
        {x = 96, y = 102, moveDir = "HORIZONTAL", moveDist = 24, moveSpeed = 0.3, moveStartDir = -1},
    },
    voidBats = {
        {x = 78, y = 126, moveDir = "HORIZONTAL", moveDist = 36, moveSpeed = 0.3, moveStartDir = 1},
        {x = 42, y = 126, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
    },
    mirrorLines = {
    },
    airWalls = {
        {x = 54, y = 90},
    },
    spawnPlatform = {x = 0, y = 94, width = 48},
}

levels[16] = {
    stencilFile = "maps/level_16_stencil.png",
    textureFile = "maps/level_16_texture.png",
    playerStart = {x = 6, y = 66},
    platformXMin = 0,
    platformXMax = 12,
    bats = {
        {x = 54, y = 144, moveDir = "VERTICAL", moveDist = 36, moveSpeed = 0.3, moveStartDir = -1},
        {x = 18, y = 126, moveDir = "HORIZONTAL", moveDist = 36, moveSpeed = 0.3, moveStartDir = 1},
        {x = 90, y = 126, moveDir = "HORIZONTAL", moveDist = 36, moveSpeed = 0.6, moveStartDir = 1},
    },
    voidBats = {
        {x = 12, y = 168, moveDir = "HORIZONTAL", moveDist = 24, moveSpeed = 0.3, moveStartDir = 1},
        {x = 36, y = 155, moveDir = "VERTICAL", moveDist = 12, moveSpeed = 0.3, moveStartDir = 1},
    },
    mirrorLines = {
    },
    airWalls = {
        {x = 18, y = 66},
    },
    spawnPlatform = {x = 0, y = 70, width = 12},
}

levels[17] = {
    stencilFile = "maps/level_17_stencil.png",
    textureFile = "maps/level_17_texture.png",
    playerStart = {x = 54, y = 66},
    platformXMin = 48,
    platformXMax = 60,
    bats = {
        {x = 72, y = 90, moveDir = "VERTICAL", moveDist = 48, moveSpeed = 0.3, moveStartDir = 1},
        {x = 84, y = 90, moveDir = "VERTICAL", moveDist = 48, moveSpeed = 0.3, moveStartDir = 1},
        {x = 36, y = 90, moveDir = "VERTICAL", moveDist = 48, moveSpeed = 0.3, moveStartDir = 1},
        {x = 24, y = 90, moveDir = "VERTICAL", moveDist = 48, moveSpeed = 0.3, moveStartDir = 1},
    },
    voidBats = {
        {x = 54, y = 108, moveDir = "NONE", moveDist = 24, moveSpeed = 0.6, moveStartDir = 1},
    },
    mirrorLines = {
    },
    airWalls = {
        {x = 66, y = 66},
        {x = 42, y = 66},
    },
    spawnPlatform = {x = 48, y = 70, width = 12},
}

return levels
