Locales = Locales or {}
Locales.fr = {
    prompt = {
        ['open'] = '[E] Parler au formateur',
    },
    menu = {
        ['title']    = 'Académie — Guide du joueur',
        ['subtitle'] = 'Choisissez un sujet pour tout savoir',
        ['close']    = 'Fermer',
        ['read']     = 'Lire le guide',
    },
    notify = {
        -- Affiché aux nouveaux joueurs à leur première connexion.
        ['newcomer'] = 'Bienvenue ! Rendez-vous à l\'Académie (point sur la carte) pour apprendre les bases du serveur.',
        ['blip']     = 'Académie',
    },
    -- --- Contenu des tutoriels (markdown ox_lib) -----------------------------
    tutorials = {
        welcome = {
            ['title']   = 'Bienvenue sur Ubuntu RP',
            ['short']   = 'Les premiers pas',
            ['content'] =
                '## Bienvenue sur **Ubuntu RP** !\n\n' ..
                'Vous incarnez un personnage dans une ville vivante. Le but : **jouer un rôle** ' ..
                '(RP) de façon crédible et vous construire une vie.\n\n' ..
                '**Les bases :**\n' ..
                '- Ouvrez votre **inventaire** et vos infos avec les touches par défaut.\n' ..
                '- Consultez la **carte** (Échap ou minimap) : chaque icône est un service.\n' ..
                '- Votre **argent** est en liquide (sur vous) ou à la **banque**.\n' ..
                '- Parlez aux autres joueurs : le RP passe avant tout par l\'interaction.\n\n' ..
                'Parcourez les autres guides de ce menu pour démarrer concrètement.',
        },
        job = {
            ['title']   = 'Trouver un travail',
            ['short']   = 'Gagner sa vie légalement',
            ['content'] =
                '## Trouver un travail\n\n' ..
                'Un travail **légal** vous verse un revenu régulier et vous donne un rôle dans la ville.\n\n' ..
                '**Comment faire :**\n' ..
                '1. Repérez les **métiers** sur la carte (police, ambulancier/EMS, etc.).\n' ..
                '2. Rendez-vous sur place et prenez votre **service** (pointeuse / vestiaire).\n' ..
                '3. Réalisez les missions du métier pour être payé sur votre compte.\n' ..
                '4. Certains postes nécessitent une **autorisation d\'un responsable** — demandez au staff.\n\n' ..
                '**Conseil :** commencez par un petit boulot pour vous constituer un capital, ' ..
                'puis visez un métier plus rémunérateur ou montez en grade.',
        },
        illegal = {
            ['title']   = 'Se lancer dans l\'illégal',
            ['short']   = 'Risqué mais lucratif',
            ['content'] =
                '## La voie illégale\n\n' ..
                'Plus rentable, mais **risquée** : la police peut vous arrêter et vous perdez tout.\n\n' ..
                '**Le trafic de drogue :**\n' ..
                '- Approvisionnez-vous auprès d\'un **grossiste** (point discret sur la carte).\n' ..
                '- Revendez aux PNJ dans les **zones chaudes** de la ville.\n' ..
                '- Chaque vente augmente votre **chaleur** : au-delà d\'un seuil, la police est alertée.\n\n' ..
                '**Les braquages :**\n' ..
                '- Supérettes, distributeurs (ATM) puis banques, du moins au plus risqué.\n' ..
                '- Certains exigent du **matériel** (kit électronique, thermite) et un minimum de policiers en service.\n\n' ..
                '**Attention :** l\'illégal est du RP — pas du chaos gratuit. Respectez les règles du serveur.',
        },
        vehicle = {
            ['title']   = 'Acheter une voiture',
            ['short']   = 'Rouler en ville',
            ['content'] =
                '## Acheter un véhicule\n\n' ..
                '**Étapes :**\n' ..
                '1. Rendez-vous à la **concession** (icône véhicule sur la carte).\n' ..
                '2. Choisissez un modèle selon votre budget et validez l\'achat.\n' ..
                '3. Le véhicule est enregistré à **votre nom** et rangé dans votre **garage**.\n' ..
                '4. Allez au **garage** le plus proche pour le **sortir**, puis **rangez-le** en repartant.\n\n' ..
                '**Bon à savoir :**\n' ..
                '- Verrouillez/déverrouillez votre véhicule avec la touche dédiée (anti-vol).\n' ..
                '- Un véhicule sorti apparaît sur votre **GPS**.\n' ..
                '- Faites le plein à la station et entretenez-le chez un mécano.',
        },
        house = {
            ['title']   = 'Acheter une maison',
            ['short']   = 'Avoir un chez-soi',
            ['content'] =
                '## Acheter une maison\n\n' ..
                'Une propriété vous offre un point de spawn, un coffre de stockage et un vrai foyer RP.\n\n' ..
                '**Étapes :**\n' ..
                '1. Repérez les **propriétés à vendre** en ville (panneau / point d\'entrée).\n' ..
                '2. Approchez la porte et consultez le **prix**.\n' ..
                '3. Si votre compte le permet, **achetez** : la maison devient la vôtre.\n' ..
                '4. Entrez, rangez vos affaires dans le **coffre** et définissez-la comme domicile.\n\n' ..
                '**Conseil :** commencez petit (studio/appartement) avant d\'investir dans une grande villa.',
        },
        business = {
            ['title']   = 'Lancer ou acheter un business',
            ['short']   = 'Devenir entrepreneur',
            ['content'] =
                '## Créer ou reprendre un business\n\n' ..
                'Diriger une entreprise, c\'est employer d\'autres joueurs et faire tourner l\'économie.\n\n' ..
                '**Comment démarrer :**\n' ..
                '1. Constituez d\'abord un **capital** (travail légal + économies).\n' ..
                '2. Choisissez une activité : commerce, société de service, entreprise de métier...\n' ..
                '3. Contactez le **staff / la mairie** pour ouvrir ou reprendre une société.\n' ..
                '4. Recrutez des employés, fixez les salaires et gérez le **compte de société**.\n\n' ..
                '**Conseil :** un bon patron soigne son RP, ses clients et ses employés — ' ..
                'la réputation vaut plus que l\'argent.',
        },
    },
}
