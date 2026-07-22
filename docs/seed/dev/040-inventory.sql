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

-- Booking E-1：租借庫位、營區對照、有效 listing 與實體庫存。
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
    'DEV-RENTAL-C002',
    'DEV-RENTAL-C002',
    'rental',
    'campground',
    NULL,
    '悠旅森林露營區租借庫位',
    true
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    active = EXCLUDED.active,
    updated_at = now();

INSERT INTO public.campground_rental_locations (campground_id, location_id)
VALUES ('C002', 'DEV-RENTAL-C002')
ON CONFLICT (campground_id) DO UPDATE SET
    location_id = EXCLUDED.location_id;

INSERT INTO public.rental_listings (
    id,
    campground_id,
    rental_sku_variant_id,
    price_per_day_weekday,
    price_per_day_holiday,
    discount,
    terrain,
    description,
    active
)
VALUES (
    'RL-DEV-C002-001',
    'C002',
    'RSV-DEV-001',
    180.00,
    220.00,
    0.00,
    '草地',
    'E-1 Swagger 租借 listing 範例。',
    true
)
ON CONFLICT (id) DO UPDATE SET
    campground_id = EXCLUDED.campground_id,
    rental_sku_variant_id = EXCLUDED.rental_sku_variant_id,
    price_per_day_weekday = EXCLUDED.price_per_day_weekday,
    price_per_day_holiday = EXCLUDED.price_per_day_holiday,
    discount = EXCLUDED.discount,
    terrain = EXCLUDED.terrain,
    description = EXCLUDED.description,
    active = EXCLUDED.active,
    updated_at = now();

INSERT INTO public.rental_sku_variant_stocks (
    location_id,
    rental_sku_variant_id,
    on_hand_quantity
)
VALUES ('DEV-RENTAL-C002', 'RSV-DEV-001', 6)
ON CONFLICT (location_id, rental_sku_variant_id) DO UPDATE SET
    on_hand_quantity = EXCLUDED.on_hand_quantity,
    updated_at = now();
