Config = {}

-- Compte du butin (money = liquide ; le bank serait traçable = trop sûr pour un braquage).
Config.MoneyType = 'money'

-- Métier considéré comme « Police » (alerte + seuil minPolice). Métier ESX.
Config.PoliceJob = 'police'

-- Interaction de proximité (comme ubuntu-location).
Config.MarkerRadius = 1.6
Config.DrawDistance = 12.0
Config.InteractKey = 38            -- E
Config.MarkerColor = { r = 91, g = 76, b = 240 } -- accent indigo #5B4CF0

-- Distance serveur max (m) tolérée entre le joueur et la cible au démarrage (anti-triche).
Config.MaxStartDistance = 6.0

-- Durée de vie du blip d'alerte envoyé à la police (ms).
Config.AlertBlipDuration = 90000

-- ---------------------------------------------------------------------------
-- Cibles de braquage (data-driven). Chaque entrée :
--   id           identifiant unique
--   type         'till' (caisse) | 'atm' (distributeur) | 'bank' (banque)
--   label        libellé affiché
--   coords       vector3 du point d'interaction
--   duration     durée du braquage en ms (barre de progression)
--   cooldown     temps de recharge de CETTE cible en secondes
--   minPolice    nb de policiers EN SERVICE requis pour lancer
--   reward       { min, max } butin (tiré aléatoirement, côté serveur)
--   needWeapon   true = arme dégainée requise (braquage à main armée)
--   requiredItem item consommé au démarrage (déclaré dans ox_inventory —
--                ajouté par install-resources.sh : electronickit, thermite)
-- ---------------------------------------------------------------------------
Config.Targets = {
    -- Supérettes (caisses) — menace à main armée, butin modéré.
    { id = 'store_center',  type = 'till', label = 'Supérette (centre)',
      coords = vector3(25.7, -1347.3, 29.5),  duration = 18000, cooldown = 1800,
      minPolice = 1, reward = { min = 8000, max = 18000 }, needWeapon = true },
    { id = 'store_east',    type = 'till', label = 'Supérette (est)',
      coords = vector3(1163.0, -323.8, 69.2), duration = 18000, cooldown = 1800,
      minPolice = 1, reward = { min = 8000, max = 18000 }, needWeapon = true },
    { id = 'store_west',    type = 'till', label = 'Supérette (ouest)',
      coords = vector3(-1487.9, -379.5, 40.2), duration = 18000, cooldown = 1800,
      minPolice = 1, reward = { min = 8000, max = 18000 }, needWeapon = true },

    -- Distributeurs (ATM) — discret, petit butin, nécessite un kit électronique.
    { id = 'atm_center',    type = 'atm', label = 'Distributeur (centre)',
      coords = vector3(-56.8, -1751.9, 29.4), duration = 12000, cooldown = 1200,
      minPolice = 0, reward = { min = 2000, max = 6000 }, needWeapon = false,
      requiredItem = 'electronickit' },
    { id = 'atm_north',     type = 'atm', label = 'Distributeur (nord)',
      coords = vector3(-717.0, -915.3, 19.2), duration = 12000, cooldown = 1200,
      minPolice = 0, reward = { min = 2000, max = 6000 }, needWeapon = false,
      requiredItem = 'electronickit' },

    -- Banques — gros butin, thermite requise, présence policière renforcée.
    { id = 'bank_downtown', type = 'bank', label = 'Banque (centre-ville)',
      coords = vector3(149.9, -1042.0, 29.4), duration = 45000, cooldown = 3600,
      minPolice = 2, reward = { min = 40000, max = 90000 }, needWeapon = true,
      requiredItem = 'thermite' },
    { id = 'bank_uptown',   type = 'bank', label = 'Banque (nord)',
      coords = vector3(-351.5, -49.5, 49.0),  duration = 45000, cooldown = 3600,
      minPolice = 2, reward = { min = 40000, max = 90000 }, needWeapon = true,
      requiredItem = 'thermite' },
}
