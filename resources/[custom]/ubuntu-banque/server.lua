local ESX = exports['es_extended']:getSharedObject()

-- Banque ESX — 100 % serveur-authoritative. Le client n'envoie qu'un montant /
-- une cible ; TOUT est revalidé ici. L'argent passe par l'API ESX
-- (add/removeAccountMoney) → cash ox_inventory + banque restent synchronisés.

local lastAction = {} -- [src] = os.clock() de la dernière opération (anti-spam)

-- --- Utilitaires ------------------------------------------------------------

local function notify(src, key, vars, kind)
    TriggerClientEvent('ox_lib:notify', src, {
        description = Lang:t(key, vars),
        type = kind or 'inform',
    })
end

local function formatMoney(amount)
    local s = tostring(math.floor(amount or 0))
    return (s:reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^%s+', '')) .. ' $'
end

-- Nettoie un montant reçu du client : entier strictement positif, borné.
local function sanitizeAmount(raw)
    local n = math.floor(tonumber(raw) or 0)
    if n <= 0 or n > Config.MaxAmount then return nil end
    return n
end

-- Throttle anti-spam par joueur.
local function throttled(src)
    local now = os.clock() * 1000
    local last = lastAction[src] or 0
    if (now - last) < Config.Cooldown then return true end
    lastAction[src] = now
    return false
end

local function logTx(identifier, txType, amount, balanceAfter, targetIdentifier)
    MySQL.insert(
        'INSERT INTO ubuntu_bank_transactions (identifier, type, amount, balance_after, target_identifier) VALUES (?, ?, ?, ?, ?)',
        { identifier, txType, amount, balanceAfter, targetIdentifier })
end

-- --- Callback solde ---------------------------------------------------------

lib.callback.register('ubuntu-banque:server:getBalance', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return { cash = 0, bank = 0 } end
    return {
        cash = (xPlayer.getAccount(Config.CashAccount) or {}).money or 0,
        bank = (xPlayer.getAccount(Config.BankAccount) or {}).money or 0,
    }
end)

-- --- Dépôt (cash -> banque) -------------------------------------------------

RegisterNetEvent('ubuntu-banque:server:deposit', function(rawAmount)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if throttled(src) then return notify(src, 'error.too_fast', nil, 'error') end

    local amount = sanitizeAmount(rawAmount)
    if not amount then return notify(src, 'error.invalid_amount', nil, 'error') end

    local cash = (xPlayer.getAccount(Config.CashAccount) or {}).money or 0
    if cash < amount then return notify(src, 'error.insufficient_cash', nil, 'error') end

    xPlayer.removeAccountMoney(Config.CashAccount, amount, 'banque-depot')
    xPlayer.addAccountMoney(Config.BankAccount, amount, 'banque-depot')

    local bank = (xPlayer.getAccount(Config.BankAccount) or {}).money or 0
    logTx(xPlayer.identifier, 'deposit', amount, bank, nil)
    notify(src, 'success.deposit', { amount = formatMoney(amount) }, 'success')
end)

-- --- Retrait (banque -> cash) -----------------------------------------------

RegisterNetEvent('ubuntu-banque:server:withdraw', function(rawAmount)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if throttled(src) then return notify(src, 'error.too_fast', nil, 'error') end

    local amount = sanitizeAmount(rawAmount)
    if not amount then return notify(src, 'error.invalid_amount', nil, 'error') end

    local bank = (xPlayer.getAccount(Config.BankAccount) or {}).money or 0
    if bank < amount then return notify(src, 'error.insufficient_bank', nil, 'error') end

    xPlayer.removeAccountMoney(Config.BankAccount, amount, 'banque-retrait')
    xPlayer.addAccountMoney(Config.CashAccount, amount, 'banque-retrait')

    logTx(xPlayer.identifier, 'withdraw', amount, bank - amount, nil)
    notify(src, 'success.withdraw', { amount = formatMoney(amount) }, 'success')
end)

-- --- Virement (banque expéditeur -> banque cible) ---------------------------

RegisterNetEvent('ubuntu-banque:server:transfer', function(rawTarget, rawAmount)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if not Config.Transfer.enabled then return notify(src, 'error.transfer_off', nil, 'error') end
    if throttled(src) then return notify(src, 'error.too_fast', nil, 'error') end

    local amount = sanitizeAmount(rawAmount)
    if not amount or amount < (Config.Transfer.minAmount or 1) then
        return notify(src, 'error.invalid_amount', nil, 'error')
    end

    local targetId = math.floor(tonumber(rawTarget) or -1)
    if targetId == src then return notify(src, 'error.target_self', nil, 'error') end

    local target = ESX.GetPlayerFromId(targetId)
    if not target then return notify(src, 'error.target_not_found', nil, 'error') end

    local fee = math.floor(amount * (Config.Transfer.feePercent or 0) / 100)
    local total = amount + fee

    local bank = (xPlayer.getAccount(Config.BankAccount) or {}).money or 0
    if bank < total then return notify(src, 'error.insufficient_bank', nil, 'error') end

    xPlayer.removeAccountMoney(Config.BankAccount, total, 'banque-virement')
    target.addAccountMoney(Config.BankAccount, amount, 'banque-virement')

    logTx(xPlayer.identifier, 'transfer_out', total, bank - total, target.identifier)
    logTx(target.identifier, 'transfer_in', amount,
        (target.getAccount(Config.BankAccount) or {}).money or 0, xPlayer.identifier)

    notify(src, 'success.transfer_sent', { amount = formatMoney(amount), target = target.getName() }, 'success')
    notify(target.source, 'success.transfer_recv', { amount = formatMoney(amount), sender = xPlayer.getName() }, 'success')
end)

AddEventHandler('playerDropped', function()
    lastAction[source] = nil
end)
