DO $$
BEGIN
  IF EXISTS (
    SELECT id
    FROM branch_features
    GROUP BY id
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'branch_features.id contains duplicate values';
  END IF;
END
$$;

ALTER TABLE branch_features
  DROP CONSTRAINT pk_branch_features,
  ADD CONSTRAINT pk_branch_features PRIMARY KEY (id),
  ADD CONSTRAINT uq_branch_features_branch_id_feature UNIQUE (branch_id, feature);
