-- Ubuntu RP — anti-chute au spawn
-- ---------------------------------------------------------------------------
-- Symptome corrige :
--   Au demarrage, le personnage tombe / reste au sol, parfois "blesse - appelez
--   les secours" puis reveil sur un lit d'hopital, ou chute libre jusque dans les
--   egouts.
--
-- Cause :
--   Le spawn (spawnmanager / esx_identity) place le joueur avec SetEntityCoords PUIS le
--   degele (FreezeEntityPosition false) AVANT que la collision de la map ne soit
--   streamee autour de lui. Le ped tombe donc a travers le monde (egouts / vide),
--   encaisse d'enormes degats de chute -> esx_ambulancejob (Phase 2) le passe en
--   blesse/mort -> reveil a l'hopital. Les trois symptomes ont cette meme origine.
--
-- Correctif :
--   A chaque chargement du joueur (nouveau perso, reconnexion, reanimation),
--   on RE-gele le ped et on force le chargement de la collision autour de son point
--   de spawn ; on ne le relache que lorsque la collision est prete (garde-fou 15 s).
--   On re-affirme le gel a chaque tick pour gagner la course contre le
--   FreezeEntityPosition(false) du spawn (aucun fichier upstream n'est modifie
--   -> survit a un re-pin des ressources).
--
--   En mono-personnage (sans multichar), c'est aussi cette ressource qui FERME le
--   loadscreen (ShutdownLoadingScreenNui) au premier chargement, car le template
--   utilise loadscreen_manual_shutdown 'yes'.
-- ---------------------------------------------------------------------------

local groundingInProgress = false

local function groundPlayerSafely()
    if groundingInProgress then return end
    groundingInProgress = true

    CreateThread(function()
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local sx, sy = pos.x, pos.y

        -- Z de référence pour streamer la collision AU BON ENDROIT. Si le ped est
        -- déjà passé SOUS la map (z bas), on le remonte au niveau ville — sinon la
        -- collision « chargerait » autour du vide souterrain (sans sol).
        local refZ = pos.z
        if refZ < 20.0 then refZ = 60.0 end

        -- Fige et remonte immédiatement le ped au niveau de référence.
        FreezeEntityPosition(ped, true)
        SetEntityCoordsNoOffset(ped, sx, sy, refZ, false, false, false)

        local timeout = GetGameTimer() + 20000 -- garde-fou : 20 s maximum
        while GetGameTimer() < timeout do
            ped = PlayerPedId()
            -- Ré-affirme le gel à chaque tick (gagne la course contre le
            -- FreezePlayer(false) d'es_extended) et force la collision autour du point.
            FreezeEntityPosition(ped, true)
            RequestCollisionAtCoord(sx, sy, refZ)

            if HasCollisionLoadedAroundEntity(ped) then
                -- Collision prête : on POSE le ped sur le sol réel.
                local found, groundZ = GetGroundZFor_3dCoord(sx, sy, refZ + 20.0, false)
                if found and groundZ > 0.0 then
                    SetEntityCoordsNoOffset(ped, sx, sy, groundZ + 1.0, false, false, false)
                    break
                end
            end

            Wait(10)
        end

        -- Collision prête (ou garde-fou atteint) : on relâche le joueur.
        FreezeEntityPosition(PlayerPedId(), false)
        groundingInProgress = false
    end)
end

-- Ferme le loadscreen (mono-perso : plus de multichar pour le faire). Idempotent.
local loadscreenClosed = false
local function shutdownLoadscreen()
    if loadscreenClosed then return end
    loadscreenClosed = true
    if GetResourceState('spawnmanager') ~= 'missing' then
        -- spawnmanager gere deja le shutdown dans certains flux ; on force par surete.
    end
    ShutdownLoadingScreenNui()
end

-- Declenche a chaque fois qu'ESX charge/relance le joueur.
RegisterNetEvent('esx:playerLoaded', function()
    shutdownLoadscreen()
    groundPlayerSafely()
end)

-- Filet de securite : certaines versions n'emettent esx:playerLoaded qu'apres la
-- selection ; on couvre aussi le spawn natif.
AddEventHandler('playerSpawned', function()
    shutdownLoadscreen()
    groundPlayerSafely()
end)
