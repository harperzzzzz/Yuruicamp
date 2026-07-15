ALTER TABLE brands
  ADD CONSTRAINT ck_brands_name
  CHECK (BTRIM(name) <> '');

ALTER TABLE product_categories
  ADD CONSTRAINT ck_product_categories_code
  CHECK (BTRIM(code) <> ''),
  ADD CONSTRAINT ck_product_categories_name
  CHECK (BTRIM(name) <> '');

ALTER TABLE equipment_items
  ADD CONSTRAINT ck_equipment_items_name
  CHECK (BTRIM(name) <> '');

ALTER TABLE equipment_specifications
  ADD CONSTRAINT ck_equipment_specifications_spec_key
  CHECK (BTRIM(spec_key) <> '');
