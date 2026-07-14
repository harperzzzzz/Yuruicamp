\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on
\pset pager off

CREATE TEMP TABLE p7_data_fingerprints (
  object_name TEXT PRIMARY KEY,
  row_count BIGINT NOT NULL,
  content_md5 TEXT NOT NULL
);

DO $$
DECLARE
  relation RECORD;
  count_value BIGINT;
  hash_value TEXT;
BEGIN
  FOR relation IN
    SELECT namespace.nspname AS schema_name, class_data.relname AS relation_name
    FROM pg_class class_data
    JOIN pg_namespace namespace ON namespace.oid = class_data.relnamespace
    WHERE namespace.nspname IN ('public', 'migration')
      AND class_data.relkind IN ('r', 'p')
      AND NOT (namespace.nspname = 'public' AND class_data.relname = 'flyway_schema_history')
    ORDER BY namespace.nspname, class_data.relname
  LOOP
    EXECUTE format(
      'SELECT count(*), md5(coalesce(string_agg((to_jsonb(source_row) - ARRAY[''created_at'',''updated_at''])::text, E''\\n'' ORDER BY (to_jsonb(source_row) - ARRAY[''created_at'',''updated_at''])::text), '''')) FROM %I.%I source_row',
      relation.schema_name, relation.relation_name
    ) INTO count_value, hash_value;
    INSERT INTO p7_data_fingerprints VALUES (
      relation.schema_name || '.' || relation.relation_name,
      count_value,
      hash_value
    );
  END LOOP;
END $$;

SELECT jsonb_build_object(
  'objectCount', count(*),
  'totalRows', sum(row_count),
  'objects', jsonb_agg(jsonb_build_object(
    'name', object_name, 'rows', row_count, 'md5', content_md5
  ) ORDER BY object_name)
)::text
FROM p7_data_fingerprints;
