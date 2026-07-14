-- P5 contract: reconcile every source row, install normalized constraints,
-- switch public names, and expose read-only compatibility/availability APIs.

DO $$
BEGIN
  IF (SELECT count(*) FROM booking_policies_p5) <> 1
     OR NOT EXISTS (
       SELECT 1
       FROM booking_policies_p5 policy
       JOIN migration.p5_policy_source source ON source.id = policy.id
       WHERE policy.id = 1
         AND policy.booking_window_days = (source.payload->>'bookingWindowDays')::integer
         AND policy.advance_days = (source.payload->>'minLeadDays')::integer
         AND policy.max_nights = (source.payload->>'maxStayNights')::integer
         AND policy.timezone = source.payload->>'timezone'
         AND policy.date_boundary_hour = 0
         AND policy.low_availability_threshold =
             round((source.payload#>>'{availabilityStatus,lowThresholdRatio}')::numeric * 100)
     ) THEN
    RAISE EXCEPTION 'P5 guard: booking policy differs from source';
  END IF;

  IF (SELECT count(*) FROM booking_policy_occupying_statuses) <> 3
     OR EXISTS (
       SELECT source_status.value #>> '{}'
       FROM migration.p5_policy_source source
       CROSS JOIN LATERAL jsonb_array_elements(source.payload->'occupyingStatuses') source_status(value)
       EXCEPT
       SELECT status FROM booking_policy_occupying_statuses
     ) THEN
    RAISE EXCEPTION 'P5 guard: occupying statuses differ from source';
  END IF;

  IF (SELECT count(*) FROM booking_policy_availability_statuses) <> 5
     OR EXISTS (
       SELECT expected.status
       FROM (VALUES ('available'), ('low'), ('full'), ('closed'), ('out_of_window')) expected(status)
       EXCEPT SELECT status FROM booking_policy_availability_statuses
     ) THEN
    RAISE EXCEPTION 'P5 guard: availability status contract differs';
  END IF;

  IF (SELECT count(*) FROM zone_blocks_p5) <> 2
     OR (SELECT count(*) FROM campground_closures_p5) <> 2
     OR EXISTS (
       SELECT 1
       FROM migration.p5_zone_block_source source
       LEFT JOIN zone_blocks_p5 block ON block.legacy_block_id = source.legacy_id
       WHERE block.id IS NULL
          OR block.campground_id <> source.payload->>'campgroundId'
          OR block.zone_id <> source.payload->>'zoneId'
          OR block.start_date <> (source.payload->>'startDate')::date
          OR block.end_date <> (source.payload->>'endDate')::date
          OR block.blocked_quantity <> (source.payload->>'blockedSites')::integer
     ) OR EXISTS (
       SELECT 1
       FROM migration.p5_closure_source source
       LEFT JOIN campground_closures_p5 closure ON closure.legacy_closure_id = source.legacy_id
       WHERE closure.id IS NULL
          OR closure.campground_id <> source.payload->>'campgroundId'
          OR closure.closure_type <> source.payload->>'type'
          OR closure.start_date IS DISTINCT FROM (source.payload->>'startDate')::date
          OR closure.end_date IS DISTINCT FROM (source.payload->>'endDate')::date
          OR closure.weekday IS DISTINCT FROM (source.payload->>'dayOfWeek')::smallint
          OR closure.effective_from IS DISTINCT FROM (source.payload->>'effectiveFrom')::date
          OR closure.effective_to IS DISTINCT FROM (source.payload->>'effectiveTo')::date
     ) THEN
    RAISE EXCEPTION 'P5 guard: block or closure differs from source';
  END IF;

  IF (SELECT count(*) FROM product_variant_min_stocks) <> 156
     OR (SELECT count(*) FROM rental_sku_variant_min_stocks) <> 333
     OR EXISTS (
       SELECT 1
       FROM migration.p5_min_stock_source source
       JOIN product_variants variant ON variant.product_id = source.target_id
       LEFT JOIN product_variant_min_stocks minimum
         ON minimum.variant_id = variant.id AND minimum.location_id = source.location_id
       WHERE source.inventory_domain = 'store'
         AND (minimum.variant_id IS NULL
              OR minimum.minimum_quantity <> source.minimum_quantity)
     ) OR EXISTS (
       SELECT 1
       FROM migration.p5_min_stock_source source
       JOIN rental_sku_variants variant ON variant.rental_sku_id = source.target_id
       LEFT JOIN rental_sku_variant_min_stocks minimum
         ON minimum.rental_sku_variant_id = variant.id
        AND minimum.location_id = source.location_id
       WHERE source.inventory_domain = 'rental'
         AND (minimum.rental_sku_variant_id IS NULL
              OR minimum.minimum_quantity <> source.minimum_quantity)
     ) THEN
    RAISE EXCEPTION 'P5 guard: expanded minimum stock differs from source';
  END IF;

  IF (SELECT count(*) FROM migration.p5_movement_source) <> 100
     OR (SELECT count(*) FROM movement_migration_map) <> 141
     OR (SELECT count(*) FROM store_inventory_movement_items) <> 65
     OR (SELECT count(*) FROM rental_inventory_movement_items) <> 44
     OR (SELECT count(*) FROM inventory_conversions) <> 31
     OR (SELECT count(*) FROM movement_migration_map WHERE quarantine_reason IS NOT NULL) <> 1
     OR NOT EXISTS (
       SELECT 1 FROM movement_migration_map
       WHERE legacy_movement_id = '97' AND legacy_item_ordinal = 0
         AND quarantine_reason LIKE 'NO_RENTAL_VARIANT:%'
     ) OR EXISTS (
       SELECT 1 FROM movement_migration_map
       WHERE num_nonnulls(store_item_id, rental_item_id, conversion_id, quarantine_reason) <> 1
     ) OR EXISTS (
       SELECT source.legacy_movement_id, item.ordinal::integer
       FROM migration.p5_movement_source source
       CROSS JOIN LATERAL jsonb_array_elements(source.payload->'items')
         WITH ORDINALITY item(payload, ordinal)
       EXCEPT
       SELECT legacy_movement_id, legacy_item_ordinal + 1 FROM movement_migration_map
     ) THEN
    RAISE EXCEPTION 'P5 guard: movement disposition is incomplete or duplicated';
  END IF;

  IF (SELECT count(*) FROM migration.p5_variant_resolution) <> 141
     OR EXISTS (
       SELECT 1 FROM migration.p5_variant_resolution
       WHERE resolution_method <> 'EXACT_PRODUCT_AND_VARIANT_LABEL'
          OR disposition_status NOT IN ('RESOLVED', 'APPROVED_QUARANTINE_NO_RENTAL_VARIANT')
     ) OR EXISTS (
       SELECT 1 FROM migration.p5_location_resolution
       WHERE disposition_status NOT IN ('RESOLVED', 'RESOLVED_NULL')
     ) THEN
    RAISE EXCEPTION 'P5 guard: a guessed or unresolved variant/location remains';
  END IF;

  IF EXISTS (
    SELECT 1 FROM inventory_movements movement
    LEFT JOIN inventory_locations source ON source.id = movement.source_location_id
    LEFT JOIN inventory_locations destination ON destination.id = movement.destination_location_id
    WHERE (source.id IS NOT NULL AND source.inventory_domain <> movement.inventory_domain)
       OR (destination.id IS NOT NULL AND destination.inventory_domain <> movement.inventory_domain)
  ) THEN
    RAISE EXCEPTION 'P5 guard: movement references a location in another domain';
  END IF;
END $$;

ALTER TABLE booking_policies_p5
  ADD CONSTRAINT pk_booking_policies PRIMARY KEY (id),
  ADD CONSTRAINT ck_booking_policies_singleton CHECK (id = 1),
  ADD CONSTRAINT ck_booking_policies_ranges CHECK (
    booking_window_days > 0 AND advance_days >= 0 AND max_nights > 0
    AND date_boundary_hour BETWEEN 0 AND 23
    AND low_availability_threshold BETWEEN 0 AND 100
  ),
  ADD CONSTRAINT ck_booking_policies_timezone CHECK (timezone = 'Asia/Taipei');

ALTER TABLE booking_policy_occupying_statuses
  ADD CONSTRAINT pk_booking_policy_occupying_statuses PRIMARY KEY (policy_id, status),
  ADD CONSTRAINT fk_booking_policy_occupying_statuses_policy_id
    FOREIGN KEY (policy_id) REFERENCES booking_policies_p5(id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  ADD CONSTRAINT ck_booking_policy_occupying_statuses_status CHECK (BTRIM(status) <> '');
CREATE INDEX idx_booking_policy_occupying_statuses_status
  ON booking_policy_occupying_statuses(status);

ALTER TABLE booking_policy_availability_statuses
  ADD CONSTRAINT pk_booking_policy_availability_statuses PRIMARY KEY (policy_id, status),
  ADD CONSTRAINT fk_booking_policy_availability_statuses_policy_id
    FOREIGN KEY (policy_id) REFERENCES booking_policies_p5(id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  ADD CONSTRAINT ck_booking_policy_availability_statuses_status CHECK (BTRIM(status) <> '');
CREATE INDEX idx_booking_policy_availability_statuses_status
  ON booking_policy_availability_statuses(status);

ALTER TABLE zone_blocks_p5
  ADD CONSTRAINT pk_zone_blocks PRIMARY KEY (id),
  ADD CONSTRAINT uq_zone_blocks_legacy_block_id UNIQUE (legacy_block_id),
  ADD CONSTRAINT fk_zone_blocks_campground_id_zone_id
    FOREIGN KEY (campground_id, zone_id) REFERENCES campground_zones(campground_id, id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_zone_blocks_created_by
    FOREIGN KEY (created_by) REFERENCES admin_users(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT ck_zone_blocks_dates CHECK (end_date >= start_date),
  ADD CONSTRAINT ck_zone_blocks_quantity CHECK (blocked_quantity > 0),
  ADD CONSTRAINT ck_zone_blocks_reason CHECK (BTRIM(reason) <> '');

ALTER TABLE campground_closures_p5
  ADD CONSTRAINT pk_campground_closures PRIMARY KEY (id),
  ADD CONSTRAINT uq_campground_closures_legacy_closure_id UNIQUE (legacy_closure_id),
  ADD CONSTRAINT fk_campground_closures_campground_id
    FOREIGN KEY (campground_id) REFERENCES campgrounds(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_campground_closures_created_by
    FOREIGN KEY (created_by) REFERENCES admin_users(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT ck_campground_closures_type
    CHECK (closure_type IN ('date_range', 'weekly')),
  ADD CONSTRAINT ck_campground_closures_payload CHECK (
    (closure_type = 'date_range'
      AND start_date IS NOT NULL AND end_date IS NOT NULL AND end_date >= start_date
      AND weekday IS NULL AND effective_from IS NULL AND effective_to IS NULL)
    OR
    (closure_type = 'weekly'
      AND start_date IS NULL AND end_date IS NULL AND weekday BETWEEN 0 AND 6
      AND effective_from IS NOT NULL AND effective_to IS NOT NULL
      AND effective_to >= effective_from)
  ),
  ADD CONSTRAINT ck_campground_closures_reason CHECK (BTRIM(reason) <> '');

ALTER TABLE product_variant_min_stocks
  ADD CONSTRAINT pk_product_variant_min_stocks PRIMARY KEY (variant_id, location_id),
  ADD CONSTRAINT fk_product_variant_min_stocks_variant_id
    FOREIGN KEY (variant_id) REFERENCES product_variants(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_product_variant_min_stocks_location_id
    FOREIGN KEY (location_id) REFERENCES inventory_locations(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT ck_product_variant_min_stocks_quantity CHECK (minimum_quantity >= 0);

ALTER TABLE rental_sku_variant_min_stocks
  ADD CONSTRAINT pk_rental_sku_variant_min_stocks
    PRIMARY KEY (rental_sku_variant_id, location_id),
  ADD CONSTRAINT fk_rental_sku_variant_min_stocks_rental_sku_variant_id
    FOREIGN KEY (rental_sku_variant_id) REFERENCES rental_sku_variants(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_rental_sku_variant_min_stocks_location_id
    FOREIGN KEY (location_id) REFERENCES inventory_locations(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT ck_rental_sku_variant_min_stocks_quantity CHECK (minimum_quantity >= 0);

ALTER TABLE inventory_movements
  ADD CONSTRAINT pk_inventory_movements PRIMARY KEY (id),
  ADD CONSTRAINT uq_inventory_movements_movement_no UNIQUE (movement_no),
  ADD CONSTRAINT uq_inventory_movements_id_inventory_domain UNIQUE (id, inventory_domain),
  ADD CONSTRAINT fk_inventory_movements_source_location_domain
    FOREIGN KEY (source_location_id, inventory_domain)
    REFERENCES inventory_locations(id, inventory_domain)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_inventory_movements_destination_location_domain
    FOREIGN KEY (destination_location_id, inventory_domain)
    REFERENCES inventory_locations(id, inventory_domain)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_inventory_movements_employee_id
    FOREIGN KEY (employee_id) REFERENCES admin_users(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT ck_inventory_movements_domain CHECK (inventory_domain IN ('store', 'rental')),
  ADD CONSTRAINT ck_inventory_movements_status CHECK (status IN ('draft', 'posted', 'cancelled')),
  ADD CONSTRAINT ck_inventory_movements_type CHECK (BTRIM(movement_type) <> ''),
  ADD CONSTRAINT ck_inventory_movements_type_payload CHECK (
    (movement_type IN ('進貨', 'receipt', 'adjustment_in')
      AND source_location_id IS NULL AND destination_location_id IS NOT NULL)
    OR
    (movement_type IN ('損耗', 'write_off', 'adjustment_out')
      AND source_location_id IS NOT NULL AND destination_location_id IS NULL)
    OR
    (movement_type IN ('移轉', '營地互轉', 'transfer')
      AND source_location_id IS NOT NULL AND destination_location_id IS NOT NULL
      AND source_location_id <> destination_location_id)
    OR
    (movement_type = 'conversion_out'
      AND inventory_domain = 'store'
      AND source_location_id IS NOT NULL AND destination_location_id IS NULL)
    OR
    (movement_type = 'conversion_in'
      AND inventory_domain = 'rental'
      AND source_location_id IS NULL AND destination_location_id IS NOT NULL)
  ),
  ADD CONSTRAINT ck_inventory_movements_reason CHECK (BTRIM(reason) <> ''),
  ADD CONSTRAINT ck_inventory_movements_locations
    CHECK (source_location_id IS NOT NULL OR destination_location_id IS NOT NULL),
  ADD CONSTRAINT ck_inventory_movements_posting CHECK (
    (status = 'posted' AND posted_at IS NOT NULL)
    OR (status IN ('draft', 'cancelled') AND posted_at IS NULL)
  );

ALTER TABLE store_inventory_movement_items
  ADD CONSTRAINT pk_store_inventory_movement_items PRIMARY KEY (id),
  ADD CONSTRAINT fk_store_inventory_movement_items_movement_id_inventory_domain
    FOREIGN KEY (movement_id, inventory_domain)
    REFERENCES inventory_movements(id, inventory_domain)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_store_inventory_movement_items_variant_id
    FOREIGN KEY (variant_id) REFERENCES product_variants(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT ck_store_inventory_movement_items_domain CHECK (inventory_domain = 'store'),
  ADD CONSTRAINT ck_store_inventory_movement_items_quantity CHECK (quantity > 0);

ALTER TABLE rental_inventory_movement_items
  ADD CONSTRAINT pk_rental_inventory_movement_items PRIMARY KEY (id),
  ADD CONSTRAINT fk_rental_inventory_movement_items_movement_id_inventory_domain
    FOREIGN KEY (movement_id, inventory_domain)
    REFERENCES inventory_movements(id, inventory_domain)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_rental_inventory_movement_items_rental_sku_variant_id
    FOREIGN KEY (rental_sku_variant_id) REFERENCES rental_sku_variants(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT ck_rental_inventory_movement_items_domain CHECK (inventory_domain = 'rental'),
  ADD CONSTRAINT ck_rental_inventory_movement_items_quantity CHECK (quantity > 0);

ALTER TABLE inventory_conversions
  ADD CONSTRAINT pk_inventory_conversions PRIMARY KEY (id),
  ADD CONSTRAINT fk_inventory_conversions_source_movement_id
    FOREIGN KEY (source_movement_id) REFERENCES inventory_movements(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_inventory_conversions_destination_movement_id
    FOREIGN KEY (destination_movement_id) REFERENCES inventory_movements(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_inventory_conversions_source_variant_id
    FOREIGN KEY (source_variant_id) REFERENCES product_variants(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_inventory_conversions_destination_rental_variant_id
    FOREIGN KEY (destination_rental_variant_id) REFERENCES rental_sku_variants(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_inventory_conversions_source_location_id
    FOREIGN KEY (source_location_id) REFERENCES inventory_locations(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_inventory_conversions_destination_location_id
    FOREIGN KEY (destination_location_id) REFERENCES inventory_locations(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT uq_inventory_conversions_source_destination
    UNIQUE (source_movement_id, destination_movement_id),
  ADD CONSTRAINT uq_inventory_conversions_idempotency_key UNIQUE (idempotency_key),
  ADD CONSTRAINT ck_inventory_conversions_quantity CHECK (quantity > 0),
  ADD CONSTRAINT ck_inventory_conversions_different_movements
    CHECK (source_movement_id <> destination_movement_id);

ALTER TABLE movement_migration_map
  ADD CONSTRAINT pk_movement_migration_map
    PRIMARY KEY (legacy_movement_id, legacy_item_ordinal),
  ADD CONSTRAINT fk_movement_migration_map_store_item_id
    FOREIGN KEY (store_item_id) REFERENCES store_inventory_movement_items(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_movement_migration_map_rental_item_id
    FOREIGN KEY (rental_item_id) REFERENCES rental_inventory_movement_items(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_movement_migration_map_conversion_id
    FOREIGN KEY (conversion_id) REFERENCES inventory_conversions(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT ck_movement_migration_map_ordinal CHECK (legacy_item_ordinal >= 0),
  ADD CONSTRAINT ck_movement_migration_map_exactly_one CHECK (
    num_nonnulls(store_item_id, rental_item_id, conversion_id, quarantine_reason) = 1
  );

ALTER TABLE product_stock_reservations
  DROP CONSTRAINT fk_product_stock_reservations_location_id,
  ADD CONSTRAINT ck_product_stock_reservations_domain CHECK (inventory_domain = 'store'),
  ADD CONSTRAINT fk_product_stock_reservations_location_domain
    FOREIGN KEY (location_id, inventory_domain)
    REFERENCES inventory_locations(id, inventory_domain)
    ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE rental_stock_reservations
  DROP CONSTRAINT fk_rental_stock_reservations_location_id,
  ADD CONSTRAINT ck_rental_stock_reservations_domain CHECK (inventory_domain = 'rental'),
  ADD CONSTRAINT fk_rental_stock_reservations_location_domain
    FOREIGN KEY (location_id, inventory_domain)
    REFERENCES inventory_locations(id, inventory_domain)
    ON UPDATE CASCADE ON DELETE RESTRICT;

-- Archive the P0 physical sources only after all reconciliation guards pass.
ALTER TABLE booking_policies SET SCHEMA migration;
ALTER TABLE migration.booking_policies RENAME TO p5_legacy_booking_policies;
ALTER SEQUENCE migration.booking_policies_id_seq RENAME TO p5_legacy_booking_policies_id_seq;

ALTER TABLE zone_blocks SET SCHEMA migration;
ALTER TABLE migration.zone_blocks RENAME TO p5_legacy_zone_blocks;

ALTER TABLE campground_closures SET SCHEMA migration;
ALTER TABLE migration.campground_closures RENAME TO p5_legacy_campground_closures;

ALTER TABLE min_stocks SET SCHEMA migration;
ALTER TABLE migration.min_stocks RENAME TO p5_legacy_min_stocks;
ALTER SEQUENCE migration.min_stocks_id_seq RENAME TO p5_legacy_min_stocks_id_seq;

ALTER TABLE movement_items SET SCHEMA migration;
ALTER TABLE migration.movement_items RENAME TO p5_legacy_movement_items;
ALTER SEQUENCE migration.movement_items_id_seq RENAME TO p5_legacy_movement_items_id_seq;

ALTER TABLE movements SET SCHEMA migration;
ALTER TABLE migration.movements RENAME TO p5_legacy_movements;
ALTER SEQUENCE migration.movements_id_seq RENAME TO p5_legacy_movements_id_seq;

ALTER TABLE booking_policies_p5 RENAME TO booking_policies;
ALTER TABLE zone_blocks_p5 RENAME TO zone_blocks;
ALTER SEQUENCE zone_blocks_p5_id_seq RENAME TO zone_blocks_id_seq;
ALTER TABLE campground_closures_p5 RENAME TO campground_closures;
ALTER SEQUENCE campground_closures_p5_id_seq RENAME TO campground_closures_id_seq;

CREATE INDEX idx_zone_blocks_zone_dates
  ON zone_blocks(campground_id, zone_id, start_date, end_date);
CREATE INDEX idx_zone_blocks_created_by ON zone_blocks(created_by);
CREATE INDEX idx_campground_closures_campground_dates
  ON campground_closures(campground_id, start_date, end_date);
CREATE INDEX idx_campground_closures_campground_weekday
  ON campground_closures(campground_id, weekday);
CREATE INDEX idx_campground_closures_created_by ON campground_closures(created_by);
CREATE INDEX idx_product_variant_min_stocks_location
  ON product_variant_min_stocks(location_id);
CREATE INDEX idx_rental_sku_variant_min_stocks_location
  ON rental_sku_variant_min_stocks(location_id);
CREATE INDEX idx_inventory_movements_domain_status_time
  ON inventory_movements(inventory_domain, status, occurred_at);
CREATE INDEX idx_inventory_movements_source_domain
  ON inventory_movements(source_location_id, inventory_domain);
CREATE INDEX idx_inventory_movements_destination_domain
  ON inventory_movements(destination_location_id, inventory_domain);
CREATE INDEX idx_inventory_movements_employee ON inventory_movements(employee_id);
CREATE INDEX idx_inventory_movements_legacy ON inventory_movements(legacy_movement_id);
CREATE INDEX idx_store_inventory_movement_items_movement
  ON store_inventory_movement_items(movement_id, inventory_domain);
CREATE INDEX idx_store_inventory_movement_items_variant
  ON store_inventory_movement_items(variant_id);
CREATE INDEX idx_rental_inventory_movement_items_movement
  ON rental_inventory_movement_items(movement_id, inventory_domain);
CREATE INDEX idx_rental_inventory_movement_items_variant
  ON rental_inventory_movement_items(rental_sku_variant_id);
CREATE INDEX idx_inventory_conversions_source_variant
  ON inventory_conversions(source_variant_id);
CREATE INDEX idx_inventory_conversions_destination_movement
  ON inventory_conversions(destination_movement_id);
CREATE INDEX idx_inventory_conversions_destination_variant
  ON inventory_conversions(destination_rental_variant_id);
CREATE INDEX idx_inventory_conversions_source_location
  ON inventory_conversions(source_location_id);
CREATE INDEX idx_inventory_conversions_destination_location
  ON inventory_conversions(destination_location_id);
CREATE INDEX idx_movement_migration_map_store_item
  ON movement_migration_map(store_item_id);
CREATE INDEX idx_movement_migration_map_rental_item
  ON movement_migration_map(rental_item_id);
CREATE INDEX idx_movement_migration_map_conversion
  ON movement_migration_map(conversion_id);
CREATE INDEX idx_product_stock_reservations_location_domain
  ON product_stock_reservations(location_id, inventory_domain);
CREATE INDEX idx_rental_stock_reservations_location_domain
  ON rental_stock_reservations(location_id, inventory_domain);

CREATE VIEW inventory_movement_items_view AS
SELECT item.id, item.movement_id, item.inventory_domain,
       item.variant_id, item.sku_snapshot, item.item_name_snapshot, item.quantity
FROM store_inventory_movement_items item
UNION ALL
SELECT item.id, item.movement_id, item.inventory_domain,
       item.rental_sku_variant_id AS variant_id,
       item.sku_snapshot, item.item_name_snapshot, item.quantity
FROM rental_inventory_movement_items item;

CREATE VIEW booking_policy_compatibility AS
SELECT jsonb_build_object(
  'bookingWindowDays', policy.booking_window_days,
  'minLeadDays', policy.advance_days,
  'maxStayNights', policy.max_nights,
  'timezone', policy.timezone,
  'occupyingStatuses', (
    SELECT jsonb_agg(status ORDER BY CASE status
      WHEN 'pending' THEN 1 WHEN 'confirmed' THEN 2 WHEN 'completed' THEN 3 ELSE 99 END)
    FROM booking_policy_occupying_statuses WHERE policy_id = policy.id
  ),
  'dateRule', jsonb_build_object(
    'checkInInclusive', TRUE, 'checkOutExclusive', TRUE
  ),
  'availabilityStatus', jsonb_build_object(
    'lowThresholdRatio', policy.low_availability_threshold / 100.0
  )
) AS policy
FROM booking_policies policy;

CREATE VIEW zone_blocks_compatibility AS
SELECT legacy_block_id AS id, campground_id AS "campgroundId", zone_id AS "zoneId",
       start_date AS "startDate", end_date AS "endDate",
       blocked_quantity AS "blockedSites", reason,
       created_by AS "createdBy", created_at AS "createdAt"
FROM zone_blocks;

CREATE VIEW campground_closures_compatibility AS
SELECT legacy_closure_id AS id, campground_id AS "campgroundId",
       closure_type AS type, start_date AS "startDate", end_date AS "endDate",
       weekday AS "dayOfWeek", effective_from AS "effectiveFrom",
       effective_to AS "effectiveTo", reason,
       created_by AS "createdBy", created_at AS "createdAt"
FROM campground_closures;

CREATE FUNCTION get_zone_availability(
  p_from DATE,
  p_to DATE,
  p_campground_id VARCHAR(32) DEFAULT NULL,
  p_zone_id VARCHAR(32) DEFAULT NULL
)
RETURNS TABLE (
  zone_id VARCHAR(32),
  stay_date DATE,
  total_sites INTEGER,
  booked_quantity BIGINT,
  blocked_quantity BIGINT,
  available_quantity BIGINT,
  is_closed BOOLEAN
)
LANGUAGE sql
STABLE
AS $$
  WITH dates AS (
    SELECT day_value::date AS stay_date
    FROM generate_series(p_from, p_to, interval '1 day') day_value
    WHERE p_to >= p_from
  ), candidates AS (
    SELECT zone.id AS zone_id, zone.campground_id, zone.total_sites, dates.stay_date
    FROM campground_zones zone
    CROSS JOIN dates
    WHERE (p_campground_id IS NULL OR zone.campground_id = p_campground_id)
      AND (p_zone_id IS NULL OR zone.id = p_zone_id)
  )
  SELECT candidate.zone_id, candidate.stay_date, candidate.total_sites,
         CASE WHEN closure.is_closed THEN 0::bigint
              ELSE occupied.booked_quantity END AS booked_quantity,
         CASE WHEN closure.is_closed THEN 0::bigint
              ELSE blocked.blocked_quantity END AS blocked_quantity,
         CASE WHEN closure.is_closed THEN 0::bigint
              ELSE greatest(
                candidate.total_sites::bigint
                - occupied.booked_quantity - blocked.blocked_quantity,
                0::bigint
              )
          END AS available_quantity,
          closure.is_closed
  FROM candidates candidate
  CROSS JOIN LATERAL (
    SELECT coalesce(sum(selected.quantity), 0)::bigint AS booked_quantity
    FROM bookings booking
    JOIN booking_selected_zones selected ON selected.booking_id = booking.id
    JOIN booking_policy_occupying_statuses status
      ON status.policy_id = 1 AND status.status = booking.status
    WHERE selected.zone_id = candidate.zone_id
      AND candidate.stay_date >= booking.check_in
      AND candidate.stay_date < booking.check_out
  ) occupied
  CROSS JOIN LATERAL (
    SELECT coalesce(sum(block.blocked_quantity), 0)::bigint AS blocked_quantity
    FROM zone_blocks block
    WHERE block.zone_id = candidate.zone_id
      AND block.campground_id = candidate.campground_id
      AND candidate.stay_date >= block.start_date
      AND candidate.stay_date < block.end_date
  ) blocked
  CROSS JOIN LATERAL (
    SELECT EXISTS (
      SELECT 1 FROM campground_closures value
      WHERE value.campground_id = candidate.campground_id
        AND (
          (value.closure_type = 'date_range'
            AND candidate.stay_date >= value.start_date
            AND candidate.stay_date < value.end_date)
          OR
          (value.closure_type = 'weekly'
            AND extract(dow FROM candidate.stay_date)::smallint = value.weekday
            AND candidate.stay_date BETWEEN value.effective_from AND value.effective_to)
        )
    ) AS is_closed
  ) closure
  ORDER BY candidate.zone_id, candidate.stay_date
$$;

CREATE FUNCTION enforce_inventory_conversion_domains()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  source_domain VARCHAR(16);
  destination_domain VARCHAR(16);
  source_location_domain VARCHAR(16);
  destination_location_domain VARCHAR(16);
BEGIN
  SELECT inventory_domain INTO source_domain
  FROM inventory_movements WHERE id = NEW.source_movement_id;
  SELECT inventory_domain INTO destination_domain
  FROM inventory_movements WHERE id = NEW.destination_movement_id;
  SELECT inventory_domain INTO source_location_domain
  FROM inventory_locations WHERE id = NEW.source_location_id;
  SELECT inventory_domain INTO destination_location_domain
  FROM inventory_locations WHERE id = NEW.destination_location_id;
  IF source_domain <> 'store' OR destination_domain <> 'rental'
     OR source_location_domain <> 'store' OR destination_location_domain <> 'rental' THEN
    RAISE EXCEPTION 'inventory conversion must be store -> rental'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END
$$;

CREATE CONSTRAINT TRIGGER trg_inventory_conversions_domains
AFTER INSERT OR UPDATE ON inventory_conversions
DEFERRABLE INITIALLY IMMEDIATE
FOR EACH ROW EXECUTE FUNCTION enforce_inventory_conversion_domains();

CREATE FUNCTION protect_inventory_movement_header()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.status <> 'draft' THEN
      RAISE EXCEPTION 'posted or cancelled inventory movement is immutable'
        USING ERRCODE = '55000';
    END IF;
    RETURN OLD;
  END IF;
  IF OLD.status IN ('posted', 'cancelled') THEN
    RAISE EXCEPTION 'posted or cancelled inventory movement is immutable'
      USING ERRCODE = '55000';
  END IF;
  IF NEW.status NOT IN ('draft', 'posted', 'cancelled') THEN
    RAISE EXCEPTION 'invalid inventory movement transition'
      USING ERRCODE = '23514';
  END IF;
  IF NEW.status = 'posted' AND NOT EXISTS (
    SELECT 1 FROM store_inventory_movement_items item WHERE item.movement_id = NEW.id
    UNION ALL
    SELECT 1 FROM rental_inventory_movement_items item WHERE item.movement_id = NEW.id
    UNION ALL
    SELECT 1 FROM inventory_conversions conversion
    WHERE conversion.source_movement_id = NEW.id OR conversion.destination_movement_id = NEW.id
  ) THEN
    RAISE EXCEPTION 'inventory movement cannot be posted without a detail or conversion'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END
$$;

CREATE TRIGGER trg_inventory_movements_immutable
BEFORE UPDATE OR DELETE ON inventory_movements
FOR EACH ROW EXECUTE FUNCTION protect_inventory_movement_header();

CREATE FUNCTION protect_inventory_movement_detail()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  target_movement_id BIGINT;
  movement_status VARCHAR(16);
BEGIN
  target_movement_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.movement_id ELSE NEW.movement_id END;
  SELECT status INTO movement_status FROM inventory_movements WHERE id = target_movement_id;
  IF movement_status IS DISTINCT FROM 'draft' THEN
    RAISE EXCEPTION 'inventory movement details are editable only while draft'
      USING ERRCODE = '55000';
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END
$$;

CREATE TRIGGER trg_store_inventory_movement_items_draft_only
BEFORE INSERT OR UPDATE OR DELETE ON store_inventory_movement_items
FOR EACH ROW EXECUTE FUNCTION protect_inventory_movement_detail();
CREATE TRIGGER trg_rental_inventory_movement_items_draft_only
BEFORE INSERT OR UPDATE OR DELETE ON rental_inventory_movement_items
FOR EACH ROW EXECUTE FUNCTION protect_inventory_movement_detail();

CREATE FUNCTION protect_inventory_conversion_draft()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  source_id BIGINT;
  destination_id BIGINT;
BEGIN
  source_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.source_movement_id ELSE NEW.source_movement_id END;
  destination_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.destination_movement_id ELSE NEW.destination_movement_id END;
  IF EXISTS (
    SELECT 1 FROM inventory_movements
    WHERE id IN (source_id, destination_id) AND status <> 'draft'
  ) THEN
    RAISE EXCEPTION 'inventory conversion is editable only while both movements are draft'
      USING ERRCODE = '55000';
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END
$$;

CREATE TRIGGER trg_inventory_conversions_draft_only
BEFORE INSERT OR UPDATE OR DELETE ON inventory_conversions
FOR EACH ROW EXECUTE FUNCTION protect_inventory_conversion_draft();

CREATE FUNCTION protect_stock_reservation_lifecycle()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.status <> 'active' THEN
      RAISE EXCEPTION 'new stock reservation must be active' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
  END IF;
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'stock reservation audit rows cannot be deleted' USING ERRCODE = '55000';
  END IF;
  IF OLD.status <> 'active' THEN
    RAISE EXCEPTION 'terminal stock reservation is immutable' USING ERRCODE = '55000';
  END IF;
  IF NEW.status NOT IN ('active', 'released', 'expired', 'fulfilled') THEN
    RAISE EXCEPTION 'invalid stock reservation transition' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END
$$;

CREATE TRIGGER trg_product_stock_reservations_lifecycle
BEFORE INSERT OR UPDATE OR DELETE ON product_stock_reservations
FOR EACH ROW EXECUTE FUNCTION protect_stock_reservation_lifecycle();
CREATE TRIGGER trg_rental_stock_reservations_lifecycle
BEFORE INSERT OR UPDATE OR DELETE ON rental_stock_reservations
FOR EACH ROW EXECUTE FUNCTION protect_stock_reservation_lifecycle();

CREATE FUNCTION enforce_minimum_stock_location_domain()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE actual_domain VARCHAR(16);
BEGIN
  SELECT inventory_domain INTO actual_domain
  FROM inventory_locations WHERE id = NEW.location_id;
  IF (TG_TABLE_NAME = 'product_variant_min_stocks' AND actual_domain <> 'store')
     OR (TG_TABLE_NAME = 'rental_sku_variant_min_stocks' AND actual_domain <> 'rental') THEN
    RAISE EXCEPTION 'minimum stock location domain mismatch' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END
$$;

CREATE CONSTRAINT TRIGGER trg_product_variant_min_stocks_domain
AFTER INSERT OR UPDATE ON product_variant_min_stocks
DEFERRABLE INITIALLY IMMEDIATE
FOR EACH ROW EXECUTE FUNCTION enforce_minimum_stock_location_domain();
CREATE CONSTRAINT TRIGGER trg_rental_sku_variant_min_stocks_domain
AFTER INSERT OR UPDATE ON rental_sku_variant_min_stocks
DEFERRABLE INITIALLY IMMEDIATE
FOR EACH ROW EXECUTE FUNCTION enforce_minimum_stock_location_domain();

CREATE FUNCTION protect_minimum_stock_location_domain()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.inventory_domain <> OLD.inventory_domain AND (
    (EXISTS (SELECT 1 FROM product_variant_min_stocks WHERE location_id = OLD.id)
      AND NEW.inventory_domain <> 'store')
    OR
    (EXISTS (SELECT 1 FROM rental_sku_variant_min_stocks WHERE location_id = OLD.id)
      AND NEW.inventory_domain <> 'rental')
  ) THEN
    RAISE EXCEPTION 'inventory location domain is fixed by minimum-stock references'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END
$$;

CREATE TRIGGER trg_inventory_locations_protect_minimum_stock_domain
BEFORE UPDATE OF inventory_domain ON inventory_locations
FOR EACH ROW EXECUTE FUNCTION protect_minimum_stock_location_domain();

COMMENT ON FUNCTION get_zone_availability(DATE, DATE, VARCHAR, VARCHAR) IS
  'P5 inclusive calendar-range query; booking occupancy is [check_in, check_out), closures force zero, and availability never becomes negative.';
COMMENT ON VIEW inventory_movement_items_view IS
  'P5 read-only UNION ALL projection; application writes only concrete domain tables.';
COMMENT ON COLUMN booking_policies.low_availability_threshold IS
  'Integer percent. Compatibility DTO divides by 100 to reproduce lowThresholdRatio.';
COMMENT ON COLUMN campground_closures.effective_from IS
  'Source-preserving inclusive lower bound for a weekly closure rule.';
COMMENT ON COLUMN campground_closures.effective_to IS
  'Source-preserving inclusive upper bound for a weekly closure rule.';
