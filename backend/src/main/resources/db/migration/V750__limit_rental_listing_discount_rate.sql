ALTER TABLE public.rental_listings
  DROP CONSTRAINT ck_rental_listings_prices;

ALTER TABLE public.rental_listings
  ADD CONSTRAINT ck_rental_listings_prices
  CHECK (
    price_per_day_weekday >= 0
    AND price_per_day_holiday >= 0
    AND discount >= 0
    AND discount <= 0.30
  );
