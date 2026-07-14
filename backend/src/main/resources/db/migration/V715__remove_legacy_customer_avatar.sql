UPDATE customers
SET avatar_url = avatar
WHERE avatar_url IS NULL
  AND avatar IS NOT NULL;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM customers
    WHERE avatar IS NOT NULL
      AND avatar_url IS NULL
  ) THEN
    RAISE EXCEPTION 'customers.avatar backfill failed: legacy avatar values remain without avatar_url';
  END IF;
END $$;

CREATE OR REPLACE VIEW review_dto_view AS
SELECT review.id,
       TRUE AS verified_purchase,
       jsonb_build_object(
         'id', review.id,
         'customerId', order_header.customer_id,
         'productId', item.product_id,
         'variantId', item.variant_id,
         'sku', item.sku_snapshot,
         'orderId', item.order_id,
         'orderItemId', review.order_item_id,
         'buyerName', order_header.buyer_name_snapshot,
         'buyerAvatar', customer.avatar_url,
         'productName', item.product_name_snapshot,
         'rating', review.rating,
         'comment', review.comment,
         'photos', COALESCE((
           SELECT jsonb_agg(photo.url ORDER BY photo.sort_order)
           FROM review_photos photo WHERE photo.review_id = review.id
         ), '[]'::jsonb),
         'createdAt', to_char(review.created_at AT TIME ZONE 'Asia/Taipei', 'YYYY-MM-DD HH24:MI:SS'),
         'verifiedPurchase', TRUE
       ) AS payload
FROM reviews review
JOIN order_items item ON item.id = review.order_item_id
JOIN orders order_header ON order_header.id = item.order_id
JOIN customers customer ON customer.id = order_header.customer_id
UNION ALL
SELECT review.id,
       FALSE AS verified_purchase,
       jsonb_build_object(
         'id', review.id,
         'customerId', review.customer_id,
         'productId', review.product_id,
         'variantId', review.variant_id,
         'sku', review.sku_snapshot,
         'buyerName', review.buyer_name_snapshot,
         'buyerAvatar', review.buyer_avatar_snapshot,
         'productName', review.product_name_snapshot,
         'rating', review.rating,
         'comment', review.comment,
         'photos', COALESCE((
           SELECT jsonb_agg(photo.url ORDER BY photo.sort_order)
           FROM legacy_review_photos photo WHERE photo.legacy_review_id = review.id
         ), '[]'::jsonb),
         'createdAt', to_char(review.created_at AT TIME ZONE 'Asia/Taipei', 'YYYY-MM-DD HH24:MI:SS'),
         'verifiedPurchase', FALSE
       ) AS payload
FROM legacy_reviews review;

DO $$
DECLARE
  dependent_objects TEXT;
BEGIN
  SELECT string_agg(
           pg_describe_object(dependency.classid, dependency.objid, dependency.objsubid),
           E'\n' ORDER BY pg_describe_object(dependency.classid, dependency.objid, dependency.objsubid)
         )
  INTO dependent_objects
  FROM pg_attribute attribute
  JOIN pg_depend dependency
    ON dependency.refobjid = attribute.attrelid
   AND dependency.refobjsubid = attribute.attnum
  WHERE attribute.attrelid = 'public.customers'::regclass
    AND attribute.attname = 'avatar'
    AND dependency.deptype = 'n';

  IF dependent_objects IS NOT NULL THEN
    RAISE EXCEPTION 'customers.avatar still has dependent database objects:%', E'\n' || dependent_objects;
  END IF;
END $$;

ALTER TABLE customers
DROP COLUMN avatar;
