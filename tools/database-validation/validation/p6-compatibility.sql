\set ON_ERROR_STOP on

CREATE TEMP TABLE p6_compatibility_issues (
  check_name TEXT NOT NULL,
  object_name TEXT NOT NULL,
  reason TEXT NOT NULL
);

INSERT INTO p6_compatibility_issues
SELECT 'review_dto', source.id, 'review DTO scalar/photo fields differ from source'
FROM migration.p6_review_source source
LEFT JOIN review_dto_view target ON target.id = source.id
WHERE target.id IS NULL
   OR target.payload->>'customerId' IS DISTINCT FROM source.payload->>'customerId'
   OR target.payload->>'productId' IS DISTINCT FROM source.payload->>'productId'
   OR target.payload->>'variantId' IS DISTINCT FROM source.payload->>'variantId'
   OR target.payload->>'sku' IS DISTINCT FROM source.payload->>'sku'
   OR target.payload->>'orderId' IS DISTINCT FROM source.payload->>'orderId'
   OR target.payload->>'buyerName' IS DISTINCT FROM source.payload->>'buyerName'
   OR target.payload->>'buyerAvatar' IS DISTINCT FROM source.payload->>'buyerAvatar'
   OR target.payload->>'productName' IS DISTINCT FROM source.payload->>'productName'
   OR target.payload->>'rating' IS DISTINCT FROM source.payload->>'rating'
   OR target.payload->>'comment' IS DISTINCT FROM source.payload->>'comment'
   OR target.payload->>'createdAt' IS DISTINCT FROM source.payload->>'createdAt'
   OR target.payload->'photos' IS DISTINCT FROM source.payload->'photos'
   OR target.verified_purchase <> (source.id = 'REV031');

INSERT INTO p6_compatibility_issues
SELECT 'reply_dto', id, 'review DTO exposes a forbidden official reply field'
FROM review_dto_view
WHERE payload ?| ARRAY[
  'replied','replyText','replyAt','repliedBy','repliedByName','replyUpdatedAt',
  'reply_text','reply_at','replied_by','replied_by_name','reply_updated_at'
];

INSERT INTO p6_compatibility_issues
SELECT 'article_dto', source.id, 'article DTO scalar/content/related fields differ from source'
FROM migration.p6_article_source source
LEFT JOIN article_dto_view target ON target.id = source.id
WHERE target.id IS NULL
   OR target.payload->>'title' IS DISTINCT FROM source.payload->>'title'
   OR target.payload->>'category' IS DISTINCT FROM source.payload->>'category'
   OR target.payload->>'author' IS DISTINCT FROM source.payload->>'author'
   OR target.payload->>'authorAvatar' IS DISTINCT FROM source.payload->>'authorAvatar'
   OR target.payload->>'publishedDate' IS DISTINCT FROM source.payload->>'publishedDate'
   OR target.payload->>'readTime' IS DISTINCT FROM source.payload->>'readTime'
   OR target.payload->>'image' IS DISTINCT FROM source.payload->>'image'
   OR target.payload->>'excerpt' IS DISTINCT FROM source.payload->>'excerpt'
   OR target.payload->>'isFeatured' IS DISTINCT FROM source.payload->>'isFeatured'
   OR target.payload->'content' IS DISTINCT FROM source.payload->'content'
   OR target.payload->'relatedProducts' IS DISTINCT FROM source.payload->'relatedProducts';

INSERT INTO p6_compatibility_issues
SELECT 'article_tag_dto', source.id, 'article DTO tag set differs from source'
FROM migration.p6_article_source source
JOIN article_dto_view target ON target.id = source.id
WHERE EXISTS (
  (SELECT value FROM jsonb_array_elements_text(source.payload->'tags') value
   EXCEPT SELECT value FROM jsonb_array_elements_text(target.payload->'tags') value)
  UNION ALL
  (SELECT value FROM jsonb_array_elements_text(target.payload->'tags') value
   EXCEPT SELECT value FROM jsonb_array_elements_text(source.payload->'tags') value)
);

INSERT INTO p6_compatibility_issues
SELECT 'movement_dto_count', 'inventory_movement_dto_view',
       format('expected 171 movement DTOs, found %s', count(*))
FROM inventory_movement_dto_view HAVING count(*) <> 171;

INSERT INTO p6_compatibility_issues
SELECT 'movement_item_dto', id::text,
       'movement item is missing domain/variant identity or exposes productId-only shape'
FROM inventory_movement_dto_view movement
CROSS JOIN LATERAL jsonb_array_elements(movement.payload->'items') item
WHERE NOT item ? 'inventoryDomain' OR NOT item ? 'variantId'
   OR item ? 'productId';

INSERT INTO p6_compatibility_issues
SELECT 'movement_item_count', 'inventory_movement_dto_view',
       format('expected 109 normalized view items, found %s', count(*))
FROM inventory_movement_dto_view movement
CROSS JOIN LATERAL jsonb_array_elements(movement.payload->'items') item
HAVING count(*) <> 109;

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*),
  'issues', coalesce(jsonb_agg(jsonb_build_object(
    'check', check_name, 'object', object_name, 'reason', reason
  ) ORDER BY check_name, object_name), '[]'::jsonb)
)) FROM p6_compatibility_issues;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p6_compatibility_issues) THEN
    RAISE EXCEPTION 'P6 compatibility validation failed with % issue(s)',
      (SELECT count(*) FROM p6_compatibility_issues);
  END IF;
END $$;
