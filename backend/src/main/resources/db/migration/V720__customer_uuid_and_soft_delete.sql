-- Customers receive database-generated 32-character UUID identifiers.
ALTER TABLE customers
  ALTER COLUMN id SET DEFAULT replace(gen_random_uuid()::text, '-', ''),
  ADD COLUMN deleted_at TIMESTAMPTZ NULL;

-- Application reads and login lookups must use this active-member projection.
CREATE VIEW active_customers AS
SELECT *
FROM customers
WHERE active = TRUE
  AND deleted_at IS NULL;

CREATE INDEX idx_customers_active_email
  ON customers (email)
  WHERE active = TRUE
    AND deleted_at IS NULL;

CREATE FUNCTION soft_delete_customer(p_customer_id VARCHAR(32))
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
  affected_rows INTEGER;
BEGIN
  UPDATE customers
  SET active = FALSE,
      deleted_at = now(),
      updated_at = now()
  WHERE id = p_customer_id
    AND active = TRUE
    AND deleted_at IS NULL;

  GET DIAGNOSTICS affected_rows = ROW_COUNT;
  RETURN affected_rows = 1;
END;
$$;

CREATE FUNCTION reject_customer_hard_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'customers must be soft deleted with soft_delete_customer(%)', OLD.id
    USING ERRCODE = '23000';
END;
$$;

CREATE TRIGGER trg_customers_prevent_hard_delete
BEFORE DELETE ON customers
FOR EACH ROW
EXECUTE FUNCTION reject_customer_hard_delete();
