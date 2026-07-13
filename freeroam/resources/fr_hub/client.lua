-- Marker-only hub (no visible shop peds). Ambient world NPCs handled by fr_world.
local Hub = {
    {
        coords = vec3(218.5, -861.0, 30.3),
        label = '[E] Change clothes',
        action = 'clothes',
        color = { 0, 200, 100 },
    },
    {
        coords = vec3(224.0, -858.5, 30.3),
        label = '[E] Gun shop',
        action = 'armory',
        color = { 200, 50, 50 },
    },
    {
        coords = vec3(228.5, -856.0, 30.3),
        label = '[E] Supplies',
        action = 'supplies',
        color = { 50, 120, 220 },
    },
}

CreateThread(function()
    while true do
        local sleep = 1000
        local ply = PlayerPedId()
        local pcoords = GetEntityCoords(ply)
        local shown = false

        for _, entry in ipairs(Hub) do
            local dist = #(pcoords - entry.coords)
            if dist < 25.0 then
                sleep = 0
                DrawMarker(
                    1,
                    entry.coords.x, entry.coords.y, entry.coords.z - 1.0,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    1.2, 1.2, 0.6,
                    entry.color[1], entry.color[2], entry.color[3], 160,
                    false, false, 2, false, nil, nil, false
                )
            end
            if dist < 1.8 then
                if not shown then
                    lib.showTextUI(entry.label)
                    shown = true
                end
                if IsControlJustReleased(0, 38) then
                    if entry.action == 'clothes' then
                        TriggerEvent('esx_skin:openSaveableMenu')
                    elseif entry.action == 'armory' then
                        exports.ox_inventory:openInventory('shop', { type = 'FreeroamArmory', id = 1 })
                    elseif entry.action == 'supplies' then
                        exports.ox_inventory:openInventory('shop', { type = 'FreeroamSupplies', id = 1 })
                    end
                end
            end
        end

        if not shown then
            lib.hideTextUI()
        end
        Wait(sleep)
    end
end)

exports('useBandage', function()
    local ped = PlayerPedId()
    local health = GetEntityHealth(ped)
    local max = GetEntityMaxHealth(ped)
    SetEntityHealth(ped, math.min(max, health + 40))
    lib.notify({ title = 'Bandage', description = 'You feel a bit better.', type = 'success' })
end)

exports('useArmour', function()
    SetPedArmour(PlayerPedId(), 100)
    lib.notify({ title = 'Armour', description = 'Vest equipped.', type = 'success' })
end)
