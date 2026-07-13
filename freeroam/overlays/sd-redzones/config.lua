Config = {}

-- Mid-range redzone ~300m south of Legion (Mission Row / downtown)
-- Green spawn: 222.20, -864.02 | Red: 58.50, -1115.00 (~306m)
Config.Zones = {
    {
        coords = vector3(58.50, -1115.00, 29.40),
        radius = 80.0
    },
}

Config.LoadoutItems = {
    "WEAPON_CARBINERIFLE",
    "WEAPON_PISTOL",
    "ammo-rifle",
    "ammo-9",
}

Config.Rewards = {
    Money = {100, 500}
}

Config.CoreNames = {
    QBCore = 'qb-core',
    ESX = 'es_extended',
}

Config.InvName = {
    OX = 'ox_inventory'
}

Framework = 'esx'
if GetResourceState(Config.CoreNames.QBCore) == 'started' then
    Framework = 'qb'
elseif GetResourceState(Config.CoreNames.ESX) ~= 'missing' then
    Framework = 'esx'
end
invState = GetResourceState(Config.InvName.OX)
