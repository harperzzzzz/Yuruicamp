\set ON_ERROR_STOP on

DO $$
DECLARE
  invalid_constraints TEXT;
BEGIN
  SELECT string_agg(constraint_name, ', ' ORDER BY constraint_name)
  INTO invalid_constraints
  FROM (
    VALUES
      ('fk_customer_preferences_customer_id'),
      ('fk_customer_shipping_addresses_customer_id'),
      ('fk_customer_tag_assignments_customer_id')
  ) expected(constraint_name)
  LEFT JOIN pg_constraint actual
    ON actual.conname = expected.constraint_name
   AND actual.contype = 'f'
   AND actual.confdeltype = 'r'
  WHERE actual.oid IS NULL;

  IF invalid_constraints IS NOT NULL THEN
    RAISE EXCEPTION 'customer foreign keys are not ON DELETE RESTRICT: %',
      invalid_constraints;
  END IF;
END $$;
