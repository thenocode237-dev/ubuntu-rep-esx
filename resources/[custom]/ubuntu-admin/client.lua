local isOpen = false
local spectating = false
local spectateReturn = nil

-- --- Ouverture du panel (gated côté serveur) --------------------------------

local function openPanel()
    if isOpen then return end
    local res = lib.callback.await('ubuntu-admin:server:getPlayers', false)
    if not res or not res.allowed then
        return lib.notify({ description = Lang:t('error.no_permission'), type = 'error' })
    end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        players = res.players,
        jobs = res.jobs,
        moneyTypes = res.moneyTypes,
    })
end

local function closePanel()
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterCommand(Config.OpenCommand, function() openPanel() end, false)
RegisterKeyMapping(Config.OpenCommand, 'Ouvrir le panel de gestion (staff)', 'keyboard', Config.DefaultKey)

-- --- Callbacks NUI ----------------------------------------------------------

RegisterNUICallback('refresh', function(_, cb)
    local res = lib.callback.await('ubuntu-admin:server:getPlayers', false)
    cb(res or { allowed = false, players = {} })
end)

RegisterNUICallback('action', function(data, cb)
    if data and data.action then
        TriggerServerEvent('ubuntu-admin:server:action', data.action, data.targetId, data.args or {})
    end
    cb('ok')
end)

RegisterNUICallback('close', function(_, cb)
    closePanel()
    cb('ok')
end)

-- --- Effets locaux déclenchés par le serveur (autoritaire) ------------------

RegisterNetEvent('ubuntu-admin:client:revive', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    SetPlayerSprint(PlayerId(), true)
    lib.notify({ description = Lang:t('success.you_revived'), type = 'success' })
end)

RegisterNetEvent('ubuntu-admin:client:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    lib.notify({ description = Lang:t('success.you_healed'), type = 'success' })
end)

RegisterNetEvent('ubuntu-admin:client:freeze', function(state)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, state)
    lib.notify({ description = state and Lang:t('success.you_frozen') or Lang:t('success.you_unfrozen'), type = 'inform' })
end)

RegisterNetEvent('ubuntu-admin:client:teleport', function(coords)
    local ped = PlayerPedId()
    SetPedCoordsKeepVehicle(ped, coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
end)

RegisterNetEvent('ubuntu-admin:client:announce', function(msg)
    lib.notify({ title = 'ANNONCE', description = msg, type = 'inform', duration = 8000 })
    TriggerEvent('chat:addMessage', {
        color = { 91, 76, 240 },
        multiline = true,
        args = { 'ANNONCE', msg },
    })
end)

-- Spectate basique : suit la cible en observateur invisible ; retap pour sortir.
RegisterNetEvent('ubuntu-admin:client:spectate', function(_, coords)
    local ped = PlayerPedId()
    if not spectating then
        spectateReturn = GetEntityCoords(ped)
        spectating = true
        SetEntityVisible(ped, false, false)
        SetEntityInvincible(ped, true)
        FreezeEntityPosition(ped, true)
        SetEntityCoords(ped, coords.x + 0.0, coords.y + 0.0, coords.z + 5.0, false, false, false, false)
        lib.notify({ description = Lang:t('success.spectate_on'), type = 'inform' })
    else
        spectating = false
        SetEntityVisible(ped, true, false)
        SetEntityInvincible(ped, false)
        FreezeEntityPosition(ped, false)
        if spectateReturn then
            SetEntityCoords(ped, spectateReturn.x, spectateReturn.y, spectateReturn.z, false, false, false, false)
        end
        lib.notify({ description = Lang:t('success.spectate_off'), type = 'inform' })
    end
end)
