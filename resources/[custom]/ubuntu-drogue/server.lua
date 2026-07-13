local ESX = exports['es_extended']:getSharedObject()

-- Vente de drogue de rue — logique serveur-authoritative. Le client n'envoie que
-- l'intention de deal (dans une zone) ou d'achat (au grossiste) ; la possession de
-- l'item, le prix, la chaleur et l'alerte Police sont validés et appliqués ICI.

local Zones = {}
for _, z in ipairs(Config.Zones) do Zones[z.id] = z end

local heat = {}     -- [identifier] = chaleur cumulée
local lastSale = {} -- [identifier] = os.time() de la dernière vente (throttle)
local layLow = {}   -- [identifier] = os.time() d'expiration du blocage

local function formatMoney(amount)
    local s = tostring(math.floor(amount or 0))
    return '$' .. (s:reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^%s+', ''))
end

local function notify(src, key, data, kind)
    local oxType = kind
    if kind == 'primary' or kind == nil then oxType = 'inform' end
    TriggerClientEvent('ox_lib:notify', src, { description = Lang:t(key, data), type = oxType })
end

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

-- Quantité d'un item dans l'inventaire ox du joueur.
local function itemCount(src, name)
    return exports.ox_inventory:GetItem(src, name, nil, true) or 0
end

-- Décroissance de la chaleur (toutes les minutes).
CreateThread(function()
    while true do
        Wait(60000)
        for id, h in pairs(heat) do
            local nh = h - Config.HeatDecayPerMin
            if nh <= 0 then heat[id] = nil else heat[id] = nh end
        end
    end
end)

-- Alerte Police + « lay low » quand la chaleur dépasse le seuil.
local function checkHeat(identifier, coords, zone)
    if (heat[identifier] or 0) < Config.HeatThreshold then return end
    heat[identifier] = nil
    layLow[identifier] = os.time() + Config.LayLowCooldown
    local cops = onDutyPolice()
    for _, csrc in ipairs(cops) do
        TriggerClientEvent('ox_lib:notify', csrc, { description = Lang:t('alert.dealing', { zone = zone.label }), type = 'error' })
        TriggerClientEvent('ubuntu-drogue:client:alert', csrc, { coords = { x = coords.x, y = coords.y, z = coords.z } })
    end
end

-- --- Vendre à un PNJ (dans une zone) ----------------------------------------
RegisterNetEvent('ubuntu-drogue:server:sell', function(zoneId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local identifier = xPlayer.identifier
    local now = os.time()

    if layLow[identifier] and layLow[identifier] > now then
        return notify(src, 'error.lay_low', { mins = math.ceil((layLow[identifier] - now) / 60) }, 'error')
    end
    if lastSale[identifier] and (now - lastSale[identifier]) < Config.SellCooldown then
        return -- throttle silencieux
    end

    local zone = Zones[zoneId]
    if not zone then return end

    -- Anti-triche : le joueur doit être dans la zone (tolérance).
    local pc = GetEntityCoords(GetPlayerPed(src))
    if #(pc - zone.center) > (zone.radius + 25.0) then return end

    -- Stock : premier item vendable détenu (choix aléatoire parmi ceux possédés).
    local owned = {}
    for item, info in pairs(Config.Products) do
        if itemCount(src, item) > 0 then
            owned[#owned + 1] = { item = item, info = info }
        end
    end
    if #owned == 0 then
        return notify(src, 'error.no_stock', nil, 'error')
    end

    lastSale[identifier] = now

    if math.random() < Config.RefuseChance then
        -- PNJ méfiant : un peu de chaleur, pas de vente.
        heat[identifier] = (heat[identifier] or 0) + math.floor(Config.HeatPerSale * 0.5 * zone.heatMult)
        notify(src, 'info.refused', nil, 'error')
        checkHeat(identifier, pc, zone)
        return
    end

    local pick = owned[math.random(#owned)]
    local base = math.random(pick.info.price.min, pick.info.price.max)
    local price = math.floor(base * zone.priceMult)

    if not exports.ox_inventory:RemoveItem(src, pick.item, 1) then
        return notify(src, 'error.no_stock', nil, 'error')
    end
    xPlayer.addAccountMoney(Config.MoneyType, price)
    heat[identifier] = (heat[identifier] or 0) + math.floor(Config.HeatPerSale * zone.heatMult)
    notify(src, 'success.sold', { label = pick.info.label, amount = formatMoney(price) }, 'success')
    checkHeat(identifier, pc, zone)
end)

-- --- Acheter du stock au grossiste ------------------------------------------
RegisterNetEvent('ubuntu-drogue:server:buy', function(item)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local entry
    for _, s in ipairs(Config.Supplier.stock) do
        if s.item == item then entry = s break end
    end
    if not entry then return end

    -- Anti-triche : proximité du grossiste.
    local sc = Config.Supplier.coords
    if #(GetEntityCoords(GetPlayerPed(src)) - vector3(sc.x, sc.y, sc.z)) > 5.0 then return end

    local acc = xPlayer.getAccount(Config.MoneyType)
    if not acc or acc.money < entry.price then
        return notify(src, 'error.insufficient_funds', { amount = formatMoney(entry.price) }, 'error')
    end
    xPlayer.removeAccountMoney(Config.MoneyType, entry.price)
    if not exports.ox_inventory:AddItem(src, item, 1) then
        xPlayer.addAccountMoney(Config.MoneyType, entry.price) -- inventaire plein → remboursement
        return notify(src, 'error.inventory_full', nil, 'error')
    end
    notify(src, 'success.bought', { label = entry.label, amount = formatMoney(entry.price) }, 'success')
end)

AddEventHandler('playerDropped', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local identifier = xPlayer.identifier
    heat[identifier] = nil
    lastSale[identifier] = nil
    layLow[identifier] = nil
end)
