Config = {}

-- =============================================================================
-- ubuntu-boite — boite de nuit ESX (entree + bar + DJ/ambiance).
-- 100 % serveur-authoritative : le client n'envoie qu'une intention (entrer,
-- acheter une boisson, basculer l'ambiance) ; le serveur revalide tout et
-- applique l'argent via l'API ESX / les items via ox_inventory.
--
-- INTERIEUR : on reutilise la discotheque NATIVE de GTA V (DLC After Hours),
-- toujours presente dans la map (aucun MLO externe, aucune licence a verifier).
-- L'entree exterieure teleporte le joueur vers les coords fixes de l'interieur ;
-- une sortie [E]/target a l'interieur le ramene dehors.
-- =============================================================================

-- Comptes ESX. `money` = liquide (item ox_inventory).
Config.CashAccount = 'money'

-- Garde-fous serveur (anti-spam / anti-triche).
Config.Cooldown  = 750          -- ms entre deux achats d'un meme joueur
Config.MaxAmount = 1000000       -- plafond de securite par operation

-- Interaction de proximite (identique aux autres ressources maison).
Config.MarkerRadius = 2.0
Config.DrawDistance = 12.0
Config.InteractKey  = 38         -- E
Config.MarkerColor  = { r = 91, g = 76, b = 240 } -- accent indigo #5B4CF0

-- ---------------------------------------------------------------------------
-- Entree exterieure : videur (PNJ) + blip + marqueur [E]. Une entree = 1 point.
-- ⚠️ Coords exterieures approximatives (a affiner en jeu) ; le PNJ est cale au
-- sol par groundSnap (comme ubuntu-banque). L'interieur, lui, est fixe (natif).
-- ---------------------------------------------------------------------------
Config.Entrances = {
    {
        label  = 'Boite de nuit',
        ped    = 'a_m_y_business_01',
        coords = vector4(-1153.6, -1571.5, 4.4, 130.0), -- porte cote Vespucci
        blip   = { sprite = 614, color = 27, scale = 0.9 },
    },
}

-- Frais d'entree (cover charge). 0 = entree libre. Preleve sur le cash a l'entree.
Config.Entry = {
    fee = 100,
}

-- ---------------------------------------------------------------------------
-- Interieur natif (discotheque After Hours). Coords fixes dans la map.
--   inside : point d'arrivee a l'interieur (bas de l'escalier / piste).
--   exit   : point + zone [E] pour ressortir (renvoie vers l'entree utilisee).
--   ipl / entitySet : chargement + habillage de l'interieur natif.
-- ---------------------------------------------------------------------------
Config.Interior = {
    inside = vector4(-1571.9, -3016.7, -76.0, 90.0),
    exit   = vector4(-1568.4, -3013.9, -76.0, 270.0),
    -- Le nightclub natif se charge via son interieur ; on l'active + un entity set
    -- par defaut pour l'habiller (bar, mobilier). Sans effet si deja actif.
    entitySets = { 'set_nightclub_lights_hanging', 'Int01_style01' },
}

-- ---------------------------------------------------------------------------
-- Bar : ciblage ox_target sur une zone a l'interieur. Menu de boissons.
-- Les items doivent exister dans ox_inventory (ajoutes par append_club_items
-- dans scripts/install-resources.sh). Prix = cash, valides cote serveur.
-- ---------------------------------------------------------------------------
Config.Bar = {
    zone = { coords = vector3(-1596.9, -3013.2, -76.0), size = vector3(3.5, 1.5, 2.0), rotation = 0.0 },
    drinks = {
        { item = 'biere',     label = 'Biere',      price = 150 },
        { item = 'cocktail',  label = 'Cocktail',   price = 350 },
        { item = 'shooter',   label = 'Shooter',    price = 250 },
        { item = 'champagne', label = 'Champagne',  price = 1200 },
    },
}

-- ---------------------------------------------------------------------------
-- DJ booth : ciblage ox_target pour basculer l'ambiance musicale (GlobalState
-- repliquee a tous les clients dans l'interieur → musique NUI synchronisee).
-- ---------------------------------------------------------------------------
Config.Dj = {
    zone = { coords = vector3(-1570.0, -3023.7, -75.9), size = vector3(2.5, 2.5, 2.0), rotation = 0.0 },
}

-- ---------------------------------------------------------------------------
-- Societe (optionnel, DESACTIVE par defaut). Si active, le revenu des boissons
-- est verse au compte de societe `society_boite` (esx_addonaccount) au lieu
-- d'etre un simple puits d'argent. Necessite esx_society + le job/societe.
-- ---------------------------------------------------------------------------
Config.Society = {
    enabled = false,
    account = 'society_boite',
}
