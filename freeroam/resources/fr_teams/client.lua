--[[
  Minimal freeroam teams (custom, lightweight).
  Commands: /team create|join|leave|menu
  - No friendly fire between teammates
  - Map blips for teammates
]]

local myTeam = nil
local members = {} -- serverId -> name
local blips = {}

local function clearBlips()
    for id, blip in pairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        blips[id] = nil
    end
end

RegisterNetEvent('fr_teams:sync', function(teamName, memberList)
    myTeam = teamName
    members = {}
    clearBlips()
    if not teamName then return end
    for _, m in ipairs(memberList or {}) do
        members[m.id] = m.name
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        if not myTeam then
            clearBlips()
        else
            local myId = GetPlayerServerId(PlayerId())
            for sid, name in pairs(members) do
                if sid ~= myId then
                    local player = GetPlayerFromServerId(sid)
                    if player ~= -1 then
                        local ped = GetPlayerPed(player)
                        if DoesEntityExist(ped) then
                            if not blips[sid] or not DoesBlipExist(blips[sid]) then
                                local b = AddBlipForEntity(ped)
                                SetBlipSprite(b, 1)
                                SetBlipColour(b, 3)
                                SetBlipScale(b, 0.75)
                                SetBlipAsShortRange(b, false)
                                BeginTextCommandSetBlipName('STRING')
                                AddTextComponentString(('Team: %s'):format(name))
                                EndTextCommandSetBlipName(b)
                                blips[sid] = b
                            end
                        end
                    elseif blips[sid] then
                        if DoesBlipExist(blips[sid]) then RemoveBlip(blips[sid]) end
                        blips[sid] = nil
                    end
                end
            end
        end
    end
end)

-- Friendly fire: server cancels teammate damage (weaponDamageEvent).
-- Client still softens local targeting for teammates.
CreateThread(function()
    while true do
        Wait(500)
        if myTeam then
            local myPed = PlayerPedId()
            for sid, _ in pairs(members) do
                local player = GetPlayerFromServerId(sid)
                if player ~= -1 and player ~= PlayerId() then
                    local ped = GetPlayerPed(player)
                    SetCanAttackFriendly(myPed, false, false)
                    SetCanAttackFriendly(ped, false, false)
                end
            end
        end
    end
end)

local function openMenu()
    local options = {
        { title = 'Create team', description = 'Become leader of a new team', icon = 'plus',
          onSelect = function()
              local input = lib.inputDialog('Create team', { { type = 'input', label = 'Team name', required = true, max = 16 } })
              if input and input[1] then TriggerServerEvent('fr_teams:create', input[1]) end
          end },
        { title = 'Join team', description = 'Join by exact name', icon = 'right-to-bracket',
          onSelect = function()
              local input = lib.inputDialog('Join team', { { type = 'input', label = 'Team name', required = true, max = 16 } })
              if input and input[1] then TriggerServerEvent('fr_teams:join', input[1]) end
          end },
        { title = 'Leave team', icon = 'right-from-bracket',
          onSelect = function() TriggerServerEvent('fr_teams:leave') end },
    }
    if myTeam then
        table.insert(options, 1, { title = ('Current: %s'):format(myTeam), disabled = true, icon = 'users' })
    end
    lib.registerContext({ id = 'fr_teams_menu', title = 'Freeroam Teams', options = options })
    lib.showContext('fr_teams_menu')
end

RegisterCommand('team', function(_, args)
    local sub = (args[1] or 'menu'):lower()
    if sub == 'menu' then
        openMenu()
    elseif sub == 'create' and args[2] then
        TriggerServerEvent('fr_teams:create', args[2])
    elseif sub == 'join' and args[2] then
        TriggerServerEvent('fr_teams:join', args[2])
    elseif sub == 'leave' then
        TriggerServerEvent('fr_teams:leave')
    else
        openMenu()
    end
end, false)

RegisterKeyMapping('team', 'Open teams menu', 'keyboard', 'F6')
