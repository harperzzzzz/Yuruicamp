-- Restore the existing payment_status enum as the authority for live orders.
-- Dependent views must be recreated around the column type change.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.orders
    WHERE payment_status::TEXT NOT IN ('unpaid', 'paid', 'refunded')
  ) THEN
    RAISE EXCEPTION
      'V734 guard: public.orders contains an unsupported payment_status';
  END IF;
END
$$;

CREATE TEMP TABLE v734_view_definitions (
  sort_order INTEGER PRIMARY KEY,
  view_name TEXT NOT NULL,
  view_definition TEXT NOT NULL,
  view_comment TEXT
) ON COMMIT DROP;

INSERT INTO v734_view_definitions (
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
  (1, 'coupon_usage_stats'),
  (2, 'customer_spending_summary'),
  (3, 'customer_tier_summary')
) source(sort_order, view_name);

DROP VIEW public.customer_tier_summary;
DROP VIEW public.customer_spending_summary;
DROP VIEW public.coupon_usage_stats;

ALTER TABLE public.orders
  ALTER COLUMN payment_status
  TYPE public.payment_status
  USING payment_status::public.payment_status;

DO $$
DECLARE
  saved_view RECORD;
BEGIN
  FOR saved_view IN
    SELECT view_name, view_definition, view_comment
    FROM v734_view_definitions
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
