Config = {}

-- Compte ESX utilisé pour les frais et la caution (money = liquide).
Config.MoneyType = 'money'

-- Distance (m) au point de location pour interagir, et touche d'interaction (E).
Config.MarkerRadius = 2.0
Config.DrawDistance = 15.0
Config.InteractKey = 38 -- E

-- Marqueur au sol (accent indigo #5B4CF0).
Config.MarkerColor = { r = 91, g = 76, b = 240 }

-- ---------------------------------------------------------------------------
-- Points de location. Chaque point : un PNJ + un blip + un marqueur ; le
-- véhicule loué apparaît à `spawn`. La logique (débit frais + caution, remise
-- de caution) est côté serveur — le client ne fait qu'afficher et spawn/supprimer.
--
-- Pour un bateau, `spawn` doit être un point sur l'eau (ajuster en jeu si besoin).
--
-- vehicles[].fee     = frais de location (non remboursés)
-- vehicles[].deposit = caution (remboursée à la restitution du véhicule)
-- ---------------------------------------------------------------------------
Config.Points = {
    {
        id = 'marina_boats', type = 'boat',
        label = 'Location bateau — Marina',
        ped = 's_m_m_dockwork_01',
        coords = vector4(-794.7, -1506.9, 1.6, 200.0),   -- ponton / PNJ + marqueur
        spawn  = vector4(-805.4, -1496.6, 0.0, 200.0),   -- mise à l'eau
        blip = { sprite = 410, color = 3, scale = 0.8 }, -- ancre, bleu
        vehicles = {
            { model = 'dinghy',   label = 'Zodiac',            fee = 2000, deposit = 5000 },
            { model = 'seashark', label = 'Jet-ski',           fee = 1500, deposit = 3000 },
            { model = 'suntrap',  label = 'Vedette de plaisance', fee = 4000, deposit = 10000 },
        },
    },
    {
        id = 'downtown_scooters', type = 'scooter',
        label = 'Location scooter — Centre-ville',
        ped = 's_m_m_autoshop_01',
        coords = vector4(215.0, -810.0, 30.7, 340.0),
        spawn  = vector4(218.5, -813.0, 30.6, 250.0),
        blip = { sprite = 226, color = 5, scale = 0.7 }, -- scooter, jaune
        vehicles = {
            { model = 'faggio',  label = 'Scooter urbain', fee = 800,  deposit = 2000 },
            { model = 'faggio2', label = 'Scooter sport',  fee = 1200, deposit = 2500 },
        },
    },
    {
        id = 'promenade_bikes', type = 'bike',
        label = 'Location vélo — Promenade',
        ped = 'a_m_y_hipster_01',
        coords = vector4(-1223.0, -1367.0, 4.3, 200.0),  -- promenade en bord de mer
        spawn  = vector4(-1226.0, -1369.0, 4.2, 110.0),
        blip = { sprite = 376, color = 2, scale = 0.7 }, -- vélo, vert
        vehicles = {
            { model = 'bmx',      label = 'Vélo BMX',      fee = 300, deposit = 800 },
            { model = 'cruiser',  label = 'Vélo de ville', fee = 300, deposit = 800 },
            { model = 'scorcher', label = 'VTT',           fee = 500, deposit = 1200 },
        },
    },
}
