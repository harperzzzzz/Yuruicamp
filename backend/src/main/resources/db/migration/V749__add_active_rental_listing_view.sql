CREATE VIEW public.active_rental_listing_view AS
SELECT
  listing.id,
  listing.campground_id,
  listing.rental_sku_variant_id,
  mapping.location_id,
  listing.price_per_day_weekday,
  listing.price_per_day_holiday,
  listing.discount,
  COALESCE(stock.on_hand_quantity, 0) AS stock
FROM public.rental_listings listing
JOIN public.campground_rental_locations mapping
  ON mapping.campground_id = listing.campground_id
JOIN public.rental_sku_variants variant
  ON variant.id = listing.rental_sku_variant_id
JOIN public.rental_skus sku
  ON sku.id = variant.rental_sku_id
LEFT JOIN public.rental_sku_variant_stocks stock
  ON stock.location_id = mapping.location_id
 AND stock.rental_sku_variant_id = listing.rental_sku_variant_id
WHERE listing.active = TRUE
  AND sku.status = 'active'
  AND variant.status = 'active';

COMMENT ON VIEW public.active_rental_listing_view IS
  'Canonical read-only projection of rentable active listings; filters listing, rental SKU, and variant status.';
