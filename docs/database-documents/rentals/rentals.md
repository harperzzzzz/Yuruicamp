# rentals
* rental_skus
    定義可出租裝備的租借 SKU 群組，是租借庫存的唯一寫入來源。
* rental_sku_variants
    定義租借 SKU 的實際規格變體。
* campground_rental_locations
    將可預約營區一對一對應至其租借庫存庫位。
* rental_listings
    定義營區可提供的租借變體、每日價格與上架狀態。


## 關聯與資料流
equipment_items
└─ 1:1 rental_skus
      └─ 1:N rental_sku_variants
            └─ 1:N rental_listings

campgrounds
└─ 1:1 campground_rental_locations ─ 1:1 inventory_locations
      └─ rental_listings 以 campground_id 確認營區已有租借庫位對照

### 關聯
* rental_skus：以 item_id 對應 equipment_items；同一裝備只能建立一個租借 SKU 群組。
* rental_sku_variants：每個變體屬於一個 rental_skus，可用顏色、尺寸與 specification 區分。
* campground_rental_locations：每個營區只能對應一個租借庫位，每個庫位也只能屬於一個營區。
* rental_listings：將租借變體上架至營區；每一組 campground_id 與 rental_sku_variant_id 只能有一筆 listing。

### 資料流程
新增可出租裝備時：
1. 先在 equipment_items 建立共用裝備主檔。
2. 在 rental_skus 建立對應的租借 SKU 群組。
3. 在 rental_sku_variants 建立可出租的規格變體。
4. 為可預約營區在 campground_rental_locations 建立唯一的租借庫位對照。
5. 在 rental_listings 建立營區與租借變體的上架資料，設定平日、假日價格及折扣。
6. 查詢實體庫存時，先用 campground_id 從 campground_rental_locations 取得 location_id，再以 location_id 與 rental_sku_variant_id 查詢租借庫存。



## 欄位說明
### rental_skus
* id                    租借 SKU 群組識別碼

* item_id               對應的裝備主檔；參照 equipment_items.id，UNIQUE。
                        同一裝備只能有一個租借 SKU 群組。

* status                狀態，預設 active，只允許 active 或 inactive。
                        *idx_rental_skus_status*

* created_at            建立時間，預設 now()。

* updated_at            更新時間，預設 now()。
                        沒有統一自動更新的 Trigger。

### rental_sku_variants
* id                    租借 SKU 變體識別碼。
* rental_sku_id         所屬租借 SKU 群組；
                        *idx_rental_sku_variants_sku_status* (rental_sku_id、status)

* sku                   變體 SKU，UNIQUE。
* color                 顏色，NULL。
* size                  尺寸，NULL。
* specification         規格說明，不可為 NULL。
* status                狀態，預設 active，只允許 active 或 inactive。
* created_at            建立時間，預設 now()。

* updated_at            更新時間，預設 now()。
                        沒有統一自動更新的 Trigger。

*(rental_sku_id, id) 為複合 UNIQUE，確保變體與其父群組的組合可被其他資料表參照。*

### campground_rental_locations
* campground_id         可預約營區；參照 campgrounds.id，主鍵。
* location_id           營區對應的租借庫位；參照 inventory_locations.id，UNIQUE。

*一個營區只能有一個租借庫位，一個租借庫位也只能對應一個營區。*
*營區 C001 是租借主倉，只存在 inventory_locations，不應建立於此表。*

### rental_listings
* id                    租借上架資料識別碼。
* campground_id         上架營區；必須存在於 campground_rental_locations。

* rental_sku_variant_id 上架的租借 SKU 變體；
                        *idx_rental_listings_variant_active* (rental_sku_variant_id、active)

* price_per_day_weekday 平日每日租金，必須大於等於 0。
* price_per_day_holiday 假日每日租金，必須大於等於 0。
* discount              折扣比率，預設 0，範圍為 0.00～0.30（最多 30%）。
* terrain               適用地形說明，NULL。
* description           上架說明，NULL。
* active                是否上架，預設 true。
* created_at            建立時間，預設 now()。

* updated_at            更新時間，預設 now()。
                        沒有統一自動更新的 Trigger。

*(campground_id, rental_sku_variant_id) 為複合 UNIQUE，同一營區不得重複上架相同變體。*



## 運作模式
* 租借品項主檔 > rental_skus
* 租借規格變體 > rental_sku_variants
* 營區與租借庫位對照 > campground_rental_locations
* 營區租借上架與定價 > rental_listings

### 庫存查詢
* rental_listings 不直接保存 location_id 或 stock。
* 營區租借庫存必須由 campground_rental_locations 解析出 location_id 後，再查詢 rental_sku_variant_stocks。
* rental_listing_view 提供 listing、庫位及實體庫存的唯讀投影；預約可用量仍應由 reservation 流程計算。



## 程式碼追蹤
* 目前在前端 `js`、`pages` 與 `components` 目錄中，未找到直接讀寫這四張 PostgreSQL 資料表的程式碼。

* 目前資料來源與正式資料庫的對應：
    `data/admin/rental-skus.json`
                ↓
    rental_skus、rental_sku_variants
                ↓
    依營區庫位對照產生 rental_listings

    * 正式後端應以 rental_sku_variants 作為租借、庫存與上架關聯的變體識別。
    * 營區端只傳遞 campground_id；服務層負責解析對應的 location_id。

* 開發 Seed 現況：`030-catalog.sql` 已建立 R001～R028 與 37 個 `RSV-Rxxx-xx`；`040-inventory.sql` 已建立 16 筆有明確定價的 listing。未在 `camp-equipment.json` 出現的組合不會因為有庫存就自動上架。


## 可能的問題
* 已處理：E-4 Booking Checkout 會同時確認 listing、equipment item、rental SKU、variant 與營區庫位有效，停用品項不會建立租借保留。

* 高風險：campground_rental_locations 的 FK 只確認庫位存在，表結構本身未限制 inventory_locations 必須是 rental 領域的營區庫位；建立或更新對照時應由服務層驗證庫位類型與領域。

* 中風險：updated_at 不會自動更新，應由 Spring Boot Service 在更新時一併寫入。

* 低風險：color、size、terrain 與 description 沒有格式或內容限制，需由應用層統一輸入規則。
