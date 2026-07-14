\set ON_ERROR_STOP on

BEGIN;
CREATE TEMP TABLE p6_business_issues (
  check_name TEXT NOT NULL,
  reason TEXT NOT NULL
);

DO $$
BEGIN
  BEGIN
    INSERT INTO reviews (id, order_item_id, rating, comment)
    VALUES ('P6-TEST-DUPLICATE', 418, 5, 'must fail');
    INSERT INTO p6_business_issues VALUES
      ('one_review_per_order_item', 'duplicate order-item review was accepted');
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO reviews (id, order_item_id, rating, comment)
    VALUES ('P6-TEST-UNPURCHASED', 999999, 5, 'must fail');
    INSERT INTO p6_business_issues VALUES
      ('verified_purchase_fk', 'review without a purchased order item was accepted');
  EXCEPTION WHEN foreign_key_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO reviews (id, order_item_id, rating, comment)
    VALUES ('P6-TEST-RATING', 419, 6, 'must fail');
    INSERT INTO p6_business_issues VALUES
      ('review_rating', 'rating outside 1-5 was accepted');
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO review_photos (review_id, sort_order, url)
    VALUES ('REV031', 0, '');
    INSERT INTO p6_business_issues VALUES
      ('review_photo_url', 'blank review photo URL was accepted');
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    UPDATE legacy_reviews SET comment = 'must fail' WHERE id = 'REV001';
    INSERT INTO p6_business_issues VALUES
      ('legacy_review_read_only', 'legacy review update was accepted');
  EXCEPTION WHEN raise_exception THEN NULL;
  END;

  BEGIN
    INSERT INTO article_content_blocks (
      article_id, sort_order, block_type, text_content, product_id
    ) VALUES ('art-001', 0, 'text', 'duplicate order', NULL);
    INSERT INTO p6_business_issues VALUES
      ('article_block_order', 'duplicate article sort order was accepted');
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO article_content_blocks (
      article_id, sort_order, block_type, text_content, product_id
    ) VALUES ('art-001', 9990, 'heading', NULL, NULL);
    INSERT INTO p6_business_issues VALUES
      ('heading_payload', 'heading without text was accepted');
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO article_content_blocks (
      article_id, sort_order, block_type, text_content, product_id
    ) VALUES ('art-001', 9991, 'text', 'both payloads', 'P001');
    INSERT INTO p6_business_issues VALUES
      ('text_payload', 'text block with product payload was accepted');
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO article_content_blocks (
      article_id, sort_order, block_type, text_content, product_id
    ) VALUES ('art-001', 9992, 'product', 'illegal text', 'P001');
    INSERT INTO p6_business_issues VALUES
      ('product_payload', 'product block with text payload was accepted');
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO article_content_blocks (
      article_id, sort_order, block_type, text_content, product_id
    ) VALUES ('art-001', 9993, 'video', NULL, NULL);
    INSERT INTO p6_business_issues VALUES
      ('unknown_block_type', 'unknown block type was accepted');
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END $$;

INSERT INTO p6_business_issues
SELECT 'official_reply_schema', column_name || ': official reply column exists'
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name IN ('reviews','legacy_reviews')
  AND (column_name = 'replied' OR column_name LIKE 'reply\_%' ESCAPE '\'
       OR column_name LIKE 'replied\_%' ESCAPE '\');

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*),
  'issues', coalesce(jsonb_agg(jsonb_build_object(
    'check', check_name, 'reason', reason
  ) ORDER BY check_name), '[]'::jsonb)
)) FROM p6_business_issues;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p6_business_issues) THEN
    RAISE EXCEPTION 'P6 business validation failed with % issue(s)',
      (SELECT count(*) FROM p6_business_issues);
  END IF;
END $$;

ROLLBACK;
