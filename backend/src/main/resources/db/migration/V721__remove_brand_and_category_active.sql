-- Brand and category availability is derived from the products that reference
-- them. Neither master table has an independent deactivate workflow.
DROP INDEX IF EXISTS idx_brands_active_sort;
DROP INDEX IF EXISTS idx_product_categories_active_sort;

ALTER TABLE brands
  DROP COLUMN active;

ALTER TABLE product_categories
  DROP COLUMN active;
