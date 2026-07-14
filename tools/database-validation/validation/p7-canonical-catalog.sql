\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on
\pset pager off

WITH catalog_rows AS (
  SELECT 'column' AS object_type,
         table_schema || '.' || table_name || '.' || column_name AS object_name,
         jsonb_build_object(
           -- Dropped columns leave physical attnum gaps that pg_dump cannot
           -- reproduce. Compare the surviving logical column order instead.
           'ordinal', row_number() OVER (
             PARTITION BY table_schema, table_name ORDER BY ordinal_position
           ),
           'type', data_type,
           'udtSchema', udt_schema,
           'udtName', udt_name,
           'nullable', is_nullable,
           'default', column_default,
           'identity', is_identity,
           'generated', is_generated
         ) AS definition
  FROM information_schema.columns
  WHERE table_schema IN ('public', 'migration')
    AND NOT (table_schema = 'public' AND table_name = 'flyway_schema_history')

  UNION ALL
  SELECT 'constraint', namespace.nspname || '.' || relation.relname || '.' || constraint_data.conname,
         jsonb_build_object(
           'type', constraint_data.contype,
           'definition', replace(replace(replace(
             pg_get_constraintdef(constraint_data.oid, TRUE),
             '::character varying::text', '::text'),
             '::character varying', '::text'), ']::text[]', ']'),
           'validated', constraint_data.convalidated,
           'deferrable', constraint_data.condeferrable,
           'deferred', constraint_data.condeferred
         )
  FROM pg_constraint constraint_data
  JOIN pg_class relation ON relation.oid = constraint_data.conrelid
  JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
  WHERE namespace.nspname IN ('public', 'migration')
    AND NOT (namespace.nspname = 'public' AND relation.relname = 'flyway_schema_history')

  UNION ALL
  SELECT 'index', namespace.nspname || '.' || relation.relname || '.' || index_relation.relname,
         jsonb_build_object(
           'definition', pg_get_indexdef(index_data.indexrelid),
           'unique', index_data.indisunique,
           'primary', index_data.indisprimary,
           'valid', index_data.indisvalid
         )
  FROM pg_index index_data
  JOIN pg_class relation ON relation.oid = index_data.indrelid
  JOIN pg_class index_relation ON index_relation.oid = index_data.indexrelid
  JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
  WHERE namespace.nspname IN ('public', 'migration')
    AND NOT (namespace.nspname = 'public' AND relation.relname = 'flyway_schema_history')

  UNION ALL
  SELECT 'relation', namespace.nspname || '.' || relation.relname,
         jsonb_build_object(
           'kind', relation.relkind,
           'persistence', relation.relpersistence,
           'rowsecurity', relation.relrowsecurity,
           'viewDefinition', CASE WHEN relation.relkind IN ('v', 'm') THEN
             replace(replace(replace(
               pg_get_viewdef(relation.oid, TRUE),
               '::character varying::text', '::text'),
               '::character varying', '::text'), ']::text[]', ']')
             END
         )
  FROM pg_class relation
  JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
  WHERE namespace.nspname IN ('public', 'migration')
    AND relation.relkind IN ('r', 'p', 'v', 'm', 'S')
    AND NOT (namespace.nspname = 'public' AND relation.relname = 'flyway_schema_history')

  UNION ALL
  SELECT 'enum', namespace.nspname || '.' || type_data.typname || '.' || enum_data.enumsortorder,
         jsonb_build_object('label', enum_data.enumlabel)
  FROM pg_enum enum_data
  JOIN pg_type type_data ON type_data.oid = enum_data.enumtypid
  JOIN pg_namespace namespace ON namespace.oid = type_data.typnamespace
  WHERE namespace.nspname IN ('public', 'migration')

  UNION ALL
  SELECT 'function', namespace.nspname || '.' || procedure.proname || '(' || pg_get_function_identity_arguments(procedure.oid) || ')',
         jsonb_build_object('definition', pg_get_functiondef(procedure.oid))
  FROM pg_proc procedure
  JOIN pg_namespace namespace ON namespace.oid = procedure.pronamespace
  WHERE namespace.nspname IN ('public', 'migration')

  UNION ALL
  SELECT 'trigger', namespace.nspname || '.' || relation.relname || '.' || trigger_data.tgname,
         jsonb_build_object('definition', pg_get_triggerdef(trigger_data.oid, TRUE))
  FROM pg_trigger trigger_data
  JOIN pg_class relation ON relation.oid = trigger_data.tgrelid
  JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
  WHERE namespace.nspname IN ('public', 'migration') AND NOT trigger_data.tgisinternal
)
SELECT jsonb_build_object(
  'objectCount', count(*),
  'objects', jsonb_agg(jsonb_build_object(
    'type', object_type, 'name', object_name, 'definition', definition
  ) ORDER BY object_type, object_name)
)::text
FROM catalog_rows;
