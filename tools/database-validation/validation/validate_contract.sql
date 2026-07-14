\set ON_ERROR_STOP on
\ir p1-compatibility.sql
\ir p2-compatibility.sql
\ir p3-compatibility.sql
\ir p4-compatibility.sql
\ir p5-compatibility.sql
\ir p6-compatibility.sql

CREATE TEMP TABLE p7_contract_issues (
  check_name TEXT NOT NULL,
  object_name TEXT NOT NULL,
  reason TEXT NOT NULL
);

INSERT INTO p7_contract_issues
SELECT 'movement_view_dependency', 'inventory_movement_dto_view',
       'movement DTO must consume the P5 normalized item view'
WHERE pg_get_viewdef('inventory_movement_dto_view'::regclass, TRUE)
      NOT LIKE '%inventory_movement_items_view%';

INSERT INTO p7_contract_issues
SELECT 'reply_dto', 'review_dto_view.' || column_name,
       'official reply contract is forbidden'
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'review_dto_view'
  AND (column_name = 'replied' OR column_name LIKE 'reply%');

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*),
  'issues', coalesce(jsonb_agg(jsonb_build_object(
    'check', check_name, 'object', object_name, 'reason', reason
  ) ORDER BY check_name, object_name), '[]'::jsonb)
)) FROM p7_contract_issues;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p7_contract_issues) THEN
    RAISE EXCEPTION 'P7 contract validation failed with % issue(s)',
      (SELECT count(*) FROM p7_contract_issues);
  END IF;
END $$;
