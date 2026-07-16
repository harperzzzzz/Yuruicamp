-- Canonical inventory movement types:
-- receipt, write_off, transfer, conversion_out, conversion_in.

ALTER TABLE inventory_movements
  DROP CONSTRAINT ck_inventory_movements_type_payload,
  DROP CONSTRAINT ck_inventory_movements_type;

UPDATE inventory_movements
SET movement_type = CASE movement_type
  WHEN '進貨' THEN 'receipt'
  WHEN 'adjustment_in' THEN 'receipt'
  WHEN '損耗' THEN 'write_off'
  WHEN 'adjustment_out' THEN 'write_off'
  WHEN '移轉' THEN 'transfer'
  WHEN '營地互轉' THEN 'transfer'
  ELSE movement_type
END;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM inventory_movements
    WHERE movement_type NOT IN (
      'receipt', 'write_off', 'transfer', 'conversion_out', 'conversion_in'
    )
  ) THEN
    RAISE EXCEPTION
      'Cannot normalize inventory movement types: unsupported movement_type exists';
  END IF;
END
$$;

ALTER TABLE inventory_movements
  ADD CONSTRAINT ck_inventory_movements_type
    CHECK (movement_type IN (
      'receipt', 'write_off', 'transfer', 'conversion_out', 'conversion_in'
    )),
  ADD CONSTRAINT ck_inventory_movements_type_payload CHECK (
    (movement_type = 'receipt'
      AND source_location_id IS NULL AND destination_location_id IS NOT NULL)
    OR
    (movement_type = 'write_off'
      AND source_location_id IS NOT NULL AND destination_location_id IS NULL)
    OR
    (movement_type = 'transfer'
      AND source_location_id IS NOT NULL AND destination_location_id IS NOT NULL
      AND source_location_id <> destination_location_id)
    OR
    (movement_type = 'conversion_out'
      AND inventory_domain = 'store'
      AND source_location_id IS NOT NULL AND destination_location_id IS NULL)
    OR
    (movement_type = 'conversion_in'
      AND inventory_domain = 'rental'
      AND source_location_id IS NULL AND destination_location_id IS NOT NULL)
  );
