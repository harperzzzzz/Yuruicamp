\set ON_ERROR_STOP on

CREATE TEMP TABLE p2_compatibility_issues (
  check_name TEXT NOT NULL,
  data_id TEXT NOT NULL,
  reason TEXT NOT NULL
);

INSERT INTO p2_compatibility_issues
SELECT 'product_scalar', source.product_id,
       'normalized product/equipment scalar fields differ from source payload'
FROM migration.p2_product_source source
LEFT JOIN products product ON product.id = source.product_id
LEFT JOIN equipment_items item ON item.id = product.item_id
LEFT JOIN product_categories category ON category.id = item.category_id
LEFT JOIN brands brand ON brand.id = item.brand_id
WHERE product.id IS NULL OR item.id IS NULL
   OR product.price IS DISTINCT FROM (source.payload->>'price')::numeric
   OR product.status IS DISTINCT FROM source.payload->>'status'
   OR item.name IS DISTINCT FROM source.payload->>'name'
   OR category.name IS DISTINCT FROM source.payload->>'category'
   OR brand.name IS DISTINCT FROM source.payload->>'brand'
   OR item.main_image_url IS DISTINCT FROM source.payload->>'image'
   OR item.description IS DISTINCT FROM source.payload->>'description'
   OR item.active IS DISTINCT FROM ((source.payload->>'status') = 'active');

INSERT INTO p2_compatibility_issues
SELECT 'product_images', source.product_id, 'image values or order differ from source payload'
FROM migration.p2_product_source source
WHERE COALESCE((
  SELECT jsonb_agg(to_jsonb(image.url) ORDER BY image.sort_order)
  FROM equipment_images image WHERE image.item_id = source.product_id
), '[]'::jsonb) IS DISTINCT FROM COALESCE(source.payload->'images', '[]'::jsonb);

WITH source_values AS (
  SELECT source.product_id, value.tag
  FROM migration.p2_product_source source
  CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(source.payload->'tags', '[]'::jsonb)) value(tag)
), target_values AS (
  SELECT item_id AS product_id, tag FROM equipment_tags
), difference AS (
  (SELECT * FROM source_values EXCEPT SELECT * FROM target_values)
  UNION
  (SELECT * FROM target_values EXCEPT SELECT * FROM source_values)
)
INSERT INTO p2_compatibility_issues
SELECT 'product_tags', product_id, 'tag sets differ from source payload' FROM difference;

WITH source_values AS (
  SELECT source.product_id, value.tag
  FROM migration.p2_product_source source
  CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(source.payload->'interestTags', '[]'::jsonb)) value(tag)
), target_values AS (
  SELECT item_id AS product_id, tag FROM equipment_interest_tags
), difference AS (
  (SELECT * FROM source_values EXCEPT SELECT * FROM target_values)
  UNION
  (SELECT * FROM target_values EXCEPT SELECT * FROM source_values)
)
INSERT INTO p2_compatibility_issues
SELECT 'product_interest_tags', product_id, 'interest tag sets differ from source payload'
FROM difference;

WITH source_values AS (
  SELECT source.product_id, value.spec_key, value.spec_value
  FROM migration.p2_product_source source
  CROSS JOIN LATERAL jsonb_each_text(COALESCE(source.payload->'specifications', '{}'::jsonb))
    value(spec_key, spec_value)
), target_values AS (
  SELECT item_id AS product_id, spec_key, value AS spec_value
  FROM equipment_specifications
), difference AS (
  (SELECT * FROM source_values EXCEPT SELECT * FROM target_values)
  UNION
  (SELECT * FROM target_values EXCEPT SELECT * FROM source_values)
)
INSERT INTO p2_compatibility_issues
SELECT 'product_specifications', product_id, 'specification map differs from source payload'
FROM difference;

INSERT INTO p2_compatibility_issues
SELECT 'product_variant', source.product_id || ':' || (source_variant.value->>'id'),
       'variant fields differ from source payload'
FROM migration.p2_product_source source
CROSS JOIN LATERAL jsonb_array_elements(source.payload->'variants') source_variant(value)
LEFT JOIN product_variants variant ON variant.id = source_variant.value->>'id'
WHERE variant.id IS NULL
   OR variant.product_id IS DISTINCT FROM source.product_id
   OR variant.sku IS DISTINCT FROM source_variant.value->>'id'
   OR COALESCE(variant.color, '') IS DISTINCT FROM COALESCE(source_variant.value->>'color', '')
   OR COALESCE(variant.size, '') IS DISTINCT FROM COALESCE(source_variant.value->>'size', '')
   OR variant.specification IS DISTINCT FROM source_variant.value->>'label'
   OR variant.price IS DISTINCT FROM (source.payload->>'price')::numeric
   OR variant.status IS DISTINCT FROM source.payload->>'status';

INSERT INTO p2_compatibility_issues
SELECT 'variant_stock', source.product_id || ':' || (source_variant.value->>'id') || ':' || source_stock.location_code,
       format('expected=%s actual=%s', source_stock.quantity, stock.on_hand_quantity)
FROM migration.p2_product_source source
CROSS JOIN LATERAL jsonb_array_elements(source.payload->'variants') source_variant(value)
CROSS JOIN LATERAL jsonb_each_text(source_variant.value->'branch') source_stock(location_code, quantity)
LEFT JOIN inventory_locations location
  ON location.code = source_stock.location_code AND location.inventory_domain = 'store'
LEFT JOIN inventory_stocks stock
  ON stock.location_id = location.id AND stock.variant_id = source_variant.value->>'id'
WHERE stock.variant_id IS NULL OR stock.on_hand_quantity <> source_stock.quantity::integer;

WITH source_values AS (
  SELECT source.campground_id, 'environment'::text AS type, value.label
  FROM migration.p2_campground_tag_source source
  CROSS JOIN LATERAL jsonb_array_elements_text(source.environment_tags) value(label)
  UNION ALL
  SELECT source.campground_id, 'facility', value.label
  FROM migration.p2_campground_tag_source source
  CROSS JOIN LATERAL jsonb_array_elements_text(source.facility_tags) value(label)
), target_values AS (
  SELECT relation.campground_id, 'environment'::text AS type, tag.label
  FROM campground_environment_tags relation
  JOIN environment_tags tag ON tag.id = relation.tag_id
  UNION ALL
  SELECT relation.campground_id, 'facility', tag.label
  FROM campground_facility_tags relation
  JOIN facility_tags tag ON tag.id = relation.tag_id
), difference AS (
  (SELECT * FROM source_values EXCEPT SELECT * FROM target_values)
  UNION
  (SELECT * FROM target_values EXCEPT SELECT * FROM source_values)
)
INSERT INTO p2_compatibility_issues
SELECT 'campground_tags', campground_id || ':' || type || ':' || label,
       'campground tag differs from source payload'
FROM difference;

INSERT INTO p2_compatibility_issues
SELECT 'product_stock_summary', source.product_id,
       format('expected=%s on_hand=%s reserved=%s available=%s',
         source.payload->>'totalStock', summary.total_on_hand,
         summary.total_reserved, summary.total_available)
FROM migration.p2_product_source source
LEFT JOIN product_stock_summary summary ON summary.product_id = source.product_id
WHERE summary.product_id IS NULL
   OR summary.total_on_hand <> (source.payload->>'totalStock')::bigint
   OR summary.total_reserved <> 0
   OR summary.total_available <> (source.payload->>'totalStock')::bigint;

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*),
  'issues', COALESCE(jsonb_agg(jsonb_build_object(
    'check', check_name, 'id', data_id, 'reason', reason
  ) ORDER BY check_name, data_id), '[]'::jsonb)
))
FROM p2_compatibility_issues;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p2_compatibility_issues) THEN
    RAISE EXCEPTION 'P2 compatibility validation failed with % issue(s)',
      (SELECT count(*) FROM p2_compatibility_issues);
  END IF;
END $$;
