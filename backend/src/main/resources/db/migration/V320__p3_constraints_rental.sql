-- P3 contract: reconcile frozen rental sources, install the final rental
-- constraints and swap legacy public stock/listing tables into migration audit
-- storage. No P4 reservation or booking target is created here.

DO $$
BEGIN
  IF (SELECT count(*) FROM migration.p3_rental_sku_source)
     <> (SELECT count(*) FROM rental_skus) THEN
    RAISE EXCEPTION 'P3 guard: rental_skus row count differs from source';
  END IF;

  IF (SELECT count(*)
      FROM migration.p3_rental_sku_source source
      CROSS JOIN LATERAL jsonb_array_elements(source.payload->'variants') value)
     <> (SELECT count(*) FROM rental_sku_variants) THEN
    RAISE EXCEPTION 'P3 guard: rental variant row count differs from source';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM migration.p3_rental_sku_source source
    LEFT JOIN rental_skus rental ON rental.id = source.rental_sku_id
    LEFT JOIN equipment_items item ON item.id = rental.item_id
    LEFT JOIN product_categories category ON category.id = item.category_id
    LEFT JOIN brands brand ON brand.id = item.brand_id
    WHERE rental.id IS NULL OR item.id IS NULL
       OR rental.item_id IS DISTINCT FROM source.payload->>'productId'
       OR item.name IS DISTINCT FROM source.payload->>'name'
       OR item.main_image_url IS DISTINCT FROM source.payload->>'image'
       OR category.name IS DISTINCT FROM source.payload->>'category'
       OR brand.name IS DISTINCT FROM source.payload->>'brand'
  ) THEN
    RAISE EXCEPTION 'P3 guard: rental to equipment mapping differs from source';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM migration.p3_rental_sku_source source
    CROSS JOIN LATERAL jsonb_array_elements(source.payload->'variants') source_variant(value)
    LEFT JOIN rental_sku_variants variant ON variant.id = source_variant.value->>'id'
    WHERE variant.id IS NULL
       OR variant.rental_sku_id IS DISTINCT FROM source.rental_sku_id
       OR variant.sku IS DISTINCT FROM source_variant.value->>'id'
       OR COALESCE(variant.color, '') IS DISTINCT FROM COALESCE(source_variant.value->>'color', '')
       OR COALESCE(variant.size, '') IS DISTINCT FROM COALESCE(source_variant.value->>'size', '')
       OR variant.specification IS DISTINCT FROM source_variant.value->>'label'
  ) THEN
    RAISE EXCEPTION 'P3 guard: rental variant fields differ from source';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM migration.p3_rental_sku_source source
    CROSS JOIN LATERAL jsonb_array_elements(source.payload->'variants') source_variant(value)
    CROSS JOIN LATERAL jsonb_each_text(source_variant.value->'camp') source_stock(location_id, quantity)
    LEFT JOIN rental_sku_variant_stocks_p3 stock
      ON stock.location_id = source_stock.location_id
     AND stock.rental_sku_variant_id = source_variant.value->>'id'
    WHERE stock.rental_sku_variant_id IS NULL
       OR stock.on_hand_quantity <> source_stock.quantity::integer
  ) OR (SELECT count(*) FROM rental_sku_variant_stocks_p3) <> (
    SELECT count(*)
    FROM migration.p3_rental_sku_source source
    CROSS JOIN LATERAL jsonb_array_elements(source.payload->'variants') source_variant(value)
    CROSS JOIN LATERAL jsonb_each(source_variant.value->'camp') source_stock
  ) THEN
    RAISE EXCEPTION 'P3 guard: rental stock rows differ from source';
  END IF;

  IF (SELECT count(*) FROM campground_rental_locations) <> 8
     OR EXISTS (
       SELECT 1
       FROM campgrounds campground
       LEFT JOIN campground_rental_locations mapping
         ON mapping.campground_id = campground.id
       LEFT JOIN inventory_locations location
         ON location.id = mapping.location_id
       WHERE mapping.campground_id IS NULL
          OR mapping.location_id IS DISTINCT FROM campground.id
          OR location.inventory_domain <> 'rental'
          OR location.type <> 'campground'
     )
     OR EXISTS (
       SELECT 1 FROM campground_rental_locations
       WHERE campground_id = 'C001' OR location_id = 'C001'
     ) THEN
    RAISE EXCEPTION 'P3 guard: C002-C009 rental location mapping is incomplete or invalid';
  END IF;

  IF (SELECT count(*) FROM migration.p3_listing_source)
     <> (SELECT count(*) FROM rental_listings_p3)
     OR EXISTS (
       SELECT 1
       FROM migration.p3_listing_source source
       LEFT JOIN rental_listings_p3 listing ON listing.id = source.listing_id
       LEFT JOIN campground_rental_locations mapping
         ON mapping.campground_id = listing.campground_id
       LEFT JOIN rental_sku_variant_stocks_p3 stock
         ON stock.location_id = mapping.location_id
        AND stock.rental_sku_variant_id = listing.rental_sku_variant_id
       WHERE listing.id IS NULL
          OR listing.campground_id IS DISTINCT FROM source.payload->>'campgroundId'
          OR listing.rental_sku_variant_id IS DISTINCT FROM source.payload->>'variantId'
          OR listing.price_per_day_weekday IS DISTINCT FROM
               (source.payload->'pricing'->>'pricePerDayWeekday')::numeric
          OR listing.price_per_day_holiday IS DISTINCT FROM
               (source.payload->'pricing'->>'pricePerDayHoliday')::numeric
          OR listing.discount IS DISTINCT FROM (source.payload->'pricing'->>'discount')::numeric
          OR listing.terrain IS DISTINCT FROM source.payload->>'terrainTag'
          OR listing.description IS DISTINCT FROM source.payload->>'description'
          OR stock.on_hand_quantity IS DISTINCT FROM (source.payload->>'stock')::integer
     ) THEN
    RAISE EXCEPTION 'P3 guard: rental listing fields or stock differ from source';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM migration.p3_rental_min_stock_source minimum
    LEFT JOIN rental_skus rental ON rental.id = minimum.rental_sku_id
    LEFT JOIN inventory_locations location ON location.id = minimum.location_id
    WHERE rental.id IS NULL OR location.id IS NULL
       OR location.inventory_domain <> 'rental'
       OR minimum.quantity < 0
  ) THEN
    RAISE EXCEPTION 'P3 guard: rental minimum-stock source mapping is incomplete';
  END IF;
END
$$;

ALTER TABLE rental_skus
  DROP CONSTRAINT rental_skus_product_id_fkey;
ALTER TABLE rental_skus RENAME CONSTRAINT rental_skus_pkey TO pk_rental_skus;
ALTER TABLE rental_skus
  ALTER COLUMN item_id SET NOT NULL,
  ADD CONSTRAINT fk_rental_skus_item_id
    FOREIGN KEY (item_id) REFERENCES equipment_items(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT uq_rental_skus_item_id UNIQUE (item_id),
  ADD CONSTRAINT ck_rental_skus_status CHECK (status IN ('active', 'inactive'));
CREATE INDEX idx_rental_skus_status ON rental_skus(status);

ALTER TABLE rental_sku_variants
  ADD CONSTRAINT fk_rental_sku_variants_rental_sku_id
    FOREIGN KEY (rental_sku_id) REFERENCES rental_skus(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT uq_rental_sku_variants_sku UNIQUE (sku),
  ADD CONSTRAINT uq_rental_sku_variants_rental_sku_id_id
    UNIQUE (rental_sku_id, id),
  ADD CONSTRAINT ck_rental_sku_variants_status
    CHECK (status IN ('active', 'inactive'));
CREATE INDEX idx_rental_sku_variants_sku_status
  ON rental_sku_variants(rental_sku_id, status);

ALTER TABLE campground_rental_locations
  ADD CONSTRAINT fk_campground_rental_locations_campground_id
    FOREIGN KEY (campground_id) REFERENCES campgrounds(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_campground_rental_locations_location_id
    FOREIGN KEY (location_id) REFERENCES inventory_locations(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT uq_campground_rental_locations_location_id UNIQUE (location_id);

CREATE FUNCTION enforce_campground_rental_location_type()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  location_domain VARCHAR(16);
  location_type VARCHAR(32);
BEGIN
  SELECT inventory_domain, type
  INTO location_domain, location_type
  FROM inventory_locations
  WHERE id = NEW.location_id;

  IF location_domain IS DISTINCT FROM 'rental'
     OR location_type IS DISTINCT FROM 'campground' THEN
    RAISE EXCEPTION 'location % must be an active rental campground location', NEW.location_id
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END
$$;

CREATE CONSTRAINT TRIGGER trg_campground_rental_locations_type
AFTER INSERT OR UPDATE OF location_id ON campground_rental_locations
DEFERRABLE INITIALLY IMMEDIATE
FOR EACH ROW EXECUTE FUNCTION enforce_campground_rental_location_type();

CREATE FUNCTION protect_mapped_rental_location_type()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM campground_rental_locations mapping
    WHERE mapping.location_id = NEW.id
  ) AND (NEW.inventory_domain <> 'rental' OR NEW.type <> 'campground') THEN
    RAISE EXCEPTION 'mapped rental location % must remain rental/campground', NEW.id
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END
$$;

CREATE TRIGGER trg_inventory_locations_protect_rental_mapping
BEFORE UPDATE OF inventory_domain, type ON inventory_locations
FOR EACH ROW EXECUTE FUNCTION protect_mapped_rental_location_type();

ALTER TABLE rental_sku_variant_stocks_p3
  ADD CONSTRAINT fk_rental_sku_variant_stocks_location_id
    FOREIGN KEY (location_id) REFERENCES inventory_locations(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_rental_sku_variant_stocks_rental_sku_variant_id
    FOREIGN KEY (rental_sku_variant_id) REFERENCES rental_sku_variants(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT ck_rental_sku_variant_stocks_on_hand
    CHECK (on_hand_quantity >= 0);
CREATE INDEX idx_rental_sku_variant_stocks_variant
  ON rental_sku_variant_stocks_p3(rental_sku_variant_id);

ALTER TABLE rental_listings_p3
  ADD CONSTRAINT fk_rental_listings_campground_id
    FOREIGN KEY (campground_id) REFERENCES campgrounds(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_rental_listings_campground_location
    FOREIGN KEY (campground_id) REFERENCES campground_rental_locations(campground_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_rental_listings_rental_sku_variant_id
    FOREIGN KEY (rental_sku_variant_id) REFERENCES rental_sku_variants(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT uq_rental_listings_campground_id_rental_sku_variant_id
    UNIQUE (campground_id, rental_sku_variant_id),
  ADD CONSTRAINT ck_rental_listings_prices
    CHECK (
      price_per_day_weekday >= 0
      AND price_per_day_holiday >= 0
      AND discount >= 0
    );
CREATE INDEX idx_rental_listings_variant_active
  ON rental_listings_p3(rental_sku_variant_id, active);

ALTER TABLE rental_sku_variant_stocks SET SCHEMA migration;
ALTER TABLE migration.rental_sku_variant_stocks
  RENAME TO p3_legacy_rental_sku_variant_stocks;
ALTER SEQUENCE migration.rental_sku_variant_stocks_id_seq
  RENAME TO p3_legacy_rental_sku_variant_stocks_id_seq;
ALTER TABLE rental_sku_variant_stocks_p3 RENAME TO rental_sku_variant_stocks;

ALTER TABLE rental_listings SET SCHEMA migration;
ALTER TABLE migration.rental_listings RENAME TO p3_legacy_rental_listings;
ALTER TABLE rental_listings_p3 RENAME TO rental_listings;

ALTER TABLE rental_skus
  DROP COLUMN product_id,
  DROP COLUMN image,
  DROP COLUMN name,
  DROP COLUMN category,
  DROP COLUMN brand;

CREATE VIEW rental_listing_view AS
SELECT
  listing.id,
  listing.campground_id,
  listing.rental_sku_variant_id,
  mapping.location_id,
  listing.price_per_day_weekday,
  listing.price_per_day_holiday,
  listing.discount,
  COALESCE(stock.on_hand_quantity, 0)::INTEGER AS stock
FROM rental_listings listing
JOIN campground_rental_locations mapping
  ON mapping.campground_id = listing.campground_id
LEFT JOIN rental_sku_variant_stocks stock
  ON stock.location_id = mapping.location_id
 AND stock.rental_sku_variant_id = listing.rental_sku_variant_id;

COMMENT ON VIEW rental_listing_view IS
  'P3 read-only listing/location/physical-stock projection; reservation availability belongs to P4.';
