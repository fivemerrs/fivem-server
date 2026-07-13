Config = {}

local txAdminLocale = GetConvar("txAdmin-locale", "en")
local esxLocale = GetConvar("esx:locale", "invalid")
Config.Locale = (esxLocale ~= "invalid") and esxLocale or (txAdminLocale ~= "custom" and txAdminLocale) or "en"

Config.CustomInventory = false

Config.Accounts = {
    bank = {
        label = TranslateCap("account_bank"),
        round = true,
    },
    black_money = {
        label = TranslateCap("account_black_money"),
        round = true,
    },
    money = {
        label = TranslateCap("account_money"),
        round = true,
    },
}

-- Freeroam starter: $50,000 cash
Config.StartingAccountMoney = { money = 50000, bank = 0 }

-- Starter pistols + ammo (ox_inventory item names)
Config.StartingInventoryItems = {
    { name = 'WEAPON_PISTOL', count = 1 },
    { name = 'WEAPON_COMBATPISTOL', count = 1 },
    { name = 'WEAPON_PISTOL_MK2', count = 1 },
    { name = 'ammo-9', count = 300 },
}

Config.DefaultSpawns = {
    { x = 222.2027, y = -864.0162, z = 30.2922, heading = 1.0 },
}

Config.AdminGroups = {
    ["owner"] = true,
    ["admin"] = true,
}

Config.ValidCharacterSets = {
    ['el'] = false,
    ['sr'] = false,
    ['he'] = false,
    ['ar'] = false,
    ['zh-cn'] = false
}

Config.EnablePaycheck = false
Config.LogPaycheck = false
Config.EnableSocietyPayouts = false
Config.MaxWeight = 60
Config.PaycheckInterval = 7 * 60000
Config.SaveDeathStatus = true
Config.EnableDebug = false

Config.DefaultJobDuty = true
Config.OffDutyPaycheckMultiplier = 0.5

Config.Multichar = GetResourceState("esx_multicharacter") ~= "missing"
Config.Identity = true
Config.DistanceGive = 4.0

Config.AdminLogging = false

-------------------------------------
-- DO NOT CHANGE BELOW THIS LINE !!!
-------------------------------------
if GetResourceState("ox_inventory") ~= "missing" then
    Config.CustomInventory = "ox"
end

Config.EnableDefaultInventory = Config.CustomInventory == false
Config.Identifier = GetConvar("esx:identifier", "license")
