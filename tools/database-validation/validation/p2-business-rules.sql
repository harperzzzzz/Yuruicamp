\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
  category_id_value BIGINT;
  brand_id_value VARCHAR(32);
  item_id_value VARCHAR(32) := 'P2-TEST-ITEM';
BEGIN
  SELECT id INTO category_id_value FROM product_categories ORDER BY id LIMIT 1;
  SELECT id INTO brand_id_value FROM brands ORDER BY id LIMIT 1;

  INSERT INTO equipment_items (id, category_id, brand_id, name)
  VALUES (item_id_value, category_id_value, brand_id_value, 'P2 Test Item');
  INSERT INTO equipment_images (item_id, sort_order, url)
  VALUES (item_id_value, 0, '/p2-test.jpg');
  INSERT INTO products (id, item_id, status)
  VALUES ('P2-TEST-PRODUCT', item_id_value, 'active');
  INSERT INTO product_variants (
    id, product_id, sku, specification, price, status
  ) VALUES (
    'P2-TEST-VARIANT', 'P2-TEST-PRODUCT', 'P2-TEST-SKU', 'standard', 1, 'active'
  );
  INSERT INTO inventory_stocks (location_id, variant_id, on_hand_quantity)
  VALUES ('main', 'P2-TEST-VARIANT', 1);

  UPDATE products
  SET updated_at = TIMESTAMPTZ '2000-01-01 00:00:00+00'
  WHERE id = 'P2-TEST-PRODUCT';
  IF (SELECT updated_at FROM products WHERE id = 'P2-TEST-PRODUCT')
       = TIMESTAMPTZ '2000-01-01 00:00:00+00' THEN
    RAISE EXCEPTION 'products.updated_at was not refreshed by its trigger';
  END IF;

  UPDATE product_variants
  SET updated_at = TIMESTAMPTZ '2000-01-01 00:00:00+00'
  WHERE id = 'P2-TEST-VARIANT';
  IF (SELECT updated_at FROM product_variants WHERE id = 'P2-TEST-VARIANT')
       = TIMESTAMPTZ '2000-01-01 00:00:00+00' THEN
    RAISE EXCEPTION 'product_variants.updated_at was not refreshed by its trigger';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM sellable_product_variants
    WHERE product_id = 'P2-TEST-PRODUCT'
      AND variant_id = 'P2-TEST-VARIANT'
  ) THEN
    RAISE EXCEPTION 'active product variant was excluded from sellable view';
  END IF;

  UPDATE equipment_items SET active = FALSE WHERE id = item_id_value;
  IF EXISTS (
    SELECT 1 FROM sellable_product_variants
    WHERE variant_id = 'P2-TEST-VARIANT'
  ) THEN
    RAISE EXCEPTION 'inactive equipment item remained sellable';
  END IF;
  UPDATE equipment_items SET active = TRUE WHERE id = item_id_value;

  UPDATE products SET status = 'inactive' WHERE id = 'P2-TEST-PRODUCT';
  IF EXISTS (
    SELECT 1 FROM sellable_product_variants
    WHERE variant_id = 'P2-TEST-VARIANT'
  ) THEN
    RAISE EXCEPTION 'inactive product remained sellable';
  END IF;
  UPDATE products SET status = 'active' WHERE id = 'P2-TEST-PRODUCT';

  UPDATE product_variants SET status = 'inactive' WHERE id = 'P2-TEST-VARIANT';
  IF EXISTS (
    SELECT 1 FROM sellable_product_variants
    WHERE variant_id = 'P2-TEST-VARIANT'
  ) THEN
    RAISE EXCEPTION 'inactive product variant remained sellable';
  END IF;
  UPDATE product_variants SET status = 'active' WHERE id = 'P2-TEST-VARIANT';

  BEGIN
    INSERT INTO products (id, item_id, status)
    VALUES ('P2-TEST-DUPLICATE-ITEM', item_id_value, 'active');
    RAISE EXCEPTION 'one equipment item was accepted by two products';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO product_variants (
      id, product_id, sku, specification, price, status
    ) VALUES (
      'P2-TEST-DUPLICATE-SKU', 'P2-TEST-PRODUCT', 'P2-TEST-SKU', 'duplicate', 1, 'active'
    );
    RAISE EXCEPTION 'duplicate SKU was accepted';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO product_variants (
      id, product_id, sku, specification, price, status
    ) VALUES (
      'P2-TEST-DUPLICATE-SPEC', 'P2-TEST-PRODUCT',
      'P2-TEST-UNIQUE-SKU', 'standard', 1, 'active'
    );
    RAISE EXCEPTION 'duplicate product color/size/specification was accepted';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  BEGIN
    UPDATE product_variants SET price = -1 WHERE id = 'P2-TEST-VARIANT';
    RAISE EXCEPTION 'negative variant price was accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    UPDATE inventory_stocks SET on_hand_quantity = -1
    WHERE variant_id = 'P2-TEST-VARIANT';
    RAISE EXCEPTION 'negative stock was accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    DELETE FROM equipment_items WHERE id = item_id_value;
    RAISE EXCEPTION 'referenced equipment item was physically deleted';
  EXCEPTION WHEN integrity_constraint_violation THEN NULL;
  END;

  DELETE FROM inventory_stocks WHERE variant_id = 'P2-TEST-VARIANT';
  DELETE FROM product_variants WHERE id = 'P2-TEST-VARIANT';
  DELETE FROM products WHERE id = 'P2-TEST-PRODUCT';
  DELETE FROM equipment_items WHERE id = item_id_value;
  IF EXISTS (SELECT 1 FROM equipment_images WHERE item_id = item_id_value) THEN
    RAISE EXCEPTION 'equipment child rows did not cascade';
  END IF;
END $$;

ROLLBACK;
SELECT jsonb_pretty(jsonb_build_object('issueCount', 0, 'result', 'P2 business-rule cases passed'));
