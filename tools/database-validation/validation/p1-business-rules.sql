\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
  preference BIGINT;
BEGIN
  INSERT INTO customers (
    id, name, email, registered_at, points, first_purchase_used, auth_provider
  ) VALUES (
    'P1-TEST-CUSTOMER', 'P1 Test', 'p1-test@example.invalid', NOW(), 0, FALSE, 'google'
  );

  INSERT INTO customer_shipping_addresses (
    customer_id, recipient_name, postal_code, city, district, address_line, phone, is_default
  ) VALUES (
    'P1-TEST-CUSTOMER', 'Test', '100', '臺北市', '中正區', '測試路 1 號', '0900000000', TRUE
  );

  BEGIN
    INSERT INTO customer_shipping_addresses (
      customer_id, recipient_name, postal_code, city, district, address_line, phone, is_default
    ) VALUES (
      'P1-TEST-CUSTOMER', 'Test 2', '100', '臺北市', '中正區', '測試路 2 號', '0900000001', TRUE
    );
    RAISE EXCEPTION 'second default address was accepted';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  SELECT id INTO preference FROM preference_options ORDER BY id LIMIT 1;
  INSERT INTO customer_preferences(customer_id, preference_id)
  VALUES ('P1-TEST-CUSTOMER', preference);
  DELETE FROM customers WHERE id = 'P1-TEST-CUSTOMER';
  IF EXISTS (SELECT 1 FROM customer_preferences WHERE customer_id = 'P1-TEST-CUSTOMER') THEN
    RAISE EXCEPTION 'customer preference did not cascade';
  END IF;

  BEGIN
    INSERT INTO inventory_locations (
      id, code, inventory_domain, type, branch_id, name
    ) VALUES (
      'P1-BAD-CAMP', 'P1-BAD-CAMP', 'rental', 'campground', 'branch-001', 'invalid'
    );
    RAISE EXCEPTION 'campground location accepted a branch_id';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    DELETE FROM branches WHERE id = 'branch-001';
    RAISE EXCEPTION 'referenced branch was physically deleted';
  EXCEPTION WHEN integrity_constraint_violation THEN NULL;
  END;

  BEGIN
    DELETE FROM campgrounds WHERE id = 'C002';
    RAISE EXCEPTION 'referenced campground was physically deleted';
  EXCEPTION WHEN integrity_constraint_violation THEN NULL;
  END;
END $$;

ROLLBACK;
SELECT jsonb_pretty(jsonb_build_object('issueCount', 0, 'result', 'P1 business-rule cases passed'));
