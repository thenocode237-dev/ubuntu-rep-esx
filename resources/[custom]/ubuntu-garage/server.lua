local ESX = exports['es_extended']:getSharedObject()

-- Garage personnel — 100 % serveur-authoritative. Le client envoie une plaque /
-- une intention ; le serveur valide la possession dans `owned_vehicles` et pilote
-- le spawn (ESX.OneSync) ou le rangement (flag `stored`).

local lastAction = {} -- [src] = timestamp ms (anti-spam)
local Spawned = {}     -- [plate] = { owner = identifier, net = netId } : véhicules sortis suivis (GPS/verrou)

local function notify(src, key, vars, kind)
    TriggerClientEvent('ox_lib:notify', src, { description = Lang:t(key, vars), type = kind or 'inform' })
end

-- Le joueur possède-t-il ce véhicule ? (owned_vehicles)
local function ownsPlate(identifier, plate)
    return MySQL.scalar.await(
        'SELECT 1 FROM owned_vehicles WHERE owner = ? AND plate = ? LIMIT 1',
        { identifier, plate }) ~= nil
end

local function throttled(src)
    local now = os.clock() * 1000
    if (now - (lastAction[src] or 0)) < 600 then return true end
    lastAction[src] = now
    return false
end

-- Point de spawn d'un garage (Config partagé, dispo côté serveur).
local function spawnPointFor(garageId)
    for _, g in ipairs(Config.Garages) do
        if g.id == garageId then return g.spawn end
    end
    return Config.Garages[1] and Config.Garages[1].spawn
end

local function normalizePlate(plate)
    return (plate or ''):gsub('%s+$', '')
end

-- --- Liste des véhicules rangés du joueur -----------------------------------

lib.callback.register('ubuntu-garage:server:list', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {} end
    local rows = MySQL.query.await(
        'SELECT plate, vehicle, type FROM owned_vehicles WHERE owner = ? AND stored = 1 ORDER BY plate',
        { xPlayer.identifier }) or {}
    local list = {}
    for _, r in ipairs(rows) do
        local props = r.vehicle and json.decode(r.vehicle) or {}
        list[#list + 1] = { plate = normalizePlate(r.plate), type = r.type or 'car', model = props.model }
    end
    return list
end)

-- --- Sortir un véhicule ------------------------------------------------------

RegisterNetEvent('ubuntu-garage:server:spawn', function(rawPlate, garageId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if throttled(src) then return notify(src, 'error.too_fast', nil, 'error') end
    if type(rawPlate) ~= 'string' then return end
    local plate = normalizePlate(rawPlate)

    local row = MySQL.single.await(
        'SELECT vehicle, stored FROM owned_vehicles WHERE owner = ? AND plate = ? LIMIT 1',
        { xPlayer.identifier, plate })
    if not row then return notify(src, 'error.not_yours', nil, 'error') end
    if tonumber(row.stored) ~= 1 then return notify(src, 'error.already_out', nil, 'error') end

    local props = row.vehicle and json.decode(row.vehicle) or {}
    local model = props.model
    if type(model) ~= 'number' then model = joaat(tostring(model or 'adder')) end

    local sp = spawnPointFor(garageId)
    if not sp then return notify(src, 'error.spawn_failed', nil, 'error') end

    ESX.OneSync.SpawnVehicle(model, vector3(sp.x, sp.y, sp.z), sp.w, { plate = plate }, function(netId)
        if not netId then return notify(src, 'error.spawn_failed', nil, 'error') end
        MySQL.update.await('UPDATE owned_vehicles SET stored = 0 WHERE plate = ?', { plate })
        Spawned[plate] = { owner = xPlayer.identifier, net = netId } -- suivi GPS / verrou
        TriggerClientEvent('ubuntu-garage:client:enterVehicle', src, netId)
        notify(src, 'success.spawned', { plate = plate }, 'success')
    end)
end)

-- --- Ranger un véhicule ------------------------------------------------------

RegisterNetEvent('ubuntu-garage:server:store', function(rawPlate)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if throttled(src) then return notify(src, 'error.too_fast', nil, 'error') end
    if type(rawPlate) ~= 'string' then return end
    local plate = normalizePlate(rawPlate)

    local row = MySQL.single.await(
        'SELECT stored FROM owned_vehicles WHERE owner = ? AND plate = ? LIMIT 1',
        { xPlayer.identifier, plate })
    if not row then return notify(src, 'error.not_yours', nil, 'error') end
    if tonumber(row.stored) == 1 then return end -- déjà rangé

    MySQL.update.await('UPDATE owned_vehicles SET stored = 1 WHERE plate = ?', { plate })
    Spawned[plate] = nil
    TriggerClientEvent('ubuntu-garage:client:deleteVehicle', src, plate)
    notify(src, 'success.stored', { plate = plate }, 'success')
end)

-- --- Clés (owned_vehicles) : liste des plaques du joueur --------------------
-- Sert au client à détecter, à l'entrée d'un véhicule, s'il lui appartient
-- (pour le suivre GPS / autoriser le verrou) sans requête à chaque véhicule.
lib.callback.register('ubuntu-garage:server:myPlates', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {} end
    local rows = MySQL.query.await('SELECT plate FROM owned_vehicles WHERE owner = ?', { xPlayer.identifier }) or {}
    local plates = {}
    for _, r in ipairs(rows) do plates[normalizePlate(r.plate)] = true end
    return plates
end)

-- Enregistre un véhicule possédé où le joueur monte (pour GPS + verrou).
RegisterNetEvent('ubuntu-garage:server:register', function(netId, rawPlate)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or type(rawPlate) ~= 'string' or type(netId) ~= 'number' then return end
    local plate = normalizePlate(rawPlate)
    if not ownsPlate(xPlayer.identifier, plate) then return end
    Spawned[plate] = { owner = xPlayer.identifier, net = netId }
end)

-- --- Verrouillage / déverrouillage (anti-vol) -------------------------------
-- Porté par un statebag d'entité (réplicable) : tous les clients l'appliquent.
RegisterNetEvent('ubuntu-garage:server:toggleLock', function(netId, rawPlate)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or type(rawPlate) ~= 'string' or type(netId) ~= 'number' then return end
    if throttled(src) then return end
    local plate = normalizePlate(rawPlate)
    if not ownsPlate(xPlayer.identifier, plate) then
        return notify(src, 'error.not_yours', nil, 'error')
    end

    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then
        return notify(src, 'error.no_vehicle_near', nil, 'error')
    end

    Spawned[plate] = { owner = xPlayer.identifier, net = netId }
    local locked = not (Entity(ent).state.ubuntuLock or false)
    Entity(ent).state:set('ubuntuLock', locked, true) -- réplicable → tous les clients
    TriggerClientEvent('ubuntu-garage:client:lockFeedback', src, netId, locked)
    notify(src, locked and 'success.locked' or 'success.unlocked', nil, locked and 'inform' or 'success')
end)

-- --- GPS : positions des véhicules sortis du joueur -------------------------
lib.callback.register('ubuntu-garage:server:myVehicles', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {} end
    local id = xPlayer.identifier
    local out = {}
    for plate, info in pairs(Spawned) do
        if info.owner == id then
            local ent = NetworkGetEntityFromNetworkId(info.net)
            if ent and ent ~= 0 and DoesEntityExist(ent) then
                local c = GetEntityCoords(ent)
                out[#out + 1] = { plate = plate, x = c.x, y = c.y, z = c.z }
            else
                Spawned[plate] = nil -- purge des entités disparues
            end
        end
    end
    return out
end)

AddEventHandler('playerDropped', function()
    lastAction[source] = nil
end)
