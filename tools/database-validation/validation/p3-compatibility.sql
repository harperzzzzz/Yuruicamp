\set ON_ERROR_STOP on

CREATE TEMP TABLE p3_compatibility_issues (
  check_name TEXT NOT NULL,
  data_id TEXT NOT NULL,
  reason TEXT NOT NULL
);

INSERT INTO p3_compatibility_issues
SELECT 'rental_scalar', source.rental_sku_id,
       'rental/equipment scalar fields differ from source payload'
FROM migration.p3_rental_sku_source source
LEFT JOIN rental_skus rental ON rental.id = source.rental_sku_id
LEFT JOIN equipment_items item ON item.id = rental.item_id
LEFT JOIN product_categories category ON category.id = item.category_id
LEFT JOIN brands brand ON brand.id = item.brand_id
WHERE rental.id IS NULL OR item.id IS NULL
   OR rental.item_id IS DISTINCT FROM source.payload->>'productId'
   OR item.name IS DISTINCT FROM source.payload->>'name'
   OR item.main_image_url IS DISTINCT FROM source.payload->>'image'
   OR category.name IS DISTINCT FROM source.payload->>'category'
   OR brand.name IS DISTINCT FROM source.payload->>'brand';

INSERT INTO p3_compatibility_issues
SELECT 'rental_variant', source.rental_sku_id || ':' || (source_variant.value->>'id'),
       'rental variant differs from source payload'
FROM migration.p3_rental_sku_source source
CROSS JOIN LATERAL jsonb_array_elements(source.payload->'variants') source_variant(value)
LEFT JOIN rental_sku_variants variant ON variant.id = source_variant.value->>'id'
WHERE variant.id IS NULL
   OR variant.rental_sku_id IS DISTINCT FROM source.rental_sku_id
   OR variant.sku IS DISTINCT FROM source_variant.value->>'id'
   OR COALESCE(variant.color, '') IS DISTINCT FROM COALESCE(source_variant.value->>'color', '')
   OR COALESCE(variant.size, '') IS DISTINCT FROM COALESCE(source_variant.value->>'size', '')
   OR variant.specification IS DISTINCT FROM source_variant.value->>'label';

INSERT INTO p3_compatibility_issues
SELECT 'rental_stock', source.rental_sku_id || ':' ||
       (source_variant.value->>'id') || ':' || source_stock.location_id,
       format('expected=%s actual=%s', source_stock.quantity, stock.on_hand_quantity)
FROM migration.p3_rental_sku_source source
CROSS JOIN LATERAL jsonb_array_elements(source.payload->'variants') source_variant(value)
CROSS JOIN LATERAL jsonb_each_text(source_variant.value->'camp') source_stock(location_id, quantity)
LEFT JOIN rental_sku_variant_stocks stock
  ON stock.location_id = source_stock.location_id
 AND stock.rental_sku_variant_id = source_variant.value->>'id'
WHERE stock.rental_sku_variant_id IS NULL
   OR stock.on_hand_quantity <> source_stock.quantity::integer;

INSERT INTO p3_compatibility_issues
SELECT 'rental_camp_aggregate', source.rental_sku_id || ':' || (source_camp.value->>'campgroundId'),
       format('expected=%s actual=%s', source_camp.value->>'quantity', target.quantity)
FROM migration.p3_rental_sku_source source
CROSS JOIN LATERAL jsonb_array_elements(source.payload->'camp') source_camp(value)
LEFT JOIN LATERAL (
  SELECT COALESCE(sum(stock.on_hand_quantity), 0)::integer AS quantity
  FROM rental_sku_variants variant
  JOIN rental_sku_variant_stocks stock
    ON stock.rental_sku_variant_id = variant.id
  WHERE variant.rental_sku_id = source.rental_sku_id
    AND stock.location_id = source_camp.value->>'campgroundId'
) target ON TRUE
WHERE target.quantity <> (source_camp.value->>'quantity')::integer;

INSERT INTO p3_compatibility_issues
SELECT 'listing_dto', source.listing_id,
       'reconstructed listing DTO differs from source payload'
FROM migration.p3_listing_source source
LEFT JOIN rental_listings listing ON listing.id = source.listing_id
LEFT JOIN rental_sku_variants variant ON variant.id = listing.rental_sku_variant_id
LEFT JOIN rental_skus rental ON rental.id = variant.rental_sku_id
LEFT JOIN equipment_items item ON item.id = rental.item_id
LEFT JOIN campground_rental_locations mapping ON mapping.campground_id = listing.campground_id
LEFT JOIN rental_sku_variant_stocks stock
  ON stock.location_id = mapping.location_id
 AND stock.rental_sku_variant_id = listing.rental_sku_variant_id
WHERE listing.id IS NULL
   OR rental.id IS DISTINCT FROM source.payload->>'rentalSkuId'
   OR rental.item_id IS DISTINCT FROM source.payload->>'productId'
   OR variant.id IS DISTINCT FROM source.payload->>'variantId'
   OR variant.sku IS DISTINCT FROM source.payload->>'sku'
   OR item.name IS DISTINCT FROM source.payload->>'name'
   OR COALESCE(variant.color, '') IS DISTINCT FROM COALESCE(source.payload->>'color', '')
   OR COALESCE(variant.size, '') IS DISTINCT FROM COALESCE(source.payload->>'size', '')
   OR variant.specification IS DISTINCT FROM source.payload->>'specLabel'
   OR item.main_image_url IS DISTINCT FROM source.payload->>'imageUrl'
   OR listing.campground_id IS DISTINCT FROM source.payload->>'campgroundId'
   OR listing.terrain IS DISTINCT FROM source.payload->>'terrainTag'
   OR listing.description IS DISTINCT FROM source.payload->>'description'
   OR listing.price_per_day_weekday IS DISTINCT FROM
        (source.payload->'pricing'->>'pricePerDayWeekday')::numeric
   OR listing.price_per_day_holiday IS DISTINCT FROM
        (source.payload->'pricing'->>'pricePerDayHoliday')::numeric
   OR listing.discount IS DISTINCT FROM (source.payload->'pricing'->>'discount')::numeric
   OR stock.on_hand_quantity IS DISTINCT FROM (source.payload->>'stock')::integer;

INSERT INTO p3_compatibility_issues
SELECT 'listing_view', source.listing_id,
       'rental_listing_view differs from source payload or resolved location'
FROM migration.p3_listing_source source
LEFT JOIN rental_listing_view listing ON listing.id = source.listing_id
WHERE listing.id IS NULL
   OR listing.campground_id IS DISTINCT FROM source.payload->>'campgroundId'
   OR listing.location_id IS DISTINCT FROM source.payload->>'campgroundId'
   OR listing.rental_sku_variant_id IS DISTINCT FROM source.payload->>'variantId'
   OR listing.price_per_day_weekday IS DISTINCT FROM
        (source.payload->'pricing'->>'pricePerDayWeekday')::numeric
   OR listing.price_per_day_holiday IS DISTINCT FROM
        (source.payload->'pricing'->>'pricePerDayHoliday')::numeric
   OR listing.discount IS DISTINCT FROM (source.payload->'pricing'->>'discount')::numeric
   OR listing.stock IS DISTINCT FROM (source.payload->>'stock')::integer;

INSERT INTO p3_compatibility_issues
SELECT 'variant_map', source.rental_sku_id || ':' || (source_variant.value->>'id'),
       'legacy to rental variant audit mapping differs'
FROM migration.p3_rental_sku_source source
CROSS JOIN LATERAL jsonb_array_elements(source.payload->'variants') source_variant(value)
LEFT JOIN migration.p3_rental_variant_map mapping
  ON mapping.rental_sku_id = source.rental_sku_id
 AND mapping.legacy_variant_id = source_variant.value->>'id'
WHERE mapping.rental_variant_id IS DISTINCT FROM source_variant.value->>'id';

INSERT INTO p3_compatibility_issues
SELECT 'minimum_stock_mapping', minimum.rental_sku_id || ':' || minimum.location_id,
       'minimum-stock evidence cannot resolve a rental group, variant or rental location'
FROM migration.p3_rental_min_stock_source minimum
LEFT JOIN rental_skus rental ON rental.id = minimum.rental_sku_id
LEFT JOIN inventory_locations location
  ON location.id = minimum.location_id AND location.inventory_domain = 'rental'
WHERE rental.id IS NULL OR location.id IS NULL
   OR NOT EXISTS (
     SELECT 1 FROM rental_sku_variants variant
     WHERE variant.rental_sku_id = minimum.rental_sku_id
   );

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*),
  'issues', COALESCE(jsonb_agg(jsonb_build_object(
    'check', check_name, 'id', data_id, 'reason', reason
  ) ORDER BY check_name, data_id), '[]'::jsonb)
))
FROM p3_compatibility_issues;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p3_compatibility_issues) THEN
    RAISE EXCEPTION 'P3 compatibility validation failed with % issue(s)',
      (SELECT count(*) FROM p3_compatibility_issues);
  END IF;
END $$;
