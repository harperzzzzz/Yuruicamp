-- 商品目錄共用參考資料；必須先於商品資料載入。
INSERT INTO public.product_categories (id, code, name, sort_order) OVERRIDING SYSTEM VALUE VALUES
  (1, 'tent', '帳篷', 0),
  (2, 'sleeping-bag', '睡袋', 1),
  (3, 'cookware', '炊具', 2),
  (4, 'lighting', '燈具', 3),
  (5, 'backpack', '背包', 4),
  (6, 'other', '其他', 5)
ON CONFLICT DO NOTHING;

SELECT setval(
    'public.product_categories_id_seq',
    GREATEST((SELECT max(id) FROM public.product_categories), 1),
    true
);

INSERT INTO public.brands (id, name, logo_url, sort_order) VALUES
  ('coleman', 'Coleman', NULL, 0),
  ('msr', 'MSR', NULL, 1),
  ('yuruicamp', 'Yuruicamp', NULL, 2),
  ('snow-peak', 'Snow Peak', NULL, 3)
ON CONFLICT DO NOTHING;

-- Booking E-1：公開營區、營位與單例政策。
INSERT INTO public.campgrounds (id, name, region, description, active)
VALUES (
    'C002',
    '悠旅森林露營區',
    '南投縣',
    'E-1 Swagger 公開讀取使用的最小開發營區。',
    true
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    region = EXCLUDED.region,
    description = EXCLUDED.description,
    active = EXCLUDED.active,
    updated_at = now();

INSERT INTO public.campgrounds (id, name, region, description, active)
VALUES ('C009', '停用開發營區', '測試區', '用來驗證公開列表不回傳 inactive 營區。', false)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    region = EXCLUDED.region,
    description = EXCLUDED.description,
    active = EXCLUDED.active,
    updated_at = now();

INSERT INTO public.campground_zones (
    id,
    campground_id,
    type,
    capacity_per_site,
    price_weekday,
    price_holiday,
    total_sites,
    active
)
VALUES
    ('C002-Z-A', 'C002', '草地營位', 4, 1200.00, 1500.00, 8, true),
    ('C002-Z-HIDDEN', 'C002', '停用測試營位', 2, 800.00, 1000.00, 1, false)
ON CONFLICT (id) DO UPDATE SET
    campground_id = EXCLUDED.campground_id,
    type = EXCLUDED.type,
    capacity_per_site = EXCLUDED.capacity_per_site,
    price_weekday = EXCLUDED.price_weekday,
    price_holiday = EXCLUDED.price_holiday,
    total_sites = EXCLUDED.total_sites,
    active = EXCLUDED.active,
    updated_at = now();

INSERT INTO public.booking_policies (
    id,
    booking_window_days,
    advance_days,
    max_nights,
    timezone,
    date_boundary_hour,
    low_availability_threshold
)
VALUES (1, 90, 1, 7, 'Asia/Taipei', 0, 20)
ON CONFLICT (id) DO UPDATE SET
    booking_window_days = EXCLUDED.booking_window_days,
    advance_days = EXCLUDED.advance_days,
    max_nights = EXCLUDED.max_nights,
    timezone = EXCLUDED.timezone,
    date_boundary_hour = EXCLUDED.date_boundary_hour,
    low_availability_threshold = EXCLUDED.low_availability_threshold,
    updated_at = now();

DELETE FROM public.booking_policy_occupying_statuses WHERE policy_id = 1;

INSERT INTO public.booking_policy_occupying_statuses (policy_id, status)
VALUES (1, 'pending'), (1, 'confirmed');

INSERT INTO public.calendar_dates (
    calendar_date,
    is_holiday,
    holiday_name,
    source_version,
    effective_at
)
VALUES (DATE '2026-10-10', true, '國慶日', 'dev-booking-e1', now())
ON CONFLICT (calendar_date) DO UPDATE SET
    is_holiday = EXCLUDED.is_holiday,
    holiday_name = EXCLUDED.holiday_name,
    source_version = EXCLUDED.source_version,
    effective_at = EXCLUDED.effective_at,
    updated_at = now();
