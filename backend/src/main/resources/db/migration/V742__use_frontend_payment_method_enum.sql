-- Restore the frontend payment-method contract on live orders. The P4 source
-- evidence preserves credit-card versus line-pay before both were contracted
-- to the generic online value.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.orders orders
    LEFT JOIN migration.p4_order_source source
      ON source.id::TEXT = orders.id::TEXT
    WHERE source.id IS NULL
       OR source.payload->>'payment' NOT IN (
         'credit-card',
         'line-pay',
         'cod'
       )
  ) THEN
    RAISE EXCEPTION
      'V742 guard: an order has no supported source payment method';
  END IF;
END
$$;

ALTER TABLE public.orders
  DROP CONSTRAINT ck_orders_payment_method;

UPDATE public.orders orders
SET payment_method = source.payload->>'payment',
    updated_at = now()
FROM migration.p4_order_source source
WHERE source.id::TEXT = orders.id::TEXT;

ALTER TABLE public.orders
  ALTER COLUMN payment_method
  TYPE public.payment_method
  USING payment_method::public.payment_method;

COMMENT ON COLUMN public.orders.payment_method IS
  'Frontend payment method: credit-card, line-pay, or cod.';
