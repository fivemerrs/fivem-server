Config = {}

Config.EnableNotifications = true
Config.GreenzonesCommand = 'setzone'
Config.GreenzonesClearCommand = 'clearzone'

-- Legion Square safe spawn (matches ESX DefaultSpawns)
Config.GreenZones = {
    ['spawn'] = {
        coords = vec3(222.2027, -864.0162, 30.2922),
        radius = 80.0,
        disablePlayerVehicleCollision = false,
        enableSpeedLimits = false,
        setSpeedLimit = 30,
        removeWeapons = true,
        disableFiring = true,
        setInvincible = true,
        displayTextUI = true,
        textToDisplay = 'Safe Zone — Spawn Hub',
        backgroundColorTextUI = '#2ecc71',
        textColor = '#ffffff',
        displayTextPosition = 'top-center',
        displayTextIcon = 'shield-halved',
        blip = true,
        blipType = 'radius',
        enableSprite = true,
        blipSprite = 487,
        blipColor = 2,
        blipScale = 0.8,
        blipAlpha = 80,
    },
}
