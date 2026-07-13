local ESX = exports['es_extended']:getSharedObject()

-- Groupes ESX considérés comme staff (affiche l'entrée « Panel Admin » du menu).
-- L'ouverture réelle du panel reste re-validée par ubuntu-admin côté serveur.
local StaffGroups = { 'admin', 'superadmin', 'mod' }

-- Indique au client si le joueur est staff — jamais de confiance au client :
-- la permission est vérifiée ici via le groupe ESX.
lib.callback.register('ubuntu-interface:server:isStaff', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    local group = xPlayer.getGroup()
    for _, g in ipairs(StaffGroups) do
        if group == g then return true end
    end
    return false
end)
