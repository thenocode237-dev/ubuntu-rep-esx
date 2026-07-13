local peds = {}
local rentedPlates = {} -- { [plate] = true } : locations en cours pour ce joueur

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

local function formatMoney(amount)
    local s = tostring(math.floor(amount or 0))
    return '$' .. (s:reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^%s+', ''))
end

local function normalizePlate(plate)
    return (plate or ''):gsub('%s+', ''):upper()
end

-- --- Menu de location (ox_lib) ----------------------------------------------

local function hasActiveRental()
    return next(rentedPlates) ~= nil
end

local function openMenu(point)
    local options = {}
    for _, v in ipairs(point.vehicles) do
        options[#options + 1] = {
            title = v.label,
            description = Lang:t('menu.price', { fee = formatMoney(v.fee), deposit = formatMoney(v.deposit) }),
            icon = 'motorcycle',
            onSelect = function()
                TriggerServerEvent('ubuntu-location:server:rent', point.id, v.model)
            end,
        }
    end
    if hasActiveRental() then
        options[#options + 1] = {
            title = Lang:t('menu.return'),
            description = Lang:t('menu.return_desc'),
            icon = 'rotate-left',
            onSelect = function() TriggerEvent('ubuntu-location:client:returnVehicle') end,
        }
    end
    lib.registerContext({ id = 'ubuntu_location', title = point.label, options = options })
    lib.showContext('ubuntu_location')
end

-- --- Apparition du véhicule loué (piloté par le serveur après débit) --------

RegisterNetEvent('ubuntu-location:client:spawnRental', function(data)
    if not data or not data.model then return end
    local model = GetHashKey(data.model)
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 100 do Wait(50); timeout = timeout + 1 end
    if not HasModelLoaded(model) then
        return lib.notify({ description = Lang:t('error.spawn_failed'), type = 'error' })
    end

    local s = data.spawn
    local veh = CreateVehicle(model, s.x, s.y, s.z, s.w, true, false)
    while not DoesEntityExist(veh) do Wait(10) end
    SetVehicleNumberPlateText(veh, data.plate)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleFuelLevel(veh, 100.0)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleEngineOn(veh, true, true, false)
    SetPedIntoVehicle(PlayerPedId(), veh, -1)
    SetModelAsNoLongerNeeded(model)

    -- Clés : si une ressource de clés ESX est en place, donner les clés ici
    -- (ex. exports['<keys>']:GiveKeys(plate)). Sans elle, aucun verrou = conduite libre.
    rentedPlates[normalizePlate(data.plate)] = true
end)

-- --- Restitution : trouve un véhicule loué proche, le supprime, rembourse ---

RegisterNetEvent('ubuntu-location:client:returnVehicle', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) then
            local plate = normalizePlate(GetVehicleNumberPlateText(veh))
            if rentedPlates[plate] and #(coords - GetEntityCoords(veh)) < 30.0 then
                rentedPlates[plate] = nil
                if IsPedInVehicle(ped, veh, false) then
                    TaskLeaveVehicle(ped, veh, 0)
                    Wait(800)
                end
                SetEntityAsMissionEntity(veh, true, true)
                DeleteVehicle(veh)
                TriggerServerEvent('ubuntu-location:server:return', plate)
                return
            end
        end
    end
    lib.notify({ description = Lang:t('error.no_vehicle_nearby'), type = 'error' })
end)

-- --- Blips, PNJ et interaction de proximité --------------------------------

CreateThread(function()
    for _, point in ipairs(Config.Points) do
        local blip = AddBlipForCoord(point.coords.x, point.coords.y, point.coords.z)
        SetBlipSprite(blip, point.blip.sprite)
        SetBlipColour(blip, point.blip.color)
        SetBlipScale(blip, point.blip.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(point.label)
        EndTextCommandSetBlipName(blip)

        local model = GetHashKey(point.ped)
        RequestModel(model)
        local t = 0
        while not HasModelLoaded(model) and t < 100 do Wait(50); t = t + 1 end
        if HasModelLoaded(model) then
            local ped = CreatePed(4, model, point.coords.x, point.coords.y, point.coords.z - 1.0, point.coords.w, false, true)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetModelAsNoLongerNeeded(model)
            peds[#peds + 1] = ped
        end
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000
        local coords = GetEntityCoords(PlayerPedId())
        for _, point in ipairs(Config.Points) do
            local pv = vector3(point.coords.x, point.coords.y, point.coords.z)
            local dist = #(coords - pv)
            if dist < Config.DrawDistance then
                sleep = 0
                local c = Config.MarkerColor
                DrawMarker(1, pv.x, pv.y, pv.z - 0.98, 0, 0, 0, 0, 0, 0, 1.2, 1.2, 0.5, c.r, c.g, c.b, 120, false, false, 2, false)
                if dist < Config.MarkerRadius then
                    DrawText3D(pv.x, pv.y, pv.z, Lang:t('misc.open_prompt'))
                    if IsControlJustReleased(0, Config.InteractKey) then
                        openMenu(point)
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
