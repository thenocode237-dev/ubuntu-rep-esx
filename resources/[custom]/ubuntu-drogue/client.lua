local peds = {}      -- PNJ grossiste
local busy = false   -- une transaction à la fois

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

-- Zone chaude courante (ou nil).
local function currentZone()
    local c = GetEntityCoords(PlayerPedId())
    for _, z in ipairs(Config.Zones) do
        if #(c - z.center) <= z.radius then return z end
    end
    return nil
end

-- PNJ acheteur le plus proche (ambient, à pied, vivant, non-joueur).
local function nearestBuyer()
    local self = PlayerPedId()
    local coords = GetEntityCoords(self)
    local closest, cd = nil, Config.SellRadius + 0.01
    for _, p in ipairs(GetGamePool('CPed')) do
        if p ~= self and DoesEntityExist(p) and not IsPedAPlayer(p)
            and not IsEntityDead(p) and not IsPedInAnyVehicle(p, false) then
            local d = #(coords - GetEntityCoords(p))
            if d < cd then cd = d; closest = p end
        end
    end
    return closest
end

-- --- Vente de rue : uniquement dans une zone chaude, près d'un PNJ ----------
CreateThread(function()
    while true do
        local sleep = 1000
        local zone = currentZone()
        if zone and not busy then
            sleep = 5
            local buyer = nearestBuyer()
            if buyer then
                local bc = GetEntityCoords(buyer)
                DrawText3D(bc.x, bc.y, bc.z + 0.9, Lang:t('misc.sell_prompt'))
                if IsControlJustReleased(0, Config.InteractKey) then
                    busy = true
                    local ped = PlayerPedId()
                    TaskTurnPedToFaceEntity(ped, buyer, 800)
                    RequestAnimDict('mp_common')
                    local t = 0
                    while not HasAnimDictLoaded('mp_common') and t < 50 do Wait(10); t = t + 1 end
                    TaskPlayAnim(ped, 'mp_common', 'givetake1_a', 8.0, -8.0, 1400, 49, 0, false, false, false)
                    Wait(1200)
                    ClearPedTasks(ped)
                    TriggerServerEvent('ubuntu-drogue:server:sell', zone.id)
                    Wait(Config.SellCooldown * 1000)
                    busy = false
                end
            end
        end
        Wait(sleep)
    end
end)

-- --- Grossiste : menu d'achat (ox_lib) --------------------------------------
local function openSupplier()
    local options = {}
    for _, e in ipairs(Config.Supplier.stock) do
        options[#options + 1] = {
            title = e.label,
            description = Lang:t('menu.buy_price', { amount = ('$%d'):format(e.price) }),
            icon = 'coins',
            onSelect = function()
                TriggerServerEvent('ubuntu-drogue:server:buy', e.item)
            end,
        }
    end
    lib.registerContext({ id = 'ubuntu_drogue_supplier', title = Config.Supplier.label, options = options })
    lib.showContext('ubuntu_drogue_supplier')
end

-- --- Alerte Police : blip clignotant temporaire -----------------------------
RegisterNetEvent('ubuntu-drogue:client:alert', function(data)
    if not data or not data.coords then return end
    local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
    SetBlipSprite(blip, 51)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.1)
    SetBlipAsShortRange(blip, false)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Lang:t('alert.blip'))
    EndTextCommandSetBlipName(blip)
    SetTimeout(Config.AlertBlipDuration, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end)

-- --- Blip + PNJ grossiste ---------------------------------------------------
CreateThread(function()
    local s = Config.Supplier
    if s.blip then
        local blip = AddBlipForCoord(s.coords.x, s.coords.y, s.coords.z)
        SetBlipSprite(blip, s.blip.sprite)
        SetBlipColour(blip, s.blip.color)
        SetBlipScale(blip, s.blip.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(s.label)
        EndTextCommandSetBlipName(blip)
    end

    local model = GetHashKey(s.ped)
    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) and t < 100 do Wait(50); t = t + 1 end
    if HasModelLoaded(model) then
        local ped = CreatePed(4, model, s.coords.x, s.coords.y, s.coords.z - 1.0, s.coords.w, false, true)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetModelAsNoLongerNeeded(model)
        peds[#peds + 1] = ped
    end
end)

-- --- Interaction de proximité au grossiste ----------------------------------
CreateThread(function()
    while true do
        local sleep = 1000
        local s = Config.Supplier
        local coords = GetEntityCoords(PlayerPedId())
        local sv = vector3(s.coords.x, s.coords.y, s.coords.z)
        local dist = #(coords - sv)
        if dist < Config.DrawDistance then
            sleep = 0
            local c = Config.MarkerColor
            DrawMarker(1, sv.x, sv.y, sv.z - 0.98, 0, 0, 0, 0, 0, 0, 1.2, 1.2, 0.5, c.r, c.g, c.b, 120, false, false, 2, false)
            if dist < Config.MarkerRadius then
                DrawText3D(sv.x, sv.y, sv.z, Lang:t('misc.supplier_prompt'))
                if IsControlJustReleased(0, Config.InteractKey) then
                    openSupplier()
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
