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
        DeleteEntity(lastVeh)
        lastVeh = 0
    end

    local veh = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, true, false)
    SetPedIntoVehicle(ped, veh, -1)
    SetVehicleNumberPlateText(veh, 'FREEROAM')
    SetVehicleEngineOn(veh, true, true, false)
    SetEntityAsMissionEntity(veh, true, true)
    lastVeh = veh
    SetModelAsNoLongerNeeded(hash)
    lib.notify({ title = 'F3 Car', description = ('Spawned %s'):format(model), type = 'success' })
end

RegisterCommand('fr_spawncar', function()
    spawnSelected()
end, false)

RegisterKeyMapping('fr_spawncar', 'Spawn freeroam car', 'keyboard', 'F3')

RegisterCommand('f3car', function(_, args)
    local model = normalize(args[1] or '')
    if model == '' then
        lib.notify({ title = 'F3 Car', description = ('Current: %s — /f3car <model>'):format(selected), type = 'inform' })
        return
    end
    if not isAllowed(model) then
        lib.notify({ title = 'F3 Car', description = 'Model not in freeroam list', type = 'error' })
        return
    end
    selected = model
    lib.notify({ title = 'F3 Car', description = ('Selected %s (press F3)'):format(selected), type = 'success' })
end, false)
