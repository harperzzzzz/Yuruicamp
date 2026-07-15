\set ON_ERROR_STOP on

DO $$
DECLARE
  unexpected_trigger TEXT;
  unexpected_function TEXT;
BEGIN
  SELECT trigger_data.tgname
  INTO unexpected_trigger
  FROM pg_trigger trigger_data
  WHERE NOT trigger_data.tgisinternal
    AND trigger_data.tgname IN (
      'trg_campground_rental_locations_type',
      'trg_coupon_claims_enforce_status_transition',
      'trg_coupon_claims_sync_capacity_on_update',
      'trg_inventory_conversions_domains',
      'trg_inventory_conversions_draft_only',
      'trg_inventory_locations_protect_minimum_stock_domain',
      'trg_inventory_locations_protect_rental_mapping',
      'trg_inventory_movements_immutable',
      'trg_order_coupons_validate_claim',
      'trg_product_stock_reservations_lifecycle',
      'trg_product_variant_min_stocks_domain',
      'trg_rental_inventory_movement_items_draft_only',
      'trg_rental_sku_variant_min_stocks_domain',
      'trg_rental_stock_reservations_lifecycle',
      'trg_store_inventory_movement_items_draft_only'
    )
  LIMIT 1;

  IF unexpected_trigger IS NOT NULL THEN
    RAISE EXCEPTION 'V744 smoke: backend-owned trigger still exists: %',
      unexpected_trigger;
  END IF;

  SELECT routine.proname
  INTO unexpected_function
  FROM pg_proc routine
  JOIN pg_namespace namespace_data ON namespace_data.oid = routine.pronamespace
  WHERE namespace_data.nspname = 'public'
    AND routine.proname IN (
      'enforce_campground_rental_location_type',
      'enforce_coupon_claim_status_transition',
      'enforce_inventory_conversion_domains',
      'enforce_minimum_stock_location_domain',
      'protect_inventory_conversion_draft',
      'protect_inventory_movement_detail',
      'protect_inventory_movement_header',
      'protect_mapped_rental_location_type',
      'protect_minimum_stock_location_domain',
      'protect_stock_reservation_lifecycle',
      'validate_order_coupon_claim_owner'
    )
  LIMIT 1;

  IF unexpected_function IS NOT NULL THEN
    RAISE EXCEPTION 'V744 smoke: backend-owned trigger function still exists: %',
      unexpected_function;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger trigger_data
    JOIN pg_class relation ON relation.oid = trigger_data.tgrelid
    JOIN pg_namespace namespace_data ON namespace_data.oid = relation.relnamespace
    WHERE namespace_data.nspname = 'public'
      AND relation.relname = 'coupon_claims'
      AND trigger_data.tgname = 'trg_coupon_claims_sync_capacity_on_delete'
      AND NOT trigger_data.tgisinternal
  ) THEN
    RAISE EXCEPTION
      'V744 smoke: allowed delete-time coupon capacity sync trigger is missing';
  END IF;
END
$$;
