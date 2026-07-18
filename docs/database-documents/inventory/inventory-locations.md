# inventory-locations
    代表一個可存放庫存的地點
* inventory_stocks  
    某商城庫位，目前有多少實物
* product_variant_min_stocks  
    商城商品規格在指定庫存地點的最低庫存設定。
* rental_sku_variant_stocks  
    租借 SKU 規格在指定庫存地點的現有庫存。
* rental_sku_variant_min_stocks  
    租借 SKU 規格在指定庫存地點的最低庫存設定。



## 關聯與資料流
```text
branches
└─ 1:N inventory_locations（僅 store／branch 類型）

inventory_locations
├─ 1:N inventory_stocks
├─ 1:N product_variant_min_stocks
├─ 1:N rental_sku_variant_stocks
└─ 1:N rental_sku_variant_min_stocks

product_variants
├─ 1:N inventory_stocks
└─ 1:N product_variant_min_stocks

rental_sku_variants
├─ 1:N rental_sku_variant_stocks
└─ 1:N rental_sku_variant_min_stocks
```

### 關聯
* inventory_locations：庫存地點中心主檔，以 `inventory_domain` 區分商城（`store`）與租借（`rental`）。
* inventory_stocks：`inventory_locations` 與 `product_variants` 的庫存數量關聯表；`(location_id, variant_id)` 是複合主鍵。
* product_variant_min_stocks：`inventory_locations` 與 `product_variants` 的最低庫存設定關聯表；`(variant_id, location_id)` 是複合主鍵。
* rental_sku_variant_stocks：`inventory_locations` 與 `rental_sku_variants` 的庫存數量關聯表；`(location_id, rental_sku_variant_id)` 是複合主鍵。
* rental_sku_variant_min_stocks：`inventory_locations` 與 `rental_sku_variants` 的最低庫存設定關聯表；`(rental_sku_variant_id, location_id)` 是複合主鍵。
* 五張表的外鍵皆為 `ON UPDATE CASCADE ON DELETE RESTRICT`，已被庫存資料使用的主檔不得直接刪除。

### 資料流程
1. 建立庫位
   inventory_locations
   └─ 宣告這是商城或租借，以及主倉／分店／營地等類型

2. 建立品項餘額
   商城：inventory_stocks
   租借：rental_sku_variant_stocks

3. 設定安全量
   商城：product_variant_min_stocks
   租借：rental_sku_variant_min_stocks

4. 查詢營運狀態
   現有量 - 最低量
   └─ 小於 0：低庫存，應補貨、調撥或停止提供



## 欄位說明
### inventory_locations

* id                    庫存地點識別碼，由呼叫端提供。
* code                  庫存地點代碼，NIQUE。
* inventory_domain      庫存類型，只允許 `store` 或 `rental`。

* type                  分類至store/rental 後的狀態
                        `store` 只允許 `main`、`branch`、`inspection`、`repair`、`damaged`。
                        `rental` 只允許 `main`、`campground`、`inspection`、`repair`、`damaged`。

* branch_id             所屬門市，NULL；只有 `type = branch` 且 `inventory_domain = store` 時必填
                        `type` 非 `branch` 時必須為 NULL。
                        *idx_inventory_locations_branch ON (branch_id)*

* name                  庫位顯示名稱
* active                是否啟用，預設 `true`。
* created_at            建立時間，預設 `now()`。
* updated_at            最後更新時間，預設 `now()`；DDL 未定義自動更新 Trigger。

*CHECK：庫存領域、地點類型，以及門市類型與 `branch_id` 的相容性。*
*idx_inventory_locations_domain_type_active ON (inventory_domain、type、active)*

### inventory_stocks
* location_id           庫存地點識別碼

* variant_id            商城商品規格識別碼
                        *idx_inventory_stocks_variant ON (variant_id)*

* on_hand_quantity      現有實體庫存量，預設 `0`，不得小於 `0`。
* inventory_domain      固定為 store。與 location_id 組成複合外鍵
                        強制只能指向商城庫位

* updated_at            最後更新時間，預設 `now()`；DDL 未定義自動更新 Trigger。

*(location_id, variant_id) 是複合主鍵，代表一個商城規格在一個地點只有一筆庫存。*

### product_variant_min_stocks
* variant_id            商城商品規格識別碼

* location_id           庫存地點識別碼
                        *idx_product_variant_min_stocks_location ON (location_id)*

* minimum_quantity      最低庫存量，不得小於 `0`。
* inventory_domain固定為 store，同樣限制庫位必須屬於商城。
* updated_at            最後更新時間，預設 `now()`；DDL 未定義自動更新 Trigger。

*(variant_id, location_id) 是複合主鍵，代表一個商城規格在一個地點只有一筆最低庫存設定。*

### rental_sku_variant_stocks
* location_id           庫存地點識別碼

* rental_sku_variant_id 租借 SKU 規格識別碼
                        *idx_rental_sku_variant_stocks_variant ON (rental_sku_variant_id)*

* on_hand_quantity      現有實體庫存量，預設 `0`，不得小於 `0`。
* updated_at            最後更新時間，預設 `now()`；DDL 未定義自動更新 Trigger。
*(location_id, rental_sku_variant_id) 是複合主鍵，代表一個租借規格在一個地點只有一筆庫存。*

### rental_sku_variant_min_stocks
* rental_sku_variant_id 租借 SKU 規格識別碼

* location_id           庫存地點識別碼
                        *idx_rental_sku_variant_min_stocks_location ON (location_id)*

* minimum_quantity      最低庫存量，不得小於 `0`。
* updated_at            最後更新時間，預設 `now()`；DDL 未定義自動更新 Trigger。
*(rental_sku_variant_id, location_id) 是複合主鍵，代表一個租借規格在一個地點只有一筆最低庫存設定。*



## 運作模式
* 庫存地點主檔 > `inventory_locations`
* 商城現有庫存 > `inventory_stocks`
* 商城最低庫存 > `product_variant_min_stocks`
* 租借現有庫存 > `rental_sku_variant_stocks`
* 租借最低庫存 > `rental_sku_variant_min_stocks`

### 領域隔離
* 商城庫存資料應只使用 `inventory_domain = store` 的地點，並搭配 `product_variants`。
* 租借庫存資料應只使用 `inventory_domain = rental` 的地點，並搭配 `rental_sku_variants`。
* `inventory_locations` 的 CHECK 會限制可用地點類型，但這五張表的外鍵本身未將 `inventory_domain` 納入鍵值，因此應由應用程式服務層驗證領域相容性。



## Admin 前端據點規則（固定清單）

後台 `admin/js/products.js` **只支援固定庫存據點**，不可在 UI 新增自訂分店或自訂營地：

| 領域 | 固定 ID | 顯示名稱 |
|------|---------|----------|
| 商城 | `main` | 商店主倉 |
| 商城 | `branch-001`～`branch-003` | 台北旗艦店／台中中港店／高雄左營店 |
| 租借 | `C001` | 租借主倉（非可預約營區） |
| 租借 | `C002`～`C009` | 可預約營區（對齊 `campgrounds`） |

讀寫時會忽略非固定 key。調撥來源僅固定分店；目標僅 `C001`～`C009`；營地互轉（Mode 2）仍可用。分類／品牌的「＋ 新增自訂…」與此無關。

---

## 程式碼追蹤

### 商城庫存與最低庫存流程
`data/catalog/products.json`
        ↓ `DataPaths.products`
`admin/js/products.js`：第 1041–1047 行
        ↓
`normalizeProductBranch()`：第 2429–2468 行
        ↓
`variants[].branch[locationId]` 作為商城規格×地點庫存
        ↓
商城庫存表格、低庫存標示與調撥來源選單

`data/admin/min-stock.json`
        ↓ `DataPaths.minStock`
`admin/js/products.js`：第 1050–1069 行
        ↓
`adminMinStockCache.store`
        ↓ `getMinStockValue()`：第 935–955 行
商城低庫存判斷與最低庫存設定模式

* `admin/js/products.js` 第 1036–1069 行會平行讀取商品 JSON 與最低庫存 JSON；最低庫存 JSON 讀取失敗時回退為空物件。
* `admin/js/products.js` 第 1816–1855 行的 `saveMinStockValues()` 僅更新記憶體中的 `adminMinStockCache`，不建立庫存異動、不寫回 JSON，也不寫入 `product_variant_min_stocks`。
* `admin/js/products.js` 第 5335–5399 行以規格的 `branch` map 取得來源分店庫存並建立調撥來源選項。
* `admin/js/products.js` 第 5799–5874 行的商城→租借調撥會先扣減商城規格的 `branch[branchId]`，再增加租借規格的 `camp[campKey]`；現行是前端快取操作，非資料庫交易。


### 租借庫存與最低庫存流程
`data/admin/rental-skus.json`
        ↓ `DataPaths.rentalSkus`
`admin/js/products.js`：第 1905–1964 行
        ↓
`normalizeRentalItem()`：第 1935–1964 行
        ↓
`variants[].camp[campgroundId]`
        ↓
`campByKey`／`camp` 彙總欄位
        ↓
租借規格×主倉／營地庫存表格

`data/admin/min-stock.json`
        ↓
`adminMinStockCache.rental`
        ↓ `getMinStockValue('rental', ...)`
租借低庫存標示與最低庫存設定模式

* `admin/js/products.js` 第 1905–1964 行載入並正規化租借 JSON；每筆資料會由營地陣列建立 `campByKey`，供表格以營地 ID 查詢。
* `admin/js/products.js` 第 3565–3650 行把租借商品舊格式轉為規格層的 `variants[].camp`，並重新計算商品層的彙總欄位。
* `admin/js/products.js` 第 2076–2104 行確認租借庫存變更前，會先產生異動明細，再更新租借快取與畫面。
* `admin/js/products.js` 第 2943–3035 行的 `buildMovementItemsForRentalChange()` 由營地前後數量差建立進貨、損耗或營地互轉的前端異動明細。
* `admin/js/products.js` 第 5100–5133 行以租借規格與營地的最低庫存值標示低庫存；缺少設定時仍回退預設值 `5`。


### 衍生 JSON 與資料維護腳本
`data/catalog/products.json`
        ↓
`admin/scripts/normalize-phase1-data.cjs`：第 13–39 行
        ↓
重算商品層 `branch` 與 `totalStock`

`data/admin/rental-skus.json`
        ↓ 正式後端寫入後應同步
`npm run sync:listings`
        ↓
`admin/scripts/sync-rental-listings.cjs`：第 19–44 行
        ↓
`data/catalog/camp-equipment.json` 的衍生 `stock`

* `package.json` 第 19、62、64 行提供 `check:normalize`、`sync:listings`、`normalize:data` 指令。
* `admin/scripts/normalize-phase1-data.cjs` 第 13–39 行檢查或更新商品 JSON 的衍生總庫存欄位；它不會寫入 `inventory_stocks`。
* `admin/scripts/sync-rental-listings.cjs` 第 19–44 行將租借 listing 的衍生庫存同步到 `camp-equipment.json`；它不會寫入 `rental_sku_variant_stocks`。



## 可能的問題
* 高風險：目前前端庫存與最低庫存的來源是 JSON／記憶體快取，後端也沒有實作這五張表的讀寫 API；畫面操作不會同步 PostgreSQL。
* 高風險：前端最低庫存 JSON 以商品 ID 與地點代碼組織，正式表則以 `product_variants.id` 或 `rental_sku_variants.id` 與 `inventory_locations.id` 組合；正式串接前必須定義明確的 ID 對應與遷移規則。
* 高風險：`rental_sku_variant_stocks` 與 `rental_sku_variant_min_stocks` 必須由後端服務層驗證。限制租借地點
* 中風險：四張庫存／最低庫存表的 `updated_at` 只有預設值，更新數量或門檻時不會自動刷新時間。
* 中風險：現有庫存與最低庫存是獨立資料列；資料庫未強制每一筆現有庫存都必須有最低庫存設定，反之亦然。
* 低風險：`inventory_locations.code` 全域 UNIQUE；如果未來需依庫存領域重複使用相同代碼，需改為含 `inventory_domain` 的複合唯一鍵。
