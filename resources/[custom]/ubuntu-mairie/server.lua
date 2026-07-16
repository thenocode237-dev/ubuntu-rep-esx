local ESX = exports['es_extended']:getSharedObject()

-- ubuntu-mairie — logique 100 % serveur-authoritative. Le client n'envoie qu'un
-- nom de métier ; le serveur revalide contre Config.Jobs (whitelist locale) et
-- l'éventuelle garde `restricted` (staff) AVANT d'appliquer xPlayer.setJob().
-- Aucune confiance client : un joueur qui forge l'event ne peut prendre qu'un
-- métier réellement listé, et jamais un métier `restricted` sans être staff.

-- Recherche l'entrée Config.Jobs correspondant à un nom (nil si absent).
local function findJob(name)
    for _, j in ipairs(Config.Jobs) do
        if j.name == name then return j end
    end
    return nil
end

local function isStaff(xPlayer)
    return Config.StaffGroups[xPlayer.getGroup()] == true
end

-- Libellé localisé d'un métier (repli sur le nom brut si absent des locales).
local function jobLabel(name)
    local label = Lang:t('jobs.' .. name)
    if label == 'jobs.' .. name then return name end
    return label
end

-- --- État du joueur (métier courant + staff) pour construire le menu ---------
lib.callback.register('ubuntu-mairie:getState', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return nil end
    return {
        job      = xPlayer.job.name,
        jobLabel = jobLabel(xPlayer.job.name),
        isStaff  = isStaff(xPlayer),
    }
end)

-- --- Prendre un emploi -------------------------------------------------------
RegisterNetEvent('ubuntu-mairie:server:takeJob', function(jobName)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local job = findJob(jobName)
    if not job then
        return TriggerClientEvent('ubuntu-mairie:client:notify', src, 'invalid', 'error')
    end
    if job.restricted and not isStaff(xPlayer) then
        return TriggerClientEvent('ubuntu-mairie:client:notify', src, 'restricted', 'error')
    end
    if xPlayer.job.name == job.name then
        return TriggerClientEvent('ubuntu-mairie:client:notify', src, 'already', 'inform')
    end

    xPlayer.setJob(job.name, job.grade or 0)
    TriggerClientEvent('ubuntu-mairie:client:notify', src, 'hired', 'success', {
        job = jobLabel(job.name),
    })
end)

-- --- Quitter son emploi (redevenir « unemployed ») ---------------------------
RegisterNetEvent('ubuntu-mairie:server:quitJob', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    if xPlayer.job.name == 'unemployed' then
        return TriggerClientEvent('ubuntu-mairie:client:notify', src, 'already_none', 'inform')
    end

    xPlayer.setJob('unemployed', 0)
    TriggerClientEvent('ubuntu-mairie:client:notify', src, 'quit', 'success')
end)
