-- Consolidate the legacy branches.image value into the authoritative
-- branches.image_url column before removing the legacy column.
UPDATE branches
SET image_url = image,
    updated_at = now()
WHERE image IS NOT NULL
  AND btrim(image) <> ''
  AND (image_url IS NULL OR btrim(image_url) = '');

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM branches
    WHERE image IS NOT NULL
      AND btrim(image) <> ''
      AND (image_url IS NULL OR btrim(image_url) = '')
  ) THEN
    RAISE EXCEPTION 'branches.image contains values that were not migrated to image_url';
  END IF;
END
$$;

ALTER TABLE branches DROP COLUMN image;
