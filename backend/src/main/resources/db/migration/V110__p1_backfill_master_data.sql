-- P1 backfill generated from the frozen JSON fixture set on 2026-07-14.
-- Applied migrations are immutable: future fixture changes require a new migration.

-- Seed authoritative P1 masters while preserving pre-existing database rows.

INSERT INTO customers (
  id, avatar, name, phone, email, birthday, registered_at, total_spent, tier, tier_name,
  points, first_purchase_used, preferences, shipping_address, tags, auth_provider, avatar_url, active
) VALUES
  ('U001', '/assets/images/avatar-01.jpg', 'Amy Chen', '0912345678', 'amy@example.com', '1992-03-18', '2025-01-15', 18391, 'guide', '嚮導', 4240, FALSE, '{"styles":["backpacking","hiking"],"equipment":["tent","backpack"]}'::jsonb, '{"lastName":"王","firstName":"小明","postalCode":"701","city":"臺南市","district":"東區","township":"","addressLine1":"長榮路二段200號","addressLine2":"","email":"amy@example.com","phone":"0912345678"}'::jsonb, '["高消費"]'::jsonb, 'google', '/assets/images/avatar-01.jpg', TRUE),
  ('U002', '/assets/images/avatar-02.jpg', '林美惠', '0923456789', 'lin@example.com', '1998-07-22', '2025-01-20', 24850, 'guide', '嚮導', 2485, FALSE, '{"styles":["backpacking","hiking"],"equipment":["sleeping-bag","chair"]}'::jsonb, '{"lastName":"林","firstName":"美惠","postalCode":"600","city":"嘉義市","district":"西區","township":"","addressLine1":"垂楊路200號","addressLine2":"","email":"lin@example.com","phone":"0923456789"}'::jsonb, '["高消費"]'::jsonb, 'facebook', '/assets/images/avatar-02.jpg', TRUE),
  ('U003', '/assets/images/avatar-03.jpg', '張志偉', '0934567890', 'chang@example.com', '1988-11-05', '2022-11-03', 23830, 'guide', '嚮導', 2383, FALSE, '{"styles":["family","car-camping"],"equipment":["backpack","navigation"]}'::jsonb, '{"lastName":"張","firstName":"志偉","postalCode":"320","city":"桃園市","district":"中壢區","township":"","addressLine1":"中山路300號","addressLine2":"","email":"chang@example.com","phone":"0934567890"}'::jsonb, '["高消費"]'::jsonb, 'line', '/assets/images/avatar-03.jpg', TRUE),
  ('U004', '/assets/images/avatar-01.jpg', '黃淑芬', '0945678901', 'huang@example.com', '1995-01-30', '2024-06-10', 55960, 'master', '大師', 5596, TRUE, '{"styles":["solo","ultralight"],"equipment":["cooking","safety"]}'::jsonb, '{"lastName":"黃","firstName":"淑芬","postalCode":"407","city":"臺中市","district":"西屯區","township":"","addressLine1":"台灣大道三段500號","addressLine2":"","email":"huang@example.com","phone":"0945678901"}'::jsonb, '["高消費"]'::jsonb, 'google', '/assets/images/avatar-01.jpg', TRUE),
  ('U005', '/assets/images/avatar-02.jpg', '李建明', '0956789012', 'lee@example.com', '1990-09-12', '2023-03-28', 9980, 'explorer', '探險家', 998, FALSE, '{"styles":["hiking","base-camp"],"equipment":["lighting","photography"]}'::jsonb, '{"lastName":"李","firstName":"建明","postalCode":"950","city":"臺東市","district":"","township":"","addressLine1":"中山路120號","addressLine2":"","email":"lee@example.com","phone":"0956789012"}'::jsonb, '[]'::jsonb, 'facebook', '/assets/images/avatar-02.jpg', TRUE),
  ('U006', '/assets/images/avatar-03.jpg', '陳大華', '0967890123', 'chen@example.com', '1985-04-08', '2025-02-14', 24300, 'guide', '嚮導', 2430, FALSE, '{"styles":["car-camping","glamping"],"equipment":["clothing","tent"]}'::jsonb, '{"lastName":"陳","firstName":"大華","postalCode":"220","city":"新北市","district":"板橋區","township":"","addressLine1":"文化路二段100號","addressLine2":"","email":"chen@example.com","phone":"0967890123"}'::jsonb, '["高消費"]'::jsonb, 'line', '/assets/images/avatar-03.jpg', TRUE),
  ('U007', '/assets/images/avatar-01.jpg', '蔡佳玲', '0978901234', 'tsai@example.com', '2000-12-25', '2025-05-01', 13200, 'guide', '嚮導', 1320, TRUE, '{"styles":["ultralight","backpacking"],"equipment":["chair","sleeping-bag"]}'::jsonb, '{"lastName":"蔡","firstName":"佳玲","postalCode":"220","city":"新北市","district":"板橋區","township":"","addressLine1":"文化路二段100號","addressLine2":"","email":"tsai@example.com","phone":"0978901234"}'::jsonb, '["高退貨率"]'::jsonb, 'google', '/assets/images/avatar-01.jpg', TRUE),
  ('U008', '/assets/images/avatar-02.jpg', '吳建宏', '0989012345', 'wu@example.com', '1987-06-17', '2021-09-22', 31730, 'master', '大師', 3173, FALSE, '{"styles":["base-camp","family"],"equipment":["navigation","backpack"]}'::jsonb, '{"lastName":"吳","firstName":"建宏","postalCode":"260","city":"宜蘭市","district":"","township":"","addressLine1":"中山路二段80號","addressLine2":"","email":"wu@example.com","phone":"0989012345"}'::jsonb, '["高消費"]'::jsonb, 'facebook', '/assets/images/avatar-02.jpg', TRUE),
  ('U009', '/assets/images/avatar-03.jpg', '劉雅婷', '0990123456', 'liu@example.com', '1999-02-14', '2025-06-18', 33250, 'master', '大師', 3325, FALSE, '{"styles":["glamping","solo"],"equipment":["safety","cooking"]}'::jsonb, '{"lastName":"劉","firstName":"雅婷","postalCode":"220","city":"新北市","district":"板橋區","township":"","addressLine1":"文化路二段100號","addressLine2":"","email":"liu@example.com","phone":"0990123456"}'::jsonb, '["高消費"]'::jsonb, 'line', '/assets/images/avatar-03.jpg', TRUE),
  ('U010', '/assets/images/avatar-01.jpg', '許志明', '0901234567', 'hsu@example.com', '1978-10-03', '2020-12-05', 45100, 'master', '大師', 4510, TRUE, '{"styles":["backpacking","hiking"],"equipment":["photography","lighting"]}'::jsonb, '{"lastName":"許","firstName":"志明","postalCode":"110","city":"臺北市","district":"信義區","township":"","addressLine1":"松仁路100號","addressLine2":"","email":"hsu@example.com","phone":"0901234567"}'::jsonb, '["高消費","高退貨率"]'::jsonb, 'google', '/assets/images/avatar-01.jpg', TRUE),
  ('U011', '/assets/images/avatar-03.jpg', '鄭文豪', '0907143781', 'user011@example.com', '1986-12-12', '2023-12-12', 48660, 'master', '大師', 4866, FALSE, '{"styles":["family","car-camping"],"equipment":["tent","clothing"]}'::jsonb, '{"lastName":"鄭","firstName":"文豪","postalCode":"260","city":"宜蘭市","district":"","township":"","addressLine1":"中山路二段80號","addressLine2":"","email":"user011@example.com","phone":"0907143781"}'::jsonb, '["高消費"]'::jsonb, 'facebook', '/assets/images/avatar-03.jpg', TRUE),
  ('U012', '/assets/images/avatar-01.jpg', '周佩君', '0944156852', 'user012@example.com', '1987-01-13', '2024-01-13', 32650, 'master', '大師', 3265, FALSE, '{"styles":["solo","ultralight"],"equipment":["sleeping-bag","chair"]}'::jsonb, '{"lastName":"周","firstName":"佩君","postalCode":"500","city":"彰化市","district":"","township":"","addressLine1":"中山路一段66號","addressLine2":"","email":"user012@example.com","phone":"0944156852"}'::jsonb, '["高消費"]'::jsonb, 'line', '/assets/images/avatar-01.jpg', TRUE),
  ('U013', '/assets/images/avatar-02.jpg', '楊承翰', '0981169923', 'user013@example.com', '1988-02-14', '2025-02-14', 33160, 'master', '大師', 3316, TRUE, '{"styles":["hiking","base-camp"],"equipment":["backpack","navigation"]}'::jsonb, '{"lastName":"楊","firstName":"承翰","postalCode":"701","city":"臺南市","district":"東區","township":"","addressLine1":"長榮路二段200號","addressLine2":"","email":"user013@example.com","phone":"0981169923"}'::jsonb, '["高消費"]'::jsonb, 'google', '/assets/images/avatar-02.jpg', TRUE),
  ('U014', '/assets/images/avatar-03.jpg', '謝宜蓁', '0918182994', 'user014@example.com', '1989-03-15', '2019-03-15', 42080, 'master', '大師', 4208, FALSE, '{"styles":["car-camping","glamping"],"equipment":["cooking","safety"]}'::jsonb, '{"lastName":"謝","firstName":"宜蓁","postalCode":"950","city":"臺東市","district":"","township":"","addressLine1":"中山路120號","addressLine2":"","email":"user014@example.com","phone":"0918182994"}'::jsonb, '["高消費","高退貨率"]'::jsonb, 'facebook', '/assets/images/avatar-03.jpg', TRUE),
  ('U015', '/assets/images/avatar-01.jpg', '洪偉傑', '0955195065', 'user015@example.com', '1990-04-16', '2020-04-16', 56560, 'master', '大師', 5656, FALSE, '{"styles":["ultralight","backpacking"],"equipment":["lighting","photography"]}'::jsonb, '{"lastName":"洪","firstName":"偉傑","postalCode":"220","city":"新北市","district":"板橋區","township":"","addressLine1":"文化路二段100號","addressLine2":"","email":"user015@example.com","phone":"0955195065"}'::jsonb, '["高消費"]'::jsonb, 'line', '/assets/images/avatar-01.jpg', TRUE),
  ('U016', '/assets/images/avatar-02.jpg', '郭欣怡', '0992208136', 'user016@example.com', '1991-05-17', '2021-05-17', 22200, 'guide', '嚮導', 2220, TRUE, '{"styles":["base-camp","family"],"equipment":["clothing","tent"]}'::jsonb, '{"lastName":"郭","firstName":"欣怡","postalCode":"600","city":"嘉義市","district":"西區","township":"","addressLine1":"垂楊路200號","addressLine2":"","email":"user016@example.com","phone":"0992208136"}'::jsonb, '["高消費"]'::jsonb, 'google', '/assets/images/avatar-02.jpg', TRUE),
  ('U017', '/assets/images/avatar-03.jpg', '邱冠宇', '0929221207', 'user017@example.com', '1992-06-18', '2022-06-18', 18960, 'guide', '嚮導', 1896, FALSE, '{"styles":["glamping","solo"],"equipment":["chair","sleeping-bag"]}'::jsonb, '{"lastName":"邱","firstName":"冠宇","postalCode":"110","city":"臺北市","district":"信義區","township":"","addressLine1":"松仁路100號","addressLine2":"","email":"user017@example.com","phone":"0929221207"}'::jsonb, '["高消費"]'::jsonb, 'facebook', '/assets/images/avatar-03.jpg', TRUE),
  ('U018', '/assets/images/avatar-01.jpg', '曾雅雯', '0966234278', 'user018@example.com', '1993-07-19', '2023-07-19', 30750, 'master', '大師', 3075, FALSE, '{"styles":["backpacking","hiking"],"equipment":["navigation","backpack"]}'::jsonb, '{"lastName":"曾","firstName":"雅雯","postalCode":"500","city":"彰化市","district":"","township":"","addressLine1":"中山路一段66號","addressLine2":"","email":"user018@example.com","phone":"0966234278"}'::jsonb, '["高消費"]'::jsonb, 'line', '/assets/images/avatar-01.jpg', TRUE),
  ('U019', '/assets/images/avatar-02.jpg', '廖俊傑', '0903247349', 'user019@example.com', '1994-08-20', '2024-08-20', 29900, 'master', '大師', 2990, TRUE, '{"styles":["family","car-camping"],"equipment":["safety","cooking"]}'::jsonb, '{"lastName":"廖","firstName":"俊傑","postalCode":"600","city":"嘉義市","district":"西區","township":"","addressLine1":"垂楊路200號","addressLine2":"","email":"user019@example.com","phone":"0903247349"}'::jsonb, '["高消費"]'::jsonb, 'google', '/assets/images/avatar-02.jpg', TRUE),
  ('U020', '/assets/images/avatar-03.jpg', '賴思妤', '0940260420', 'user020@example.com', '1995-09-21', '2025-09-21', 19680, 'guide', '嚮導', 1968, FALSE, '{"styles":["solo","ultralight"],"equipment":["photography","lighting"]}'::jsonb, '{"lastName":"賴","firstName":"思妤","postalCode":"220","city":"新北市","district":"板橋區","township":"","addressLine1":"文化路二段100號","addressLine2":"","email":"user020@example.com","phone":"0940260420"}'::jsonb, '["新會員","高消費"]'::jsonb, 'facebook', '/assets/images/avatar-03.jpg', TRUE),
  ('U021', '/assets/images/avatar-01.jpg', '徐柏翰', '0977273491', 'user021@example.com', '1996-10-22', '2019-10-22', 12250, 'guide', '嚮導', 1225, FALSE, '{"styles":["hiking","base-camp"],"equipment":["tent","clothing"]}'::jsonb, '{"lastName":"徐","firstName":"柏翰","postalCode":"600","city":"嘉義市","district":"西區","township":"","addressLine1":"垂楊路200號","addressLine2":"","email":"user021@example.com","phone":"0977273491"}'::jsonb, '[]'::jsonb, 'line', '/assets/images/avatar-01.jpg', TRUE),
  ('U022', '/assets/images/avatar-02.jpg', '蘇品妍', '0914286562', 'user022@example.com', '1997-11-23', '2020-11-23', 32300, 'master', '大師', 3230, TRUE, '{"styles":["car-camping","glamping"],"equipment":["sleeping-bag","chair"]}'::jsonb, '{"lastName":"蘇","firstName":"品妍","postalCode":"260","city":"宜蘭市","district":"","township":"","addressLine1":"中山路二段80號","addressLine2":"","email":"user022@example.com","phone":"0914286562"}'::jsonb, '["高消費"]'::jsonb, 'google', '/assets/images/avatar-02.jpg', TRUE),
  ('U023', '/assets/images/avatar-03.jpg', '葉家豪', '0951299633', 'user023@example.com', '1998-12-24', '2021-12-24', 31680, 'master', '大師', 3168, FALSE, '{"styles":["ultralight","backpacking"],"equipment":["backpack","navigation"]}'::jsonb, '{"lastName":"葉","firstName":"家豪","postalCode":"600","city":"嘉義市","district":"西區","township":"","addressLine1":"垂楊路200號","addressLine2":"","email":"user023@example.com","phone":"0951299633"}'::jsonb, '["高消費"]'::jsonb, 'facebook', '/assets/images/avatar-03.jpg', TRUE),
  ('U024', '/assets/images/avatar-01.jpg', '莊淑惠', '0988312704', 'user024@example.com', '1999-01-25', '2022-01-25', 37990, 'master', '大師', 3799, FALSE, '{"styles":["base-camp","family"],"equipment":["cooking","safety"]}'::jsonb, '{"lastName":"莊","firstName":"淑惠","postalCode":"600","city":"嘉義市","district":"西區","township":"","addressLine1":"垂楊路200號","addressLine2":"","email":"user024@example.com","phone":"0988312704"}'::jsonb, '["高消費"]'::jsonb, 'line', '/assets/images/avatar-01.jpg', TRUE),
  ('U025', '/assets/images/avatar-02.jpg', '江志豪', '0925325775', 'user025@example.com', '1975-02-26', '2023-02-26', 33390, 'master', '大師', 3339, TRUE, '{"styles":["glamping","solo"],"equipment":["lighting","photography"]}'::jsonb, '{"lastName":"江","firstName":"志豪","postalCode":"300","city":"新竹市","district":"東區","township":"","addressLine1":"光復路一段100號","addressLine2":"","email":"user025@example.com","phone":"0925325775"}'::jsonb, '["高消費"]'::jsonb, 'google', '/assets/images/avatar-02.jpg', TRUE),
  ('U026', '/assets/images/avatar-03.jpg', '何佳穎', '0962338846', 'user026@example.com', '1976-03-27', '2024-03-27', 22900, 'guide', '嚮導', 2290, FALSE, '{"styles":["backpacking","hiking"],"equipment":["clothing","tent"]}'::jsonb, '{"lastName":"何","firstName":"佳穎","postalCode":"260","city":"宜蘭市","district":"","township":"","addressLine1":"中山路二段80號","addressLine2":"","email":"user026@example.com","phone":"0962338846"}'::jsonb, '["高消費"]'::jsonb, 'facebook', '/assets/images/avatar-03.jpg', TRUE),
  ('U027', '/assets/images/avatar-01.jpg', '羅俊宏', '0999351917', 'user027@example.com', '1977-04-28', '2025-04-28', 31500, 'master', '大師', 3150, FALSE, '{"styles":["family","car-camping"],"equipment":["chair","sleeping-bag"]}'::jsonb, '{"lastName":"羅","firstName":"俊宏","postalCode":"200","city":"基隆市","district":"仁愛區","township":"","addressLine1":"愛一路50號","addressLine2":"","email":"user027@example.com","phone":"0999351917"}'::jsonb, '["高消費"]'::jsonb, 'line', '/assets/images/avatar-01.jpg', TRUE),
  ('U028', '/assets/images/avatar-02.jpg', '高詩涵', '0936364988', 'user028@example.com', '1978-05-01', '2019-05-01', 22780, 'guide', '嚮導', 2278, TRUE, '{"styles":["solo","ultralight"],"equipment":["navigation","backpack"]}'::jsonb, '{"lastName":"高","firstName":"詩涵","postalCode":"813","city":"高雄市","district":"左營區","township":"","addressLine1":"高鐵路100號","addressLine2":"","email":"user028@example.com","phone":"0936364988"}'::jsonb, '["高消費"]'::jsonb, 'google', '/assets/images/avatar-02.jpg', TRUE),
  ('U029', '/assets/images/avatar-03.jpg', '潘宇軒', '0973377059', 'user029@example.com', '1979-06-02', '2020-06-02', 27200, 'guide', '嚮導', 2720, FALSE, '{"styles":["hiking","base-camp"],"equipment":["safety","cooking"]}'::jsonb, '{"lastName":"潘","firstName":"宇軒","postalCode":"300","city":"新竹市","district":"東區","township":"","addressLine1":"光復路一段100號","addressLine2":"","email":"user029@example.com","phone":"0973377059"}'::jsonb, '["高消費"]'::jsonb, 'facebook', '/assets/images/avatar-03.jpg', TRUE),
  ('U030', '/assets/images/avatar-01.jpg', '簡惠如', '0910390130', 'user030@example.com', '1980-07-03', '2021-07-03', 32250, 'master', '大師', 3225, FALSE, '{"styles":["car-camping","glamping"],"equipment":["photography","lighting"]}'::jsonb, '{"lastName":"簡","firstName":"惠如","postalCode":"220","city":"新北市","district":"板橋區","township":"","addressLine1":"文化路二段100號","addressLine2":"","email":"user030@example.com","phone":"0910390130"}'::jsonb, '["高消費"]'::jsonb, 'line', '/assets/images/avatar-01.jpg', TRUE),
  ('U031', '/assets/images/avatar-02.jpg', '馬冠廷', '0947403201', 'user031@example.com', '1981-08-04', '2022-08-04', 47200, 'master', '大師', 4720, TRUE, '{"styles":["ultralight","backpacking"],"equipment":["tent","clothing"]}'::jsonb, '{"lastName":"馬","firstName":"冠廷","postalCode":"970","city":"花蓮市","district":"","township":"","addressLine1":"國聯一路20號","addressLine2":"","email":"user031@example.com","phone":"0947403201"}'::jsonb, '["高消費"]'::jsonb, 'google', '/assets/images/avatar-02.jpg', TRUE),
  ('U032', '/assets/images/avatar-03.jpg', '鍾怡君', '0984416272', 'user032@example.com', '1982-09-05', '2023-09-05', 19880, 'guide', '嚮導', 1988, FALSE, '{"styles":["base-camp","family"],"equipment":["sleeping-bag","chair"]}'::jsonb, '{"lastName":"鍾","firstName":"怡君","postalCode":"600","city":"嘉義市","district":"西區","township":"","addressLine1":"垂楊路200號","addressLine2":"","email":"user032@example.com","phone":"0984416272"}'::jsonb, '["高消費"]'::jsonb, 'facebook', '/assets/images/avatar-03.jpg', TRUE),
  ('U033', '/assets/images/avatar-01.jpg', '游承恩', '0921429343', 'user033@example.com', '1983-10-06', '2024-10-06', 10550, 'explorer', '探險家', 1055, FALSE, '{"styles":["glamping","solo"],"equipment":["backpack","navigation"]}'::jsonb, '{"lastName":"游","firstName":"承恩","postalCode":"950","city":"臺東市","district":"","township":"","addressLine1":"中山路120號","addressLine2":"","email":"user033@example.com","phone":"0921429343"}'::jsonb, '[]'::jsonb, 'line', '/assets/images/avatar-01.jpg', TRUE),
  ('U034', '/assets/images/avatar-02.jpg', '石雅琪', '0958442414', 'user034@example.com', '1984-11-07', '2025-11-07', 26180, 'guide', '嚮導', 2618, TRUE, '{"styles":["backpacking","hiking"],"equipment":["cooking","safety"]}'::jsonb, '{"lastName":"石","firstName":"雅琪","postalCode":"950","city":"臺東市","district":"","township":"","addressLine1":"中山路120號","addressLine2":"","email":"user034@example.com","phone":"0958442414"}'::jsonb, '["新會員","高消費"]'::jsonb, 'google', '/assets/images/avatar-02.jpg', TRUE),
  ('U035', '/assets/images/avatar-03.jpg', '方建志', '0995455485', 'user035@example.com', '1985-12-08', '2019-12-08', 42240, 'master', '大師', 4224, FALSE, '{"styles":["family","car-camping"],"equipment":["lighting","photography"]}'::jsonb, '{"lastName":"方","firstName":"建志","postalCode":"110","city":"臺北市","district":"信義區","township":"","addressLine1":"松仁路100號","addressLine2":"","email":"user035@example.com","phone":"0995455485"}'::jsonb, '["高消費"]'::jsonb, 'facebook', '/assets/images/avatar-03.jpg', TRUE),
  ('U036', '/assets/images/avatar-01.jpg', '彭心怡', '0932468556', 'user036@example.com', '1986-01-09', '2020-01-09', 52310, 'master', '大師', 5231, FALSE, '{"styles":["solo","ultralight"],"equipment":["clothing","tent"]}'::jsonb, '{"lastName":"彭","firstName":"心怡","postalCode":"900","city":"屏東市","district":"","township":"","addressLine1":"民生路88號","addressLine2":"","email":"user036@example.com","phone":"0932468556"}'::jsonb, '["高消費"]'::jsonb, 'line', '/assets/images/avatar-01.jpg', TRUE),
  ('U037', '/assets/images/avatar-02.jpg', '韓宗翰', '0969481627', 'user037@example.com', '1987-02-10', '2021-02-10', 37280, 'master', '大師', 3728, TRUE, '{"styles":["hiking","base-camp"],"equipment":["chair","sleeping-bag"]}'::jsonb, '{"lastName":"韓","firstName":"宗翰","postalCode":"701","city":"臺南市","district":"東區","township":"","addressLine1":"長榮路二段200號","addressLine2":"","email":"user037@example.com","phone":"0969481627"}'::jsonb, '["高消費"]'::jsonb, 'google', '/assets/images/avatar-02.jpg', TRUE),
  ('U038', '/assets/images/avatar-03.jpg', '唐美玲', '0906494698', 'user038@example.com', '1988-03-11', '2022-03-11', 20940, 'guide', '嚮導', 2094, FALSE, '{"styles":["car-camping","glamping"],"equipment":["navigation","backpack"]}'::jsonb, '{"lastName":"唐","firstName":"美玲","postalCode":"110","city":"臺北市","district":"信義區","township":"","addressLine1":"松仁路100號","addressLine2":"","email":"user038@example.com","phone":"0906494698"}'::jsonb, '["高消費","高退貨率"]'::jsonb, 'facebook', '/assets/images/avatar-03.jpg', TRUE),
  ('U039', '/assets/images/avatar-01.jpg', '馮志偉', '0943507769', 'user039@example.com', '1989-04-12', '2023-04-12', 56490, 'master', '大師', 5649, FALSE, '{"styles":["ultralight","backpacking"],"equipment":["safety","cooking"]}'::jsonb, '{"lastName":"馮","firstName":"志偉","postalCode":"200","city":"基隆市","district":"仁愛區","township":"","addressLine1":"愛一路50號","addressLine2":"","email":"user039@example.com","phone":"0943507769"}'::jsonb, '["高消費"]'::jsonb, 'line', '/assets/images/avatar-01.jpg', TRUE),
  ('U040', '/assets/images/avatar-02.jpg', '董佳蓉', '0980520840', 'user040@example.com', '1990-05-13', '2024-05-13', 45000, 'master', '大師', 4500, TRUE, '{"styles":["base-camp","family"],"equipment":["photography","lighting"]}'::jsonb, '{"lastName":"董","firstName":"佳蓉","postalCode":"300","city":"新竹市","district":"東區","township":"","addressLine1":"光復路一段100號","addressLine2":"","email":"user040@example.com","phone":"0980520840"}'::jsonb, '["高消費"]'::jsonb, 'google', '/assets/images/avatar-02.jpg', TRUE),
  ('U041', '/assets/images/avatar-03.jpg', '程俊賢', '0917533911', 'user041@example.com', '1991-06-14', '2025-06-14', 22300, 'guide', '嚮導', 2230, FALSE, '{"styles":["glamping","solo"],"equipment":["tent","clothing"]}'::jsonb, '{"lastName":"程","firstName":"俊賢","postalCode":"407","city":"臺中市","district":"西屯區","township":"","addressLine1":"台灣大道三段500號","addressLine2":"","email":"user041@example.com","phone":"0917533911"}'::jsonb, '["高消費"]'::jsonb, 'facebook', '/assets/images/avatar-03.jpg', TRUE),
  ('U042', '/assets/images/avatar-01.jpg', '傅淑芬', '0954546982', 'user042@example.com', '1992-07-15', '2019-07-15', 40300, 'master', '大師', 4030, FALSE, '{"styles":["backpacking","hiking"],"equipment":["sleeping-bag","chair"]}'::jsonb, '{"lastName":"傅","firstName":"淑芬","postalCode":"320","city":"桃園市","district":"中壢區","township":"","addressLine1":"中山路300號","addressLine2":"","email":"user042@example.com","phone":"0954546982"}'::jsonb, '["高消費"]'::jsonb, 'line', '/assets/images/avatar-01.jpg', TRUE),
  ('U043', '/assets/images/avatar-02.jpg', '范冠霖', '0991559053', 'user043@example.com', '1993-08-16', '2020-08-16', 27760, 'guide', '嚮導', 2776, TRUE, '{"styles":["family","car-camping"],"equipment":["backpack","navigation"]}'::jsonb, '{"lastName":"范","firstName":"冠霖","postalCode":"110","city":"臺北市","district":"信義區","township":"","addressLine1":"松仁路100號","addressLine2":"","email":"user043@example.com","phone":"0991559053"}'::jsonb, '["高消費"]'::jsonb, 'google', '/assets/images/avatar-02.jpg', TRUE),
  ('U044', '/assets/images/avatar-03.jpg', '戴雅婷', '0928572124', 'user044@example.com', '1994-09-17', '2021-09-17', 61710, 'master', '大師', 6171, FALSE, '{"styles":["solo","ultralight"],"equipment":["cooking","safety"]}'::jsonb, '{"lastName":"戴","firstName":"雅婷","postalCode":"260","city":"宜蘭市","district":"","township":"","addressLine1":"中山路二段80號","addressLine2":"","email":"user044@example.com","phone":"0928572124"}'::jsonb, '["高消費"]'::jsonb, 'facebook', '/assets/images/avatar-03.jpg', TRUE),
  ('U045', '/assets/images/avatar-01.jpg', '段家銘', '0965585195', 'user045@example.com', '1995-10-18', '2022-10-18', 33850, 'master', '大師', 3385, FALSE, '{"styles":["hiking","base-camp"],"equipment":["lighting","photography"]}'::jsonb, '{"lastName":"段","firstName":"家銘","postalCode":"600","city":"嘉義市","district":"西區","township":"","addressLine1":"垂楊路200號","addressLine2":"","email":"user045@example.com","phone":"0965585195"}'::jsonb, '["高消費"]'::jsonb, 'line', '/assets/images/avatar-01.jpg', TRUE),
  ('U046', '/assets/images/avatar-02.jpg', '曹佩珊', '0902598266', 'user046@example.com', '1996-11-19', '2023-11-19', 19100, 'guide', '嚮導', 1910, TRUE, '{"styles":["car-camping","glamping"],"equipment":["clothing","tent"]}'::jsonb, '{"lastName":"曹","firstName":"佩珊","postalCode":"300","city":"新竹市","district":"東區","township":"","addressLine1":"光復路一段100號","addressLine2":"","email":"user046@example.com","phone":"0902598266"}'::jsonb, '["高消費","高退貨率"]'::jsonb, 'google', '/assets/images/avatar-02.jpg', TRUE),
  ('U047', '/assets/images/avatar-03.jpg', '袁宇翔', '0939611337', 'user047@example.com', '1997-12-20', '2024-12-20', 37840, 'master', '大師', 3784, FALSE, '{"styles":["ultralight","backpacking"],"equipment":["chair","sleeping-bag"]}'::jsonb, '{"lastName":"袁","firstName":"宇翔","postalCode":"500","city":"彰化市","district":"","township":"","addressLine1":"中山路一段66號","addressLine2":"","email":"user047@example.com","phone":"0939611337"}'::jsonb, '["高消費","高退貨率"]'::jsonb, 'facebook', '/assets/images/avatar-03.jpg', TRUE),
  ('U048', '/assets/images/avatar-01.jpg', '鄧欣妤', '0976624408', 'user048@example.com', '1998-01-21', '2025-01-21', 27690, 'guide', '嚮導', 2769, FALSE, '{"styles":["base-camp","family"],"equipment":["navigation","backpack"]}'::jsonb, '{"lastName":"鄧","firstName":"欣妤","postalCode":"220","city":"新北市","district":"板橋區","township":"","addressLine1":"文化路二段100號","addressLine2":"","email":"user048@example.com","phone":"0976624408"}'::jsonb, '["高消費","高退貨率"]'::jsonb, 'line', '/assets/images/avatar-01.jpg', TRUE),
  ('U049', '/assets/images/avatar-02.jpg', '許柏均', '0913637479', 'user049@example.com', '1999-02-22', '2019-02-22', 40600, 'master', '大師', 4060, TRUE, '{"styles":["glamping","solo"],"equipment":["safety","cooking"]}'::jsonb, '{"lastName":"許","firstName":"柏均","postalCode":"970","city":"花蓮市","district":"","township":"","addressLine1":"國聯一路20號","addressLine2":"","email":"user049@example.com","phone":"0913637479"}'::jsonb, '["高消費","高退貨率"]'::jsonb, 'google', '/assets/images/avatar-02.jpg', TRUE),
  ('U050', '/assets/images/avatar-03.jpg', '丁惠珍', '0950650550', 'user050@example.com', '1975-03-23', '2020-03-23', 54200, 'master', '大師', 5420, FALSE, '{"styles":["backpacking","hiking"],"equipment":["photography","lighting"]}'::jsonb, '{"lastName":"丁","firstName":"惠珍","postalCode":"970","city":"花蓮市","district":"","township":"","addressLine1":"國聯一路20號","addressLine2":"","email":"user050@example.com","phone":"0950650550"}'::jsonb, '["高消費"]'::jsonb, 'facebook', '/assets/images/avatar-03.jpg', TRUE)
ON CONFLICT (id) DO NOTHING;

UPDATE customers SET avatar_url = COALESCE(avatar_url, avatar);

INSERT INTO admin_users (id, name, email, role) VALUES
  ('01', 'Warehouse 01', '01@migration.invalid', 'warehouse'),
  ('02', 'Warehouse 02', '02@migration.invalid', 'warehouse'),
  ('03', 'Warehouse 03', '03@migration.invalid', 'warehouse'),
  ('admin', 'System Admin', 'admin@migration.invalid', 'admin')
ON CONFLICT (id) DO NOTHING;

INSERT INTO admin_users (id, name, email, role)
SELECT ref.id, ref.id, ref.id || '@migration.invalid',
       CASE WHEN ref.id = 'admin' THEN 'admin' ELSE 'operator' END
FROM (
  SELECT employee_id AS id FROM movements WHERE employee_id IS NOT NULL
  UNION SELECT created_by FROM zone_blocks WHERE created_by IS NOT NULL
  UNION SELECT created_by FROM campground_closures WHERE created_by IS NOT NULL
) ref
ON CONFLICT (id) DO NOTHING;

INSERT INTO brands (id, name, logo_url, sort_order) VALUES
  ('brand-001', 'Snow Peak', NULL, 1),
  ('brand-002', 'Osprey', NULL, 2),
  ('brand-003', 'MSR', NULL, 3),
  ('brand-004', 'Coleman', NULL, 4),
  ('brand-005', 'Patagonia', NULL, 5),
  ('brand-006', 'Deuter', NULL, 6),
  ('brand-007', 'Sawyer', NULL, 7),
  ('brand-008', 'Black Diamond', NULL, 8),
  ('brand-009', 'Helinox', NULL, 9),
  ('brand-010', 'Columbia', NULL, 10),
  ('brand-011', 'Ogawa', NULL, 11),
  ('brand-012', 'Therm-a-Rest', NULL, 12)
ON CONFLICT (id) DO NOTHING;

INSERT INTO product_categories (code, name, sort_order)
SELECT seed.code, seed.name, seed.sort_order
FROM (VALUES
  ('tent', '帳篷', 1),
  ('sleeping-bag', '睡袋', 2),
  ('cookware', '炊具', 3),
  ('lighting', '燈具', 4),
  ('backpack', '背包', 5),
  ('other', '其他', 6)
) AS seed(code, name, sort_order)
WHERE NOT EXISTS (SELECT 1 FROM product_categories current WHERE current.code = seed.code OR current.name = seed.name);

INSERT INTO campgrounds (id, name, region, description) VALUES
  ('C002', '雲海仙境露營區', '北部', '坐落於海拔 1,800 公尺的山頂，每逢清晨雲海翻騰，是北台灣最壯觀的高山露營地。夜晚氣溫涼爽，星空清晰可見，是追求自然療癒的首選。'),
  ('C003', '溪谷秘境野營地', '中部', '緊鄰清澈溪流，水聲潺潺，夏日親水露營的不二之選。夜晚可觀星，營地旁設有天然戲水區，全家出遊的完美選擇。'),
  ('C004', '太平山森林豪華露營', '北部', '台灣頂級 Glamping 體驗，免搭帳篷，入住配備空調與獨立洗手間的豪華帳型，享受森林芬多精與雲海美景，是犒賞自己的奢華選擇。'),
  ('C005', '南台灣星空草原營地', '南部', '位於屏東平原，視野開闊，光害極低，是南台灣最佳觀星露營勝地。廣闊草地讓孩子盡情奔跑，寵物也歡迎入住。'),
  ('C006', '花蓮海岸風露營區', '東部', '緊鄰太平洋，清晨可見日出從海面升起，聆聽浪濤聲入睡，提供有雨棚遮蔽，無論晴雨都能盡情享受海岸露營。'),
  ('C007', '阿里山雲霧繚繞營地', '南部', '海拔 2,200 公尺，阿里山林道旁，終年雲霧繚繞，日出與神木相伴。全區設有完善雨棚，是愛雨族的最愛。'),
  ('C008', '宜蘭礁溪湯泉露營', '北部', '全台唯一溫泉露營體驗，帳篷旁設有私人泡湯池，泡完湯直接鑽進睡袋。溪邊環境清幽，可攜帶寵物同行。'),
  ('C009', '台中武陵溪流野營', '中部', '武陵農場旁，四季各有風情：春賞櫻、夏戲水、秋楓紅、冬雪景。溪流旁的棧板區是最受歡迎的位置，也提供完整裝備租借。')
ON CONFLICT (id) DO NOTHING;

INSERT INTO campground_zones (id, campground_id, type, capacity_per_site, price_weekday, price_holiday, total_sites) VALUES
  ('Z001', 'C002', '草皮區', 4, 1000, 1500, 10),
  ('Z002', 'C002', '雨棚區', 6, 1200, 1800, 5),
  ('Z003', 'C003', '碎石區', 4, 800, 1200, 15),
  ('Z004', 'C003', '棧板區', 4, 900, 1300, 8),
  ('Z005', 'C004', '免搭帳／豪華露營 (Glamping)', 2, 3500, 5000, 4),
  ('Z006', 'C005', '草皮區', 6, 700, 1100, 20),
  ('Z007', 'C006', '草皮區', 4, 900, 1400, 12),
  ('Z008', 'C006', '雨棚區', 4, 1100, 1600, 6),
  ('Z009', 'C007', '棧板區', 4, 1100, 1700, 10),
  ('Z010', 'C008', '草皮區', 4, 1500, 2200, 8),
  ('Z011', 'C008', '免搭帳／豪華露營 (Glamping)', 2, 4000, 6000, 3),
  ('Z012', 'C009', '碎石區', 4, 950, 1450, 14),
  ('Z013', 'C009', '棧板區', 4, 1050, 1600, 8)
ON CONFLICT (id) DO NOTHING;

INSERT INTO branches (id, name, address, phone, hours, image, latitude, longitude, map_query, description, code, business_hours, image_url) VALUES
  ('branch-001', 'Yuruicamp 台北旗艦店', '台北市信義區信義路五段100號 B1', '02-8789-1234', '週一至週日 10:00–20:00', 'https://picsum.photos/seed/store1/600/400', 25.033, 121.5654, '台北市信義區信義路五段100號', '台北旗艦店位於信義商圈核心，擁有完整產品陳列和互動體驗區，提供帳篷實搭示範。', 'branch-001', '週一至週日 10:00–20:00', 'https://picsum.photos/seed/store1/600/400'),
  ('branch-002', 'Yuruicamp 台中中港店', '台中市西屯區文心路二段101號', '04-2234-5678', '週一至週五 11:00–21:00，週六日 10:00–21:00', 'https://picsum.photos/seed/store2/600/400', 24.1637, 120.6467, '台中市西屯區文心路二段101號', '台中中港店是中部最大的露營裝備專賣店，擁有超過 500 坪的展示空間。', 'branch-002', '週一至週五 11:00–21:00，週六日 10:00–21:00', 'https://picsum.photos/seed/store2/600/400'),
  ('branch-003', 'Yuruicamp 高雄左營店', '高雄市左營區重聖街199號', '07-5567-8901', '週一至週五 11:00–21:00，週六日 10:00–21:00', 'https://picsum.photos/seed/store3/600/400', 22.6978, 120.2991, '高雄市左營區重聖街199號', '南台灣最齊全的戶外裝備選購中心，提供裝備租借讓南部的露友輕鬆嘗試露營。', 'branch-003', '週一至週五 11:00–21:00，週六日 10:00–21:00', 'https://picsum.photos/seed/store3/600/400')
ON CONFLICT (id) DO NOTHING;

UPDATE branches
SET code = COALESCE(code, id),
    business_hours = COALESCE(business_hours, hours),
    image_url = COALESCE(image_url, image);

INSERT INTO branch_features (branch_id, feature)
SELECT seed.branch_id, seed.feature
FROM (VALUES
  ('branch-001', '體驗區'),
  ('branch-001', '專業諮詢'),
  ('branch-001', '租借服務'),
  ('branch-001', '停車場'),
  ('branch-002', '體驗區'),
  ('branch-002', '專業諮詢'),
  ('branch-002', '停車場'),
  ('branch-003', '體驗區'),
  ('branch-003', '租借服務')
) AS seed(branch_id, feature)
WHERE NOT EXISTS (
  SELECT 1 FROM branch_features current
  WHERE current.branch_id = seed.branch_id AND current.feature = seed.feature
);

INSERT INTO preference_options (type, code, label, sort_order)
SELECT seed.type, seed.code, seed.label, seed.sort_order
FROM (VALUES
  ('style', 'backpacking', '背包旅行', 1),
  ('style', 'hiking', '健行', 2),
  ('style', 'family', '家庭露營', 3),
  ('style', 'car-camping', '車露', 4),
  ('style', 'solo', '單人露營', 5),
  ('style', 'ultralight', '輕量化', 6),
  ('style', 'base-camp', '基地營', 7),
  ('style', 'glamping', '豪華露營', 8),
  ('equipment', 'tent', '帳篷', 1),
  ('equipment', 'backpack', '背包', 2),
  ('equipment', 'sleeping-bag', '睡袋', 3),
  ('equipment', 'chair', '露營椅', 4),
  ('equipment', 'navigation', '導航', 5),
  ('equipment', 'cooking', '炊具', 6),
  ('equipment', 'safety', '安全裝備', 7),
  ('equipment', 'lighting', '照明', 8),
  ('equipment', 'photography', '攝影', 9),
  ('equipment', 'clothing', '服飾', 10)
) AS seed(type, code, label, sort_order)
WHERE NOT EXISTS (
  SELECT 1 FROM preference_options current
  WHERE current.type = seed.type AND current.code = seed.code
);

INSERT INTO customer_preferences (customer_id, preference_id)
SELECT customer.id, option.id
FROM customers customer
CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(customer.preferences->'styles', '[]'::jsonb)) value(code)
JOIN preference_options option ON option.type = 'style' AND option.code = value.code
ON CONFLICT DO NOTHING;

INSERT INTO customer_preferences (customer_id, preference_id)
SELECT customer.id, option.id
FROM customers customer
CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(customer.preferences->'equipment', '[]'::jsonb)) value(code)
JOIN preference_options option ON option.type = 'equipment' AND option.code = value.code
ON CONFLICT DO NOTHING;

INSERT INTO customer_tags (name, color, sort_order)
SELECT seed.name, seed.color, seed.sort_order
FROM (VALUES
  ('高消費', 'bg-success', 1),
  ('高退貨率', 'bg-danger', 2),
  ('新會員', 'bg-info text-dark', 3)
) AS seed(name, color, sort_order)
WHERE NOT EXISTS (SELECT 1 FROM customer_tags current WHERE current.name = seed.name);

INSERT INTO customer_tag_assignments (customer_id, tag_id)
SELECT customer.id, tag.id
FROM customers customer
CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(customer.tags, '[]'::jsonb)) value(name)
JOIN customer_tags tag ON tag.name = value.name
ON CONFLICT DO NOTHING;

INSERT INTO customer_shipping_addresses (
  customer_id, recipient_name, postal_code, city, district, address_line, phone, is_default
)
SELECT customer.id,
       CONCAT(COALESCE(customer.shipping_address->>'lastName', ''), COALESCE(customer.shipping_address->>'firstName', '')),
       customer.shipping_address->>'postalCode',
       customer.shipping_address->>'city',
       COALESCE(NULLIF(customer.shipping_address->>'district', ''), customer.shipping_address->>'township'),
       CONCAT_WS(' ', NULLIF(customer.shipping_address->>'addressLine1', ''), NULLIF(customer.shipping_address->>'addressLine2', '')),
       customer.shipping_address->>'phone', TRUE
FROM customers customer
WHERE customer.shipping_address IS NOT NULL AND customer.shipping_address <> '{}'::jsonb
  AND NOT EXISTS (
    SELECT 1 FROM customer_shipping_addresses address
    WHERE address.customer_id = customer.id AND address.is_default
  );

INSERT INTO inventory_locations (id, code, inventory_domain, type, branch_id, name) VALUES
  ('main', 'main', 'store', 'main', NULL, '商城主倉'),
  ('branch-001', 'branch-001', 'store', 'branch', 'branch-001', 'Yuruicamp 台北旗艦店'),
  ('branch-002', 'branch-002', 'store', 'branch', 'branch-002', 'Yuruicamp 台中中港店'),
  ('branch-003', 'branch-003', 'store', 'branch', 'branch-003', 'Yuruicamp 高雄左營店'),
  ('store-inspection', 'store-inspection', 'store', 'inspection', NULL, '商城退貨待檢區'),
  ('store-repair', 'store-repair', 'store', 'repair', NULL, '商城維修區'),
  ('store-damaged', 'store-damaged', 'store', 'damaged', NULL, '商城損壞區'),
  ('C001', 'C001', 'rental', 'main', NULL, '租借主倉'),
  ('C002', 'C002', 'rental', 'campground', NULL, '雲海仙境露營區'),
  ('C003', 'C003', 'rental', 'campground', NULL, '溪谷秘境野營地'),
  ('C004', 'C004', 'rental', 'campground', NULL, '太平山森林豪華露營'),
  ('C005', 'C005', 'rental', 'campground', NULL, '南台灣星空草原營地'),
  ('C006', 'C006', 'rental', 'campground', NULL, '花蓮海岸風露營區'),
  ('C007', 'C007', 'rental', 'campground', NULL, '阿里山雲霧繚繞營地'),
  ('C008', 'C008', 'rental', 'campground', NULL, '宜蘭礁溪湯泉露營'),
  ('C009', 'C009', 'rental', 'campground', NULL, '台中武陵溪流野營')
ON CONFLICT (id) DO NOTHING;

INSERT INTO migration.p1_location_aliases (alias, location_id, source) VALUES
  ('main', 'main', 'fixture code'),
  ('商店主倉', 'main', 'movement legacy label'),
  ('商城主倉', 'main', 'canonical name'),
  ('租借主倉', 'C001', 'movement legacy label'),
  ('C001', 'C001', 'fixture code'),
  ('branch-001', 'branch-001', 'fixture code'),
  ('Yuruicamp 台北旗艦店', 'branch-001', 'canonical name'),
  ('台北旗艦店', 'branch-001', 'movement legacy label'),
  ('branch-002', 'branch-002', 'fixture code'),
  ('Yuruicamp 台中中港店', 'branch-002', 'canonical name'),
  ('台中中港店', 'branch-002', 'movement legacy label'),
  ('branch-003', 'branch-003', 'fixture code'),
  ('Yuruicamp 高雄左營店', 'branch-003', 'canonical name'),
  ('高雄左營店', 'branch-003', 'movement legacy label'),
  ('C002', 'C002', 'fixture code'),
  ('雲海仙境露營區', 'C002', 'canonical name'),
  ('C003', 'C003', 'fixture code'),
  ('溪谷秘境野營地', 'C003', 'canonical name'),
  ('C004', 'C004', 'fixture code'),
  ('太平山森林豪華露營', 'C004', 'canonical name'),
  ('C005', 'C005', 'fixture code'),
  ('南台灣星空草原營地', 'C005', 'canonical name'),
  ('C006', 'C006', 'fixture code'),
  ('花蓮海岸風露營區', 'C006', 'canonical name'),
  ('C007', 'C007', 'fixture code'),
  ('阿里山雲霧繚繞營地', 'C007', 'canonical name'),
  ('C008', 'C008', 'fixture code'),
  ('宜蘭礁溪湯泉露營', 'C008', 'canonical name'),
  ('C009', 'C009', 'fixture code'),
  ('台中武陵溪流野營', 'C009', 'canonical name')
ON CONFLICT (alias) DO NOTHING;

INSERT INTO migration.p1_location_quarantine (source_table, source_row_id, field_name, raw_value, reason) VALUES
  ('data/admin/movement.json', '3:1', 'from_store', '湖畔星空營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '3:1', 'to_store', '溪谷森林營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '4:0', 'to_store', '溪谷森林營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '7:0', 'to_store', '雲海高原營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '8:0', 'to_store', '溪谷森林營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '9:0', 'to_store', '海岸微風營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '11:1', 'from_store', '湖畔星空營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '11:1', 'to_store', '松林野營基地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '12:0', 'to_store', '湖畔星空營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '12:2', 'from_store', '湖畔星空營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '12:2', 'to_store', '雲海高原營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '14:0', 'from_store', '湖畔星空營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '14:0', 'to_store', '溪谷森林營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '15:2', 'from_store', '湖畔星空營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '15:2', 'to_store', '溪谷森林營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '17:0', 'from_store', '海岸微風營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '18:0', 'to_store', '雲海高原營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '20:0', 'to_store', '雲海高原營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '20:1', 'from_store', '松林野營基地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '22:0', 'to_store', '湖畔星空營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '23:0', 'from_store', '溪谷森林營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '23:0', 'to_store', '雲海高原營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '25:0', 'from_store', '溪谷森林營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '28:0', 'to_store', '湖畔星空營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '29:0', 'from_store', '雲海高原營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '29:0', 'to_store', '松林野營基地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '29:1', 'from_store', '溪谷森林營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '29:1', 'to_store', '松林野營基地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '29:2', 'to_store', '溪谷森林營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '31:1', 'from_store', '松林野營基地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '32:1', 'from_store', '溪谷森林營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '32:1', 'to_store', '雲海高原營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '33:0', 'from_store', '海岸微風營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '33:0', 'to_store', '溪谷森林營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '35:0', 'to_store', '雲海高原營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '38:0', 'from_store', '海岸微風營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '38:0', 'to_store', '松林野營基地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '39:0', 'from_store', '雲海高原營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '39:0', 'to_store', '松林野營基地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '41:0', 'from_store', '松林野營基地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '44:0', 'from_store', '海岸微風營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '47:0', 'to_store', '雲海高原營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '48:0', 'from_store', '溪谷森林營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '48:0', 'to_store', '海岸微風營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '50:1', 'to_store', '雲海高原營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '51:0', 'from_store', '溪谷森林營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '52:1', 'from_store', '雲海高原營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '52:1', 'to_store', '海岸微風營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '53:0', 'to_store', '溪谷森林營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '53:1', 'from_store', '海岸微風營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '53:1', 'to_store', '雲海高原營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '54:0', 'from_store', '溪谷森林營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '54:0', 'to_store', '海岸微風營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '55:0', 'to_store', '松林野營基地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '57:0', 'from_store', '溪谷森林營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '57:0', 'to_store', '雲海高原營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '59:0', 'to_store', '湖畔星空營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '60:0', 'to_store', '松林野營基地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '61:0', 'from_store', '溪谷森林營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '62:0', 'to_store', '雲海高原營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '66:0', 'to_store', '湖畔星空營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '67:0', 'from_store', '海岸微風營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '67:0', 'to_store', '雲海高原營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '71:0', 'from_store', '海岸微風營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '71:0', 'to_store', '溪谷森林營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '73:0', 'from_store', '海岸微風營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '73:0', 'to_store', '雲海高原營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '75:0', 'to_store', '雲海高原營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '76:1', 'to_store', '松林野營基地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '76:2', 'to_store', '湖畔星空營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '77:0', 'from_store', '松林野營基地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '79:0', 'from_store', '溪谷森林營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '79:0', 'to_store', '海岸微風營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '79:2', 'to_store', '松林野營基地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '80:1', 'to_store', '溪谷森林營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '80:2', 'from_store', '雲海高原營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '80:2', 'to_store', '海岸微風營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '82:0', 'to_store', '溪谷森林營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '84:0', 'from_store', '海岸微風營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '84:0', 'to_store', '松林野營基地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '86:0', 'from_store', '海岸微風營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '86:0', 'to_store', '溪谷森林營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '87:0', 'to_store', '雲海高原營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '88:0', 'to_store', '溪谷森林營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '96:0', 'to_store', '湖畔星空營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '97:0', 'to_store', '雲海高原營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '98:0', 'to_store', '海岸微風營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '100:0', 'to_store', '溪谷森林營地', 'No unique P1 inventory location mapping; manual classification required'),
  ('data/admin/movement.json', '100:2', 'to_store', '松林野營基地', 'No unique P1 inventory location mapping; manual classification required')
ON CONFLICT DO NOTHING;

INSERT INTO migration.p1_location_quarantine (source_table, source_row_id, field_name, raw_value, reason)
SELECT 'movement_items', item.id::text, endpoint.field_name, endpoint.raw_value,
       'No unique P1 inventory location mapping; manual classification required'
FROM movement_items item
CROSS JOIN LATERAL (VALUES
  ('from_store', item.from_store), ('to_store', item.to_store)
) endpoint(field_name, raw_value)
LEFT JOIN migration.p1_location_aliases alias ON alias.alias = endpoint.raw_value
WHERE endpoint.raw_value IS NOT NULL
  AND endpoint.raw_value NOT IN ('進貨', '損耗')
  AND alias.alias IS NULL
ON CONFLICT DO NOTHING;
