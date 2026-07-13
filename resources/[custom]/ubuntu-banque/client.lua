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

local function formatMoney(amount)
    local s = tostring(math.floor(amount or 0))
    return (s:reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^%s+', '')) .. ' $'
end

-- --- Saisie d'un montant (ox_lib) -------------------------------------------

local function askAmount(title)
    local input = lib.inputDialog(title, {
        { type = 'number', label = Lang:t('dialog.amount'), min = 1, required = true, icon = 'coins' },
    })
    if not input or not input[1] then return nil end
    local amount = math.floor(tonumber(input[1]) or 0)
    if amount <= 0 then return nil end
    return amount
end

local function doDeposit()
    local amount = askAmount(Lang:t('dialog.deposit_title'))
    if amount then TriggerServerEvent('ubuntu-banque:server:deposit', amount) end
end

local function doWithdraw()
    local amount = askAmount(Lang:t('dialog.withdraw_title'))
    if amount then TriggerServerEvent('ubuntu-banque:server:withdraw', amount) end
end

local function doTransfer()
    local input = lib.inputDialog(Lang:t('dialog.transfer_title'), {
        { type = 'number', label = Lang:t('dialog.target_id'), min = 1, required = true, icon = 'user' },
        { type = 'number', label = Lang:t('dialog.amount'),    min = 1, required = true, icon = 'coins' },
    })
    if not input or not input[1] or not input[2] then return end
    local target = math.floor(tonumber(input[1]) or 0)
    local amount = math.floor(tonumber(input[2]) or 0)
    if target <= 0 or amount <= 0 then return end
    TriggerServerEvent('ubuntu-banque:server:transfer', target, amount)
end

-- --- Menu banque (guichet = complet, ATM = sans virement) -------------------

local function openMenu(isAtm)
    local bal = lib.callback.await('ubuntu-banque:server:getBalance', false) or { cash = 0, bank = 0 }
    local options = {
        -- Solde en tête (option non cliquable).
        {
            title = Lang:t('menu.balance', { cash = formatMoney(bal.cash), bank = formatMoney(bal.bank) }),
            icon = 'wallet',
            disabled = true,
        },
        {
            title = Lang:t('menu.deposit'),
            description = Lang:t('menu.deposit_desc'),
            icon = 'arrow-down',
            onSelect = doDeposit,
        },
        {
            title = Lang:t('menu.withdraw'),
            description = Lang:t('menu.withdraw_desc'),
            icon = 'arrow-up',
            onSelect = doWithdraw,
        },
    }
    if not isAtm and Config.Transfer.enabled then
        options[#options + 1] = {
            title = Lang:t('menu.transfer'),
            description = Lang:t('menu.transfer_desc'),
            icon = 'right-left',
            onSelect = doTransfer,
        }
    end

    lib.registerContext({
        id = 'ubuntu_banque_menu',
        title = isAtm and Lang:t('menu.atm_title') or Lang:t('menu.bank_title'),
        options = options,
    })
    lib.showContext('ubuntu_banque_menu')
end

-- --- Guichets : PNJ + blips + interaction de proximité ----------------------

CreateThread(function()
    for _, teller in ipairs(Config.Tellers) do
        local blip = AddBlipForCoord(teller.coords.x, teller.coords.y, teller.coords.z)
        SetBlipSprite(blip, teller.blip.sprite)
        SetBlipColour(blip, teller.blip.color)
        SetBlipScale(blip, teller.blip.scale or 0.8)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(teller.label)
        EndTextCommandSetBlipName(blip)

        local model = GetHashKey(teller.ped)
        RequestModel(model)
        local t = 0
        while not HasModelLoaded(model) and t < 100 do Wait(50); t = t + 1 end
        if HasModelLoaded(model) then
            local ped = CreatePed(4, model, teller.coords.x, teller.coords.y, teller.coords.z - 1.0, teller.coords.w, false, true)
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
        for _, teller in ipairs(Config.Tellers) do
            local tv = vector3(teller.coords.x, teller.coords.y, teller.coords.z)
            local dist = #(coords - tv)
            if dist < Config.DrawDistance then
                sleep = 0
                local c = Config.MarkerColor
                DrawMarker(1, tv.x, tv.y, tv.z - 0.98, 0, 0, 0, 0, 0, 0, 1.2, 1.2, 0.5, c.r, c.g, c.b, 120, false, false, 2, false)
                if dist < Config.MarkerRadius then
                    DrawText3D(tv.x, tv.y, tv.z, Lang:t('prompt.open_bank'))
                    if IsControlJustReleased(0, Config.InteractKey) then
                        openMenu(false)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- --- Distributeurs (ATM) : ciblage ox_target sur les props ------------------

CreateThread(function()
    exports.ox_target:addModel(Config.Atm.models, {
        {
            name = 'ubuntu_banque_atm',
            label = Lang:t('prompt.use_atm'),
            icon = 'fas fa-credit-card',
            distance = 1.6,
            onSelect = function() openMenu(true) end,
        },
    })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, ped in ipairs(peds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    exports.ox_target:removeModel(Config.Atm.models, 'ubuntu_banque_atm')
end)
