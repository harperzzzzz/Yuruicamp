DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM order_items item
    JOIN product_variants variant ON variant.id = item.variant_id
    WHERE variant.product_id <> item.product_id
  ) THEN
    RAISE EXCEPTION
      'Cannot enforce order item product/variant pairing: mismatched rows exist';
  END IF;
END $$;

ALTER TABLE order_items
  DROP CONSTRAINT fk_order_items_product_id,
  DROP CONSTRAINT fk_order_items_variant_id,
  ADD CONSTRAINT fk_order_items_product_id_variant_id
    FOREIGN KEY (product_id, variant_id)
    REFERENCES product_variants (product_id, id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT;

DROP INDEX idx_order_items_product;

CREATE INDEX idx_order_items_product_variant
  ON order_items (product_id, variant_id);

