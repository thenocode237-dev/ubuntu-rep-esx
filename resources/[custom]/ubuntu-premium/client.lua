local shopPed = nil
local isOpen = false

-- DrawText3D natif (remplace QBCore.Functions.DrawText3D).
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

-- Mapping nom de composant tenue -> id de composant GTA.
local COMPONENTS = {
    ['mask'] = 1, ['hair'] = 2, ['arms'] = 3, ['pants'] = 4, ['bag'] = 5,
    ['shoes'] = 6, ['accessory'] = 7, ['t-shirt'] = 8, ['vest'] = 9,
    ['decals'] = 10, ['torso2'] = 11,
}

-- Applique un skin (table de composants) au ped via natives GTA.
local function applyOutfit(skin)
    if type(skin) ~= 'table' then return end
    local ped = PlayerPedId()
    for name, comp in pairs(skin) do
        local id = COMPONENTS[name]
        if id and type(comp) == 'table' then
            SetPedComponentVariation(ped, id, comp.item or 0, comp.texture or 0, 0)
        end
    end
end

-- Poussé par le serveur à l'achat d'une tenue.
RegisterNetEvent('ubuntu-premium:client:applyOutfit', function(skin)
    applyOutfit(skin)
end)

-- --- Menu « Mes tenues » : re-porter une tenue achetée à volonté ------------
local function openOutfitsMenu()
    local data = lib.callback.await('ubuntu-premium:server:getOutfits', false)
    local outfits = data and data.outfits or {}
    if #outfits == 0 then
        return lib.notify({ description = Lang:t('outfit.none'), type = 'inform' })
    end
    local options = {}
    for _, o in ipairs(outfits) do
        options[#options + 1] = {
            title = o.name,
            icon = 'shirt',
            onSelect = function()
                applyOutfit(o.skin)
                TriggerServerEvent('ubuntu-premium:server:setLastOutfit', o.name)
                lib.notify({ description = Lang:t('outfit.worn', { name = o.name }), type = 'success' })
            end,
        }
    end
    lib.registerContext({ id = 'ubuntu_premium_outfits', title = Lang:t('outfit.menu_title'), options = options })
    lib.showContext('ubuntu_premium_outfits')
end

RegisterCommand('tenues', function() openOutfitsMenu() end, false)
RegisterKeyMapping('tenues', 'Ouvrir mes tenues premium', 'keyboard', '')

-- Ré-applique la dernière tenue portée au (re)spawn (après le chargement de la
-- peau de base par esx_skin/appearance).
AddEventHandler('esx:playerLoaded', function()
    CreateThread(function()
        Wait(4000)
        local data = lib.callback.await('ubuntu-premium:server:getOutfits', false)
        if not data or not data.last then return end
        for _, o in ipairs(data.outfits or {}) do
            if o.name == data.last then applyOutfit(o.skin); break end
        end
    end)
end)

-- --- Livraison immédiate d'un véhicule acheté (poussé par le serveur) --------
RegisterNetEvent('ubuntu-premium:client:spawnVehicle', function(data)
    if not data or not data.model then return end
    local model = GetHashKey(data.model)
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 100 do Wait(50); timeout = timeout + 1 end
    if not HasModelLoaded(model) then
        return lib.notify({ description = Lang:t('vehicle.spawn_failed'), type = 'error' })
    end

    local ped = PlayerPedId()
    local pc = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    -- Apparition devant le joueur.
    local fwd = GetEntityForwardVector(ped)
    local sx, sy = pc.x + fwd.x * 4.0, pc.y + fwd.y * 4.0
    local veh = CreateVehicle(model, sx, sy, pc.z, heading, true, false)
    while not DoesEntityExist(veh) do Wait(10) end
    SetVehicleNumberPlateText(veh, data.plate)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleFuelLevel(veh, 100.0)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleOnGroundProperly(veh)
    SetModelAsNoLongerNeeded(model)
    -- Pas de ressource de clés ESX en place → conduite libre (comme ubuntu-location).
    lib.notify({ description = Lang:t('vehicle.delivered', { plate = data.plate }), type = 'success' })
end)

-- --- Ouverture / fermeture de la boutique (NUI) -----------------------------

local function buildCatalogForUI()
    return { catalog = Config.Catalog, categories = Config.Categories, currency = Config.CurrencyName }
end

local function openShop()
    if isOpen then return end
    local store = lib.callback.await('ubuntu-premium:server:getStore', false)
    if not store then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        data = buildCatalogForUI(),
        balance = store.balance,
        owned = store.owned,
    })
end

local function closeShop()
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('buy', function(data, cb)
    if data and data.id then
        TriggerServerEvent('ubuntu-premium:server:buy', data.id)
    end
    cb('ok')
end)

RegisterNUICallback('close', function(_, cb)
    closeShop()
    cb('ok')
end)

-- Rafraîchissement poussé par le serveur après un achat.
RegisterNetEvent('ubuntu-premium:client:refresh', function(store)
    SendNUIMessage({ action = 'refresh', balance = store.balance, owned = store.owned })
end)

RegisterCommand('boutique', function() openShop() end, false)
RegisterKeyMapping('boutique', 'Ouvrir la boutique premium', 'keyboard', '')

-- --- PNJ + blip + marqueur de la boutique -----------------------------------

CreateThread(function()
    local blip = AddBlipForCoord(Config.Shop.coords.x, Config.Shop.coords.y, Config.Shop.coords.z)
    SetBlipSprite(blip, Config.Shop.blip.sprite)
    SetBlipColour(blip, Config.Shop.blip.color)
    SetBlipScale(blip, Config.Shop.blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Lang:t('misc.blip_name'))
    EndTextCommandSetBlipName(blip)

    local model = GetHashKey(Config.Shop.ped)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
    shopPed = CreatePed(4, model, Config.Shop.coords.x, Config.Shop.coords.y, Config.Shop.coords.z - 1.0, Config.Shop.coords.w, false, true)
    FreezeEntityPosition(shopPed, true)
    SetEntityInvincible(shopPed, true)
    SetBlockingOfNonTemporaryEvents(shopPed, true)
    SetModelAsNoLongerNeeded(model)
end)

-- Interaction de proximité.
CreateThread(function()
    local shopVec = vector3(Config.Shop.coords.x, Config.Shop.coords.y, Config.Shop.coords.z)
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local dist = #(GetEntityCoords(ped) - shopVec)
        if dist < 15.0 then
            sleep = 0
            local c = Config.Shop.markerColor
            DrawMarker(1, shopVec.x, shopVec.y, shopVec.z - 0.98, 0, 0, 0, 0, 0, 0, 1.2, 1.2, 0.5, c.r, c.g, c.b, 120, false, false, 2, false)
            if dist < 1.6 then
                DrawText3D(shopVec.x, shopVec.y, shopVec.z, Lang:t('misc.open_prompt'))
                if IsControlJustReleased(0, 38) then -- E
                    openShop()
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and shopPed then
        DeleteEntity(shopPed)
    end
end)
