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

-- Les véhicules achetés sont désormais livrés dans le garage (owned_vehicles,
-- stored=1) et récupérés via ubuntu-garage — plus de spawn immédiat ici.

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
    Config.Shop.__ped = shopPed
end)

-- Cale le PNJ + le marqueur sur le sol réel dès que le joueur est assez proche
-- pour que la map soit streamée (GetGroundZ fiable). Évite un PNJ/marqueur
-- flottant ou enterré quand le Z de la config n'est pas exact. Idempotent
-- (résultat mis en cache) et prudent : on ne déplace jamais le PNJ vers le niveau
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
            local baseZ = (groundSnap(Config.Shop, shopVec.x, shopVec.y, shopVec.z) or (shopVec.z - 1.0)) + 0.02
            DrawMarker(1, shopVec.x, shopVec.y, baseZ, 0, 0, 0, 0, 0, 0, 1.2, 1.2, 0.5, c.r, c.g, c.b, 120, false, false, 2, false)
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
