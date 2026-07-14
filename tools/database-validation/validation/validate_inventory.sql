\set ON_ERROR_STOP on
\ir p5-data.sql
\ir p5-business-rules.sql

CREATE TEMP TABLE p7_inventory_issues (
  check_name TEXT NOT NULL,
  object_name TEXT NOT NULL,
  reason TEXT NOT NULL
);

INSERT INTO p7_inventory_issues
SELECT 'negative_store_stock', variant_id || '@' || location_id,
       'on-hand quantity is negative'
FROM inventory_stocks
WHERE on_hand_quantity < 0
UNION ALL
SELECT 'negative_rental_stock', rental_sku_variant_id || '@' || location_id,
       'on-hand quantity is negative'
FROM rental_sku_variant_stocks
WHERE on_hand_quantity < 0;

INSERT INTO p7_inventory_issues
SELECT 'orphan_store_reservation', reservation.id::text, 'missing order item or inventory stock'
FROM product_stock_reservations reservation
LEFT JOIN order_items item ON item.id = reservation.order_item_id
LEFT JOIN inventory_stocks stock
  ON stock.variant_id = reservation.variant_id
 AND stock.location_id = reservation.location_id
WHERE item.id IS NULL OR stock.variant_id IS NULL
UNION ALL
SELECT 'orphan_rental_reservation', reservation.id::text, 'missing booking rental or inventory stock'
FROM rental_stock_reservations reservation
LEFT JOIN booking_selected_rentals item ON item.id = reservation.booking_selected_rental_id
LEFT JOIN rental_sku_variant_stocks stock
  ON stock.rental_sku_variant_id = reservation.rental_sku_variant_id
 AND stock.location_id = reservation.location_id
WHERE item.id IS NULL OR stock.rental_sku_variant_id IS NULL;

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*),
  'issues', coalesce(jsonb_agg(jsonb_build_object(
    'check', check_name, 'object', object_name, 'reason', reason
  ) ORDER BY check_name, object_name), '[]'::jsonb)
)) FROM p7_inventory_issues;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p7_inventory_issues) THEN
    RAISE EXCEPTION 'P7 inventory validation failed with % issue(s)',
      (SELECT count(*) FROM p7_inventory_issues);
  END IF;
END $$;
