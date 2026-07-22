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

-- frontend customers end
