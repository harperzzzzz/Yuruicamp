CREATE VIEW sellable_product_variants AS
SELECT
  product.id AS product_id,
  product.item_id,
  variant.id AS variant_id,
  variant.sku,
  variant.color,
  variant.size,
  variant.specification,
  variant.price
FROM equipment_items item
JOIN products product
  ON product.item_id = item.id
JOIN product_variants variant
  ON variant.product_id = product.id
WHERE item.active = TRUE
  AND product.status = 'active'
  AND variant.status = 'active';

COMMENT ON VIEW sellable_product_variants IS
  'Canonical read model for product listing, detail, cart validation, and checkout repricing.';

