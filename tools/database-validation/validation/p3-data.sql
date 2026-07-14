\set ON_ERROR_STOP on

CREATE TEMP TABLE p3_data_issues (
  check_name TEXT NOT NULL,
  data_id TEXT NOT NULL,
  reason TEXT NOT NULL
);

WITH expected(check_name, expected_count, actual_count) AS (
  VALUES
    ('rental_skus',
      (SELECT count(*) FROM migration.p3_rental_sku_source),
      (SELECT count(*) FROM rental_skus)),
    ('rental_variants',
      (SELECT count(*) FROM migration.p3_rental_sku_source source,
       LATERAL jsonb_array_elements(source.payload->'variants') value),
      (SELECT count(*) FROM rental_sku_variants)),
    ('rental_stock_rows',
      (SELECT count(*) FROM migration.p3_rental_sku_source source,
       LATERAL jsonb_array_elements(source.payload->'variants') variant,
       LATERAL jsonb_each(variant->'camp') stock),
      (SELECT count(*) FROM rental_sku_variant_stocks)),
    ('rental_listings',
      (SELECT count(*) FROM migration.p3_listing_source),
      (SELECT count(*) FROM rental_listings)),
    ('campground_mappings', 8::bigint,
      (SELECT count(*) FROM campground_rental_locations)),
    ('minimum_stock_evidence', 252::bigint,
      (SELECT count(*) FROM migration.p3_rental_min_stock_source))
)
INSERT INTO p3_data_issues
SELECT 'row_count', check_name, format('expected=%s actual=%s', expected_count, actual_count)
FROM expected WHERE expected_count <> actual_count;

INSERT INTO p3_data_issues
SELECT 'campground_location_mapping', campground.id,
       format('location=%s domain=%s type=%s', mapping.location_id, location.inventory_domain, location.type)
FROM campgrounds campground
LEFT JOIN campground_rental_locations mapping ON mapping.campground_id = campground.id
LEFT JOIN inventory_locations location ON location.id = mapping.location_id
WHERE mapping.location_id IS NULL
   OR mapping.location_id <> campground.id
   OR location.inventory_domain <> 'rental'
   OR location.type <> 'campground';

INSERT INTO p3_data_issues
SELECT 'c001_mapping', campground_id, 'C001 warehouse must not be a campground mapping'
FROM campground_rental_locations
WHERE campground_id = 'C001' OR location_id = 'C001';

INSERT INTO p3_data_issues
SELECT 'orphan_rental', rental.id, 'rental item does not resolve'
FROM rental_skus rental
LEFT JOIN equipment_items item ON item.id = rental.item_id
WHERE item.id IS NULL;

INSERT INTO p3_data_issues
SELECT 'orphan_variant', variant.id, 'variant rental group does not resolve'
FROM rental_sku_variants variant
LEFT JOIN rental_skus rental ON rental.id = variant.rental_sku_id
WHERE rental.id IS NULL;

INSERT INTO p3_data_issues
SELECT 'orphan_stock', stock.rental_sku_variant_id || ':' || stock.location_id,
       'stock variant or rental location does not resolve'
FROM rental_sku_variant_stocks stock
LEFT JOIN rental_sku_variants variant ON variant.id = stock.rental_sku_variant_id
LEFT JOIN inventory_locations location
  ON location.id = stock.location_id AND location.inventory_domain = 'rental'
WHERE variant.id IS NULL OR location.id IS NULL;

INSERT INTO p3_data_issues
SELECT 'orphan_listing', listing.id, 'listing variant, campground or location mapping does not resolve'
FROM rental_listings listing
LEFT JOIN rental_sku_variants variant ON variant.id = listing.rental_sku_variant_id
LEFT JOIN campground_rental_locations mapping ON mapping.campground_id = listing.campground_id
WHERE variant.id IS NULL OR mapping.campground_id IS NULL;

INSERT INTO p3_data_issues
SELECT 'invalid_value', data_id, reason
FROM (
  SELECT rental_sku_variant_id || ':' || location_id AS data_id,
         'negative rental on-hand quantity' AS reason
  FROM rental_sku_variant_stocks WHERE on_hand_quantity < 0
  UNION ALL
  SELECT id, 'negative listing price or discount'
  FROM rental_listings
  WHERE price_per_day_weekday < 0 OR price_per_day_holiday < 0 OR discount < 0
) invalid;

INSERT INTO p3_data_issues
SELECT 'duplicate_variant_sku', sku, format('count=%s', count(*))
FROM rental_sku_variants GROUP BY sku HAVING count(*) > 1;

INSERT INTO p3_data_issues
SELECT 'duplicate_listing', campground_id || ':' || rental_sku_variant_id,
       format('count=%s', count(*))
FROM rental_listings
GROUP BY campground_id, rental_sku_variant_id HAVING count(*) > 1;

INSERT INTO p3_data_issues
SELECT 'listing_stock_cardinality', listing.id, format('stock rows=%s', count(stock.*))
FROM rental_listings listing
JOIN campground_rental_locations mapping ON mapping.campground_id = listing.campground_id
LEFT JOIN rental_sku_variant_stocks stock
  ON stock.location_id = mapping.location_id
 AND stock.rental_sku_variant_id = listing.rental_sku_variant_id
GROUP BY listing.id HAVING count(stock.*) <> 1;

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*),
  'counts', jsonb_build_object(
    'rentals', (SELECT count(*) FROM rental_skus),
    'variants', (SELECT count(*) FROM rental_sku_variants),
    'stockRows', (SELECT count(*) FROM rental_sku_variant_stocks),
    'totalOnHand', (SELECT sum(on_hand_quantity) FROM rental_sku_variant_stocks),
    'listings', (SELECT count(*) FROM rental_listings)
  ),
  'issues', COALESCE(jsonb_agg(jsonb_build_object(
    'check', check_name, 'id', data_id, 'reason', reason
  ) ORDER BY check_name, data_id), '[]'::jsonb)
))
FROM p3_data_issues;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p3_data_issues) THEN
    RAISE EXCEPTION 'P3 data validation failed with % issue(s)',
      (SELECT count(*) FROM p3_data_issues);
  END IF;
END $$;
