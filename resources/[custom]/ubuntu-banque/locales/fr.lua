Locales = Locales or {}
Locales.fr = {
    menu = {
        ['bank_title']  = 'Banque',
        ['atm_title']   = 'Distributeur',
        ['balance']     = 'Solde : %{cash} cash · %{bank} banque',
        ['deposit']     = 'Déposer',
        ['deposit_desc'] = 'Verser du liquide sur le compte banque',
        ['withdraw']    = 'Retirer',
        ['withdraw_desc'] = 'Retirer de l\'argent du compte banque',
        ['transfer']    = 'Virement',
        ['transfer_desc'] = 'Envoyer de l\'argent à un autre joueur',
    },
    dialog = {
        ['amount']      = 'Montant',
        ['deposit_title'] = 'Dépôt',
        ['withdraw_title'] = 'Retrait',
        ['transfer_title'] = 'Virement',
        ['target_id']   = 'Identifiant du joueur (ID)',
    },
    prompt = {
        ['open_bank']   = '[E] Guichet bancaire',
        ['use_atm']     = 'Distributeur',
    },
    success = {
        ['deposit']       = 'Dépôt de %{amount} effectué',
        ['withdraw']      = 'Retrait de %{amount} effectué',
        ['transfer_sent'] = 'Virement de %{amount} envoyé à %{target}',
        ['transfer_recv'] = 'Vous avez reçu %{amount} de %{sender}',
    },
    error = {
        ['invalid_amount']   = 'Montant invalide',
        ['insufficient_cash'] = 'Vous n\'avez pas assez de liquide',
        ['insufficient_bank'] = 'Solde bancaire insuffisant',
        ['transfer_off']     = 'Les virements sont désactivés',
        ['target_not_found'] = 'Joueur introuvable',
        ['target_self']      = 'Vous ne pouvez pas vous virer de l\'argent',
        ['too_fast']         = 'Veuillez patienter un instant',
    },
}
