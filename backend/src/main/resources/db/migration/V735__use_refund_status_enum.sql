-- Constrain live order refund workflow states with a dedicated enum.
-- Dependent views are preserved and recreated around the column type change.

CREATE TYPE public.refund_status AS ENUM (
  'none',
  'requested',
  'approved',
  'processing',
  'refunded',
  'rejected',
  'failed'
);

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.orders
    WHERE refund_status::TEXT NOT IN (
      'none',
      'requested',
      'approved',
      'processing',
      'refunded',
      'rejected',
      'failed'
    )
  ) THEN
    RAISE EXCEPTION
      'V735 guard: public.orders contains an unsupported refund_status';
  END IF;
END
$$;

CREATE TEMP TABLE v735_view_definitions (
  sort_order INTEGER PRIMARY KEY,
  view_name TEXT NOT NULL,
  view_definition TEXT NOT NULL,
  view_comment TEXT
) ON COMMIT DROP;

INSERT INTO v735_view_definitions (
  sort_order,
  view_name,
  view_definition,
  view_comment
)
SELECT source.sort_order,
       source.view_name,
       pg_get_viewdef(format('public.%I', source.view_name)::REGCLASS, true),
       obj_description(
         format('public.%I', source.view_name)::REGCLASS,
         'pg_class'
       )
FROM (VALUES
  (1, 'customer_spending_summary'),
  (2, 'customer_tier_summary')
) source(sort_order, view_name);

DROP VIEW public.customer_tier_summary;
DROP VIEW public.customer_spending_summary;

ALTER TABLE public.orders
  ALTER COLUMN refund_status DROP DEFAULT;

ALTER TABLE public.orders
  ALTER COLUMN refund_status
  TYPE public.refund_status
  USING refund_status::public.refund_status;

ALTER TABLE public.orders
  ALTER COLUMN refund_status
  SET DEFAULT 'none'::public.refund_status;

DO $$
DECLARE
  saved_view RECORD;
BEGIN
  FOR saved_view IN
    SELECT view_name, view_definition, view_comment
    FROM v735_view_definitions
    ORDER BY sort_order
  LOOP
    EXECUTE format(
      'CREATE VIEW public.%I AS %s',
      saved_view.view_name,
      saved_view.view_definition
    );

    IF saved_view.view_comment IS NOT NULL THEN
      EXECUTE format(
        'COMMENT ON VIEW public.%I IS %L',
        saved_view.view_name,
        saved_view.view_comment
      );
    END IF;
  END LOOP;
END
$$;
