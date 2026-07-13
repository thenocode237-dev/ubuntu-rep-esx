-- Table de bannissements (ESX n'en fournit pas). Importée par
-- scripts/install-resources.sh (SQL des ressources [custom]). Idempotent.
-- Le check à la connexion vit dans ubuntu-admin/server.lua (playerConnecting).
CREATE TABLE IF NOT EXISTS `bans` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `license` varchar(120) DEFAULT NULL,
  `discord` varchar(120) DEFAULT NULL,
  `ip` varchar(120) DEFAULT NULL,
  `reason` varchar(255) DEFAULT NULL,
  `expire` int(11) DEFAULT 0,
  `bannedby` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
