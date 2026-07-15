\set ON_ERROR_STOP on

BEGIN;

INSERT INTO customers (
  id, name, email, registered_at, auth_provider
) VALUES
  ('P4-TIER-11999', 'P4 Tier 11999', 'p4-tier-11999@example.test', NOW(), 'google'),
  ('P4-TIER-12000', 'P4 Tier 12000', 'p4-tier-12000@example.test', NOW(), 'google'),
  ('P4-TIER-27999', 'P4 Tier 27999', 'p4-tier-27999@example.test', NOW(), 'google'),
  ('P4-TIER-28000', 'P4 Tier 28000', 'p4-tier-28000@example.test', NOW(), 'google');

INSERT INTO orders (
  id, customer_id, buyer_name_snapshot, buyer_email_snapshot,
  recipient_name_snapshot, shipping_address_snapshot,
  shipping_phone_snapshot, subtotal, shipping_fee, discount, total,
  payment_method, payment_status, refund_status, status,
  placed_at, paid_at, created_at, updated_at
) VALUES
  ('P4-TIER-11999', 'P4-TIER-11999', 'P4 Test', 'p4-tier-11999@example.test',
   'P4 Test', 'test', '0900000000', 11999, 0, 0, 11999,
   'online', 'paid', 'none', 'completed', NOW(), NOW(), NOW(), NOW()),
  ('P4-TIER-12000', 'P4-TIER-12000', 'P4 Test', 'p4-tier-12000@example.test',
   'P4 Test', 'test', '0900000000', 12000, 0, 0, 12000,
   'online', 'paid', 'none', 'completed', NOW(), NOW(), NOW(), NOW()),
  ('P4-TIER-27999', 'P4-TIER-27999', 'P4 Test', 'p4-tier-27999@example.test',
   'P4 Test', 'test', '0900000000', 27999, 0, 0, 27999,
   'online', 'paid', 'none', 'completed', NOW(), NOW(), NOW(), NOW()),
  ('P4-TIER-28000', 'P4-TIER-28000', 'P4 Test', 'p4-tier-28000@example.test',
   'P4 Test', 'test', '0900000000', 28000, 0, 0, 28000,
   'online', 'paid', 'none', 'completed', NOW(), NOW(), NOW(), NOW());

DO $$
DECLARE
  order_item_value order_items%ROWTYPE;
  product_location_id VARCHAR(32);
  rental_detail_value booking_selected_rentals%ROWTYPE;
  rental_location_id VARCHAR(32);
  coupon_id_value BIGINT;
BEGIN
  IF EXISTS (
    SELECT 1
    FROM (VALUES
      ('P4-TIER-11999', 11999::NUMERIC, 'explorer', '探險家'),
      ('P4-TIER-12000', 12000::NUMERIC, 'guide', '嚮導'),
      ('P4-TIER-27999', 27999::NUMERIC, 'guide', '嚮導'),
      ('P4-TIER-28000', 28000::NUMERIC, 'master', '大師')
    ) expected(customer_id, total_spent, tier_code, tier_name)
    LEFT JOIN customer_tier_summary actual
      ON actual.customer_id = expected.customer_id
    WHERE actual.customer_id IS NULL
       OR actual.total_spent IS DISTINCT FROM expected.total_spent
       OR actual.tier_code IS DISTINCT FROM expected.tier_code
       OR actual.tier_name IS DISTINCT FROM expected.tier_name
  ) THEN
    RAISE EXCEPTION 'D-001 tier boundary view failed';
  END IF;

  BEGIN
    UPDATE orders SET total = total + 1 WHERE id = 'P4-TIER-11999';
    RAISE EXCEPTION 'invalid order amount formula was accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    UPDATE orders SET payment_method = 'cash' WHERE id = 'P4-TIER-11999';
    RAISE EXCEPTION 'invalid payment method was accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    DELETE FROM customers WHERE id = 'P4-TIER-11999';
    RAISE EXCEPTION 'referenced order customer was deleted';
  EXCEPTION WHEN integrity_constraint_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO order_items (
      order_id, product_id, variant_id, sku_snapshot,
      product_name_snapshot, specification_snapshot, brand_name_snapshot,
      unit_price_snapshot, quantity
    ) VALUES (
      'P4-TIER-11999', 'P001', 'v-P002-0', 'P4-MISMATCH',
      'mismatched product', 'mismatched variant', 'P4', 1, 1
    );
    RAISE EXCEPTION 'mismatched product and variant were accepted';
  EXCEPTION WHEN foreign_key_violation THEN NULL;
  END;

  BEGIN
    UPDATE coupons SET discount_type = 'percent', discount_value = 101
    WHERE id = (SELECT min(id) FROM coupons);
    RAISE EXCEPTION 'percentage coupon over 100 was accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  SELECT min(id) INTO coupon_id_value FROM coupons;
  INSERT INTO order_coupons (
    order_id, coupon_id, code_snapshot, discount_type_snapshot,
    discount_value_snapshot, amount, applied_at
  ) VALUES (
    'P4-TIER-11999', coupon_id_value, 'P4-TEST-COUPON',
    'fixed', 1, 0, NOW()
  );

  INSERT INTO coupon_usage_adjustments (
    order_coupon_id, adjustment_type, quantity_delta,
    idempotency_key, reason
  ) VALUES (
    currval(pg_get_serial_sequence('order_coupons', 'id')),
    'restore', -1, 'P4-TEST-COUPON-RESTORE', 'P4 rollback validation'
  );

  BEGIN
    INSERT INTO coupon_usage_adjustments (
      order_coupon_id, adjustment_type, quantity_delta,
      idempotency_key, reason
    ) VALUES (
      currval(pg_get_serial_sequence('order_coupons', 'id')),
      'restore', 1, 'P4-TEST-BAD-DELTA', 'P4 rollback validation'
    );
    RAISE EXCEPTION 'coupon adjustment with wrong delta was accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO coupon_usage_adjustments (
      order_coupon_id, adjustment_type, quantity_delta,
      idempotency_key, reason
    ) VALUES (
      currval(pg_get_serial_sequence('order_coupons', 'id')),
      'restore', -1, 'P4-TEST-COUPON-RESTORE', 'duplicate'
    );
    RAISE EXCEPTION 'duplicate coupon adjustment idempotency key was accepted';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  BEGIN
    UPDATE calendar_dates SET holiday_name = 'invalid'
    WHERE calendar_date = (
      SELECT min(calendar_date) FROM calendar_dates WHERE NOT is_holiday
    );
    RAISE EXCEPTION 'non-holiday calendar row accepted a holiday name';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    UPDATE bookings SET weekday_count = weekday_count + 1
    WHERE id = (SELECT min(id) FROM bookings);
    RAISE EXCEPTION 'booking day-count mismatch was accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    UPDATE bookings SET final_amount = final_amount + 1
    WHERE id = (SELECT min(id) FROM bookings);
    RAISE EXCEPTION 'booking amount mismatch was accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  SELECT item.* INTO order_item_value
  FROM order_items item
  WHERE EXISTS (
    SELECT 1 FROM inventory_stocks stock WHERE stock.variant_id = item.variant_id
  )
  ORDER BY item.id LIMIT 1;
  SELECT location_id INTO product_location_id
  FROM inventory_stocks WHERE variant_id = order_item_value.variant_id
  ORDER BY location_id LIMIT 1;

  INSERT INTO product_stock_reservations (
    order_item_id, variant_id, location_id, quantity, status,
    idempotency_key, reserved_at, expires_at
  ) VALUES (
    order_item_value.id, order_item_value.variant_id, product_location_id,
    1, 'active', 'P4-TEST-PRODUCT-RESERVATION', NOW(), NOW() + INTERVAL '30 minutes'
  );

  BEGIN
    INSERT INTO product_stock_reservations (
      order_item_id, variant_id, location_id, quantity, status,
      idempotency_key, reserved_at, released_at
    ) VALUES (
      order_item_value.id, order_item_value.variant_id, product_location_id,
      1, 'active', 'P4-TEST-PRODUCT-BAD-TERMINAL', NOW(), NOW()
    );
    RAISE EXCEPTION 'active product reservation accepted released_at';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO product_stock_reservations (
      order_item_id, variant_id, location_id, quantity, status,
      idempotency_key, reserved_at
    ) VALUES (
      order_item_value.id, order_item_value.variant_id, product_location_id,
      1, 'active', 'P4-TEST-PRODUCT-RESERVATION', NOW()
    );
    RAISE EXCEPTION 'duplicate product reservation idempotency key was accepted';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  BEGIN
    DELETE FROM order_items WHERE id = order_item_value.id;
    RAISE EXCEPTION 'reserved order item was deleted';
  EXCEPTION WHEN integrity_constraint_violation THEN NULL;
  END;

  SELECT detail.* INTO rental_detail_value
  FROM booking_selected_rentals detail ORDER BY detail.id LIMIT 1;
  SELECT mapping.location_id INTO rental_location_id
  FROM booking_selected_rentals detail
  JOIN bookings booking ON booking.id = detail.booking_id
  JOIN campground_rental_locations mapping
    ON mapping.campground_id = booking.campground_id
  WHERE detail.id = rental_detail_value.id;

  INSERT INTO rental_stock_reservations (
    booking_selected_rental_id, rental_sku_variant_id, location_id,
    check_in, check_out, quantity, status, idempotency_key, reserved_at
  ) VALUES (
    rental_detail_value.id, rental_detail_value.rental_sku_variant_id,
    rental_location_id, DATE '2099-01-01', DATE '2099-01-02', 1,
    'active', 'P4-TEST-RENTAL-RESERVATION', NOW()
  );

  BEGIN
    INSERT INTO rental_stock_reservations (
      booking_selected_rental_id, rental_sku_variant_id, location_id,
      check_in, check_out, quantity, status, idempotency_key, reserved_at
    ) VALUES (
      rental_detail_value.id, rental_detail_value.rental_sku_variant_id,
      rental_location_id, DATE '2099-01-02', DATE '2099-01-01', 1,
      'active', 'P4-TEST-RENTAL-BAD-DATES', NOW()
    );
    RAISE EXCEPTION 'invalid rental reservation interval was accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO rental_stock_reservations (
      booking_selected_rental_id, rental_sku_variant_id, location_id,
      check_in, check_out, quantity, status, idempotency_key, reserved_at
    ) VALUES (
      rental_detail_value.id, rental_detail_value.rental_sku_variant_id,
      rental_location_id, DATE '2099-01-01', DATE '2099-01-02', 1,
      'active', 'P4-TEST-RENTAL-RESERVATION', NOW()
    );
    RAISE EXCEPTION 'duplicate rental reservation idempotency key was accepted';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
END $$;

ROLLBACK;

DO $$
BEGIN
  IF EXISTS (
    WITH active_usage AS (
      SELECT reservation.rental_sku_variant_id, reservation.location_id,
             day_value::DATE AS reserved_date,
             sum(reservation.quantity) AS reserved_quantity
      FROM rental_stock_reservations reservation
      CROSS JOIN LATERAL generate_series(
        reservation.check_in, reservation.check_out - 1, INTERVAL '1 day'
      ) day_value
      WHERE reservation.status = 'active'
      GROUP BY reservation.rental_sku_variant_id,
               reservation.location_id, day_value::DATE
    )
    SELECT 1
    FROM active_usage usage
    LEFT JOIN rental_sku_variant_stocks stock
      ON stock.rental_sku_variant_id = usage.rental_sku_variant_id
     AND stock.location_id = usage.location_id
    WHERE stock.rental_sku_variant_id IS NULL
       OR usage.reserved_quantity > stock.on_hand_quantity
  ) THEN
    RAISE EXCEPTION 'current active rental reservations exceed physical stock';
  END IF;

  IF EXISTS (SELECT 1 FROM product_stock_summary WHERE total_available < 0) THEN
    RAISE EXCEPTION 'current active product reservations make availability negative';
  END IF;
END $$;

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', 0,
  'result', 'P4 transaction, coupon, calendar, tier and reservation rules passed'
));
