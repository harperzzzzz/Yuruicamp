\set ON_ERROR_STOP on

CREATE TEMP TABLE p6_structure_issues (
  check_name TEXT NOT NULL,
  object_name TEXT NOT NULL,
  reason TEXT NOT NULL
);

INSERT INTO p6_structure_issues
SELECT 'required_relation', expected.name, 'missing or wrong P6 relation kind'
FROM (VALUES
  ('reviews', 'BASE TABLE'), ('review_photos', 'BASE TABLE'),
  ('legacy_reviews', 'BASE TABLE'), ('legacy_review_photos', 'BASE TABLE'),
  ('articles', 'BASE TABLE'), ('article_tags', 'BASE TABLE'),
  ('article_content_blocks', 'BASE TABLE'),
  ('article_related_products', 'BASE TABLE'),
  ('review_dto_view', 'VIEW'), ('article_dto_view', 'VIEW'),
  ('inventory_movement_dto_view', 'VIEW')
) expected(name, kind)
LEFT JOIN information_schema.tables actual
  ON actual.table_schema = 'public' AND actual.table_name = expected.name
WHERE actual.table_name IS NULL OR actual.table_type <> expected.kind;

INSERT INTO p6_structure_issues
SELECT 'formal_review_columns', 'reviews',
       'formal reviews must contain only id/order_item_id/rating/comment/created_at'
WHERE (SELECT array_agg(column_name::text ORDER BY ordinal_position)
       FROM information_schema.columns
       WHERE table_schema = 'public' AND table_name = 'reviews')
      IS DISTINCT FROM ARRAY['id','order_item_id','rating','comment','created_at']::text[];

INSERT INTO p6_structure_issues
SELECT 'official_reply_relation', relation.relname,
       'official reply relation is forbidden by D-009'
FROM pg_class relation
JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
WHERE namespace.nspname = 'public' AND relation.relname = 'review_replies';

INSERT INTO p6_structure_issues
SELECT 'official_reply_column', table_name || '.' || column_name,
       'official reply column is forbidden by D-009'
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('reviews', 'legacy_reviews')
  AND (column_name = 'replied' OR column_name LIKE 'reply\_%' ESCAPE '\'
       OR column_name LIKE 'replied\_%' ESCAPE '\');

INSERT INTO p6_structure_issues
SELECT 'required_constraint', expected.name, 'missing or wrong P6 constraint type'
FROM (VALUES
  ('pk_reviews','p'), ('fk_reviews_order_item_id','f'),
  ('uq_reviews_order_item_id','u'), ('ck_reviews_rating','c'),
  ('pk_review_photos','p'), ('fk_review_photos_review_id','f'),
  ('pk_legacy_reviews','p'), ('fk_legacy_reviews_customer_id','f'),
  ('fk_legacy_reviews_product_id_variant_id','f'),
  ('ck_legacy_reviews_reason','c'), ('pk_legacy_review_photos','p'),
  ('pk_articles','p'), ('ck_articles_published','c'),
  ('pk_article_tags','p'), ('fk_article_tags_article_id','f'),
  ('pk_article_content_blocks','p'),
  ('fk_article_content_blocks_article_id','f'),
  ('fk_article_content_blocks_product_id','f'),
  ('uq_article_content_blocks_article_id_sort_order','u'),
  ('ck_article_content_blocks_payload','c'),
  ('pk_article_related_products','p'),
  ('uq_article_related_products_article_id_sort_order','u')
) expected(name, kind)
LEFT JOIN pg_constraint actual
  ON actual.conname = LEFT(expected.name, 63) AND actual.contype::text = expected.kind
WHERE actual.oid IS NULL;

WITH p6_tables AS (
  SELECT relation.oid
  FROM pg_class relation
  JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
  WHERE namespace.nspname = 'public'
    AND relation.relname IN (
      'reviews', 'review_photos', 'legacy_reviews', 'legacy_review_photos',
      'article_tags', 'article_content_blocks', 'article_related_products'
    )
), foreign_keys AS (
  SELECT constraint_data.conname, constraint_data.conrelid, constraint_data.conkey
  FROM pg_constraint constraint_data
  JOIN p6_tables p6_table ON p6_table.oid = constraint_data.conrelid
  WHERE constraint_data.contype = 'f'
)
INSERT INTO p6_structure_issues
SELECT 'foreign_key_index', foreign_key.conname,
       'referencing columns lack a usable non-partial index'
FROM foreign_keys foreign_key
WHERE NOT EXISTS (
  SELECT 1 FROM pg_index index_data
  WHERE index_data.indrelid = foreign_key.conrelid
    AND index_data.indisvalid AND index_data.indpred IS NULL
    AND foreign_key.conkey <@ index_data.indkey::smallint[]
);

INSERT INTO p6_structure_issues
SELECT 'author_admin_fk', constraint_data.conname,
       'articles.author must remain a public pen name without admin_users FK'
FROM pg_constraint constraint_data
JOIN pg_class source_relation ON source_relation.oid = constraint_data.conrelid
JOIN pg_class target_relation ON target_relation.oid = constraint_data.confrelid
WHERE constraint_data.contype = 'f'
  AND source_relation.relname = 'articles' AND target_relation.relname = 'admin_users';

INSERT INTO p6_structure_issues
SELECT 'required_trigger', expected.name, 'legacy read-only trigger is missing'
FROM (VALUES ('trg_legacy_reviews_read_only'), ('trg_legacy_review_photos_read_only')) expected(name)
LEFT JOIN pg_trigger actual ON actual.tgname = expected.name AND NOT actual.tgisinternal
WHERE actual.oid IS NULL;

INSERT INTO p6_structure_issues
SELECT 'legacy_evidence', expected.name, 'P6 migration evidence is missing'
FROM (VALUES
  ('p6_legacy_reviews'), ('p6_legacy_articles'),
  ('p6_legacy_article_content_blocks'), ('p6_legacy_article_related_products'),
  ('p6_review_source'), ('p6_article_source'), ('p6_review_resolution')
) expected(name)
LEFT JOIN information_schema.tables actual
  ON actual.table_schema = 'migration' AND actual.table_name = expected.name
WHERE actual.table_name IS NULL;

INSERT INTO p6_structure_issues
SELECT 'movement_consumer_view', 'inventory_movement_dto_view',
       'movement DTO does not explicitly consume inventory_movement_items_view'
WHERE pg_get_viewdef('inventory_movement_dto_view'::regclass, TRUE)
      NOT LIKE '%inventory_movement_items_view%';

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*),
  'issues', coalesce(jsonb_agg(jsonb_build_object(
    'check', check_name, 'object', object_name, 'reason', reason
  ) ORDER BY check_name, object_name), '[]'::jsonb)
)) FROM p6_structure_issues;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p6_structure_issues) THEN
    RAISE EXCEPTION 'P6 structure validation failed with % issue(s)',
      (SELECT count(*) FROM p6_structure_issues);
  END IF;
END $$;
