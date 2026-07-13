-- Journal des transactions bancaires (ubuntu-banque). Idempotent : importé à
-- chaque `make resources` par import_custom_sql (CREATE TABLE IF NOT EXISTS).
CREATE TABLE IF NOT EXISTS `ubuntu_bank_transactions` (
  `id`                INT AUTO_INCREMENT PRIMARY KEY,
  `identifier`        VARCHAR(60)  NOT NULL,
  `type`              VARCHAR(20)  NOT NULL,   -- deposit | withdraw | transfer_in | transfer_out
  `amount`            INT          NOT NULL,
  `balance_after`     INT          DEFAULT NULL,
  `target_identifier` VARCHAR(60)  DEFAULT NULL,
  `created_at`        TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_identifier` (`identifier`),
  INDEX `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
