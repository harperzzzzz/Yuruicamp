\set ON_ERROR_STOP on

-- Thresholds are fixed before execution. These fixture thresholds are a local
-- guard only; P7 still requires the same query set on production-sized seed.
ANALYZE;

CREATE FUNCTION pg_temp.p7_explain(query_text TEXT)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  result JSONB;
BEGIN
  EXECUTE 'EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) ' || query_text INTO result;
  RETURN result;
END $$;

CREATE FUNCTION pg_temp.p7_plan_nodes(explain_result JSONB)
RETURNS TABLE(node JSONB)
LANGUAGE sql
AS $$
  WITH RECURSIVE nodes(node) AS (
    SELECT explain_result->0->'Plan'
    UNION ALL
    SELECT child.value
    FROM nodes
    CROSS JOIN LATERAL jsonb_array_elements(coalesce(nodes.node->'Plans', '[]'::jsonb)) child
  )
  SELECT node FROM nodes
$$;

CREATE TEMP TABLE p7_performance_results (
  query_name TEXT PRIMARY KEY,
  threshold_ms NUMERIC NOT NULL,
  query_text TEXT NOT NULL,
  plan JSONB NOT NULL
);

INSERT INTO p7_performance_results (query_name, threshold_ms, query_text, plan)
SELECT query_name, threshold_ms, query_text, pg_temp.p7_explain(query_text)
FROM (VALUES
  ('review_by_order_item', 250::numeric,
   $$SELECT * FROM review_dto_view WHERE id = 'REV031'$$),
  ('article_blocks_by_article', 250::numeric,
   $$SELECT * FROM article_content_blocks WHERE article_id = 'art-001' ORDER BY sort_order$$),
  ('movement_items_by_movement', 250::numeric,
   'SELECT * FROM inventory_movement_items_view WHERE movement_id = 1'),
  ('store_stock_by_variant_location', 250::numeric,
   $$SELECT * FROM inventory_stocks WHERE variant_id = 'v-P001-0' AND location_id = 'branch-001'$$),
  ('rental_stock_by_variant_location', 250::numeric,
   $$SELECT * FROM rental_sku_variant_stocks WHERE rental_sku_variant_id = 'v-P001-0' AND location_id = 'C001'$$),
  ('order_by_business_id', 250::numeric,
   $$SELECT * FROM orders WHERE id = '1'$$)
) queries(query_name, threshold_ms, query_text);

CREATE TEMP TABLE p7_performance_issues (
  check_name TEXT NOT NULL,
  object_name TEXT NOT NULL,
  reason TEXT NOT NULL
);

INSERT INTO p7_performance_issues
SELECT 'execution_threshold', query_name,
       format('execution time %s ms exceeds threshold %s ms', plan->0->>'Execution Time', threshold_ms)
FROM p7_performance_results
WHERE (plan->0->>'Execution Time')::numeric > threshold_ms;

-- A sequential scan is approved for this local fixture only when ANALYZE says
-- the relation has fewer than 1,000 rows. Larger scans need explicit approval.
INSERT INTO p7_performance_issues
SELECT 'unapproved_sequential_scan', result.query_name,
       format('sequential scan on %s has estimated relation size %s', node.node->>'Relation Name', relation.reltuples)
FROM p7_performance_results result
CROSS JOIN LATERAL pg_temp.p7_plan_nodes(result.plan) node
JOIN pg_class relation ON relation.relname = node.node->>'Relation Name'
JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace AND namespace.nspname = 'public'
WHERE node.node->>'Node Type' = 'Seq Scan'
  AND relation.reltuples >= 1000;

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', (SELECT count(*) FROM p7_performance_issues),
  'queries', (SELECT jsonb_agg(jsonb_build_object(
    'name', query_name,
    'thresholdMs', threshold_ms,
    'planningMs', (plan->0->>'Planning Time')::numeric,
    'executionMs', (plan->0->>'Execution Time')::numeric,
    'sequentialScans', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'relation', node.node->>'Relation Name',
        'actualRows', node.node->>'Actual Rows',
        'approvedSmallFixture', relation.reltuples < 1000
      ) ORDER BY node.node->>'Relation Name')
      FROM pg_temp.p7_plan_nodes(result.plan) node
      JOIN pg_class relation ON relation.relname = node.node->>'Relation Name'
      JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace AND namespace.nspname = 'public'
      WHERE node.node->>'Node Type' = 'Seq Scan'
    ), '[]'::jsonb)
  ) ORDER BY query_name) FROM p7_performance_results result),
  'issues', coalesce((SELECT jsonb_agg(jsonb_build_object(
    'check', check_name, 'object', object_name, 'reason', reason
  ) ORDER BY check_name, object_name) FROM p7_performance_issues), '[]'::jsonb)
));

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p7_performance_issues) THEN
    RAISE EXCEPTION 'P7 performance validation failed with % issue(s)',
      (SELECT count(*) FROM p7_performance_issues);
  END IF;
END $$;
