\set ON_ERROR_STOP on

CREATE TEMP TABLE p4_structure_issues (
  check_name TEXT NOT NULL,
  object_name TEXT NOT NULL,
  reason TEXT NOT NULL
);

INSERT INTO p4_structure_issues
SELECT 'required_relation', expected.name, 'missing or wrong P4 relation kind'
FROM (VALUES
  ('orders', 'BASE TABLE'), ('order_items', 'BASE TABLE'),
  ('order_status_history', 'BASE TABLE'), ('coupons', 'BASE TABLE'),
  ('order_coupons', 'BASE TABLE'), ('coupon_usage_adjustments', 'BASE TABLE'),
  ('calendar_dates', 'BASE TABLE'), ('bookings', 'BASE TABLE'),
  ('booking_selected_zones', 'BASE TABLE'),
  ('booking_selected_rentals', 'BASE TABLE'),
  ('booking_status_history', 'BASE TABLE'),
  ('product_stock_reservations', 'BASE TABLE'),
  ('rental_stock_reservations', 'BASE TABLE'),
  ('coupon_usage_stats', 'VIEW'), ('customer_spending_summary', 'VIEW'),
  ('customer_tier_summary', 'VIEW'), ('product_stock_summary', 'VIEW')
) expected(name, kind)
LEFT JOIN information_schema.tables actual
  ON actual.table_schema = 'public' AND actual.table_name = expected.name
WHERE actual.table_name IS NULL OR actual.table_type <> expected.kind;

INSERT INTO p4_structure_issues
SELECT 'required_constraint', expected.name,
       'missing or wrong constraint type (names longer than 63 bytes use PostgreSQL truncation)'
FROM (VALUES
  ('pk_orders', 'p'), ('fk_orders_customer_id', 'f'),
  ('ck_orders_money', 'c'), ('ck_orders_payment_method', 'c'),
  ('ck_orders_status', 'c'),
  ('pk_order_items', 'p'), ('fk_order_items_order_id', 'f'),
  ('fk_order_items_product_id', 'f'), ('fk_order_items_variant_id', 'f'),
  ('uq_order_items_id_variant_id', 'u'),
  ('ck_order_items_quantity', 'c'), ('ck_order_items_price', 'c'),
  ('pk_order_status_history', 'p'),
  ('fk_order_status_history_order_id', 'f'),
  ('fk_order_status_history_actor_id', 'f'),
  ('pk_coupons', 'p'), ('uq_coupons_code', 'u'),
  ('ck_coupons_type', 'c'), ('ck_coupons_values', 'c'),
  ('ck_coupons_dates', 'c'), ('ck_coupons_percentage', 'c'),
  ('pk_order_coupons', 'p'), ('fk_order_coupons_order_id', 'f'),
  ('fk_order_coupons_coupon_id', 'f'),
  ('uq_order_coupons_order_id_code_snapshot', 'u'),
  ('ck_order_coupons_amounts', 'c'),
  ('pk_coupon_usage_adjustments', 'p'),
  ('fk_coupon_usage_adjustments_order_coupon_id', 'f'),
  ('uq_coupon_usage_adjustments_idempotency_key', 'u'),
  ('ck_coupon_usage_adjustments_type', 'c'),
  ('ck_coupon_usage_adjustments_delta', 'c'),
  ('ck_coupon_usage_adjustments_reason', 'c'),
  ('pk_calendar_dates', 'p'), ('ck_calendar_dates_source', 'c'),
  ('ck_calendar_dates_holiday_name', 'c'),
  ('pk_bookings', 'p'), ('fk_bookings_customer_id', 'f'),
  ('fk_bookings_campground_id', 'f'), ('ck_bookings_dates', 'c'),
  ('ck_bookings_guests', 'c'), ('ck_bookings_day_counts', 'c'),
  ('ck_bookings_money', 'c'),
  ('pk_booking_selected_zones', 'p'),
  ('fk_booking_selected_zones_booking_id', 'f'),
  ('fk_booking_selected_zones_zone_id', 'f'),
  ('ck_booking_selected_zones_quantity', 'c'),
  ('ck_booking_selected_zones_prices', 'c'),
  ('pk_booking_selected_rentals', 'p'),
  ('fk_booking_selected_rentals_booking_id', 'f'),
  ('fk_booking_selected_rentals_rental_listing_id', 'f'),
  ('fk_booking_selected_rentals_rental_sku_variant_id', 'f'),
  ('uq_booking_selected_rentals_id_rental_sku_variant_id', 'u'),
  ('ck_booking_selected_rentals_quantity', 'c'),
  ('ck_booking_selected_rentals_money', 'c'),
  ('pk_booking_status_history', 'p'),
  ('fk_booking_status_history_booking_id', 'f'),
  ('fk_booking_status_history_actor_id', 'f'),
  ('pk_product_stock_reservations', 'p'),
  ('fk_product_stock_reservations_order_item_id_variant_id', 'f'),
  ('fk_product_stock_reservations_location_id', 'f'),
  ('uq_product_stock_reservations_idempotency_key', 'u'),
  ('ck_product_stock_reservations_quantity', 'c'),
  ('ck_product_stock_reservations_status', 'c'),
  ('ck_product_stock_reservations_expiry', 'c'),
  ('ck_product_stock_reservations_terminal', 'c'),
  ('pk_rental_stock_reservations', 'p'),
  ('fk_rental_stock_reservations_booking_selected_rental_id_rental_sku_variant_id', 'f'),
  ('fk_rental_stock_reservations_location_id', 'f'),
  ('uq_rental_stock_reservations_idempotency_key', 'u'),
  ('ck_rental_stock_reservations_dates', 'c'),
  ('ck_rental_stock_reservations_quantity', 'c'),
  ('ck_rental_stock_reservations_status', 'c'),
  ('ck_rental_stock_reservations_terminal', 'c')
) expected(name, type)
LEFT JOIN pg_constraint actual
  ON actual.conname = LEFT(expected.name, 63)
 AND actual.contype::TEXT = expected.type
WHERE actual.oid IS NULL;

INSERT INTO p4_structure_issues
SELECT 'required_index', expected.name, 'missing or invalid P4 index'
FROM (VALUES
  ('idx_orders_customer_placed'), ('idx_orders_status_payment'),
  ('idx_order_items_order'), ('idx_order_items_product'),
  ('idx_order_items_variant'), ('idx_order_status_history_order_time'),
  ('idx_order_status_history_actor'), ('idx_coupons_status_validity'),
  ('idx_order_coupons_coupon'),
  ('idx_coupon_usage_adjustments_order_coupon_time'),
  ('idx_calendar_dates_holiday_date'), ('idx_bookings_customer_created'),
  ('idx_bookings_campground_dates'),
  ('idx_booking_selected_zones_booking'), ('idx_booking_selected_zones_zone'),
  ('idx_booking_selected_rentals_booking'),
  ('idx_booking_selected_rentals_listing'),
  ('idx_booking_selected_rentals_variant'),
  ('idx_booking_status_history_booking_time'),
  ('idx_booking_status_history_actor'),
  ('idx_product_stock_reservations_order_item'),
  ('idx_product_stock_reservations_order_item_variant'),
  ('idx_product_stock_reservations_location'),
  ('idx_product_stock_reservations_active_lookup'),
  ('idx_product_stock_reservations_expiry'),
  ('idx_rental_stock_reservations_booking_item'),
  ('idx_rental_stock_reservations_booking_item_variant'),
  ('idx_rental_stock_reservations_location'),
  ('idx_rental_stock_reservations_active_range')
) expected(name)
LEFT JOIN pg_class index_class ON index_class.relname = expected.name
LEFT JOIN pg_index index_data ON index_data.indexrelid = index_class.oid
WHERE index_class.oid IS NULL OR NOT index_data.indisvalid;

WITH p4_tables AS (
  SELECT relation.oid
  FROM pg_class relation
  JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
  WHERE namespace.nspname = 'public'
    AND relation.relname IN (
      'orders', 'order_items', 'order_status_history', 'coupons',
      'order_coupons', 'coupon_usage_adjustments', 'calendar_dates',
      'bookings', 'booking_selected_zones', 'booking_selected_rentals',
      'booking_status_history', 'product_stock_reservations',
      'rental_stock_reservations'
    )
), foreign_keys AS (
  SELECT constraint_data.conname, constraint_data.conrelid,
         constraint_data.conkey
  FROM pg_constraint constraint_data
  JOIN p4_tables p4_table ON p4_table.oid = constraint_data.conrelid
  WHERE constraint_data.contype = 'f'
)
INSERT INTO p4_structure_issues
SELECT 'foreign_key_index', foreign_key.conname,
       'referencing columns lack a usable non-partial index'
FROM foreign_keys foreign_key
WHERE NOT EXISTS (
  SELECT 1
  FROM pg_index index_data
  WHERE index_data.indrelid = foreign_key.conrelid
    AND index_data.indisvalid
    AND index_data.indpred IS NULL
    AND foreign_key.conkey <@ index_data.indkey::SMALLINT[]
);

INSERT INTO p4_structure_issues
SELECT 'legacy_public_table', actual.table_name,
       'pre-P4 physical table was not replaced'
FROM information_schema.tables actual
WHERE actual.table_schema = 'public'
  AND actual.table_name IN (
    'order_history', 'booking_history'
  );

INSERT INTO p4_structure_issues
SELECT 'legacy_column', table_name || '.' || column_name,
       'legacy transaction column remains in the normalized P4 table'
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (table_name, column_name) IN (
    ('orders', 'buyer_name'), ('orders', 'address'),
    ('orders', 'buyer_phone'), ('orders', 'points'),
    ('orders', 'points_awarded'), ('orders', 'payment'),
    ('orders', 'tracking_number'), ('orders', 'reviewed'),
    ('order_items', 'sku'), ('order_items', 'name'),
    ('order_items', 'spec_label'), ('order_items', 'price'),
    ('coupons', 'used'), ('coupons', 'discount'),
    ('bookings', 'total_days'), ('bookings', 'payment_status'),
    ('booking_selected_zones', 'subtotal'),
    ('booking_selected_rentals', 'equipment_id'),
    ('booking_selected_rentals', 'subtotal')
  );

INSERT INTO p4_structure_issues
SELECT 'view_column', expected.view_name || '.' || expected.column_name,
       'missing or wrong P4 view output type'
FROM (VALUES
  ('coupon_usage_stats', 'coupon_id', 'bigint'),
  ('coupon_usage_stats', 'used_quantity', 'bigint'),
  ('coupon_usage_stats', 'remaining_quantity', 'bigint'),
  ('customer_spending_summary', 'customer_id', 'character varying'),
  ('customer_spending_summary', 'total_spent', 'numeric'),
  ('customer_tier_summary', 'customer_id', 'character varying'),
  ('customer_tier_summary', 'total_spent', 'numeric'),
  ('customer_tier_summary', 'tier_code', 'character varying'),
  ('customer_tier_summary', 'tier_name', 'character varying'),
  ('product_stock_summary', 'product_id', 'character varying'),
  ('product_stock_summary', 'total_on_hand', 'bigint'),
  ('product_stock_summary', 'total_reserved', 'bigint'),
  ('product_stock_summary', 'total_available', 'bigint')
) expected(view_name, column_name, data_type)
LEFT JOIN information_schema.columns actual
  ON actual.table_schema = 'public'
 AND actual.table_name = expected.view_name
 AND actual.column_name = expected.column_name
WHERE actual.column_name IS NULL OR actual.data_type <> expected.data_type;

INSERT INTO p4_structure_issues
SELECT 'legacy_audit', expected.name, 'P4 migration evidence table is missing'
FROM (VALUES
  ('p4_legacy_orders'), ('p4_legacy_order_items'),
  ('p4_legacy_order_history'), ('p4_legacy_order_coupons'),
  ('p4_legacy_coupons'), ('p4_legacy_bookings'),
  ('p4_legacy_booking_selected_zones'),
  ('p4_legacy_booking_selected_rentals'), ('p4_legacy_booking_history'),
  ('p4_order_source'), ('p4_coupon_source'), ('p4_booking_source'),
  ('p4_action_map'), ('p4_booking_day_count_resolution'),
  ('p4_zone_price_reconciliation'), ('p4_rental_price_reconciliation'),
  ('p4_snapshot_fallbacks'), ('p4_rental_reservation_quarantine')
) expected(name)
LEFT JOIN information_schema.tables actual
  ON actual.table_schema = 'migration' AND actual.table_name = expected.name
WHERE actual.table_name IS NULL;

INSERT INTO p4_structure_issues
SELECT 'p5_scope', actual.table_name, 'P5-only target exists during P4'
FROM information_schema.tables actual
WHERE actual.table_schema = 'public'
  AND actual.table_name IN (
    'booking_policy_occupying_statuses',
    'booking_policy_availability_statuses', 'zone_availability',
    'product_variant_min_stocks', 'rental_sku_variant_min_stocks',
    'store_inventory_movement_items', 'rental_inventory_movement_items',
    'inventory_movement_items_view', 'inventory_conversions',
    'movement_migration_map'
  );

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*),
  'issues', COALESCE(jsonb_agg(jsonb_build_object(
    'check', check_name, 'object', object_name, 'reason', reason
  ) ORDER BY check_name, object_name), '[]'::JSONB)
))
FROM p4_structure_issues;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p4_structure_issues) THEN
    RAISE EXCEPTION 'P4 structure validation failed with % issue(s)',
      (SELECT count(*) FROM p4_structure_issues);
  END IF;
END $$;
