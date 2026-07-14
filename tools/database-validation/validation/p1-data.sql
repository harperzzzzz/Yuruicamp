\set ON_ERROR_STOP on

CREATE TEMP TABLE p1_data_issues (
  check_name TEXT NOT NULL,
  data_id TEXT NOT NULL,
  reason TEXT NOT NULL
);

-- P5 archives the P0 movement/policy tables. Resolve the same legacy evidence
-- from either location so the P1 regression remains runnable after P5/P6.
DO $$
BEGIN
  IF to_regclass('public.movements') IS NOT NULL THEN
    EXECUTE 'CREATE TEMP VIEW p1_validation_movements AS SELECT * FROM public.movements';
    EXECUTE 'CREATE TEMP VIEW p1_validation_movement_items AS SELECT * FROM public.movement_items';
    EXECUTE 'CREATE TEMP VIEW p1_validation_min_stocks AS SELECT * FROM public.min_stocks';
    EXECUTE 'CREATE TEMP VIEW p1_validation_zone_blocks AS SELECT * FROM public.zone_blocks';
    EXECUTE 'CREATE TEMP VIEW p1_validation_closures AS SELECT * FROM public.campground_closures';
  ELSE
    EXECUTE 'CREATE TEMP VIEW p1_validation_movements AS SELECT * FROM migration.p5_legacy_movements';
    EXECUTE 'CREATE TEMP VIEW p1_validation_movement_items AS SELECT * FROM migration.p5_legacy_movement_items';
    EXECUTE 'CREATE TEMP VIEW p1_validation_min_stocks AS SELECT * FROM migration.p5_legacy_min_stocks';
    EXECUTE 'CREATE TEMP VIEW p1_validation_zone_blocks AS SELECT * FROM migration.p5_legacy_zone_blocks';
    EXECUTE 'CREATE TEMP VIEW p1_validation_closures AS SELECT * FROM migration.p5_legacy_campground_closures';
  END IF;
END $$;

INSERT INTO p1_data_issues
SELECT 'duplicate_customer_email', email, format('count=%s', count(*))
FROM customers GROUP BY email HAVING count(*) > 1;

INSERT INTO p1_data_issues
SELECT 'duplicate_admin_email', email, format('count=%s', count(*))
FROM admin_users GROUP BY email HAVING count(*) > 1;

INSERT INTO p1_data_issues
SELECT 'duplicate_business_key', key, format('count=%s', count(*))
FROM (
  SELECT 'brand:' || name AS key FROM brands
  UNION ALL SELECT 'category-code:' || code FROM product_categories
  UNION ALL SELECT 'category-name:' || name FROM product_categories
  UNION ALL SELECT 'location:' || code FROM inventory_locations
) keys GROUP BY key HAVING count(*) > 1;

INSERT INTO p1_data_issues
SELECT 'orphan_admin_reference', ref.id, ref.source
FROM (
  SELECT employee_id AS id, 'movements.employee_id' AS source FROM p1_validation_movements WHERE employee_id IS NOT NULL
  UNION ALL SELECT created_by, 'zone_blocks.created_by' FROM p1_validation_zone_blocks WHERE created_by IS NOT NULL
  UNION ALL SELECT created_by, 'campground_closures.created_by' FROM p1_validation_closures WHERE created_by IS NOT NULL
) ref
LEFT JOIN admin_users admin_user ON admin_user.id = ref.id
WHERE admin_user.id IS NULL;

INSERT INTO p1_data_issues
SELECT 'unmapped_preference', customer.id || ':' || value.type || ':' || value.code,
       'legacy preference has no preference_options row'
FROM customers customer
CROSS JOIN LATERAL (
  SELECT 'style'::text AS type, code
  FROM jsonb_array_elements_text(COALESCE(customer.preferences->'styles', '[]'::jsonb)) code
  UNION ALL
  SELECT 'equipment', code
  FROM jsonb_array_elements_text(COALESCE(customer.preferences->'equipment', '[]'::jsonb)) code
) value
LEFT JOIN preference_options option
  ON option.type = value.type AND option.code = value.code
WHERE option.id IS NULL;

INSERT INTO p1_data_issues
SELECT 'missing_preference_assignment', customer.id || ':' || value.type || ':' || value.code,
       'normalized assignment is missing'
FROM customers customer
CROSS JOIN LATERAL (
  SELECT 'style'::text AS type, code
  FROM jsonb_array_elements_text(COALESCE(customer.preferences->'styles', '[]'::jsonb)) code
  UNION ALL
  SELECT 'equipment', code
  FROM jsonb_array_elements_text(COALESCE(customer.preferences->'equipment', '[]'::jsonb)) code
) value
JOIN preference_options option ON option.type = value.type AND option.code = value.code
LEFT JOIN customer_preferences assignment
  ON assignment.customer_id = customer.id AND assignment.preference_id = option.id
WHERE assignment.customer_id IS NULL;

INSERT INTO p1_data_issues
SELECT 'unmapped_customer_tag', customer.id || ':' || value.name,
       'legacy tag has no customer_tags row'
FROM customers customer
CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(customer.tags, '[]'::jsonb)) value(name)
LEFT JOIN customer_tags tag ON tag.name = value.name
WHERE tag.id IS NULL;

INSERT INTO p1_data_issues
SELECT 'missing_tag_assignment', customer.id || ':' || value.name,
       'normalized tag assignment is missing'
FROM customers customer
CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(customer.tags, '[]'::jsonb)) value(name)
JOIN customer_tags tag ON tag.name = value.name
LEFT JOIN customer_tag_assignments assignment
  ON assignment.customer_id = customer.id AND assignment.tag_id = tag.id
WHERE assignment.customer_id IS NULL;

INSERT INTO p1_data_issues
SELECT 'default_address_count', customer.id, format('expected=1 actual=%s', count(address.id))
FROM customers customer
LEFT JOIN customer_shipping_addresses address
  ON address.customer_id = customer.id AND address.is_default
WHERE customer.shipping_address IS NOT NULL AND customer.shipping_address <> '{}'::jsonb
GROUP BY customer.id HAVING count(address.id) <> 1;

INSERT INTO p1_data_issues
SELECT 'unmapped_min_stock_location', stock.id::text,
       format('location_key=%s', stock.location_key)
FROM p1_validation_min_stocks stock
LEFT JOIN inventory_locations location ON location.code = stock.location_key
WHERE location.id IS NULL;

INSERT INTO p1_data_issues
SELECT 'unhandled_movement_location', item.id::text || ':' || endpoint.field_name,
       format('raw_value=%s', endpoint.raw_value)
FROM p1_validation_movement_items item
CROSS JOIN LATERAL (VALUES
  ('from_store', item.from_store), ('to_store', item.to_store)
) endpoint(field_name, raw_value)
LEFT JOIN migration.p1_location_aliases alias ON alias.alias = endpoint.raw_value
LEFT JOIN migration.p1_location_quarantine quarantine
  ON quarantine.source_table = 'movement_items'
 AND quarantine.source_row_id = item.id::text
 AND quarantine.field_name = endpoint.field_name
 AND quarantine.raw_value = endpoint.raw_value
WHERE endpoint.raw_value IS NOT NULL
  AND endpoint.raw_value NOT IN ('進貨', '損耗')
  AND alias.alias IS NULL
  AND quarantine.source_row_id IS NULL;

INSERT INTO p1_data_issues
SELECT 'location_branch_exclusivity', id,
       format('domain=%s type=%s branch_id=%s', inventory_domain, type, branch_id)
FROM inventory_locations
WHERE NOT (
  (type = 'branch' AND inventory_domain = 'store' AND branch_id IS NOT NULL)
  OR (type <> 'branch' AND branch_id IS NULL)
);

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*),
  'quarantineCount', (SELECT count(*) FROM migration.p1_location_quarantine),
  'issues', COALESCE(jsonb_agg(jsonb_build_object(
    'check', check_name, 'id', data_id, 'reason', reason
  ) ORDER BY check_name, data_id), '[]'::jsonb)
))
FROM p1_data_issues;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p1_data_issues) THEN
    RAISE EXCEPTION 'P1 data validation failed with % issue(s)',
      (SELECT count(*) FROM p1_data_issues);
  END IF;
END $$;
