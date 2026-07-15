CREATE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

ALTER TABLE equipment_images
  ADD COLUMN created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE equipment_specifications
  ADD COLUMN created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE equipment_tags
  ADD COLUMN created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE equipment_interest_tags
  ADD COLUMN created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE TRIGGER trg_brands_set_updated_at
BEFORE UPDATE ON brands
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_product_categories_set_updated_at
BEFORE UPDATE ON product_categories
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_equipment_items_set_updated_at
BEFORE UPDATE ON equipment_items
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_equipment_images_set_updated_at
BEFORE UPDATE ON equipment_images
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_equipment_specifications_set_updated_at
BEFORE UPDATE ON equipment_specifications
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_equipment_tags_set_updated_at
BEFORE UPDATE ON equipment_tags
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_equipment_interest_tags_set_updated_at
BEFORE UPDATE ON equipment_interest_tags
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE FUNCTION touch_equipment_item_from_child()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    UPDATE equipment_items SET updated_at = NOW() WHERE id = OLD.item_id;
    RETURN OLD;
  ELSIF TG_OP = 'INSERT' THEN
    UPDATE equipment_items SET updated_at = NOW() WHERE id = NEW.item_id;
    RETURN NEW;
  END IF;

  UPDATE equipment_items
  SET updated_at = NOW()
  WHERE id = OLD.item_id OR id = NEW.item_id;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_equipment_images_touch_item
AFTER INSERT OR UPDATE OR DELETE ON equipment_images
FOR EACH ROW EXECUTE FUNCTION touch_equipment_item_from_child();

CREATE TRIGGER trg_equipment_specifications_touch_item
AFTER INSERT OR UPDATE OR DELETE ON equipment_specifications
FOR EACH ROW EXECUTE FUNCTION touch_equipment_item_from_child();

CREATE TRIGGER trg_equipment_tags_touch_item
AFTER INSERT OR UPDATE OR DELETE ON equipment_tags
FOR EACH ROW EXECUTE FUNCTION touch_equipment_item_from_child();

CREATE TRIGGER trg_equipment_interest_tags_touch_item
AFTER INSERT OR UPDATE OR DELETE ON equipment_interest_tags
FOR EACH ROW EXECUTE FUNCTION touch_equipment_item_from_child();
