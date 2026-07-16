local peds = {}
local ownedPlates = {}       -- { [plate] = true } : plaques possédées (détection à l'entrée / verrou)
local gpsBlips = {}          -- [plate] = blip GPS (véhicules sortis)
local refreshOwnedPlates     -- forward declaration (défini plus bas)

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

local function normalizePlate(plate)
    return (plate or ''):gsub('%s+$', '')
end

-- Libellé lisible d'un modèle (sinon nil).
local function modelLabel(model)
    if not model then return nil end
    local dn = GetDisplayNameFromVehicleModel(model + 0)
    if dn and dn ~= '' and dn ~= 'CARNOTFOUND' then
        local lbl = GetLabelText(dn)
        if lbl and lbl ~= 'NULL' and lbl ~= '' then return lbl end
        return dn
    end
    return nil
end

-- --- Sortir un véhicule : liste des véhicules rangés -------------------------

local function openTakeMenu(garageId)
    local list = lib.callback.await('ubuntu-garage:server:list', false) or {}
    if #list == 0 then
        return lib.notify({ description = Lang:t('menu.none'), type = 'inform' })
    end
    local options = {}
    for _, v in ipairs(list) do
        options[#options + 1] = {
            title = modelLabel(v.model) or v.plate,
            description = Lang:t('menu.plate', { plate = v.plate }),
            icon = 'car',
            onSelect = function()
                TriggerServerEvent('ubuntu-garage:server:spawn', v.plate, garageId)
            end,
        }
    end
    lib.registerContext({ id = 'ubuntu_garage_take', title = Lang:t('menu.take'), options = options })
    lib.showContext('ubuntu_garage_take')
end

-- --- Ranger : trouve un véhicule proche appartenant au joueur ----------------

local function storeNearbyVehicle()
    local ped = PlayerPedId()
    local plate
    if IsPedInAnyVehicle(ped, false) then
        plate = GetVehicleNumberPlateText(GetVehiclePedIsIn(ped, false))
    else
        local coords = GetEntityCoords(ped)
        local best, bestDist = nil, Config.StoreRadius
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if DoesEntityExist(veh) then
                local d = #(coords - GetEntityCoords(veh))
                if d < bestDist then best, bestDist = veh, d end
            end
        end
        if best then plate = GetVehicleNumberPlateText(best) end
    end
    if not plate then
        return lib.notify({ description = Lang:t('error.no_vehicle_near'), type = 'error' })
    end
    TriggerServerEvent('ubuntu-garage:server:store', normalizePlate(plate))
end

-- --- Menu du garage ----------------------------------------------------------

local function openGarage(garageId)
    lib.registerContext({
        id = 'ubuntu_garage_menu',
        title = Lang:t('menu.title'),
        options = {
            { title = Lang:t('menu.take'),  description = Lang:t('menu.take_desc'),  icon = 'warehouse',  onSelect = function() openTakeMenu(garageId) end },
            { title = Lang:t('menu.store'), description = Lang:t('menu.store_desc'), icon = 'square-parking', onSelect = storeNearbyVehicle },
        },
    })
    lib.showContext('ubuntu_garage_menu')
end

-- --- Warp / suppression pilotés par le serveur ------------------------------

RegisterNetEvent('ubuntu-garage:client:enterVehicle', function(netId)
    local timeout = 0
    while not NetworkDoesEntityExistWithNetworkId(netId) and timeout < 100 do Wait(20); timeout = timeout + 1 end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh and veh ~= 0 then
        local t = 0
        while not DoesEntityExist(veh) and t < 50 do Wait(20); t = t + 1 end
        if DoesEntityExist(veh) then
            SetVehicleEngineOn(veh, true, true, false)
            TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
        end
    end
    refreshOwnedPlates() -- la plaque sortie devient « la mienne » (verrou/GPS)
end)

RegisterNetEvent('ubuntu-garage:client:deleteVehicle', function(plate)
    plate = normalizePlate(plate)
    local coords = GetEntityCoords(PlayerPedId())
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) and normalizePlate(GetVehicleNumberPlateText(veh)) == plate then
            if #(coords - GetEntityCoords(veh)) < 60.0 then
                SetEntityAsMissionEntity(veh, true, true)
                DeleteVehicle(veh)
                return
            end
        end
    end
end)

-- ============================================================================
-- Clés (verrou anti-vol) + GPS des véhicules sortis
-- ============================================================================
refreshOwnedPlates = function()
    ownedPlates = lib.callback.await('ubuntu-garage:server:myPlates', false) or {}
end

-- Statebag verrou → appliqué sur TOUS les clients (réplicable, résiste au streaming).
AddStateBagChangeHandler('ubuntuLock', nil, function(bagName, _, value)
    local ent = GetEntityFromStateBagName(bagName)
    if ent and ent ~= 0 and DoesEntityExist(ent) then
        SetVehicleDoorsLocked(ent, value and 2 or 1)
        SetVehicleDoorsLockedForAllPlayers(ent, value == true)
    end
end)

-- Retour visuel/sonore au propriétaire (klaxon + phares).
RegisterNetEvent('ubuntu-garage:client:lockFeedback', function(netId, locked)
    if not Config.Keys.honk then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    SetVehicleLights(veh, 2)
    StartVehicleHorn(veh, 150, `HELDDOWN`, false)
    Wait(200)
    SetVehicleLights(veh, 0)
end)

-- Véhicule ciblé par le verrou : celui où on est, sinon le plus proche possédé.
local function targetOwnedVehicle()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        return veh, normalizePlate(GetVehicleNumberPlateText(veh))
    end
    local coords = GetEntityCoords(ped)
    local best, bestPlate, bestDist = nil, nil, Config.Keys.reach
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) then
            local plate = normalizePlate(GetVehicleNumberPlateText(veh))
            if ownedPlates[plate] then
                local d = #(coords - GetEntityCoords(veh))
                if d < bestDist then best, bestPlate, bestDist = veh, plate, d end
            end
        end
    end
    return best, bestPlate
end

RegisterCommand('ubuntu_veh_lock', function()
    local ped = PlayerPedId()
    local veh, plate
    if IsPedInAnyVehicle(ped, false) then
        -- Dans un véhicule : on cible celui-ci (le serveur valide la possession
        -- dans owned_vehicles — pas de dépendance au cache client, qui peut être
        -- périmé juste après un achat au concessionnaire).
        veh = GetVehiclePedIsIn(ped, false)
        plate = normalizePlate(GetVehicleNumberPlateText(veh))
    else
        refreshOwnedPlates() -- set frais pour la détection à pied
        veh, plate = targetOwnedVehicle()
    end
    if not veh or not plate then
        return lib.notify({ description = Lang:t('error.no_owned_near'), type = 'error' })
    end
    TriggerServerEvent('ubuntu-garage:server:toggleLock', NetworkGetNetworkIdFromEntity(veh), plate)
end, false)
RegisterKeyMapping('ubuntu_veh_lock', 'Verrouiller / déverrouiller son véhicule', 'keyboard', Config.Keys.key)

-- Enregistre le véhicule possédé où l'on monte (pour GPS + verrou serveur).
CreateThread(function()
    local lastVeh = 0
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= lastVeh then
                lastVeh = veh
                local plate = normalizePlate(GetVehicleNumberPlateText(veh))
                if ownedPlates[plate] then
                    TriggerServerEvent('ubuntu-garage:server:register', NetworkGetNetworkIdFromEntity(veh), plate)
                    -- Le joueur est dedans → retrait immédiat du blip GPS (sans attendre
                    -- le cycle de rafraîchissement) ; il réapparaîtra à la sortie.
                    if gpsBlips[plate] then
                        if DoesBlipExist(gpsBlips[plate]) then RemoveBlip(gpsBlips[plate]) end
                        gpsBlips[plate] = nil
                    end
                end
            end
        else
            lastVeh = 0
        end
    end
end)

-- GPS : un blip suit chaque véhicule possédé sorti (position lue côté serveur).
-- Le blip ne s'affiche QUE quand le véhicule est garé dehors : dès que le joueur
-- est assis dedans, on masque son blip (inutile de se guider vers soi-même).
CreateThread(function()
    if not Config.Gps.enabled then return end
    while true do
        Wait(Config.Gps.refresh)
        local list = lib.callback.await('ubuntu-garage:server:myVehicles', false) or {}
        -- Plaque du véhicule actuellement occupé par le joueur (à exclure du GPS).
        local ped = PlayerPedId()
        local insidePlate = IsPedInAnyVehicle(ped, false)
            and normalizePlate(GetVehicleNumberPlateText(GetVehiclePedIsIn(ped, false)))
            or nil
        local seen = {}
        for _, v in ipairs(list) do
            if v.plate == insidePlate then
                -- Joueur à l'intérieur : pas de blip (retiré plus bas car non « vu »).
            elseif gpsBlips[v.plate] and DoesBlipExist(gpsBlips[v.plate]) then
                seen[v.plate] = true
                SetBlipCoords(gpsBlips[v.plate], v.x, v.y, v.z)
            else
                seen[v.plate] = true
                local b = AddBlipForCoord(v.x, v.y, v.z)
                SetBlipSprite(b, Config.Gps.sprite)
                SetBlipColour(b, Config.Gps.color)
                SetBlipScale(b, Config.Gps.scale)
                SetBlipAsShortRange(b, false)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName(Lang:t('gps.blip', { plate = v.plate }))
                EndTextCommandSetBlipName(b)
                gpsBlips[v.plate] = b
            end
        end
        for plate, b in pairs(gpsBlips) do
            if not seen[plate] then
                if DoesBlipExist(b) then RemoveBlip(b) end
                gpsBlips[plate] = nil
            end
        end
    end
end)

AddEventHandler('esx:playerLoaded', function()
    Wait(2000)
    refreshOwnedPlates()
end)

CreateThread(function()
    Wait(3000)
    while true do
        refreshOwnedPlates() -- garde le set frais (achats concession, garage…)
        Wait(30000)
    end
end)

-- --- PNJ + blips + interaction de proximité ---------------------------------

CreateThread(function()
    for _, g in ipairs(Config.Garages) do
        local blip = AddBlipForCoord(g.coords.x, g.coords.y, g.coords.z)
        SetBlipSprite(blip, g.blip.sprite)
        SetBlipColour(blip, g.blip.color)
        SetBlipScale(blip, g.blip.scale or 0.8)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(g.label)
        EndTextCommandSetBlipName(blip)

        local model = GetHashKey(g.ped)
        RequestModel(model)
        local t = 0
        while not HasModelLoaded(model) and t < 100 do Wait(50); t = t + 1 end
        if HasModelLoaded(model) then
            local ped = CreatePed(4, model, g.coords.x, g.coords.y, g.coords.z - 1.0, g.coords.w, false, true)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetModelAsNoLongerNeeded(model)
            peds[#peds + 1] = ped
            g.__ped = ped
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

CreateThread(function()
    while true do
        local sleep = 1000
        local coords = GetEntityCoords(PlayerPedId())
        for _, g in ipairs(Config.Garages) do
            local gv = vector3(g.coords.x, g.coords.y, g.coords.z)
            local dist = #(coords - gv)
            if dist < Config.DrawDistance then
                sleep = 0
                local c = Config.MarkerColor
                local baseZ = (groundSnap(g, gv.x, gv.y, gv.z) or (gv.z - 1.0)) + 0.02
                DrawMarker(1, gv.x, gv.y, baseZ, 0, 0, 0, 0, 0, 0, 1.5, 1.5, 0.5, c.r, c.g, c.b, 120, false, false, 2, false)
                if dist < Config.MarkerRadius then
                    DrawText3D(gv.x, gv.y, gv.z, Lang:t('prompt.open'))
                    if IsControlJustReleased(0, Config.InteractKey) then
                        openGarage(g.id)
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
    for _, b in pairs(gpsBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
end)
