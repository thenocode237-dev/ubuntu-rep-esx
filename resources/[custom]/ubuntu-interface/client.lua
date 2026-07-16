local ESX = exports['es_extended']:getSharedObject()
local isStaff = false
local blips = {}

-- =============================================================================
-- 1) Habillage du menu pause (Échap) : remplace le libellé de l'onglet en ligne
--    par l'identité du serveur. À réappliquer après chaque (re)chargement.
-- =============================================================================
local function brandPauseMenu()
    if not Config.PauseMenu.enabled then return end
    AddTextEntry('FE_THDR_GTAO', Config.PauseMenu.title)
end

-- =============================================================================
-- 1bis) Solde du menu pause : ESX ne synchronise pas les stats natives GTA:Online
--    (haut-droite du menu pause). On les alimente depuis les comptes ESX
--    `money`/`bank` (mis à jour en direct via esx:setAccountMoney, y compris quand
--    le cash change via ox_inventory), sinon le menu pause reste figé à 0.
--    (Pas de HUD à l'écran — retiré à la demande.)
-- =============================================================================
local cachedCash, cachedBank = 0, 0

local function pushMoneyStats()
    if not Config.PauseMenu.syncMoney then return end
    StatSetInt(GetHashKey('MP0_WALLET_BALANCE'), cachedCash, true)
    StatSetInt(GetHashKey('BANK_BALANCE'), cachedBank, true)
end

-- Rafraîchit le cache depuis la table `accounts` d'un xPlayer.
local function syncMoneyFromAccounts(accounts)
    if type(accounts) ~= 'table' then return end
    for _, acc in ipairs(accounts) do
        if acc.name == 'money' then cachedCash = acc.money or 0
        elseif acc.name == 'bank' then cachedBank = acc.money or 0 end
    end
    pushMoneyStats()
end

-- Mise à jour au changement d'un compte (paiement, retrait, salaire, cash ox…).
AddEventHandler('esx:setAccountMoney', function(account)
    if type(account) ~= 'table' then return end
    if account.name == 'money' then cachedCash = account.money or cachedCash
    elseif account.name == 'bank' then cachedBank = account.money or cachedBank
    else return end
    pushMoneyStats()
end)

-- Garde-fou : le jeu peut réinitialiser les stats natives ; on les re-pousse.
CreateThread(function()
    while true do
        Wait(5000)
        pushMoneyStats()
    end
end)

-- =============================================================================
-- 2) Carte : place les points d'intérêt du serveur (blips permanents).
-- =============================================================================
local function createBlips()
    if not Config.ShowBlips then return end
    for _, b in ipairs(Config.Blips) do
        local blip = AddBlipForCoord(b.coords.x, b.coords.y, b.coords.z)
        SetBlipSprite(blip, b.sprite)
        SetBlipColour(blip, b.color)
        SetBlipScale(blip, b.scale or 0.8)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(b.label)
        EndTextCommandSetBlipName(blip)
        blips[#blips + 1] = blip
    end
end

-- =============================================================================
-- 3) Menu principal (F1) — construit avec ox_lib (lib.registerContext),
--    data-driven depuis config.
-- =============================================================================

local openMainMenu -- forward declaration

-- Sous-menu « Se repérer » : chaque lieu pose un waypoint sur la carte.
local function openLocationsMenu()
    local options = {}
    for _, b in ipairs(Config.Blips) do
        if b.menu then
            options[#options + 1] = {
                title = b.label,
                icon = 'location-dot',
                onSelect = function()
                    SetNewWaypoint(b.coords.x, b.coords.y)
                    lib.notify({ description = Lang:t('menu.waypoint_set', { label = b.label }), type = 'inform' })
                end,
            }
        end
    end
    options[#options + 1] = { title = Lang:t('menu.back'), icon = 'arrow-left', onSelect = function() openMainMenu() end }
    lib.registerContext({ id = 'ubuntu_locations', title = Lang:t('menu.locations'), options = options })
    lib.showContext('ubuntu_locations')
end

local function showHelp()
    for _, line in ipairs(Config.HelpLines) do
        TriggerEvent('chat:addMessage', { color = { 91, 76, 240 }, multiline = false, args = { 'AIDE', line } })
    end
    lib.notify({ description = Lang:t('menu.help_sent'), type = 'inform' })
end

openMainMenu = function()
    local options = {}
    for _, item in ipairs(Config.MainMenu.items) do
        if not (item.staffOnly and not isStaff) then
            local onSelect
            if item.type == 'locations' then
                onSelect = openLocationsMenu
            elseif item.type == 'help' then
                onSelect = showHelp
            elseif item.command then
                local cmd = item.command
                onSelect = function() ExecuteCommand(cmd) end
            end
            options[#options + 1] = {
                title = item.label,
                description = item.description,
                icon = item.icon,
                onSelect = onSelect,
            }
        end
    end
    lib.registerContext({ id = 'ubuntu_main', title = Config.MainMenu.title, options = options })
    lib.showContext('ubuntu_main')
end

RegisterCommand(Config.MainMenu.command, function() openMainMenu() end, false)
RegisterKeyMapping(Config.MainMenu.command, 'Ouvrir le menu principal', 'keyboard', Config.MainMenu.key)

-- =============================================================================
-- 4) Roue de sélection d'arme à la molette de la souris.
--    Piège des contrôles GTA : quand la roue est FERMÉE, un cran de molette
--    déclenche 16/17 (INPUT_SELECT_NEXT/PREV_WEAPON = switch instantané), et
--    NON 14/15 (ceux-là ne servent qu'à naviguer dans une roue déjà ouverte).
--    On bloque donc le switch instantané (16/17) et, à sa place, on ouvre la
--    roue en maintenant le contrôle 37 (INPUT_SELECT_WEAPON, équivaut à TAB)
--    pendant `openMs`. Chaque nouveau cran (16/17 fermé, 14/15 ouvert) relance
--    le minuteur ; quand on arrête de scroller, la roue se ferme et sélectionne.
-- =============================================================================
local INPUT_SELECT_WEAPON      = 37  -- ouvre / maintient la roue (TAB)
local INPUT_SELECT_NEXT_WEAPON = 16  -- molette (roue fermée) → switch instantané
local INPUT_SELECT_PREV_WEAPON = 17
local INPUT_WEAPON_WHEEL_NEXT  = 14  -- molette pendant que la roue est ouverte
local INPUT_WEAPON_WHEEL_PREV  = 15

CreateThread(function()
    if not Config.WeaponWheel or not Config.WeaponWheel.enabled then return end
    local openMs = Config.WeaponWheel.openMs or 1500
    local holdUntil = 0
    while true do
        Wait(0)
        -- Neutralise le switch instantané pour que la molette ouvre la roue.
        DisableControlAction(0, INPUT_SELECT_NEXT_WEAPON, true)
        DisableControlAction(0, INPUT_SELECT_PREV_WEAPON, true)

        if IsDisabledControlJustPressed(0, INPUT_SELECT_NEXT_WEAPON)
            or IsDisabledControlJustPressed(0, INPUT_SELECT_PREV_WEAPON)
            or IsControlJustPressed(0, INPUT_WEAPON_WHEEL_NEXT)
            or IsControlJustPressed(0, INPUT_WEAPON_WHEEL_PREV) then
            holdUntil = GetGameTimer() + openMs
        end

        if GetGameTimer() < holdUntil then
            SetControlNormal(0, INPUT_SELECT_WEAPON, 1.0)
        end
    end
end)

-- =============================================================================
-- Initialisation (au chargement du joueur + au (re)démarrage de la ressource).
-- =============================================================================
local function refreshStaff()
    isStaff = lib.callback.await('ubuntu-interface:server:isStaff', false) == true
end

local function init(xPlayer)
    brandPauseMenu()
    refreshStaff()
    if xPlayer then syncMoneyFromAccounts(xPlayer.accounts) end
end

AddEventHandler('esx:playerLoaded', function(xPlayer)
    init(xPlayer)
end)

CreateThread(function()
    Wait(1500)
    brandPauseMenu()
    createBlips()
    -- Si la ressource redémarre alors que le joueur est déjà en jeu.
    refreshStaff()
    local pd = ESX.GetPlayerData and ESX.GetPlayerData() or ESX.PlayerData
    if pd and pd.accounts then
        syncMoneyFromAccounts(pd.accounts)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
end)
