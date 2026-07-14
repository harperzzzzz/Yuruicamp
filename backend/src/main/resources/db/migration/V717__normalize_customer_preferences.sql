DO $$
DECLARE
  unmapped TEXT;
BEGIN
  WITH legacy AS (
    SELECT customer.id, value.type, value.code
    FROM customers customer
    CROSS JOIN LATERAL (
      SELECT 'style'::TEXT AS type,
             jsonb_array_elements_text(COALESCE(customer.preferences->'styles', '[]'::jsonb)) AS code
      UNION ALL
      SELECT 'equipment',
             jsonb_array_elements_text(COALESCE(customer.preferences->'equipment', '[]'::jsonb))
    ) value
  )
  SELECT string_agg(format('%s:%s/%s', legacy.id, legacy.type, legacy.code), ', ' ORDER BY legacy.id)
  INTO unmapped
  FROM legacy
  LEFT JOIN preference_options option
    ON option.type = legacy.type AND option.code = legacy.code
  WHERE option.id IS NULL;

  IF unmapped IS NOT NULL THEN
    RAISE EXCEPTION 'unmapped customer preference codes: %', unmapped;
  END IF;
END $$;

INSERT INTO customer_preferences (customer_id, preference_id)
SELECT customer.id, option.id
FROM customers customer
CROSS JOIN LATERAL (
  SELECT 'style'::TEXT AS type,
         jsonb_array_elements_text(COALESCE(customer.preferences->'styles', '[]'::jsonb)) AS code
  UNION ALL
  SELECT 'equipment',
         jsonb_array_elements_text(COALESCE(customer.preferences->'equipment', '[]'::jsonb))
) value
JOIN preference_options option
  ON option.type = value.type AND option.code = value.code
ON CONFLICT DO NOTHING;

DO $$
BEGIN
  IF EXISTS (
    WITH legacy AS (
      SELECT customer.id AS customer_id, option.id AS preference_id
      FROM customers customer
      CROSS JOIN LATERAL (
        SELECT 'style'::TEXT AS type,
               jsonb_array_elements_text(COALESCE(customer.preferences->'styles', '[]'::jsonb)) AS code
        UNION ALL
        SELECT 'equipment',
               jsonb_array_elements_text(COALESCE(customer.preferences->'equipment', '[]'::jsonb))
      ) value
      JOIN preference_options option
        ON option.type = value.type AND option.code = value.code
    )
    SELECT 1
    FROM legacy
    LEFT JOIN customer_preferences current USING (customer_id, preference_id)
    WHERE current.customer_id IS NULL
  ) THEN
    RAISE EXCEPTION 'customer preference backfill is incomplete';
  END IF;
END $$;

ALTER TABLE customers
DROP COLUMN preferences;
