\set ON_ERROR_STOP on

BEGIN;

UPDATE public.coupons
SET issue_quantity = 1,
    claimed_quantity = 0,
    status = 'active',
    valid_from = now() - INTERVAL '1 day',
    valid_until = now() + INTERVAL '1 day'
WHERE id = 1;

INSERT INTO public.coupon_claims (coupon_id, customer_id)
VALUES (1, 'U001');

DO $$
BEGIN
  BEGIN
    INSERT INTO public.coupon_claims (coupon_id, customer_id)
    VALUES (1, 'U002');
    RAISE EXCEPTION 'V738 smoke: second claim unexpectedly succeeded';
  EXCEPTION
    WHEN check_violation THEN
      NULL;
  END;
END
$$;

DO $$
BEGIN
  IF (SELECT claimed_quantity FROM public.coupons WHERE id = 1) <> 1 THEN
    RAISE EXCEPTION 'V738 smoke: claimed_quantity is not 1';
  END IF;

  IF (SELECT count(*) FROM public.coupon_claims WHERE coupon_id = 1) <> 1 THEN
    RAISE EXCEPTION 'V738 smoke: persisted claim count is not 1';
  END IF;
END
$$;

ROLLBACK;
