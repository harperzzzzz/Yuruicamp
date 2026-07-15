-- A coupon remains consumed after cancellation, return, or refund. Claims may
-- never transition from consumed back to claimed, so the legacy redemption
-- adjustment ledger is no longer part of the live model.

CREATE FUNCTION public.enforce_coupon_claim_status_transition()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;

  IF OLD.status = 'claimed'::public.coupon_claim_status
     AND NEW.status IN (
       'consumed'::public.coupon_claim_status,
       'revoked'::public.coupon_claim_status,
       'expired'::public.coupon_claim_status
     ) THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION
    'Invalid coupon claim transition from % to %', OLD.status, NEW.status
    USING ERRCODE = 'check_violation';
END
$$;

CREATE TRIGGER trg_coupon_claims_enforce_status_transition
BEFORE UPDATE OF status ON public.coupon_claims
FOR EACH ROW
EXECUTE FUNCTION public.enforce_coupon_claim_status_transition();

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.coupon_usage_adjustments
  ) THEN
    RAISE EXCEPTION
      'V741 guard: coupon_usage_adjustments contains audit records';
  END IF;
END
$$;

DROP TABLE public.coupon_usage_adjustments;

COMMENT ON TABLE public.coupon_claims IS
  'Current coupon ownership state; consumed claims are never returned after cancellation, return, or refund.';
