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

-- 前端公開品牌使用 12 個 canonical slug；yuruicamp 保留為站內自有品牌。
INSERT INTO public.brands (id, name, logo_url, sort_order) VALUES
  ('yuruicamp', 'Yuruicamp', NULL, 0),
  ('snow-peak', 'Snow Peak', NULL, 1),
  ('osprey', 'Osprey', NULL, 2),
  ('msr', 'MSR', NULL, 3),
  ('coleman', 'Coleman', NULL, 4),
  ('patagonia', 'Patagonia', NULL, 5),
  ('deuter', 'Deuter', NULL, 6),
  ('sawyer', 'Sawyer', NULL, 7),
  ('black-diamond', 'Black Diamond', NULL, 8),
  ('helinox', 'Helinox', NULL, 9),
  ('columbia', 'Columbia', NULL, 10),
  ('ogawa', 'Ogawa', NULL, 11),
  ('therm-a-rest', 'Therm-a-Rest', NULL, 12)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    logo_url = EXCLUDED.logo_url,
    sort_order = EXCLUDED.sort_order,
    updated_at = now();

-- 前端 catalog/campgrounds.json 的 8 個公開營區。
INSERT INTO public.campgrounds (id, name, region, description, active)
VALUES
    ('C002', '雲海仙境露營區', '北部', '坐落於海拔 1,800 公尺的山頂，每逢清晨雲海翻騰，是北台灣最壯觀的高山露營地。夜晚氣溫涼爽，星空清晰可見，是追求自然療癒的首選。', true),
    ('C003', '溪谷秘境野營地', '中部', '緊鄰清澈溪流，水聲潺潺，夏日親水露營的不二之選。夜晚可觀星，營地旁設有天然戲水區，全家出遊的完美選擇。', true),
    ('C004', '太平山森林豪華露營', '北部', '台灣頂級 Glamping 體驗，免搭帳篷，入住配備空調與獨立洗手間的豪華帳型，享受森林芬多精與雲海美景，是犒賞自己的奢華選擇。', true),
    ('C005', '南台灣星空草原營地', '南部', '位於屏東平原，視野開闊，光害極低，是南台灣最佳觀星露營勝地。廣闊草地讓孩子盡情奔跑，寵物也歡迎入住。', true),
    ('C006', '花蓮海岸風露營區', '東部', '緊鄰太平洋，清晨可見日出從海面升起，聆聽浪濤聲入睡，提供有雨棚遮蔽，無論晴雨都能盡情享受海岸露營。', true),
    ('C007', '阿里山雲霧繚繞營地', '南部', '海拔 2,200 公尺，阿里山林道旁，終年雲霧繚繞，日出與神木相伴。全區設有完善雨棚，是愛雨族的最愛。', true),
    ('C008', '宜蘭礁溪湯泉露營', '北部', '全台唯一溫泉露營體驗，帳篷旁設有私人泡湯池，泡完湯直接鑽進睡袋。溪邊環境清幽，可攜帶寵物同行。', true),
    ('C009', '台中武陵溪流野營', '中部', '武陵農場旁，四季各有風情：春賞櫻、夏戲水、秋楓紅、冬雪景。溪流旁的棧板區是最受歡迎的位置，也提供完整裝備租借。', true),
    ('DEV-CAMP-INACTIVE', '停用開發營區', '測試區', '用來驗證公開列表不回傳 inactive 營區。', false)
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
    ('Z001', 'C002', '草皮區', 4, 1000.00, 1500.00, 10, true),
    ('Z002', 'C002', '雨棚區', 6, 1200.00, 1800.00, 5, true),
    ('Z003', 'C003', '碎石區', 4, 800.00, 1200.00, 15, true),
    ('Z004', 'C003', '棧板區', 4, 900.00, 1300.00, 8, true),
    ('Z005', 'C004', '免搭帳／豪華露營 (Glamping)', 2, 3500.00, 5000.00, 4, true),
    ('Z006', 'C005', '草皮區', 6, 700.00, 1100.00, 20, true),
    ('Z007', 'C006', '草皮區', 4, 900.00, 1400.00, 12, true),
    ('Z008', 'C006', '雨棚區', 4, 1100.00, 1600.00, 6, true),
    ('Z009', 'C007', '棧板區', 4, 1100.00, 1700.00, 10, true),
    ('Z010', 'C008', '草皮區', 4, 1500.00, 2200.00, 8, true),
    ('Z011', 'C008', '免搭帳／豪華露營 (Glamping)', 2, 4000.00, 6000.00, 3, true),
    ('Z012', 'C009', '碎石區', 4, 950.00, 1450.00, 14, true),
    ('Z013', 'C009', '棧板區', 4, 1050.00, 1600.00, 8, true),
    -- 舊 Swagger fixture 保留 ID 但停用，避免重跑 Seed 時破壞既有外鍵。
    ('C002-Z-A', 'C002', '舊版草地營位', 4, 1200.00, 1500.00, 8, false),
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

-- 營區環境與設施標籤採固定 ID，供 Seed 與後續 API 對照。
INSERT INTO public.environment_tags (id, code, label, sort_order, active) OVERRIDING SYSTEM VALUE VALUES
    (1, 'high-altitude', '高海拔', 0, true),
    (2, 'cloud-sea', '有雲海', 1, true),
    (3, 'forest', '森林系', 2, true),
    (4, 'low-altitude', '低海拔', 3, true),
    (5, 'stream', '有溪流', 4, true)
ON CONFLICT (id) DO UPDATE SET
    code = EXCLUDED.code,
    label = EXCLUDED.label,
    sort_order = EXCLUDED.sort_order,
    active = EXCLUDED.active;

SELECT setval(
    'public.environment_tags_id_seq',
    GREATEST((SELECT max(id) FROM public.environment_tags), 1),
    true
);

INSERT INTO public.facility_tags (id, code, label, sort_order, active) OVERRIDING SYSTEM VALUE VALUES
    (1, 'private-bathroom', '獨立衛浴', 0, true),
    (2, 'equipment-rental', '裝備租借', 1, true),
    (3, 'rain-shelter', '有雨棚', 2, true),
    (4, 'playground', '兒童遊樂設施', 3, true),
    (5, 'pet-friendly', '寵物友善', 4, true),
    (6, 'cabin', '小木屋', 5, true),
    (7, 'private-area', '可包區', 6, true)
ON CONFLICT (id) DO UPDATE SET
    code = EXCLUDED.code,
    label = EXCLUDED.label,
    sort_order = EXCLUDED.sort_order,
    active = EXCLUDED.active;

SELECT setval(
    'public.facility_tags_id_seq',
    GREATEST((SELECT max(id) FROM public.facility_tags), 1),
    true
);

DELETE FROM public.campground_environment_tags
WHERE campground_id IN ('C002', 'C003', 'C004', 'C005', 'C006', 'C007', 'C008', 'C009');

INSERT INTO public.campground_environment_tags (campground_id, tag_id) VALUES
    ('C002', 1), ('C002', 2), ('C002', 3),
    ('C003', 4), ('C003', 5), ('C003', 3),
    ('C004', 1), ('C004', 3),
    ('C005', 4),
    ('C006', 4), ('C006', 5),
    ('C007', 1), ('C007', 2), ('C007', 3),
    ('C008', 4), ('C008', 5),
    ('C009', 1), ('C009', 5), ('C009', 3);

DELETE FROM public.campground_facility_tags
WHERE campground_id IN ('C002', 'C003', 'C004', 'C005', 'C006', 'C007', 'C008', 'C009');

INSERT INTO public.campground_facility_tags (campground_id, tag_id) VALUES
    ('C002', 1), ('C002', 2), ('C002', 3),
    ('C003', 4), ('C003', 5), ('C003', 2),
    ('C004', 6), ('C004', 1), ('C004', 7),
    ('C005', 5), ('C005', 2),
    ('C006', 1), ('C006', 3), ('C006', 2),
    ('C007', 3), ('C007', 2), ('C007', 1),
    ('C008', 1), ('C008', 7), ('C008', 5), ('C008', 2),
    ('C009', 2), ('C009', 4), ('C009', 3);

-- 前端 marketing/branches.json 的 3 個固定門市。
INSERT INTO public.branches (
    id, name, address, phone, latitude, longitude, map_query, business_hours, image_url
) VALUES
    ('branch-001', 'Yuruicamp 台北旗艦店', '台北市信義區信義路五段100號 B1', '02-8789-1234', 25.033000, 121.565400, '台北市信義區信義路五段100號', '週一至週日 10:00–20:00', 'https://picsum.photos/seed/store1/600/400'),
    ('branch-002', 'Yuruicamp 台中中港店', '台中市西屯區文心路二段101號', '04-2234-5678', 24.163700, 120.646700, '台中市西屯區文心路二段101號', '週一至週五 11:00–21:00，週六日 10:00–21:00', 'https://picsum.photos/seed/store2/600/400'),
    ('branch-003', 'Yuruicamp 高雄左營店', '高雄市左營區重聖街199號', '07-5567-8901', 22.697800, 120.299100, '高雄市左營區重聖街199號', '週一至週五 11:00–21:00，週六日 10:00–21:00', 'https://picsum.photos/seed/store3/600/400')
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    address = EXCLUDED.address,
    phone = EXCLUDED.phone,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    map_query = EXCLUDED.map_query,
    business_hours = EXCLUDED.business_hours,
    image_url = EXCLUDED.image_url,
    updated_at = now();

DELETE FROM public.branch_features
WHERE branch_id IN ('branch-001', 'branch-002', 'branch-003');

INSERT INTO public.branch_features (branch_id, feature) VALUES
    ('branch-001', '體驗區'),
    ('branch-001', '專業諮詢'),
    ('branch-001', '租借服務'),
    ('branch-001', '停車場'),
    ('branch-002', '體驗區'),
    ('branch-002', '專業諮詢'),
    ('branch-002', '停車場'),
    ('branch-003', '體驗區'),
    ('branch-003', '租借服務')
ON CONFLICT (branch_id, feature) DO NOTHING;

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
-- G-1：後台 10 個功能頁面的 view／edit 權限字典。
INSERT INTO public.admin_permissions (code, section, action)
VALUES
    ('analytics.view', 'analytics', 'view'),
    ('analytics.edit', 'analytics', 'edit'),
    ('orders.view', 'orders', 'view'),
    ('orders.edit', 'orders', 'edit'),
    ('movement.view', 'movement', 'view'),
    ('movement.edit', 'movement', 'edit'),
    ('products.view', 'products', 'view'),
    ('products.edit', 'products', 'edit'),
    ('customers.view', 'customers', 'view'),
    ('customers.edit', 'customers', 'edit'),
    ('discounts.view', 'discounts', 'view'),
    ('discounts.edit', 'discounts', 'edit'),
    ('reviews.view', 'reviews', 'view'),
    ('reviews.edit', 'reviews', 'edit'),
    ('booking-calendar.view', 'booking-calendar', 'view'),
    ('booking-calendar.edit', 'booking-calendar', 'edit'),
    ('bookings.view', 'bookings', 'view'),
    ('bookings.edit', 'bookings', 'edit'),
    ('permissions.view', 'permissions', 'view'),
    ('permissions.edit', 'permissions', 'edit')
ON CONFLICT (code) DO UPDATE SET
    section = EXCLUDED.section,
    action = EXCLUDED.action;

-- admin 擁有全部權限；其他角色只放入日常工作需要的預設權限。
INSERT INTO public.admin_role_permissions (role, permission_code)
SELECT 'admin', code
FROM public.admin_permissions
ON CONFLICT (role, permission_code) DO NOTHING;

INSERT INTO public.admin_role_permissions (role, permission_code)
VALUES
    ('operator', 'analytics.view'),
    ('operator', 'orders.view'),
    ('operator', 'orders.edit'),
    ('operator', 'customers.view'),
    ('operator', 'discounts.view'),
    ('operator', 'reviews.view'),
    ('operator', 'reviews.edit'),
    ('operator', 'booking-calendar.view'),
    ('operator', 'bookings.view'),
    ('operator', 'bookings.edit'),
    ('warehouse', 'movement.view'),
    ('warehouse', 'movement.edit'),
    ('warehouse', 'products.view'),
    ('warehouse', 'products.edit')
ON CONFLICT (role, permission_code) DO NOTHING;
