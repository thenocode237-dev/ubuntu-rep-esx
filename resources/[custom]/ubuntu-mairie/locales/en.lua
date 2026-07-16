Locales = Locales or {}
Locales.en = {
    prompt = {
        ['open'] = '[E] Talk to the city clerk',
    },
    menu = {
        ['title']        = 'City Hall — Job Center',
        ['current']      = 'Current job: %{job}',
        ['take']         = 'Take a job',
        ['take_desc']    = 'Pick an available job',
        ['quit']         = 'Quit my job',
        ['quit_desc']    = 'Become unemployed again',
        ['staff_only']   = 'Staff only',
        ['close']        = 'Close',
    },
    notify = {
        ['hired']        = 'You are now: %{job}.',
        ['quit']         = 'You quit your job (unemployed).',
        ['already']      = 'You already hold this job.',
        ['already_none'] = 'You are already unemployed.',
        ['restricted']   = 'This job requires a supervisor\'s approval — ask the staff.',
        ['invalid']      = 'This job is not available here.',
    },
    -- Job labels (key = job name in DB). Used by the menu and notifications.
    jobs = {
        ['unemployed'] = 'Unemployed',
        ['police']     = 'Police',
        ['ambulance']  = 'Paramedic (EMS)',
        ['cardealer']  = 'Car dealer',
    },
}
