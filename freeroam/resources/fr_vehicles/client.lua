local lastVeh = 0
local selected = Config.DefaultModel

local function normalize(name)
    return (name or ''):lower():gsub('%s+', '')
end

local function isAllowed(model)
    model = normalize(model)
    for _, m in ipairs(Config.AllowedModels) do
        if normalize(m) == model then return true end
    end
    return false
end

local function applyPreset(veh, model)
    local preset = Config.Presets[model]
    if not preset then return end

    SetVehicleModKit(veh, 0)

    if preset.wheelType then
        SetVehicleWheelType(veh, preset.wheelType)
    end

    if preset.customPrimary then
        local r, g, b = table.unpack(preset.customPrimary)
        SetVehicleCustomPrimaryColour(veh, r, g, b)
    end
    if preset.secondary then
        local _, sec = GetVehicleColours(veh)
        SetVehicleColours(veh, 0, preset.secondary)
    end
    if preset.pearl or preset.rim then
        SetVehicleExtraColours(veh, preset.pearl or 0, preset.rim or 0)
    end

    if preset.plate then
        SetVehicleNumberPlateText(veh, preset.plate)
    end
    if preset.plateIndex then
        SetVehicleNumberPlateTextIndex(veh, preset.plateIndex)
    end

    for modType, modIndex in pairs(preset.mods or {}) do
        SetVehicleMod(veh, modType, modIndex, false)
    end
    for modType, enabled in pairs(preset.toggles or {}) do
        ToggleVehicleMod(veh, modType, enabled)
    end
end

local function spawnSelected()
    local model = normalize(selected)
    if model == '' then model = Config.DefaultModel end
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        lib.notify({ title = 'F3 Car', description = ('Model %s not available'):format(model), type = 'error' })
        return
    end

    lib.requestModel(hash, 5000)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    if lastVeh ~= 0 and DoesEntityExist(lastVeh) then
        SetEntityAsMissionEntity(lastVeh, true, true)
        DeleteVehicle(lastVeh)
        DeleteEntity(lastVeh)
        lastVeh = 0
    end

    local veh = CreateVehicle(hash, coords.x + 2.0, coords.y, coords.z, heading, true, false)
    SetVehicleOnGroundProperly(veh)
    SetPedIntoVehicle(ped, veh, -1)
    SetVehicleEngineOn(veh, true, true, false)
    SetEntityAsMissionEntity(veh, true, true)
    applyPreset(veh, model)
    if not Config.Presets[model] or not Config.Presets[model].plate then
        SetVehicleNumberPlateText(veh, 'FREEROAM')
    end
    lastVeh = veh
    SetModelAsNoLongerNeeded(hash)

    local label = model == 'dukes' and "Dom's Charger (dukes)" or model
    lib.notify({ title = 'F3 Car', description = ('Spawned %s'):format(label), type = 'success' })
end

RegisterCommand('fr_spawncar', function()
    spawnSelected()
end, false)

RegisterKeyMapping('fr_spawncar', 'Spawn Fast1 freeroam car', 'keyboard', 'F3')

RegisterCommand('f3car', function(_, args)
    local model = normalize(args[1] or '')
    if model == '' then
        lib.notify({
            title = 'F3 Car',
            description = ('Current: %s — /f3car dukes|penumbra|jester|…'):format(selected),
            type = 'inform',
        })
        return
    end
    if not isAllowed(model) then
        lib.notify({ title = 'F3 Car', description = 'Model not in Fast1 lore list', type = 'error' })
        return
    end
    selected = model
    lib.notify({ title = 'F3 Car', description = ('Selected %s (press F3)'):format(selected), type = 'success' })
end, false)
