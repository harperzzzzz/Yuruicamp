-- Brand and category names are unique after trimming surrounding whitespace
-- and folding case, so values such as "Coleman" and " coleman " conflict.
ALTER TABLE brands
  DROP CONSTRAINT uq_brands_name;

ALTER TABLE product_categories
  DROP CONSTRAINT uq_product_categories_name;

CREATE UNIQUE INDEX uq_brands_name
  ON brands (LOWER(BTRIM(name)));

CREATE UNIQUE INDEX uq_product_categories_name
  ON product_categories (LOWER(BTRIM(name)));
