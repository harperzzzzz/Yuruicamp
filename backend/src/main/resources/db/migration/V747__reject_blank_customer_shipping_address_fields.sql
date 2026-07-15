DO $$
DECLARE
  invalid_addresses TEXT;
BEGIN
  SELECT string_agg(
           format('%s[%s]', customer_id, id),
           ', '
           ORDER BY customer_id, id
         )
  INTO invalid_addresses
  FROM public.customer_shipping_addresses
  WHERE btrim(recipient_name) = ''
     OR btrim(postal_code) = ''
     OR btrim(city) = ''
     OR btrim(district) = ''
     OR btrim(address_line) = ''
     OR btrim(phone) = '';

  IF invalid_addresses IS NOT NULL THEN
    RAISE EXCEPTION
      'V747 guard: blank required customer shipping address fields: %',
      invalid_addresses;
  END IF;
END $$;

ALTER TABLE public.customer_shipping_addresses
  ADD CONSTRAINT ck_customer_shipping_addresses_recipient_name_not_blank
    CHECK (btrim(recipient_name) <> ''),
  ADD CONSTRAINT ck_customer_shipping_addresses_postal_code_not_blank
    CHECK (btrim(postal_code) <> ''),
  ADD CONSTRAINT ck_customer_shipping_addresses_city_not_blank
    CHECK (btrim(city) <> ''),
  ADD CONSTRAINT ck_customer_shipping_addresses_district_not_blank
    CHECK (btrim(district) <> ''),
  ADD CONSTRAINT ck_customer_shipping_addresses_address_line_not_blank
    CHECK (btrim(address_line) <> ''),
  ADD CONSTRAINT ck_customer_shipping_addresses_phone_not_blank
    CHECK (btrim(phone) <> '');
