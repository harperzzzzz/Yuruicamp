\set ON_ERROR_STOP on

BEGIN;

INSERT INTO public.coupon_claims (coupon_id, customer_id)
VALUES (1, 'U001');

UPDATE public.coupon_claims
SET status = 'consumed',
    consumed_at = now()
WHERE coupon_id = 1
  AND customer_id = 'U001';

DO $$
BEGIN
  BEGIN
    UPDATE public.coupon_claims
    SET status = 'claimed',
        consumed_at = NULL
    WHERE coupon_id = 1
      AND customer_id = 'U001';

    RAISE EXCEPTION
      'V741 smoke: consumed coupon unexpectedly returned to claimed';
  EXCEPTION
    WHEN check_violation THEN
      NULL;
  END;
END
$$;

DO $$
BEGIN
  IF (
    SELECT status
    FROM public.coupon_claims
    WHERE coupon_id = 1
      AND customer_id = 'U001'
  ) <> 'consumed'::public.coupon_claim_status THEN
    RAISE EXCEPTION 'V741 smoke: claim did not remain consumed';
  END IF;
END
$$;

ROLLBACK;
