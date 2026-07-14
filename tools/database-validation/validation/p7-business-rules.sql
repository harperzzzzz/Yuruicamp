\set ON_ERROR_STOP on

DO $$
DECLARE
  archived_md5 TEXT;
BEGIN
  IF to_regclass('public.movement_migration_map') IS NOT NULL
     OR to_regclass('migration.movement_migration_map') IS NULL THEN
    RAISE EXCEPTION 'P7 map is not archived exclusively in migration schema';
  END IF;

  IF to_regclass('public.booking_policy_compatibility') IS NOT NULL
     OR to_regclass('public.zone_blocks_compatibility') IS NOT NULL
     OR to_regclass('public.campground_closures_compatibility') IS NOT NULL THEN
    RAISE EXCEPTION 'P7 temporary compatibility view remains in public schema';
  END IF;

  SELECT md5(string_agg(concat_ws('|',
           legacy_movement_id,
           legacy_item_ordinal::text,
           coalesce(store_item_id::text, ''),
           coalesce(rental_item_id::text, ''),
           coalesce(conversion_id::text, ''),
           coalesce(quarantine_reason, '')
         ), E'\n' ORDER BY legacy_movement_id, legacy_item_ordinal))
  INTO archived_md5
  FROM migration.movement_migration_map;

  IF NOT EXISTS (
    SELECT 1 FROM migration.p7_contract_evidence
    WHERE id = 1
      AND authorization_mode = 'OWNER_WAIVER'
      AND movement_map_rows = 141
      AND movement_map_quarantine_rows = 1
      AND movement_map_md5 = archived_md5
      AND authorization_reference =
        'codex-thread://019f5e33-e1d2-7411-a6a9-309de86b1e34/user-directive-2026-07-14'
  ) THEN
    RAISE EXCEPTION 'P7 archive evidence is missing or differs from the archived map';
  END IF;

  BEGIN
    UPDATE migration.movement_migration_map
    SET quarantine_reason = quarantine_reason
    WHERE legacy_movement_id = '97' AND legacy_item_ordinal = 0;
    RAISE EXCEPTION 'P7 archived movement map accepted an update';
  EXCEPTION WHEN SQLSTATE '55000' THEN
    NULL;
  END;

  BEGIN
    DELETE FROM migration.p7_contract_evidence WHERE id = 1;
    RAISE EXCEPTION 'P7 contract evidence accepted a delete';
  EXCEPTION WHEN SQLSTATE '55000' THEN
    NULL;
  END;
END $$;

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', 0,
  'result', 'P7 archive lifecycle and read-only cases passed'
));
