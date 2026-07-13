local teams = {} -- name -> { leader = src, members = { [src] = name } }

local function teamList(name)
    local list = {}
    local t = teams[name]
    if not t then return list end
    for id, pname in pairs(t.members) do
        list[#list + 1] = { id = id, name = pname }
    end
    return list
end

local function syncTeam(name)
    local list = teamList(name)
    local t = teams[name]
    if not t then return end
    for id, _ in pairs(t.members) do
        TriggerClientEvent('fr_teams:sync', id, name, list)
    end
end

local function findPlayerTeam(src)
    for name, t in pairs(teams) do
        if t.members[src] then return name end
    end
    return nil
end

local function leave(src, silent)
    local name = findPlayerTeam(src)
    if not name then
        if not silent then
            TriggerClientEvent('ox_lib:notify', src, { title = 'Teams', description = 'Not in a team', type = 'error' })
        end
        return
    end
    local t = teams[name]
    t.members[src] = nil
    TriggerClientEvent('fr_teams:sync', src, nil, {})
    local count = 0
    for _ in pairs(t.members) do count = count + 1 end
    if count == 0 then
        teams[name] = nil
    else
        if t.leader == src then
            for id, _ in pairs(t.members) do
                t.leader = id
                break
            end
        end
        syncTeam(name)
    end
    if not silent then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Teams', description = ('Left %s'):format(name), type = 'inform' })
    end
end

RegisterNetEvent('fr_teams:create', function(rawName)
    local src = source
    local name = tostring(rawName or ''):gsub('%s+', ' '):sub(1, 16)
    if name == '' then return end
    if findPlayerTeam(src) then leave(src, true) end
    if teams[name] then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Teams', description = 'Name taken', type = 'error' })
        return
    end
    teams[name] = {
        leader = src,
        members = { [src] = GetPlayerName(src) },
    }
    syncTeam(name)
    TriggerClientEvent('ox_lib:notify', src, { title = 'Teams', description = ('Created %s'):format(name), type = 'success' })
end)

RegisterNetEvent('fr_teams:join', function(rawName)
    local src = source
    local name = tostring(rawName or ''):gsub('%s+', ' '):sub(1, 16)
    local t = teams[name]
    if not t then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Teams', description = 'Team not found', type = 'error' })
        return
    end
    if findPlayerTeam(src) then leave(src, true) end
    t.members[src] = GetPlayerName(src)
    syncTeam(name)
    TriggerClientEvent('ox_lib:notify', src, { title = 'Teams', description = ('Joined %s'):format(name), type = 'success' })
end)

RegisterNetEvent('fr_teams:leave', function()
    leave(source, false)
end)

AddEventHandler('playerDropped', function()
    leave(source, true)
end)

-- Cancel PvP damage between teammates (server-authoritative)
AddEventHandler('weaponDamageEvent', function(sender, data)
    local attacker = sender
    if type(data) ~= 'table' then return end
    local netId = data.hitGlobalId
    if not netId then return end
    local victimPed = NetworkGetEntityFromNetworkId(netId)
    if victimPed == 0 or not DoesEntityExist(victimPed) then return end
    if not IsPedAPlayer(victimPed) then return end
    local victim = NetworkGetEntityOwner(victimPed)
    if not victim or victim <= 0 or victim == attacker then return end
    local aTeam = findPlayerTeam(attacker)
    local vTeam = findPlayerTeam(victim)
    if aTeam and vTeam and aTeam == vTeam then
        CancelEvent()
    end
end)

print('^2[fr_teams]^7 loaded — /team or F6')
