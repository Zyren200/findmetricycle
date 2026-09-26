-- Migration: archive legacy cashless tables without deleting records.
-- These tables are no longer used by the cash-only Admin Dashboard V2 flow.

SET @db_name = DATABASE();

SET @has_old = (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.TABLES
  WHERE TABLE_SCHEMA = @db_name
    AND TABLE_NAME = 'wallets'
);
SET @has_new = (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.TABLES
  WHERE TABLE_SCHEMA = @db_name
    AND TABLE_NAME = 'legacy_cashless_accounts'
);
SET @sql = IF(@has_old = 1 AND @has_new = 0, 'RENAME TABLE wallets TO legacy_cashless_accounts', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_old = (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.TABLES
  WHERE TABLE_SCHEMA = @db_name
    AND TABLE_NAME = 'payments'
);
SET @has_new = (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.TABLES
  WHERE TABLE_SCHEMA = @db_name
    AND TABLE_NAME = 'legacy_cashless_records'
);
SET @sql = IF(@has_old = 1 AND @has_new = 0, 'RENAME TABLE payments TO legacy_cashless_records', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_old = (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.TABLES
  WHERE TABLE_SCHEMA = @db_name
    AND TABLE_NAME = 'wallet_transactions'
);
SET @has_new = (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.TABLES
  WHERE TABLE_SCHEMA = @db_name
    AND TABLE_NAME = 'legacy_cashless_ledger'
);
SET @sql = IF(@has_old = 1 AND @has_new = 0, 'RENAME TABLE wallet_transactions TO legacy_cashless_ledger', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
