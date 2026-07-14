\set ON_ERROR_STOP on

CREATE TEMP TABLE p1_compatibility_issues (
  check_name TEXT NOT NULL,
  data_id TEXT NOT NULL,
  reason TEXT NOT NULL
);

DO $$
BEGIN
  IF to_regclass('public.movements') IS NOT NULL THEN
    EXECUTE 'CREATE TEMP VIEW p1_validation_movements AS SELECT * FROM public.movements';
    EXECUTE 'CREATE TEMP VIEW p1_validation_zone_blocks AS SELECT * FROM public.zone_blocks';
    EXECUTE 'CREATE TEMP VIEW p1_validation_closures AS SELECT * FROM public.campground_closures';
  ELSE
    EXECUTE 'CREATE TEMP VIEW p1_validation_movements AS SELECT * FROM migration.p5_legacy_movements';
    EXECUTE 'CREATE TEMP VIEW p1_validation_zone_blocks AS SELECT * FROM migration.p5_legacy_zone_blocks';
    EXECUTE 'CREATE TEMP VIEW p1_validation_closures AS SELECT * FROM migration.p5_legacy_campground_closures';
  END IF;
END $$;

INSERT INTO p1_compatibility_issues
SELECT 'customer_avatar', id, 'avatar_url differs from legacy avatar'
FROM customers WHERE avatar_url IS DISTINCT FROM avatar;

INSERT INTO p1_compatibility_issues
SELECT 'customer_address', customer.id, 'normalized default address differs from legacy JSON'
FROM customers customer
JOIN customer_shipping_addresses address
  ON address.customer_id = customer.id AND address.is_default
WHERE address.recipient_name IS DISTINCT FROM CONCAT(
        COALESCE(customer.shipping_address->>'lastName', ''),
        COALESCE(customer.shipping_address->>'firstName', '')
      )
   OR address.postal_code IS DISTINCT FROM customer.shipping_address->>'postalCode'
   OR address.city IS DISTINCT FROM customer.shipping_address->>'city'
   OR address.district IS DISTINCT FROM COALESCE(
        NULLIF(customer.shipping_address->>'district', ''),
        customer.shipping_address->>'township'
      )
   OR address.address_line IS DISTINCT FROM CONCAT_WS(
        ' ', NULLIF(customer.shipping_address->>'addressLine1', ''),
        NULLIF(customer.shipping_address->>'addressLine2', '')
      )
   OR address.phone IS DISTINCT FROM customer.shipping_address->>'phone';

WITH legacy AS (
  SELECT customer.id, value.name
  FROM customers customer
  CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(customer.tags, '[]'::jsonb)) value(name)
), normalized AS (
  SELECT assignment.customer_id AS id, tag.name
  FROM customer_tag_assignments assignment
  JOIN customer_tags tag ON tag.id = assignment.tag_id
)
INSERT INTO p1_compatibility_issues
SELECT 'customer_tags', difference.id, 'legacy and normalized tag sets differ'
FROM (
  (SELECT * FROM legacy EXCEPT SELECT * FROM normalized)
  UNION
  (SELECT * FROM normalized EXCEPT SELECT * FROM legacy)
) difference;

WITH legacy AS (
  SELECT customer.id, value.type, value.code
  FROM customers customer
  CROSS JOIN LATERAL (
    SELECT 'style'::text AS type, code
    FROM jsonb_array_elements_text(COALESCE(customer.preferences->'styles', '[]'::jsonb)) code
    UNION ALL
    SELECT 'equipment', code
    FROM jsonb_array_elements_text(COALESCE(customer.preferences->'equipment', '[]'::jsonb)) code
  ) value
), normalized AS (
  SELECT assignment.customer_id AS id, option.type, option.code
  FROM customer_preferences assignment
  JOIN preference_options option ON option.id = assignment.preference_id
)
INSERT INTO p1_compatibility_issues
SELECT 'customer_preferences', difference.id, 'legacy and normalized preference sets differ'
FROM (
  (SELECT * FROM legacy EXCEPT SELECT * FROM normalized)
  UNION
  (SELECT * FROM normalized EXCEPT SELECT * FROM legacy)
) difference;

INSERT INTO p1_compatibility_issues
SELECT 'admin_reference', ref.id, 'legacy admin reference cannot resolve a display name'
FROM (
  SELECT employee_id AS id FROM p1_validation_movements WHERE employee_id IS NOT NULL
  UNION SELECT created_by FROM p1_validation_zone_blocks WHERE created_by IS NOT NULL
  UNION SELECT created_by FROM p1_validation_closures WHERE created_by IS NOT NULL
) ref
LEFT JOIN admin_users admin_user ON admin_user.id = ref.id
WHERE admin_user.id IS NULL OR BTRIM(admin_user.name) = '';

INSERT INTO p1_compatibility_issues
SELECT 'location_alias', alias.alias, 'alias cannot resolve an active location display name'
FROM migration.p1_location_aliases alias
LEFT JOIN inventory_locations location ON location.id = alias.location_id
WHERE location.id IS NULL OR NOT location.active OR BTRIM(location.name) = '';

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*),
  'issues', COALESCE(jsonb_agg(jsonb_build_object(
    'check', check_name, 'id', data_id, 'reason', reason
  ) ORDER BY check_name, data_id), '[]'::jsonb)
))
FROM p1_compatibility_issues;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p1_compatibility_issues) THEN
    RAISE EXCEPTION 'P1 compatibility validation failed with % issue(s)',
      (SELECT count(*) FROM p1_compatibility_issues);
  END IF;
END $$;
