-- P1 constraints: fixed names, explicit FK actions, business checks and FK indexes.

ALTER TABLE customers RENAME CONSTRAINT customers_pkey TO pk_customers;
ALTER TABLE customers RENAME CONSTRAINT customers_email_key TO uq_customers_email;
ALTER TABLE customers
  ALTER COLUMN registered_at TYPE TIMESTAMPTZ
    USING registered_at::timestamp AT TIME ZONE 'Asia/Taipei',
  ALTER COLUMN registered_at SET NOT NULL,
  ALTER COLUMN auth_provider TYPE VARCHAR(32) USING auth_provider::text,
  ALTER COLUMN auth_provider SET NOT NULL,
  ADD CONSTRAINT ck_customers_points CHECK (points >= 0),
  ADD CONSTRAINT ck_customers_auth_provider
    CHECK (auth_provider IN ('google', 'facebook', 'line'));
CREATE INDEX idx_customers_auth_provider ON customers(auth_provider);

ALTER TABLE admin_users
  ADD CONSTRAINT uq_admin_users_email UNIQUE (email),
  ADD CONSTRAINT ck_admin_users_role
    CHECK (role IN ('admin', 'operator', 'warehouse'));
CREATE INDEX idx_admin_users_role_active ON admin_users(role, active);

ALTER TABLE customer_shipping_addresses
  ADD CONSTRAINT fk_customer_shipping_addresses_customer_id
    FOREIGN KEY (customer_id) REFERENCES customers(id)
    ON UPDATE CASCADE ON DELETE CASCADE;
CREATE INDEX idx_customer_shipping_addresses_customer
  ON customer_shipping_addresses(customer_id);
CREATE UNIQUE INDEX idx_customer_shipping_addresses_one_default
  ON customer_shipping_addresses(customer_id)
  WHERE is_default;

ALTER TABLE preference_options
  ADD CONSTRAINT uq_preference_options_type_code UNIQUE (type, code),
  ADD CONSTRAINT uq_preference_options_type_label UNIQUE (type, label),
  ADD CONSTRAINT ck_preference_options_type
    CHECK (type IN ('style', 'equipment')),
  ADD CONSTRAINT ck_preference_options_sort_order CHECK (sort_order >= 0);
CREATE INDEX idx_preference_options_type_active_sort
  ON preference_options(type, active, sort_order);

ALTER TABLE customer_preferences
  ADD CONSTRAINT fk_customer_preferences_customer_id
    FOREIGN KEY (customer_id) REFERENCES customers(id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  ADD CONSTRAINT fk_customer_preferences_preference_id
    FOREIGN KEY (preference_id) REFERENCES preference_options(id)
    ON UPDATE CASCADE ON DELETE RESTRICT;
CREATE INDEX idx_customer_preferences_preference
  ON customer_preferences(preference_id);

ALTER TABLE customer_tags
  ADD CONSTRAINT uq_customer_tags_name UNIQUE (name),
  ADD CONSTRAINT ck_customer_tags_sort_order CHECK (sort_order >= 0);
CREATE INDEX idx_customer_tags_active_sort ON customer_tags(active, sort_order);

ALTER TABLE customer_tag_assignments
  ADD CONSTRAINT fk_customer_tag_assignments_customer_id
    FOREIGN KEY (customer_id) REFERENCES customers(id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  ADD CONSTRAINT fk_customer_tag_assignments_tag_id
    FOREIGN KEY (tag_id) REFERENCES customer_tags(id)
    ON UPDATE CASCADE ON DELETE RESTRICT;
CREATE INDEX idx_customer_tag_assignments_tag
  ON customer_tag_assignments(tag_id);

ALTER TABLE brands RENAME CONSTRAINT brands_pkey TO pk_brands;
ALTER TABLE brands
  ALTER COLUMN name TYPE VARCHAR(120),
  ADD CONSTRAINT uq_brands_name UNIQUE (name),
  ADD CONSTRAINT ck_brands_sort_order CHECK (sort_order >= 0);
CREATE INDEX idx_brands_active_sort ON brands(active, sort_order);

ALTER TABLE product_categories
  ADD CONSTRAINT uq_product_categories_code UNIQUE (code),
  ADD CONSTRAINT uq_product_categories_name UNIQUE (name),
  ADD CONSTRAINT ck_product_categories_sort_order CHECK (sort_order >= 0);
CREATE INDEX idx_product_categories_active_sort
  ON product_categories(active, sort_order);

ALTER TABLE campgrounds RENAME CONSTRAINT campgrounds_pkey TO pk_campgrounds;
ALTER TABLE campgrounds
  ALTER COLUMN name TYPE VARCHAR(150),
  ALTER COLUMN region TYPE VARCHAR(100),
  ALTER COLUMN region SET NOT NULL;
CREATE INDEX idx_campgrounds_region_active ON campgrounds(region, active);

ALTER TABLE campground_zones
  DROP CONSTRAINT campground_zones_campground_id_fkey;
ALTER TABLE campground_zones
  RENAME CONSTRAINT campground_zones_pkey TO pk_campground_zones;
ALTER TABLE campground_zones
  ADD CONSTRAINT fk_campground_zones_campground_id
    FOREIGN KEY (campground_id) REFERENCES campgrounds(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT uq_campground_zones_id_campground_id
    UNIQUE (id, campground_id),
  ADD CONSTRAINT ck_campground_zones_capacity CHECK (capacity_per_site > 0),
  ADD CONSTRAINT ck_campground_zones_sites CHECK (total_sites > 0),
  ADD CONSTRAINT ck_campground_zones_prices
    CHECK (price_weekday >= 0 AND price_holiday >= 0);
DROP INDEX idx_zones_campground;
CREATE INDEX idx_campground_zones_campground_active
  ON campground_zones(campground_id, active);

ALTER TABLE branches RENAME CONSTRAINT branches_pkey TO pk_branches;
ALTER TABLE branches
  ALTER COLUMN name TYPE VARCHAR(120),
  ALTER COLUMN address TYPE VARCHAR(300),
  ALTER COLUMN code SET NOT NULL,
  ALTER COLUMN address SET NOT NULL,
  ALTER COLUMN phone SET NOT NULL,
  ALTER COLUMN business_hours SET NOT NULL,
  ADD CONSTRAINT uq_branches_code UNIQUE (code),
  ADD CONSTRAINT ck_branches_latitude
    CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
  ADD CONSTRAINT ck_branches_longitude
    CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180);
CREATE INDEX idx_branches_active_code ON branches(active, code);

ALTER TABLE branch_features
  DROP CONSTRAINT branch_features_pkey,
  DROP CONSTRAINT branch_features_branch_id_fkey,
  ALTER COLUMN feature TYPE VARCHAR(100),
  ADD CONSTRAINT pk_branch_features PRIMARY KEY (branch_id, feature),
  ADD CONSTRAINT fk_branch_features_branch_id
    FOREIGN KEY (branch_id) REFERENCES branches(id)
    ON UPDATE CASCADE ON DELETE CASCADE;
CREATE INDEX idx_branch_features_feature ON branch_features(feature);

ALTER TABLE inventory_locations
  ADD CONSTRAINT fk_inventory_locations_branch_id
    FOREIGN KEY (branch_id) REFERENCES branches(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT uq_inventory_locations_code UNIQUE (code),
  ADD CONSTRAINT uq_inventory_locations_id_inventory_domain
    UNIQUE (id, inventory_domain),
  ADD CONSTRAINT ck_inventory_locations_domain
    CHECK (inventory_domain IN ('store', 'rental')),
  ADD CONSTRAINT ck_inventory_locations_type
    CHECK (type IN ('main', 'branch', 'campground', 'inspection', 'repair', 'damaged')),
  ADD CONSTRAINT ck_inventory_locations_branch_type
    CHECK (
      (type = 'branch' AND inventory_domain = 'store' AND branch_id IS NOT NULL)
      OR (type <> 'branch' AND branch_id IS NULL)
    ),
  ADD CONSTRAINT ck_inventory_locations_domain_type
    CHECK (
      (inventory_domain = 'store' AND type IN ('main', 'branch', 'inspection', 'repair', 'damaged'))
      OR (inventory_domain = 'rental' AND type IN ('main', 'campground', 'inspection', 'repair', 'damaged'))
    );
CREATE INDEX idx_inventory_locations_domain_type_active
  ON inventory_locations(inventory_domain, type, active);
CREATE INDEX idx_inventory_locations_branch ON inventory_locations(branch_id);

ALTER TABLE migration.p1_location_aliases
  ADD CONSTRAINT fk_p1_location_aliases_location
    FOREIGN KEY (location_id) REFERENCES inventory_locations(id)
    ON UPDATE CASCADE ON DELETE RESTRICT;
CREATE INDEX idx_p1_location_aliases_location
  ON migration.p1_location_aliases(location_id);

ALTER TABLE movements
  ADD CONSTRAINT fk_movements_employee_id
    FOREIGN KEY (employee_id) REFERENCES admin_users(id)
    ON UPDATE CASCADE ON DELETE RESTRICT;
CREATE INDEX idx_movements_employee_id ON movements(employee_id);

ALTER TABLE zone_blocks
  ADD CONSTRAINT fk_zone_blocks_created_by
    FOREIGN KEY (created_by) REFERENCES admin_users(id)
    ON UPDATE CASCADE ON DELETE RESTRICT;
CREATE INDEX idx_zone_blocks_created_by ON zone_blocks(created_by);
CREATE INDEX idx_zone_blocks_campground_id ON zone_blocks(campground_id);
CREATE INDEX idx_zone_blocks_zone_id ON zone_blocks(zone_id);

ALTER TABLE campground_closures
  ADD CONSTRAINT fk_campground_closures_created_by
    FOREIGN KEY (created_by) REFERENCES admin_users(id)
    ON UPDATE CASCADE ON DELETE RESTRICT;
CREATE INDEX idx_campground_closures_created_by
  ON campground_closures(created_by);
CREATE INDEX idx_campground_closures_campground_id
  ON campground_closures(campground_id);
