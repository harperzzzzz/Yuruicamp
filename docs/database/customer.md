# customers

## problem : 
1. preferences 使用 JSONB 儲存多值資料。
2. tags 使用 JSONB 儲存多值資料。
違反1NF

* 拆成「偏好主檔」與「會員偏好關聯表」

實際資料在 data/customers/customers.json 是：
```
"preferences": {
  "styles": ["backpacking", "hiking"],
  "equipment": ["tent", "backpack"]
}
```

### preferences 主要影響 : 
缺點 : 
- 難做 FK，無法保證值一定存在於合法偏好清單
- 造成二次查詢降低效能，但還是可以查的到
- 難統計
- 難防重複
- 偏好值改名時，要全搜一次資料庫維護成本高

優點 :
- 防重複

### preferences 更動 :
刪除customers 的preferences
* customers 1 : customer_preferences N
* customer_preferences N : preference_options 1

```
CREATE TABLE preference_options (
  id          VARCHAR(64) PRIMARY KEY,
  type        VARCHAR(32) NOT NULL CHECK (type IN ('style', 'equipment')),
  label       VARCHAR(100) NOT NULL,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE customer_preferences (
  customer_id    VARCHAR(32) NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  preference_id  VARCHAR(64) NOT NULL REFERENCES preference_options(id),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (customer_id, preference_id)
);

CREATE INDEX idx_customer_preferences_preference
  ON customer_preferences(preference_id);
```

* data/customers/customers.json，整理syltles, equipment ，preference_options 到perference_options
* Json 檔可以造舊資料可以撈出來在組合
* 改完移除customers.preferences


* 修改 seed 文件
更新 [docs/mock-json-to-sql-seed.md (line 48)](D:/GithubDesk/Yuruicamp/docs/mock-json-to-sql-seed.md:48)，把 preferences 的轉換規則改成：
JSON preferences.styles[] -> preference_options.type = 'style' + customer_preferences
JSON preferences.equipment[] -> preference_options.type = 'equipment' + customer_preferences






### tags 主要影響 : (如果前端只限定一項，改動tags 的資料型態就行了)
缺點 : 
- 難做 FK，無法保證值一定合法
- 造成二次查詢降低效能，但還是可以查的到
- 難統計
- 難防重複
- 改名時，要全搜一次資料庫維護成本高

優點 :
- 防重複

### tags 更動 :
新增「標籤主檔」和「會員標籤關聯表」：
* customers 1 : customer_tag_assignments N
* customer_tag_assignments N : customer_tags 1

```
CREATE TABLE customer_tags (
  id          VARCHAR(64) PRIMARY KEY,
  name        VARCHAR(100) NOT NULL UNIQUE,
  color_class VARCHAR(64) NOT NULL DEFAULT 'bg-secondary',
  sort_order  INTEGER NOT NULL DEFAULT 0,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE customer_tag_assignments (
  customer_id VARCHAR(32) NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  tag_id      VARCHAR(64) NOT NULL REFERENCES customer_tags(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (customer_id, tag_id)
);

CREATE INDEX idx_customer_tag_assignments_tag
  ON customer_tag_assignments(tag_id);
```

* 從 data/customers/customers.json 的 tags[] 和 window.tagColorMap 收集所有標籤名稱與顏色，整理成 customer_tags。
* 每個會員每個標籤建立一筆 customer_tag_assignments。
PRIMARY KEY (customer_id, tag_id) 負責防重。
* 將 /tag-pool 改為真正標籤主檔
目前 [admin/js/admin-api.js (line 126)] 的 PUT /tag-pool 儲存 tagColorMap。後端應改成寫入 customer_tags，而不是只保存前端 map。





### shipping_address 主要影響 : 
缺點 : 
- 地址欄位藏在 JSONB，資料庫無法檢查 postal_code、city、phone、email 等欄位格式。
- 無法針對城市、區域、郵遞區號做乾淨查詢或統計
- 後台和前台都各自 clone / validate / format，欄位規則容易分散
- `只能存「一組預設地址」，要多地址、超商地址、公司地址會卡住。 不一定要多個`
- 會員地址可被更新，但歷史訂單不能跟著變。

優點 :
- 支援多地址
- 保存舊地址，避免資料非法更動

### shipping_address 更動 :
支援多地址 :
```
CREATE TABLE customer_shipping_addresses (
  id             BIGSERIAL PRIMARY KEY,
  customer_id    VARCHAR(32) NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  recipient_name VARCHAR(100) NOT NULL,
  last_name      VARCHAR(50),
  first_name     VARCHAR(50),
  postal_code    VARCHAR(10) NOT NULL,
  city           VARCHAR(50) NOT NULL,
  district       VARCHAR(50) NOT NULL,
  township       VARCHAR(50),
  address_line1  TEXT NOT NULL,
  address_line2  TEXT,
  email          VARCHAR(255),
  phone          VARCHAR(32) NOT NULL,
  is_default     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_customer_shipping_addresses_customer
  ON customer_shipping_addresses(customer_id);

CREATE UNIQUE INDEX uq_customer_default_shipping_address
  ON customer_shipping_addresses(customer_id)
  WHERE is_default = TRUE;
```

只想支援一組地址，也可以簡化成：
```
CREATE TABLE customer_shipping_profiles (
  customer_id    VARCHAR(32) PRIMARY KEY REFERENCES customers(id) ON DELETE CASCADE,
  last_name      VARCHAR(50) NOT NULL,
  first_name     VARCHAR(50) NOT NULL,
  postal_code    VARCHAR(10) NOT NULL,
  city           VARCHAR(50) NOT NULL,
  district       VARCHAR(50) NOT NULL,
  township       VARCHAR(50),
  address_line1  TEXT NOT NULL,
  address_line2  TEXT,
  email          VARCHAR(255),
  phone          VARCHAR(32) NOT NULL,
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

* customers 不再直接存地址 JSON，只保留會員身份、電話、email、點數、等級等主資料。
* customer_shipping_addresses 存會員地址，一個會員可以有多筆，並用 is_default 指出預設地址。
* 查詢時用GET 組回舊格式
* 訂單仍保留地址快照
