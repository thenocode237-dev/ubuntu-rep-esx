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
-- les effets réels : seul l'`id` voyage à l'achat.  Coûts en Points.
-- category ∈ starter | vehicle | cosmetic | item | rank | perk
-- type     ∈ bundle  | vehicle | cosmetic | item | rank | perk
-- oneTime = true  -> achat unique (possession vérifiée côté serveur)
-- LIVRAISON : vehicle -> owned_vehicles (stored=1, récupérable au garage) ;
--             outfit  -> re-portable via /tenues ; item -> ox_inventory (AddItem) ;
--             bundle  -> combine vehicle + outfit + items.
-- vehicle.vtype ∈ car | bike  (pas de bateau : le garage spawne sur terre)
-- ---------------------------------------------------------------------------
Config.Catalog = {
    -- ======================= PACKS (bundle) =======================
    {
        id = 'starter_urban', category = 'starter', type = 'bundle', oneTime = true,
        label = 'Starter Pack — Urban', cost = 1500,
        description = 'Scooter de ville + tenue streetwear + en-cas.',
        payload = {
            vehicle = { model = 'faggio', vtype = 'bike' },
            outfit = { name = 'Urban', skin = outfit({
                ['t-shirt'] = { item = 15, texture = 0 },
                ['torso2']  = { item = 245, texture = 2 },
                ['arms']    = { item = 30, texture = 0 },
                ['pants']   = { item = 24, texture = 0 },
                ['shoes']   = { item = 21, texture = 0 },
            }) },
            items = { { name = 'premium_snack', count = 2 }, { name = 'premium_drink', count = 2 } },
        },
    },
    {
        id = 'starter_corporate', category = 'starter', type = 'bundle', oneTime = true,
        label = 'Starter Pack — Corporate', cost = 2500,
        description = 'Berline sobre + tenue business + café.',
        payload = {
            vehicle = { model = 'asea', vtype = 'car' },
            outfit = { name = 'Corporate', skin = outfit({
                ['t-shirt'] = { item = 31, texture = 0 },
                ['torso2']  = { item = 26, texture = 0 },
                ['pants']   = { item = 10, texture = 0 },
                ['shoes']   = { item = 10, texture = 0 },
            }) },
            items = { { name = 'premium_coffee', count = 3 } },
        },
    },
    {
        id = 'starter_young', category = 'starter', type = 'bundle', oneTime = true,
        label = 'Starter Pack — Young', cost = 1500,
        description = 'Quad + tenue décontractée + en-cas.',
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
            items = { { name = 'premium_snack', count = 3 } },
        },
    },
    {
        id = 'pack_deluxe', category = 'starter', type = 'bundle', oneTime = true,
        label = 'Pack Deluxe — Donateur', cost = 15000,
        description = 'Sportive de collection + tenue élégante + coffret cadeau.',
        payload = {
            vehicle = { model = 'comet2', vtype = 'car' },
            outfit = { name = 'Deluxe', skin = outfit({
                ['torso2'] = { item = 6, texture = 3 },
                ['pants']  = { item = 6, texture = 3 },
                ['shoes']  = { item = 20, texture = 0 },
            }) },
            items = { { name = 'premium_giftbox', count = 1 }, { name = 'premium_coffee', count = 2 } },
        },
    },

    -- ======================= VÉHICULES (vehicle) =======================
    {
        id = 'vehicle_compact', category = 'vehicle', type = 'vehicle', oneTime = true,
        label = 'Compacte — Blista', cost = 3000,
        description = 'Petite citadine pratique (aucun bonus de performance).',
        payload = { vehicle = { model = 'blista', vtype = 'car' } },
    },
    {
        id = 'vehicle_sedan', category = 'vehicle', type = 'vehicle', oneTime = true,
        label = 'Berline — Stanier', cost = 4500,
        description = 'Berline confortable (cosmétique).',
        payload = { vehicle = { model = 'stanier', vtype = 'car' } },
    },
    {
        id = 'vehicle_classic', category = 'vehicle', type = 'vehicle', oneTime = true,
        label = 'Ancienne — Roosevelt', cost = 6000,
        description = 'Voiture de collection des années folles (cosmétique).',
        payload = { vehicle = { model = 'btype', vtype = 'car' } },
    },
    {
        id = 'vehicle_suv', category = 'vehicle', type = 'vehicle', oneTime = true,
        label = 'SUV — Baller', cost = 8000,
        description = 'SUV de standing aux finitions custom (cosmétique).',
        payload = { vehicle = { model = 'baller3', vtype = 'car' } },
    },
    {
        id = 'vehicle_offroad', category = 'vehicle', type = 'vehicle', oneTime = true,
        label = '4x4 — Sandking', cost = 9000,
        description = 'Tout-terrain surélevé (cosmétique, non P2W).',
        payload = { vehicle = { model = 'sandking', vtype = 'car' } },
    },
    {
        id = 'vehicle_utility', category = 'vehicle', type = 'vehicle', oneTime = true,
        label = 'Utilitaire — Bison', cost = 5500,
        description = 'Pick-up utilitaire polyvalent (cosmétique).',
        payload = { vehicle = { model = 'bison', vtype = 'car' } },
    },
    {
        id = 'vehicle_sport', category = 'vehicle', type = 'vehicle', oneTime = true,
        label = 'Sportive — Comet', cost = 12000,
        description = 'Coupé sport de collection (look custom, aucune performance ajoutée).',
        payload = { vehicle = { model = 'comet2', vtype = 'car' } },
    },
    {
        id = 'vehicle_super', category = 'vehicle', type = 'vehicle', oneTime = true,
        label = 'Supercar — Adder', cost = 20000,
        description = 'Hypercar de prestige (cosmétique de collection).',
        payload = { vehicle = { model = 'adder', vtype = 'car' } },
    },
    {
        id = 'vehicle_moto', category = 'vehicle', type = 'vehicle', oneTime = true,
        label = 'Moto — Bati', cost = 6000,
        description = 'Roadster deux-roues aux couleurs custom (cosmétique).',
        payload = { vehicle = { model = 'bati', vtype = 'bike' } },
    },
    {
        id = 'vehicle_chopper', category = 'vehicle', type = 'vehicle', oneTime = true,
        label = 'Chopper — Daemon', cost = 7000,
        description = 'Custom bike de croisière (cosmétique).',
        payload = { vehicle = { model = 'daemon', vtype = 'bike' } },
    },

    -- ======================= TENUES (cosmetic) =======================
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
        id = 'cosmetic_bomber', category = 'cosmetic', type = 'cosmetic', oneTime = true,
        label = 'Tenue Bomber (exclusive)', cost = 1400,
        description = 'Blouson bomber streetwear, exclusive donateurs.',
        payload = { outfit = { name = 'Bomber', skin = outfit({
            ['torso2'] = { item = 242, texture = 0 },
            ['arms']   = { item = 30, texture = 0 },
            ['pants']  = { item = 24, texture = 1 },
            ['shoes']  = { item = 21, texture = 0 },
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
        id = 'cosmetic_suit', category = 'cosmetic', type = 'cosmetic', oneTime = true,
        label = 'Costume Trois-Pièces (exclusive)', cost = 2000,
        description = 'Costume classe pour les grandes occasions, donateurs.',
        payload = { outfit = { name = 'Costume', skin = outfit({
            ['t-shirt'] = { item = 31, texture = 0 },
            ['torso2']  = { item = 26, texture = 2 },
            ['pants']   = { item = 24, texture = 0 },
            ['shoes']   = { item = 10, texture = 0 },
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

    -- ======================= OBJETS (item -> inventaire) =======================
    {
        id = 'item_snackpack', category = 'item', type = 'item', oneTime = false,
        label = 'Pack En-cas ×5', cost = 500,
        description = '5 en-cas premium livrés dans votre inventaire.',
        payload = { items = { { name = 'premium_snack', count = 5 } } },
    },
    {
        id = 'item_drinkpack', category = 'item', type = 'item', oneTime = false,
        label = 'Pack Boissons ×5', cost = 500,
        description = '5 boissons premium livrées dans votre inventaire.',
        payload = { items = { { name = 'premium_drink', count = 5 } } },
    },
    {
        id = 'item_coffeepack', category = 'item', type = 'item', oneTime = false,
        label = 'Pack Café ×5', cost = 600,
        description = '5 cafés premium (petit regain de forme).',
        payload = { items = { { name = 'premium_coffee', count = 5 } } },
    },
    {
        id = 'item_picnic', category = 'item', type = 'item', oneTime = false,
        label = 'Panier Pique-nique', cost = 900,
        description = 'Assortiment : en-cas, boissons et cafés.',
        payload = { items = {
            { name = 'premium_snack', count = 3 },
            { name = 'premium_drink', count = 3 },
            { name = 'premium_coffee', count = 2 },
        } },
    },
    {
        id = 'item_giftbox', category = 'item', type = 'item', oneTime = false,
        label = 'Coffret Cadeau', cost = 1000,
        description = 'Un coffret cadeau collector (objet décoratif).',
        payload = { items = { { name = 'premium_giftbox', count = 1 } } },
    },

    -- ======================= GRADE VIP (rank) =======================
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
    {
        id = 'rank_vip_ultimate', category = 'rank', type = 'rank', oneTime = true,
        label = 'Grade Donateur VIP Ultimate', cost = 12000,
        description = 'Le grade le plus prestigieux : tous les avantages donateurs.',
        payload = { rankId = 'vip_ultimate', aceGroup = 'vip_ultimate' },
    },

    -- ======================= CONFORT (perk) =======================
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
    { id = 'starter',  label = 'Packs' },
    { id = 'vehicle',  label = 'Véhicules' },
    { id = 'cosmetic', label = 'Tenues' },
    { id = 'item',     label = 'Objets' },
    { id = 'rank',     label = 'Grade VIP' },
    { id = 'perk',     label = 'Confort' },
}
