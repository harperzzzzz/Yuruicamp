DROP INDEX IF EXISTS idx_branches_active_code;

ALTER TABLE branches
  DROP CONSTRAINT IF EXISTS uq_branches_code,
  DROP COLUMN code,
  DROP COLUMN active;
