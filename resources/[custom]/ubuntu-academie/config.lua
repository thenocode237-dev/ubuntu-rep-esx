Config = {}

-- =============================================================================
-- ubuntu-academie — centre d'accueil / académie RP. Un PNJ « formateur » à qui
-- parler ouvre un menu de tutoriels (trouver un travail, se lancer dans
-- l'illégal, acheter une voiture, acheter une maison, lancer un business).
-- Les nouveaux joueurs reçoivent, à leur première connexion, une notification
-- les invitant à s'y rendre (un point sur la carte / GPS les y guide).
--
-- Data-driven : ajouter un point = 1 entrée dans Config.Points ; ajouter un
-- tutoriel = 1 entrée dans Config.Tutorials + son texte dans locales/*.lua.
-- Aucune logique sensible côté serveur : le serveur ne gère que le suivi
-- « ce joueur a-t-il déjà vu l'académie » (table ubuntu_academy_seen).
-- =============================================================================

-- --- Interaction de proximité (identique aux autres ressources maison) -------
Config.MarkerRadius = 2.0
Config.DrawDistance = 15.0
Config.InteractKey  = 38 -- E
Config.MarkerColor  = { r = 91, g = 76, b = 240 } -- accent indigo #5B4CF0

-- --- Notification des nouveaux joueurs ---------------------------------------
-- À la première connexion (identifier absent de ubuntu_academy_seen), on invite
-- le joueur à se rendre à l'académie. Un blip clignotant + itinéraire GPS le
-- guide vers le PREMIER point de Config.Points. Le joueur est marqué « vu » dès
-- qu'il ouvre le menu de l'académie (la notif ne réapparaît plus ensuite).
Config.Notify = {
    enabled    = true,
    delay      = 8000,   -- ms après esx:playerLoaded avant d'afficher la notif
    duration   = 12000,  -- ms d'affichage de la notif
    routeBlip  = true,   -- pose un itinéraire GPS clignotant vers l'académie
    routeColor = 5,      -- jaune
}

-- --- Points d'accueil (PNJ + blip) -------------------------------------------
-- `coords` = position/orientation du PNJ et du marqueur d'accès.
Config.Points = {
    {
        id     = 'centre',
        label  = 'Académie — Centre d\'accueil',
        ped    = 'a_m_m_business_01',
        coords = vector4(-263.9, -956.3, 31.2, 208.0), -- près de la mairie / centre-ville
        blip   = { sprite = 407, color = 5, scale = 0.9 },
    },
}

-- --- Tutoriels (menu) --------------------------------------------------------
-- Chaque entrée pointe vers une clé de locale : `tutorials.<id>.title`,
-- `tutorials.<id>.short` (sous-titre du menu) et `tutorials.<id>.content`
-- (markdown affiché dans une fenêtre lib.alertDialog). `icon` = icône FontAwesome
-- (rendu par ox_lib). Réordonner / masquer = éditer cette liste.
Config.Tutorials = {
    { id = 'welcome',  icon = 'circle-info' },
    { id = 'job',      icon = 'briefcase' },
    { id = 'illegal',  icon = 'user-secret' },
    { id = 'vehicle',  icon = 'car' },
    { id = 'house',    icon = 'house' },
    { id = 'business', icon = 'store' },
}
