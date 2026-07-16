-- Article author identity, avatar, and estimated reading time are no longer
-- product requirements. Drop their DTO fields and the underlying columns.

DROP VIEW article_dto_view;

ALTER TABLE articles
  DROP CONSTRAINT ck_articles_reading;

ALTER TABLE articles
  DROP COLUMN author,
  DROP COLUMN author_avatar_url,
  DROP COLUMN reading_minutes;

CREATE VIEW article_dto_view AS
SELECT article.id,
       jsonb_build_object(
         'id', article.id,
         'title', article.title,
         'category', article.category,
         'publishedDate', to_char(article.published_at AT TIME ZONE 'Asia/Taipei', 'YYYY-MM-DD'),
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
