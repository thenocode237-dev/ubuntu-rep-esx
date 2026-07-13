Locales = Locales or {}
Locales.en = {
    menu = {
        ['bank_title']  = 'Bank',
        ['atm_title']   = 'ATM',
        ['balance']     = 'Balance: %{cash} cash · %{bank} bank',
        ['deposit']     = 'Deposit',
        ['deposit_desc'] = 'Deposit cash into your bank account',
        ['withdraw']    = 'Withdraw',
        ['withdraw_desc'] = 'Withdraw money from your bank account',
        ['transfer']    = 'Transfer',
        ['transfer_desc'] = 'Send money to another player',
    },
    dialog = {
        ['amount']      = 'Amount',
        ['deposit_title'] = 'Deposit',
        ['withdraw_title'] = 'Withdraw',
        ['transfer_title'] = 'Transfer',
        ['target_id']   = 'Player id (ID)',
    },
    prompt = {
        ['open_bank']   = '[E] Bank teller',
        ['use_atm']     = 'ATM',
    },
    success = {
        ['deposit']       = 'Deposited %{amount}',
        ['withdraw']      = 'Withdrew %{amount}',
        ['transfer_sent'] = 'Transferred %{amount} to %{target}',
        ['transfer_recv'] = 'You received %{amount} from %{sender}',
    },
    error = {
        ['invalid_amount']   = 'Invalid amount',
        ['insufficient_cash'] = 'You do not have enough cash',
        ['insufficient_bank'] = 'Insufficient bank balance',
        ['transfer_off']     = 'Transfers are disabled',
        ['target_not_found'] = 'Player not found',
        ['target_self']      = 'You cannot transfer money to yourself',
        ['too_fast']         = 'Please wait a moment',
    },
}
