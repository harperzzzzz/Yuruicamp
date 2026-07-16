# camps
* campgrounds
    「可預約」營區的主檔資料。
* campground_zones
    營區底下的營位區、單位容量、價格與每晚可售數量。



## 關聯與資料流
campgrounds
└─ 1:N campground_zones

### 關聯
* campgrounds：可預約營區的中心主檔；僅包含 C002–C009，C001 是租借主倉，並不在此表中。
* campground_zones：每筆營位區必須屬於一個營區，透過 `campground_id` 關聯至 `campgrounds.id`。
* 資料庫更新營區 ID 時，子表的 `campground_id` 會一併更新；有營位區時不可直接刪除營區（`ON UPDATE CASCADE`、`ON DELETE RESTRICT`）。

### 資料流程
營區資料建立後：
1. 在 campgrounds 建立營區基本資料。
2. 以 campgrounds.id 作為 campground_zones.campground_id，建立一或多個營位區。
3. 每個營位區設定每帳營位可入住人數、平日／假日價格與每晚可售總數。
4. 預約服務以營區與營位區資料判斷可選區域與定價；`total_sites` 是單晚的可售上限。



## 欄位說明
### campgrounds
* id                    營區識別碼，VARCHAR(32)，主鍵 `pk_campgrounds`。
* name                  營區名稱，VARCHAR(150)

* region                所在區域，VARCHAR(100)
                        *idx_campgrounds_region_active* (region、active)

* description           營區介紹，NULL。
* active                是否啟用，預設 true
* created_at            建立時間，預設 now()

* updated_at            更新時間，預設 now()
                        沒有自動更新的 Trigger。

### campground_zones
* id                    營位區識別碼，VARCHAR(32)
                        與 `campground_id` 組成複合 UNIQUE `uq_campground_zones_id_campground_id`，供複合外鍵使用。

* campground_id         所屬營區識別碼，VARCHAR(32)
                        *idx_campground_zones_campground_active* (campground_id、active)

* type                  營位類型，例如草皮區、雨棚區，VARCHAR(64)
* capacity_per_site     每帳營位的可入住人數，預設 1，必須大於 0
* price_weekday         平日每帳價格，NUMERIC(12,2)，預設 0，不得為負數。
* price_holiday         假日每帳價格，NUMERIC(12,2)，預設 0，不得為負數。
* total_sites           每晚可售的營位總數，預設 0，必填，必須大於 0。
* active                是否啟用，預設 true
* created_at            建立時間，預設 now()

* updated_at            更新時間，預設 now()
                        沒有自動更新的 Trigger。



## 運作模式
* 營區基本資料 > campgrounds
* 營位區設定、單位容量與售價 > campground_zones
* 停用營區或營位區應更新 `active = false`；schema 未提供軟刪除欄位與禁止 DELETE 的 Trigger。
* 刪除營區前必須先處理其營位區與其他引用該營區的資料，因為外鍵採 `ON DELETE RESTRICT`。



## 程式碼追蹤
* 前台營區搜尋與詳情
    `booking/js/camp-search.js`、`booking/js/camp-detail.js`
                ↓
    `window.BookingAPI.getCampgrounds()`
                ↓
    `js/booking-api.js`
                ↓
    讀取 `data/catalog/campgrounds.json`
                ↓
    以 campgroundId 與 zones[] 組合營區及營位區資料

    * 目前實際執行時：
        - 不直接查詢 PostgreSQL campgrounds 或 campground_zones。
        - 營區與營位區皆由 `campgrounds.json` 的巢狀資料提供。
        - JSON 的 `environmentTags`、`facilityTags` 屬於另一組標籤主檔與關聯表的來源。

## 可能的問題
* 高風險：前端目前讀取 JSON，與正式資料庫的 campgrounds、campground_zones 為兩套資料來源；資料更新後可能不一致。
* 中風險：updated_at 僅有預設值，更新資料時不會由資料庫自動改寫；應由後端服務統一處理。
* 中風險：campgrounds 沒有名稱或區域不可空白的 CHECK，僅限制 NOT NULL；空字串仍可能寫入。
* 中風險：schema 中 `campgrounds` 夾帶 6 個名稱為 `ck_customer_shipping_addresses_*`、且引用地址欄位的 CHECK。這些欄位不屬於 campgrounds，應確認匯出的 schema 是否正確，避免正式建表或 migration 失敗。
