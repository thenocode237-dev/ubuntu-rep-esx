Config = {}

-- =============================================================================
-- ubuntu-mairie — mairie / centre pour l'emploi. Un PNJ « agent municipal » à
-- qui parler ouvre un menu ox_lib permettant de PRENDRE ou QUITTER un métier
-- (redevenir « sans emploi »). C'est le point d'entrée en jeu vers les métiers
-- ESX (police, EMS, concession...) : sans lui, seul /admin pouvait assigner un
-- job. 100 % serveur-authoritative : le client n'envoie qu'un nom de métier,
-- le serveur revalide TOUT contre Config.Jobs avant d'appliquer setJob().
--
-- Data-driven : ajouter un métier proposé = 1 entrée dans Config.Jobs (+ son
-- libellé dans locales/*.lua sous `jobs.<name>`). Ajouter un guichet = 1 entrée
-- dans Config.Points. Aucun SQL propre (ESX setJob persiste dans `users`).
-- =============================================================================

-- --- Interaction de proximité (identique aux autres ressources maison) -------
Config.MarkerRadius = 2.0
Config.DrawDistance = 15.0
Config.InteractKey  = 38 -- E
Config.MarkerColor  = { r = 91, g = 76, b = 240 } -- accent indigo #5B4CF0

-- --- Groupes autorisés à accorder les métiers `restricted` (police, EMS...) ---
-- Un métier marqué `restricted = true` n'est accordé QUE si le joueur qui le
-- demande a l'un de ces groupes ESX (staff). Sinon la mairie répond « demandez
-- au staff ». Mettre `restricted = false` sur un métier pour l'ouvrir à tous.
Config.StaffGroups = { admin = true, superadmin = true, mod = true }

-- --- Guichets mairie (PNJ + blip + marqueur [E]) -----------------------------
-- `coords` = position/orientation du PNJ et du marqueur d'accès. Le blip Mairie
-- vit désormais ici (retiré d'ubuntu-interface pour éviter le doublon).
Config.Points = {
    {
        id     = 'mairie',
        label  = 'Mairie — Centre pour l\'emploi',
        ped    = 'a_m_y_business_02',
        -- Hôtel de ville (bâtiment gouvernemental d'Alta / Legion SE). Emplacement
        -- canonique QBCore (qb-cityhall), accessible sur le trottoir devant l'entrée.
        coords = vector4(-262.79, -964.18, 30.22, 181.71),
        blip   = { sprite = 419, color = 0, scale = 0.9 },
    },
}

-- --- Métiers proposés à la mairie --------------------------------------------
-- Chaque entrée : { name, grade?, icon?, restricted? }.
--   name       = clé du métier dans la table `jobs` (validée côté serveur).
--   grade      = grade attribué (défaut 0 = recrue).
--   icon       = icône FontAwesome (ox_lib).
--   restricted = true → réservé au staff (métiers de service, whitelist RP).
-- Le libellé affiché vient de locales/*.lua : `jobs.<name>`.
Config.Jobs = {
    { name = 'police',     grade = 0, icon = 'shield-halved', restricted = false },
    { name = 'ambulance',  grade = 0, icon = 'truck-medical', restricted = false },
    { name = 'cardealer',  grade = 0, icon = 'car',           restricted = false },
}
