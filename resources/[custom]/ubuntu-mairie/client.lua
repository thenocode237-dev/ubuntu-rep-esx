local peds = {}

-- DrawText3D natif (identique aux autres ressources maison).
local function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

-- --- Notifications (le serveur pilote, le client localise) -------------------
RegisterNetEvent('ubuntu-mairie:client:notify', function(key, kind, vars)
    lib.notify({
        title       = Lang:t('menu.title'),
        description = Lang:t('notify.' .. key, vars),
        type        = kind or 'inform',
        position    = 'top',
    })
end)

-- --- Sous-menu « Prendre un emploi » -----------------------------------------
local function openJobList(state)
    local options = {}
    for _, j in ipairs(Config.Jobs) do
        local locked = j.restricted and not state.isStaff
        local desc   = nil
        if locked then desc = Lang:t('menu.staff_only') end
        options[#options + 1] = {
            title       = Lang:t('jobs.' .. j.name),
            description = desc,
            icon        = locked and 'lock' or j.icon,
            disabled    = (state.job == j.name),
            onSelect    = function()
                TriggerServerEvent('ubuntu-mairie:server:takeJob', j.name)
            end,
        }
    end

    lib.registerContext({
        id      = 'ubuntu_mairie_jobs',
        title   = Lang:t('menu.take'),
        menu    = 'ubuntu_mairie_menu',
        options = options,
    })
    lib.showContext('ubuntu_mairie_jobs')
end

-- --- Menu principal de la mairie ---------------------------------------------
local function openMairie()
    local state = lib.callback.await('ubuntu-mairie:getState', false)
    if not state then return end

    local options = {
        {
            title       = Lang:t('menu.current', { job = state.jobLabel }),
            icon        = 'id-card',
            disabled    = true,
        },
        {
            title       = Lang:t('menu.take'),
            description = Lang:t('menu.take_desc'),
            icon        = 'briefcase',
            arrow       = true,
            onSelect    = function() openJobList(state) end,
        },
    }

    -- « Quitter mon emploi » n'a de sens que si le joueur a un métier.
    if state.job ~= 'unemployed' then
        options[#options + 1] = {
            title       = Lang:t('menu.quit'),
            description = Lang:t('menu.quit_desc'),
            icon        = 'user-slash',
            onSelect    = function() TriggerServerEvent('ubuntu-mairie:server:quitJob') end,
        }
    end

    lib.registerContext({
        id      = 'ubuntu_mairie_menu',
        title   = Lang:t('menu.title'),
        options = options,
    })
    lib.showContext('ubuntu_mairie_menu')
end

-- --- PNJ + blips -------------------------------------------------------------
CreateThread(function()
    for _, p in ipairs(Config.Points) do
        local blip = AddBlipForCoord(p.coords.x, p.coords.y, p.coords.z)
        SetBlipSprite(blip, p.blip.sprite)
        SetBlipColour(blip, p.blip.color)
        SetBlipScale(blip, p.blip.scale or 0.9)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(p.label)
        EndTextCommandSetBlipName(blip)

        local model = GetHashKey(p.ped)
        RequestModel(model)
        local t = 0
        while not HasModelLoaded(model) and t < 100 do Wait(50); t = t + 1 end
        if HasModelLoaded(model) then
            local ped = CreatePed(4, model, p.coords.x, p.coords.y, p.coords.z - 1.0, p.coords.w, false, true)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetModelAsNoLongerNeeded(model)
            peds[#peds + 1] = ped
            p.__ped = ped
        end
    end
end)

-- Cale le PNJ + le marqueur sur le sol réel dès que le joueur est assez proche
-- pour que la map soit streamée (GetGroundZ fiable). Évite les PNJ/marqueurs
-- flottants ou enterrés quand le Z de la config n'est pas exact. Idempotent
-- (résultat mis en cache) et prudent : on ne déplace jamais un PNJ vers le niveau
-- de la mer si le sol n'est pas trouvé, ni de plus de 12 m.
local function groundSnap(rec, x, y, z)
    if rec.__gz then return rec.__gz end
    local ok, gz = GetGroundZFor_3dCoord(x + 0.0, y + 0.0, z + 3.0, false)
    if ok and gz > 0.5 and math.abs(gz - z) < 12.0 then
        rec.__gz = gz
        if rec.__ped and DoesEntityExist(rec.__ped) then
            SetEntityCoords(rec.__ped, x, y, gz, false, false, false, false)
        end
    end
    return rec.__gz
end

-- --- Interaction de proximité ------------------------------------------------
CreateThread(function()
    while true do
        local sleep = 1000
        local coords = GetEntityCoords(PlayerPedId())
        for _, p in ipairs(Config.Points) do
            local pv = vector3(p.coords.x, p.coords.y, p.coords.z)
            local dist = #(coords - pv)
            if dist < Config.DrawDistance then
                sleep = 0
                local c = Config.MarkerColor
                local baseZ = (groundSnap(p, pv.x, pv.y, pv.z) or (pv.z - 1.0)) + 0.02
                DrawMarker(1, pv.x, pv.y, baseZ, 0, 0, 0, 0, 0, 0, 1.5, 1.5, 0.5, c.r, c.g, c.b, 120, false, false, 2, false)
                if dist < Config.MarkerRadius then
                    DrawText3D(pv.x, pv.y, pv.z, Lang:t('prompt.open'))
                    if IsControlJustReleased(0, Config.InteractKey) then
                        openMairie()
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, ped in ipairs(peds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
end)
