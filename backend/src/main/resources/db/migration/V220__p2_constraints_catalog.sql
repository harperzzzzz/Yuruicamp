-- P2 contract: verify the normalized copy before removing legacy catalog JSONB
-- and cached stock fields, then install fixed-name constraints and views.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM products product
    LEFT JOIN equipment_items item ON item.id = product.item_id
    WHERE product.item_id IS NULL OR item.id IS NULL
  ) THEN
    RAISE EXCEPTION 'P2 guard: product to equipment mapping is incomplete';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM products product
    JOIN equipment_items item ON item.id = product.item_id
    JOIN product_categories category ON category.id = item.category_id
    JOIN brands brand ON brand.id = item.brand_id
    WHERE item.name IS DISTINCT FROM product.name
       OR category.name IS DISTINCT FROM product.category
       OR brand.name IS DISTINCT FROM product.brand
       OR item.main_image_url IS DISTINCT FROM product.image
       OR item.description IS DISTINCT FROM product.description
  ) THEN
    RAISE EXCEPTION 'P2 guard: normalized equipment scalar fields differ from products';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM products product
    WHERE COALESCE(jsonb_array_length(product.images), 0) <> (
            SELECT COUNT(*) FROM equipment_images image WHERE image.item_id = product.id
          )
       OR COALESCE(jsonb_array_length(product.tags), 0) <> (
            SELECT COUNT(*) FROM equipment_tags tag WHERE tag.item_id = product.id
          )
       OR COALESCE(jsonb_array_length(product.interest_tags), 0) <> (
            SELECT COUNT(*) FROM equipment_interest_tags tag WHERE tag.item_id = product.id
          )
       OR (SELECT count(*) FROM jsonb_object_keys(COALESCE(product.specifications, '{}'::jsonb))) <> (
            SELECT COUNT(*) FROM equipment_specifications specification
            WHERE specification.item_id = product.id
          )
  ) THEN
    RAISE EXCEPTION 'P2 guard: normalized equipment collection counts differ from products';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM products product
    CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(product.images, '[]'::jsonb))
      WITH ORDINALITY source_image(url, ordinality)
    LEFT JOIN equipment_images image
      ON image.item_id = product.id
     AND image.sort_order = source_image.ordinality::integer - 1
     AND image.url = source_image.url
    WHERE image.item_id IS NULL
  ) OR EXISTS (
    SELECT 1
    FROM products product
    CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(product.tags, '[]'::jsonb)) source_tag(tag)
    LEFT JOIN equipment_tags tag ON tag.item_id = product.id AND tag.tag = source_tag.tag
    WHERE tag.item_id IS NULL
  ) OR EXISTS (
    SELECT 1
    FROM products product
    CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(product.interest_tags, '[]'::jsonb)) source_tag(tag)
    LEFT JOIN equipment_interest_tags tag ON tag.item_id = product.id AND tag.tag = source_tag.tag
    WHERE tag.item_id IS NULL
  ) OR EXISTS (
    SELECT 1
    FROM products product
    CROSS JOIN LATERAL jsonb_each_text(COALESCE(product.specifications, '{}'::jsonb)) source_spec(spec_key, value)
    LEFT JOIN equipment_specifications specification
      ON specification.item_id = product.id
     AND specification.spec_key = source_spec.spec_key
     AND specification.value = source_spec.value
    WHERE specification.item_id IS NULL
  ) THEN
    RAISE EXCEPTION 'P2 guard: normalized equipment collection values differ from products';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM product_variants variant
    CROSS JOIN LATERAL jsonb_each_text(COALESCE(variant.branch_stock, '{}'::jsonb)) source_stock(location_code, quantity)
    LEFT JOIN inventory_locations location
      ON location.code = source_stock.location_code
     AND location.inventory_domain = 'store'
    LEFT JOIN inventory_stocks stock
      ON stock.location_id = location.id
     AND stock.variant_id = variant.id
     AND stock.on_hand_quantity = source_stock.quantity::integer
    WHERE location.id IS NULL OR stock.variant_id IS NULL
  ) THEN
    RAISE EXCEPTION 'P2 guard: store stock location mapping or quantity differs';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM products product
    WHERE product.total_stock IS DISTINCT FROM (
      SELECT COALESCE(SUM(stock.on_hand_quantity), 0)::integer
      FROM product_variants variant
      LEFT JOIN inventory_stocks stock ON stock.variant_id = variant.id
      WHERE variant.product_id = product.id
    )
  ) THEN
    RAISE EXCEPTION 'P2 guard: normalized stock total differs from products.total_stock';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM migration.p2_campground_tag_source source
    WHERE jsonb_array_length(source.environment_tags) <> (
            SELECT COUNT(*) FROM campground_environment_tags relation
            WHERE relation.campground_id = source.campground_id
          )
       OR jsonb_array_length(source.facility_tags) <> (
            SELECT COUNT(*) FROM campground_facility_tags relation
            WHERE relation.campground_id = source.campground_id
          )
  ) THEN
    RAISE EXCEPTION 'P2 guard: normalized campground tag counts differ';
  END IF;
END
$$;

ALTER TABLE equipment_items
  ADD CONSTRAINT fk_equipment_items_category_id
    FOREIGN KEY (category_id) REFERENCES product_categories(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_equipment_items_brand_id
    FOREIGN KEY (brand_id) REFERENCES brands(id)
    ON UPDATE CASCADE ON DELETE RESTRICT;
CREATE INDEX idx_equipment_items_category_active
  ON equipment_items(category_id, active);
CREATE INDEX idx_equipment_items_brand ON equipment_items(brand_id);

ALTER TABLE equipment_images
  ADD CONSTRAINT fk_equipment_images_item_id
    FOREIGN KEY (item_id) REFERENCES equipment_items(id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  ADD CONSTRAINT ck_equipment_images_sort_order CHECK (sort_order >= 0),
  ADD CONSTRAINT ck_equipment_images_value CHECK (BTRIM(url) <> '');
CREATE INDEX idx_equipment_images_sort_order ON equipment_images(sort_order);

ALTER TABLE equipment_tags
  ADD CONSTRAINT fk_equipment_tags_item_id
    FOREIGN KEY (item_id) REFERENCES equipment_items(id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  ADD CONSTRAINT ck_equipment_tags_value CHECK (BTRIM(tag) <> '');
CREATE INDEX idx_equipment_tags_tag ON equipment_tags(tag);

ALTER TABLE equipment_interest_tags
  ADD CONSTRAINT fk_equipment_interest_tags_item_id
    FOREIGN KEY (item_id) REFERENCES equipment_items(id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  ADD CONSTRAINT ck_equipment_interest_tags_value CHECK (BTRIM(tag) <> '');
CREATE INDEX idx_equipment_interest_tags_tag ON equipment_interest_tags(tag);

ALTER TABLE equipment_specifications
  ADD CONSTRAINT fk_equipment_specifications_item_id
    FOREIGN KEY (item_id) REFERENCES equipment_items(id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  ADD CONSTRAINT ck_equipment_specifications_value CHECK (BTRIM(value) <> '');
CREATE INDEX idx_equipment_specifications_spec_key
  ON equipment_specifications(spec_key);

ALTER TABLE environment_tags
  ADD CONSTRAINT uq_environment_tags_code UNIQUE (code),
  ADD CONSTRAINT uq_environment_tags_label UNIQUE (label),
  ADD CONSTRAINT ck_environment_tags_sort_order CHECK (sort_order >= 0);
CREATE INDEX idx_environment_tags_active_sort
  ON environment_tags(active, sort_order);

ALTER TABLE facility_tags
  ADD CONSTRAINT uq_facility_tags_code UNIQUE (code),
  ADD CONSTRAINT uq_facility_tags_label UNIQUE (label),
  ADD CONSTRAINT ck_facility_tags_sort_order CHECK (sort_order >= 0);
CREATE INDEX idx_facility_tags_active_sort
  ON facility_tags(active, sort_order);

ALTER TABLE campground_environment_tags
  ADD CONSTRAINT fk_campground_environment_tags_campground_id
    FOREIGN KEY (campground_id) REFERENCES campgrounds(id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  ADD CONSTRAINT fk_campground_environment_tags_tag_id
    FOREIGN KEY (tag_id) REFERENCES environment_tags(id)
    ON UPDATE CASCADE ON DELETE RESTRICT;
CREATE INDEX idx_campground_environment_tags_tag
  ON campground_environment_tags(tag_id);

ALTER TABLE campground_facility_tags
  ADD CONSTRAINT fk_campground_facility_tags_campground_id
    FOREIGN KEY (campground_id) REFERENCES campgrounds(id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  ADD CONSTRAINT fk_campground_facility_tags_tag_id
    FOREIGN KEY (tag_id) REFERENCES facility_tags(id)
    ON UPDATE CASCADE ON DELETE RESTRICT;
CREATE INDEX idx_campground_facility_tags_tag
  ON campground_facility_tags(tag_id);

ALTER TABLE products DROP CONSTRAINT fk_products_rental_sku;
ALTER TABLE products RENAME CONSTRAINT products_pkey TO pk_products;
ALTER TABLE products
  ALTER COLUMN status DROP DEFAULT,
  ALTER COLUMN status TYPE VARCHAR(16) USING status::text,
  ALTER COLUMN status SET DEFAULT 'active',
  ALTER COLUMN item_id SET NOT NULL,
  ADD CONSTRAINT fk_products_item_id
    FOREIGN KEY (item_id) REFERENCES equipment_items(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT uq_products_item_id UNIQUE (item_id),
  ADD CONSTRAINT ck_products_price CHECK (price >= 0),
  ADD CONSTRAINT ck_products_status CHECK (status IN ('active', 'inactive'));
CREATE INDEX idx_products_status ON products(status);

ALTER TABLE product_variants
  DROP CONSTRAINT product_variants_product_id_fkey,
  DROP CONSTRAINT product_variants_product_id_sku_key;
ALTER TABLE product_variants RENAME CONSTRAINT product_variants_pkey TO pk_product_variants;
DROP INDEX idx_product_variants_product;
ALTER TABLE product_variants
  ALTER COLUMN color TYPE VARCHAR(100),
  ALTER COLUMN size TYPE VARCHAR(100),
  ALTER COLUMN specification SET NOT NULL,
  ALTER COLUMN price SET NOT NULL,
  ADD CONSTRAINT fk_product_variants_product_id
    FOREIGN KEY (product_id) REFERENCES products(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT uq_product_variants_sku UNIQUE (sku),
  ADD CONSTRAINT uq_product_variants_product_id_id UNIQUE (product_id, id),
  ADD CONSTRAINT ck_product_variants_price CHECK (price >= 0),
  ADD CONSTRAINT ck_product_variants_status CHECK (status IN ('active', 'inactive'));
CREATE INDEX idx_product_variants_product_status
  ON product_variants(product_id, status);

ALTER TABLE inventory_stocks
  ADD CONSTRAINT fk_inventory_stocks_location_id
    FOREIGN KEY (location_id) REFERENCES inventory_locations(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_inventory_stocks_variant_id
    FOREIGN KEY (variant_id) REFERENCES product_variants(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT ck_inventory_stocks_on_hand CHECK (on_hand_quantity >= 0);
CREATE INDEX idx_inventory_stocks_variant ON inventory_stocks(variant_id);

ALTER TABLE products
  DROP COLUMN rental_id,
  DROP COLUMN rental_enabled,
  DROP COLUMN name,
  DROP COLUMN category,
  DROP COLUMN brand,
  DROP COLUMN interest_tags,
  DROP COLUMN image,
  DROP COLUMN images,
  DROP COLUMN description,
  DROP COLUMN specifications,
  DROP COLUMN tags,
  DROP COLUMN total_stock;

ALTER TABLE product_variants
  DROP COLUMN label,
  DROP COLUMN branch_stock;

ALTER TABLE campgrounds
  DROP COLUMN environment_tags,
  DROP COLUMN facility_tags;

CREATE VIEW product_stock_summary AS
SELECT
  product.id AS product_id,
  COALESCE(SUM(stock.on_hand_quantity), 0)::BIGINT AS total_on_hand,
  0::BIGINT AS total_reserved,
  COALESCE(SUM(stock.on_hand_quantity), 0)::BIGINT AS total_available
FROM products product
LEFT JOIN product_variants variant ON variant.product_id = product.id
LEFT JOIN inventory_stocks stock ON stock.variant_id = variant.id
GROUP BY product.id;

COMMENT ON VIEW product_stock_summary IS
  'P2 store stock summary. P4 replaces total_reserved with the active reservation ledger.';
