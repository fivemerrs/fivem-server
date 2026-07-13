local Hub = {
    {
        id = 'clothes',
        model = `s_m_y_shop_mask`,
        coords = vec4(218.5, -861.0, 30.3, 250.0),
        label = '[E] Change clothes',
        action = 'clothes',
    },
    {
        id = 'armory',
        model = `s_m_y_ammucity_01`,
        coords = vec4(224.0, -858.5, 30.3, 160.0),
        label = '[E] Open gun shop (or use marker)',
        action = 'armory',
    },
    {
        id = 'supplies',
        model = `s_m_m_doctor_01`,
        coords = vec4(228.5, -856.0, 30.3, 160.0),
        label = '[E] Open supplies (or use marker)',
        action = 'supplies',
    },
}

local peds = {}

local function spawnPeds()
    for i, entry in ipairs(Hub) do
        lib.requestModel(entry.model, 5000)
        local ped = CreatePed(0, entry.model, entry.coords.x, entry.coords.y, entry.coords.z - 1.0, entry.coords.w, false, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        SetPedCanRagdoll(ped, false)
        peds[i] = { ped = ped, data = entry }
    end
end

CreateThread(function()
    spawnPeds()
    while true do
        local sleep = 1000
        local ply = PlayerPedId()
        local pcoords = GetEntityCoords(ply)
        local shown = false

        for _, entry in ipairs(peds) do
            local dist = #(pcoords - GetEntityCoords(entry.ped))
            if dist < 2.0 then
                sleep = 0
                if not shown then
                    lib.showTextUI(entry.data.label)
                    shown = true
                end
                if IsControlJustReleased(0, 38) then -- E
                    if entry.data.action == 'clothes' then
                        TriggerEvent('esx_skin:openSaveableMenu')
                    elseif entry.data.action == 'armory' then
                        exports.ox_inventory:openInventory('shop', { type = 'FreeroamArmory', id = 1 })
                    elseif entry.data.action == 'supplies' then
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

-- Usable item helpers registered via ox_inventory item client exports if wired
exports('useBandage', function(_, data)
    local ped = PlayerPedId()
    local health = GetEntityHealth(ped)
    local max = GetEntityMaxHealth(ped)
    SetEntityHealth(ped, math.min(max, health + 40))
    lib.notify({ title = 'Bandage', description = 'You feel a bit better.', type = 'success' })
end)

exports('useArmour', function(_, data)
    SetPedArmour(PlayerPedId(), 100)
    lib.notify({ title = 'Armour', description = 'Vest equipped.', type = 'success' })
end)
