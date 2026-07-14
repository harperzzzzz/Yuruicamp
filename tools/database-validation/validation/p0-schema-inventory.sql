\set ON_ERROR_STOP on
\pset tuples_only on
\pset format unaligned

-- Machine-readable P0 inventory for the current schema. The result is one JSON value.
WITH project_tables AS (
  SELECT c.oid, n.nspname AS schema_name, c.relname AS table_name
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind = 'r'
), columns_json AS (
  SELECT jsonb_agg(jsonb_build_object(
    'schema', table_schema,
    'table', table_name,
    'ordinal', ordinal_position,
    'column', column_name,
    'dataType', data_type,
    'udt', udt_name,
    'nullable', is_nullable = 'YES',
    'default', column_default
  ) ORDER BY table_name, ordinal_position) AS value
  FROM information_schema.columns
  WHERE table_schema = 'public'
), constraints_json AS (
  SELECT jsonb_agg(jsonb_build_object(
    'table', t.table_name,
    'name', c.conname,
    'type', CASE c.contype WHEN 'p' THEN 'PRIMARY KEY' WHEN 'f' THEN 'FOREIGN KEY' WHEN 'u' THEN 'UNIQUE' WHEN 'c' THEN 'CHECK' ELSE c.contype::text END,
    'definition', pg_get_constraintdef(c.oid, true),
    'onUpdate', CASE WHEN c.contype = 'f' THEN CASE c.confupdtype WHEN 'a' THEN 'NO ACTION' WHEN 'r' THEN 'RESTRICT' WHEN 'c' THEN 'CASCADE' WHEN 'n' THEN 'SET NULL' WHEN 'd' THEN 'SET DEFAULT' END END,
    'onDelete', CASE WHEN c.contype = 'f' THEN CASE c.confdeltype WHEN 'a' THEN 'NO ACTION' WHEN 'r' THEN 'RESTRICT' WHEN 'c' THEN 'CASCADE' WHEN 'n' THEN 'SET NULL' WHEN 'd' THEN 'SET DEFAULT' END END,
    'referencingIndexPresent', CASE WHEN c.contype = 'f' THEN EXISTS (
      SELECT 1 FROM pg_index i
      WHERE i.indrelid = c.conrelid AND c.conkey <@ (i.indkey::smallint[])
    ) END
  ) ORDER BY t.table_name, c.conname) AS value
  FROM pg_constraint c
  JOIN project_tables t ON t.oid = c.conrelid
), indexes_json AS (
  SELECT jsonb_agg(jsonb_build_object(
    'table', t.table_name,
    'name', i.relname,
    'unique', x.indisunique,
    'primary', x.indisprimary,
    'valid', x.indisvalid,
    'definition', pg_get_indexdef(i.oid)
  ) ORDER BY t.table_name, i.relname) AS value
  FROM pg_index x
  JOIN project_tables t ON t.oid = x.indrelid
  JOIN pg_class i ON i.oid = x.indexrelid
), enums_json AS (
  SELECT jsonb_agg(jsonb_build_object('name', enum_name, 'values', values) ORDER BY enum_name) AS value
  FROM (
    SELECT t.typname AS enum_name, jsonb_agg(e.enumlabel ORDER BY e.enumsortorder) AS values
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    JOIN pg_enum e ON e.enumtypid = t.oid
    WHERE n.nspname = 'public'
    GROUP BY t.typname
  ) q
), tables_json AS (
  SELECT jsonb_agg(jsonb_build_object('schema', schema_name, 'table', table_name) ORDER BY table_name) AS value,
         count(*) AS table_count
  FROM project_tables
)
SELECT jsonb_pretty(jsonb_build_object(
  'schema', 'public',
  'tableCount', tables_json.table_count,
  'enumCount', COALESCE(jsonb_array_length(enums_json.value), 0),
  'tables', COALESCE(tables_json.value, '[]'::jsonb),
  'columns', COALESCE(columns_json.value, '[]'::jsonb),
  'constraints', COALESCE(constraints_json.value, '[]'::jsonb),
  'indexes', COALESCE(indexes_json.value, '[]'::jsonb),
  'enums', COALESCE(enums_json.value, '[]'::jsonb)
))
FROM tables_json, columns_json, constraints_json, indexes_json, enums_json;
