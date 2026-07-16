-- Historical movement IDs belong to migration evidence, not the production
-- inventory_movements table. Their legacy JSON source is data/admin/movement.json.

DROP VIEW inventory_movement_dto_view;

DROP INDEX IF EXISTS idx_inventory_movements_legacy;

ALTER TABLE inventory_movements
  DROP COLUMN legacy_movement_id;

CREATE VIEW inventory_movement_dto_view AS
SELECT movement.id,
       jsonb_build_object(
         'id', movement.id,
         'movementNo', movement.movement_no,
         'inventoryDomain', movement.inventory_domain,
         'movementType', movement.movement_type,
         'status', movement.status,
         'sourceLocationId', movement.source_location_id,
         'destinationLocationId', movement.destination_location_id,
         'employeeId', movement.employee_id,
         'occurredAt', to_char(movement.occurred_at AT TIME ZONE 'Asia/Taipei', 'YYYY-MM-DD HH24:MI:SS'),
         'items', COALESCE((
           SELECT jsonb_agg(jsonb_build_object(
             'inventoryDomain', item.inventory_domain,
             'variantId', item.variant_id,
             'sku', item.sku_snapshot,
             'productName', item.item_name_snapshot,
             'quantity', item.quantity,
             'sourceLocationId', movement.source_location_id,
             'destinationLocationId', movement.destination_location_id,
             'type', movement.movement_type
           ) ORDER BY item.id)
           FROM inventory_movement_items_view item
           WHERE item.movement_id = movement.id
         ), '[]'::jsonb)
       ) AS payload
FROM inventory_movements movement;

COMMENT ON VIEW inventory_movement_dto_view IS
  'P6 admin/report DTO built exclusively from P5 inventory_movements and inventory_movement_items_view.';

COMMENT ON TABLE migration.p5_movement_source IS
  'Legacy JSON source: data/admin/movement.json. Retained as P5 migration evidence.';
