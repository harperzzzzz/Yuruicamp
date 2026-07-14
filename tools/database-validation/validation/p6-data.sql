\set ON_ERROR_STOP on

CREATE TEMP TABLE p6_data_issues (
  check_name TEXT NOT NULL,
  object_name TEXT NOT NULL,
  reason TEXT NOT NULL
);

INSERT INTO p6_data_issues
SELECT 'review_count', expected.name,
       format('expected %s, found %s', expected.expected_count, actual.actual_count)
FROM (VALUES
  ('source',38::bigint), ('resolution',38), ('formal',1), ('legacy',37),
  ('formal_photos',0), ('legacy_photos',0)
) expected(name, expected_count)
JOIN LATERAL (SELECT CASE expected.name
  WHEN 'source' THEN (SELECT count(*) FROM migration.p6_review_source)
  WHEN 'resolution' THEN (SELECT count(*) FROM migration.p6_review_resolution)
  WHEN 'formal' THEN (SELECT count(*) FROM reviews)
  WHEN 'legacy' THEN (SELECT count(*) FROM legacy_reviews)
  WHEN 'formal_photos' THEN (SELECT count(*) FROM review_photos)
  WHEN 'legacy_photos' THEN (SELECT count(*) FROM legacy_review_photos)
END::bigint AS actual_count) actual ON TRUE
WHERE actual.actual_count <> expected.expected_count;

INSERT INTO p6_data_issues
SELECT 'formal_resolution', 'REV031', 'REV031 is not the sole exact formal review'
WHERE NOT EXISTS (
  SELECT 1 FROM migration.p6_review_resolution resolution
  JOIN reviews review ON review.id = resolution.review_id
  WHERE resolution.review_id = 'REV031'
    AND resolution.disposition = 'formal'
    AND resolution.order_item_id = 418
    AND review.order_item_id = 418
)
OR EXISTS (SELECT 1 FROM reviews WHERE id <> 'REV031');

INSERT INTO p6_data_issues
SELECT 'legacy_resolution', resolution.review_id,
       'legacy review lacks the approved NO_ORDER_ID reason or target row'
FROM migration.p6_review_resolution resolution
LEFT JOIN legacy_reviews review ON review.id = resolution.review_id
WHERE resolution.disposition = 'legacy'
  AND (review.id IS NULL OR resolution.order_item_id IS NOT NULL
       OR resolution.resolution_method <> 'NO_ORDER_ID'
       OR BTRIM(resolution.legacy_reason) = '');

INSERT INTO p6_data_issues
SELECT 'unmigrated_review', source.id, 'source review has no exactly-one target'
FROM migration.p6_review_source source
LEFT JOIN reviews formal_review ON formal_review.id = source.id
LEFT JOIN legacy_reviews legacy_review ON legacy_review.id = source.id
WHERE num_nonnulls(formal_review.id, legacy_review.id) <> 1;

INSERT INTO p6_data_issues
SELECT 'reply_payload', id, 'source unexpectedly contains an official reply key'
FROM migration.p6_review_source
WHERE payload ?| ARRAY[
  'replied','replyText','replyAt','repliedBy','repliedByName','replyUpdatedAt',
  'reply_text','reply_at','replied_by','replied_by_name','reply_updated_at'
];

INSERT INTO p6_data_issues
SELECT 'article_count', expected.name,
       format('expected %s, found %s', expected.expected_count, actual.actual_count)
FROM (VALUES
  ('articles',6::bigint), ('tags',18), ('blocks',41), ('headings',12), ('related',16)
) expected(name, expected_count)
JOIN LATERAL (SELECT CASE expected.name
  WHEN 'articles' THEN (SELECT count(*) FROM articles)
  WHEN 'tags' THEN (SELECT count(*) FROM article_tags)
  WHEN 'blocks' THEN (SELECT count(*) FROM article_content_blocks)
  WHEN 'headings' THEN (SELECT count(*) FROM article_content_blocks WHERE block_type = 'heading')
  WHEN 'related' THEN (SELECT count(*) FROM article_related_products)
END::bigint AS actual_count) actual ON TRUE
WHERE actual.actual_count <> expected.expected_count;

INSERT INTO p6_data_issues
SELECT 'article_tag', source.id, 'article tag set differs from source'
FROM migration.p6_article_source source
WHERE EXISTS (
  (SELECT value FROM jsonb_array_elements_text(source.payload->'tags') value
   EXCEPT SELECT tag FROM article_tags WHERE article_id = source.id)
  UNION ALL
  (SELECT tag FROM article_tags WHERE article_id = source.id
   EXCEPT SELECT value FROM jsonb_array_elements_text(source.payload->'tags') value)
);

INSERT INTO p6_data_issues
SELECT 'article_block', source.id, 'article block order/type/payload differs from source'
FROM migration.p6_article_source source
WHERE EXISTS (
  SELECT block.ordinality - 1, block.payload->>'type',
         CASE WHEN block.payload->>'type' IN ('text','heading') THEN block.payload->>'value' END,
         CASE WHEN block.payload->>'type' = 'product' THEN block.payload->>'productId' END
  FROM jsonb_array_elements(source.payload->'content') WITH ORDINALITY block(payload, ordinality)
  EXCEPT
  SELECT sort_order, block_type, text_content, product_id
  FROM article_content_blocks WHERE article_id = source.id
);

INSERT INTO p6_data_issues
SELECT 'article_related', source.id, 'related product order differs from source'
FROM migration.p6_article_source source
WHERE EXISTS (
  SELECT related.value, related.ordinality - 1
  FROM jsonb_array_elements_text(source.payload->'relatedProducts')
    WITH ORDINALITY related(value, ordinality)
  EXCEPT
  SELECT product_id, sort_order
  FROM article_related_products WHERE article_id = source.id
);

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*),
  'issues', coalesce(jsonb_agg(jsonb_build_object(
    'check', check_name, 'object', object_name, 'reason', reason
  ) ORDER BY check_name, object_name), '[]'::jsonb)
)) FROM p6_data_issues;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p6_data_issues) THEN
    RAISE EXCEPTION 'P6 data validation failed with % issue(s)',
      (SELECT count(*) FROM p6_data_issues);
  END IF;
END $$;
