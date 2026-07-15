\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
  category_id_value BIGINT;
  brand_id_value VARCHAR(32);
BEGIN
  SELECT id INTO category_id_value FROM product_categories ORDER BY id LIMIT 1;
  SELECT id INTO brand_id_value FROM brands ORDER BY id LIMIT 1;

  INSERT INTO equipment_items (id, category_id, brand_id, name)
  VALUES ('P3-TEST-ITEM', category_id_value, brand_id_value, 'P3 Test Item');
  INSERT INTO rental_skus (id, item_id, status)
  VALUES ('P3-TEST-RENTAL', 'P3-TEST-ITEM', 'active');
  INSERT INTO rental_sku_variants (
    id, rental_sku_id, sku, specification, status
  ) VALUES (
    'P3-TEST-VARIANT', 'P3-TEST-RENTAL', 'P3-TEST-SKU', 'standard', 'active'
  );
  INSERT INTO rental_sku_variant_stocks (
    location_id, rental_sku_variant_id, on_hand_quantity
  ) VALUES
    ('C001', 'P3-TEST-VARIANT', 1),
    ('C002', 'P3-TEST-VARIANT', 1);
  INSERT INTO rental_listings (
    id, campground_id, rental_sku_variant_id,
    price_per_day_weekday, price_per_day_holiday, discount
  ) VALUES (
    'P3-TEST-LISTING', 'C002', 'P3-TEST-VARIANT', 1, 1, 0
  );

  BEGIN
    INSERT INTO rental_skus (id, item_id, status)
    VALUES ('P3-TEST-DUPLICATE-ITEM', 'P3-TEST-ITEM', 'active');
    RAISE EXCEPTION 'one equipment item was accepted by two rental groups';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO rental_sku_variants (
      id, rental_sku_id, sku, specification, status
    ) VALUES (
      'P3-TEST-DUPLICATE-SKU', 'P3-TEST-RENTAL', 'P3-TEST-SKU', 'duplicate', 'active'
    );
    RAISE EXCEPTION 'duplicate rental SKU was accepted';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  BEGIN
    UPDATE rental_sku_variant_stocks SET on_hand_quantity = -1
    WHERE rental_sku_variant_id = 'P3-TEST-VARIANT' AND location_id = 'C001';
    RAISE EXCEPTION 'negative rental stock was accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    UPDATE rental_listings SET price_per_day_weekday = -1
    WHERE id = 'P3-TEST-LISTING';
    RAISE EXCEPTION 'negative rental listing price was accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- Campground rental-location classification is validated by Spring Boot.

  INSERT INTO campgrounds (id, name, region)
  VALUES ('P3-TEST-CAMP', 'P3 Test Camp', 'test');
  BEGIN
    INSERT INTO rental_listings (
      id, campground_id, rental_sku_variant_id,
      price_per_day_weekday, price_per_day_holiday, discount
    ) VALUES (
      'P3-TEST-NO-MAPPING', 'P3-TEST-CAMP', 'P3-TEST-VARIANT', 1, 1, 0
    );
    RAISE EXCEPTION 'listing without campground rental mapping was accepted';
  EXCEPTION WHEN foreign_key_violation THEN NULL;
  END;

  BEGIN
    DELETE FROM rental_sku_variants WHERE id = 'P3-TEST-VARIANT';
    RAISE EXCEPTION 'referenced rental variant was physically deleted';
  EXCEPTION WHEN integrity_constraint_violation THEN NULL;
  END;

  BEGIN
    DELETE FROM campground_rental_locations WHERE campground_id = 'C002';
    RAISE EXCEPTION 'referenced campground rental mapping was physically deleted';
  EXCEPTION WHEN integrity_constraint_violation THEN NULL;
  END;
END $$;

ROLLBACK;
SELECT jsonb_pretty(jsonb_build_object('issueCount', 0, 'result', 'P3 business-rule cases passed'));
