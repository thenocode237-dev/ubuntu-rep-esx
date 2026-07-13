-- Boutique premium (Points). Importé par scripts/install-resources.sh
-- (SQL des ressources [custom]). Idempotent : CREATE TABLE IF NOT EXISTS.

-- État premium par joueur (ESX n'a pas de metadata générique) :
--   points  = solde de points de dons (crédité par /addpoints)
--   data    = JSON { owned = {id=true}, cosmetics = {}, rank, perks = {} }
-- Clé = identifier ESX (license:xx..).
CREATE TABLE IF NOT EXISTS `ubuntu_premium_data` (
  `identifier` varchar(60) NOT NULL,
  `points`     int(11)     NOT NULL DEFAULT 0,
  `data`       longtext    DEFAULT NULL,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Journal d'audit des achats.
CREATE TABLE IF NOT EXISTS `ubuntu_premium_purchases` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(60) DEFAULT NULL,
  `item_id` varchar(64) DEFAULT NULL,
  `item_label` varchar(128) DEFAULT NULL,
  `cost` int(11) NOT NULL DEFAULT 0,
  `purchased_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
