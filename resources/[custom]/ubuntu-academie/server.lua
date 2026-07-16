local ESX = exports['es_extended']:getSharedObject()

-- ubuntu-academie — le serveur ne gère que le suivi « ce joueur a-t-il déjà vu
-- l'académie ». À la première connexion (identifier absent de la table
-- ubuntu_academy_seen), on invite le joueur à s'y rendre. Le joueur est marqué
-- « vu » dès qu'il ouvre le menu de l'académie (client → server:markSeen).

local pending = {} -- [src] = true : joueur en attente de notification (nouveau)

-- Le joueur a-t-il déjà été accueilli ? (table ubuntu_academy_seen)
local function hasSeen(identifier)
    return MySQL.scalar.await(
        'SELECT 1 FROM ubuntu_academy_seen WHERE identifier = ? LIMIT 1',
        { identifier }) ~= nil
end

local function markSeen(identifier)
    MySQL.insert.await(
        'INSERT IGNORE INTO ubuntu_academy_seen (identifier) VALUES (?)',
        { identifier })
end

-- Nouveau joueur : notification + itinéraire GPS vers l'académie.
AddEventHandler('esx:playerLoaded', function(src, xPlayer)
    if not Config.Notify.enabled then return end
    local identifier = xPlayer and xPlayer.identifier
    if not identifier then return end
    if hasSeen(identifier) then return end

    pending[src] = true
    SetTimeout(Config.Notify.delay or 8000, function()
        if pending[src] then
            TriggerClientEvent('ubuntu-academie:client:newcomer', src)
        end
    end)
end)

-- Le joueur a ouvert l'académie : on le marque « vu » (idempotent).
RegisterNetEvent('ubuntu-academie:server:markSeen', function()
    local src = source
    pending[src] = nil
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    markSeen(xPlayer.identifier)
end)

AddEventHandler('playerDropped', function()
    pending[source] = nil
end)
