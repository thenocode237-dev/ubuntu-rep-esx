Config = {}

-- =============================================================================
-- ubuntu-interface — interface joueur : menu principal (F1), habillage du
-- menu pause et carte des points d'intérêt (blips).
-- Tout est data-driven : ajouter une entrée de menu ou un point de carte se
-- fait ici, sans toucher au client.lua.
-- =============================================================================

-- --- Menu principal (touche F1) ---------------------------------------------
-- Ouvert par la commande `menuprincipal`, mappée par défaut sur F1 (réassignable
-- dans Paramètres > Touches). Chaque entrée déclenche soit une commande existante
-- (`command`), soit un point de repère (`type=locations`), soit l'aide
-- (`type=help`). `staffOnly` masque l'entrée aux joueurs non-staff.
-- `icon` = nom d'icône FontAwesome (compatible ox_lib).
Config.MainMenu = {
    command = 'menuprincipal',
    key = 'F1',
    title = 'UBUNTU RP',
    subtitle = 'Menu principal',
    items = {
        { label = 'Boutique premium',    description = 'Points : cosmétiques, véhicules, VIP',  icon = 'gift',              command = 'boutique' },
        { label = 'Téléphone',           description = 'Ouvrir le téléphone',                   icon = 'phone',             command = 'phone' },
        { label = 'Se repérer en ville', description = 'Placer un repère vers un lieu clé',      icon = 'map-location-dot',  type = 'locations' },
        { label = 'Aide & commandes',    description = 'Liste des commandes utiles',             icon = 'circle-question',   type = 'help' },
        { label = 'Panel Admin',         description = 'Gestion des joueurs (staff)',            icon = 'shield-halved',     command = 'admin', staffOnly = true },
    },
}

-- Lignes d'aide affichées par l'entrée « Aide & commandes ».
Config.HelpLines = {
    '/boutique — boutique premium (Points)',
    'F1 — ce menu principal · F6 — panel staff',
    'Échap — menu pause',
    'E — interagir avec un commerce/PNJ de proximité',
}

-- --- Habillage du menu pause (Échap) ----------------------------------------
-- `syncMoney` : pousse les comptes ESX (money + bank) dans les stats natives du
-- menu pause GTA (MP0_WALLET_BALANCE / BANK_BALANCE), sinon elles restent à 0
-- (ESX ne synchronise pas ces stats). Pas de HUD à l'écran (retiré à la demande).
Config.PauseMenu = {
    enabled = true,
    title = 'UBUNTU RP',
    syncMoney = true,
}

-- --- Roue de sélection d'arme à la molette ----------------------------------
-- Par défaut GTA fait défiler l'arme directement à la molette et n'ouvre la
-- roue de sélection qu'en maintenant TAB. Activé, un coup de molette (haut ou
-- bas) ouvre la roue et la maintient affichée `openMs` millisecondes pour
-- choisir tranquillement (chaque nouveau cran de molette relance le minuteur).
Config.WeaponWheel = {
    enabled = true,
    openMs = 1500,
}

-- --- Carte : points d'intérêt (blips) ---------------------------------------
-- Carte « officielle » du serveur ; s'ajoute aux blips créés par d'autres
-- ressources. `menu = true` fait apparaître le lieu dans « Se repérer » (F1).
-- Réf. sprites/couleurs : https://docs.fivem.net/docs/game-references/blips/
Config.ShowBlips = true
Config.Blips = {
    -- === Services publics ===
    { label = 'Police',          sprite = 60,  color = 29, scale = 0.9, coords = vector3(428.3, -984.2, 30.7),   menu = true },
    { label = 'Hôpital',         sprite = 61,  color = 1,  scale = 0.9, coords = vector3(298.6, -584.4, 43.3),   menu = true },
    -- Blip Mairie géré par `ubuntu-mairie` (PNJ + centre pour l'emploi) — pas de doublon ici.

    -- === Banques ===
    -- Blips gérés par `ubuntu-banque` (guichets interactifs) — pas de doublon ici.

    -- === Automobile ===
    { label = 'Concession auto', sprite = 326, color = 3,  scale = 0.8, coords = vector3(-56.7, -1096.6, 26.4), menu = true },
    { label = 'Garage / Mécano', sprite = 446, color = 47, scale = 0.8, coords = vector3(-337.0, -136.0, 39.0),  menu = true },

    -- === Commerces ===
    { label = 'Supérette',       sprite = 52,  color = 46, scale = 0.7, coords = vector3(373.5, 325.6, 103.6) },
    { label = 'Supérette (ouest)', sprite = 52, color = 46, scale = 0.7, coords = vector3(-3045.0, 585.5, 7.9) },
    { label = 'Supérette (est)', sprite = 52,  color = 46, scale = 0.7, coords = vector3(1965.0, 3741.5, 32.3) },
    { label = 'Marché',          sprite = 52,  color = 5,  scale = 0.8, coords = vector3(199.0, -928.0, 30.7),   menu = true },
    { label = 'Station-service', sprite = 361, color = 46, scale = 0.7, coords = vector3(265.0, -1261.3, 29.3) },
    { label = 'Station-service (nord)', sprite = 361, color = 46, scale = 0.7, coords = vector3(49.4, 2778.8, 58.0) },
}
