<#
Generates the beginner-facing schema guide from the canonical PostgreSQL snapshot.
The guide deliberately derives column, PK, FK, required/default metadata from DDL,
so it must be regenerated whenever the snapshot is regenerated.
#>
param(
  [string]$SchemaPath = 'docs/schema_copy.sql',
  [string]$OutputPath = 'docs/database-schema-guide.md'
)

$ErrorActionPreference = 'Stop'
$sql = [System.IO.File]::ReadAllText((Resolve-Path $SchemaPath))

function Escape-Cell([string]$value) { return $value.Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ') }

$columnMeaning = @{
  'id'='本列的唯一識別碼。'; 'created_at'='建立此筆資料的時間。'; 'updated_at'='最後更新時間。';
  'active'='是否啟用／可使用。'; 'status'='目前生命週期或上架狀態。'; 'name'='顯示名稱。';
  'code'='人可讀、通常唯一的代碼。'; 'email'='電子郵件；帳號或聯絡資訊。'; 'description'='文字說明。';
  'sort_order'='排序序號（較小者通常較前）。'; 'quantity'='數量；限制通常要求大於 0。';
  'on_hand_quantity'='實際現有庫存。'; 'minimum_quantity'='低庫存警示門檻。';
  'price'='金額（新台幣）；以 numeric 避免浮點誤差。'; 'discount'='折扣金額或百分比，依 type 解讀。';
  'customer_id'='指向 customers 的會員。'; 'product_id'='指向 products 的商城商品。';
  'variant_id'='指向商品規格（product_variants）。'; 'item_id'='指向 equipment_items 的共用裝備主檔。';
  'campground_id'='指向 campgrounds 的營區。'; 'branch_id'='指向 branches 的門市。';
  'location_id'='指向 inventory_locations 的庫存地點。'; 'order_id'='指向 orders 的訂單。';
  'booking_id'='指向 bookings 的預約。'; 'actor_id'='執行狀態變更的後台使用者。';
  'occurred_at'='事件實際發生時間。'; 'reason'='操作或限制的原因。';
  'sku'='庫存單位（SKU）代碼。'; 'inventory_domain'='庫存領域：store（商城）或 rental（租借）。';
  'idempotency_key'='冪等鍵：重送相同請求不應重複扣庫存／記帳。';
}
function Meaning([string]$name) {
  if ($columnMeaning.ContainsKey($name)) { return $columnMeaning[$name] }
  if ($name -like '*_snapshot') { return '交易當下複製的快照；保留歷史，不隨主檔改動。' }
  if ($name -like '*_url') { return '外部或靜態資源的網址。' }
  if ($name -like '*_id') { return '識別碼；是否為外鍵請看「關聯」欄。' }
  if ($name -like '*_at') { return '時間戳記。' }
  if ($name -like 'is_*') { return '布林判斷旗標。' }
  if ($name -like '*_date') { return '日期（不含時間）。' }
  if ($name -like '*_total' -or $name -like '*_amount') { return '彙總金額。' }
  if ($name -like '*_count') { return '計數值。' }
  return '請依表格用途與 SQL 的 CHECK／FK 約束一起解讀。'
}

$purposes = @{
  'admin_users'='後台員工與角色。'; 'customers'='會員基本資料（OAuth 帳號）。'; 'customer_shipping_addresses'='會員收件地址。'; 'customer_tags'='會員分群標籤。'; 'customer_tag_assignments'='會員與標籤的多對多關係。'; 'customer_preferences'='會員偏好問卷答案。'; 'preference_options'='偏好題目的可選值。';
  'brands'='品牌主檔。'; 'product_categories'='商品分類主檔。'; 'equipment_items'='裝備共用主檔；商城與租借共用。'; 'equipment_images'='裝備圖片。'; 'equipment_specifications'='裝備規格鍵值。'; 'equipment_tags'='裝備搜尋標籤。'; 'equipment_interest_tags'='裝備興趣標籤。'; 'products'='可販售商城商品。'; 'product_variants'='商城商品規格與 SKU。';
  'campgrounds'='營區主檔。'; 'campground_zones'='營區內可預約的營位類型與容量／定價。'; 'environment_tags'='營區環境標籤。'; 'facility_tags'='營區設施標籤。'; 'campground_environment_tags'='營區與環境標籤的多對多關係。'; 'campground_facility_tags'='營區與設施標籤的多對多關係。'; 'campground_closures'='營區關閉日期或每週公休。'; 'zone_blocks'='特定營位、日期區間的人工保留量。'; 'booking_policies'='預約規則的單例設定。'; 'booking_policy_availability_statuses'='哪些預約狀態可在可用性中顯示。'; 'booking_policy_occupying_statuses'='哪些預約狀態會占用營位。'; 'calendar_dates'='假日判定日曆。';
  'rental_skus'='可租借裝備群組。'; 'rental_sku_variants'='可租借裝備規格與 SKU。'; 'rental_listings'='營區可出租的規格、定價與文案。'; 'campground_rental_locations'='營區對應的租借庫存地點。';
  'orders'='商城訂單表頭。'; 'order_items'='商城訂單品項與交易快照。'; 'order_status_history'='訂單狀態歷程。'; 'coupons'='優惠券主檔。'; 'order_coupons'='訂單套用的優惠券快照。'; 'coupon_usage_adjustments'='優惠券使用量回補／重扣稽核。';
  'bookings'='營區預約表頭與金額快照。'; 'booking_selected_zones'='預約選取的營位。'; 'booking_selected_rentals'='預約加租的裝備。'; 'booking_status_history'='預約狀態歷程。';
  'branches'='門市主檔。'; 'branch_features'='門市特色文字。'; 'inventory_locations'='庫存地點（商城與租借分域）。'; 'inventory_stocks'='商城規格在地點的現有庫存。'; 'rental_sku_variant_stocks'='租借規格在地點的現有庫存。'; 'product_variant_min_stocks'='商城規格最低庫存。'; 'rental_sku_variant_min_stocks'='租借規格最低庫存。'; 'inventory_movements'='庫存異動單表頭。'; 'store_inventory_movement_items'='商城庫存異動明細。'; 'rental_inventory_movement_items'='租借庫存異動明細。'; 'inventory_conversions'='商城商品轉為租借裝備的成對異動。'; 'product_stock_reservations'='商城訂單的庫存保留帳。'; 'rental_stock_reservations'='預約租借的日期區間庫存保留帳。';
  'reviews'='已購買品項的正式評論。'; 'review_photos'='正式評論圖片。'; 'legacy_reviews'='無法完全轉正的舊評論，只讀遷移證據。'; 'legacy_review_photos'='舊評論圖片。'; 'articles'='文章主檔。'; 'article_content_blocks'='文章內容區塊。'; 'article_related_products'='文章關聯商品。'; 'article_tags'='文章標籤。'
}

# Parse all table bodies from the dump. The dump uses one column/constraint per line.
$tables = @()
foreach ($m in [regex]::Matches($sql, '(?ms)^CREATE TABLE (?<schema>migration|public)\.(?<name>[A-Za-z0-9_]+) \(\r?\n(?<body>.*?)^\);')) {
  $full = "$($m.Groups['schema'].Value).$($m.Groups['name'].Value)"
  $columns = @()
  foreach ($line in ($m.Groups['body'].Value -split "`n")) {
    $line = $line.Trim().TrimEnd(',')
    if (!$line -or $line -match '^(CONSTRAINT|\))') { continue }
    if ($line -match '^(?<name>[A-Za-z0-9_]+)\s+(?<type>.+?)(?=\s+(?:DEFAULT|NOT NULL|CONSTRAINT|REFERENCES|CHECK)\b|$)\s*(?<rest>.*)$') {
      $columns += [pscustomobject]@{ Name=$Matches.name; Type=$Matches.type; Rest=$Matches.rest }
    }
  }
  $tables += [pscustomobject]@{ Schema=$m.Groups['schema'].Value; Name=$m.Groups['name'].Value; Full=$full; Columns=$columns }
}

$keys = @{}
foreach ($m in [regex]::Matches($sql, '(?ms)^ALTER TABLE ONLY (?<table>[^\r\n]+)\r?\n\s+ADD CONSTRAINT [^ ]+ (?<kind>PRIMARY KEY|UNIQUE) \((?<cols>[^)]+)\)')) {
  $key = $m.Groups['table'].Value.Trim(); if (!$keys.ContainsKey($key)) { $keys[$key] = @() }; $keys[$key] += "$($m.Groups['kind'].Value): $($m.Groups['cols'].Value)"
}
$fks = @{}
foreach ($m in [regex]::Matches($sql, '(?ms)^ALTER TABLE ONLY (?<table>[^\r\n]+)\r?\n\s+ADD CONSTRAINT [^ ]+ FOREIGN KEY \((?<cols>[^)]+)\) REFERENCES (?<target>[^ (]+)\((?<targetCols>[^)]+)\)')) {
  $key = $m.Groups['table'].Value.Trim(); if (!$fks.ContainsKey($key)) { $fks[$key] = @() }; $fks[$key] += "$($m.Groups['cols'].Value) → $($m.Groups['target'].Value)($($m.Groups['targetCols'].Value))"
}

$public = @($tables | Where-Object Schema -eq 'public'); $migration = @($tables | Where-Object Schema -eq 'migration')
$out = [System.Collections.Generic.List[string]]::new()
$out.Add('# Yuruicamp 資料庫結構導覽')
$out.Add('')
$out.Add('> 來源：`docs/schema_copy.sql`（P7 驗證後快照）。本文件由 `tools/database-validation/generate-schema-guide.ps1` 產生；欄位描述以名稱與 DDL 約束解讀，業務規則以 SQL 為最終準則。')
$out.Add('')
$out.Add('## 先說結論')
$out.Add('')
$out.Add('- **資料庫**：PostgreSQL。證據包含 `pg_catalog`、`plpgsql`、`jsonb`、`timestamp with time zone`、`generate_series` 與 PostgreSQL dump 格式。')
$out.Add('- **Schema 定義方式**：資料庫優先（database-first）。`docs/schema_copy.sql` 是可重建新資料庫的最終快照；既有資料庫只能依 `backend/src/main/resources/db/migration/V001…V700` 的 Flyway migration 升級。')
$out.Add('- **ORM**：後端 `pom.xml` 有 Spring Data JPA，但目前 `backend/src/main` 沒有 Java `@Entity`；`spring.jpa.hibernate.ddl-auto=validate` 只驗證結構、不讓 Hibernate 建表。因此實際 schema 來源是 Flyway SQL，不是 ORM 類別。')
$out.Add("- **規模**：共 $($tables.Count) 張表：`public` $($public.Count) 張日常業務表、`migration` $($migration.Count) 張歷史遷移／稽核表。")
$out.Add('- **關鍵觀念**：`public` 是應用程式的現行資料；`migration` 是轉換證據，P7 已設為唯讀，正常功能不可寫入。')
$out.Add('')
$out.Add('## ERD（業務主幹）')
$out.Add('')
$out.Add('```mermaid')
$out.Add('erDiagram')
$out.Add('  CUSTOMERS ||--o{ ORDERS : places')
$out.Add('  ORDERS ||--|{ ORDER_ITEMS : contains')
$out.Add('  PRODUCTS ||--|{ PRODUCT_VARIANTS : has')
$out.Add('  EQUIPMENT_ITEMS ||--o| PRODUCTS : sold_as')
$out.Add('  EQUIPMENT_ITEMS ||--o| RENTAL_SKUS : rented_as')
$out.Add('  CUSTOMERS ||--o{ BOOKINGS : makes')
$out.Add('  CAMPGROUNDS ||--|{ CAMPGROUND_ZONES : contains')
$out.Add('  BOOKINGS ||--|{ BOOKING_SELECTED_ZONES : selects')
$out.Add('  BOOKINGS ||--o{ BOOKING_SELECTED_RENTALS : adds')
$out.Add('  RENTAL_SKUS ||--|{ RENTAL_SKU_VARIANTS : has')
$out.Add('  RENTAL_SKU_VARIANTS ||--o{ RENTAL_LISTINGS : listed_at')
$out.Add('  INVENTORY_LOCATIONS ||--o{ INVENTORY_STOCKS : holds')
$out.Add('  INVENTORY_LOCATIONS ||--o{ RENTAL_SKU_VARIANT_STOCKS : holds')
$out.Add('  INVENTORY_MOVEMENTS ||--o{ STORE_INVENTORY_MOVEMENT_ITEMS : details')
$out.Add('  INVENTORY_MOVEMENTS ||--o{ RENTAL_INVENTORY_MOVEMENT_ITEMS : details')
$out.Add('  ORDER_ITEMS ||--o| REVIEWS : reviewed_by')
$out.Add('  ARTICLES ||--|{ ARTICLE_CONTENT_BLOCKS : contains')
$out.Add('```')
$out.Add('')
$out.Add('這張圖只放主要路徑；完整、可機器查核的每一條 FK 都列在各表的「關聯」。複合 FK（例如 `(id, inventory_domain)`）刻意保留兩欄，避免商城庫存與租借庫存混用。')
$out.Add('')
$out.Add('## 資料庫會主動做什麼？（函式與 Trigger）')
$out.Add('')
$out.Add('- `public.get_zone_availability(...)`：按日期展開營位，扣掉會占位的預約與人工 block；遇到公休直接回傳可用量 0，且不會回傳負數。')
$out.Add('- `trg_inventory_movements_immutable`：已過帳或取消的庫存異動不可改；過帳前必須有明細或轉換資料。')
$out.Add('- `trg_store_inventory_movement_items_draft_only`、`trg_rental_inventory_movement_items_draft_only`、`trg_inventory_conversions_draft_only`：明細與轉換只允許在異動單仍是 `draft` 時編輯。')
$out.Add('- `trg_product_stock_reservations_lifecycle`、`trg_rental_stock_reservations_lifecycle`：強制保留帳由 `active` 走向終態，終態不可改／不可刪，避免庫存稽核斷鏈。')
$out.Add('- `trg_inventory_locations_protect_minimum_stock_domain`、`trg_inventory_locations_protect_rental_mapping`：已被最低庫存或營區租借對應使用的地點，不能改成不相容領域／類型。')
$out.Add('- `trg_legacy_reviews_read_only`、`trg_legacy_review_photos_read_only`、`trg_movement_migration_map_read_only`、`trg_p7_contract_evidence_read_only`：保護遷移證據不被應用程式改寫。')
$out.Add('')
$out.Add('## 資料如何流動')
$out.Add('')
$out.Add('1. **商品下單**：`equipment_items`（裝備主檔）→ `products` → `product_variants`；結帳建立 `orders`、`order_items`（價格與名稱快照），再以 `product_stock_reservations` 暫保庫存。狀態改變寫入 `order_status_history`；用券寫入 `order_coupons`，回補／重扣留在 `coupon_usage_adjustments`。')
$out.Add('2. **營區預約**：讀取 `campgrounds`、`campground_zones`、`calendar_dates`、`campground_closures`、`zone_blocks`，並呼叫 `get_zone_availability()` 算出可訂量。成立後寫 `bookings`、選取明細與 `rental_stock_reservations`；取消／完成走狀態歷程與保留帳生命週期。入住日含、退房日不含：`[check_in, check_out)`。')
$out.Add('3. **庫存異動**：先建 `inventory_movements` 草稿與商城或租借明細；只有 `posted` 才是正式異動，資料庫 trigger 禁止事後修改。`inventory_conversions` 將商城規格以成對異動轉入租借規格。')
$out.Add('4. **內容與評價**：文章由 `articles`、區塊、標籤、關聯商品組成。正式評論只能對 `order_items` 建立一筆 `reviews`；舊格式無法完全對應的資料保留在 `legacy_reviews`。')
$out.Add('')
$out.Add('## 設計上值得注意的地方')
$out.Add('')
$out.Add('- **快照不是 migration**：檔案註解已明示 `schema_copy.sql` 不能拿來升級既有資料庫；請新增更高版本的 Flyway migration。')
$out.Add('- **交易快照是刻意去正規化**：訂單／預約明細的 `*_snapshot` 不應回頭同步主檔，否則舊訂單金額與名稱會被改寫。')
$out.Add('- **庫存領域隔離**：商城 `product_variants` 與租借 `rental_sku_variants` 是不同規格體系；以 `inventory_domain`、複合 FK、trigger 防止混接。')
$out.Add('- **資料庫不只存資料，也執行規則**：可用性函式、CHECK、FK、唯一鍵與 trigger 都是防線；例如異動過帳後不可改、預約關閉日可用量為零、保留帳終態不可改。')
$out.Add('- **`migration` 不可當業務來源**：那些表是 P1–P7 的來源／對帳／隔離資料，保留是為了可追溯性，而非供畫面查詢。')
$out.Add('- **時間與金額**：時間多用含時區 timestamp；金額用 `numeric(12,2)`／`numeric(14,2)`，不要在程式端以浮點數累加。')
$out.Add('')
$out.Add('## 完整資料字典')
$out.Add('')
$out.Add('欄位的「必填」依 `NOT NULL` 判斷；「預設值」直接取自 DDL；PK／UNIQUE／FK 均以快照最後的 `ALTER TABLE` 約束為準。')

foreach ($group in @(@{Title='A. 現行業務資料（public）'; Tables=$public}, @{Title='B. 遷移與稽核資料（migration；唯讀）'; Tables=$migration})) {
  $out.Add('')
  $out.Add("## $($group.Title)")
  foreach ($table in $group.Tables) {
    $out.Add('')
    $out.Add("### ``$($table.Full)``")
    $purpose = if ($purposes.ContainsKey($table.Name)) { $purposes[$table.Name] } elseif ($table.Schema -eq 'migration') { '歷史資料轉換、對帳、隔離或合約證據；不是現行業務資料。' } else { '現行業務資料表。' }
    $out.Add("**用途：** $purpose")
    $keyText = if ($keys.ContainsKey($table.Full)) { $keys[$table.Full] -join '；' } else { '此快照未以 ALTER TABLE 宣告 PK／UNIQUE（多為過渡證據表）。' }
    $out.Add("**鍵：** $keyText")
    $fkText = if ($fks.ContainsKey($table.Full)) { $fks[$table.Full] -join '；' } else { '無外鍵。' }
    $out.Add("**關聯：** $fkText")
    $out.Add('')
    $out.Add('| 欄位 | 型別 | 必填 | 預設值 | 意義 |')
    $out.Add('| --- | --- | --- | --- | --- |')
    foreach ($c in $table.Columns) {
      $required = if ($c.Rest -match 'NOT NULL') { '是' } else { '否' }
      $default = if ($c.Rest -match 'DEFAULT\s+(.+?)(?=\s+(?:NOT NULL|CONSTRAINT)|$)') { Escape-Cell $Matches[1] } else { '—' }
      $out.Add("| ``$($c.Name)`` | ``$($c.Type)`` | $required | $default | $(Meaning $c.Name) |")
    }
  }
}

$out.Add('')
$out.Add('## 讀這份文件的實用順序')
$out.Add('')
$out.Add('1. 先從 ERD 選一個流程（下單、預約或庫存）。')
$out.Add('2. 讀該流程的表頭（`orders`／`bookings`／`inventory_movements`）後，再讀明細與歷程表。')
$out.Add('3. 遇到 `*_snapshot`、複合鍵或 `inventory_domain` 時，回看本文件的注意事項與 DDL 約束。')
$out.Add('4. 要改結構時，閱讀相對應的 Flyway migration，新增下一版 migration；不要直接改已套用檔案或快照。')

[System.IO.File]::WriteAllText((Join-Path (Get-Location) $OutputPath), ($out -join "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
