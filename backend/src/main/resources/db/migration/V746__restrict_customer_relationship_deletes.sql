ALTER TABLE public.customer_preferences
  DROP CONSTRAINT fk_customer_preferences_customer_id,
  ADD CONSTRAINT fk_customer_preferences_customer_id
    FOREIGN KEY (customer_id)
    REFERENCES public.customers(id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT;

ALTER TABLE public.customer_shipping_addresses
  DROP CONSTRAINT fk_customer_shipping_addresses_customer_id,
  ADD CONSTRAINT fk_customer_shipping_addresses_customer_id
    FOREIGN KEY (customer_id)
    REFERENCES public.customers(id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT;

ALTER TABLE public.customer_tag_assignments
  DROP CONSTRAINT fk_customer_tag_assignments_customer_id,
  ADD CONSTRAINT fk_customer_tag_assignments_customer_id
    FOREIGN KEY (customer_id)
    REFERENCES public.customers(id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT;
