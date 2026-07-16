-- Ensure store stock and store minimum-stock settings can reference only
-- inventory_locations in the store domain.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM inventory_stocks stock
    JOIN inventory_locations location ON location.id = stock.location_id
    WHERE location.inventory_domain <> 'store'
  ) THEN
    RAISE EXCEPTION
      'Cannot enforce store inventory location domain: inventory_stocks contains a non-store location';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM product_variant_min_stocks minimum
    JOIN inventory_locations location ON location.id = minimum.location_id
    WHERE location.inventory_domain <> 'store'
  ) THEN
    RAISE EXCEPTION
      'Cannot enforce store minimum-stock location domain: product_variant_min_stocks contains a non-store location';
  END IF;
END
$$;

ALTER TABLE inventory_stocks
  ADD COLUMN inventory_domain character varying(16) NOT NULL DEFAULT 'store',
  DROP CONSTRAINT fk_inventory_stocks_location_id,
  ADD CONSTRAINT ck_inventory_stocks_domain CHECK (inventory_domain = 'store'),
  ADD CONSTRAINT fk_inventory_stocks_location_domain
    FOREIGN KEY (location_id, inventory_domain)
    REFERENCES inventory_locations(id, inventory_domain)
    ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE product_variant_min_stocks
  ADD COLUMN inventory_domain character varying(16) NOT NULL DEFAULT 'store',
  DROP CONSTRAINT fk_product_variant_min_stocks_location_id,
  ADD CONSTRAINT ck_product_variant_min_stocks_domain CHECK (inventory_domain = 'store'),
  ADD CONSTRAINT fk_product_variant_min_stocks_location_domain
    FOREIGN KEY (location_id, inventory_domain)
    REFERENCES inventory_locations(id, inventory_domain)
    ON UPDATE CASCADE ON DELETE RESTRICT;
