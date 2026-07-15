-- An order coupon must reference the same coupon as its claim, and the claim
-- must belong to the customer who owns the order.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.order_coupons usage
    JOIN public.coupon_claims claim
      ON claim.id = usage.coupon_claim_id
    JOIN public.orders orders
      ON orders.id = usage.order_id
    WHERE usage.coupon_id IS NULL
       OR usage.coupon_id IS DISTINCT FROM claim.coupon_id
       OR orders.customer_id IS DISTINCT FROM claim.customer_id
  ) THEN
    RAISE EXCEPTION
      'V743 guard: an order coupon has an inconsistent coupon claim';
  END IF;
END
$$;

ALTER TABLE public.coupon_claims
  ADD CONSTRAINT uq_coupon_claims_id_coupon_id
    UNIQUE (id, coupon_id);

ALTER TABLE public.order_coupons
  ALTER COLUMN coupon_id SET NOT NULL;

ALTER TABLE public.order_coupons
  DROP CONSTRAINT fk_order_coupons_coupon_claim_id;

ALTER TABLE public.order_coupons
  DROP CONSTRAINT fk_order_coupons_coupon_id;

ALTER TABLE public.order_coupons
  ADD CONSTRAINT fk_order_coupons_coupon_id
    FOREIGN KEY (coupon_id) REFERENCES public.coupons(id)
    ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public.order_coupons
  ADD CONSTRAINT fk_order_coupons_claim_coupon_pair
    FOREIGN KEY (coupon_claim_id, coupon_id)
    REFERENCES public.coupon_claims(id, coupon_id)
    ON UPDATE CASCADE ON DELETE RESTRICT;

CREATE FUNCTION public.validate_order_coupon_claim_owner()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.orders orders
    JOIN public.coupon_claims claim
      ON claim.id = NEW.coupon_claim_id
    WHERE orders.id = NEW.order_id
      AND orders.customer_id = claim.customer_id
      AND claim.coupon_id = NEW.coupon_id
  ) THEN
    RAISE EXCEPTION
      'Coupon claim does not belong to the order customer'
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END
$$;

CREATE TRIGGER trg_order_coupons_validate_claim
BEFORE INSERT OR UPDATE OF order_id, coupon_id, coupon_claim_id
ON public.order_coupons
FOR EACH ROW
EXECUTE FUNCTION public.validate_order_coupon_claim_owner();
