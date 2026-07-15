\set ON_ERROR_STOP on

CREATE TEMP TABLE p2_data_issues (
  check_name TEXT NOT NULL,
  data_id TEXT NOT NULL,
  reason TEXT NOT NULL
);

WITH expected(check_name, expected_count, actual_count) AS (
  VALUES
    ('products', (SELECT count(*) FROM migration.p2_product_source), (SELECT count(*) FROM products)),
    ('equipment_items', (SELECT count(*) FROM migration.p2_product_source), (SELECT count(*) FROM equipment_items)),
    ('product_variants', (
      SELECT count(*) FROM migration.p2_product_source source,
      LATERAL jsonb_array_elements(source.payload->'variants') value
    ), (SELECT count(*) FROM product_variants)),
    ('equipment_images', (
      SELECT count(*) FROM migration.p2_product_source source,
      LATERAL jsonb_array_elements(COALESCE(source.payload->'images', '[]'::jsonb)) value
    ), (SELECT count(*) FROM equipment_images)),
    ('equipment_tags', (
      SELECT count(*) FROM migration.p2_product_source source,
      LATERAL jsonb_array_elements(COALESCE(source.payload->'tags', '[]'::jsonb)) value
    ), (SELECT count(*) FROM equipment_tags)),
    ('equipment_interest_tags', (
      SELECT count(*) FROM migration.p2_product_source source,
      LATERAL jsonb_array_elements(COALESCE(source.payload->'interestTags', '[]'::jsonb)) value
    ), (SELECT count(*) FROM equipment_interest_tags)),
    ('equipment_specifications', (
      SELECT count(*) FROM migration.p2_product_source source,
      LATERAL jsonb_each(COALESCE(source.payload->'specifications', '{}'::jsonb)) value
    ), (SELECT count(*) FROM equipment_specifications)),
    ('inventory_stocks', (
      SELECT count(*) FROM migration.p2_product_source source,
      LATERAL jsonb_array_elements(source.payload->'variants') variant,
      LATERAL jsonb_each(COALESCE(variant->'branch', '{}'::jsonb)) stock
    ), (SELECT count(*) FROM inventory_stocks)),
    ('environment_relations', (
      SELECT count(*) FROM migration.p2_campground_tag_source source,
      LATERAL jsonb_array_elements(source.environment_tags) value
    ), (SELECT count(*) FROM campground_environment_tags)),
    ('facility_relations', (
      SELECT count(*) FROM migration.p2_campground_tag_source source,
      LATERAL jsonb_array_elements(source.facility_tags) value
    ), (SELECT count(*) FROM campground_facility_tags))
)
INSERT INTO p2_data_issues
SELECT 'row_count', check_name, format('expected=%s actual=%s', expected_count, actual_count)
FROM expected WHERE expected_count <> actual_count;

INSERT INTO p2_data_issues
SELECT 'orphan_product_item', product.id, 'products.item_id does not resolve'
FROM products product
LEFT JOIN equipment_items item ON item.id = product.item_id
WHERE item.id IS NULL;

INSERT INTO p2_data_issues
SELECT 'orphan_variant_product', variant.id, 'variant product does not resolve'
FROM product_variants variant
LEFT JOIN products product ON product.id = variant.product_id
WHERE product.id IS NULL;

INSERT INTO p2_data_issues
SELECT 'orphan_stock', stock.variant_id || ':' || stock.location_id,
       'stock variant or store location does not resolve'
FROM inventory_stocks stock
LEFT JOIN product_variants variant ON variant.id = stock.variant_id
LEFT JOIN inventory_locations location
  ON location.id = stock.location_id AND location.inventory_domain = 'store'
WHERE variant.id IS NULL OR location.id IS NULL;

INSERT INTO p2_data_issues
SELECT 'invalid_value', data_id, reason
FROM (
  SELECT variant.id, 'negative variant price'
  FROM product_variants variant WHERE variant.price < 0
  UNION ALL
  SELECT stock.variant_id || ':' || stock.location_id, 'negative on-hand quantity'
  FROM inventory_stocks stock WHERE stock.on_hand_quantity < 0
) invalid;

INSERT INTO p2_data_issues
SELECT 'duplicate_sku', sku, format('count=%s', count(*))
FROM product_variants GROUP BY sku HAVING count(*) > 1;

INSERT INTO p2_data_issues
SELECT 'stock_total', source.product_id,
       format('expected=%s actual=%s', source.payload->>'totalStock', summary.total_on_hand)
FROM migration.p2_product_source source
JOIN product_stock_summary summary ON summary.product_id = source.product_id
WHERE summary.total_on_hand <> (source.payload->>'totalStock')::bigint
   OR summary.total_reserved <> 0
   OR summary.total_available <> summary.total_on_hand;

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*),
  'counts', jsonb_build_object(
    'products', (SELECT count(*) FROM products),
    'variants', (SELECT count(*) FROM product_variants),
    'inventoryRows', (SELECT count(*) FROM inventory_stocks),
    'totalOnHand', (SELECT sum(on_hand_quantity) FROM inventory_stocks)
  ),
  'issues', COALESCE(jsonb_agg(jsonb_build_object(
    'check', check_name, 'id', data_id, 'reason', reason
  ) ORDER BY check_name, data_id), '[]'::jsonb)
))
FROM p2_data_issues;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p2_data_issues) THEN
    RAISE EXCEPTION 'P2 data validation failed with % issue(s)',
      (SELECT count(*) FROM p2_data_issues);
  END IF;
END $$;
