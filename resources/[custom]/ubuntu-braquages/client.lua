local busy = false -- un seul braquage à la fois côté client

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

-- Le joueur tient-il une arme (braquage à main armée) ?
local function weaponDrawn()
    return GetSelectedPedWeapon(PlayerPedId()) ~= GetHashKey('WEAPON_UNARMED')
end

local function findTarget(id)
    for _, t in ipairs(Config.Targets) do
        if t.id == id then return t end
    end
    return nil
end

-- --- Intention de démarrage (validée côté serveur) --------------------------
local function attemptStart(target)
    if busy then return end
    if target.needWeapon and not weaponDrawn() then
        return lib.notify({ description = Lang:t('error.need_weapon'), type = 'error' })
    end
    TriggerServerEvent('ubuntu-braquages:server:start', target.id)
end

-- --- Barre de progression du braquage (pilotée par le serveur) --------------
RegisterNetEvent('ubuntu-braquages:client:begin', function(data)
    if busy or not data or not data.targetId then return end
    local target = findTarget(data.targetId)
    if not target then return end
    busy = true

    lib.notify({ description = Lang:t('info.started', { label = target.label }), type = 'inform' })

    local ok = lib.progressBar({
        duration = data.duration,
        label = Lang:t('progress.' .. target.type),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'mp_common', clip = 'givetake1_a', flag = 49 },
    })

    ClearPedTasks(PlayerPedId())
    busy = false
    if ok then
        TriggerServerEvent('ubuntu-braquages:server:finish', target.id)
    else
        TriggerServerEvent('ubuntu-braquages:server:cancel', target.id)
        lib.notify({ description = Lang:t('error.cancelled'), type = 'error' })
    end
end)

-- --- Alerte Police : blip clignotant temporaire -----------------------------
RegisterNetEvent('ubuntu-braquages:client:alert', function(data)
    if not data or not data.coords then return end
    local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
    SetBlipSprite(blip, 161)          -- braquage
    SetBlipColour(blip, 1)            -- rouge
    SetBlipScale(blip, 1.2)
    SetBlipAsShortRange(blip, false)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Lang:t('alert.blip'))
    EndTextCommandSetBlipName(blip)
    SetTimeout(Config.AlertBlipDuration, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end)

-- Cale le marqueur sur le sol réel dès que le joueur est assez proche pour que la
-- map soit streamée (GetGroundZ fiable). Évite un marqueur flottant/enterré quand
-- le Z de la config n'est pas exact. Idempotent (résultat mis en cache) et prudent
-- (ignore un sol < 0.5 m ou un écart > 12 m → garde le Z de config en repli).
local function groundSnap(rec, x, y, z)
    if rec.__gz then return rec.__gz end
    local ok, gz = GetGroundZFor_3dCoord(x + 0.0, y + 0.0, z + 3.0, false)
    if ok and gz > 0.5 and math.abs(gz - z) < 12.0 then
        rec.__gz = gz
    end
    return rec.__gz
end

-- --- Interaction de proximité (marqueur + prompt E) -------------------------
CreateThread(function()
    while true do
        local sleep = 1000
        local coords = GetEntityCoords(PlayerPedId())
        for _, target in ipairs(Config.Targets) do
            local tc = vector3(target.coords.x, target.coords.y, target.coords.z)
            local dist = #(coords - tc)
            if dist < Config.DrawDistance then
                sleep = 0
                local c = Config.MarkerColor
                local baseZ = (groundSnap(target, tc.x, tc.y, tc.z) or (tc.z - 1.0)) + 0.02
                DrawMarker(1, tc.x, tc.y, baseZ, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 0.5, c.r, c.g, c.b, 120, false, false, 2, false)
                if dist < Config.MarkerRadius and not busy then
                    DrawText3D(tc.x, tc.y, tc.z, Lang:t('misc.prompt', { label = target.label }))
                    if IsControlJustReleased(0, Config.InteractKey) then
                        attemptStart(target)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)
