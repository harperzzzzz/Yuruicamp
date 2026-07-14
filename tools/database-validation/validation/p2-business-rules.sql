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
  INSERT INTO products (id, item_id, price, status)
  VALUES ('P2-TEST-PRODUCT', item_id_value, 1, 'active');
  INSERT INTO product_variants (
    id, product_id, sku, specification, price, status
  ) VALUES (
    'P2-TEST-VARIANT', 'P2-TEST-PRODUCT', 'P2-TEST-SKU', 'standard', 1, 'active'
  );
  INSERT INTO inventory_stocks (location_id, variant_id, on_hand_quantity)
  VALUES ('main', 'P2-TEST-VARIANT', 1);

  BEGIN
    INSERT INTO products (id, item_id, price, status)
    VALUES ('P2-TEST-DUPLICATE-ITEM', item_id_value, 1, 'active');
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
    UPDATE products SET price = -1 WHERE id = 'P2-TEST-PRODUCT';
    RAISE EXCEPTION 'negative product price was accepted';
  EXCEPTION WHEN check_violation THEN NULL;
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
