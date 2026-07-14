\set ON_ERROR_STOP on

CREATE TEMP TABLE p1_compatibility_issues (
  check_name TEXT NOT NULL,
  data_id TEXT NOT NULL,
  reason TEXT NOT NULL
);

DO $$
BEGIN
  IF to_regclass('public.movements') IS NOT NULL THEN
    EXECUTE 'CREATE TEMP VIEW p1_validation_movements AS SELECT * FROM public.movements';
    EXECUTE 'CREATE TEMP VIEW p1_validation_zone_blocks AS SELECT * FROM public.zone_blocks';
    EXECUTE 'CREATE TEMP VIEW p1_validation_closures AS SELECT * FROM public.campground_closures';
  ELSE
    EXECUTE 'CREATE TEMP VIEW p1_validation_movements AS SELECT * FROM migration.p5_legacy_movements';
    EXECUTE 'CREATE TEMP VIEW p1_validation_zone_blocks AS SELECT * FROM migration.p5_legacy_zone_blocks';
    EXECUTE 'CREATE TEMP VIEW p1_validation_closures AS SELECT * FROM migration.p5_legacy_campground_closures';
  END IF;
END $$;

INSERT INTO p1_compatibility_issues
SELECT 'admin_reference', ref.id, 'legacy admin reference cannot resolve a display name'
FROM (
  SELECT employee_id AS id FROM p1_validation_movements WHERE employee_id IS NOT NULL
  UNION SELECT created_by FROM p1_validation_zone_blocks WHERE created_by IS NOT NULL
  UNION SELECT created_by FROM p1_validation_closures WHERE created_by IS NOT NULL
) ref
LEFT JOIN admin_users admin_user ON admin_user.id = ref.id
WHERE admin_user.id IS NULL OR BTRIM(admin_user.name) = '';

INSERT INTO p1_compatibility_issues
SELECT 'location_alias', alias.alias, 'alias cannot resolve an active location display name'
FROM migration.p1_location_aliases alias
LEFT JOIN inventory_locations location ON location.id = alias.location_id
WHERE location.id IS NULL OR NOT location.active OR BTRIM(location.name) = '';

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*),
  'issues', COALESCE(jsonb_agg(jsonb_build_object(
    'check', check_name, 'id', data_id, 'reason', reason
  ) ORDER BY check_name, data_id), '[]'::jsonb)
))
FROM p1_compatibility_issues;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p1_compatibility_issues) THEN
    RAISE EXCEPTION 'P1 compatibility validation failed with % issue(s)',
      (SELECT count(*) FROM p1_compatibility_issues);
  END IF;
END $$;
