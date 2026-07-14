\set ON_ERROR_STOP on

-- P7 global structure gate. P6 owns the latest phase-specific target checks;
-- the queries below add cross-schema guarantees that remain valid before and
-- after an authorized V700 contract migration.
\ir p6-structure.sql

CREATE TEMP TABLE p7_schema_issues (
  check_name TEXT NOT NULL,
  object_name TEXT NOT NULL,
  reason TEXT NOT NULL
);

INSERT INTO p7_schema_issues
SELECT 'invalid_constraint', namespace.nspname || '.' || relation.relname || '.' || constraint_data.conname,
       'constraint is not validated'
FROM pg_constraint constraint_data
JOIN pg_class relation ON relation.oid = constraint_data.conrelid
JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
WHERE namespace.nspname IN ('public', 'migration')
  AND NOT constraint_data.convalidated;

INSERT INTO p7_schema_issues
SELECT 'missing_primary_key', table_data.table_name,
       'public base table has no primary key'
FROM information_schema.tables table_data
WHERE table_data.table_schema = 'public'
  AND table_data.table_type = 'BASE TABLE'
  AND NOT EXISTS (
    SELECT 1
    FROM pg_constraint constraint_data
    JOIN pg_class relation ON relation.oid = constraint_data.conrelid
    JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
    WHERE namespace.nspname = table_data.table_schema
      AND relation.relname = table_data.table_name
      AND constraint_data.contype = 'p'
  );

WITH public_foreign_keys AS (
  SELECT constraint_data.conname, constraint_data.conrelid, constraint_data.conkey,
         relation.relname AS table_name
  FROM pg_constraint constraint_data
  JOIN pg_class relation ON relation.oid = constraint_data.conrelid
  JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
  WHERE namespace.nspname = 'public' AND constraint_data.contype = 'f'
)
INSERT INTO p7_schema_issues
SELECT 'foreign_key_index', table_name || '.' || conname,
       'referencing columns lack a usable non-partial index'
FROM public_foreign_keys foreign_key
WHERE NOT EXISTS (
  SELECT 1
  FROM pg_index index_data
  WHERE index_data.indrelid = foreign_key.conrelid
    AND index_data.indisvalid
    AND index_data.indpred IS NULL
    AND foreign_key.conkey <@ index_data.indkey::smallint[]
);

INSERT INTO p7_schema_issues
SELECT 'forbidden_reply_contract', table_name || '.' || column_name,
       'D-009 forbids official reply fields'
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (column_name = 'replied' OR column_name LIKE 'reply\_%' ESCAPE '\'
       OR column_name LIKE 'replied\_%' ESCAPE '\');

INSERT INTO p7_schema_issues
SELECT 'forbidden_reply_relation', namespace.nspname || '.' || relation.relname,
       'D-009 forbids review_replies'
FROM pg_class relation
JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
WHERE namespace.nspname = 'public' AND relation.relname = 'review_replies';

WITH state AS (
  SELECT EXISTS (
    SELECT 1 FROM public.flyway_schema_history
    WHERE success AND version = '700'
  ) AS contracted
)
INSERT INTO p7_schema_issues
SELECT 'movement_map_lifecycle', 'movement_migration_map',
       CASE WHEN state.contracted
         THEN 'after V700 the map must exist only in migration schema'
         ELSE 'before V700 the map must remain in public for contract audit'
       END
FROM state
WHERE (state.contracted AND (
         to_regclass('public.movement_migration_map') IS NOT NULL
         OR to_regclass('migration.movement_migration_map') IS NULL
       ))
   OR (NOT state.contracted AND to_regclass('public.movement_migration_map') IS NULL);

INSERT INTO p7_schema_issues
SELECT 'flyway_failure', coalesce(version, '<none>'), description
FROM public.flyway_schema_history
WHERE NOT success;

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*),
  'issues', coalesce(jsonb_agg(jsonb_build_object(
    'check', check_name, 'object', object_name, 'reason', reason
  ) ORDER BY check_name, object_name), '[]'::jsonb)
)) FROM p7_schema_issues;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p7_schema_issues) THEN
    RAISE EXCEPTION 'P7 global schema validation failed with % issue(s)',
      (SELECT count(*) FROM p7_schema_issues);
  END IF;
END $$;
