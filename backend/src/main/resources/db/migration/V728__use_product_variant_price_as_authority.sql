-- SKU price is the only current catalog price authority.
-- Historical order-item prices remain immutable transaction snapshots.
ALTER TABLE products
  DROP CONSTRAINT ck_products_price,
  DROP COLUMN price;

