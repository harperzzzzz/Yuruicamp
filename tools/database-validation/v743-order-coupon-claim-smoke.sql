\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
  claim_id BIGINT;
  owner_order_id VARCHAR(32);
  other_order_id VARCHAR(32);
BEGIN
  SELECT id INTO owner_order_id
  FROM public.orders
  WHERE customer_id = 'U001'
  ORDER BY id
  LIMIT 1;

  SELECT id INTO other_order_id
  FROM public.orders
  WHERE customer_id <> 'U001'
  ORDER BY id
  LIMIT 1;

  IF owner_order_id IS NULL OR other_order_id IS NULL THEN
    RAISE EXCEPTION 'V743 smoke: required fixture orders are missing';
  END IF;

  INSERT INTO public.coupon_claims (coupon_id, customer_id)
  VALUES (1, 'U001')
  RETURNING id INTO claim_id;

  BEGIN
    INSERT INTO public.order_coupons (
      order_id,
      coupon_id,
      coupon_claim_id,
      code_snapshot,
      discount_type_snapshot,
      discount_value_snapshot,
      amount,
      applied_at
    ) VALUES (
      owner_order_id,
      2,
      claim_id,
      'CAMPFUN50',
      'fixed',
      50,
      50,
      now()
    );

    RAISE EXCEPTION
      'V743 smoke: mismatched coupon and claim unexpectedly succeeded';
  EXCEPTION
    WHEN foreign_key_violation OR check_violation THEN
      NULL;
  END;

  BEGIN
    INSERT INTO public.order_coupons (
      order_id,
      coupon_id,
      coupon_claim_id,
      code_snapshot,
      discount_type_snapshot,
      discount_value_snapshot,
      amount,
      applied_at
    ) VALUES (
      other_order_id,
      1,
      claim_id,
      'YURUIKAMP20',
      'fixed',
      200,
      200,
      now()
    );

    RAISE EXCEPTION
      'V743 smoke: another customer claim unexpectedly succeeded';
  EXCEPTION
    WHEN check_violation THEN
      NULL;
  END;

  INSERT INTO public.order_coupons (
    order_id,
    coupon_id,
    coupon_claim_id,
    code_snapshot,
    discount_type_snapshot,
    discount_value_snapshot,
    amount,
    applied_at
  ) VALUES (
    owner_order_id,
    1,
    claim_id,
    'YURUIKAMP20',
    'fixed',
    200,
    200,
    now()
  );
END
$$;

ROLLBACK;
