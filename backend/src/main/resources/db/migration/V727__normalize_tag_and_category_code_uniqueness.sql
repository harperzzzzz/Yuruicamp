ALTER TABLE product_categories
  DROP CONSTRAINT uq_product_categories_code;

CREATE UNIQUE INDEX uq_product_categories_code
  ON product_categories (LOWER(BTRIM(code)));

CREATE UNIQUE INDEX uq_equipment_tags_item_tag_normalized
  ON equipment_tags (item_id, LOWER(BTRIM(tag)));

CREATE UNIQUE INDEX uq_equipment_interest_tags_item_tag_normalized
  ON equipment_interest_tags (item_id, LOWER(BTRIM(tag)));
