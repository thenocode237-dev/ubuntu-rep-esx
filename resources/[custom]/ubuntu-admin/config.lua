Config = {}

-- Groupes ESX autorisés à ouvrir le panel et exécuter les actions.
-- Vérifié via xPlayer.getGroup() côté serveur (colonne users.group).
Config.AllowedGroups = { 'admin', 'superadmin', 'mod' }

-- Commande + keybind d'ouverture (le joueur peut réassigner la touche).
Config.OpenCommand = 'admin'
Config.DefaultKey = 'F6'

-- Durée de ban par défaut (jours).
Config.DefaultBanDays = 1

-- Comptes ESX modifiables depuis le panel (money = cash).
Config.MoneyTypes = { 'money', 'bank', 'black_money' }

-- Envoi des logs d'action staff vers Discord (convar `discord_webhook`,
-- déjà présente dans config/server.cfg.template). Vide = désactivé.
Config.DiscordWebhookConvar = 'discord_webhook'
Config.DiscordBotName = 'Ubuntu RP — Admin'
