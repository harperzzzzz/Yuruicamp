DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM product_variants
    GROUP BY product_id, color, size, specification
    HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION
      'Cannot enforce unique product variant specification: duplicate combinations exist';
  END IF;
END $$;

ALTER TABLE product_variants
  ADD CONSTRAINT uq_product_variants_product_color_size_specification
  UNIQUE NULLS NOT DISTINCT (product_id, color, size, specification);

