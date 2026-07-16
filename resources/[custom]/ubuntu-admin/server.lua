local ESX = exports['es_extended']:getSharedObject()

-- Panel de gestion des joueurs (staff). TOUTES les actions revérifient la
-- permission côté serveur : le client n'est jamais une source d'autorité.

local function isAllowed(src)
    if src == 0 then return true end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    local group = xPlayer.getGroup()
    for _, g in ipairs(Config.AllowedGroups) do
        if group == g then return true end
    end
    return false
end

local function adminName(src)
    if src == 0 then return 'console' end
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
        return ('%s (%s)'):format(xPlayer.getName(), src)
    end
    return ('console/%s'):format(src)
end

local function notify(src, msg, kind)
    if src == 0 then return end
    local oxType = kind
    if kind == 'primary' or kind == nil then oxType = 'inform' end
    TriggerClientEvent('ox_lib:notify', src, { description = msg, type = oxType })
end

-- Identifiant d'un joueur par préfixe (license:/discord:/ip:).
local function getId(src, prefix)
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id and id:sub(1, #prefix) == prefix then return id end
    end
    return nil
end

-- --- Log Discord (best-effort) ----------------------------------------------

local function discordLog(action, admin, detail)
    local url = GetConvar(Config.DiscordWebhookConvar, '')
    if url == '' then return end
    local embed = { {
        title = 'Admin — ' .. action,
        color = 5983984, -- indigo #5B4CF0
        fields = {
            { name = 'Staff', value = admin, inline = true },
            { name = 'Détail', value = detail or '—', inline = false },
        },
        footer = { text = os.date('%Y-%m-%d %H:%M:%S') },
    } }
    PerformHttpRequest(url, function() end, 'POST',
        json.encode({ username = Config.DiscordBotName, embeds = embed }),
        { ['Content-Type'] = 'application/json' })
end

-- Garde commune : true si autorisé, sinon notif + false.
local function guard(src)
    if not isAllowed(src) then
        notify(src, Lang:t('error.no_permission'), 'error')
        return false
    end
    return true
end

-- --- Bannissement à la connexion --------------------------------------------

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    -- Robuste : toute erreur SQL (ex. table `bans` absente) NE DOIT PAS bloquer la
    -- connexion. On autorise par défaut ; on ne rejette que sur un ban confirmé.
    local ok, banReason = pcall(function()
        local license = getId(src, 'license:')
        if not license then return nil end
        local row = MySQL.single.await('SELECT reason, expire FROM bans WHERE license = ? LIMIT 1', { license })
        if row and (not row.expire or row.expire == 0 or row.expire > os.time()) then
            return row.reason or 'Banni'
        end
        return nil
    end)
    if ok and banReason then
        deferrals.done(('Vous êtes banni : %s'):format(banReason))
    else
        deferrals.done()
    end
end)

-- --- Lecture : autorisation, liste des joueurs, jobs ------------------------

lib.callback.register('ubuntu-admin:server:isAllowed', function(source)
    return isAllowed(source)
end)

lib.callback.register('ubuntu-admin:server:getPlayers', function(source)
    if not isAllowed(source) then return { allowed = false, players = {} } end
    local list = {}
    for _, xPlayer in pairs(ESX.GetExtendedPlayers()) do
        list[#list + 1] = {
            id = xPlayer.source,
            name = xPlayer.getName(),
            citizenid = xPlayer.identifier,
            job = ('%s (%s)'):format(xPlayer.job.label or xPlayer.job.name, xPlayer.job.grade_name or ''),
            jobName = xPlayer.job.name,
            grade = xPlayer.job.grade,
            ping = GetPlayerPing(xPlayer.source),
            cash = (xPlayer.getAccount('money') or {}).money or 0,
            bank = (xPlayer.getAccount('bank') or {}).money or 0,
            black = (xPlayer.getAccount('black_money') or {}).money or 0,
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return { allowed = true, players = list, jobs = ESX.GetJobs(), moneyTypes = Config.MoneyTypes }
end)

-- --- Actions ----------------------------------------------------------------

local function getTarget(src, targetId)
    local target = ESX.GetPlayerFromId(tonumber(targetId) or -1)
    if not target then notify(src, Lang:t('error.invalid_target'), 'error') end
    return target 
end

RegisterNetEvent('ubuntu-admin:server:action', function(action, targetId, args)
    local src = source
    if not guard(src) then return end
    args = args or {}

    -- Actions serveur globales (sans cible).
    if action == 'announce' then
        local msg = tostring(args.message or '')
        if msg == '' then return end
        TriggerClientEvent('ubuntu-admin:client:announce', -1, msg)
        discordLog('Annonce', adminName(src), msg)
        return notify(src, Lang:t('success.announced'), 'success')
    end

    -- Actions ciblant un joueur.
    local target = getTarget(src, targetId)
    if not target then return end
    local tsrc = target.source
    local tname = ('%s [%s]'):format(target.getName(), tsrc)

    if action == 'kick' then
        local reason = tostring(args.reason or 'Expulsé par un administrateur')
        discordLog('Kick', adminName(src), tname .. ' — ' .. reason)
        DropPlayer(tsrc, reason)

    elseif action == 'ban' then
        local reason = tostring(args.reason or 'Banni par un administrateur')
        local days = tonumber(args.days) or Config.DefaultBanDays
        local expire = os.time() + math.floor(days * 86400)
        MySQL.insert('INSERT INTO bans (name, license, discord, ip, reason, expire, bannedby) VALUES (?, ?, ?, ?, ?, ?, ?)', {
            tname,
            getId(tsrc, 'license:'),
            getId(tsrc, 'discord:'),
            getId(tsrc, 'ip:'),
            reason, expire, adminName(src),
        })
        discordLog('Ban', adminName(src), ('%s — %s (%d j)'):format(tname, reason, days))
        DropPlayer(tsrc, ('Banni : %s'):format(reason))
        notify(src, Lang:t('success.banned', { name = tname }), 'success')

    elseif action == 'money' then
        local mtype = tostring(args.moneyType or 'money')
        local amount = math.floor(tonumber(args.amount) or 0)
        local ok = false
        if amount > 0 then
            target.addAccountMoney(mtype, amount)
            ok = true
        elseif amount < 0 then
            local acc = target.getAccount(mtype)
            if acc and acc.money >= -amount then
                target.removeAccountMoney(mtype, -amount)
                ok = true
            end
        end
        if ok then
            discordLog('Argent', adminName(src), ('%s : %+d %s'):format(tname, amount, mtype))
            notify(src, Lang:t('success.money', { amount = amount, type = mtype, name = tname }), 'success')
            notify(tsrc, Lang:t('success.money_target', { amount = amount, type = mtype }), 'primary')
        else
            notify(src, Lang:t('error.money_failed'), 'error')
        end

    elseif action == 'setjob' then
        local jobName = tostring(args.jobName or '')
        local grade = math.floor(tonumber(args.grade) or 0)
        local jobs = ESX.GetJobs()
        if not jobs[jobName] then return notify(src, Lang:t('error.invalid_job'), 'error') end
        if not jobs[jobName].grades[tostring(grade)] then grade = 0 end
        target.setJob(jobName, grade)
        discordLog('Job', adminName(src), ('%s -> %s grade %d'):format(tname, jobName, grade))
        notify(src, Lang:t('success.job', { name = tname, job = jobName, grade = grade }), 'success')

    elseif action == 'revive' then
        TriggerClientEvent('ubuntu-admin:client:revive', tsrc)
        discordLog('Revive', adminName(src), tname)
        notify(src, Lang:t('success.revived', { name = tname }), 'success')

    elseif action == 'heal' then
        TriggerClientEvent('ubuntu-admin:client:heal', tsrc)
        notify(src, Lang:t('success.healed', { name = tname }), 'success')

    elseif action == 'freeze' then
        TriggerClientEvent('ubuntu-admin:client:freeze', tsrc, args.state and true or false)
        notify(src, Lang:t(args.state and 'success.frozen' or 'success.unfrozen', { name = tname }), 'success')

    elseif action == 'goto' then
        local coords = GetEntityCoords(GetPlayerPed(tsrc))
        TriggerClientEvent('ubuntu-admin:client:teleport', src, { x = coords.x, y = coords.y, z = coords.z })

    elseif action == 'bring' then
        local coords = GetEntityCoords(GetPlayerPed(src))
        TriggerClientEvent('ubuntu-admin:client:teleport', tsrc, { x = coords.x, y = coords.y, z = coords.z })
        notify(src, Lang:t('success.brought', { name = tname }), 'success')

    elseif action == 'spectate' then
        local coords = GetEntityCoords(GetPlayerPed(tsrc))
        TriggerClientEvent('ubuntu-admin:client:spectate', src, tsrc, { x = coords.x, y = coords.y, z = coords.z })

    elseif action == 'addpoints' then
        -- Réutilise la logique de la boutique premium (crédit de dons).
        local amount = math.floor(tonumber(args.amount) or 0)
        if amount > 0 then
            exports['ubuntu-premium']:AddPoints(tsrc, amount)
            discordLog('Points', adminName(src), ('%s : +%d Points'):format(tname, amount))
            notify(src, Lang:t('success.points', { amount = amount, name = tname }), 'success')
        end

    elseif action == 'weaponlicense' then
        -- Permis d'arme (table ESX `user_licenses`) : débloque l'achat des armes à
        -- feu gatées `license = 'weapon'` par ox_inventory (bridge ESX teste juste
        -- l'existence de la ligne owner = xPlayer.identifier). Idempotent.
        local grant = args.grant and true or false
        local owner = target.identifier
        if grant then
            local exists = MySQL.scalar.await(
                'SELECT 1 FROM user_licenses WHERE type = ? AND owner = ? LIMIT 1', { 'weapon', owner })
            if not exists then
                MySQL.insert.await('INSERT INTO user_licenses (type, owner) VALUES (?, ?)', { 'weapon', owner })
            end
            discordLog('Permis arme', adminName(src), tname .. ' — accordé')
            notify(src, Lang:t('success.weaponlicense_grant', { name = tname }), 'success')
            notify(tsrc, Lang:t('success.weaponlicense_you_grant'), 'primary')
        else
            MySQL.query.await('DELETE FROM user_licenses WHERE type = ? AND owner = ?', { 'weapon', owner })
            discordLog('Permis arme', adminName(src), tname .. ' — retiré')
            notify(src, Lang:t('success.weaponlicense_revoke', { name = tname }), 'success')
            notify(tsrc, Lang:t('success.weaponlicense_you_revoke'), 'primary')
        end
    end
end)
