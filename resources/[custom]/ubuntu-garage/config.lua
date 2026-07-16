Config = {}

-- =============================================================================
-- ubuntu-garage — garage personnel. Sortir / ranger les véhicules possédés
-- (table ESX `owned_vehicles`). 100 % serveur-authoritative : le client envoie
-- une plaque / une intention, le serveur valide la possession et pilote le spawn.
-- Aucun garage joueur n'existait (esx_property = par maison, esx_vehicleshop =
-- métier seulement) ; les véhicules premium sont livrés ici (stored=1).
-- =============================================================================

-- Interaction de proximité (comme ubuntu-location).
Config.MarkerRadius = 2.5
Config.DrawDistance = 15.0
Config.InteractKey  = 38 -- E
Config.MarkerColor  = { r = 91, g = 76, b = 240 } -- accent indigo #5B4CF0
Config.StoreRadius  = 8.0 -- distance max pour ranger un véhicule proche

-- --- Clés / verrouillage (anti-vol) -----------------------------------------
-- Le joueur verrouille/déverrouille un véhicule qu'il POSSÈDE (plaque présente
-- dans owned_vehicles). Verrou porté par un statebag d'entité (réplicable, résiste
-- au streaming). Touche par défaut réassignable dans Paramètres > Touches.
Config.Keys = {
    key       = 'U',   -- touche du verrou (RegisterKeyMapping)
    reach     = 6.0,   -- distance max pour verrouiller un véhicule à pied
    honk      = true,  -- petit coup de klaxon + phares au verrouillage
}

-- --- GPS : repérage des véhicules sortis sur la carte ------------------------
-- Un blip suit chaque véhicule possédé du joueur qui est sorti (hors garage).
-- Le serveur lit la position (OneSync) même si le véhicule n'est pas streamé.
Config.Gps = {
    enabled = true,
    refresh = 4000,          -- rafraîchissement des positions (ms)
    sprite  = 225,           -- blip véhicule
    color   = 3,             -- bleu
    scale   = 0.9,
}

-- ---------------------------------------------------------------------------
-- Points de garage. `coords` = PNJ/marqueur d'accès ; `spawn` = point où le
-- véhicule sorti apparaît (dégagé, orienté vers la route). Ajouter un garage =
-- 1 entrée.
-- ---------------------------------------------------------------------------
Config.Garages = {
    {
        id = 'legion',
        label = 'Garage — Legion Square',
        ped   = 's_m_y_valet_01',
        coords = vector4(215.9, -809.9, 30.7, 68.0),
        spawn  = vector4(211.0, -800.5, 30.6, 250.0),
        blip = { sprite = 357, color = 3, scale = 0.8 },
    },
    {
        id = 'airport',
        label = 'Garage — Aéroport',
        ped   = 's_m_y_valet_01',
        -- Garage public canonique qb-garages, HORS de l'enceinte clôturée du LSIA
        -- (l'ancien -1037,-2737 était derrière la barrière = inaccessible à pied).
        coords = vector4(-796.6, -2025.1, 8.9, 138.0),
        spawn  = vector4(-802.0, -2022.0, 8.9, 230.0),
        blip = { sprite = 357, color = 3, scale = 0.8 },
    },
}
