Config = {}

-- Boutique de dons « Points » (non pay-to-win : cosmétique / confort uniquement).
-- Les points ne sont PAS un compte ESX : ils vivent dans la table propre
-- `ubuntu_premium_data` (colonne `points`), créditée par un admin (/addpoints).
Config.CurrencyName = 'Points'

-- Groupes ESX autorisés à créditer des points (/addpoints) — simule un don.
-- Vérifié via xPlayer.getGroup() côté serveur.
Config.AdminGroups = { 'admin', 'superadmin' }

-- Emplacement de la boutique (PNJ + blip + marqueur). Legion Square.
Config.Shop = {
    coords = vector4(-46.68, -1758.2, 29.42, 320.0),
    ped = 's_m_m_autoshop_01',
    blip = { sprite = 617, color = 2, scale = 0.8 }, -- cadeau
    markerColor = { r = 91, g = 76, b = 240 },       -- accent indigo #5B4CF0
}

-- Un « outfit » décrit des composants de vêtements (drawable/texture) appliqués
-- au ped via natives GTA (SetPedComponentVariation / SetPedPropIndex) à l'achat.
-- Composants : mask(1) arms(3) t-shirt(8) torso2(11) vest(9) decals(10) bag(5)
-- pants(4) shoes(6) hair(2) accessory(7). (id de composant GTA entre parenthèses)
local function outfit(components)
    local base = {
        ['mask']      = { item = 0, texture = 0 },
        ['hair']      = { item = 0, texture = 0 },
        ['arms']      = { item = 0, texture = 0 },
        ['t-shirt']   = { item = 0, texture = 0 },
        ['torso2']    = { item = 0, texture = 0 },
        ['vest']      = { item = 0, texture = 0 },
        ['decals']    = { item = 0, texture = 0 },
        ['bag']       = { item = 0, texture = 0 },
        ['pants']     = { item = 0, texture = 0 },
        ['shoes']     = { item = 0, texture = 0 },
        ['accessory'] = { item = 0, texture = 0 },
    }
    for k, v in pairs(components) do base[k] = v end
    return base
end

-- ---------------------------------------------------------------------------
-- Catalogue premium (SOURCE DE VÉRITÉ SERVEUR). Le client ne connaît jamais
-- les coûts réels ni les effets : seul l'`id` voyage. Coûts en Points.
-- category ∈ starter | cosmetic | vehicle | rank | perk
-- type     ∈ bundle | cosmetic | vehicle | rank | perk
-- oneTime = true  -> achat unique (possession vérifiée côté serveur)
-- vehicle.vtype ∈ car | bike | boat (colonne owned_vehicles.type)
-- ---------------------------------------------------------------------------
Config.Catalog = {
    -- === Starter packs : un moyen de transport + une tenue distincte ===
    {
        id = 'starter_urban', category = 'starter', type = 'bundle', oneTime = true,
        label = 'Starter Pack — Urban', cost = 1500,
        description = 'Scooter de ville + tenue streetwear (hoodie, jean, baskets).',
        payload = {
            vehicle = { model = 'faggio', vtype = 'bike' },
            outfit = { name = 'Urban', skin = outfit({
                ['t-shirt'] = { item = 15, texture = 0 },
                ['torso2']  = { item = 245, texture = 2 },
                ['arms']    = { item = 30, texture = 0 },
                ['pants']   = { item = 24, texture = 0 },
                ['shoes']   = { item = 21, texture = 0 },
            }) },
        },
    },
    {
        id = 'starter_corporate', category = 'starter', type = 'bundle', oneTime = true,
        label = 'Starter Pack — Corporate', cost = 2500,
        description = 'Berline sobre + tenue business (costume, chemise, chaussures de ville).',
        payload = {
            vehicle = { model = 'asea', vtype = 'car' },
            outfit = { name = 'Corporate', skin = outfit({
                ['t-shirt'] = { item = 31, texture = 0 },
                ['torso2']  = { item = 26, texture = 0 },
                ['arms']    = { item = 0, texture = 0 },
                ['pants']   = { item = 10, texture = 0 },
                ['shoes']   = { item = 10, texture = 0 },
            }) },
        },
    },
    {
        id = 'starter_young', category = 'starter', type = 'bundle', oneTime = true,
        label = 'Starter Pack — Young', cost = 1500,
        description = 'Quad + tenue décontractée (t-shirt, sneakers).',
        payload = {
            vehicle = { model = 'blazer', vtype = 'bike' },
            outfit = { name = 'Young', skin = outfit({
                ['t-shirt'] = { item = 15, texture = 0 },
                ['torso2']  = { item = 4, texture = 3 },
                ['arms']    = { item = 41, texture = 0 },
                ['pants']   = { item = 4, texture = 5 },
                ['shoes']   = { item = 25, texture = 0 },
                ['hair']    = { item = 10, texture = 0 },
            }) },
        },
    },

    -- === Cosmétiques (tenues exclusives donateurs, génériques) ===
    {
        id = 'cosmetic_street', category = 'cosmetic', type = 'cosmetic', oneTime = true,
        label = 'Tenue Street (exclusive)', cost = 1200,
        description = 'Tenue urbaine exclusive aux donateurs.',
        payload = { outfit = { name = 'Street', skin = outfit({
            ['torso2'] = { item = 6, texture = 1 },
            ['pants']  = { item = 6, texture = 1 },
            ['shoes']  = { item = 20, texture = 0 },
        }) } },
    },
    {
        id = 'cosmetic_sport', category = 'cosmetic', type = 'cosmetic', oneTime = true,
        label = 'Tenue Sport (exclusive)', cost = 1500,
        description = 'Tenue de sport aux couleurs vives, exclusive donateurs.',
        payload = { outfit = { name = 'Sport', skin = outfit({
            ['t-shirt'] = { item = 15, texture = 0 },
            ['torso2']  = { item = 4, texture = 1 },
            ['arms']    = { item = 41, texture = 0 },
            ['pants']   = { item = 4, texture = 0 },
            ['shoes']   = { item = 25, texture = 0 },
        }) } },
    },
    {
        id = 'cosmetic_elegant', category = 'cosmetic', type = 'cosmetic', oneTime = true,
        label = 'Tenue Élégante (exclusive)', cost = 1800,
        description = 'Tenue de cérémonie élégante, exclusive donateurs.',
        payload = { outfit = { name = 'Élégante', skin = outfit({
            ['torso2'] = { item = 6, texture = 3 },
            ['pants']  = { item = 6, texture = 3 },
            ['shoes']  = { item = 20, texture = 0 },
        }) } },
    },
    {
        id = 'cosmetic_event', category = 'cosmetic', type = 'cosmetic', oneTime = true,
        label = 'Tenue Événement (édition limitée)', cost = 2200,
        description = 'Tenue événementielle — édition limitée donateurs.',
        payload = { outfit = { name = 'Événement', skin = outfit({
            ['t-shirt'] = { item = 15, texture = 0 },
            ['torso2']  = { item = 245, texture = 5 },
            ['arms']    = { item = 30, texture = 0 },
            ['pants']   = { item = 24, texture = 1 },
            ['shoes']   = { item = 21, texture = 0 },
        }) } },
    },

    -- === Véhicules cosmétiques (mods NEUTRES, aucun avantage — non P2W).
    -- Pour un vrai véhicule add-on : remplacer `model` par le nom du modèle
    -- streamé (fichiers du car pack fournis/streamés par le serveur). ===
    {
        id = 'vehicle_classic', category = 'vehicle', type = 'vehicle', oneTime = true,
        label = 'Véhicule cosmétique — Classic', cost = 5000,
        description = 'Ancienne de collection (aucun bonus de performance).',
        payload = { vehicle = { model = 'btype', vtype = 'car' } },
    },
    {
        id = 'vehicle_suv_custom', category = 'vehicle', type = 'vehicle', oneTime = true,
        label = 'SUV custom — Donateur', cost = 8000,
        description = 'SUV de collection aux finitions custom (cosmétique).',
        payload = { vehicle = { model = 'baller3', vtype = 'car' } },
    },
    {
        id = 'vehicle_sport_custom', category = 'vehicle', type = 'vehicle', oneTime = true,
        label = 'Sportive custom — Donateur', cost = 12000,
        description = 'Coupé sport de collection (look custom, aucune performance ajoutée).',
        payload = { vehicle = { model = 'comet2', vtype = 'car' } },
    },
    {
        id = 'vehicle_moto_custom', category = 'vehicle', type = 'vehicle', oneTime = true,
        label = 'Moto custom — Donateur', cost = 6000,
        description = 'Roadster deux-roues de collection aux couleurs custom (cosmétique).',
        payload = { vehicle = { model = 'bati', vtype = 'bike' } },
    },

    -- === Grade donateur VIP (statut, pas de pouvoir gameplay) ===
    {
        id = 'rank_vip', category = 'rank', type = 'rank', oneTime = true,
        label = 'Grade Donateur VIP', cost = 3000,
        description = 'Badge VIP, accès salon Discord donateurs, file prioritaire.',
        payload = { rankId = 'vip', aceGroup = 'vip' },
    },
    {
        id = 'rank_vip_plus', category = 'rank', type = 'rank', oneTime = true,
        label = 'Grade Donateur VIP+', cost = 6000,
        description = 'Tous les avantages VIP + cosmétiques exclusifs VIP+.',
        payload = { rankId = 'vip_plus', aceGroup = 'vip_plus' },
    },

    -- === Confort (slots supplémentaires — pratique, pas du pouvoir) ===
    {
        id = 'perk_garage_slot', category = 'perk', type = 'perk', oneTime = true,
        label = 'Slot de garage supplémentaire', cost = 2000,
        description = 'Un emplacement de garage en plus (confort).',
        payload = { key = 'extra_garage_slots', value = 1 },
    },
    {
        id = 'perk_wardrobe', category = 'perk', type = 'perk', oneTime = true,
        label = 'Accès garde-robe étendue', cost = 2000,
        description = 'Emplacements de tenues supplémentaires (confort).',
        payload = { key = 'extra_wardrobe_slots', value = 1 },
    },
}

-- Libellés des onglets de la boutique (ordre d'affichage).
Config.Categories = {
    { id = 'starter',  label = 'Starter packs' },
    { id = 'cosmetic', label = 'Cosmétiques' },
    { id = 'vehicle',  label = 'Véhicules' },
    { id = 'rank',     label = 'Grade VIP' },
    { id = 'perk',     label = 'Confort' },
}
