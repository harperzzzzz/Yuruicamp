-- =============================================================================
-- Dev seed: minimal catalog for Product API Contract v0.1 (B-1 / B-2)
-- 開發用最小商品種子：讓 GET /api/products 有資料可驗收
--
-- Fresh Docker volume: mounted as docker-entrypoint-initdb.d/002-...
-- Existing DB: docker exec -i yuruicamp-db psql -U postgres -d yuruicamp < docs/seed/002-dev-catalog-min.sql
-- =============================================================================

BEGIN;

INSERT INTO public.product_categories (id, code, name, sort_order)
OVERRIDING SYSTEM VALUE
VALUES (1, 'tent', '帳篷', 0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.brands (id, name, logo_url, sort_order)
VALUES ('coleman', 'Coleman', NULL, 0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.equipment_items (id, category_id, brand_id, name, description, active)
VALUES (
  'E001',
  1,
  'coleman',
  'Coleman 六人帳篷',
  '<p>適合露營使用。</p>',
  true
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.equipment_images (item_id, sort_order, url, alt_text)
VALUES ('E001', 0, '/assets/images/products/P001-1.jpg', 'Coleman 六人帳篷')
ON CONFLICT (item_id, sort_order) DO NOTHING;

INSERT INTO public.products (id, status, item_id)
VALUES ('P001', 'active', 'E001')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.product_variants (id, product_id, sku, color, size, price, specification, status)
VALUES
  ('V001', 'P001', 'TENT-OLIVE', '深橄欖綠', NULL, 3200.00, '深橄欖綠', 'active'),
  ('V002', 'P001', 'TENT-SAND', '沙漠棕', NULL, 3300.00, '沙漠棕', 'active')
ON CONFLICT (id) DO NOTHING;

COMMIT;
