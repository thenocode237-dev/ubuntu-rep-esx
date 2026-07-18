local peds = {}
local zones = {}          -- ids ox_target a nettoyer
local isInside = false     -- le joueur est-il dans l'interieur de la boite ?
local lastEntrance = nil   -- entree utilisee (pour ressortir au meme endroit)
local musicPlaying = false

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

local function formatMoney(amount)
    local s = tostring(math.floor(amount or 0))
    return (s:reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^%s+', '')) .. ' $'
end

-- Cale le PNJ + le marqueur sur le sol reel (comme ubuntu-banque). Prudent :
-- jamais de teleportation au niveau de la mer, jamais un ecart > 12 m.
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

-- --- Ambiance musicale (NUI auto-contenue, comme ubuntu-loadscreen) ----------
local function setMusic(state)
    if state == musicPlaying then return end
    musicPlaying = state
    SendNUIMessage({ action = state and 'play' or 'stop' })
end

-- --- Teleportation + chargement de l'interieur natif ------------------------
local function teleportTo(v)
    DoScreenFadeOut(400)
    local ft = 0
    while not IsScreenFadedOut() and ft < 40 do Wait(10); ft = ft + 1 end

    local ped = PlayerPedId()
    SetEntityCoords(ped, v.x, v.y, v.z, false, false, false, false)
    SetEntityHeading(ped, v.w or 0.0)

    -- Charge/habille l'interieur natif de la discotheque (After Hours).
    local interior = GetInteriorAtCoords(v.x, v.y, v.z)
    if interior ~= 0 then
        LoadInterior(interior)
        for _, es in ipairs(Config.Interior.entitySets or {}) do
            if not IsInteriorEntitySetActive(interior, es) then
                ActivateInteriorEntitySet(interior, es)
            end
        end
        RefreshInterior(interior)
    end

    local t = 0
    while not HasCollisionLoadedAroundEntity(ped) and t < 100 do
        RequestCollisionAtCoord(v.x, v.y, v.z)
        Wait(50); t = t + 1
    end
    Wait(200)
    DoScreenFadeIn(500)
end

-- --- Menus (bar / DJ) -------------------------------------------------------
local function openBar()
    local options = {}
    for _, d in ipairs(Config.Bar.drinks) do
        options[#options + 1] = {
            title = Lang:t('menu.drink', { label = d.label, price = formatMoney(d.price) }),
            icon = 'wine-glass',
            onSelect = function() TriggerServerEvent('ubuntu-boite:server:buyDrink', d.item) end,
        }
    end
    lib.registerContext({ id = 'ubuntu_boite_bar', title = Lang:t('menu.bar_title'), options = options })
    lib.showContext('ubuntu_boite_bar')
end

local function openDj()
    local on = GlobalState.boiteMusic == true
    lib.registerContext({
        id = 'ubuntu_boite_dj',
        title = Lang:t('menu.dj_title'),
        options = {
            {
                title = on and Lang:t('menu.dj_off') or Lang:t('menu.dj_on'),
                description = on and Lang:t('menu.dj_off_desc') or Lang:t('menu.dj_on_desc'),
                icon = 'music',
                onSelect = function() TriggerServerEvent('ubuntu-boite:server:toggleMusic') end,
            },
        },
    })
    lib.showContext('ubuntu_boite_dj')
end

-- --- Entrees exterieures : PNJ videur + blips ------------------------------
CreateThread(function()
    for _, e in ipairs(Config.Entrances) do
        local blip = AddBlipForCoord(e.coords.x, e.coords.y, e.coords.z)
        SetBlipSprite(blip, e.blip.sprite)
        SetBlipColour(blip, e.blip.color)
        SetBlipScale(blip, e.blip.scale or 0.9)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(e.label)
        EndTextCommandSetBlipName(blip)

        local model = GetHashKey(e.ped)
        RequestModel(model)
        local t = 0
        while not HasModelLoaded(model) and t < 100 do Wait(50); t = t + 1 end
        if HasModelLoaded(model) then
            local ped = CreatePed(4, model, e.coords.x, e.coords.y, e.coords.z - 1.0, e.coords.w, false, true)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetModelAsNoLongerNeeded(model)
            peds[#peds + 1] = ped
            e.__ped = ped
        end
    end
end)

-- Marqueur [E] a l'entree → tente d'entrer (frais valides cote serveur).
CreateThread(function()
    while true do
        local sleep = 1000
        local coords = GetEntityCoords(PlayerPedId())
        for _, e in ipairs(Config.Entrances) do
            local ev = vector3(e.coords.x, e.coords.y, e.coords.z)
            local dist = #(coords - ev)
            if dist < Config.DrawDistance then
                sleep = 0
                local c = Config.MarkerColor
                local baseZ = (groundSnap(e, ev.x, ev.y, ev.z) or (ev.z - 1.0)) + 0.02
                DrawMarker(1, ev.x, ev.y, baseZ, 0, 0, 0, 0, 0, 0, 1.2, 1.2, 0.5, c.r, c.g, c.b, 120, false, false, 2, false)
                if dist < Config.MarkerRadius then
                    DrawText3D(ev.x, ev.y, ev.z, Lang:t('prompt.enter'))
                    if IsControlJustReleased(0, Config.InteractKey) then
                        local ok = lib.callback.await('ubuntu-boite:server:tryEnter', false)
                        if ok then
                            lastEntrance = e.coords
                            isInside = true
                            teleportTo(Config.Interior.inside)
                            lib.notify({ description = Lang:t('success.entered'), type = 'success' })
                        else
                            lib.notify({ description = Lang:t('error.no_entry'), type = 'error' })
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- Marqueur [E] a la sortie interieure → ressort a l'entree utilisee.
CreateThread(function()
    while true do
        local sleep = 1000
        if isInside then
            local coords = GetEntityCoords(PlayerPedId())
            local xv = Config.Interior.exit
            local dist = #(coords - vector3(xv.x, xv.y, xv.z))
            if dist < Config.DrawDistance then
                sleep = 0
                local c = Config.MarkerColor
                DrawMarker(1, xv.x, xv.y, xv.z - 0.98, 0, 0, 0, 0, 0, 0, 1.2, 1.2, 0.5, c.r, c.g, c.b, 120, false, false, 2, false)
                if dist < Config.MarkerRadius then
                    DrawText3D(xv.x, xv.y, xv.z, Lang:t('prompt.exit'))
                    if IsControlJustReleased(0, Config.InteractKey) then
                        isInside = false
                        teleportTo(lastEntrance or Config.Entrances[1].coords)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- --- Bar + DJ : ciblage ox_target (zones a l'interieur) ---------------------
CreateThread(function()
    local bar = Config.Bar.zone
    zones[#zones + 1] = exports.ox_target:addBoxZone({
        coords = bar.coords,
        size = bar.size,
        rotation = bar.rotation or 0.0,
        options = {
            { name = 'ubuntu_boite_bar', label = Lang:t('prompt.bar'), icon = 'fas fa-martini-glass', distance = 2.0, onSelect = openBar },
        },
    })
    local dj = Config.Dj.zone
    zones[#zones + 1] = exports.ox_target:addBoxZone({
        coords = dj.coords,
        size = dj.size,
        rotation = dj.rotation or 0.0,
        options = {
            { name = 'ubuntu_boite_dj', label = Lang:t('prompt.dj'), icon = 'fas fa-headphones', distance = 2.0, onSelect = openDj },
        },
    })
end)

-- --- Ambiance : joue la musique quand on est dedans + DJ actif ---------------
CreateThread(function()
    while true do
        setMusic(isInside and GlobalState.boiteMusic == true)
        Wait(500)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    setMusic(false)
    for _, ped in ipairs(peds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    for _, id in ipairs(zones) do
        if id then exports.ox_target:removeZone(id) end
    end
end)
