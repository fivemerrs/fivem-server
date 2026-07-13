Config = {}

-- Grove Street redzone (PvP)
Config.Zones = {
    {
        coords = vector3(106.75, -1941.19, 20.8),
        radius = 100.0
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
