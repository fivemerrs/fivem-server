-- Disable ambient NPC peds and traffic vehicles everywhere.
CreateThread(function()
    while true do
        SetPedDensityMultiplierThisFrame(0.0)
        SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)
        SetVehicleDensityMultiplierThisFrame(0.0)
        SetRandomVehicleDensityMultiplierThisFrame(0.0)
        SetParkedVehicleDensityMultiplierThisFrame(0.0)
        SetGarbageTrucks(false)
        SetRandomBoats(false)
        SetCreateRandomCops(false)
        SetCreateRandomCopsNotOnScenarios(false)
        SetCreateRandomCopsOnScenarios(false)
        Wait(0)
    end
end)

CreateThread(function()
    -- Clear existing ambient entities periodically near player
    while true do
        local player = PlayerPedId()
        local coords = GetEntityCoords(player)
        ClearAreaOfPeds(coords.x, coords.y, coords.z, 200.0, 1)
        ClearAreaOfVehicles(coords.x, coords.y, coords.z, 200.0, false, false, false, false, false)
        Wait(5000)
    end
end)
