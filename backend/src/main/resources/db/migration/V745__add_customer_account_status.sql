CREATE TYPE public.customer_status AS ENUM (
  'active',
  'suspended',
  'deleted'
);

ALTER TABLE public.customers
  ADD COLUMN status public.customer_status;

UPDATE public.customers
SET status = CASE
  WHEN deleted_at IS NOT NULL THEN 'deleted'::public.customer_status
  WHEN active = FALSE THEN 'suspended'::public.customer_status
  ELSE 'active'::public.customer_status
END;

ALTER TABLE public.customers
  ALTER COLUMN status SET DEFAULT 'active'::public.customer_status,
  ALTER COLUMN status SET NOT NULL;

DROP VIEW public.active_customers;
DROP INDEX public.idx_customers_active_email;

ALTER TABLE public.customers
  DROP COLUMN active,
  ADD CONSTRAINT ck_customers_status_deleted_at CHECK (
    (status = 'deleted'::public.customer_status AND deleted_at IS NOT NULL)
    OR
    (status IN ('active'::public.customer_status, 'suspended'::public.customer_status)
      AND deleted_at IS NULL)
  );

CREATE VIEW public.active_customers AS
SELECT *
FROM public.customers
WHERE status = 'active'::public.customer_status
  AND deleted_at IS NULL;

CREATE INDEX idx_customers_active_email
  ON public.customers (email)
  WHERE status = 'active'::public.customer_status
    AND deleted_at IS NULL;

CREATE OR REPLACE FUNCTION public.soft_delete_customer(p_customer_id VARCHAR(32))
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
  affected_rows INTEGER;
BEGIN
  UPDATE public.customers
  SET status = 'deleted'::public.customer_status,
      deleted_at = now(),
      updated_at = now()
  WHERE id = p_customer_id
    AND status <> 'deleted'::public.customer_status;

  GET DIAGNOSTICS affected_rows = ROW_COUNT;
  RETURN affected_rows = 1;
END;
$$;

CREATE FUNCTION public.suspend_customer(p_customer_id VARCHAR(32))
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
  affected_rows INTEGER;
BEGIN
  UPDATE public.customers
  SET status = 'suspended'::public.customer_status,
      deleted_at = NULL,
      updated_at = now()
  WHERE id = p_customer_id
    AND status = 'active'::public.customer_status;

  GET DIAGNOSTICS affected_rows = ROW_COUNT;
  RETURN affected_rows = 1;
END;
$$;

CREATE FUNCTION public.reactivate_customer(p_customer_id VARCHAR(32))
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
  affected_rows INTEGER;
BEGIN
  UPDATE public.customers
  SET status = 'active'::public.customer_status,
      deleted_at = NULL,
      updated_at = now()
  WHERE id = p_customer_id
    AND status IN (
      'suspended'::public.customer_status,
      'deleted'::public.customer_status
    );

  GET DIAGNOSTICS affected_rows = ROW_COUNT;
  RETURN affected_rows = 1;
END;
$$;
