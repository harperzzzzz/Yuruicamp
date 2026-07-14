UPDATE customers
SET shipping_address = jsonb_set(
      jsonb_set(shipping_address, '{city}', to_jsonb(
        CASE shipping_address->>'city'
          WHEN '臺東市' THEN '臺東縣'
          WHEN '宜蘭市' THEN '宜蘭縣'
          WHEN '彰化市' THEN '彰化縣'
          WHEN '花蓮市' THEN '花蓮縣'
          WHEN '屏東市' THEN '屏東縣'
        END
      )),
      '{district}', to_jsonb(shipping_address->>'city')
    )
WHERE shipping_address->>'city' IN ('臺東市', '宜蘭市', '彰化市', '花蓮市', '屏東市')
  AND BTRIM(COALESCE(NULLIF(shipping_address->>'district', ''), shipping_address->>'township', '')) = '';

UPDATE customer_shipping_addresses
SET district = city,
    city = CASE city
      WHEN '臺東市' THEN '臺東縣'
      WHEN '宜蘭市' THEN '宜蘭縣'
      WHEN '彰化市' THEN '彰化縣'
      WHEN '花蓮市' THEN '花蓮縣'
      WHEN '屏東市' THEN '屏東縣'
    END,
    updated_at = now()
WHERE city IN ('臺東市', '宜蘭市', '彰化市', '花蓮市', '屏東市')
  AND BTRIM(district) = '';

DO $$
DECLARE
  invalid_addresses TEXT;
BEGIN
  SELECT string_agg(customer.id, ', ' ORDER BY customer.id)
  INTO invalid_addresses
  FROM customers customer
  WHERE customer.shipping_address IS NOT NULL
    AND customer.shipping_address <> '{}'::jsonb
    AND (
      BTRIM(CONCAT(COALESCE(customer.shipping_address->>'lastName', ''), COALESCE(customer.shipping_address->>'firstName', ''))) = ''
      OR BTRIM(COALESCE(customer.shipping_address->>'postalCode', '')) = ''
      OR BTRIM(COALESCE(customer.shipping_address->>'city', '')) = ''
      OR BTRIM(COALESCE(NULLIF(customer.shipping_address->>'district', ''), customer.shipping_address->>'township', '')) = ''
      OR BTRIM(CONCAT_WS(' ', NULLIF(customer.shipping_address->>'addressLine1', ''), NULLIF(customer.shipping_address->>'addressLine2', ''))) = ''
      OR BTRIM(COALESCE(customer.shipping_address->>'phone', '')) = ''
    );

  IF invalid_addresses IS NOT NULL THEN
    RAISE EXCEPTION 'invalid legacy customer shipping addresses: %', invalid_addresses;
  END IF;
END $$;

INSERT INTO customer_shipping_addresses (
  customer_id, recipient_name, postal_code, city, district, address_line, phone, is_default
)
SELECT customer.id,
       CONCAT(COALESCE(customer.shipping_address->>'lastName', ''), COALESCE(customer.shipping_address->>'firstName', '')),
       customer.shipping_address->>'postalCode',
       customer.shipping_address->>'city',
       COALESCE(NULLIF(customer.shipping_address->>'district', ''), customer.shipping_address->>'township'),
       CONCAT_WS(' ', NULLIF(customer.shipping_address->>'addressLine1', ''), NULLIF(customer.shipping_address->>'addressLine2', '')),
       customer.shipping_address->>'phone',
       TRUE
FROM customers customer
WHERE customer.shipping_address IS NOT NULL
  AND customer.shipping_address <> '{}'::jsonb
  AND NOT EXISTS (
    SELECT 1 FROM customer_shipping_addresses address
    WHERE address.customer_id = customer.id AND address.is_default
  );

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM customers customer
    WHERE customer.shipping_address IS NOT NULL
      AND customer.shipping_address <> '{}'::jsonb
      AND NOT EXISTS (
        SELECT 1 FROM customer_shipping_addresses address
        WHERE address.customer_id = customer.id
          AND address.is_default
          AND BTRIM(address.recipient_name) <> ''
          AND BTRIM(address.postal_code) <> ''
          AND BTRIM(address.city) <> ''
          AND BTRIM(address.district) <> ''
          AND BTRIM(address.address_line) <> ''
          AND BTRIM(address.phone) <> ''
      )
  ) THEN
    RAISE EXCEPTION 'customer shipping address backfill is incomplete';
  END IF;
END $$;

ALTER TABLE customers
DROP COLUMN shipping_address;
