-- Booking E-1：公休資料需要一位固定的開發管理員作為建立者。
-- 真 Firebase Google 後台登入：請在本機另加白名單（勿把真實 email 寫進本檔）
-- → 見 021-admin-google-whitelist.example.sql
INSERT INTO public.admin_users (id, name, email, role, active)
VALUES (
    'DEV-BOOKING-ADMIN',
    'Booking Seed Admin',
    'booking-seed@example.test',
    'admin',
    true
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    email = EXCLUDED.email,
    role = EXCLUDED.role,
    active = EXCLUDED.active,
    updated_at = now();

INSERT INTO public.campground_closures (
    id,
    campground_id,
    closure_type,
    start_date,
    end_date,
    weekday,
    effective_from,
    effective_to,
    reason,
    created_by
)
OVERRIDING SYSTEM VALUE
VALUES (
    900001,
    'C002',
    'date_range',
    DATE '2026-09-01',
    DATE '2026-09-02',
    NULL,
    NULL,
    NULL,
    'E-1 Swagger 公休範例',
    'DEV-BOOKING-ADMIN'
)
ON CONFLICT (id) DO UPDATE SET
    campground_id = EXCLUDED.campground_id,
    closure_type = EXCLUDED.closure_type,
    start_date = EXCLUDED.start_date,
    end_date = EXCLUDED.end_date,
    weekday = EXCLUDED.weekday,
    effective_from = EXCLUDED.effective_from,
    effective_to = EXCLUDED.effective_to,
    reason = EXCLUDED.reason,
    created_by = EXCLUDED.created_by,
    updated_at = now();

SELECT setval(
    'public.campground_closures_id_seq',
    GREATEST((SELECT max(id) FROM public.campground_closures), 1),
    true
);

-- 目前正式 Firebase Google 登入會員；保留真實 UID，讓重建開發資料庫後仍綁定同一帳號。
INSERT INTO public.customers (
    id,
    name,
    phone,
    email,
    birthday,
    registered_at,
    tier,
    tier_name,
    points,
    first_purchase_used,
    auth_provider,
    firebase_uid,
    created_at,
    updated_at,
    avatar_url,
    deleted_at,
    status
)
VALUES (
    '99eeb41d1cc948ff98bca94d90ddfa93',
    '粉紅雞',
    NULL,
    'pinkchickstarburstc8763@gmail.com',
    NULL,
    TIMESTAMPTZ '2026-07-22T12:02:12.881906+00:00',
    NULL,
    NULL,
    0,
    false,
    'google',
    'FLE7Yl1bB5QwmuSZEANeUd5PyKe2',
    TIMESTAMPTZ '2026-07-22T12:02:12.881906+00:00',
    TIMESTAMPTZ '2026-07-22T12:02:12.881906+00:00',
    'https://lh3.googleusercontent.com/a/ACg8ocLomWN6fwbkaMm8Dkp6jT6ZJi_pn0-9-FnfXDgEaDi5HusY5xw=s96-c',
    NULL,
    'active'
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    phone = EXCLUDED.phone,
    email = EXCLUDED.email,
    birthday = EXCLUDED.birthday,
    registered_at = EXCLUDED.registered_at,
    tier = EXCLUDED.tier,
    tier_name = EXCLUDED.tier_name,
    points = EXCLUDED.points,
    first_purchase_used = EXCLUDED.first_purchase_used,
    auth_provider = EXCLUDED.auth_provider,
    firebase_uid = EXCLUDED.firebase_uid,
    avatar_url = EXCLUDED.avatar_url,
    deleted_at = EXCLUDED.deleted_at,
    status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at;

-- frontend customers begin
-- 訂單與預訂的固定開發會員；皆為 example.com 假資料。
INSERT INTO public.customers (id, name, phone, email, birthday, registered_at, tier, tier_name, points, first_purchase_used, auth_provider, avatar_url, status)
VALUES
    ('U001', 'Amy Chen', '0912345678', 'amy@example.com', DATE '1992-03-18', TIMESTAMPTZ '2025-01-15T00:00:00+08:00', 'guide', '嚮導', 4240, false, 'google', '/assets/images/camp_hero2.png', 'active'),
    ('U002', '林美惠', '0923456789', 'lin@example.com', DATE '1998-07-22', TIMESTAMPTZ '2025-01-20T00:00:00+08:00', 'guide', '嚮導', 2485, false, 'facebook', '/assets/images/camp_hero3.png', 'active'),
    ('U003', '張志偉', '0934567890', 'chang@example.com', DATE '1988-11-05', TIMESTAMPTZ '2022-11-03T00:00:00+08:00', 'guide', '嚮導', 2383, false, 'line', '/assets/images/camp_hero4.png', 'active'),
    ('U004', '黃淑芬', '0945678901', 'huang@example.com', DATE '1995-01-30', TIMESTAMPTZ '2024-06-10T00:00:00+08:00', 'master', '大師', 5596, true, 'google', '/assets/images/camp_hero2.png', 'active'),
    ('U005', '李建明', '0956789012', 'lee@example.com', DATE '1990-09-12', TIMESTAMPTZ '2023-03-28T00:00:00+08:00', 'explorer', '探險家', 998, false, 'facebook', '/assets/images/camp_hero3.png', 'active'),
    ('U006', '陳大華', '0967890123', 'chen@example.com', DATE '1985-04-08', TIMESTAMPTZ '2025-02-14T00:00:00+08:00', 'guide', '嚮導', 2430, false, 'line', '/assets/images/camp_hero4.png', 'active'),
    ('U007', '蔡佳玲', '0978901234', 'tsai@example.com', DATE '2000-12-25', TIMESTAMPTZ '2025-05-01T00:00:00+08:00', 'guide', '嚮導', 1320, true, 'google', '/assets/images/camp_hero2.png', 'active'),
    ('U008', '吳建宏', '0989012345', 'wu@example.com', DATE '1987-06-17', TIMESTAMPTZ '2021-09-22T00:00:00+08:00', 'master', '大師', 3173, false, 'facebook', '/assets/images/camp_hero3.png', 'active'),
    ('U009', '劉雅婷', '0990123456', 'liu@example.com', DATE '1999-02-14', TIMESTAMPTZ '2025-06-18T00:00:00+08:00', 'master', '大師', 3325, false, 'line', '/assets/images/camp_hero4.png', 'active'),
    ('U010', '許志明', '0901234567', 'hsu@example.com', DATE '1978-10-03', TIMESTAMPTZ '2020-12-05T00:00:00+08:00', 'master', '大師', 4510, true, 'google', '/assets/images/camp_hero2.png', 'active'),
    ('U011', '鄭文豪', '0907143781', 'user011@example.com', DATE '1986-12-12', TIMESTAMPTZ '2023-12-12T00:00:00+08:00', 'master', '大師', 4866, false, 'facebook', '/assets/images/camp_hero3.png', 'active'),
    ('U012', '周佩君', '0944156852', 'user012@example.com', DATE '1987-01-13', TIMESTAMPTZ '2024-01-13T00:00:00+08:00', 'master', '大師', 3265, false, 'line', '/assets/images/camp_hero4.png', 'active'),
    ('U013', '楊承翰', '0981169923', 'user013@example.com', DATE '1988-02-14', TIMESTAMPTZ '2025-02-14T00:00:00+08:00', 'master', '大師', 3316, true, 'google', '/assets/images/camp_hero2.png', 'active'),
    ('U014', '謝宜蓁', '0918182994', 'user014@example.com', DATE '1989-03-15', TIMESTAMPTZ '2019-03-15T00:00:00+08:00', 'master', '大師', 4208, false, 'facebook', '/assets/images/camp_hero3.png', 'active'),
    ('U015', '洪偉傑', '0955195065', 'user015@example.com', DATE '1990-04-16', TIMESTAMPTZ '2020-04-16T00:00:00+08:00', 'master', '大師', 5656, false, 'line', '/assets/images/camp_hero4.png', 'active'),
    ('U016', '郭欣怡', '0992208136', 'user016@example.com', DATE '1991-05-17', TIMESTAMPTZ '2021-05-17T00:00:00+08:00', 'guide', '嚮導', 2220, true, 'google', '/assets/images/camp_hero2.png', 'active'),
    ('U017', '邱冠宇', '0929221207', 'user017@example.com', DATE '1992-06-18', TIMESTAMPTZ '2022-06-18T00:00:00+08:00', 'guide', '嚮導', 1896, false, 'facebook', '/assets/images/camp_hero3.png', 'active'),
    ('U018', '曾雅雯', '0966234278', 'user018@example.com', DATE '1993-07-19', TIMESTAMPTZ '2023-07-19T00:00:00+08:00', 'master', '大師', 3075, false, 'line', '/assets/images/camp_hero4.png', 'active'),
    ('U019', '廖俊傑', '0903247349', 'user019@example.com', DATE '1994-08-20', TIMESTAMPTZ '2024-08-20T00:00:00+08:00', 'master', '大師', 2990, true, 'google', '/assets/images/camp_hero2.png', 'active'),
    ('U020', '賴思妤', '0940260420', 'user020@example.com', DATE '1995-09-21', TIMESTAMPTZ '2025-09-21T00:00:00+08:00', 'guide', '嚮導', 1968, false, 'facebook', '/assets/images/camp_hero3.png', 'active'),
    ('U021', '徐柏翰', '0977273491', 'user021@example.com', DATE '1996-10-22', TIMESTAMPTZ '2019-10-22T00:00:00+08:00', 'guide', '嚮導', 1225, false, 'line', '/assets/images/camp_hero4.png', 'active'),
    ('U022', '蘇品妍', '0914286562', 'user022@example.com', DATE '1997-11-23', TIMESTAMPTZ '2020-11-23T00:00:00+08:00', 'master', '大師', 3230, true, 'google', '/assets/images/camp_hero2.png', 'active'),
    ('U023', '葉家豪', '0951299633', 'user023@example.com', DATE '1998-12-24', TIMESTAMPTZ '2021-12-24T00:00:00+08:00', 'master', '大師', 3168, false, 'facebook', '/assets/images/camp_hero3.png', 'active'),
    ('U024', '莊淑惠', '0988312704', 'user024@example.com', DATE '1999-01-25', TIMESTAMPTZ '2022-01-25T00:00:00+08:00', 'master', '大師', 3799, false, 'line', '/assets/images/camp_hero4.png', 'active'),
    ('U025', '江志豪', '0925325775', 'user025@example.com', DATE '1975-02-26', TIMESTAMPTZ '2023-02-26T00:00:00+08:00', 'master', '大師', 3339, true, 'google', '/assets/images/camp_hero2.png', 'active'),
    ('U026', '何佳穎', '0962338846', 'user026@example.com', DATE '1976-03-27', TIMESTAMPTZ '2024-03-27T00:00:00+08:00', 'guide', '嚮導', 2290, false, 'facebook', '/assets/images/camp_hero3.png', 'active'),
    ('U027', '羅俊宏', '0999351917', 'user027@example.com', DATE '1977-04-28', TIMESTAMPTZ '2025-04-28T00:00:00+08:00', 'master', '大師', 3150, false, 'line', '/assets/images/camp_hero4.png', 'active'),
    ('U028', '高詩涵', '0936364988', 'user028@example.com', DATE '1978-05-01', TIMESTAMPTZ '2019-05-01T00:00:00+08:00', 'guide', '嚮導', 2278, true, 'google', '/assets/images/camp_hero2.png', 'active'),
    ('U029', '潘宇軒', '0973377059', 'user029@example.com', DATE '1979-06-02', TIMESTAMPTZ '2020-06-02T00:00:00+08:00', 'guide', '嚮導', 2720, false, 'facebook', '/assets/images/camp_hero3.png', 'active'),
    ('U030', '簡惠如', '0910390130', 'user030@example.com', DATE '1980-07-03', TIMESTAMPTZ '2021-07-03T00:00:00+08:00', 'master', '大師', 3225, false, 'line', '/assets/images/camp_hero4.png', 'active'),
    ('U031', '馬冠廷', '0947403201', 'user031@example.com', DATE '1981-08-04', TIMESTAMPTZ '2022-08-04T00:00:00+08:00', 'master', '大師', 4720, true, 'google', '/assets/images/camp_hero2.png', 'active'),
    ('U032', '鍾怡君', '0984416272', 'user032@example.com', DATE '1982-09-05', TIMESTAMPTZ '2023-09-05T00:00:00+08:00', 'guide', '嚮導', 1988, false, 'facebook', '/assets/images/camp_hero3.png', 'active'),
    ('U033', '游承恩', '0921429343', 'user033@example.com', DATE '1983-10-06', TIMESTAMPTZ '2024-10-06T00:00:00+08:00', 'explorer', '探險家', 1055, false, 'line', '/assets/images/camp_hero4.png', 'active'),
    ('U034', '石雅琪', '0958442414', 'user034@example.com', DATE '1984-11-07', TIMESTAMPTZ '2025-11-07T00:00:00+08:00', 'guide', '嚮導', 2618, true, 'google', '/assets/images/camp_hero2.png', 'active'),
    ('U035', '方建志', '0995455485', 'user035@example.com', DATE '1985-12-08', TIMESTAMPTZ '2019-12-08T00:00:00+08:00', 'master', '大師', 4224, false, 'facebook', '/assets/images/camp_hero3.png', 'active'),
    ('U036', '彭心怡', '0932468556', 'user036@example.com', DATE '1986-01-09', TIMESTAMPTZ '2020-01-09T00:00:00+08:00', 'master', '大師', 5231, false, 'line', '/assets/images/camp_hero4.png', 'active'),
    ('U037', '韓宗翰', '0969481627', 'user037@example.com', DATE '1987-02-10', TIMESTAMPTZ '2021-02-10T00:00:00+08:00', 'master', '大師', 3728, true, 'google', '/assets/images/camp_hero2.png', 'active'),
    ('U038', '唐美玲', '0906494698', 'user038@example.com', DATE '1988-03-11', TIMESTAMPTZ '2022-03-11T00:00:00+08:00', 'guide', '嚮導', 2094, false, 'facebook', '/assets/images/camp_hero3.png', 'active'),
    ('U039', '馮志偉', '0943507769', 'user039@example.com', DATE '1989-04-12', TIMESTAMPTZ '2023-04-12T00:00:00+08:00', 'master', '大師', 5649, false, 'line', '/assets/images/camp_hero4.png', 'active'),
    ('U040', '董佳蓉', '0980520840', 'user040@example.com', DATE '1990-05-13', TIMESTAMPTZ '2024-05-13T00:00:00+08:00', 'master', '大師', 4500, true, 'google', '/assets/images/camp_hero2.png', 'active'),
    ('U041', '程俊賢', '0917533911', 'user041@example.com', DATE '1991-06-14', TIMESTAMPTZ '2025-06-14T00:00:00+08:00', 'guide', '嚮導', 2230, false, 'facebook', '/assets/images/camp_hero3.png', 'active'),
    ('U042', '傅淑芬', '0954546982', 'user042@example.com', DATE '1992-07-15', TIMESTAMPTZ '2019-07-15T00:00:00+08:00', 'master', '大師', 4030, false, 'line', '/assets/images/camp_hero4.png', 'active'),
    ('U043', '范冠霖', '0991559053', 'user043@example.com', DATE '1993-08-16', TIMESTAMPTZ '2020-08-16T00:00:00+08:00', 'guide', '嚮導', 2776, true, 'google', '/assets/images/camp_hero2.png', 'active'),
    ('U044', '戴雅婷', '0928572124', 'user044@example.com', DATE '1994-09-17', TIMESTAMPTZ '2021-09-17T00:00:00+08:00', 'master', '大師', 6171, false, 'facebook', '/assets/images/camp_hero3.png', 'active'),
    ('U045', '段家銘', '0965585195', 'user045@example.com', DATE '1995-10-18', TIMESTAMPTZ '2022-10-18T00:00:00+08:00', 'master', '大師', 3385, false, 'line', '/assets/images/camp_hero4.png', 'active'),
    ('U046', '曹佩珊', '0902598266', 'user046@example.com', DATE '1996-11-19', TIMESTAMPTZ '2023-11-19T00:00:00+08:00', 'guide', '嚮導', 1910, true, 'google', '/assets/images/camp_hero2.png', 'active'),
    ('U047', '袁宇翔', '0939611337', 'user047@example.com', DATE '1997-12-20', TIMESTAMPTZ '2024-12-20T00:00:00+08:00', 'master', '大師', 3784, false, 'facebook', '/assets/images/camp_hero3.png', 'active'),
    ('U048', '鄧欣妤', '0976624408', 'user048@example.com', DATE '1998-01-21', TIMESTAMPTZ '2025-01-21T00:00:00+08:00', 'guide', '嚮導', 2769, false, 'line', '/assets/images/camp_hero4.png', 'active'),
    ('U049', '許柏均', '0913637479', 'user049@example.com', DATE '1999-02-22', TIMESTAMPTZ '2019-02-22T00:00:00+08:00', 'master', '大師', 4060, true, 'google', '/assets/images/camp_hero2.png', 'active'),
    ('U050', '丁惠珍', '0950650550', 'user050@example.com', DATE '1975-03-23', TIMESTAMPTZ '2020-03-23T00:00:00+08:00', 'master', '大師', 5420, false, 'facebook', '/assets/images/camp_hero3.png', 'active')
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    phone = EXCLUDED.phone,
    email = EXCLUDED.email,
    birthday = EXCLUDED.birthday,
    registered_at = EXCLUDED.registered_at,
    tier = EXCLUDED.tier,
    tier_name = EXCLUDED.tier_name,
    points = EXCLUDED.points,
    first_purchase_used = EXCLUDED.first_purchase_used,
    auth_provider = EXCLUDED.auth_provider,
    avatar_url = EXCLUDED.avatar_url,
    status = EXCLUDED.status;

-- 會員周邊展示資料：偏好選項、個人偏好、預設配送地址與後台會員標籤。
-- 這些資料不參與訂單／預訂成立條件，但由 Admin Customers 詳情與前端會員資料使用。
INSERT INTO public.preference_options (id, type, code, label, sort_order, active)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 'style', 'glamping', 'Glamping', 1, true),
    (2, 'style', 'backpacking', '背包旅行', 2, true),
    (3, 'style', 'family', '家庭露營', 3, true),
    (4, 'style', 'solo', '獨旅', 4, true),
    (5, 'style', 'hiking', '登山健行', 5, true),
    (6, 'style', 'car-camping', '車宿', 6, true),
    (7, 'style', 'ultralight', '輕量化', 7, true),
    (8, 'style', 'base-camp', '基地營', 8, true),
    (9, 'equipment', 'tent', '帳篷', 1, true),
    (10, 'equipment', 'sleeping-bag', '睡袋', 2, true),
    (11, 'equipment', 'backpack', '背包', 3, true),
    (12, 'equipment', 'cooking', '炊具', 4, true),
    (13, 'equipment', 'lighting', '照明', 5, true),
    (14, 'equipment', 'chair', '椅凳', 6, true),
    (15, 'equipment', 'navigation', '導航', 7, true),
    (16, 'equipment', 'safety', '安全用品', 8, true),
    (17, 'equipment', 'photography', '攝影', 9, true),
    (18, 'equipment', 'clothing', '服飾', 10, true)
ON CONFLICT (id) DO UPDATE SET
    type = EXCLUDED.type,
    code = EXCLUDED.code,
    label = EXCLUDED.label,
    sort_order = EXCLUDED.sort_order,
    active = EXCLUDED.active,
    updated_at = now();

SELECT setval(
    'public.preference_options_id_seq',
    GREATEST((SELECT max(id) FROM public.preference_options), 1),
    true
);

-- U001 保留前端展示用特例；U002～U050 依固定週期產生兩種風格與兩種裝備偏好。
DELETE FROM public.customer_preferences
WHERE customer_id IN (SELECT 'U' || to_char(number, 'FM000') FROM generate_series(1, 50) AS number);

INSERT INTO public.customer_preferences (customer_id, preference_id)
VALUES
    ('U001', 2),
    ('U001', 5),
    ('U001', 9),
    ('U001', 11);

INSERT INTO public.customer_preferences (customer_id, preference_id)
SELECT 'U' || to_char(number, 'FM000'), preference_id
FROM generate_series(2, 50) AS number
CROSS JOIN LATERAL (
    VALUES
        (1 + ((number - 1) % 8)),
        (1 + ((number + 2) % 8)),
        (9 + ((number - 1) % 5)),
        (14 + ((number - 2) % 5))
) AS generated(preference_id);

-- 每位展示會員固定一筆預設地址；JSON 的 email 由 customers.email 提供，不重複存入地址表。
UPDATE public.customer_shipping_addresses
SET is_default = false,
    updated_at = now()
WHERE customer_id IN (SELECT 'U' || to_char(number, 'FM000') FROM generate_series(1, 50) AS number)
  AND is_default = true;

INSERT INTO public.customer_shipping_addresses (
    id, customer_id, recipient_name, postal_code, city, district, address_line, phone, is_default
)
OVERRIDING SYSTEM VALUE
VALUES
    (1, 'U001', '王小明', '701', '臺南市', '東區', '長榮路二段200號', '0912345678', true),
    (2, 'U002', '林美惠', '600', '嘉義市', '西區', '垂楊路200號', '0923456789', true),
    (3, 'U003', '張志偉', '320', '桃園市', '中壢區', '中山路300號', '0934567890', true),
    (4, 'U004', '黃淑芬', '407', '臺中市', '西屯區', '台灣大道三段500號', '0945678901', true),
    (5, 'U005', '李建明', '950', '臺東縣', '臺東市', '中山路120號', '0956789012', true),
    (6, 'U006', '陳大華', '220', '新北市', '板橋區', '文化路二段100號', '0967890123', true),
    (7, 'U007', '蔡佳玲', '220', '新北市', '板橋區', '文化路二段100號', '0978901234', true),
    (8, 'U008', '吳建宏', '260', '宜蘭縣', '宜蘭市', '中山路二段80號', '0989012345', true),
    (9, 'U009', '劉雅婷', '220', '新北市', '板橋區', '文化路二段100號', '0990123456', true),
    (10, 'U010', '許志明', '110', '臺北市', '信義區', '松仁路100號', '0901234567', true),
    (11, 'U011', '鄭文豪', '260', '宜蘭縣', '宜蘭市', '中山路二段80號', '0907143781', true),
    (12, 'U012', '周佩君', '500', '彰化縣', '彰化市', '中山路一段66號', '0944156852', true),
    (13, 'U013', '楊承翰', '701', '臺南市', '東區', '長榮路二段200號', '0981169923', true),
    (14, 'U014', '謝宜蓁', '950', '臺東縣', '臺東市', '中山路120號', '0918182994', true),
    (15, 'U015', '洪偉傑', '220', '新北市', '板橋區', '文化路二段100號', '0955195065', true),
    (16, 'U016', '郭欣怡', '600', '嘉義市', '西區', '垂楊路200號', '0992208136', true),
    (17, 'U017', '邱冠宇', '110', '臺北市', '信義區', '松仁路100號', '0929221207', true),
    (18, 'U018', '曾雅雯', '500', '彰化縣', '彰化市', '中山路一段66號', '0966234278', true),
    (19, 'U019', '廖俊傑', '600', '嘉義市', '西區', '垂楊路200號', '0903247349', true),
    (20, 'U020', '賴思妤', '220', '新北市', '板橋區', '文化路二段100號', '0940260420', true),
    (21, 'U021', '徐柏翰', '600', '嘉義市', '西區', '垂楊路200號', '0977273491', true),
    (22, 'U022', '蘇品妍', '260', '宜蘭縣', '宜蘭市', '中山路二段80號', '0914286562', true),
    (23, 'U023', '葉家豪', '600', '嘉義市', '西區', '垂楊路200號', '0951299633', true),
    (24, 'U024', '莊淑惠', '600', '嘉義市', '西區', '垂楊路200號', '0988312704', true),
    (25, 'U025', '江志豪', '300', '新竹市', '東區', '光復路一段100號', '0925325775', true),
    (26, 'U026', '何佳穎', '260', '宜蘭縣', '宜蘭市', '中山路二段80號', '0962338846', true),
    (27, 'U027', '羅俊宏', '200', '基隆市', '仁愛區', '愛一路50號', '0999351917', true),
    (28, 'U028', '高詩涵', '813', '高雄市', '左營區', '高鐵路100號', '0936364988', true),
    (29, 'U029', '潘宇軒', '300', '新竹市', '東區', '光復路一段100號', '0973377059', true),
    (30, 'U030', '簡惠如', '220', '新北市', '板橋區', '文化路二段100號', '0910390130', true),
    (31, 'U031', '馬冠廷', '970', '花蓮縣', '花蓮市', '國聯一路20號', '0947403201', true),
    (32, 'U032', '鍾怡君', '600', '嘉義市', '西區', '垂楊路200號', '0984416272', true),
    (33, 'U033', '游承恩', '950', '臺東縣', '臺東市', '中山路120號', '0921429343', true),
    (34, 'U034', '石雅琪', '950', '臺東縣', '臺東市', '中山路120號', '0958442414', true),
    (35, 'U035', '方建志', '110', '臺北市', '信義區', '松仁路100號', '0995455485', true),
    (36, 'U036', '彭心怡', '900', '屏東縣', '屏東市', '民生路88號', '0932468556', true),
    (37, 'U037', '韓宗翰', '701', '臺南市', '東區', '長榮路二段200號', '0969481627', true),
    (38, 'U038', '唐美玲', '110', '臺北市', '信義區', '松仁路100號', '0906494698', true),
    (39, 'U039', '馮志偉', '200', '基隆市', '仁愛區', '愛一路50號', '0943507769', true),
    (40, 'U040', '董佳蓉', '300', '新竹市', '東區', '光復路一段100號', '0980520840', true),
    (41, 'U041', '程俊賢', '407', '臺中市', '西屯區', '台灣大道三段500號', '0917533911', true),
    (42, 'U042', '傅淑芬', '320', '桃園市', '中壢區', '中山路300號', '0954546982', true),
    (43, 'U043', '范冠霖', '110', '臺北市', '信義區', '松仁路100號', '0991559053', true),
    (44, 'U044', '戴雅婷', '260', '宜蘭縣', '宜蘭市', '中山路二段80號', '0928572124', true),
    (45, 'U045', '段家銘', '600', '嘉義市', '西區', '垂楊路200號', '0965585195', true),
    (46, 'U046', '曹佩珊', '300', '新竹市', '東區', '光復路一段100號', '0902598266', true),
    (47, 'U047', '袁宇翔', '500', '彰化縣', '彰化市', '中山路一段66號', '0939611337', true),
    (48, 'U048', '鄧欣妤', '220', '新北市', '板橋區', '文化路二段100號', '0976624408', true),
    (49, 'U049', '許柏均', '970', '花蓮縣', '花蓮市', '國聯一路20號', '0913637479', true),
    (50, 'U050', '丁惠珍', '970', '花蓮縣', '花蓮市', '國聯一路20號', '0950650550', true)
ON CONFLICT (id) DO UPDATE SET
    customer_id = EXCLUDED.customer_id,
    recipient_name = EXCLUDED.recipient_name,
    postal_code = EXCLUDED.postal_code,
    city = EXCLUDED.city,
    district = EXCLUDED.district,
    address_line = EXCLUDED.address_line,
    phone = EXCLUDED.phone,
    is_default = EXCLUDED.is_default,
    updated_at = now();

SELECT setval(
    'public.customer_shipping_addresses_id_seq',
    GREATEST((SELECT max(id) FROM public.customer_shipping_addresses), 1),
    true
);

INSERT INTO public.customer_tags (id, name, color, sort_order, active)
OVERRIDING SYSTEM VALUE
VALUES
    (1, '高消費', 'bg-success', 1, true),
    (2, '高退貨率', 'bg-danger', 2, true),
    (3, '新會員', 'bg-info text-dark', 3, true)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    color = EXCLUDED.color,
    sort_order = EXCLUDED.sort_order,
    active = EXCLUDED.active,
    updated_at = now();

SELECT setval(
    'public.customer_tags_id_seq',
    GREATEST((SELECT max(id) FROM public.customer_tags), 1),
    true
);

DELETE FROM public.customer_tag_assignments
WHERE customer_id IN (SELECT 'U' || to_char(number, 'FM000') FROM generate_series(1, 50) AS number);

INSERT INTO public.customer_tag_assignments (customer_id, tag_id)
VALUES
    ('U001', 1),
    ('U002', 1),
    ('U003', 1),
    ('U004', 1),
    ('U006', 1),
    ('U007', 2),
    ('U008', 1),
    ('U009', 1),
    ('U010', 1),
    ('U010', 2),
    ('U011', 1),
    ('U012', 1),
    ('U013', 1),
    ('U014', 1),
    ('U014', 2),
    ('U015', 1),
    ('U016', 1),
    ('U017', 1),
    ('U018', 1),
    ('U019', 1),
    ('U020', 3),
    ('U020', 1),
    ('U022', 1),
    ('U023', 1),
    ('U024', 1),
    ('U025', 1),
    ('U026', 1),
    ('U027', 1),
    ('U028', 1),
    ('U029', 1),
    ('U030', 1),
    ('U031', 1),
    ('U032', 1),
    ('U034', 3),
    ('U034', 1),
    ('U035', 1),
    ('U036', 1),
    ('U037', 1),
    ('U038', 1),
    ('U038', 2),
    ('U039', 1),
    ('U040', 1),
    ('U041', 1),
    ('U042', 1),
    ('U043', 1),
    ('U044', 1),
    ('U045', 1),
    ('U046', 1),
    ('U046', 2),
    ('U047', 1),
    ('U047', 2),
    ('U048', 1),
    ('U048', 2),
    ('U049', 1),
    ('U049', 2),
    ('U050', 1);

-- frontend customers end
