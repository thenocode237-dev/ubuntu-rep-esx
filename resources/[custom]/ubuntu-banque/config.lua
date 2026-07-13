Config = {}

-- =============================================================================
-- ubuntu-banque — banque ESX (guichets + ATM). Dépôt / retrait / virement.
-- 100 % serveur-authoritative : le client n'envoie qu'une intention (montant,
-- cible) ; le serveur revalide tout et applique l'argent via l'API ESX
-- (addAccountMoney / removeAccountMoney). Cash (ox_inventory) et banque restent
-- synchronisés → le HUD (ubuntu-interface) se met à jour tout seul.
-- =============================================================================

-- Comptes ESX. `money` = liquide (item ox_inventory), `bank` = compte banque.
Config.CashAccount = 'money'
Config.BankAccount = 'bank'

-- Virements entre joueurs.
Config.Transfer = {
    enabled    = true,
    feePercent = 0,   -- frais prélevés à l'expéditeur (% du montant), 0 = gratuit
    minAmount  = 1,
}

-- Garde-fous serveur.
Config.MaxAmount = 100000000  -- plafond par opération (anti-overflow / triche)
Config.Cooldown  = 750        -- anti-spam entre deux opérations d'un même joueur (ms)

-- Interaction de proximité aux guichets (comme ubuntu-location).
Config.MarkerRadius = 2.0
Config.DrawDistance = 12.0
Config.InteractKey  = 38 -- E
Config.MarkerColor  = { r = 91, g = 76, b = 240 } -- accent indigo #5B4CF0

-- ---------------------------------------------------------------------------
-- Guichets (PNJ + blip + marqueur). Réutilise les emplacements « Banque » de
-- ubuntu-interface. Ajouter un guichet = 1 entrée.
-- ---------------------------------------------------------------------------
Config.Tellers = {
    {
        label = 'Banque',
        ped   = 'ig_bankman',
        coords = vector4(149.9, -1040.0, 29.37, 160.0),
        blip = { sprite = 108, color = 2, scale = 0.8 },
    },
    {
        label = 'Banque (centre)',
        ped   = 'ig_bankman',
        coords = vector4(235.0, 216.0, 106.29, 340.0),
        blip = { sprite = 108, color = 2, scale = 0.8 },
    },
}

-- ---------------------------------------------------------------------------
-- Distributeurs automatiques (ATM). Ciblés par ox_target sur les modèles de
-- props GTA (retrait / dépôt / solde ; pas de virement à l'ATM).
-- ---------------------------------------------------------------------------
Config.Atm = {
    models = {
        `prop_atm_01`,
        `prop_atm_02`,
        `prop_atm_03`,
        `prop_fleeca_atm`,
    },
}
