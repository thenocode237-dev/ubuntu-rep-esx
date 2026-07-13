-- =============================================================================
-- Ubuntu RP — schéma ESX Legacy de base (versionné, importé par
-- scripts/install-resources.sh à la place de l'ancien qbcore.sql).
--
-- Suit le schéma de référence ESX Legacy (users/jobs/job_grades/user_licenses/
-- owned_vehicles). Idempotent (CREATE TABLE IF NOT EXISTS). Les ressources ESX
-- (es_extended, ox_inventory, esx_identity, métiers...) apportent leurs propres
-- SQL additionnels, importés ensuite par le script.
--
-- ⚠️  À réconcilier avec le SQL exact des versions es_extended / ox_inventory
--     installées lors du premier déploiement (colonnes ajoutées par ces
--     ressources : ce fichier fournit une base fonctionnelle, pas l'exhaustif).
-- =============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- --- Joueurs -----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `users` (
  `identifier`   VARCHAR(60)  NOT NULL,
  `accounts`     LONGTEXT     DEFAULT NULL,
  `group`        VARCHAR(50)  DEFAULT 'user',
  `inventory`    LONGTEXT     DEFAULT NULL,
  `job`          VARCHAR(20)  DEFAULT 'unemployed',
  `job_grade`    INT(11)      DEFAULT 0,
  `loadout`      LONGTEXT     DEFAULT NULL,
  `position`     VARCHAR(255) DEFAULT NULL,
  `firstname`    VARCHAR(50)  DEFAULT NULL,
  `lastname`     VARCHAR(50)  DEFAULT NULL,
  `dateofbirth`  VARCHAR(25)  DEFAULT NULL,
  `sex`          VARCHAR(10)  DEFAULT NULL,
  `height`       INT(11)      DEFAULT NULL,
  `skin`         LONGTEXT     DEFAULT NULL,
  `metadata`     LONGTEXT     DEFAULT NULL,
  `disabled`     TINYINT(1)   DEFAULT 0,
  `is_dead`      TINYINT(1)   DEFAULT 0,
  `last_seen`    TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- --- Métiers (ESX par défaut ; les ressources métier ajoutent les leurs) ------
CREATE TABLE IF NOT EXISTS `jobs` (
  `name`         VARCHAR(50) NOT NULL,
  `label`        VARCHAR(50) DEFAULT NULL,
  `whitelisted`  TINYINT(1)  DEFAULT 0,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `job_grades` (
  `id`           INT(11)     NOT NULL AUTO_INCREMENT,
  `job_name`     VARCHAR(50) DEFAULT NULL,
  `grade`        INT(11)     DEFAULT 0,
  `name`         VARCHAR(50) DEFAULT NULL,
  `label`        VARCHAR(50) DEFAULT NULL,
  `salary`       INT(11)     DEFAULT 0,
  `skin_male`    LONGTEXT    DEFAULT NULL,
  `skin_female`  LONGTEXT    DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Métier par défaut : sans emploi (les métiers ESX Phase 2 ajoutent police, etc.)
INSERT INTO `jobs` (`name`, `label`, `whitelisted`) VALUES
  ('unemployed', 'Sans emploi', 0)
ON DUPLICATE KEY UPDATE `label` = VALUES(`label`);

INSERT INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`, `skin_male`, `skin_female`) VALUES
  ('unemployed', 0, 'unemployed', 'Sans emploi', 200, '{}', '{}')
ON DUPLICATE KEY UPDATE `label` = VALUES(`label`);

-- --- Licences (permis) --------------------------------------------------------
CREATE TABLE IF NOT EXISTS `user_licenses` (
  `id`      INT(11)     NOT NULL AUTO_INCREMENT,
  `type`    VARCHAR(60) DEFAULT NULL,
  `owner`   VARCHAR(60) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- --- Véhicules possédés (utilisé par le concessionnaire / garage / premium) ---
CREATE TABLE IF NOT EXISTS `owned_vehicles` (
  `owner`         VARCHAR(60)  DEFAULT NULL,
  `plate`         VARCHAR(12)  NOT NULL,
  `vehicle`       LONGTEXT     DEFAULT NULL,
  `type`          VARCHAR(20)  DEFAULT 'car',
  `job`           VARCHAR(20)  DEFAULT NULL,
  `stored`        TINYINT(1)   DEFAULT 1,
  PRIMARY KEY (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET FOREIGN_KEY_CHECKS = 1;
