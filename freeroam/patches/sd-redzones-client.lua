-- Patched client for ESX freeroam (no qb-ambulancejob)
local zones = {}

CreateThread(function()
    for zoneId, zoneData in ipairs(Config.Zones) do
        local zone = lib.zones.sphere({
            coords = zoneData.coords,
            radius = zoneData.radius,
            debug = false,
            onEnter = function()
                TriggerServerEvent('sd-redzones:server:addLoadout', zoneId)
            end,
            onExit = function()
                TriggerServerEvent('sd-redzones:server:removeLoadout', zoneId)
            end
        })

        local blip = AddBlipForRadius(zoneData.coords.x, zoneData.coords.y, zoneData.coords.z, zoneData.radius)
        SetBlipColour(blip, 1)
        SetBlipAlpha(blip, 100)

        local center = AddBlipForCoord(zoneData.coords.x, zoneData.coords.y, zoneData.coords.z)
        SetBlipSprite(center, 84)
        SetBlipScale(center, 0.8)
        SetBlipColour(center, 1)
        SetBlipAsShortRange(center, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Redzone')
        EndTextCommandSetBlipName(center)

        zones[#zones + 1] = zone
    end
end)

RegisterNetEvent('sd-redzones:client:handleDeath', function(nearestPoint)
    local player = PlayerPedId()
    DoScreenFadeOut(1000)
    Wait(1000)

    NetworkResurrectLocalPlayer(nearestPoint.x, nearestPoint.y, nearestPoint.z, 0.0, true, false)
    SetEntityCoords(PlayerPedId(), nearestPoint.x, nearestPoint.y, nearestPoint.z, false, false, false, false)
    SetEntityMaxHealth(PlayerPedId(), 200)
    SetEntityHealth(PlayerPedId(), 200)
    ClearPedBloodDamage(PlayerPedId())
    SetPlayerSprint(PlayerId(), true)

    -- ESX / freeroam revive (no qb-ambulancejob)
    TriggerEvent('esx_ambulancejob:revive')
    if LocalPlayer and LocalPlayer.state then
        LocalPlayer.state:set('dead', false, true)
        LocalPlayer.state:set('isDead', false, true)
    end

    Wait(500)
    DoScreenFadeIn(1000)
end)
