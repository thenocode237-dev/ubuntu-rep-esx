fx_version 'cerulean'
game 'gta5'

name 'ubuntu-otaku'
author 'Ubuntu RP'
description 'Conteneur de contenu streame otaku / anime (vetements, accessoires, props). Depose tes assets legit dans stream/.'
version '1.0.0'

-- Tout fichier place dans stream/ (recursif) est streame automatiquement des que
-- la ressource est demarree (ensure ubuntu-otaku). Pas besoin de le lister ici :
-- .ydd / .ytd / .ymt / #dd / #td des vetements MP freemode sont detectes seuls.

-- Vetements ADD-ON (drawables supplementaires via une meta) : decommente la ligne
-- correspondant au(x) fichier(s) .meta fourni(s) par ton pack, et liste-les dans files{}.
-- files {
--     'stream/mp_m_freemode_01^*.meta',
--     'stream/mp_f_freemode_01^*.meta',
-- }
-- data_file 'SHOP_PED_APPAREL_META_FILE' 'stream/mp_m_freemode_01_male.meta'
-- data_file 'SHOP_PED_APPAREL_META_FILE' 'stream/mp_f_freemode_01_female.meta'
