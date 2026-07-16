Locales = Locales or {}
Locales.fr = {
    prompt = {
        ['open'] = '[E] Parler à l\'agent municipal',
    },
    menu = {
        ['title']        = 'Mairie — Centre pour l\'emploi',
        ['current']      = 'Emploi actuel : %{job}',
        ['take']         = 'Prendre un emploi',
        ['take_desc']    = 'Choisir un métier disponible',
        ['quit']         = 'Quitter mon emploi',
        ['quit_desc']    = 'Redevenir « sans emploi »',
        ['staff_only']   = 'Réservé au staff',
        ['close']        = 'Fermer',
    },
    notify = {
        ['hired']        = 'Vous êtes désormais : %{job}.',
        ['quit']         = 'Vous avez quitté votre emploi (sans emploi).',
        ['already']      = 'Vous occupez déjà ce poste.',
        ['already_none'] = 'Vous êtes déjà sans emploi.',
        ['restricted']   = 'Ce poste nécessite l\'autorisation d\'un responsable — demandez au staff.',
        ['invalid']      = 'Ce métier n\'est pas disponible ici.',
    },
    -- Libellés des métiers (clé = nom du job en base). Sert au menu et aux notifs.
    jobs = {
        ['unemployed'] = 'Sans emploi',
        ['police']     = 'Police',
        ['ambulance']  = 'Ambulancier (EMS)',
        ['cardealer']  = 'Concessionnaire',
    },
}
