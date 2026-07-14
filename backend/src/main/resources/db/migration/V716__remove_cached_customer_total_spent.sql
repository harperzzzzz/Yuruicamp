DO $$
BEGIN
  IF to_regclass('public.customer_spending_summary') IS NULL THEN
    RAISE EXCEPTION 'customer_spending_summary must exist before customers.total_spent is removed';
  END IF;

  PERFORM customer_id, total_spent
  FROM customer_spending_summary
  LIMIT 1;
END $$;

DO $$
DECLARE
  dependent_objects TEXT;
BEGIN
  SELECT string_agg(
           pg_describe_object(dependency.classid, dependency.objid, dependency.objsubid),
           E'\n' ORDER BY pg_describe_object(dependency.classid, dependency.objid, dependency.objsubid)
         )
  INTO dependent_objects
  FROM pg_attribute attribute
  JOIN pg_depend dependency
    ON dependency.refobjid = attribute.attrelid
   AND dependency.refobjsubid = attribute.attnum
  WHERE attribute.attrelid = 'public.customers'::regclass
    AND attribute.attname = 'total_spent'
    AND dependency.deptype = 'n';

  IF dependent_objects IS NOT NULL THEN
    RAISE EXCEPTION 'customers.total_spent still has dependent database objects:%', E'\n' || dependent_objects;
  END IF;
END $$;

ALTER TABLE customers
DROP COLUMN total_spent;
