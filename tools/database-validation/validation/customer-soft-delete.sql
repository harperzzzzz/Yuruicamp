\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
  customer_id_value VARCHAR(32);
  preference_id_value BIGINT;
  tag_id_value BIGINT;
BEGIN
  INSERT INTO customers (
    name, email, registered_at, points, first_purchase_used, auth_provider
  ) VALUES (
    'Soft Delete Test', 'soft-delete-test@example.invalid', now(), 0, false, 'google'
  ) RETURNING id INTO customer_id_value;

  IF customer_id_value IS NULL
     OR length(customer_id_value) <> 32
     OR customer_id_value !~ '^[0-9a-f]{32}$' THEN
    RAISE EXCEPTION 'database-generated customer id is invalid: %', customer_id_value;
  END IF;

  SELECT id INTO preference_id_value FROM preference_options ORDER BY id LIMIT 1;
  SELECT id INTO tag_id_value FROM customer_tags ORDER BY id LIMIT 1;

  INSERT INTO customer_preferences (customer_id, preference_id)
  VALUES (customer_id_value, preference_id_value);
  INSERT INTO customer_tag_assignments (customer_id, tag_id)
  VALUES (customer_id_value, tag_id_value);

  IF NOT soft_delete_customer(customer_id_value) THEN
    RAISE EXCEPTION 'soft delete did not update the customer';
  END IF;

  IF EXISTS (SELECT 1 FROM active_customers WHERE id = customer_id_value) THEN
    RAISE EXCEPTION 'soft-deleted customer remains visible to active queries';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM customers
    WHERE id = customer_id_value
      AND active = false
      AND deleted_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'soft-delete state was not persisted';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM customer_preferences WHERE customer_id = customer_id_value
  ) OR NOT EXISTS (
    SELECT 1 FROM customer_tag_assignments WHERE customer_id = customer_id_value
  ) THEN
    RAISE EXCEPTION 'customer relationships were removed by soft delete';
  END IF;

  BEGIN
    DELETE FROM customers WHERE id = customer_id_value;
    RAISE EXCEPTION 'hard delete was accepted';
  EXCEPTION WHEN integrity_constraint_violation THEN NULL;
  END;
END $$;

ROLLBACK;
