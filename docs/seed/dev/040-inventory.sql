-- 建立 Swagger Checkout 可使用的門市庫位與 V001 庫存。
-- V001 由 030-catalog.sql 建立，因此本檔必須在商品目錄之後載入。
INSERT INTO public.inventory_locations (
    id,
    code,
    inventory_domain,
    type,
    branch_id,
    name,
    active
)
VALUES (
    'DEV-STORE-MAIN',
    'DEV-STORE-MAIN',
    'store',
    'main',
    NULL,
    '開發測試主倉',
    true
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    active = EXCLUDED.active,
    updated_at = now();

INSERT INTO public.inventory_stocks (
    location_id,
    variant_id,
    on_hand_quantity,
    inventory_domain
)
VALUES (
    'DEV-STORE-MAIN',
    'V001',
    10,
    'store'
)
ON CONFLICT (location_id, variant_id) DO UPDATE SET
    on_hand_quantity = EXCLUDED.on_hand_quantity,
    updated_at = now();
