local ESX = exports['es_extended']:getSharedObject()

-- Boutique premium « Points ». Toute la logique (coûts, effets, possession) vit
-- ici, côté serveur : le client n'envoie que l'`id` d'un article. Non P2W.
-- Les points ne sont PAS un compte ESX : ils vivent dans `ubuntu_premium_data`.

-- Index du catalogue par id (source de vérité serveur).
local Catalog = {}
for _, item in ipairs(Config.Catalog) do Catalog[item.id] = item end

local function formatPoints(amount)
    local s = tostring(math.floor(amount or 0))
    local formatted = s:reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^%s+', '')
    return formatted .. ' ' .. Config.CurrencyName
end

-- ox_lib notify (map des variantes qb -> ox).
local function notify(src, msg, kind)
    local oxType = kind
    if kind == 'primary' or kind == nil then oxType = 'inform' end
    TriggerClientEvent('ox_lib:notify', src, { description = msg, type = oxType })
end

-- --- Persistance premium (table propre) -------------------------------------

local function ensureRow(identifier)
    MySQL.insert.await('INSERT IGNORE INTO ubuntu_premium_data (identifier, points, data) VALUES (?, 0, ?)',
        { identifier, '{}' })
end

local function getPoints(identifier)
    ensureRow(identifier)
    return MySQL.scalar.await('SELECT points FROM ubuntu_premium_data WHERE identifier = ?', { identifier }) or 0
end

local function setPoints(identifier, value)
    if value < 0 then value = 0 end
    MySQL.update.await('UPDATE ubuntu_premium_data SET points = ? WHERE identifier = ?', { math.floor(value), identifier })
end

-- Métadonnée premium : { owned = {id=true}, cosmetics = {}, rank, perks = {} }
local function getData(identifier)
    ensureRow(identifier)
    local raw = MySQL.scalar.await('SELECT data FROM ubuntu_premium_data WHERE identifier = ?', { identifier })
    local meta = raw and json.decode(raw) or nil
    if type(meta) ~= 'table' then meta = {} end
    meta.owned = meta.owned or {}
    meta.cosmetics = meta.cosmetics or {}
    meta.perks = meta.perks or {}
    return meta
end

local function setData(identifier, meta)
    MySQL.update.await('UPDATE ubuntu_premium_data SET data = ? WHERE identifier = ?',
        { json.encode(meta), identifier })
end

local function isAdmin(src)
    if src == 0 then return true end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    local group = xPlayer.getGroup()
    for _, g in ipairs(Config.AdminGroups) do
        if group == g then return true end
    end
    return false
end

-- --- Effets d'achat ---------------------------------------------------------

-- Plaque unique de 8 caractères (charset alphanumérique majuscule).
local PLATE_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
local function generatePlate()
    local plate = {}
    for i = 1, 8 do
        local n = math.random(1, #PLATE_CHARS)
        plate[i] = PLATE_CHARS:sub(n, n)
    end
    return table.concat(plate)
end

-- Livre un véhicule cosmétique DANS LE GARAGE : insert dans owned_vehicles avec
-- stored=1 (récupérable via ubuntu-garage), même patron que esx_vehicleshop mais
-- SANS spawn immédiat. Mods NEUTRES (aucune performance).
local function grantVehicle(xPlayer, veh)
    local plate = generatePlate()
    local props = json.encode({ model = GetHashKey(veh.model), plate = plate })
    MySQL.insert.await(
        'INSERT INTO owned_vehicles (owner, plate, vehicle, type, stored) VALUES (?, ?, ?, ?, ?)',
        { xPlayer.identifier, plate, props, veh.vtype or 'car', 1 })
    return plate
end

-- Livre des objets dans l'inventaire ox_inventory (refund si l'inventaire est
-- plein). payload.items = { { name = 'premium_snack', count = 3 }, ... }.
local function grantItems(src, items)
    for _, entry in ipairs(items or {}) do
        local name, count = entry.name, entry.count or 1
        if name and not exports.ox_inventory:AddItem(src, name, count) then
            return false -- inventaire plein : l'appelant annule/rembourse
        end
    end
    return true
end

-- Applique une tenue cosmétique au ped via natives GTA (côté client) ET stocke
-- le skin complet dans la méta pour permettre de la re-porter à volonté (/tenues)
-- et de la ré-appliquer au spawn (mémorisée comme dernière tenue portée).
local function grantOutfit(src, out, meta)
    TriggerClientEvent('ubuntu-premium:client:applyOutfit', src, out.skin)
    meta.cosmetics[#meta.cosmetics + 1] = out.name -- rétro-compat / audit
    meta.outfits = meta.outfits or {}
    meta.outfits[out.name] = out.skin
    meta.lastOutfit = out.name
end

-- Grade VIP : mémorise rank + groupe ace pour le ré-appliquer à chaque connexion
-- (le principal de session est recréé au join → VIP durable across reconnexions).
local function grantRank(src, payload, meta)
    meta.rank = payload.rankId
    meta.aceGroup = payload.aceGroup
    if payload.aceGroup then
        ExecuteCommand(('add_principal player.%s group.%s'):format(src, payload.aceGroup))
    end
end

-- --- Callbacks / events -----------------------------------------------------

-- État de la boutique pour l'UI : solde + articles possédés.
lib.callback.register('ubuntu-premium:server:getStore', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return { balance = 0, owned = {} } end
    local meta = getData(xPlayer.identifier)
    return {
        balance = getPoints(xPlayer.identifier),
        owned = meta.owned,
    }
end)

-- Liste des tenues possédées (pour le menu /tenues) + dernière tenue portée
-- (pour la ré-application au spawn côté client).
lib.callback.register('ubuntu-premium:server:getOutfits', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return { outfits = {}, last = nil } end
    local meta = getData(xPlayer.identifier)
    local outfits = {}
    for name, skin in pairs(meta.outfits or {}) do
        outfits[#outfits + 1] = { name = name, skin = skin }
    end
    table.sort(outfits, function(a, b) return a.name < b.name end)
    return { outfits = outfits, last = meta.lastOutfit }
end)

-- Mémorise la dernière tenue re-portée via /tenues (ré-appliquée au prochain spawn).
RegisterNetEvent('ubuntu-premium:server:setLastOutfit', function(name)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or type(name) ~= 'string' then return end
    local meta = getData(xPlayer.identifier)
    if not (meta.outfits and meta.outfits[name]) then return end -- possession requise
    meta.lastOutfit = name
    setData(xPlayer.identifier, meta)
end)

-- Ré-applique le grade ace donateur à chaque connexion (VIP persistant).
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    local meta = getData(xPlayer.identifier)
    if meta.aceGroup then
        ExecuteCommand(('add_principal player.%s group.%s'):format(playerId, meta.aceGroup))
    end
end)

RegisterNetEvent('ubuntu-premium:server:buy', function(itemId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local identifier = xPlayer.identifier

    local item = Catalog[itemId]
    if not item then
        return notify(src, Lang:t('error.unknown_item'), 'error')
    end

    local meta = getData(identifier)
    if item.oneTime and meta.owned[item.id] then
        return notify(src, Lang:t('error.already_owned'), 'error')
    end

    -- Débit des points (vérif du solde AVANT — pas de solde négatif).
    local balance = getPoints(identifier)
    if balance < item.cost then
        return notify(src, Lang:t('error.insufficient_funds', { currency = Config.CurrencyName }), 'error')
    end
    setPoints(identifier, balance - item.cost)

    -- Application de l'effet selon le type.
    local payload = item.payload or {}
    if item.type == 'bundle' then
        if payload.vehicle then grantVehicle(xPlayer, payload.vehicle) end
        if payload.outfit then grantOutfit(src, payload.outfit, meta) end
        -- Objets du pack : non bloquant (le reste du pack est déjà livré).
        if payload.items and not grantItems(src, payload.items) then
            notify(src, Lang:t('error.inventory_full'), 'error')
        end
    elseif item.type == 'vehicle' then
        if payload.vehicle then grantVehicle(xPlayer, payload.vehicle) end
    elseif item.type == 'cosmetic' then
        if payload.outfit then grantOutfit(src, payload.outfit, meta) end
    elseif item.type == 'item' then
        -- Objets seuls : si l'inventaire est plein, on rembourse et on annule.
        if not grantItems(src, payload.items) then
            setPoints(identifier, getPoints(identifier) + item.cost)
            return notify(src, Lang:t('error.inventory_full'), 'error')
        end
    elseif item.type == 'rank' then
        grantRank(src, payload, meta)
    elseif item.type == 'perk' then
        if payload.key then
            meta.perks[payload.key] = (meta.perks[payload.key] or 0) + (payload.value or 1)
        end
    end

    -- Marque l'article possédé + persiste la métadonnée premium.
    if item.oneTime then meta.owned[item.id] = true end
    setData(identifier, meta)

    -- Journal d'audit (best-effort).
    MySQL.insert('INSERT INTO ubuntu_premium_purchases (identifier, item_id, item_label, cost, purchased_at) VALUES (?, ?, ?, ?, NOW())',
        { identifier, item.id, item.label, item.cost })

    notify(src, Lang:t('success.purchased', { label = item.label, cost = formatPoints(item.cost) }), 'success')

    -- Renvoie le nouvel état à l'UI (rafraîchit solde + possessions).
    TriggerClientEvent('ubuntu-premium:client:refresh', src, {
        balance = getPoints(identifier),
        owned = meta.owned,
    })

    print(('[ubuntu-premium] %s a acheté %s (%d %s)'):format(identifier, item.id, item.cost, Config.CurrencyName))
end)

-- --- Crédit admin (simule un don) : /addpoints <id> <montant> ----------------

local function addPointsCmd(src, targetId, rawAmount)
    if not isAdmin(src) then
        return notify(src, Lang:t('error.no_permission'), 'error')
    end
    local target = ESX.GetPlayerFromId(tonumber(targetId) or -1)
    if not target then
        if src ~= 0 then notify(src, Lang:t('error.invalid_target'), 'error') end
        return
    end
    local amount = math.floor(tonumber(rawAmount) or 0)
    if amount <= 0 then
        if src ~= 0 then notify(src, Lang:t('error.invalid_amount'), 'error') end
        return
    end
    setPoints(target.identifier, getPoints(target.identifier) + amount)
    notify(target.source, Lang:t('success.points_received', { amount = formatPoints(amount) }), 'success')
    if src ~= 0 then
        notify(src, Lang:t('success.points_granted', { amount = formatPoints(amount), id = target.source }), 'success')
    end
    print(('[ubuntu-premium] +%d %s -> %s (par %s)'):format(amount, Config.CurrencyName, target.identifier, src == 0 and 'console' or src))
end

RegisterCommand('addpoints', function(source, args)
    addPointsCmd(source, args[1], args[2])
end, false)

-- Export réutilisable (ex. depuis ubuntu-admin) pour créditer des points.
exports('AddPoints', function(targetId, amount)
    addPointsCmd(0, targetId, amount)
end)

-- --- Exports de lecture (seam pour d'autres ressources) ----------------------
-- Perks confort (ex. { extra_garage_slots = 1 }). Tant qu'aucune ressource
-- garage/garde-robe ne les consomme, ils restent informatifs.
exports('GetPerks', function(identifier)
    return getData(identifier).perks or {}
end)

-- Grade donateur courant (ex. 'vip' / 'vip_plus') ou nil.
exports('GetRank', function(identifier)
    return getData(identifier).rank
end)

-- Métadonnée premium complète (owned/outfits/rank/aceGroup/perks/lastOutfit).
exports('GetPremiumData', function(identifier)
    return getData(identifier)
end)
