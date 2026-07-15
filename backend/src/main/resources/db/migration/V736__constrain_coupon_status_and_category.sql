-- Constrain coupon lifecycle and eligibility categories to the values used by
-- the current application contract. Expiration remains derived from the
-- valid_from and valid_until timestamps.

-- Reuse the coupon_status and coupon_category enums retained from the P0
-- schema. Their values already match the live application contract.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.coupons
    WHERE status::TEXT NOT IN ('active', 'disabled')
  ) THEN
    RAISE EXCEPTION
      'V736 guard: public.coupons contains an unsupported status';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.coupons
    WHERE category IS NOT NULL
      AND category::TEXT NOT IN (
        'promotion',
        'birthday',
        'firstPurchase'
      )
  ) THEN
    RAISE EXCEPTION
      'V736 guard: public.coupons contains an unsupported category';
  END IF;
END
$$;

UPDATE public.coupons
SET category = 'promotion',
    updated_at = now()
WHERE category IS NULL;

ALTER TABLE public.coupons
  ALTER COLUMN status
  TYPE public.coupon_status
  USING status::public.coupon_status;

ALTER TABLE public.coupons
  ALTER COLUMN category
  TYPE public.coupon_category
  USING category::public.coupon_category;

ALTER TABLE public.coupons
  ALTER COLUMN category SET NOT NULL;
