Config = {}

-- Compte (money = liquide ; l'argent sale ne passe pas par la banque).
Config.MoneyType = 'money'

-- Métier « Police » pour l'alerte (métier ESX).
Config.PoliceJob = 'police'

-- Vente aux PNJ.
Config.SellRadius = 2.5      -- distance max à un PNJ acheteur (m)
Config.SellCooldown = 4      -- délai mini entre deux ventes (s) — throttle serveur + client
Config.RefuseChance = 0.15   -- probabilité que le PNJ refuse (0..1)

-- Chaleur (« heat ») : monte à chaque vente, déclenche une alerte Police au seuil.
Config.HeatPerSale = 8       -- gain par vente réussie
Config.HeatThreshold = 100   -- seuil → alerte Police + « lay low »
Config.HeatDecayPerMin = 20  -- décroissance par minute
Config.LayLowCooldown = 180  -- blocage des ventes après une alerte (s)

-- Interaction / rendu (grossiste).
Config.InteractKey = 38      -- E
Config.MarkerRadius = 2.0
Config.DrawDistance = 15.0
Config.MarkerColor = { r = 91, g = 76, b = 240 } -- accent indigo #5B4CF0
Config.AlertBlipDuration = 60000

-- ---------------------------------------------------------------------------
-- Produits vendables = items déclarés dans ox_inventory (ajoutés par
-- install-resources.sh → append_ox_items). price = fourchette (tirée serveur).
-- Si un nom d'item diffère sur votre build, éditez la clé ici.
-- ---------------------------------------------------------------------------
Config.Products = {
    ['joint']       = { label = 'Joint',            price = { min = 150, max = 300 } },
    ['xtcbaggy']    = { label = 'Ecstasy',          price = { min = 400, max = 700 } },
    ['crack_baggy'] = { label = 'Crack',            price = { min = 500, max = 900 } },
    ['coke_baggy']  = { label = 'Cocaïne',          price = { min = 800, max = 1400 } },
}

-- ---------------------------------------------------------------------------
-- Quartiers chauds : on ne peut vendre QUE dans une de ces zones (les acheteurs
-- traînent en ville). priceMult = bonus de prix ; heatMult = risque relatif.
-- ---------------------------------------------------------------------------
Config.Zones = {
    { id = 'zone_east',  label = 'Quartier est',      center = vector3(110.0, -1950.0, 21.0),  radius = 90.0,  priceMult = 1.15, heatMult = 1.0 },
    { id = 'zone_north', label = 'Quartier nord',     center = vector3(-45.0, -1450.0, 32.0),  radius = 90.0,  priceMult = 1.05, heatMult = 0.9 },
    { id = 'zone_west',  label = 'Quartier ouest',    center = vector3(720.0, -2600.0, 22.0),  radius = 110.0, priceMult = 1.25, heatMult = 1.2 },
    { id = 'zone_market', label = 'Abords du marché', center = vector3(766.0, -740.0, 26.0),   radius = 80.0,  priceMult = 1.10, heatMult = 1.1 },
}

-- ---------------------------------------------------------------------------
-- Grossiste (approvisionnement) : PNJ + blip discret + marqueur. Vend les items
-- moins cher que la revente de rue (la marge = le gameplay).
-- ---------------------------------------------------------------------------
Config.Supplier = {
    label = 'Grossiste — approvisionnement',
    ped = 'g_m_m_armboss_01',
    coords = vector4(-598.0, -1622.0, 33.0, 90.0),
    blip = { sprite = 51, color = 2, scale = 0.7 }, -- discret, vert
    stock = {
        { item = 'joint',       label = 'Joint',   price = 100 },
        { item = 'xtcbaggy',    label = 'Ecstasy', price = 250 },
        { item = 'crack_baggy', label = 'Crack',   price = 350 },
        { item = 'coke_baggy',  label = 'Cocaïne', price = 600 },
    },
}
