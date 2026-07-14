-- P4 contract: prove the deterministic transaction backfill, install the
-- target constraints, retain legacy tables as migration evidence, and expose
-- authoritative derived views. P5 objects are intentionally out of scope.

DO $$
BEGIN
  IF (SELECT count(*) FROM migration.p4_order_source)
     <> (SELECT count(*) FROM orders_p4) THEN
    RAISE EXCEPTION 'P4 guard: order row count differs from source';
  END IF;

  IF (SELECT COALESCE(sum(jsonb_array_length(payload->'items')), 0)
      FROM migration.p4_order_source)
     <> (SELECT count(*) FROM order_items_p4) THEN
    RAISE EXCEPTION 'P4 guard: order item row count differs from source';
  END IF;

  IF (SELECT COALESCE(sum(jsonb_array_length(payload->'history')), 0)
      FROM migration.p4_order_source)
     <> (SELECT count(*) FROM order_status_history_p4) THEN
    RAISE EXCEPTION 'P4 guard: order history row count differs from source';
  END IF;

  IF (SELECT count(*) FROM migration.p4_coupon_source)
     <> (SELECT count(*) FROM coupons_p4) THEN
    RAISE EXCEPTION 'P4 guard: coupon row count differs from source';
  END IF;

  IF (SELECT count(*) FROM migration.p4_booking_source)
     <> (SELECT count(*) FROM bookings_p4) THEN
    RAISE EXCEPTION 'P4 guard: booking row count differs from source';
  END IF;

  IF (SELECT COALESCE(sum(jsonb_array_length(payload->'selectedZones')), 0)
      FROM migration.p4_booking_source)
     <> (SELECT count(*) FROM booking_selected_zones_p4) THEN
    RAISE EXCEPTION 'P4 guard: booking zone row count differs from source';
  END IF;

  IF (SELECT COALESCE(sum(jsonb_array_length(payload->'selectedRentals')), 0)
      FROM migration.p4_booking_source)
     <> (SELECT count(*) FROM booking_selected_rentals_p4) THEN
    RAISE EXCEPTION 'P4 guard: booking rental row count differs from source';
  END IF;

  IF (SELECT COALESCE(sum(jsonb_array_length(payload->'history')), 0)
      FROM migration.p4_booking_source)
     <> (SELECT count(*) FROM booking_status_history_p4) THEN
    RAISE EXCEPTION 'P4 guard: booking history row count differs from source';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM orders_p4 orders
    LEFT JOIN (
      SELECT order_id, sum(unit_price_snapshot * quantity)::NUMERIC(14, 2) AS subtotal
      FROM order_items_p4
      GROUP BY order_id
    ) items ON items.order_id = orders.id
    WHERE items.subtotal IS DISTINCT FROM orders.subtotal
       OR orders.total IS DISTINCT FROM
          GREATEST(orders.subtotal + orders.shipping_fee - orders.discount, 0)
  ) THEN
    RAISE EXCEPTION 'P4 guard: order detail or header amount differs';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM bookings_p4 booking
    LEFT JOIN (
      SELECT detail.booking_id,
             sum((
               booking_value.weekday_count * detail.price_weekday_snapshot
               + booking_value.holiday_count * detail.price_holiday_snapshot
             ) * detail.quantity)::NUMERIC(14, 2) AS amount
      FROM booking_selected_zones_p4 detail
      JOIN bookings_p4 booking_value ON booking_value.id = detail.booking_id
      GROUP BY detail.booking_id
    ) zones ON zones.booking_id = booking.id
    LEFT JOIN (
      SELECT detail.booking_id,
             sum(GREATEST(
               booking_value.weekday_count * detail.price_weekday_snapshot
               + booking_value.holiday_count * detail.price_holiday_snapshot
               - detail.discount_snapshot,
               0
             ) * detail.quantity)::NUMERIC(14, 2) AS amount
      FROM booking_selected_rentals_p4 detail
      JOIN bookings_p4 booking_value ON booking_value.id = detail.booking_id
      GROUP BY detail.booking_id
    ) rentals ON rentals.booking_id = booking.id
    WHERE COALESCE(zones.amount, 0) IS DISTINCT FROM booking.zone_total
       OR COALESCE(rentals.amount, 0) IS DISTINCT FROM booking.rental_total
       OR booking.final_amount IS DISTINCT FROM GREATEST(
            booking.zone_total + booking.rental_total - booking.applied_discount,
            0
          )
  ) THEN
    RAISE EXCEPTION 'P4 guard: booking detail or header amount differs';
  END IF;

  IF (SELECT count(*) FROM calendar_dates_p4) <> 365
     OR (SELECT min(calendar_date) FROM calendar_dates_p4) <> DATE '2026-01-01'
     OR (SELECT max(calendar_date) FROM calendar_dates_p4) <> DATE '2026-12-31'
     OR EXISTS (
       SELECT 1
       FROM bookings_p4 booking
       LEFT JOIN LATERAL (
         SELECT
           count(*) FILTER (WHERE NOT calendar.is_holiday)::INTEGER AS weekday_count,
           count(*) FILTER (WHERE calendar.is_holiday)::INTEGER AS holiday_count
         FROM calendar_dates_p4 calendar
         WHERE calendar.calendar_date >= booking.check_in
           AND calendar.calendar_date < booking.check_out
       ) resolved ON TRUE
       WHERE resolved.weekday_count IS DISTINCT FROM booking.weekday_count
          OR resolved.holiday_count IS DISTINCT FROM booking.holiday_count
     ) THEN
    RAISE EXCEPTION 'P4 guard: official calendar coverage or booking day counts differ';
  END IF;

  IF EXISTS (
    SELECT 1 FROM migration.p4_booking_day_count_resolution
    WHERE disposition_status NOT IN ('MATCHED', 'APPROVED_FALLBACK')
       OR resolved_weekday_count IS NULL OR resolved_holiday_count IS NULL
  ) OR EXISTS (
    SELECT 1 FROM migration.p4_zone_price_reconciliation
    WHERE disposition_status NOT IN ('MATCHED', 'APPROVED_FALLBACK')
       OR chosen_weekday_price IS NULL OR chosen_holiday_price IS NULL
  ) OR EXISTS (
    SELECT 1 FROM migration.p4_rental_price_reconciliation
    WHERE disposition_status NOT IN ('MATCHED', 'APPROVED_FALLBACK')
       OR chosen_weekday_price IS NULL OR chosen_holiday_price IS NULL
       OR chosen_discount IS NULL
  ) THEN
    RAISE EXCEPTION 'P4 guard: unresolved calendar or price reconciliation remains';
  END IF;

  IF (SELECT count(*) FROM migration.p4_snapshot_fallbacks)
     <> 3 * (SELECT count(*) FROM migration.p4_order_source)
        + (SELECT count(*) FROM migration.p4_coupon_source)
     OR EXISTS (
       SELECT 1 FROM migration.p4_snapshot_fallbacks
       WHERE (domain = 'order' AND field_name NOT IN (
                'buyer_email_snapshot', 'recipient_name_snapshot',
                'shipping_phone_snapshot'
              ))
          OR (domain = 'coupon' AND field_name <> 'name')
          OR domain NOT IN ('order', 'coupon')
     ) THEN
    RAISE EXCEPTION 'P4 guard: approved snapshot fallback evidence is incomplete';
  END IF;

  IF (SELECT count(*) FROM product_stock_reservations_p4) <> 0 THEN
    RAISE EXCEPTION 'P4 guard: historical product reservation was created';
  END IF;

  IF (SELECT count(*) FROM rental_stock_reservations_p4) <> 21
     OR (SELECT count(*) FROM rental_stock_reservations_p4 WHERE status = 'active') <> 3
     OR (SELECT count(*) FROM rental_stock_reservations_p4
         WHERE status IN ('released', 'fulfilled')) <> 18
     OR (SELECT count(*) FROM migration.p4_rental_reservation_quarantine) <> 19
     OR EXISTS (
       SELECT 1 FROM migration.p4_rental_reservation_quarantine
       WHERE disposition_status <> 'APPROVED_QUARANTINE'
          OR reason_code NOT IN ('STALE_ACTIVE_PAST', 'FUTURE_CAPACITY_CONFLICT')
     )
     OR (SELECT count(*) FROM rental_stock_reservations_p4)
        + (SELECT count(*) FROM migration.p4_rental_reservation_quarantine)
        <> (SELECT COALESCE(sum(jsonb_array_length(payload->'selectedRentals')), 0)
            FROM migration.p4_booking_source) THEN
    RAISE EXCEPTION 'P4 guard: approved rental reservation disposition differs';
  END IF;

  IF EXISTS (
    WITH active_usage AS (
      SELECT reservation.rental_sku_variant_id,
             reservation.location_id,
             day_value::DATE AS reserved_date,
             sum(reservation.quantity) AS reserved_quantity
      FROM rental_stock_reservations_p4 reservation
      CROSS JOIN LATERAL generate_series(
        reservation.check_in,
        reservation.check_out - 1,
        INTERVAL '1 day'
      ) day_value
      WHERE reservation.status = 'active'
      GROUP BY reservation.rental_sku_variant_id,
               reservation.location_id,
               day_value::DATE
    )
    SELECT 1
    FROM active_usage usage
    LEFT JOIN rental_sku_variant_stocks stock
      ON stock.rental_sku_variant_id = usage.rental_sku_variant_id
     AND stock.location_id = usage.location_id
    WHERE stock.rental_sku_variant_id IS NULL
       OR usage.reserved_quantity > stock.on_hand_quantity
  ) THEN
    RAISE EXCEPTION 'P4 guard: active rental reservations exceed physical stock';
  END IF;
END
$$;

ALTER TABLE orders_p4
  ADD CONSTRAINT pk_orders PRIMARY KEY (id),
  ADD CONSTRAINT fk_orders_customer_id
    FOREIGN KEY (customer_id) REFERENCES customers(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT ck_orders_money CHECK (
    subtotal >= 0 AND shipping_fee >= 0 AND discount >= 0
    AND total = GREATEST(subtotal + shipping_fee - discount, 0)
  ),
  ADD CONSTRAINT ck_orders_payment_method
    CHECK (payment_method IN ('online', 'cod')),
  ADD CONSTRAINT ck_orders_status CHECK (
    status IN ('unshipped', 'shipped', 'completed', 'cancelled', 'returned')
  );

ALTER TABLE order_items_p4
  ADD CONSTRAINT pk_order_items PRIMARY KEY (id),
  ADD CONSTRAINT fk_order_items_order_id
    FOREIGN KEY (order_id) REFERENCES orders_p4(id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  ADD CONSTRAINT fk_order_items_product_id
    FOREIGN KEY (product_id) REFERENCES products(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_order_items_variant_id
    FOREIGN KEY (variant_id) REFERENCES product_variants(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT uq_order_items_id_variant_id UNIQUE (id, variant_id),
  ADD CONSTRAINT ck_order_items_quantity CHECK (quantity > 0),
  ADD CONSTRAINT ck_order_items_price CHECK (unit_price_snapshot >= 0);

ALTER TABLE order_status_history_p4
  ADD CONSTRAINT pk_order_status_history PRIMARY KEY (id),
  ADD CONSTRAINT fk_order_status_history_order_id
    FOREIGN KEY (order_id) REFERENCES orders_p4(id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  ADD CONSTRAINT fk_order_status_history_actor_id
    FOREIGN KEY (actor_id) REFERENCES admin_users(id)
    ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE coupons_p4
  ADD CONSTRAINT pk_coupons PRIMARY KEY (id),
  ADD CONSTRAINT uq_coupons_code UNIQUE (code),
  ADD CONSTRAINT ck_coupons_type
    CHECK (discount_type IN ('fixed', 'percent')),
  ADD CONSTRAINT ck_coupons_values CHECK (
    discount_value > 0 AND minimum_amount >= 0 AND issue_quantity >= 0
  ),
  ADD CONSTRAINT ck_coupons_dates CHECK (valid_until > valid_from),
  ADD CONSTRAINT ck_coupons_percentage
    CHECK (discount_type <> 'percent' OR discount_value <= 100);

ALTER TABLE order_coupons_p4
  ADD CONSTRAINT pk_order_coupons PRIMARY KEY (id),
  ADD CONSTRAINT fk_order_coupons_order_id
    FOREIGN KEY (order_id) REFERENCES orders_p4(id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  ADD CONSTRAINT fk_order_coupons_coupon_id
    FOREIGN KEY (coupon_id) REFERENCES coupons_p4(id)
    ON UPDATE CASCADE ON DELETE SET NULL,
  ADD CONSTRAINT uq_order_coupons_order_id_code_snapshot
    UNIQUE (order_id, code_snapshot),
  ADD CONSTRAINT ck_order_coupons_amounts
    CHECK (discount_value_snapshot >= 0 AND amount >= 0);

ALTER TABLE coupon_usage_adjustments_p4
  ADD CONSTRAINT pk_coupon_usage_adjustments PRIMARY KEY (id),
  ADD CONSTRAINT fk_coupon_usage_adjustments_order_coupon_id
    FOREIGN KEY (order_coupon_id) REFERENCES order_coupons_p4(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT uq_coupon_usage_adjustments_idempotency_key
    UNIQUE (idempotency_key),
  ADD CONSTRAINT ck_coupon_usage_adjustments_type
    CHECK (adjustment_type IN ('restore', 'reconsume')),
  ADD CONSTRAINT ck_coupon_usage_adjustments_delta CHECK (
    (adjustment_type = 'restore' AND quantity_delta = -1)
    OR (adjustment_type = 'reconsume' AND quantity_delta = 1)
  ),
  ADD CONSTRAINT ck_coupon_usage_adjustments_reason
    CHECK (BTRIM(reason) <> '');

ALTER TABLE calendar_dates_p4
  ADD CONSTRAINT pk_calendar_dates PRIMARY KEY (calendar_date),
  ADD CONSTRAINT ck_calendar_dates_source CHECK (BTRIM(source_version) <> ''),
  ADD CONSTRAINT ck_calendar_dates_holiday_name
    CHECK (is_holiday OR holiday_name IS NULL);

ALTER TABLE bookings_p4
  ADD CONSTRAINT pk_bookings PRIMARY KEY (id),
  ADD CONSTRAINT fk_bookings_customer_id
    FOREIGN KEY (customer_id) REFERENCES customers(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_bookings_campground_id
    FOREIGN KEY (campground_id) REFERENCES campgrounds(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT ck_bookings_dates CHECK (check_out > check_in),
  ADD CONSTRAINT ck_bookings_guests CHECK (guest_count > 0),
  ADD CONSTRAINT ck_bookings_day_counts CHECK (
    weekday_count >= 0 AND holiday_count >= 0
    AND weekday_count + holiday_count = check_out - check_in
  ),
  ADD CONSTRAINT ck_bookings_money CHECK (
    zone_total >= 0 AND rental_total >= 0 AND applied_discount >= 0
    AND final_amount = GREATEST(zone_total + rental_total - applied_discount, 0)
  );

ALTER TABLE booking_selected_zones_p4
  ADD CONSTRAINT pk_booking_selected_zones PRIMARY KEY (id),
  ADD CONSTRAINT fk_booking_selected_zones_booking_id
    FOREIGN KEY (booking_id) REFERENCES bookings_p4(id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  ADD CONSTRAINT fk_booking_selected_zones_zone_id
    FOREIGN KEY (zone_id) REFERENCES campground_zones(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT ck_booking_selected_zones_quantity CHECK (quantity > 0),
  ADD CONSTRAINT ck_booking_selected_zones_prices CHECK (
    price_weekday_snapshot >= 0 AND price_holiday_snapshot >= 0
  );

ALTER TABLE booking_selected_rentals_p4
  ADD CONSTRAINT pk_booking_selected_rentals PRIMARY KEY (id),
  ADD CONSTRAINT fk_booking_selected_rentals_booking_id
    FOREIGN KEY (booking_id) REFERENCES bookings_p4(id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  ADD CONSTRAINT fk_booking_selected_rentals_rental_listing_id
    FOREIGN KEY (rental_listing_id) REFERENCES rental_listings(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_booking_selected_rentals_rental_sku_variant_id
    FOREIGN KEY (rental_sku_variant_id) REFERENCES rental_sku_variants(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT uq_booking_selected_rentals_id_rental_sku_variant_id
    UNIQUE (id, rental_sku_variant_id),
  ADD CONSTRAINT ck_booking_selected_rentals_quantity CHECK (quantity > 0),
  ADD CONSTRAINT ck_booking_selected_rentals_money CHECK (
    price_weekday_snapshot >= 0 AND price_holiday_snapshot >= 0
    AND discount_snapshot >= 0
  );

ALTER TABLE booking_status_history_p4
  ADD CONSTRAINT pk_booking_status_history PRIMARY KEY (id),
  ADD CONSTRAINT fk_booking_status_history_booking_id
    FOREIGN KEY (booking_id) REFERENCES bookings_p4(id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  ADD CONSTRAINT fk_booking_status_history_actor_id
    FOREIGN KEY (actor_id) REFERENCES admin_users(id)
    ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE product_stock_reservations_p4
  ADD CONSTRAINT pk_product_stock_reservations PRIMARY KEY (id),
  ADD CONSTRAINT fk_product_stock_reservations_order_item_id_variant_id
    FOREIGN KEY (order_item_id, variant_id)
    REFERENCES order_items_p4(id, variant_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_product_stock_reservations_location_id
    FOREIGN KEY (location_id) REFERENCES inventory_locations(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT uq_product_stock_reservations_idempotency_key
    UNIQUE (idempotency_key),
  ADD CONSTRAINT ck_product_stock_reservations_quantity CHECK (quantity > 0),
  ADD CONSTRAINT ck_product_stock_reservations_status CHECK (
    status IN ('active', 'released', 'fulfilled', 'expired')
  ),
  ADD CONSTRAINT ck_product_stock_reservations_expiry CHECK (
    expires_at IS NULL OR expires_at > reserved_at
  ),
  ADD CONSTRAINT ck_product_stock_reservations_terminal CHECK (
    (status = 'active' AND released_at IS NULL AND fulfilled_at IS NULL)
    OR (status IN ('released', 'expired')
        AND released_at IS NOT NULL AND fulfilled_at IS NULL)
    OR (status = 'fulfilled' AND fulfilled_at IS NOT NULL)
  );

ALTER TABLE rental_stock_reservations_p4
  ADD CONSTRAINT pk_rental_stock_reservations PRIMARY KEY (id),
  ADD CONSTRAINT fk_rental_stock_reservations_booking_selected_rental_id_rental_sku_variant_id
    FOREIGN KEY (booking_selected_rental_id, rental_sku_variant_id)
    REFERENCES booking_selected_rentals_p4(id, rental_sku_variant_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_rental_stock_reservations_location_id
    FOREIGN KEY (location_id) REFERENCES inventory_locations(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT uq_rental_stock_reservations_idempotency_key
    UNIQUE (idempotency_key),
  ADD CONSTRAINT ck_rental_stock_reservations_dates CHECK (check_out > check_in),
  ADD CONSTRAINT ck_rental_stock_reservations_quantity CHECK (quantity > 0),
  ADD CONSTRAINT ck_rental_stock_reservations_status
    CHECK (status IN ('active', 'released', 'fulfilled')),
  ADD CONSTRAINT ck_rental_stock_reservations_terminal CHECK (
    (status = 'active' AND released_at IS NULL AND fulfilled_at IS NULL)
    OR (status = 'released' AND released_at IS NOT NULL AND fulfilled_at IS NULL)
    OR (status = 'fulfilled' AND fulfilled_at IS NOT NULL)
  );

-- Move the pre-P4 physical tables and their owned sequences into the audit
-- schema. Existing pre-P6 review FKs deliberately continue to reference the
-- retained legacy order table until the review phase resolves them.
ALTER TABLE order_coupons SET SCHEMA migration;
ALTER TABLE migration.order_coupons RENAME TO p4_legacy_order_coupons;
ALTER SEQUENCE migration.order_coupons_id_seq
  RENAME TO p4_legacy_order_coupons_id_seq;

ALTER TABLE order_history SET SCHEMA migration;
ALTER TABLE migration.order_history RENAME TO p4_legacy_order_history;
ALTER SEQUENCE migration.order_history_id_seq
  RENAME TO p4_legacy_order_history_id_seq;

ALTER TABLE order_items SET SCHEMA migration;
ALTER TABLE migration.order_items RENAME TO p4_legacy_order_items;
ALTER SEQUENCE migration.order_items_id_seq
  RENAME TO p4_legacy_order_items_id_seq;

ALTER TABLE orders SET SCHEMA migration;
ALTER TABLE migration.orders RENAME TO p4_legacy_orders;
ALTER SEQUENCE migration.orders_id_seq RENAME TO p4_legacy_orders_id_seq;

ALTER TABLE coupons SET SCHEMA migration;
ALTER TABLE migration.coupons RENAME TO p4_legacy_coupons;

ALTER TABLE booking_history SET SCHEMA migration;
ALTER TABLE migration.booking_history RENAME TO p4_legacy_booking_history;
ALTER SEQUENCE migration.booking_history_id_seq
  RENAME TO p4_legacy_booking_history_id_seq;

ALTER TABLE booking_selected_rentals SET SCHEMA migration;
ALTER TABLE migration.booking_selected_rentals
  RENAME TO p4_legacy_booking_selected_rentals;
ALTER SEQUENCE migration.booking_selected_rentals_id_seq
  RENAME TO p4_legacy_booking_selected_rentals_id_seq;

ALTER TABLE booking_selected_zones SET SCHEMA migration;
ALTER TABLE migration.booking_selected_zones
  RENAME TO p4_legacy_booking_selected_zones;
ALTER SEQUENCE migration.booking_selected_zones_id_seq
  RENAME TO p4_legacy_booking_selected_zones_id_seq;

ALTER TABLE bookings SET SCHEMA migration;
ALTER TABLE migration.bookings RENAME TO p4_legacy_bookings;
ALTER SEQUENCE migration.bookings_id_seq RENAME TO p4_legacy_bookings_id_seq;

ALTER TABLE orders_p4 RENAME TO orders;
ALTER TABLE order_items_p4 RENAME TO order_items;
ALTER SEQUENCE order_items_p4_id_seq RENAME TO order_items_id_seq;
ALTER TABLE order_status_history_p4 RENAME TO order_status_history;
ALTER SEQUENCE order_status_history_p4_id_seq
  RENAME TO order_status_history_id_seq;
ALTER TABLE coupons_p4 RENAME TO coupons;
ALTER SEQUENCE coupons_p4_id_seq RENAME TO coupons_id_seq;
ALTER TABLE order_coupons_p4 RENAME TO order_coupons;
ALTER SEQUENCE order_coupons_p4_id_seq RENAME TO order_coupons_id_seq;
ALTER TABLE coupon_usage_adjustments_p4 RENAME TO coupon_usage_adjustments;
ALTER SEQUENCE coupon_usage_adjustments_p4_id_seq
  RENAME TO coupon_usage_adjustments_id_seq;
ALTER TABLE calendar_dates_p4 RENAME TO calendar_dates;
ALTER TABLE bookings_p4 RENAME TO bookings;
ALTER TABLE booking_selected_zones_p4 RENAME TO booking_selected_zones;
ALTER SEQUENCE booking_selected_zones_p4_id_seq
  RENAME TO booking_selected_zones_id_seq;
ALTER TABLE booking_selected_rentals_p4 RENAME TO booking_selected_rentals;
ALTER SEQUENCE booking_selected_rentals_p4_id_seq
  RENAME TO booking_selected_rentals_id_seq;
ALTER TABLE booking_status_history_p4 RENAME TO booking_status_history;
ALTER SEQUENCE booking_status_history_p4_id_seq
  RENAME TO booking_status_history_id_seq;
ALTER TABLE product_stock_reservations_p4 RENAME TO product_stock_reservations;
ALTER SEQUENCE product_stock_reservations_p4_id_seq
  RENAME TO product_stock_reservations_id_seq;
ALTER TABLE rental_stock_reservations_p4 RENAME TO rental_stock_reservations;
ALTER SEQUENCE rental_stock_reservations_p4_id_seq
  RENAME TO rental_stock_reservations_id_seq;

CREATE INDEX idx_orders_customer_placed ON orders(customer_id, placed_at);
CREATE INDEX idx_orders_status_payment ON orders(status, payment_status);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);
CREATE INDEX idx_order_items_variant ON order_items(variant_id);
CREATE INDEX idx_order_status_history_order_time
  ON order_status_history(order_id, occurred_at);
CREATE INDEX idx_order_status_history_actor
  ON order_status_history(actor_id);
CREATE INDEX idx_coupons_status_validity
  ON coupons(status, valid_from, valid_until);
CREATE INDEX idx_order_coupons_coupon ON order_coupons(coupon_id);
CREATE INDEX idx_coupon_usage_adjustments_order_coupon_time
  ON coupon_usage_adjustments(order_coupon_id, created_at);
CREATE INDEX idx_calendar_dates_holiday_date
  ON calendar_dates(is_holiday, calendar_date);
CREATE INDEX idx_bookings_customer_created ON bookings(customer_id, created_at);
CREATE INDEX idx_bookings_campground_dates
  ON bookings(campground_id, check_in, check_out);
CREATE INDEX idx_booking_selected_zones_booking
  ON booking_selected_zones(booking_id);
CREATE INDEX idx_booking_selected_zones_zone ON booking_selected_zones(zone_id);
CREATE INDEX idx_booking_selected_rentals_booking
  ON booking_selected_rentals(booking_id);
CREATE INDEX idx_booking_selected_rentals_listing
  ON booking_selected_rentals(rental_listing_id);
CREATE INDEX idx_booking_selected_rentals_variant
  ON booking_selected_rentals(rental_sku_variant_id);
CREATE INDEX idx_booking_status_history_booking_time
  ON booking_status_history(booking_id, occurred_at);
CREATE INDEX idx_booking_status_history_actor
  ON booking_status_history(actor_id);
CREATE INDEX idx_product_stock_reservations_order_item
  ON product_stock_reservations(order_item_id);
CREATE INDEX idx_product_stock_reservations_order_item_variant
  ON product_stock_reservations(order_item_id, variant_id);
CREATE INDEX idx_product_stock_reservations_location
  ON product_stock_reservations(location_id);
CREATE INDEX idx_product_stock_reservations_active_lookup
  ON product_stock_reservations(variant_id, location_id)
  WHERE status = 'active';
CREATE INDEX idx_product_stock_reservations_expiry
  ON product_stock_reservations(expires_at)
  WHERE status = 'active' AND expires_at IS NOT NULL;
CREATE INDEX idx_rental_stock_reservations_booking_item
  ON rental_stock_reservations(booking_selected_rental_id);
CREATE INDEX idx_rental_stock_reservations_booking_item_variant
  ON rental_stock_reservations(
    booking_selected_rental_id, rental_sku_variant_id
  );
CREATE INDEX idx_rental_stock_reservations_location
  ON rental_stock_reservations(location_id);
CREATE INDEX idx_rental_stock_reservations_active_range
  ON rental_stock_reservations(
    rental_sku_variant_id, location_id, check_in, check_out
  ) WHERE status = 'active';

CREATE VIEW coupon_usage_stats AS
WITH recognized AS (
  SELECT usage.coupon_id, count(*)::BIGINT AS quantity
  FROM order_coupons usage
  JOIN orders orders ON orders.id = usage.order_id
  WHERE usage.coupon_id IS NOT NULL
    AND orders.payment_status = 'paid'
    AND orders.status IN ('unshipped', 'shipped', 'completed')
  GROUP BY usage.coupon_id
), adjustments AS (
  SELECT usage.coupon_id,
         COALESCE(sum(adjustment.quantity_delta), 0)::BIGINT AS quantity
  FROM coupon_usage_adjustments adjustment
  JOIN order_coupons usage ON usage.id = adjustment.order_coupon_id
  WHERE usage.coupon_id IS NOT NULL
  GROUP BY usage.coupon_id
)
SELECT coupon.id AS coupon_id,
       (COALESCE(recognized.quantity, 0)
        + COALESCE(adjustments.quantity, 0))::BIGINT AS used_quantity,
       (coupon.issue_quantity
        - COALESCE(recognized.quantity, 0)
        - COALESCE(adjustments.quantity, 0))::BIGINT AS remaining_quantity
FROM coupons coupon
LEFT JOIN recognized ON recognized.coupon_id = coupon.id
LEFT JOIN adjustments ON adjustments.coupon_id = coupon.id;

CREATE VIEW customer_spending_summary AS
SELECT orders.customer_id,
       sum(orders.total)::NUMERIC(14, 2) AS total_spent
FROM orders
WHERE orders.payment_status = 'paid'
  AND orders.status = 'completed'
  AND orders.refund_status = 'none'
GROUP BY orders.customer_id;

CREATE VIEW customer_tier_summary AS
SELECT spending.customer_id,
       spending.total_spent,
       CASE
         WHEN spending.total_spent >= 28000 THEN 'master'
         WHEN spending.total_spent >= 12000 THEN 'guide'
         ELSE 'explorer'
       END::VARCHAR(16) AS tier_code,
       CASE
         WHEN spending.total_spent >= 28000 THEN '大師'
         WHEN spending.total_spent >= 12000 THEN '嚮導'
         ELSE '探險家'
       END::VARCHAR(32) AS tier_name
FROM customer_spending_summary spending;

CREATE OR REPLACE VIEW product_stock_summary AS
WITH stock AS (
  SELECT variant.product_id,
         COALESCE(sum(inventory.on_hand_quantity), 0)::BIGINT AS total_on_hand
  FROM product_variants variant
  LEFT JOIN inventory_stocks inventory ON inventory.variant_id = variant.id
  GROUP BY variant.product_id
), reserved AS (
  SELECT variant.product_id,
         COALESCE(sum(reservation.quantity), 0)::BIGINT AS total_reserved
  FROM product_stock_reservations reservation
  JOIN product_variants variant ON variant.id = reservation.variant_id
  WHERE reservation.status = 'active'
  GROUP BY variant.product_id
)
SELECT product.id AS product_id,
       COALESCE(stock.total_on_hand, 0)::BIGINT AS total_on_hand,
       COALESCE(reserved.total_reserved, 0)::BIGINT AS total_reserved,
       (COALESCE(stock.total_on_hand, 0)
        - COALESCE(reserved.total_reserved, 0))::BIGINT AS total_available
FROM products product
LEFT JOIN stock ON stock.product_id = product.id
LEFT JOIN reserved ON reserved.product_id = product.id;

COMMENT ON VIEW coupon_usage_stats IS
  'P4 authoritative paid-order coupon use plus idempotent adjustment ledger; values are never silently clamped.';
COMMENT ON VIEW customer_spending_summary IS
  'P4 completed, paid and non-refunded order totals by customer.';
COMMENT ON VIEW customer_tier_summary IS
  'P4 D-001 derived explorer/guide/master tier; never persisted to customer rows.';
COMMENT ON VIEW product_stock_summary IS
  'P4 physical product stock minus active product reservation ledger.';
