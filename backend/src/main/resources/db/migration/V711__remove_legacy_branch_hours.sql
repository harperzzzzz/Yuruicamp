-- Consolidate the legacy branches.hours value into the authoritative
-- branches.business_hours column before removing the legacy column.
UPDATE branches
SET business_hours = hours,
    updated_at = now()
WHERE hours IS NOT NULL
  AND btrim(hours) <> ''
  AND btrim(business_hours) = '';

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM branches
    WHERE hours IS NOT NULL
      AND btrim(hours) <> ''
      AND btrim(business_hours) = ''
  ) THEN
    RAISE EXCEPTION 'branches.hours contains values that were not migrated to business_hours';
  END IF;
END
$$;

ALTER TABLE branches
  DROP COLUMN hours;
