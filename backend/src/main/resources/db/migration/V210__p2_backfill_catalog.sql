-- P2 backfill generated from the frozen catalog fixture set on 2026-07-14.
-- Applied migrations are immutable: future fixture changes require a new migration.

-- Yuruicamp is an exact source brand used by 25 products. It is added as a
-- first-party brand rather than being guessed as one of the marketing brands.
INSERT INTO brands (id, name, sort_order)
SELECT 'brand-yuruicamp', 'Yuruicamp', COALESCE(MAX(sort_order), 0) + 1
FROM brands
WHERE NOT EXISTS (SELECT 1 FROM brands WHERE name = 'Yuruicamp');

INSERT INTO migration.p2_product_source (product_id, payload) VALUES
  ('P001', '{"id":"P001","rentalId":"R001","rentalEnabled":true,"name":"Coleman 六人帳篷","category":"帳篷","brand":"Coleman","interestTags":["tent"],"price":3200,"status":"active","image":"/assets/images/products/P001-1.jpg","images":["/assets/images/products/P001-1.jpg","/assets/images/products/P001-2.jpg","/assets/images/products/P001-3.jpg"],"description":"<p><strong>Coleman 六人帳篷</strong> 為 Yuruicamp 精選的帳篷商品，提供 <em>深橄欖綠</em>、<em>沙漠棕</em>、<em>太空灰</em> 三色可選。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{"weight":"4.2 kg","capacity":"6 人","material":"聚酯纖維","waterproof":"3000mm"},"variants":[{"id":"v-P001-0","color":"深橄欖綠","size":"","label":"深橄欖綠","branch":{"main":2,"branch-001":1,"branch-002":0,"branch-003":0}},{"id":"v-P001-1","color":"沙漠棕","size":"","label":"沙漠棕","branch":{"main":0,"branch-001":1,"branch-002":0,"branch-003":1}},{"id":"v-P001-2","color":"太空灰","size":"","label":"太空灰","branch":{"main":0,"branch-001":0,"branch-002":0,"branch-003":0}}],"tags":["帳篷","Coleman"],"totalStock":5,"branch":{"main":2,"branch-001":2,"branch-002":0,"branch-003":1}}'::jsonb),
  ('P002', '{"id":"P002","rentalId":"R002","rentalEnabled":true,"name":"MSR 超輕量帳篷","category":"帳篷","brand":"MSR","interestTags":["tent"],"price":9800,"status":"active","image":"/assets/images/products/P002-1.jpg","images":["/assets/images/products/P002-1.jpg","/assets/images/products/P002-2.jpg","/assets/images/products/P002-3.jpg"],"description":"<p><strong>MSR 超輕量帳篷</strong> 為 Yuruicamp 精選的帳篷商品，規格：<em>沙漠卡其</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{},"variants":[{"id":"v-P002-0","color":"沙漠卡其","size":"","label":"沙漠卡其","branch":{"main":2,"branch-001":7,"branch-002":4,"branch-003":1}}],"tags":["帳篷","MSR"],"totalStock":14,"branch":{"main":2,"branch-001":7,"branch-002":4,"branch-003":1}}'::jsonb),
  ('P003', '{"id":"P003","rentalId":"R018","rentalEnabled":true,"name":"充氣式睡墊","category":"睡袋","brand":"Yuruicamp","interestTags":["safety"],"price":1200,"status":"active","image":"/assets/images/products/P003-1.jpg","images":["/assets/images/products/P003-1.jpg","/assets/images/products/P003-2.jpg","/assets/images/products/P003-3.jpg"],"description":"<p><strong>充氣式睡墊</strong> 為 Yuruicamp 精選的睡袋商品，提供 <em>S / M / L</em> 三種尺寸。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{"weight":"0.8 kg","material":"TPU 充氣層","capacity":"單人"},"variants":[{"id":"v-P003-0","color":"","size":"S","label":"S","branch":{"main":1,"branch-001":3,"branch-002":1,"branch-003":1}},{"id":"v-P003-1","color":"","size":"M","label":"M","branch":{"main":1,"branch-001":3,"branch-002":1,"branch-003":1}},{"id":"v-P003-2","color":"","size":"L","label":"L","branch":{"main":0,"branch-001":2,"branch-002":0,"branch-003":1}}],"tags":["睡袋"],"totalStock":15,"branch":{"main":2,"branch-001":8,"branch-002":2,"branch-003":3}}'::jsonb),
  ('P004', '{"id":"P004","rentalId":"R005","rentalEnabled":true,"name":"羽絨睡袋","category":"睡袋","brand":"Yuruicamp","interestTags":["safety"],"price":2800,"status":"active","image":"/assets/images/products/P004-1.jpg","images":["/assets/images/products/P004-1.jpg","/assets/images/products/P004-2.jpg","/assets/images/products/P004-3.jpg"],"description":"<p><strong>羽絨睡袋</strong> 為 Yuruicamp 精選的睡袋商品，提供 <em>-10°C / -5°C / 0°C</em> 三種溫標可選。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{"weight":"1.2 kg","material":"90% 羽絨","capacity":"單人"},"variants":[{"id":"v-P004-0","color":"","size":"-10°C","label":"-10°C","branch":{"main":1,"branch-001":3,"branch-002":2,"branch-003":0}},{"id":"v-P004-1","color":"","size":"-5°C","label":"-5°C","branch":{"main":1,"branch-001":2,"branch-002":1,"branch-003":0}},{"id":"v-P004-2","color":"","size":"0°C","label":"0°C","branch":{"main":0,"branch-001":1,"branch-002":0,"branch-003":0}}],"tags":["睡袋"],"totalStock":11,"branch":{"main":2,"branch-001":6,"branch-002":3,"branch-003":0}}'::jsonb),
  ('P005', '{"id":"P005","rentalId":"R006","rentalEnabled":true,"name":"Coleman 氣化爐","category":"炊具","brand":"Coleman","interestTags":["cooking"],"price":5000,"status":"active","image":"/assets/images/products/P005-1.jpg","images":["/assets/images/products/P005-1.jpg","/assets/images/products/P005-2.jpg","/assets/images/products/P005-3.jpg"],"description":"<p><strong>Coleman 氣化爐</strong> 為 Yuruicamp 精選的炊具商品，規格：<em>標準版</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{},"variants":[{"id":"v-P005-0","color":"標準版","size":"","label":"標準版","branch":{"main":3,"branch-001":0,"branch-002":2,"branch-003":6}}],"tags":["炊具","Coleman"],"totalStock":11,"branch":{"main":3,"branch-001":0,"branch-002":2,"branch-003":6}}'::jsonb),
  ('P006', '{"id":"P006","rentalId":"R007","rentalEnabled":true,"name":"Snow Peak 鈦合金杯組","category":"炊具","brand":"Snow Peak","interestTags":["cooking"],"price":1800,"status":"active","image":"/assets/images/products/P006-1.jpg","images":["/assets/images/products/P006-1.jpg","/assets/images/products/P006-2.jpg","/assets/images/products/P006-3.jpg"],"description":"<p><strong>Snow Peak 鈦合金杯組</strong> 為 Yuruicamp 精選的炊具商品，規格：<em>鈦金屬原色</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{},"variants":[{"id":"v-P006-0","color":"鈦金屬原色","size":"","label":"鈦金屬原色","branch":{"main":2,"branch-001":1,"branch-002":2,"branch-003":5}}],"tags":["炊具","Snow Peak"],"totalStock":10,"branch":{"main":2,"branch-001":1,"branch-002":2,"branch-003":5}}'::jsonb),
  ('P007', '{"id":"P007","rentalId":"R011","rentalEnabled":true,"name":"LED 露營燈","category":"燈具","brand":"Yuruicamp","interestTags":["safety"],"price":800,"status":"active","image":"/assets/images/products/P007-1.jpg","images":["/assets/images/products/P007-1.jpg","/assets/images/products/P007-2.jpg","/assets/images/products/P007-3.jpg"],"description":"<p><strong>LED 露營燈</strong> 為 Yuruicamp 精選的燈具商品，提供 <em>暖白光</em>、<em>冷白光</em> 兩種色溫。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{"lumens":"300 lm","batteryLife":"約 40 小時","power":"USB 充電"},"variants":[{"id":"v-P007-0","color":"暖白光","size":"","label":"暖白光","branch":{"main":1,"branch-001":2,"branch-002":2,"branch-003":2}},{"id":"v-P007-1","color":"冷白光","size":"","label":"冷白光","branch":{"main":1,"branch-001":2,"branch-002":2,"branch-003":2}}],"tags":["燈具"],"totalStock":14,"branch":{"main":2,"branch-001":4,"branch-002":4,"branch-003":4}}'::jsonb),
  ('P008', '{"id":"P008","rentalId":"R013","rentalEnabled":true,"name":"防水登山背包","category":"背包","brand":"Yuruicamp","interestTags":["backpack"],"price":1600,"status":"active","image":"/assets/images/products/P008-1.jpg","images":["/assets/images/products/P008-1.jpg","/assets/images/products/P008-2.jpg","/assets/images/products/P008-3.jpg"],"description":"<p><strong>防水登山背包</strong> 為 Yuruicamp 精選的背包商品，提供 <em>35L / 45L</em> 兩種容量（森林綠）。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{"weight":"1.1 kg","material":"防潑水尼龍","waterproof":"IPX4"},"variants":[{"id":"v-P008-0","color":"森林綠","size":"35L","label":"森林綠 / 35L","branch":{"main":1,"branch-001":2,"branch-002":2,"branch-003":3}},{"id":"v-P008-1","color":"森林綠","size":"45L","label":"森林綠 / 45L","branch":{"main":1,"branch-001":2,"branch-002":3,"branch-003":3}}],"tags":["背包"],"totalStock":17,"branch":{"main":2,"branch-001":4,"branch-002":5,"branch-003":6}}'::jsonb),
  ('P009', '{"id":"P009","rentalId":"R008","rentalEnabled":true,"name":"折疊桌椅組","category":"其他","brand":"Yuruicamp","interestTags":["safety"],"price":2800,"status":"active","image":"/assets/images/products/P009-1.jpg","images":["/assets/images/products/P009-1.jpg","/assets/images/products/P009-2.jpg","/assets/images/products/P009-3.jpg"],"description":"<p><strong>折疊桌椅組</strong> 為 Yuruicamp 精選的其他商品，規格：<em>鋁合金輕量版</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{},"variants":[{"id":"v-P009-0","color":"鋁合金輕量版","size":"","label":"鋁合金輕量版","branch":{"main":3,"branch-001":8,"branch-002":8,"branch-003":7}}],"tags":["其他"],"totalStock":26,"branch":{"main":3,"branch-001":8,"branch-002":8,"branch-003":7}}'::jsonb),
  ('P010', '{"id":"P010","rentalId":null,"rentalEnabled":false,"name":"保溫壺 1L","category":"其他","brand":"Yuruicamp","interestTags":["safety"],"price":880,"status":"inactive","image":"/assets/images/products/P010-1.jpg","images":["/assets/images/products/P010-1.jpg","/assets/images/products/P010-2.jpg","/assets/images/products/P010-3.jpg"],"description":"<p><strong>保溫壺 1L</strong> 為 Yuruicamp 精選的其他商品，規格：<em>消光黑</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{},"variants":[{"id":"v-P010-0","color":"消光黑","size":"","label":"消光黑","branch":{"main":1,"branch-001":0,"branch-002":0,"branch-003":0}}],"tags":["其他"],"totalStock":1,"branch":{"main":1,"branch-001":0,"branch-002":0,"branch-003":0}}'::jsonb),
  ('P011', '{"id":"P011","rentalId":"R003","rentalEnabled":true,"name":"Snow Peak 客廳帳","category":"帳篷","brand":"Snow Peak","interestTags":["tent"],"price":8500,"status":"active","image":"/assets/images/products/P011-1.jpg","images":["/assets/images/products/P011-1.jpg","/assets/images/products/P011-2.jpg","/assets/images/products/P011-3.jpg"],"description":"<p><strong>Snow Peak 客廳帳</strong> 為 Yuruicamp 精選的帳篷商品，規格：<em>象牙白</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{},"variants":[{"id":"v-P011-0","color":"象牙白","size":"","label":"象牙白","branch":{"main":1,"branch-001":7,"branch-002":2,"branch-003":0}}],"tags":["帳篷","Snow Peak"],"totalStock":10,"branch":{"main":1,"branch-001":7,"branch-002":2,"branch-003":0}}'::jsonb),
  ('P012', '{"id":"P012","rentalId":"R004","rentalEnabled":true,"name":"四季保暖睡袋","category":"睡袋","brand":"Yuruicamp","interestTags":["safety"],"price":2200,"status":"active","image":"/assets/images/products/P012-1.jpg","images":["/assets/images/products/P012-1.jpg","/assets/images/products/P012-2.jpg","/assets/images/products/P012-3.jpg"],"description":"<p><strong>四季保暖睡袋</strong> 為 Yuruicamp 精選的睡袋商品，提供 <em>M / L</em> 兩種尺寸（深藍）。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{"weight":"1.5 kg","material":"合成纖維","capacity":"單人"},"variants":[{"id":"v-P012-0","color":"深藍","size":"M","label":"深藍 / M","branch":{"main":1,"branch-001":3,"branch-002":3,"branch-003":4}},{"id":"v-P012-1","color":"深藍","size":"L","label":"深藍 / L","branch":{"main":0,"branch-001":3,"branch-002":3,"branch-003":4}}],"tags":["睡袋"],"totalStock":21,"branch":{"main":1,"branch-001":6,"branch-002":6,"branch-003":8}}'::jsonb),
  ('P013', '{"id":"P013","rentalId":"R009","rentalEnabled":true,"name":"折疊蛋捲桌","category":"其他","brand":"Yuruicamp","interestTags":["safety"],"price":1500,"status":"active","image":"/assets/images/products/P013-1.jpg","images":["/assets/images/products/P013-1.jpg","/assets/images/products/P013-2.jpg","/assets/images/products/P013-3.jpg"],"description":"<p><strong>折疊蛋捲桌</strong> 為 Yuruicamp 精選的其他商品，規格：<em>胡桃木紋</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{},"variants":[{"id":"v-P013-0","color":"胡桃木紋","size":"","label":"胡桃木紋","branch":{"main":2,"branch-001":5,"branch-002":2,"branch-003":0}}],"tags":["其他"],"totalStock":9,"branch":{"main":2,"branch-001":5,"branch-002":2,"branch-003":0}}'::jsonb),
  ('P014', '{"id":"P014","rentalId":"R010","rentalEnabled":true,"name":"高背月亮椅","category":"其他","brand":"Yuruicamp","interestTags":["safety"],"price":980,"status":"active","image":"/assets/images/products/P014-1.jpg","images":["/assets/images/products/P014-1.jpg","/assets/images/products/P014-2.jpg","/assets/images/products/P014-3.jpg"],"description":"<p><strong>高背月亮椅</strong> 為 Yuruicamp 精選的其他商品，規格：<em>軍綠</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{},"variants":[{"id":"v-P014-0","color":"軍綠","size":"","label":"軍綠","branch":{"main":2,"branch-001":4,"branch-002":4,"branch-003":5}}],"tags":["其他"],"totalStock":15,"branch":{"main":2,"branch-001":4,"branch-002":4,"branch-003":5}}'::jsonb),
  ('P015', '{"id":"P015","rentalId":"R012","rentalEnabled":true,"name":"充電式頭燈","category":"燈具","brand":"Yuruicamp","interestTags":["safety"],"price":650,"status":"active","image":"/assets/images/products/P015-1.jpg","images":["/assets/images/products/P015-1.jpg","/assets/images/products/P015-2.jpg","/assets/images/products/P015-3.jpg"],"description":"<p><strong>充電式頭燈</strong> 為 Yuruicamp 精選的燈具商品，規格：<em>USB-C</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{},"variants":[{"id":"v-P015-0","color":"USB-C","size":"","label":"USB-C","branch":{"main":1,"branch-001":8,"branch-002":0,"branch-003":3}}],"tags":["燈具"],"totalStock":12,"branch":{"main":1,"branch-001":8,"branch-002":0,"branch-003":3}}'::jsonb),
  ('P016', '{"id":"P016","rentalId":"R014","rentalEnabled":true,"name":"65L 重裝背包","category":"背包","brand":"Yuruicamp","interestTags":["backpack"],"price":4200,"status":"active","image":"/assets/images/products/P016-1.jpg","images":["/assets/images/products/P016-1.jpg","/assets/images/products/P016-2.jpg","/assets/images/products/P016-3.jpg"],"description":"<p><strong>65L 重裝背包</strong> 為 Yuruicamp 精選的背包商品，規格：<em>岩石灰</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{},"variants":[{"id":"v-P016-0","color":"岩石灰","size":"","label":"岩石灰","branch":{"main":3,"branch-001":1,"branch-002":8,"branch-003":0}}],"tags":["背包"],"totalStock":12,"branch":{"main":3,"branch-001":1,"branch-002":8,"branch-003":0}}'::jsonb),
  ('P017', '{"id":"P017","rentalId":"R015","rentalEnabled":true,"name":"露營拖車","category":"其他","brand":"Yuruicamp","interestTags":["safety"],"price":3600,"status":"active","image":"/assets/images/products/P017-1.jpg","images":["/assets/images/products/P017-1.jpg","/assets/images/products/P017-2.jpg","/assets/images/products/P017-3.jpg"],"description":"<p><strong>露營拖車</strong> 為 Yuruicamp 精選的其他商品，規格：<em>折疊式</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{},"variants":[{"id":"v-P017-0","color":"折疊式","size":"","label":"折疊式","branch":{"main":3,"branch-001":3,"branch-002":1,"branch-003":4}}],"tags":["其他"],"totalStock":11,"branch":{"main":3,"branch-001":3,"branch-002":1,"branch-003":4}}'::jsonb),
  ('P018', '{"id":"P018","rentalId":"R016","rentalEnabled":true,"name":"大型天幕","category":"帳篷","brand":"Yuruicamp","interestTags":["tent"],"price":2400,"status":"active","image":"/assets/images/products/P018-1.jpg","images":["/assets/images/products/P018-1.jpg","/assets/images/products/P018-2.jpg","/assets/images/products/P018-3.jpg"],"description":"<p><strong>大型天幕</strong> 為 Yuruicamp 精選的帳篷商品，規格：<em>4x4m</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{},"variants":[{"id":"v-P018-0","color":"4x4m","size":"","label":"4x4m","branch":{"main":3,"branch-001":5,"branch-002":6,"branch-003":4}}],"tags":["帳篷"],"totalStock":18,"branch":{"main":3,"branch-001":5,"branch-002":6,"branch-003":4}}'::jsonb),
  ('P019', '{"id":"P019","rentalId":"R017","rentalEnabled":true,"name":"營柱與營繩組","category":"其他","brand":"Yuruicamp","interestTags":["safety"],"price":450,"status":"active","image":"/assets/images/products/P019-1.jpg","images":["/assets/images/products/P019-1.jpg","/assets/images/products/P019-2.jpg","/assets/images/products/P019-3.jpg"],"description":"<p><strong>營柱與營繩組</strong> 為 Yuruicamp 精選的其他商品，規格：<em>標準套組</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{},"variants":[{"id":"v-P019-0","color":"標準套組","size":"","label":"標準套組","branch":{"main":2,"branch-001":1,"branch-002":3,"branch-003":4}}],"tags":["其他"],"totalStock":10,"branch":{"main":2,"branch-001":1,"branch-002":3,"branch-003":4}}'::jsonb),
  ('P020', '{"id":"P020","rentalId":"R019","rentalEnabled":true,"name":"行動電源站","category":"其他","brand":"Yuruicamp","interestTags":["safety"],"price":12800,"status":"active","image":"/assets/images/products/P020-1.jpg","images":["/assets/images/products/P020-1.jpg","/assets/images/products/P020-2.jpg","/assets/images/products/P020-3.jpg"],"description":"<p><strong>行動電源站</strong> 為 Yuruicamp 精選的其他商品，規格：<em>500Wh</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{},"variants":[{"id":"v-P020-0","color":"500Wh","size":"","label":"500Wh","branch":{"main":3,"branch-001":0,"branch-002":8,"branch-003":5}}],"tags":["其他"],"totalStock":16,"branch":{"main":3,"branch-001":0,"branch-002":8,"branch-003":5}}'::jsonb),
  ('P021', '{"id":"P021","rentalId":"R020","rentalEnabled":true,"name":"保冷冰桶 45L","category":"其他","brand":"Yuruicamp","interestTags":["safety"],"price":1900,"status":"active","image":"/assets/images/products/P021-1.jpg","images":["/assets/images/products/P021-1.jpg","/assets/images/products/P021-2.jpg","/assets/images/products/P021-3.jpg"],"description":"<p><strong>保冷冰桶 45L</strong> 為 Yuruicamp 精選的其他商品，規格：<em>深藍</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{},"variants":[{"id":"v-P021-0","color":"深藍","size":"","label":"深藍","branch":{"main":1,"branch-001":3,"branch-002":5,"branch-003":3}}],"tags":["其他"],"totalStock":12,"branch":{"main":1,"branch-001":3,"branch-002":5,"branch-003":3}}'::jsonb),
  ('P022', '{"id":"P022","rentalId":"R021","rentalEnabled":true,"name":"雙層防風外套","category":"其他","brand":"Yuruicamp","interestTags":["safety"],"price":3200,"status":"active","image":"/assets/images/products/P022-1.jpg","images":["/assets/images/products/P022-1.jpg","/assets/images/products/P022-2.jpg","/assets/images/products/P022-3.jpg"],"description":"<p><strong>雙層防風外套</strong> 為 Yuruicamp 精選的其他商品，規格：<em>L號</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{},"variants":[{"id":"v-P022-0","color":"L號","size":"","label":"L號","branch":{"main":1,"branch-001":5,"branch-002":6,"branch-003":3}}],"tags":["其他"],"totalStock":15,"branch":{"main":1,"branch-001":5,"branch-002":6,"branch-003":3}}'::jsonb),
  ('P023', '{"id":"P023","rentalId":"R022","rentalEnabled":true,"name":"快煮鍋 1.5L","category":"炊具","brand":"Yuruicamp","interestTags":["cooking"],"price":1100,"status":"active","image":"/assets/images/products/P023-1.jpg","images":["/assets/images/products/P023-1.jpg","/assets/images/products/P023-2.jpg","/assets/images/products/P023-3.jpg"],"description":"<p><strong>快煮鍋 1.5L</strong> 為 Yuruicamp 精選的炊具商品，規格：<em>不鏽鋼</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{},"variants":[{"id":"v-P023-0","color":"不鏽鋼","size":"","label":"不鏽鋼","branch":{"main":1,"branch-001":8,"branch-002":8,"branch-003":8}}],"tags":["炊具"],"totalStock":25,"branch":{"main":1,"branch-001":8,"branch-002":8,"branch-003":8}}'::jsonb),
  ('P024', '{"id":"P024","rentalId":"R023","rentalEnabled":true,"name":"碳纖維登山杖","category":"其他","brand":"Yuruicamp","interestTags":["safety"],"price":1400,"status":"active","image":"/assets/images/products/P024-1.jpg","images":["/assets/images/products/P024-1.jpg","/assets/images/products/P024-2.jpg","/assets/images/products/P024-3.jpg"],"description":"<p><strong>碳纖維登山杖</strong> 為 Yuruicamp 精選的其他商品，規格：<em>一對</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{},"variants":[{"id":"v-P024-0","color":"一對","size":"","label":"一對","branch":{"main":3,"branch-001":0,"branch-002":8,"branch-003":4}}],"tags":["其他"],"totalStock":15,"branch":{"main":3,"branch-001":0,"branch-002":8,"branch-003":4}}'::jsonb),
  ('P025', '{"id":"P025","rentalId":"R024","rentalEnabled":true,"name":"防水戶外手錶","category":"其他","brand":"Yuruicamp","interestTags":["safety"],"price":5600,"status":"active","image":"/assets/images/products/P025-1.jpg","images":["/assets/images/products/P025-1.jpg","/assets/images/products/P025-2.jpg","/assets/images/products/P025-3.jpg"],"description":"<p><strong>防水戶外手錶</strong> 為 Yuruicamp 精選的其他商品，規格：<em>GPS版</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{},"variants":[{"id":"v-P025-0","color":"GPS版","size":"","label":"GPS版","branch":{"main":2,"branch-001":7,"branch-002":3,"branch-003":1}}],"tags":["其他"],"totalStock":13,"branch":{"main":2,"branch-001":7,"branch-002":3,"branch-003":1}}'::jsonb),
  ('P026', '{"id":"P026","rentalId":"R025","rentalEnabled":true,"name":"輕量吊床","category":"其他","brand":"Yuruicamp","interestTags":["safety"],"price":890,"status":"active","image":"/assets/images/products/P026-1.jpg","images":["/assets/images/products/P026-1.jpg","/assets/images/products/P026-2.jpg","/assets/images/products/P026-3.jpg"],"description":"<p><strong>輕量吊床</strong> 為 Yuruicamp 精選的其他商品，規格：<em>雙人</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{},"variants":[{"id":"v-P026-0","color":"雙人","size":"","label":"雙人","branch":{"main":2,"branch-001":1,"branch-002":2,"branch-003":4}}],"tags":["其他"],"totalStock":9,"branch":{"main":2,"branch-001":1,"branch-002":2,"branch-003":4}}'::jsonb),
  ('P027', '{"id":"P027","rentalId":"R026","rentalEnabled":true,"name":"戶外淋浴袋","category":"其他","brand":"Yuruicamp","interestTags":["safety"],"price":680,"status":"active","image":"/assets/images/products/P027-1.jpg","images":["/assets/images/products/P027-1.jpg","/assets/images/products/P027-2.jpg","/assets/images/products/P027-3.jpg"],"description":"<p><strong>戶外淋浴袋</strong> 為 Yuruicamp 精選的其他商品，規格：<em>20L</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{},"variants":[{"id":"v-P027-0","color":"20L","size":"","label":"20L","branch":{"main":2,"branch-001":0,"branch-002":6,"branch-003":7}}],"tags":["其他"],"totalStock":15,"branch":{"main":2,"branch-001":0,"branch-002":6,"branch-003":7}}'::jsonb),
  ('P028', '{"id":"P028","rentalId":"R027","rentalEnabled":true,"name":"折疊式焚火台","category":"炊具","brand":"Yuruicamp","interestTags":["cooking"],"price":2100,"status":"active","image":"/assets/images/products/P028-1.jpg","images":["/assets/images/products/P028-1.jpg","/assets/images/products/P028-2.jpg","/assets/images/products/P028-3.jpg"],"description":"<p><strong>折疊式焚火台</strong> 為 Yuruicamp 精選的炊具商品，規格：<em>不鏽鋼</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{},"variants":[{"id":"v-P028-0","color":"不鏽鋼","size":"","label":"不鏽鋼","branch":{"main":3,"branch-001":6,"branch-002":8,"branch-003":7}}],"tags":["炊具"],"totalStock":24,"branch":{"main":3,"branch-001":6,"branch-002":8,"branch-003":7}}'::jsonb),
  ('P029', '{"id":"P029","rentalId":"R028","rentalEnabled":true,"name":"防蚊帳篷內帳","category":"帳篷","brand":"Yuruicamp","interestTags":["tent"],"price":750,"status":"active","image":"/assets/images/products/P029-1.jpg","images":["/assets/images/products/P029-1.jpg","/assets/images/products/P029-2.jpg","/assets/images/products/P029-3.jpg"],"description":"<p><strong>防蚊帳篷內帳</strong> 為 Yuruicamp 精選的帳篷商品，規格：<em>通用型</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{},"variants":[{"id":"v-P029-0","color":"通用型","size":"","label":"通用型","branch":{"main":2,"branch-001":5,"branch-002":6,"branch-003":1}}],"tags":["帳篷"],"totalStock":14,"branch":{"main":2,"branch-001":5,"branch-002":6,"branch-003":1}}'::jsonb),
  ('P030', '{"id":"P030","rentalId":null,"rentalEnabled":false,"name":"露營貼紙組","category":"其他","brand":"Yuruicamp","interestTags":["safety"],"price":199,"status":"inactive","image":"/assets/images/products/P030-1.jpg","images":["/assets/images/products/P030-1.jpg","/assets/images/products/P030-2.jpg","/assets/images/products/P030-3.jpg"],"description":"<p><strong>露營貼紙組</strong> 為 Yuruicamp 精選的其他商品，規格：<em>50入</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>","specifications":{},"variants":[{"id":"v-P030-0","color":"50入","size":"","label":"50入","branch":{"main":1,"branch-001":0,"branch-002":0,"branch-003":0}}],"tags":["其他"],"totalStock":1,"branch":{"main":1,"branch-001":0,"branch-002":0,"branch-003":0}}'::jsonb)
ON CONFLICT (product_id) DO NOTHING;

INSERT INTO migration.p2_campground_tag_source (
  campground_id, environment_tags, facility_tags
) VALUES
  ('C002', '["高海拔","有雲海","森林系"]'::jsonb, '["獨立衛浴","裝備租借","有雨棚"]'::jsonb),
  ('C003', '["低海拔","有溪流","森林系"]'::jsonb, '["兒童遊樂設施","寵物友善","裝備租借"]'::jsonb),
  ('C004', '["高海拔","森林系"]'::jsonb, '["小木屋","獨立衛浴","可包區"]'::jsonb),
  ('C005', '["低海拔"]'::jsonb, '["寵物友善","裝備租借"]'::jsonb),
  ('C006', '["低海拔","有溪流"]'::jsonb, '["獨立衛浴","有雨棚","裝備租借"]'::jsonb),
  ('C007', '["高海拔","有雲海","森林系"]'::jsonb, '["有雨棚","裝備租借","獨立衛浴"]'::jsonb),
  ('C008', '["低海拔","有溪流"]'::jsonb, '["獨立衛浴","可包區","寵物友善","裝備租借"]'::jsonb),
  ('C009', '["高海拔","有溪流","森林系"]'::jsonb, '["裝備租借","兒童遊樂設施","有雨棚"]'::jsonb)
ON CONFLICT (campground_id) DO NOTHING;

UPDATE campgrounds campground
SET environment_tags = source.environment_tags,
    facility_tags = source.facility_tags
FROM (VALUES
  ('C002', '["高海拔","有雲海","森林系"]'::jsonb, '["獨立衛浴","裝備租借","有雨棚"]'::jsonb),
  ('C003', '["低海拔","有溪流","森林系"]'::jsonb, '["兒童遊樂設施","寵物友善","裝備租借"]'::jsonb),
  ('C004', '["高海拔","森林系"]'::jsonb, '["小木屋","獨立衛浴","可包區"]'::jsonb),
  ('C005', '["低海拔"]'::jsonb, '["寵物友善","裝備租借"]'::jsonb),
  ('C006', '["低海拔","有溪流"]'::jsonb, '["獨立衛浴","有雨棚","裝備租借"]'::jsonb),
  ('C007', '["高海拔","有雲海","森林系"]'::jsonb, '["有雨棚","裝備租借","獨立衛浴"]'::jsonb),
  ('C008', '["低海拔","有溪流"]'::jsonb, '["獨立衛浴","可包區","寵物友善","裝備租借"]'::jsonb),
  ('C009', '["高海拔","有溪流","森林系"]'::jsonb, '["裝備租借","兒童遊樂設施","有雨棚"]'::jsonb)
) source(campground_id, environment_tags, facility_tags)
WHERE campground.id = source.campground_id;

INSERT INTO products (
  id, rental_id, rental_enabled, name, category, brand, interest_tags, price, status,
  image, images, description, specifications, tags, total_stock, item_id
) VALUES
  ('P001', NULL, TRUE, 'Coleman 六人帳篷', '帳篷', 'Coleman', '["tent"]'::jsonb, 3200, 'active', '/assets/images/products/P001-1.jpg', '["/assets/images/products/P001-1.jpg","/assets/images/products/P001-2.jpg","/assets/images/products/P001-3.jpg"]'::jsonb, '<p><strong>Coleman 六人帳篷</strong> 為 Yuruicamp 精選的帳篷商品，提供 <em>深橄欖綠</em>、<em>沙漠棕</em>、<em>太空灰</em> 三色可選。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{"weight":"4.2 kg","capacity":"6 人","material":"聚酯纖維","waterproof":"3000mm"}'::jsonb, '["帳篷","Coleman"]'::jsonb, 5, 'P001'),
  ('P002', NULL, TRUE, 'MSR 超輕量帳篷', '帳篷', 'MSR', '["tent"]'::jsonb, 9800, 'active', '/assets/images/products/P002-1.jpg', '["/assets/images/products/P002-1.jpg","/assets/images/products/P002-2.jpg","/assets/images/products/P002-3.jpg"]'::jsonb, '<p><strong>MSR 超輕量帳篷</strong> 為 Yuruicamp 精選的帳篷商品，規格：<em>沙漠卡其</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{}'::jsonb, '["帳篷","MSR"]'::jsonb, 14, 'P002'),
  ('P003', NULL, TRUE, '充氣式睡墊', '睡袋', 'Yuruicamp', '["safety"]'::jsonb, 1200, 'active', '/assets/images/products/P003-1.jpg', '["/assets/images/products/P003-1.jpg","/assets/images/products/P003-2.jpg","/assets/images/products/P003-3.jpg"]'::jsonb, '<p><strong>充氣式睡墊</strong> 為 Yuruicamp 精選的睡袋商品，提供 <em>S / M / L</em> 三種尺寸。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{"weight":"0.8 kg","material":"TPU 充氣層","capacity":"單人"}'::jsonb, '["睡袋"]'::jsonb, 15, 'P003'),
  ('P004', NULL, TRUE, '羽絨睡袋', '睡袋', 'Yuruicamp', '["safety"]'::jsonb, 2800, 'active', '/assets/images/products/P004-1.jpg', '["/assets/images/products/P004-1.jpg","/assets/images/products/P004-2.jpg","/assets/images/products/P004-3.jpg"]'::jsonb, '<p><strong>羽絨睡袋</strong> 為 Yuruicamp 精選的睡袋商品，提供 <em>-10°C / -5°C / 0°C</em> 三種溫標可選。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{"weight":"1.2 kg","material":"90% 羽絨","capacity":"單人"}'::jsonb, '["睡袋"]'::jsonb, 11, 'P004'),
  ('P005', NULL, TRUE, 'Coleman 氣化爐', '炊具', 'Coleman', '["cooking"]'::jsonb, 5000, 'active', '/assets/images/products/P005-1.jpg', '["/assets/images/products/P005-1.jpg","/assets/images/products/P005-2.jpg","/assets/images/products/P005-3.jpg"]'::jsonb, '<p><strong>Coleman 氣化爐</strong> 為 Yuruicamp 精選的炊具商品，規格：<em>標準版</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{}'::jsonb, '["炊具","Coleman"]'::jsonb, 11, 'P005'),
  ('P006', NULL, TRUE, 'Snow Peak 鈦合金杯組', '炊具', 'Snow Peak', '["cooking"]'::jsonb, 1800, 'active', '/assets/images/products/P006-1.jpg', '["/assets/images/products/P006-1.jpg","/assets/images/products/P006-2.jpg","/assets/images/products/P006-3.jpg"]'::jsonb, '<p><strong>Snow Peak 鈦合金杯組</strong> 為 Yuruicamp 精選的炊具商品，規格：<em>鈦金屬原色</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{}'::jsonb, '["炊具","Snow Peak"]'::jsonb, 10, 'P006'),
  ('P007', NULL, TRUE, 'LED 露營燈', '燈具', 'Yuruicamp', '["safety"]'::jsonb, 800, 'active', '/assets/images/products/P007-1.jpg', '["/assets/images/products/P007-1.jpg","/assets/images/products/P007-2.jpg","/assets/images/products/P007-3.jpg"]'::jsonb, '<p><strong>LED 露營燈</strong> 為 Yuruicamp 精選的燈具商品，提供 <em>暖白光</em>、<em>冷白光</em> 兩種色溫。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{"lumens":"300 lm","batteryLife":"約 40 小時","power":"USB 充電"}'::jsonb, '["燈具"]'::jsonb, 14, 'P007'),
  ('P008', NULL, TRUE, '防水登山背包', '背包', 'Yuruicamp', '["backpack"]'::jsonb, 1600, 'active', '/assets/images/products/P008-1.jpg', '["/assets/images/products/P008-1.jpg","/assets/images/products/P008-2.jpg","/assets/images/products/P008-3.jpg"]'::jsonb, '<p><strong>防水登山背包</strong> 為 Yuruicamp 精選的背包商品，提供 <em>35L / 45L</em> 兩種容量（森林綠）。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{"weight":"1.1 kg","material":"防潑水尼龍","waterproof":"IPX4"}'::jsonb, '["背包"]'::jsonb, 17, 'P008'),
  ('P009', NULL, TRUE, '折疊桌椅組', '其他', 'Yuruicamp', '["safety"]'::jsonb, 2800, 'active', '/assets/images/products/P009-1.jpg', '["/assets/images/products/P009-1.jpg","/assets/images/products/P009-2.jpg","/assets/images/products/P009-3.jpg"]'::jsonb, '<p><strong>折疊桌椅組</strong> 為 Yuruicamp 精選的其他商品，規格：<em>鋁合金輕量版</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{}'::jsonb, '["其他"]'::jsonb, 26, 'P009'),
  ('P010', NULL, FALSE, '保溫壺 1L', '其他', 'Yuruicamp', '["safety"]'::jsonb, 880, 'inactive', '/assets/images/products/P010-1.jpg', '["/assets/images/products/P010-1.jpg","/assets/images/products/P010-2.jpg","/assets/images/products/P010-3.jpg"]'::jsonb, '<p><strong>保溫壺 1L</strong> 為 Yuruicamp 精選的其他商品，規格：<em>消光黑</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{}'::jsonb, '["其他"]'::jsonb, 1, 'P010'),
  ('P011', NULL, TRUE, 'Snow Peak 客廳帳', '帳篷', 'Snow Peak', '["tent"]'::jsonb, 8500, 'active', '/assets/images/products/P011-1.jpg', '["/assets/images/products/P011-1.jpg","/assets/images/products/P011-2.jpg","/assets/images/products/P011-3.jpg"]'::jsonb, '<p><strong>Snow Peak 客廳帳</strong> 為 Yuruicamp 精選的帳篷商品，規格：<em>象牙白</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{}'::jsonb, '["帳篷","Snow Peak"]'::jsonb, 10, 'P011'),
  ('P012', NULL, TRUE, '四季保暖睡袋', '睡袋', 'Yuruicamp', '["safety"]'::jsonb, 2200, 'active', '/assets/images/products/P012-1.jpg', '["/assets/images/products/P012-1.jpg","/assets/images/products/P012-2.jpg","/assets/images/products/P012-3.jpg"]'::jsonb, '<p><strong>四季保暖睡袋</strong> 為 Yuruicamp 精選的睡袋商品，提供 <em>M / L</em> 兩種尺寸（深藍）。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{"weight":"1.5 kg","material":"合成纖維","capacity":"單人"}'::jsonb, '["睡袋"]'::jsonb, 21, 'P012'),
  ('P013', NULL, TRUE, '折疊蛋捲桌', '其他', 'Yuruicamp', '["safety"]'::jsonb, 1500, 'active', '/assets/images/products/P013-1.jpg', '["/assets/images/products/P013-1.jpg","/assets/images/products/P013-2.jpg","/assets/images/products/P013-3.jpg"]'::jsonb, '<p><strong>折疊蛋捲桌</strong> 為 Yuruicamp 精選的其他商品，規格：<em>胡桃木紋</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{}'::jsonb, '["其他"]'::jsonb, 9, 'P013'),
  ('P014', NULL, TRUE, '高背月亮椅', '其他', 'Yuruicamp', '["safety"]'::jsonb, 980, 'active', '/assets/images/products/P014-1.jpg', '["/assets/images/products/P014-1.jpg","/assets/images/products/P014-2.jpg","/assets/images/products/P014-3.jpg"]'::jsonb, '<p><strong>高背月亮椅</strong> 為 Yuruicamp 精選的其他商品，規格：<em>軍綠</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{}'::jsonb, '["其他"]'::jsonb, 15, 'P014'),
  ('P015', NULL, TRUE, '充電式頭燈', '燈具', 'Yuruicamp', '["safety"]'::jsonb, 650, 'active', '/assets/images/products/P015-1.jpg', '["/assets/images/products/P015-1.jpg","/assets/images/products/P015-2.jpg","/assets/images/products/P015-3.jpg"]'::jsonb, '<p><strong>充電式頭燈</strong> 為 Yuruicamp 精選的燈具商品，規格：<em>USB-C</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{}'::jsonb, '["燈具"]'::jsonb, 12, 'P015'),
  ('P016', NULL, TRUE, '65L 重裝背包', '背包', 'Yuruicamp', '["backpack"]'::jsonb, 4200, 'active', '/assets/images/products/P016-1.jpg', '["/assets/images/products/P016-1.jpg","/assets/images/products/P016-2.jpg","/assets/images/products/P016-3.jpg"]'::jsonb, '<p><strong>65L 重裝背包</strong> 為 Yuruicamp 精選的背包商品，規格：<em>岩石灰</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{}'::jsonb, '["背包"]'::jsonb, 12, 'P016'),
  ('P017', NULL, TRUE, '露營拖車', '其他', 'Yuruicamp', '["safety"]'::jsonb, 3600, 'active', '/assets/images/products/P017-1.jpg', '["/assets/images/products/P017-1.jpg","/assets/images/products/P017-2.jpg","/assets/images/products/P017-3.jpg"]'::jsonb, '<p><strong>露營拖車</strong> 為 Yuruicamp 精選的其他商品，規格：<em>折疊式</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{}'::jsonb, '["其他"]'::jsonb, 11, 'P017'),
  ('P018', NULL, TRUE, '大型天幕', '帳篷', 'Yuruicamp', '["tent"]'::jsonb, 2400, 'active', '/assets/images/products/P018-1.jpg', '["/assets/images/products/P018-1.jpg","/assets/images/products/P018-2.jpg","/assets/images/products/P018-3.jpg"]'::jsonb, '<p><strong>大型天幕</strong> 為 Yuruicamp 精選的帳篷商品，規格：<em>4x4m</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{}'::jsonb, '["帳篷"]'::jsonb, 18, 'P018'),
  ('P019', NULL, TRUE, '營柱與營繩組', '其他', 'Yuruicamp', '["safety"]'::jsonb, 450, 'active', '/assets/images/products/P019-1.jpg', '["/assets/images/products/P019-1.jpg","/assets/images/products/P019-2.jpg","/assets/images/products/P019-3.jpg"]'::jsonb, '<p><strong>營柱與營繩組</strong> 為 Yuruicamp 精選的其他商品，規格：<em>標準套組</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{}'::jsonb, '["其他"]'::jsonb, 10, 'P019'),
  ('P020', NULL, TRUE, '行動電源站', '其他', 'Yuruicamp', '["safety"]'::jsonb, 12800, 'active', '/assets/images/products/P020-1.jpg', '["/assets/images/products/P020-1.jpg","/assets/images/products/P020-2.jpg","/assets/images/products/P020-3.jpg"]'::jsonb, '<p><strong>行動電源站</strong> 為 Yuruicamp 精選的其他商品，規格：<em>500Wh</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{}'::jsonb, '["其他"]'::jsonb, 16, 'P020'),
  ('P021', NULL, TRUE, '保冷冰桶 45L', '其他', 'Yuruicamp', '["safety"]'::jsonb, 1900, 'active', '/assets/images/products/P021-1.jpg', '["/assets/images/products/P021-1.jpg","/assets/images/products/P021-2.jpg","/assets/images/products/P021-3.jpg"]'::jsonb, '<p><strong>保冷冰桶 45L</strong> 為 Yuruicamp 精選的其他商品，規格：<em>深藍</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{}'::jsonb, '["其他"]'::jsonb, 12, 'P021'),
  ('P022', NULL, TRUE, '雙層防風外套', '其他', 'Yuruicamp', '["safety"]'::jsonb, 3200, 'active', '/assets/images/products/P022-1.jpg', '["/assets/images/products/P022-1.jpg","/assets/images/products/P022-2.jpg","/assets/images/products/P022-3.jpg"]'::jsonb, '<p><strong>雙層防風外套</strong> 為 Yuruicamp 精選的其他商品，規格：<em>L號</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{}'::jsonb, '["其他"]'::jsonb, 15, 'P022'),
  ('P023', NULL, TRUE, '快煮鍋 1.5L', '炊具', 'Yuruicamp', '["cooking"]'::jsonb, 1100, 'active', '/assets/images/products/P023-1.jpg', '["/assets/images/products/P023-1.jpg","/assets/images/products/P023-2.jpg","/assets/images/products/P023-3.jpg"]'::jsonb, '<p><strong>快煮鍋 1.5L</strong> 為 Yuruicamp 精選的炊具商品，規格：<em>不鏽鋼</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{}'::jsonb, '["炊具"]'::jsonb, 25, 'P023'),
  ('P024', NULL, TRUE, '碳纖維登山杖', '其他', 'Yuruicamp', '["safety"]'::jsonb, 1400, 'active', '/assets/images/products/P024-1.jpg', '["/assets/images/products/P024-1.jpg","/assets/images/products/P024-2.jpg","/assets/images/products/P024-3.jpg"]'::jsonb, '<p><strong>碳纖維登山杖</strong> 為 Yuruicamp 精選的其他商品，規格：<em>一對</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{}'::jsonb, '["其他"]'::jsonb, 15, 'P024'),
  ('P025', NULL, TRUE, '防水戶外手錶', '其他', 'Yuruicamp', '["safety"]'::jsonb, 5600, 'active', '/assets/images/products/P025-1.jpg', '["/assets/images/products/P025-1.jpg","/assets/images/products/P025-2.jpg","/assets/images/products/P025-3.jpg"]'::jsonb, '<p><strong>防水戶外手錶</strong> 為 Yuruicamp 精選的其他商品，規格：<em>GPS版</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{}'::jsonb, '["其他"]'::jsonb, 13, 'P025'),
  ('P026', NULL, TRUE, '輕量吊床', '其他', 'Yuruicamp', '["safety"]'::jsonb, 890, 'active', '/assets/images/products/P026-1.jpg', '["/assets/images/products/P026-1.jpg","/assets/images/products/P026-2.jpg","/assets/images/products/P026-3.jpg"]'::jsonb, '<p><strong>輕量吊床</strong> 為 Yuruicamp 精選的其他商品，規格：<em>雙人</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{}'::jsonb, '["其他"]'::jsonb, 9, 'P026'),
  ('P027', NULL, TRUE, '戶外淋浴袋', '其他', 'Yuruicamp', '["safety"]'::jsonb, 680, 'active', '/assets/images/products/P027-1.jpg', '["/assets/images/products/P027-1.jpg","/assets/images/products/P027-2.jpg","/assets/images/products/P027-3.jpg"]'::jsonb, '<p><strong>戶外淋浴袋</strong> 為 Yuruicamp 精選的其他商品，規格：<em>20L</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{}'::jsonb, '["其他"]'::jsonb, 15, 'P027'),
  ('P028', NULL, TRUE, '折疊式焚火台', '炊具', 'Yuruicamp', '["cooking"]'::jsonb, 2100, 'active', '/assets/images/products/P028-1.jpg', '["/assets/images/products/P028-1.jpg","/assets/images/products/P028-2.jpg","/assets/images/products/P028-3.jpg"]'::jsonb, '<p><strong>折疊式焚火台</strong> 為 Yuruicamp 精選的炊具商品，規格：<em>不鏽鋼</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{}'::jsonb, '["炊具"]'::jsonb, 24, 'P028'),
  ('P029', NULL, TRUE, '防蚊帳篷內帳', '帳篷', 'Yuruicamp', '["tent"]'::jsonb, 750, 'active', '/assets/images/products/P029-1.jpg', '["/assets/images/products/P029-1.jpg","/assets/images/products/P029-2.jpg","/assets/images/products/P029-3.jpg"]'::jsonb, '<p><strong>防蚊帳篷內帳</strong> 為 Yuruicamp 精選的帳篷商品，規格：<em>通用型</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{}'::jsonb, '["帳篷"]'::jsonb, 14, 'P029'),
  ('P030', NULL, FALSE, '露營貼紙組', '其他', 'Yuruicamp', '["safety"]'::jsonb, 199, 'inactive', '/assets/images/products/P030-1.jpg', '["/assets/images/products/P030-1.jpg","/assets/images/products/P030-2.jpg","/assets/images/products/P030-3.jpg"]'::jsonb, '<p><strong>露營貼紙組</strong> 為 Yuruicamp 精選的其他商品，規格：<em>50入</em>。</p><p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>', '{}'::jsonb, '["其他"]'::jsonb, 1, 'P030')
ON CONFLICT (id) DO NOTHING;

INSERT INTO product_variants (
  id, product_id, sku, color, size, label, price, branch_stock, specification, status
) VALUES
  ('v-P001-0', 'P001', 'v-P001-0', '深橄欖綠', NULL, '深橄欖綠', 3200, '{"main":2,"branch-001":1,"branch-002":0,"branch-003":0}'::jsonb, '深橄欖綠', 'active'),
  ('v-P001-1', 'P001', 'v-P001-1', '沙漠棕', NULL, '沙漠棕', 3200, '{"main":0,"branch-001":1,"branch-002":0,"branch-003":1}'::jsonb, '沙漠棕', 'active'),
  ('v-P001-2', 'P001', 'v-P001-2', '太空灰', NULL, '太空灰', 3200, '{"main":0,"branch-001":0,"branch-002":0,"branch-003":0}'::jsonb, '太空灰', 'active'),
  ('v-P002-0', 'P002', 'v-P002-0', '沙漠卡其', NULL, '沙漠卡其', 9800, '{"main":2,"branch-001":7,"branch-002":4,"branch-003":1}'::jsonb, '沙漠卡其', 'active'),
  ('v-P003-0', 'P003', 'v-P003-0', NULL, 'S', 'S', 1200, '{"main":1,"branch-001":3,"branch-002":1,"branch-003":1}'::jsonb, 'S', 'active'),
  ('v-P003-1', 'P003', 'v-P003-1', NULL, 'M', 'M', 1200, '{"main":1,"branch-001":3,"branch-002":1,"branch-003":1}'::jsonb, 'M', 'active'),
  ('v-P003-2', 'P003', 'v-P003-2', NULL, 'L', 'L', 1200, '{"main":0,"branch-001":2,"branch-002":0,"branch-003":1}'::jsonb, 'L', 'active'),
  ('v-P004-0', 'P004', 'v-P004-0', NULL, '-10°C', '-10°C', 2800, '{"main":1,"branch-001":3,"branch-002":2,"branch-003":0}'::jsonb, '-10°C', 'active'),
  ('v-P004-1', 'P004', 'v-P004-1', NULL, '-5°C', '-5°C', 2800, '{"main":1,"branch-001":2,"branch-002":1,"branch-003":0}'::jsonb, '-5°C', 'active'),
  ('v-P004-2', 'P004', 'v-P004-2', NULL, '0°C', '0°C', 2800, '{"main":0,"branch-001":1,"branch-002":0,"branch-003":0}'::jsonb, '0°C', 'active'),
  ('v-P005-0', 'P005', 'v-P005-0', '標準版', NULL, '標準版', 5000, '{"main":3,"branch-001":0,"branch-002":2,"branch-003":6}'::jsonb, '標準版', 'active'),
  ('v-P006-0', 'P006', 'v-P006-0', '鈦金屬原色', NULL, '鈦金屬原色', 1800, '{"main":2,"branch-001":1,"branch-002":2,"branch-003":5}'::jsonb, '鈦金屬原色', 'active'),
  ('v-P007-0', 'P007', 'v-P007-0', '暖白光', NULL, '暖白光', 800, '{"main":1,"branch-001":2,"branch-002":2,"branch-003":2}'::jsonb, '暖白光', 'active'),
  ('v-P007-1', 'P007', 'v-P007-1', '冷白光', NULL, '冷白光', 800, '{"main":1,"branch-001":2,"branch-002":2,"branch-003":2}'::jsonb, '冷白光', 'active'),
  ('v-P008-0', 'P008', 'v-P008-0', '森林綠', '35L', '森林綠 / 35L', 1600, '{"main":1,"branch-001":2,"branch-002":2,"branch-003":3}'::jsonb, '森林綠 / 35L', 'active'),
  ('v-P008-1', 'P008', 'v-P008-1', '森林綠', '45L', '森林綠 / 45L', 1600, '{"main":1,"branch-001":2,"branch-002":3,"branch-003":3}'::jsonb, '森林綠 / 45L', 'active'),
  ('v-P009-0', 'P009', 'v-P009-0', '鋁合金輕量版', NULL, '鋁合金輕量版', 2800, '{"main":3,"branch-001":8,"branch-002":8,"branch-003":7}'::jsonb, '鋁合金輕量版', 'active'),
  ('v-P010-0', 'P010', 'v-P010-0', '消光黑', NULL, '消光黑', 880, '{"main":1,"branch-001":0,"branch-002":0,"branch-003":0}'::jsonb, '消光黑', 'inactive'),
  ('v-P011-0', 'P011', 'v-P011-0', '象牙白', NULL, '象牙白', 8500, '{"main":1,"branch-001":7,"branch-002":2,"branch-003":0}'::jsonb, '象牙白', 'active'),
  ('v-P012-0', 'P012', 'v-P012-0', '深藍', 'M', '深藍 / M', 2200, '{"main":1,"branch-001":3,"branch-002":3,"branch-003":4}'::jsonb, '深藍 / M', 'active'),
  ('v-P012-1', 'P012', 'v-P012-1', '深藍', 'L', '深藍 / L', 2200, '{"main":0,"branch-001":3,"branch-002":3,"branch-003":4}'::jsonb, '深藍 / L', 'active'),
  ('v-P013-0', 'P013', 'v-P013-0', '胡桃木紋', NULL, '胡桃木紋', 1500, '{"main":2,"branch-001":5,"branch-002":2,"branch-003":0}'::jsonb, '胡桃木紋', 'active'),
  ('v-P014-0', 'P014', 'v-P014-0', '軍綠', NULL, '軍綠', 980, '{"main":2,"branch-001":4,"branch-002":4,"branch-003":5}'::jsonb, '軍綠', 'active'),
  ('v-P015-0', 'P015', 'v-P015-0', 'USB-C', NULL, 'USB-C', 650, '{"main":1,"branch-001":8,"branch-002":0,"branch-003":3}'::jsonb, 'USB-C', 'active'),
  ('v-P016-0', 'P016', 'v-P016-0', '岩石灰', NULL, '岩石灰', 4200, '{"main":3,"branch-001":1,"branch-002":8,"branch-003":0}'::jsonb, '岩石灰', 'active'),
  ('v-P017-0', 'P017', 'v-P017-0', '折疊式', NULL, '折疊式', 3600, '{"main":3,"branch-001":3,"branch-002":1,"branch-003":4}'::jsonb, '折疊式', 'active'),
  ('v-P018-0', 'P018', 'v-P018-0', '4x4m', NULL, '4x4m', 2400, '{"main":3,"branch-001":5,"branch-002":6,"branch-003":4}'::jsonb, '4x4m', 'active'),
  ('v-P019-0', 'P019', 'v-P019-0', '標準套組', NULL, '標準套組', 450, '{"main":2,"branch-001":1,"branch-002":3,"branch-003":4}'::jsonb, '標準套組', 'active'),
  ('v-P020-0', 'P020', 'v-P020-0', '500Wh', NULL, '500Wh', 12800, '{"main":3,"branch-001":0,"branch-002":8,"branch-003":5}'::jsonb, '500Wh', 'active'),
  ('v-P021-0', 'P021', 'v-P021-0', '深藍', NULL, '深藍', 1900, '{"main":1,"branch-001":3,"branch-002":5,"branch-003":3}'::jsonb, '深藍', 'active'),
  ('v-P022-0', 'P022', 'v-P022-0', 'L號', NULL, 'L號', 3200, '{"main":1,"branch-001":5,"branch-002":6,"branch-003":3}'::jsonb, 'L號', 'active'),
  ('v-P023-0', 'P023', 'v-P023-0', '不鏽鋼', NULL, '不鏽鋼', 1100, '{"main":1,"branch-001":8,"branch-002":8,"branch-003":8}'::jsonb, '不鏽鋼', 'active'),
  ('v-P024-0', 'P024', 'v-P024-0', '一對', NULL, '一對', 1400, '{"main":3,"branch-001":0,"branch-002":8,"branch-003":4}'::jsonb, '一對', 'active'),
  ('v-P025-0', 'P025', 'v-P025-0', 'GPS版', NULL, 'GPS版', 5600, '{"main":2,"branch-001":7,"branch-002":3,"branch-003":1}'::jsonb, 'GPS版', 'active'),
  ('v-P026-0', 'P026', 'v-P026-0', '雙人', NULL, '雙人', 890, '{"main":2,"branch-001":1,"branch-002":2,"branch-003":4}'::jsonb, '雙人', 'active'),
  ('v-P027-0', 'P027', 'v-P027-0', '20L', NULL, '20L', 680, '{"main":2,"branch-001":0,"branch-002":6,"branch-003":7}'::jsonb, '20L', 'active'),
  ('v-P028-0', 'P028', 'v-P028-0', '不鏽鋼', NULL, '不鏽鋼', 2100, '{"main":3,"branch-001":6,"branch-002":8,"branch-003":7}'::jsonb, '不鏽鋼', 'active'),
  ('v-P029-0', 'P029', 'v-P029-0', '通用型', NULL, '通用型', 750, '{"main":2,"branch-001":5,"branch-002":6,"branch-003":1}'::jsonb, '通用型', 'active'),
  ('v-P030-0', 'P030', 'v-P030-0', '50入', NULL, '50入', 199, '{"main":1,"branch-001":0,"branch-002":0,"branch-003":0}'::jsonb, '50入', 'inactive')
ON CONFLICT (id) DO NOTHING;

INSERT INTO equipment_items (
  id, category_id, brand_id, name, main_image_url, description, active
)
SELECT product.id, category.id, brand.id, product.name, product.image,
       product.description, product.status::text = 'active'
FROM products product
JOIN product_categories category ON category.name = product.category
JOIN brands brand ON brand.name = product.brand
ON CONFLICT (id) DO NOTHING;

UPDATE products product
SET item_id = product.id
WHERE EXISTS (SELECT 1 FROM equipment_items item WHERE item.id = product.id);

INSERT INTO equipment_images (item_id, sort_order, url)
SELECT product.id, image.ordinality::integer - 1, image.url
FROM products product
CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(product.images, '[]'::jsonb))
  WITH ORDINALITY AS image(url, ordinality)
WHERE BTRIM(image.url) <> ''
ON CONFLICT DO NOTHING;

INSERT INTO equipment_tags (item_id, tag)
SELECT product.id, tag.value
FROM products product
CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(product.tags, '[]'::jsonb)) tag(value)
WHERE BTRIM(tag.value) <> ''
ON CONFLICT DO NOTHING;

INSERT INTO equipment_interest_tags (item_id, tag)
SELECT product.id, tag.value
FROM products product
CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(product.interest_tags, '[]'::jsonb)) tag(value)
WHERE BTRIM(tag.value) <> ''
ON CONFLICT DO NOTHING;

INSERT INTO equipment_specifications (item_id, spec_key, value)
SELECT product.id, specification.spec_key, specification.value
FROM products product
CROSS JOIN LATERAL jsonb_each_text(COALESCE(product.specifications, '{}'::jsonb))
  specification(spec_key, value)
WHERE BTRIM(specification.spec_key) <> '' AND BTRIM(specification.value) <> ''
ON CONFLICT DO NOTHING;

INSERT INTO environment_tags (code, label, sort_order) VALUES
  ('environment-001', '高海拔', 1),
  ('environment-002', '有雲海', 2),
  ('environment-003', '森林系', 3),
  ('environment-004', '低海拔', 4),
  ('environment-005', '有溪流', 5)
ON CONFLICT DO NOTHING;

INSERT INTO facility_tags (code, label, sort_order) VALUES
  ('facility-001', '獨立衛浴', 1),
  ('facility-002', '裝備租借', 2),
  ('facility-003', '有雨棚', 3),
  ('facility-004', '兒童遊樂設施', 4),
  ('facility-005', '寵物友善', 5),
  ('facility-006', '小木屋', 6),
  ('facility-007', '可包區', 7)
ON CONFLICT DO NOTHING;

INSERT INTO campground_environment_tags (campground_id, tag_id)
SELECT campground.id, tag.id
FROM campgrounds campground
CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(campground.environment_tags, '[]'::jsonb)) value(label)
JOIN environment_tags tag ON tag.label = value.label
ON CONFLICT DO NOTHING;

INSERT INTO campground_facility_tags (campground_id, tag_id)
SELECT campground.id, tag.id
FROM campgrounds campground
CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(campground.facility_tags, '[]'::jsonb)) value(label)
JOIN facility_tags tag ON tag.label = value.label
ON CONFLICT DO NOTHING;

UPDATE product_variants variant
SET specification = COALESCE(NULLIF(BTRIM(variant.label), ''), variant.id),
    price = COALESCE(variant.price, product.price),
    status = product.status::text
FROM products product
WHERE product.id = variant.product_id;

INSERT INTO inventory_stocks (location_id, variant_id, on_hand_quantity)
SELECT location.id, variant.id, stock.quantity::integer
FROM product_variants variant
CROSS JOIN LATERAL jsonb_each_text(COALESCE(variant.branch_stock, '{}'::jsonb))
  stock(location_code, quantity)
JOIN inventory_locations location
  ON location.code = stock.location_code
 AND location.inventory_domain = 'store'
ON CONFLICT (location_id, variant_id) DO NOTHING;
