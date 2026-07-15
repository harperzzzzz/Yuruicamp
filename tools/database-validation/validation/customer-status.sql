\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
  customer_id_value VARCHAR(32);
BEGIN
  INSERT INTO public.customers (
    name, email, registered_at, points, first_purchase_used, auth_provider
  ) VALUES (
    'Customer Status Test', 'customer-status-test@example.invalid',
    now(), 0, false, 'google'
  ) RETURNING id INTO customer_id_value;

  IF NOT public.suspend_customer(customer_id_value) THEN
    RAISE EXCEPTION 'active to suspended transition failed';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.customers
    WHERE id = customer_id_value
      AND status = 'suspended'::public.customer_status
      AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'suspended state is inconsistent';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.active_customers WHERE id = customer_id_value
  ) THEN
    RAISE EXCEPTION 'suspended customer remains visible to active queries';
  END IF;

  IF NOT public.reactivate_customer(customer_id_value) THEN
    RAISE EXCEPTION 'suspended to active transition failed';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.active_customers WHERE id = customer_id_value
  ) THEN
    RAISE EXCEPTION 'reactivated customer is missing from active queries';
  END IF;

  IF NOT public.soft_delete_customer(customer_id_value) THEN
    RAISE EXCEPTION 'active to deleted transition failed';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.customers
    WHERE id = customer_id_value
      AND status = 'deleted'::public.customer_status
      AND deleted_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'deleted state is inconsistent';
  END IF;

  BEGIN
    UPDATE public.customers
    SET status = 'active'::public.customer_status
    WHERE id = customer_id_value;
    RAISE EXCEPTION 'active status with deleted_at was accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END $$;

ROLLBACK;
