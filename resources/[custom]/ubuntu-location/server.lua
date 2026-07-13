local ESX = exports['es_extended']:getSharedObject()

-- Location de véhicules — logique serveur-authoritative. Le client n'envoie que
-- l'intention (louer un modèle à un point / restituer une plaque) ; les frais,
-- la caution et sa remise sont validés et appliqués ici.

-- Index des points par id (source de vérité serveur).
local Points = {}
for _, p in ipairs(Config.Points) do Points[p.id] = p end

-- Locations actives, indexées par plaque : { identifier, deposit, pointId }.
local Rentals = {}

local function formatMoney(amount)
    local s = tostring(math.floor(amount or 0))
    return '$' .. (s:reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^%s+', ''))
end

local function notify(src, key, data, kind)
    local oxType = kind
    if kind == 'primary' or kind == nil then oxType = 'inform' end
    TriggerClientEvent('ox_lib:notify', src, { description = Lang:t(key, data), type = oxType })
end

-- Plaque unique (charset alphanumérique majuscule).
local PLATE_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
local function generatePlate()
    local plate = {}
    for i = 1, 8 do
        local n = math.random(1, #PLATE_CHARS)
        plate[i] = PLATE_CHARS:sub(n, n)
    end
    return table.concat(plate)
end

local function findVehicle(point, model)
    for _, v in ipairs(point.vehicles) do
        if v.model == model then return v end
    end
    return nil
end

-- --- Louer -----------------------------------------------------------------
RegisterNetEvent('ubuntu-location:server:rent', function(pointId, model)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local point = Points[pointId]
    if not point then return end
    local veh = findVehicle(point, model)
    if not veh then return end

    local total = (veh.fee or 0) + (veh.deposit or 0)
    local acc = xPlayer.getAccount(Config.MoneyType)
    if not acc or acc.money < total then
        return notify(src, 'error.insufficient_funds', { amount = formatMoney(total) }, 'error')
    end
    xPlayer.removeAccountMoney(Config.MoneyType, total)

    local plate = generatePlate()
    Rentals[plate] = {
        identifier = xPlayer.identifier,
        deposit = veh.deposit or 0,
        pointId = pointId,
    }

    local s = point.spawn
    TriggerClientEvent('ubuntu-location:client:spawnRental', src, {
        model = veh.model,
        spawn = { x = s.x, y = s.y, z = s.z, w = s.w },
        plate = plate,
    })
    notify(src, 'success.rented', {
        label = veh.label,
        fee = formatMoney(veh.fee or 0),
        deposit = formatMoney(veh.deposit or 0),
    }, 'success')
    print(('[ubuntu-location] %s loue %s (%s) à %s'):format(xPlayer.identifier, veh.model, plate, pointId))
end)

-- --- Restituer (rembourse la caution) --------------------------------------
RegisterNetEvent('ubuntu-location:server:return', function(plate)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if type(plate) ~= 'string' then return end

    local rental = Rentals[plate]
    if not rental or rental.identifier ~= xPlayer.identifier then
        return notify(src, 'error.not_your_rental', nil, 'error')
    end

    xPlayer.addAccountMoney(Config.MoneyType, rental.deposit)
    Rentals[plate] = nil
    notify(src, 'success.returned', { deposit = formatMoney(rental.deposit) }, 'success')
    print(('[ubuntu-location] %s restitue %s (+%d caution)'):format(xPlayer.identifier, plate, rental.deposit))
end)

-- Nettoyage : si le joueur se déconnecte, on oublie ses locations (la caution
-- reste consommée — incite à restituer avant de quitter).
AddEventHandler('playerDropped', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local identifier = xPlayer.identifier
    for plate, rental in pairs(Rentals) do
        if rental.identifier == identifier then Rentals[plate] = nil end
    end
end)
