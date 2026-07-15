-- Business workflow validation belongs in Spring Boot services.
-- Database triggers remain only for timestamps, audit/history protection,
-- log maintenance, and fields that must stay synchronized.

-- Backend: validate that a campground rental location uses the
-- rental/campground inventory classification before saving the mapping.
DROP TRIGGER IF EXISTS trg_campground_rental_locations_type
  ON public.campground_rental_locations;

-- Backend: enforce coupon-claim lifecycle transitions.
DROP TRIGGER IF EXISTS trg_coupon_claims_enforce_status_transition
  ON public.coupon_claims;

-- Backend: reject coupon_id changes and coordinate claim status changes.
-- Delete-time claimed_quantity synchronization remains in the database.
DROP TRIGGER IF EXISTS trg_coupon_claims_sync_capacity_on_update
  ON public.coupon_claims;

-- Backend: validate store-to-rental inventory conversion domains.
DROP TRIGGER IF EXISTS trg_inventory_conversions_domains
  ON public.inventory_conversions;

-- Backend: allow conversion edits only while both movements are drafts.
DROP TRIGGER IF EXISTS trg_inventory_conversions_draft_only
  ON public.inventory_conversions;

-- Backend: prevent incompatible inventory-domain changes when minimum-stock
-- settings reference the location.
DROP TRIGGER IF EXISTS trg_inventory_locations_protect_minimum_stock_domain
  ON public.inventory_locations;

-- Backend: keep mapped campground locations classified as rental/campground.
DROP TRIGGER IF EXISTS trg_inventory_locations_protect_rental_mapping
  ON public.inventory_locations;

-- Backend: enforce movement lifecycle, posting prerequisites, and editability.
DROP TRIGGER IF EXISTS trg_inventory_movements_immutable
  ON public.inventory_movements;

-- Backend: verify that a coupon claim belongs to the order customer.
-- The claim/coupon pair remains protected by its composite foreign key.
DROP TRIGGER IF EXISTS trg_order_coupons_validate_claim
  ON public.order_coupons;

-- Backend: enforce product stock-reservation lifecycle and immutability.
DROP TRIGGER IF EXISTS trg_product_stock_reservations_lifecycle
  ON public.product_stock_reservations;

-- Backend: validate that product minimum stock uses a store location.
DROP TRIGGER IF EXISTS trg_product_variant_min_stocks_domain
  ON public.product_variant_min_stocks;

-- Backend: allow rental movement-detail edits only while the header is draft.
DROP TRIGGER IF EXISTS trg_rental_inventory_movement_items_draft_only
  ON public.rental_inventory_movement_items;

-- Backend: validate that rental minimum stock uses a rental location.
DROP TRIGGER IF EXISTS trg_rental_sku_variant_min_stocks_domain
  ON public.rental_sku_variant_min_stocks;

-- Backend: enforce rental stock-reservation lifecycle and immutability.
DROP TRIGGER IF EXISTS trg_rental_stock_reservations_lifecycle
  ON public.rental_stock_reservations;

-- Backend: allow store movement-detail edits only while the header is draft.
DROP TRIGGER IF EXISTS trg_store_inventory_movement_items_draft_only
  ON public.store_inventory_movement_items;

-- Remove trigger functions that no longer have a database responsibility.
DROP FUNCTION IF EXISTS public.enforce_campground_rental_location_type();
DROP FUNCTION IF EXISTS public.enforce_coupon_claim_status_transition();
DROP FUNCTION IF EXISTS public.enforce_inventory_conversion_domains();
DROP FUNCTION IF EXISTS public.enforce_minimum_stock_location_domain();
DROP FUNCTION IF EXISTS public.protect_inventory_conversion_draft();
DROP FUNCTION IF EXISTS public.protect_inventory_movement_detail();
DROP FUNCTION IF EXISTS public.protect_inventory_movement_header();
DROP FUNCTION IF EXISTS public.protect_mapped_rental_location_type();
DROP FUNCTION IF EXISTS public.protect_minimum_stock_location_domain();
DROP FUNCTION IF EXISTS public.protect_stock_reservation_lifecycle();
DROP FUNCTION IF EXISTS public.validate_order_coupon_claim_owner();

-- Keep only the allowed delete-time counter synchronization responsibility.
CREATE OR REPLACE FUNCTION public.sync_coupon_claim_capacity()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.status IN ('claimed', 'consumed') THEN
    UPDATE public.coupons
    SET claimed_quantity = claimed_quantity - 1,
        updated_at = now()
    WHERE id = OLD.coupon_id
      AND claimed_quantity > 0;

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'Coupon % claim counter cannot be released', OLD.coupon_id
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  RETURN OLD;
END
$$;

COMMENT ON FUNCTION public.sync_coupon_claim_capacity() IS
  'Synchronizes coupons.claimed_quantity when an allocated claim is deleted.';
