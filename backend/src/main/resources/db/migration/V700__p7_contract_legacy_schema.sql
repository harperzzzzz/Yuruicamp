-- P7 contract migration.
--
-- External observation/sign-off was explicitly waived by the repository owner
-- in docs/database/p7-waiver-decision.md. The waiver does not relax any local
-- reconciliation, archive-integrity, or schema-equivalence guard below.

DO $$
BEGIN
  IF to_regclass('public.movement_migration_map') IS NULL
     OR to_regclass('migration.movement_migration_map') IS NOT NULL THEN
    RAISE EXCEPTION 'P7 guard: movement_migration_map is not in the pre-contract state';
  END IF;

  IF (SELECT count(*) FROM public.movement_migration_map) <> 141
     OR (SELECT count(*) FROM public.movement_migration_map
         WHERE quarantine_reason IS NOT NULL) <> 1
     OR EXISTS (
       SELECT 1 FROM public.movement_migration_map
       WHERE num_nonnulls(
         store_item_id, rental_item_id, conversion_id, quarantine_reason
       ) <> 1
     )
     OR NOT EXISTS (
       SELECT 1 FROM public.movement_migration_map
       WHERE legacy_movement_id = '97'
         AND legacy_item_ordinal = 0
         AND quarantine_reason LIKE 'NO_RENTAL_VARIANT:%'
     ) THEN
    RAISE EXCEPTION 'P7 guard: movement migration dispositions are incomplete or changed';
  END IF;

  IF (SELECT count(*) FROM migration.p6_review_resolution) <> 38
     OR (SELECT count(*) FROM public.reviews) <> 1
     OR (SELECT count(*) FROM public.legacy_reviews) <> 37 THEN
    RAISE EXCEPTION 'P7 guard: approved P6 review disposition changed';
  END IF;
END $$;

CREATE TABLE migration.p7_contract_evidence (
  id SMALLINT NOT NULL,
  authorization_mode VARCHAR(32) NOT NULL,
  authorization_reference TEXT NOT NULL,
  contracted_at TIMESTAMPTZ NOT NULL,
  movement_map_rows INTEGER NOT NULL,
  movement_map_quarantine_rows INTEGER NOT NULL,
  movement_map_md5 CHAR(32) NOT NULL,
  CONSTRAINT pk_p7_contract_evidence PRIMARY KEY (id),
  CONSTRAINT ck_p7_contract_evidence_singleton CHECK (id = 1),
  CONSTRAINT ck_p7_contract_evidence_mode CHECK (authorization_mode = 'OWNER_WAIVER'),
  CONSTRAINT ck_p7_contract_evidence_counts CHECK (
    movement_map_rows = 141 AND movement_map_quarantine_rows = 1
  ),
  CONSTRAINT ck_p7_contract_evidence_md5 CHECK (movement_map_md5 ~ '^[0-9a-f]{32}$')
);

INSERT INTO migration.p7_contract_evidence (
  id, authorization_mode, authorization_reference, contracted_at,
  movement_map_rows, movement_map_quarantine_rows, movement_map_md5
)
SELECT 1,
       'OWNER_WAIVER',
       'codex-thread://019f5e33-e1d2-7411-a6a9-309de86b1e34/user-directive-2026-07-14',
       TIMESTAMPTZ '2026-07-14 15:00:00+08',
       count(*)::integer,
       count(*) FILTER (WHERE quarantine_reason IS NOT NULL)::integer,
       md5(string_agg(concat_ws('|',
         legacy_movement_id,
         legacy_item_ordinal::text,
         coalesce(store_item_id::text, ''),
         coalesce(rental_item_id::text, ''),
         coalesce(conversion_id::text, ''),
         coalesce(quarantine_reason, '')
       ), E'\n' ORDER BY legacy_movement_id, legacy_item_ordinal))
FROM public.movement_migration_map;

ALTER TABLE public.movement_migration_map SET SCHEMA migration;

CREATE FUNCTION migration.reject_p7_archive_write() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'P7 migration archive is read-only' USING ERRCODE = '55000';
END $$;

CREATE TRIGGER trg_movement_migration_map_read_only
BEFORE INSERT OR UPDATE OR DELETE OR TRUNCATE
ON migration.movement_migration_map
FOR EACH STATEMENT EXECUTE FUNCTION migration.reject_p7_archive_write();

CREATE TRIGGER trg_p7_contract_evidence_read_only
BEFORE INSERT OR UPDATE OR DELETE OR TRUNCATE
ON migration.p7_contract_evidence
FOR EACH STATEMENT EXECUTE FUNCTION migration.reject_p7_archive_write();

REVOKE INSERT, UPDATE, DELETE, TRUNCATE
  ON migration.movement_migration_map, migration.p7_contract_evidence
  FROM PUBLIC;

-- These views existed only to reproduce the frozen JSON contract during the
-- expand/backfill observation period. Post-contract validators rebuild their
-- projections as TEMP views directly from the normalized tables.
DROP VIEW public.booking_policy_compatibility;
DROP VIEW public.zone_blocks_compatibility;
DROP VIEW public.campground_closures_compatibility;

COMMENT ON TABLE migration.movement_migration_map IS
  'P7 read-only archive of the deterministic P5 legacy-item disposition map.';
COMMENT ON TABLE migration.p7_contract_evidence IS
  'P7 contract authorization and archive checksum; external observation/sign-off was explicitly waived.';
COMMENT ON FUNCTION migration.reject_p7_archive_write() IS
  'Rejects every owner/application DML attempt against P7 archive relations.';
