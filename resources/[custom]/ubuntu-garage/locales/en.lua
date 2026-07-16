Locales = Locales or {}
Locales.en = {
    menu = {
        ['title']       = 'Garage',
        ['take']        = 'Take out a vehicle',
        ['take_desc']   = 'Bring a stored vehicle out',
        ['store']       = 'Store the vehicle',
        ['store_desc']  = 'Store the vehicle you are in/near',
        ['none']        = 'No stored vehicle',
        ['plate']       = 'Plate: %{plate}',
    },
    prompt = {
        ['open']        = '[E] Garage',
    },
    success = {
        ['spawned']     = 'Vehicle taken out (plate %{plate})',
        ['stored']      = 'Vehicle stored (plate %{plate})',
        ['locked']      = 'Vehicle locked',
        ['unlocked']    = 'Vehicle unlocked',
    },
    error = {
        ['not_found']       = 'Vehicle not found',
        ['not_yours']       = 'This vehicle is not yours',
        ['already_out']     = 'This vehicle is already out',
        ['no_vehicle_near'] = 'No vehicle of yours nearby',
        ['no_owned_near']   = 'No vehicle of yours in reach',
        ['spawn_failed']    = 'Unable to spawn the vehicle',
        ['too_fast']        = 'Please wait a moment',
    },
    gps = {
        ['blip']        = 'My vehicle (%{plate})',
    },
}
