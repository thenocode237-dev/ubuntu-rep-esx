local ESX = exports['es_extended']:getSharedObject()

-- Braquages — logique serveur-authoritative. Le client n'envoie que des intentions
-- (démarrer / terminer / annuler un braquage sur une cible) ; les cooldowns, le seuil
-- de police, la consommation d'item et le butin sont validés et appliqués ICI.

-- Index des cibles par id (source de vérité serveur).
local Targets = {}
for _, t in ipairs(Config.Targets) do Targets[t.id] = t end

-- Cooldowns par cible : [targetId] = os.time() d'expiration.
local cooldowns = {}
-- Braquages en cours : [targetId] = { identifier, startedAt, duration, reward }.
local active = {}

local function formatMoney(amount)
    local s = tostring(math.floor(amount or 0))
    return '$' .. (s:reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^%s+', ''))
end

local function notify(src, key, data, kind)
    local oxType = kind
    if kind == 'primary' or kind == nil then oxType = 'inform' end
    TriggerClientEvent('ox_lib:notify', src, { description = Lang:t(key, data), type = oxType })
end

-- Nombre de policiers EN SERVICE (sert au seuil minPolice ET à la liste d'alerte).
local function onDutyPolice()
    local list = {}
    for _, xPlayer in pairs(ESX.GetExtendedPlayers()) do
        local job = xPlayer.job
        if job and job.name == Config.PoliceJob and (job.onDuty ~= false) then
            list[#list + 1] = xPlayer.source
        end
    end
    return list
end

-- Alerte : notifie chaque policier en service et pose un blip clignotant temporaire.
local function alertPolice(target, cops)
    local c = target.coords
    for _, src in ipairs(cops) do
        TriggerClientEvent('ox_lib:notify', src, { description = Lang:t('alert.robbery', { label = target.label }), type = 'error' })
        TriggerClientEvent('ubuntu-braquages:client:alert', src, {
            coords = { x = c.x, y = c.y, z = c.z },
            label = target.label,
        })
    end
end

-- Quantité d'un item dans l'inventaire ox du joueur.
local function itemCount(src, name)
    return exports.ox_inventory:GetItem(src, name, nil, true) or 0
end

-- --- Démarrer un braquage ---------------------------------------------------
RegisterNetEvent('ubuntu-braquages:server:start', function(targetId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local target = Targets[targetId]
    if not target then return end

    -- Anti-triche : le joueur doit réellement être sur la cible.
    local ped = GetPlayerPed(src)
    local pcoords = GetEntityCoords(ped)
    if #(pcoords - vector3(target.coords.x, target.coords.y, target.coords.z)) > Config.MaxStartDistance then
        return
    end

    local now = os.time()
    if cooldowns[targetId] and cooldowns[targetId] > now then
        return notify(src, 'error.cooldown', { mins = math.ceil((cooldowns[targetId] - now) / 60) }, 'error')
    end
    if active[targetId] then
        return notify(src, 'error.in_progress', nil, 'error')
    end

    local cops = onDutyPolice()
    if #cops < (target.minPolice or 0) then
        return notify(src, 'error.no_police', { n = target.minPolice }, 'error')
    end

    -- Item requis (consommé au démarrage — thermite/kit).
    if target.requiredItem then
        if itemCount(src, target.requiredItem) < 1 then
            return notify(src, 'error.need_item', { item = target.requiredItem }, 'error')
        end
        exports.ox_inventory:RemoveItem(src, target.requiredItem, 1)
    end

    local reward = math.random(target.reward.min, target.reward.max)
    active[targetId] = {
        identifier = xPlayer.identifier,
        startedAt = now,
        duration = target.duration,
        reward = reward,
    }
    cooldowns[targetId] = now + (target.cooldown or 600)

    alertPolice(target, cops)
    TriggerClientEvent('ubuntu-braquages:client:begin', src, { targetId = targetId, duration = target.duration })
    print(('[ubuntu-braquages] %s démarre un braquage sur %s'):format(xPlayer.identifier, targetId))
end)

-- --- Terminer un braquage (crédite le butin) --------------------------------
RegisterNetEvent('ubuntu-braquages:server:finish', function(targetId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local a = active[targetId]
    if not a or a.identifier ~= xPlayer.identifier then return end

    -- Le braquage doit avoir duré au moins (duration - 3s) : anti-triche « finish » instantané.
    if (os.time() - a.startedAt) < math.floor(a.duration / 1000) - 3 then
        active[targetId] = nil
        return
    end
    active[targetId] = nil

    xPlayer.addAccountMoney(Config.MoneyType, a.reward)
    notify(src, 'success.looted', { amount = formatMoney(a.reward) }, 'success')
    print(('[ubuntu-braquages] %s empoche %d sur %s'):format(xPlayer.identifier, a.reward, targetId))
end)

-- --- Annuler (interruption / mort côté client) ------------------------------
RegisterNetEvent('ubuntu-braquages:server:cancel', function(targetId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local a = active[targetId]
    if a and a.identifier == xPlayer.identifier then
        active[targetId] = nil
    end
end)

-- Nettoyage : un joueur qui se déconnecte pendant un braquage libère la cible
-- (le cooldown reste posé — pas de spam).
AddEventHandler('playerDropped', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local identifier = xPlayer.identifier
    for id, a in pairs(active) do
        if a.identifier == identifier then active[id] = nil end
    end
end)
