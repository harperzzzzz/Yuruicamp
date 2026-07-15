\set ON_ERROR_STOP on

BEGIN;

CREATE TEMP TABLE p5_business_issues (
  check_name TEXT NOT NULL,
  reason TEXT NOT NULL
);

DO $$
DECLARE
  store_movement_id BIGINT;
  rental_movement_id BIGINT;
  cancelled_movement_id BIGINT;
  mismatch_movement_id BIGINT;
  reservation_id BIGINT;
  order_item_value RECORD;
  stock_before INTEGER;
  stock_after INTEGER;
  combined_before INTEGER;
  combined_after INTEGER;
BEGIN
  BEGIN
    INSERT INTO booking_policies (
      id, booking_window_days, advance_days, max_nights,
      timezone, date_boundary_hour, low_availability_threshold
    ) VALUES (2, 90, 0, 7, 'Asia/Taipei', 0, 30);
    INSERT INTO p5_business_issues VALUES
      ('policy_singleton', 'id other than 1 was accepted');
  EXCEPTION WHEN check_violation OR unique_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO zone_blocks (
      legacy_block_id, campground_id, zone_id, start_date, end_date,
      blocked_quantity, reason, created_by
    ) VALUES (
      'TEST-BAD-ZONE', 'C003', 'Z001', DATE '2026-08-01', DATE '2026-08-02',
      1, 'expected rejection', 'admin'
    );
    INSERT INTO p5_business_issues VALUES
      ('zone_campground_fk', 'zone from another campground was accepted');
  EXCEPTION WHEN foreign_key_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO campground_closures (
      legacy_closure_id, campground_id, closure_type, weekday,
      reason, created_by
    ) VALUES ('TEST-BAD-CLOSURE', 'C002', 'weekly', 2, 'expected rejection', 'admin');
    INSERT INTO p5_business_issues VALUES
      ('closure_payload', 'weekly closure without effective range was accepted');
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- Minimum-stock location-domain validation is owned by Spring Boot.

  BEGIN
    INSERT INTO inventory_movements (
      movement_no, inventory_domain, movement_type, status,
      source_location_id, destination_location_id, employee_id, reason, occurred_at
    ) VALUES (
      'P5-TEST-BAD-LOCATION', 'store', 'transfer', 'draft',
      'C001', 'main', 'admin', 'expected rejection', clock_timestamp()
    );
    INSERT INTO p5_business_issues VALUES
      ('movement_location_domain', 'store movement accepted a rental location');
  EXCEPTION WHEN foreign_key_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO inventory_movements (
      movement_no, inventory_domain, movement_type, status,
      source_location_id, employee_id, reason, occurred_at
    ) VALUES (
      'P5-TEST-BAD-TRANSFER', 'store', 'transfer', 'draft',
      'main', 'admin', 'expected rejection', clock_timestamp()
    );
    INSERT INTO p5_business_issues VALUES
      ('movement_type_payload', 'transfer with only one endpoint was accepted');
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  INSERT INTO inventory_movements (
    movement_no, inventory_domain, movement_type, status,
    destination_location_id, employee_id, reason, occurred_at
  ) VALUES (
    'P5-TEST-RENTAL-MISMATCH', 'rental', 'receipt', 'draft',
    'C001', 'admin', 'detail mismatch test', clock_timestamp()
  ) RETURNING id INTO mismatch_movement_id;

  BEGIN
    INSERT INTO store_inventory_movement_items (
      movement_id, inventory_domain, variant_id, sku_snapshot,
      item_name_snapshot, quantity
    ) VALUES (
      mismatch_movement_id, 'store', 'v-P002-0', 'v-P002-0', 'test', 1
    );
    INSERT INTO p5_business_issues VALUES
      ('store_detail_domain', 'store detail was accepted on rental movement');
  EXCEPTION WHEN foreign_key_violation THEN NULL;
  END;

  INSERT INTO inventory_movements (
    movement_no, inventory_domain, movement_type, status,
    destination_location_id, employee_id, reason, occurred_at
  ) VALUES (
    'P5-TEST-POST', 'store', 'receipt', 'draft',
    'main', 'admin', 'draft movement', clock_timestamp()
  ) RETURNING id INTO store_movement_id;

  INSERT INTO store_inventory_movement_items (
    movement_id, inventory_domain, variant_id, sku_snapshot,
    item_name_snapshot, quantity
  ) VALUES (
    store_movement_id, 'store', 'v-P002-0', 'v-P002-0', 'MSR 超輕量帳篷（沙漠卡其）', 1
  );

  UPDATE inventory_movements SET reason = 'draft remains editable' WHERE id = store_movement_id;
  UPDATE inventory_movements
  SET status = 'posted', posted_at = clock_timestamp(), updated_at = clock_timestamp()
  WHERE id = store_movement_id;

  -- Posted movement and detail immutability are owned by Spring Boot.

  SELECT sum(on_hand_quantity)::integer INTO stock_before FROM inventory_stocks;
  INSERT INTO inventory_movements (
    movement_no, inventory_domain, movement_type, status,
    destination_location_id, employee_id, reason, occurred_at
  ) VALUES (
    'P5-TEST-CANCEL', 'store', 'receipt', 'draft',
    'main', 'admin', 'cancel test', clock_timestamp()
  ) RETURNING id INTO cancelled_movement_id;
  UPDATE inventory_movements SET status = 'cancelled' WHERE id = cancelled_movement_id;
  SELECT sum(on_hand_quantity)::integer INTO stock_after FROM inventory_stocks;
  IF stock_after <> stock_before THEN
    INSERT INTO p5_business_issues VALUES
      ('cancelled_stock', 'cancelled movement changed physical stock');
  END IF;
  -- Cancelled movement editability is owned by Spring Boot.

  INSERT INTO inventory_movements (
    movement_no, inventory_domain, movement_type, status,
    source_location_id, employee_id, reason, occurred_at
  ) VALUES (
    'P5-TEST-CONVERSION-OUT', 'store', 'conversion_out', 'draft',
    'main', 'admin', 'conversion test', clock_timestamp()
  ) RETURNING id INTO store_movement_id;
  INSERT INTO inventory_movements (
    movement_no, inventory_domain, movement_type, status,
    destination_location_id, employee_id, reason, occurred_at
  ) VALUES (
    'P5-TEST-CONVERSION-IN', 'rental', 'conversion_in', 'draft',
    'C002', 'admin', 'conversion test', clock_timestamp()
  ) RETURNING id INTO rental_movement_id;

  INSERT INTO inventory_conversions (
    source_movement_id, destination_movement_id,
    source_variant_id, destination_rental_variant_id,
    source_location_id, destination_location_id,
    quantity, idempotency_key
  ) VALUES (
    store_movement_id, rental_movement_id,
    'v-P002-0', 'v-P002-0', 'main', 'C002', 1, 'p5-test-conversion'
  );

  SELECT store.on_hand_quantity + rental.on_hand_quantity
  INTO combined_before
  FROM inventory_stocks store
  CROSS JOIN rental_sku_variant_stocks rental
  WHERE store.variant_id = 'v-P002-0' AND store.location_id = 'main'
    AND rental.rental_sku_variant_id = 'v-P002-0' AND rental.location_id = 'C002';
  UPDATE inventory_stocks SET on_hand_quantity = on_hand_quantity - 1
  WHERE variant_id = 'v-P002-0' AND location_id = 'main';
  UPDATE rental_sku_variant_stocks SET on_hand_quantity = on_hand_quantity + 1
  WHERE rental_sku_variant_id = 'v-P002-0' AND location_id = 'C002';
  UPDATE inventory_movements
  SET status = 'posted', posted_at = clock_timestamp()
  WHERE id IN (store_movement_id, rental_movement_id);
  SELECT store.on_hand_quantity + rental.on_hand_quantity
  INTO combined_after
  FROM inventory_stocks store
  CROSS JOIN rental_sku_variant_stocks rental
  WHERE store.variant_id = 'v-P002-0' AND store.location_id = 'main'
    AND rental.rental_sku_variant_id = 'v-P002-0' AND rental.location_id = 'C002';
  IF combined_after <> combined_before THEN
    INSERT INTO p5_business_issues VALUES
      ('conversion_conservation', 'cross-domain conversion did not conserve quantity');
  END IF;
  -- Posted conversion immutability is owned by Spring Boot.

  SELECT item.id, item.variant_id INTO order_item_value
  FROM order_items item
  JOIN inventory_stocks stock
    ON stock.variant_id = item.variant_id AND stock.location_id = 'main'
  ORDER BY item.id LIMIT 1;
  INSERT INTO product_stock_reservations (
    order_item_id, variant_id, location_id, quantity,
    status, idempotency_key, reserved_at
  ) VALUES (
    order_item_value.id, order_item_value.variant_id, 'main', 1,
    'active', 'p5-test-reservation', clock_timestamp()
  ) RETURNING id INTO reservation_id;
  BEGIN
    INSERT INTO product_stock_reservations (
      order_item_id, variant_id, location_id, quantity,
      status, idempotency_key, reserved_at
    ) VALUES (
      order_item_value.id, order_item_value.variant_id, 'main', 1,
      'active', 'p5-test-reservation', clock_timestamp()
    );
    INSERT INTO p5_business_issues VALUES
      ('reservation_idempotency', 'duplicate reservation request was accepted');
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
  UPDATE product_stock_reservations
  SET status = 'released', released_at = clock_timestamp()
  WHERE id = reservation_id;
  -- Terminal reservation immutability is owned by Spring Boot.
  BEGIN
    INSERT INTO product_stock_reservations (
      order_item_id, variant_id, location_id, quantity,
      status, idempotency_key, reserved_at
    ) VALUES (
      order_item_value.id, order_item_value.variant_id, 'C001', 1,
      'active', 'p5-test-wrong-domain', clock_timestamp()
    );
    INSERT INTO p5_business_issues VALUES
      ('reservation_location_domain', 'product reservation accepted rental location');
  EXCEPTION WHEN foreign_key_violation THEN NULL;
  END;
END $$;

INSERT INTO p5_business_issues
SELECT 'availability_block', 'zone block boundary did not subtract quantity'
WHERE NOT EXISTS (
  SELECT 1 FROM get_zone_availability('2026-07-20', '2026-07-20', NULL, 'Z001')
  WHERE blocked_quantity = 2 AND available_quantity = 8 AND NOT is_closed
);

INSERT INTO p5_business_issues
SELECT 'availability_closure', 'campground closure did not force zero'
WHERE NOT EXISTS (
  SELECT 1 FROM get_zone_availability('2026-07-28', '2026-07-28', NULL, 'Z001')
  WHERE available_quantity = 0 AND is_closed
);

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*),
  'issues', coalesce(jsonb_agg(jsonb_build_object(
    'check', check_name, 'reason', reason
  ) ORDER BY check_name), '[]'::jsonb)
))
FROM p5_business_issues;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p5_business_issues) THEN
    RAISE EXCEPTION 'P5 business validation failed with % issue(s)',
      (SELECT count(*) FROM p5_business_issues);
  END IF;
END $$;

ROLLBACK;
