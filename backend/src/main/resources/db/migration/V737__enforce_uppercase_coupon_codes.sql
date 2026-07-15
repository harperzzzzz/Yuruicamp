-- Coupon codes are canonical uppercase identifiers. Reject lowercase,
-- surrounding whitespace, blank values, and case-insensitive duplicates.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.coupons
    WHERE code <> upper(btrim(code))
       OR btrim(code) = ''
  ) THEN
    RAISE EXCEPTION
      'V737 guard: public.coupons contains a non-canonical coupon code';
  END IF;

  IF EXISTS (
    SELECT upper(code)
    FROM public.coupons
    GROUP BY upper(code)
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION
      'V737 guard: public.coupons contains case-insensitive duplicates';
  END IF;
END
$$;

ALTER TABLE public.coupons
  DROP CONSTRAINT uq_coupons_code;

ALTER TABLE public.coupons
  ADD CONSTRAINT ck_coupons_code_canonical CHECK (
    btrim(code) <> ''
    AND code = btrim(code)
    AND code = upper(code)
  );

CREATE UNIQUE INDEX uq_coupons_code_upper
  ON public.coupons (upper(code));
