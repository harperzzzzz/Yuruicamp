-- equipment_images is the single source of truth for equipment imagery.
-- The row with sort_order = 0 is the main image used by product listings.
ALTER TABLE equipment_items
  DROP COLUMN main_image_url;

COMMENT ON COLUMN equipment_images.sort_order IS
  'Zero-based image order; sort_order = 0 is the main image.';
