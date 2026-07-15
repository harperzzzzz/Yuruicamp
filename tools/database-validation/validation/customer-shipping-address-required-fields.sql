\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
  customer_id_value VARCHAR(32);
BEGIN
  SELECT id INTO customer_id_value
  FROM public.customers
  ORDER BY id
  LIMIT 1;

  BEGIN
    INSERT INTO public.customer_shipping_addresses (
      customer_id,
      recipient_name,
      postal_code,
      city,
      district,
      address_line,
      phone,
      is_default
    ) VALUES (
      customer_id_value,
      ' ',
      E'\t',
      ' ',
      E'\n',
      ' ',
      E'\r',
      false
    );
    RAISE EXCEPTION 'blank required shipping address fields were accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END $$;

ROLLBACK;
