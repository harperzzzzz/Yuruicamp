DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM customers customer
    CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(customer.tags, '[]'::jsonb)) value(name)
    WHERE BTRIM(value.name) = ''
  ) THEN
    RAISE EXCEPTION 'blank legacy customer tag names cannot be migrated';
  END IF;
END $$;

INSERT INTO customer_tags (name, color, sort_order)
SELECT DISTINCT value.name, 'bg-secondary', 0
FROM customers customer
CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(customer.tags, '[]'::jsonb)) value(name)
WHERE NOT EXISTS (
  SELECT 1 FROM customer_tags current WHERE current.name = value.name
);

INSERT INTO customer_tag_assignments (customer_id, tag_id)
SELECT customer.id, tag.id
FROM customers customer
CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(customer.tags, '[]'::jsonb)) value(name)
JOIN customer_tags tag ON tag.name = value.name
ON CONFLICT DO NOTHING;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM customers customer
    CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(customer.tags, '[]'::jsonb)) value(name)
    LEFT JOIN customer_tags tag ON tag.name = value.name
    LEFT JOIN customer_tag_assignments assignment
      ON assignment.customer_id = customer.id AND assignment.tag_id = tag.id
    WHERE tag.id IS NULL OR assignment.customer_id IS NULL
  ) THEN
    RAISE EXCEPTION 'customer tag backfill is incomplete';
  END IF;
END $$;

ALTER TABLE customers
DROP COLUMN tags;
