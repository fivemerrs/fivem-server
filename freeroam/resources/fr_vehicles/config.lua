Config = {}

-- GTA5-Mods "Fast Furious 1 Lore Friendly" pack is Menyoo XML presets for VANILLA
-- vehicles (21KB zip) — NOT streamed .yft addons. F3 spawns Dom's Charger (dukes)
-- with the pack's FF1 Dukes.xml styling applied via natives.
-- Pack URL: https://www.gta5-mods.com/vehicles/fast-furious-1-lore-friendly-car-pack-diablo317

Config.DefaultModel = 'dukes' -- Dom's 1970 Charger stand-in (most iconic Fast 1)

Config.AllowedModels = {
    'dukes',     -- Dom's Charger (F3 default)
    'penumbra',  -- Brian's Eclipse
    'jester',    -- Orange Supra stand-in
    'remus',     -- Letty's Silvia stand-in
    'kanjo',     -- Silvia / Kanjo
    'rt3000',
    'intruder',
    'zr350',
    'astron',    -- ASP-ish
}

-- Applied when spawning dukes (from FF1 Dukes.xml)
Config.Presets = {
    dukes = {
        plate = '2JRI424',
        plateIndex = 4,
        wheelType = 1,
        customPrimary = { 8, 8, 8 },
        secondary = 120,
        pearl = 0,
        rim = 156,
        mods = {
            [1] = 2, [2] = 0, [4] = 0, [5] = 2, [6] = 2, [7] = 10,
            [9] = 0, [10] = 0, [11] = 3, [12] = 2, [13] = 2, [15] = 3, [16] = 4,
            [23] = 19,
        },
        toggles = {
            [18] = true, -- turbo
        },
    },
    penumbra = {
        plate = 'BRIAN',
        plateIndex = 0,
        mods = {},
        toggles = { [18] = true },
    },
    jester = {
        plate = 'SUPRA',
        plateIndex = 0,
        mods = {},
        toggles = { [18] = true },
    },
}
