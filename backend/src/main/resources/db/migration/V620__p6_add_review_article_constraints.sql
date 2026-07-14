-- P6 constraint/switch: prove complete source disposition, install the target
-- constraints, preserve legacy P0 structures in migration, and expose DTOs
-- backed only by normalized P5/P6 objects.

DO $$
BEGIN
  IF (SELECT count(*) FROM migration.p6_review_source) <> 38
     OR (SELECT count(*) FROM migration.p6_review_resolution) <> 38
     OR (SELECT count(*) FROM reviews_p6) <> 1
     OR (SELECT count(*) FROM legacy_reviews) <> 37
     OR (SELECT count(*) FROM migration.p6_review_resolution WHERE disposition = 'formal') <> 1
     OR (SELECT count(*) FROM migration.p6_review_resolution WHERE disposition = 'legacy') <> 37
     OR NOT EXISTS (
       SELECT 1 FROM migration.p6_review_resolution
       WHERE review_id = 'REV031' AND disposition = 'formal'
         AND order_item_id = 418
         AND resolution_method = 'EXACT_ORDER_CUSTOMER_PRODUCT_VARIANT'
         AND legacy_reason IS NULL
     )
     OR EXISTS (
       SELECT 1 FROM migration.p6_review_resolution
       WHERE (disposition = 'formal') <> (order_item_id IS NOT NULL)
          OR (disposition = 'legacy') <> (legacy_reason IS NOT NULL)
          OR disposition NOT IN ('formal', 'legacy')
     )
     OR EXISTS (
       SELECT source.id FROM migration.p6_review_source source
       EXCEPT
       SELECT id FROM reviews_p6
       EXCEPT
       SELECT id FROM legacy_reviews
     )
     OR EXISTS (
       SELECT id FROM reviews_p6
       INTERSECT
       SELECT id FROM legacy_reviews
     ) THEN
    RAISE EXCEPTION 'P6 guard: review disposition is incomplete, overlapping or changed';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM reviews_p6 review
    JOIN migration.p6_review_source source ON source.id = review.id
    JOIN order_items item ON item.id = review.order_item_id
    JOIN orders order_header ON order_header.id = item.order_id
    WHERE source.payload->>'orderId' <> item.order_id
       OR source.payload->>'customerId' <> order_header.customer_id
       OR source.payload->>'productId' <> item.product_id
       OR source.payload->>'variantId' <> item.variant_id
       OR review.rating <> (source.payload->>'rating')::smallint
       OR review.comment IS DISTINCT FROM source.payload->>'comment'
       OR review.created_at <> (source.payload->>'createdAt')::timestamp AT TIME ZONE 'Asia/Taipei'
  ) THEN
    RAISE EXCEPTION 'P6 guard: formal review does not match its authoritative purchase/source';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM legacy_reviews review
    JOIN migration.p6_review_source source ON source.id = review.id
    WHERE review.customer_id <> source.payload->>'customerId'
       OR review.product_id <> source.payload->>'productId'
       OR review.variant_id <> source.payload->>'variantId'
       OR review.sku_snapshot IS DISTINCT FROM source.payload->>'sku'
       OR review.buyer_name_snapshot IS DISTINCT FROM source.payload->>'buyerName'
       OR review.buyer_avatar_snapshot IS DISTINCT FROM source.payload->>'buyerAvatar'
       OR review.product_name_snapshot IS DISTINCT FROM source.payload->>'productName'
       OR review.rating <> (source.payload->>'rating')::smallint
       OR review.comment IS DISTINCT FROM source.payload->>'comment'
       OR review.created_at <> (source.payload->>'createdAt')::timestamp AT TIME ZONE 'Asia/Taipei'
       OR BTRIM(review.legacy_reason) = ''
  ) THEN
    RAISE EXCEPTION 'P6 guard: a legacy review or its quarantine reason differs from source';
  END IF;

  IF (SELECT count(*) FROM review_photos) <> (
       SELECT count(*) FROM migration.p6_review_source source
       JOIN reviews_p6 review ON review.id = source.id
       CROSS JOIN LATERAL jsonb_array_elements_text(source.payload->'photos') photo
     )
     OR (SELECT count(*) FROM legacy_review_photos) <> (
       SELECT count(*) FROM migration.p6_review_source source
       JOIN legacy_reviews review ON review.id = source.id
       CROSS JOIN LATERAL jsonb_array_elements_text(source.payload->'photos') photo
     )
     OR EXISTS (
       SELECT source.id, photo.ordinality - 1, photo.url
       FROM migration.p6_review_source source
       JOIN reviews_p6 review ON review.id = source.id
       CROSS JOIN LATERAL jsonb_array_elements_text(source.payload->'photos')
         WITH ORDINALITY photo(url, ordinality)
       EXCEPT SELECT review_id, sort_order, url FROM review_photos
     )
     OR EXISTS (
       SELECT source.id, photo.ordinality - 1, photo.url
       FROM migration.p6_review_source source
       JOIN legacy_reviews review ON review.id = source.id
       CROSS JOIN LATERAL jsonb_array_elements_text(source.payload->'photos')
         WITH ORDINALITY photo(url, ordinality)
       EXCEPT SELECT legacy_review_id, sort_order, url FROM legacy_review_photos
     ) THEN
    RAISE EXCEPTION 'P6 guard: review photos differ from source';
  END IF;

  IF EXISTS (
    SELECT 1 FROM migration.p6_review_source
    WHERE payload ?| ARRAY[
      'replied', 'replyText', 'replyAt', 'repliedBy', 'repliedByName', 'replyUpdatedAt',
      'reply_text', 'reply_at', 'replied_by', 'replied_by_name', 'reply_updated_at'
    ]
  ) THEN
    RAISE EXCEPTION 'P6 guard: official reply fields contain source payload';
  END IF;

  IF (SELECT count(*) FROM migration.p6_article_source) <> 6
     OR (SELECT count(*) FROM articles_p6) <> 6
     OR (SELECT count(*) FROM article_tags) <> 18
     OR (SELECT count(*) FROM article_content_blocks_p6) <> 41
     OR (SELECT count(*) FROM article_content_blocks_p6 WHERE block_type = 'heading') <> 12
     OR (SELECT count(*) FROM article_related_products_p6) <> 16 THEN
    RAISE EXCEPTION 'P6 guard: article target counts differ from frozen source';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM articles_p6 article
    JOIN migration.p6_article_source source ON source.id = article.id
    WHERE article.title <> source.payload->>'title'
       OR article.category <> source.payload->>'category'
       OR article.author <> source.payload->>'author'
       OR article.author_avatar_url IS DISTINCT FROM source.payload->>'authorAvatar'
       OR article.published_at <> (source.payload->>'publishedDate')::date::timestamp
          AT TIME ZONE 'Asia/Taipei'
       OR article.summary <> source.payload->>'excerpt'
       OR article.cover_image_url IS DISTINCT FROM source.payload->>'image'
       OR article.reading_minutes <> (source.payload->>'readTime')::integer
       OR article.featured <> (source.payload->>'isFeatured')::boolean
       OR article.status <> 'published'
  ) THEN
    RAISE EXCEPTION 'P6 guard: article master differs from source';
  END IF;

  IF EXISTS (
    SELECT source.id, tag.value #>> '{}'
    FROM migration.p6_article_source source
    CROSS JOIN LATERAL jsonb_array_elements(source.payload->'tags') tag(value)
    EXCEPT SELECT article_id, tag FROM article_tags
  ) OR EXISTS (
    SELECT source.id, block.ordinality - 1, block.payload->>'type',
           CASE WHEN block.payload->>'type' IN ('text', 'heading') THEN block.payload->>'value' END,
           CASE WHEN block.payload->>'type' = 'product' THEN block.payload->>'productId' END
    FROM migration.p6_article_source source
    CROSS JOIN LATERAL jsonb_array_elements(source.payload->'content')
      WITH ORDINALITY block(payload, ordinality)
    EXCEPT
    SELECT article_id, sort_order, block_type, text_content, product_id
    FROM article_content_blocks_p6
  ) OR EXISTS (
    SELECT source.id, related.value #>> '{}', related.ordinality - 1
    FROM migration.p6_article_source source
    CROSS JOIN LATERAL jsonb_array_elements(source.payload->'relatedProducts')
      WITH ORDINALITY related(value, ordinality)
    EXCEPT
    SELECT article_id, product_id, sort_order FROM article_related_products_p6
  ) THEN
    RAISE EXCEPTION 'P6 guard: article tags, blocks or related products differ from source';
  END IF;
END $$;

ALTER TABLE reviews_p6
  ADD CONSTRAINT pk_reviews PRIMARY KEY (id),
  ADD CONSTRAINT fk_reviews_order_item_id
    FOREIGN KEY (order_item_id) REFERENCES order_items(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT uq_reviews_order_item_id UNIQUE (order_item_id),
  ADD CONSTRAINT ck_reviews_rating CHECK (rating BETWEEN 1 AND 5);
CREATE INDEX idx_reviews_created_at ON reviews_p6(created_at);

ALTER TABLE review_photos
  ADD CONSTRAINT pk_review_photos PRIMARY KEY (review_id, sort_order),
  ADD CONSTRAINT fk_review_photos_review_id
    FOREIGN KEY (review_id) REFERENCES reviews_p6(id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  ADD CONSTRAINT ck_review_photos_sort_order CHECK (sort_order >= 0),
  ADD CONSTRAINT ck_review_photos_url CHECK (BTRIM(url) <> '');

ALTER TABLE legacy_reviews
  ADD CONSTRAINT pk_legacy_reviews PRIMARY KEY (id),
  ADD CONSTRAINT fk_legacy_reviews_customer_id
    FOREIGN KEY (customer_id) REFERENCES customers(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_legacy_reviews_product_id_variant_id
    FOREIGN KEY (product_id, variant_id) REFERENCES product_variants(product_id, id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT ck_legacy_reviews_rating CHECK (rating BETWEEN 1 AND 5),
  ADD CONSTRAINT ck_legacy_reviews_reason CHECK (BTRIM(legacy_reason) <> '');
CREATE INDEX idx_legacy_reviews_customer ON legacy_reviews(customer_id);
CREATE INDEX idx_legacy_reviews_product_variant ON legacy_reviews(product_id, variant_id);

ALTER TABLE legacy_review_photos
  ADD CONSTRAINT pk_legacy_review_photos PRIMARY KEY (legacy_review_id, sort_order),
  ADD CONSTRAINT fk_legacy_review_photos_legacy_review_id
    FOREIGN KEY (legacy_review_id) REFERENCES legacy_reviews(id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  ADD CONSTRAINT ck_legacy_review_photos_sort_order CHECK (sort_order >= 0),
  ADD CONSTRAINT ck_legacy_review_photos_url CHECK (BTRIM(url) <> '');

ALTER TABLE articles_p6
  ADD CONSTRAINT pk_articles PRIMARY KEY (id),
  ADD CONSTRAINT ck_articles_reading CHECK (reading_minutes >= 0),
  ADD CONSTRAINT ck_articles_status CHECK (status IN ('draft', 'published', 'archived')),
  ADD CONSTRAINT ck_articles_published CHECK (status <> 'published' OR published_at IS NOT NULL);
CREATE INDEX idx_articles_category_published ON articles_p6(category, published_at);
CREATE INDEX idx_articles_featured_published ON articles_p6(featured, published_at);

ALTER TABLE article_tags
  ADD CONSTRAINT pk_article_tags PRIMARY KEY (article_id, tag),
  ADD CONSTRAINT fk_article_tags_article_id
    FOREIGN KEY (article_id) REFERENCES articles_p6(id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  ADD CONSTRAINT ck_article_tags_tag CHECK (BTRIM(tag) <> '');
CREATE INDEX idx_article_tags_tag ON article_tags(tag);

ALTER TABLE article_content_blocks_p6
  ADD CONSTRAINT pk_article_content_blocks PRIMARY KEY (id),
  ADD CONSTRAINT fk_article_content_blocks_article_id
    FOREIGN KEY (article_id) REFERENCES articles_p6(id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  ADD CONSTRAINT fk_article_content_blocks_product_id
    FOREIGN KEY (product_id) REFERENCES products(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT uq_article_content_blocks_article_id_sort_order
    UNIQUE (article_id, sort_order),
  ADD CONSTRAINT ck_article_content_blocks_sort_order CHECK (sort_order >= 0),
  ADD CONSTRAINT ck_article_content_blocks_payload CHECK (
    (block_type IN ('text', 'heading') AND text_content IS NOT NULL AND product_id IS NULL)
    OR (block_type = 'product' AND text_content IS NULL AND product_id IS NOT NULL)
  );
CREATE INDEX idx_article_content_blocks_product ON article_content_blocks_p6(product_id);

ALTER TABLE article_related_products_p6
  ADD CONSTRAINT pk_article_related_products PRIMARY KEY (article_id, product_id),
  ADD CONSTRAINT fk_article_related_products_article_id
    FOREIGN KEY (article_id) REFERENCES articles_p6(id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  ADD CONSTRAINT fk_article_related_products_product_id
    FOREIGN KEY (product_id) REFERENCES products(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT uq_article_related_products_article_id_sort_order
    UNIQUE (article_id, sort_order),
  ADD CONSTRAINT ck_article_related_products_sort_order CHECK (sort_order >= 0);
CREATE INDEX idx_article_related_products_product ON article_related_products_p6(product_id);

ALTER TABLE migration.p6_review_resolution
  ADD CONSTRAINT fk_p6_review_resolution_source
    FOREIGN KEY (review_id) REFERENCES migration.p6_review_source(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_p6_review_resolution_order_item
    FOREIGN KEY (order_item_id) REFERENCES order_items(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT ck_p6_review_resolution_disposition CHECK (
    (disposition = 'formal' AND order_item_id IS NOT NULL AND legacy_reason IS NULL)
    OR (disposition = 'legacy' AND order_item_id IS NULL AND BTRIM(legacy_reason) <> '')
  );

-- Preserve the pre-P6 physical structures for rollback/evidence. Moving a
-- serial table also moves its owned sequence into the migration schema.
ALTER TABLE reviews SET SCHEMA migration;
ALTER TABLE migration.reviews RENAME TO p6_legacy_reviews;

ALTER TABLE article_content_blocks SET SCHEMA migration;
ALTER TABLE migration.article_content_blocks RENAME TO p6_legacy_article_content_blocks;
ALTER SEQUENCE migration.article_content_blocks_id_seq
  RENAME TO p6_legacy_article_content_blocks_id_seq;

ALTER TABLE article_related_products SET SCHEMA migration;
ALTER TABLE migration.article_related_products RENAME TO p6_legacy_article_related_products;

ALTER TABLE articles SET SCHEMA migration;
ALTER TABLE migration.articles RENAME TO p6_legacy_articles;

ALTER TABLE reviews_p6 RENAME TO reviews;
ALTER TABLE articles_p6 RENAME TO articles;
ALTER TABLE article_content_blocks_p6 RENAME TO article_content_blocks;
ALTER SEQUENCE article_content_blocks_p6_id_seq RENAME TO article_content_blocks_id_seq;
ALTER TABLE article_related_products_p6 RENAME TO article_related_products;

CREATE VIEW review_dto_view AS
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
         'buyerAvatar', COALESCE(customer.avatar_url, customer.avatar),
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

CREATE VIEW article_dto_view AS
SELECT article.id,
       jsonb_build_object(
         'id', article.id,
         'title', article.title,
         'category', article.category,
         'author', article.author,
         'authorAvatar', article.author_avatar_url,
         'publishedDate', to_char(article.published_at AT TIME ZONE 'Asia/Taipei', 'YYYY-MM-DD'),
         'readTime', article.reading_minutes,
         'image', article.cover_image_url,
         'excerpt', article.summary,
         'tags', COALESCE((
           SELECT jsonb_agg(tag.tag ORDER BY tag.tag)
           FROM article_tags tag WHERE tag.article_id = article.id
         ), '[]'::jsonb),
         'isFeatured', article.featured,
         'relatedProducts', COALESCE((
           SELECT jsonb_agg(related.product_id ORDER BY related.sort_order)
           FROM article_related_products related WHERE related.article_id = article.id
         ), '[]'::jsonb),
         'content', COALESCE((
           SELECT jsonb_agg(
             jsonb_strip_nulls(jsonb_build_object(
               'type', block.block_type,
               'value', block.text_content,
               'productId', block.product_id
             )) ORDER BY block.sort_order
           )
           FROM article_content_blocks block WHERE block.article_id = article.id
         ), '[]'::jsonb)
       ) AS payload
FROM articles article;

CREATE VIEW inventory_movement_dto_view AS
SELECT movement.id,
       jsonb_build_object(
         'id', movement.id,
         'movementNo', movement.movement_no,
         'legacyMovementId', movement.legacy_movement_id,
         'inventoryDomain', movement.inventory_domain,
         'movementType', movement.movement_type,
         'status', movement.status,
         'sourceLocationId', movement.source_location_id,
         'destinationLocationId', movement.destination_location_id,
         'employeeId', movement.employee_id,
         'occurredAt', to_char(movement.occurred_at AT TIME ZONE 'Asia/Taipei', 'YYYY-MM-DD HH24:MI:SS'),
         'items', COALESCE((
           SELECT jsonb_agg(jsonb_build_object(
             'inventoryDomain', item.inventory_domain,
             'variantId', item.variant_id,
             'sku', item.sku_snapshot,
             'productName', item.item_name_snapshot,
             'quantity', item.quantity,
             'sourceLocationId', movement.source_location_id,
             'destinationLocationId', movement.destination_location_id,
             'type', movement.movement_type
           ) ORDER BY item.id)
           FROM inventory_movement_items_view item
           WHERE item.movement_id = movement.id
         ), '[]'::jsonb)
       ) AS payload
FROM inventory_movements movement;

CREATE FUNCTION reject_legacy_review_write() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'legacy reviews are read-only migration evidence';
END $$;

CREATE TRIGGER trg_legacy_reviews_read_only
BEFORE INSERT OR UPDATE OR DELETE ON legacy_reviews
FOR EACH STATEMENT EXECUTE FUNCTION reject_legacy_review_write();

CREATE TRIGGER trg_legacy_review_photos_read_only
BEFORE INSERT OR UPDATE OR DELETE ON legacy_review_photos
FOR EACH STATEMENT EXECUTE FUNCTION reject_legacy_review_write();

COMMENT ON TABLE reviews IS
  'Formal verified-purchase reviews; order_item_id is the only authoritative relationship.';
COMMENT ON TABLE legacy_reviews IS
  'Read-only reviews without a uniquely provable order item; never writable through the formal review API.';
COMMENT ON COLUMN articles.author IS
  'Public author pen name. D-012 forbids an admin_users relationship.';
COMMENT ON VIEW inventory_movement_dto_view IS
  'P6 admin/report DTO built exclusively from P5 inventory_movements and inventory_movement_items_view.';
