-- Legacy source identifiers belong to the P5 archive, not to current tables.
-- Original sources: data/admin/zone-blocks.json and
-- data/admin/campground-closures.json.

ALTER TABLE public.zone_blocks
  DROP CONSTRAINT uq_zone_blocks_legacy_block_id,
  DROP COLUMN legacy_block_id;

ALTER TABLE public.campground_closures
  DROP CONSTRAINT uq_campground_closures_legacy_closure_id,
  DROP COLUMN legacy_closure_id;
