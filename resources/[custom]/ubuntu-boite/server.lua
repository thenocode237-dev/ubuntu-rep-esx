local ESX = exports['es_extended']:getSharedObject()

-- Boite de nuit ESX — 100 % serveur-authoritative. Le client n'envoie qu'une
-- intention (entrer, acheter, basculer l'ambiance) ; TOUT est revalide ici.
-- L'argent passe par l'API ESX (removeAccountMoney), les items par ox_inventory.

local lastAction = {} -- [src] = timestamp de la derniere operation (anti-spam)

local function notify(src, key, vars, kind)
    TriggerClientEvent('ox_lib:notify', src, {
        description = Lang:t(key, vars),
        type = kind or 'inform',
    })
end

-- Throttle anti-spam par joueur.
local function throttled(src)
    local now = os.clock() * 1000
    local last = lastAction[src] or 0
    if (now - last) < Config.Cooldown then return true end
    lastAction[src] = now
    return false
end

-- Retrouve une boisson du catalogue par son item (source de verite serveur).
local function findDrink(item)
    for _, d in ipairs(Config.Bar.drinks) do
        if d.item == item then return d end
    end
    return nil
end

-- --- Entree : cover charge (frais valides cote serveur) ---------------------
-- Renvoie true si le joueur peut entrer (frais preleves le cas echeant).
lib.callback.register('ubuntu-boite:server:tryEnter', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    local fee = math.floor(tonumber(Config.Entry.fee) or 0)
    if fee <= 0 then return true end

    local cash = (xPlayer.getAccount(Config.CashAccount) or {}).money or 0
    if cash < fee then
        notify(source, 'error.insufficient_cash', nil, 'error')
        return false
    end

    xPlayer.removeAccountMoney(Config.CashAccount, fee, 'boite-entree')
    if Config.Society.enabled then
        TriggerEvent('esx_addonaccount:getSharedAccount', Config.Society.account, function(account)
            if account then account.addMoney(fee) end
        end)
    end
    return true
end)

-- --- Achat d'une boisson au bar ---------------------------------------------
RegisterNetEvent('ubuntu-boite:server:buyDrink', function(item)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if throttled(src) then return notify(src, 'error.too_fast', nil, 'error') end

    local drink = findDrink(item)
    if not drink then return notify(src, 'error.unknown_drink', nil, 'error') end

    local price = math.floor(tonumber(drink.price) or 0)
    if price < 0 or price > Config.MaxAmount then return end

    local cash = (xPlayer.getAccount(Config.CashAccount) or {}).money or 0
    if cash < price then return notify(src, 'error.insufficient_cash', nil, 'error') end

    -- On verifie qu'on peut donner l'item AVANT de debiter (aucune perte d'argent).
    if not exports.ox_inventory:CanCarryItem(src, drink.item, 1) then
        return notify(src, 'error.inventory_full', nil, 'error')
    end
    if not exports.ox_inventory:AddItem(src, drink.item, 1) then
        return notify(src, 'error.inventory_full', nil, 'error')
    end

    xPlayer.removeAccountMoney(Config.CashAccount, price, 'boite-boisson')
    if Config.Society.enabled and price > 0 then
        TriggerEvent('esx_addonaccount:getSharedAccount', Config.Society.account, function(account)
            if account then account.addMoney(price) end
        end)
    end

    notify(src, 'success.bought', { label = drink.label }, 'success')
end)

-- --- DJ / ambiance : bascule la musique pour toute la boite ------------------
-- Etat global replique a tous les clients (statebag), reinitialise au reboot.
GlobalState.boiteMusic = false

RegisterNetEvent('ubuntu-boite:server:toggleMusic', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if throttled(src) then return notify(src, 'error.too_fast', nil, 'error') end

    local on = not GlobalState.boiteMusic
    GlobalState.boiteMusic = on
    notify(src, on and 'success.dj_on' or 'success.dj_off', nil, 'success')
end)

AddEventHandler('playerDropped', function()
    lastAction[source] = nil
end)
