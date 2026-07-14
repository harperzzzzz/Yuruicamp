-- P3 expand: introduce rental-specific variants, campground/location mapping,
-- normalized rental stock and listing staging structures. V310 backfills the
-- frozen sources; V320 validates and swaps the legacy public tables.

ALTER TABLE rental_skus
  ADD COLUMN item_id VARCHAR(32),
  ADD COLUMN status VARCHAR(16) NOT NULL DEFAULT 'active',
  ADD COLUMN created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE TABLE rental_sku_variants (
  id            VARCHAR(64) NOT NULL,
  rental_sku_id VARCHAR(32) NOT NULL,
  sku           VARCHAR(64) NOT NULL,
  color         VARCHAR(100),
  size          VARCHAR(100),
  specification VARCHAR(200) NOT NULL,
  status        VARCHAR(16) NOT NULL DEFAULT 'active',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT pk_rental_sku_variants PRIMARY KEY (id)
);

CREATE TABLE campground_rental_locations (
  campground_id VARCHAR(32) NOT NULL,
  location_id   VARCHAR(32) NOT NULL,
  CONSTRAINT pk_campground_rental_locations PRIMARY KEY (campground_id)
);

CREATE TABLE rental_sku_variant_stocks_p3 (
  location_id           VARCHAR(32) NOT NULL,
  rental_sku_variant_id VARCHAR(64) NOT NULL,
  on_hand_quantity      INTEGER NOT NULL DEFAULT 0,
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT pk_rental_sku_variant_stocks PRIMARY KEY (location_id, rental_sku_variant_id)
);

CREATE TABLE rental_listings_p3 (
  id                    VARCHAR(64) NOT NULL,
  campground_id         VARCHAR(32) NOT NULL,
  rental_sku_variant_id VARCHAR(64) NOT NULL,
  price_per_day_weekday NUMERIC(12,2) NOT NULL,
  price_per_day_holiday NUMERIC(12,2) NOT NULL,
  discount              NUMERIC(12,2) NOT NULL DEFAULT 0,
  terrain               VARCHAR(100),
  description           TEXT,
  active                BOOLEAN NOT NULL DEFAULT TRUE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT pk_rental_listings PRIMARY KEY (id)
);

-- Frozen validation evidence remains in the migration schema after the public
-- legacy display/stock columns are contracted.
CREATE TABLE migration.p3_rental_sku_source (
  rental_sku_id VARCHAR(32) NOT NULL,
  payload       JSONB NOT NULL,
  CONSTRAINT pk_p3_rental_sku_source PRIMARY KEY (rental_sku_id)
);

CREATE TABLE migration.p3_listing_source (
  listing_id VARCHAR(64) NOT NULL,
  payload    JSONB NOT NULL,
  CONSTRAINT pk_p3_listing_source PRIMARY KEY (listing_id)
);

CREATE TABLE migration.p3_rental_min_stock_source (
  rental_sku_id VARCHAR(32) NOT NULL,
  location_id   VARCHAR(32) NOT NULL,
  quantity      INTEGER NOT NULL,
  CONSTRAINT pk_p3_rental_min_stock_source PRIMARY KEY (rental_sku_id, location_id)
);

CREATE TABLE migration.p3_rental_variant_map (
  rental_sku_id       VARCHAR(32) NOT NULL,
  legacy_variant_id   VARCHAR(64) NOT NULL,
  rental_variant_id   VARCHAR(64) NOT NULL,
  CONSTRAINT pk_p3_rental_variant_map PRIMARY KEY (rental_sku_id, legacy_variant_id),
  CONSTRAINT uq_p3_rental_variant_map_target UNIQUE (rental_variant_id)
);
