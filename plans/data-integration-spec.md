# Yuruicamp 假資料整合規格

> **Schema 整合任務清單**（可勾選進度）：[`schema-migration-checklist.md`](./schema-migration-checklist.md)
>
> **DDL（真相來源）**：[`../docs/latest_schema.sql`](../docs/latest_schema.sql)
>
> **導覽／枚舉**：[`../docs/database-schema-guide.md`](../docs/database-schema-guide.md) · [`../docs/schema-enums.md`](../docs/schema-enums.md)
>
> **領域說明（含快照語意）**：[`../docs/database-documents/`](../docs/database-documents/)
>
> **PostgreSQL 開發 Seed**：[`../docs/seed/README.md`](../docs/seed/README.md)
>
> **JSON／Seed 固定 ID**：[`../docs/data/json-seed-id-mapping.md`](../docs/data/json-seed-id-mapping.md)

| 欄位         | 內容                                      |
| ------------ | ----------------------------------------- |
| **目前定位** | 前端 Mock JSON 的資料語意、關聯與維護規格 |
| **更新日期** | 2026-07-22                                |
| **不負責**   | PostgreSQL Seed 載入順序、交易與執行方式  |

> **簡單說**：本文件回答「前端 Mock 資料怎麼維持一致」；[`docs/seed/README.md`](../docs/seed/README.md) 回答「PostgreSQL 本機展示資料怎麼建立」。已搬移的資料以 Schema／Seed 為準，Mock JSON 是同一案例的前端契約投影，但目前不會自動產檔。

商品、商城規格、品牌、營區、zone、標籤、門市、租借 SKU 與租借規格的 canonical ID 統一記錄於 [`json-seed-id-mapping.md`](../docs/data/json-seed-id-mapping.md)。品牌、營區、zone、門市與租借資料已對齊 SQL Seed；其他 Mock 若仍使用舊 ID，必須先依對照表轉換，不得直接把 `v-P...` 寫入商城或租借 FK。

## 文件邊界與閱讀路徑

| 要處理的事情                                        | 先讀哪裡                                                          |
| --------------------------------------------------- | ----------------------------------------------------------------- |
| 修改前端 Mock JSON、localStorage overlay 或衍生資料 | 本文件                                                            |
| 確認 JSON 與 Seed 應共用的固定 ID                 | [`json-seed-id-mapping.md`](../docs/data/json-seed-id-mapping.md)  |
| 修改 PostgreSQL 開發展示資料                        | [`docs/seed/README.md`](../docs/seed/README.md)                   |
| 確認 API Request／Response 欄位                     | [`docs/api/README.md`](../docs/api/README.md) 與對應 API Contract |
| 確認資料表、ENUM、FK、CHECK                         | [`docs/latest_schema.sql`](../docs/latest_schema.sql)             |

建議閱讀順序：

1. 先看對應 API Contract，確認前後端交換欄位。
2. 需要 Mock 模式時，再依本文件維護 `frontend/data/**`。
3. 需要真後端資料時，依 [`docs/seed/README.md`](../docs/seed/README.md) 維護 `docs/seed/**`。
4. 涉及資料庫欄位或外鍵時，回到 `latest_schema.sql` 驗證，不可從 JSON 反推 Schema。

## 定案摘要（2026-07-09）

| 項目                | 決策                                                                                                                                                         |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 會員訂單查詢        | 刪 `customers.orders[]` / `rentals[]`，改 `orders.customerId` / `camp-bookings.customerId` FK                                                                |
| 租借庫存權威        | `data/admin/rental-skus.json` 為唯一寫入來源 → `sync-rental-listings.cjs` 衍生 `camp-equipment.stock`                                                        |
| 預約窗口            | `bookingWindowDays = 90`                                                                                                                                     |
| 折價券              | 會員中心僅 `birthday` + `firstPurchase`；結帳可輸入 `promotion`                                                                                              |
| 訂單 / 預約         | **下單當下寫快照（B）** + 保留 `productId` / `variantId` 等 FK                                                                                               |
| 訂單付款            | `payment`＝方式（ecpay-credit/ecpay-atm/ecpay-cvs/ecpay-other/cod）；`paymentStatus`＝狀態（unpaid/paid/refunded）；**勿**把 `cod` 寫進 status；預約禁止 COD |
| 商品上下架          | `active` / `inactive`（勿用 `disabled`；`disabled` 僅折價券停用）                                                                                            |
| 會員登入            | 僅 OAuth，**無 `password`**                                                                                                                                  |
| 會員周邊資料        | 地址、偏好選項／指派、會員標籤／指派已搬至 `020-identity.sql`；不作為訂單／預訂成立條件                                                                    |
| 部落格              | `productId` 統一 `P001` 格式、camelCase                                                                                                                      |
| 靜態內容（不進 DB） | FAQ、夥伴營地 `PARTNER_DATA`、`rental-guide.html`                                                                                                            |
| 庫存保留          | 435 訂單明細與 40 租借明細已建立 Seed 保留；Mock 庫存必須與後端扣除 active 保留後的可用量一致                                               |
| 評論                  | 38 筆 Mock 已使用 canonical variant／SKU；只有明確 orderId 且可唯一對到 order item 的評論才可寫入 DB                                                     |
| 庫存異動            | `movement.json` 缺 variant、單一表頭語意與員工主檔對照，目前不搬移                                                                                      |

## 目錄結構

```text
frontend/data/catalog/          products.json, campgrounds.json, camp-equipment.json
frontend/data/commerce/         orders.json, camp-bookings.json
frontend/data/customers/        customers.json, preference-options.json, customer-preferences.json,
                                customer-shipping-addresses.json, customer-tags.json,
                                customer-tag-assignments.json
frontend/data/marketing/        articles.json, branches.json, brands.json
frontend/data/promotions/       coupons.json
frontend/data/admin/            reviews.json, movement.json, min-stock.json, rental-skus.json,
                                booking-policy.json, zone-blocks.json, campground-closures.json
```

磁碟來源位於 `frontend/data/**`；Vite 以 `frontend/` 為網站根目錄，因此瀏覽器執行期使用 `/data/**`。這些 JSON 是前端契約投影，不可在忽略 Schema 欄位與限制的情況下直接複製成 SQL。

## 會員周邊資料

`020-identity.sql` 現為會員周邊展示資料的 canonical Seed；以下 Mock 必須維持同一組固定 ID 與關聯：

| Mock JSON | Schema | 筆數 | 規則 |
| --- | --- | ---: | --- |
| `preference-options.json` | `preference_options` | 18 | ID 1～8 為 `style`，9～18 為 `equipment` |
| `customer-preferences.json` | `customer_preferences` | 200 | U001～U050 各 4 筆；每人 2 種風格、2 種裝備 |
| `customer-shipping-addresses.json` | `customer_shipping_addresses` | 50 | U001～U050 各 1 筆預設地址；`email` 由 `customers.email` 投影 |
| `customer-tags.json` | `customer_tags` | 3 | 固定 ID 1～3，color 保留前端 badge class |
| `customer-tag-assignments.json` | `customer_tag_assignments` | 56 | 複合鍵為 `customerId + tagId` |

這些資料不參與 Checkout 或 Booking 建立；訂單與預訂仍保存各自的收件／營區快照。Seed 變更後應同步上述 JSON，並驗證會員、偏好選項與標籤沒有孤兒、每位會員至多一筆預設地址。

## 庫存、保留與評論投影

- `products.json > variants[].availableQuantity` 是 28 個 active 商品在四個固定商城據點的可用量合計，目前總計 399。資料庫 on-hand 包含 active 保留；API 扣除 `product_stock_reservations.status=active` 後才是這個值。
- `rental-skus.json` 是租借實體 on-hand 投影。本輪已將 9 筆庫存提高到 active 預訂區間的最大重疊數，variant total 與營區匯總仍必須相等。
- `reviews.json` 不得再出現 `v-P...`。Mock 可保留沒有 `orderId` 的展示評論，但後端 `reviews` 只接受可驗證的 `order_item_id`；目前只有 `REV031 → order 208 → item 602081 → V001`。
- `movement.json` 仍是未搬移 Mock，不可直接視為 API 寫入 payload。只有 productId 不足以建立 variant-level 庫存異動。

> `camp-equipment.json` 的 **stock 為唯讀衍生**，請勿手改；改庫存請改 `rental-skus.json` 後執行 `npm run sync:listings`。  
> `products.totalStock` / `products.branch` 亦為衍生（由 `variants[].branch` 加總）。

租借跨層規則：`rental-skus.json` 與 Seed 都使用 `RSV-Rxxx-xx`；C001～C009 分別對應資料庫庫位 `RENTAL-C001`～`RENTAL-C009`。Mock 模式仍由 `rental-skus.json` 衍生 listing stock，Backend 模式則只採 `rental_sku_variant_stocks`。現有 listing 折扣已統一為 `0`，因舊 Mock 固定金額折抵不能直接寫入資料庫折扣比率。

## API 層

| 全域物件                     | 用途                                                                           |
| ---------------------------- | ------------------------------------------------------------------------------ |
| `window.MockDataPaths`       | Storefront Mock JSON 絕對路徑；定義於 `frontend/storefront/js/api-mock.js`     |
| `window.API`                 | 買家 Mock API                                                                  |
| `window.BookingAPI`          | 預約 Mock API（含 `getAvailability`）                                          |
| `window.BookingAvailability` | Zone 可用性計算（mock = 未來 SQL 查詢契約）                                    |
| `AdminAPI`                   | 後台 CRUD（mock 模式讀 DataPaths；`configure({ useBackend: true })` 接真後端） |
| `MockStorageMerge`           | localStorage overlay 合併（**暫時層**，後端以 DB transaction 取代）            |

## 營區與租借庫存 ID

| ID        | 說明                                                             |
| --------- | ---------------------------------------------------------------- |
| C001      | 租借主倉（僅 rental-skus / 後台庫存，**不在** campgrounds.json） |
| C002–C009 | 可預約營區（`campgrounds.json`）                                 |

`rental-skus.camp[]`：`{ campgroundId, name, quantity }`，名稱與 campgrounds 一致（C001 固定「租借主倉」）。

`camp-equipment.campgroundId` 僅能為 C002–C009。  
`camp-bookings.bookingInfo.campgroundId` 同上。

營區公開 API 的 `environmentTags`、`facilityTags` 分別由
`campground_environment_tags → environment_tags.label` 與
`campground_facility_tags → facility_tags.label` 產生；只回 active 標籤，無關聯時固定回 `[]`，供前台搜尋頁篩選。

## 預約可用性（Zone 級）

| 檔案                         | 對應未來 DB 表                        | 說明                                  |
| ---------------------------- | ------------------------------------- | ------------------------------------- |
| `campgrounds.json > zones[]` | `campground_zones`                    | `totalSites` = 庫存上限               |
| `camp-bookings.json`         | `bookings` + `booking_selected_zones` | 佔用來源；區間 `[checkIn, checkOut)`  |
| `booking-policy.json`        | `booking_policies`                    | `bookingWindowDays: 90`、佔用狀態枚舉 |
| `zone-blocks.json`           | `zone_blocks`                         | 維修停售例外（扣減可賣數）            |
| `campground-closures.json`   | `campground_closures`                 | 營區公休（`date_range` 或 `weekly`）  |

公休效果：該營區**所有 zone** 當晚 `status: closed`、`remaining: 0`。

## 折價券規則

| category        | 會員中心列表 | 結帳輸入 | 資格                          |
| --------------- | ------------ | -------- | ----------------------------- |
| `birthday`      | ✅           | ✅       | 當月生日                      |
| `firstPurchase` | ✅           | ✅       | `firstPurchaseUsed === false` |
| `promotion`     | ❌           | ✅       | 活動碼（如 `YURUIKAMP20`）    |

預設：`type: "fixed"`、`minOrder: 0`（缺欄時前端 / 腳本補齊）。

`coupons.json` 已對齊 `050-coupons.sql` 的固定 ID 1～7 與顯示名稱。前端 `startDate`／`endDate` 視為 `Asia/Taipei` 本地時間；SQL 寫入 `timestamptz` 時明確使用 `+08:00`。目前沒有 claim Seed，所以本階段所有 `used` 皆為 `0`；Backend 模式的已領數只採 `coupons.claimed_quantity` 與 claim 流程。

目前 222 筆 `orders.json` 都沒有 `coupons[]`，`discount` 皆為 `0`；資料庫也沒有 `coupon_claims` 或 `order_coupons`。生日／首購資格、券仍在有效期或會員曾經下單，都不能單獨證明已領券。後續只有來源能同時提供 `customerId`、canonical coupon、`claimedAt`、claim 狀態，以及 consumed claim 的訂單／折扣快照時，才能建立關聯；`claimed_quantity` 由資料庫 Trigger 維護，不得由 Mock `used` 反推。

## 訂單 / 預約快照（策略 B）

下單當下寫入顯示用快照，並保留 FK 供關聯：

- 訂單表頭：`buyerName`、`address`、`buyerPhone`（可選）…
- 訂單明細：`name`、`specLabel`、`productId`、`variantId`、`sku`
- 預約：`bookingInfo.campgroundName` / `region`；`selectedRentals[].specLabel` 等
- 券：`order.coupons[]` 快照（code / type / discount / amount）

目前固定展示訂單沒有券快照；上列欄位只適用於未來真正帶有可追溯 `couponClaimId` 的新訂單，不能替舊訂單補造。

`specLabel` 統一分隔符：`/`（非 `、`）。

## localStorage Keys（Mock overlay）

| Key                      | 用途                                                           | 後台 merge             |
| ------------------------ | -------------------------------------------------------------- | ---------------------- |
| `mockOrders`             | Legacy Order 頁面暫存；新 Checkout 不再寫入                    | orders.js ✅           |
| `mockCheckoutSessions`   | 契約化 CheckoutSession、冪等指紋與 Mock 更新／取消             | Checkout facade        |
| `mockBookings`           | 僅 Mock 模式的預約結帳；Backend 模式不讀寫                     | bookings.js ✅         |
| `mockReviews`            | 會員評價                                                       | reviews.js ✅          |
| `mockCustomerOverlay`    | 點數 / 首購 / 個資 patch（語意 ≈ 未來 `PATCH /customers/:id`） | API only               |
| `mockCampgroundClosures` | 公休規則 overlay                                               | booking-calendar.js ✅ |
| `adminEmployees`         | 後台員工帳號                                                   | permissions.js         |

可用性為**查詢結果**，不另存日曆矩陣 JSON。

## Checkout sessionStorage Keys

| Key                        | 用途                      | 清除時機               |
| -------------------------- | ------------------------- | ---------------------- |
| `checkoutIdempotencyKey`   | 建立商城 Checkout 的 UUID | 購物車變更、取消、逾時 |
| `checkoutCartFingerprint`  | 規格 ID 與數量指紋        | 購物車變更、取消、逾時 |
| `checkoutCompletedOrderId` | 建立成功後阻止重複建立    | 購物車變更、取消、逾時 |
| `lastCheckoutSession`      | 暫存完整 Session 與後端金額 | 購物車變更、取消、逾時 |

這些資料只存在目前分頁的 sessionStorage，不是 PostgreSQL Seed，也不是 Mock 業務資料。

I-6 狀態 UI 只讀 `lastCheckoutSession.checkoutStep`、`checkoutExpiresAt` 與 `pricing`。取消或逾時會清除上述四個 key，但不會修改或清空 localStorage 購物車。

## 靜態內容（不進 schema / 不進 DB）

| 內容     | 位置                                               |
| -------- | -------------------------------------------------- |
| FAQ      | `pages/faq.html`、`booking/pages/booking-faq.html` |
| 夥伴營地 | `js/pages/branches.js` → `PARTNER_DATA`            |
| 租借指南 | `booking/pages/rental-guide.html`                  |

## 測試資料 Amy (U001)

- 訂單：依 `orders.customerId === "U001"` 查詢（不再寫在 customers 上）
- 預約：依 `camp-bookings.customerId === "U001"`
- 訂單 `id: 1`（畫面顯示 `ORD-0001`，見 `formatOrderDisplayId`）地址快照：台南市東區長榮路二段200號

## 維護腳本

以下指令從 `frontend/` 執行；可用指令以 `frontend/package.json` 為準：

```powershell
cd frontend
npm run validate:data     # 驗證 Mock FK 與資料規則
npm run check:listings    # 預覽租借 listing 是否需要同步
npm run sync:listings     # 寫入 rental-skus 衍生的 camp-equipment.stock
npm run check:articles    # 預覽文章商品 ID 修正
npm run fix:articles      # 寫入文章商品 ID 修正
npm run check:normalize   # 預覽第一階段資料正規化
npm run normalize:data    # 寫入第一階段資料正規化
```

已移除的一次性整合腳本不再列為操作入口；需要追溯舊遷移流程時請查看 Git 歷史，不要重新建立同名腳本。

## 多規格資料契約

| 層級    | JSON                  | 說明                                                        |
| ------- | --------------------- | ----------------------------------------------------------- |
| SPU     | `products.json`       | `name` 為主名（不含規格）                                   |
| SKU     | `products.variants[]` | `id` 與 `sku` 均採後端 canonical 值（例 `V004-01` / `P004-01`） |
| Listing | `camp-equipment.json` | 每列一個 `equipmentId` + `variantId` + 營區 `stock`（衍生） |
| 訂單    | `orders.items[]`      | `name` + `specLabel` + `variantId` / `sku`                  |

`orders.items[]` 不再使用舊 `v-P...`；active 商品的 `variantId` 必須存在於 `products.variants[].id`，`sku` 必須等於同一 variant 的 `sku`。歷史訂單可以保留已下架商品快照（目前為 P010），但其 product／variant 必須仍存在 PostgreSQL Seed，不能因為不在公開商品 JSON 就改回 legacy ID。預訂天數以 `[checkIn, checkOut)` 計夜，週五、週六計入 `holidayCount`，其餘計入 `weekdayCount`；兩者合計必須等於日期差，快照總額須由目前 zone／listing 定價重算。

## 已移除的舊路徑

以下舊 Mock 路徑已刪除（內容已併入 `frontend/data/**`；需要對照時查 git 歷史）：

- `admin/data/*.json`（含舊檔名 `reantal.json`）
- `booking/data/*.json`
- 根目錄扁平 `data/*.json`、`users.json`
- `equipment-id-map.json`
- `_archive/pre-integration/`（過渡歸檔目錄，已清空）

Mock 來源只改 `frontend/data/**`（Storefront 路徑見 `frontend/storefront/js/api-mock.js`，其他頁面依各自載入設定）。PostgreSQL 開發資料只改 `docs/seed/**`；若兩邊需要相同案例，必須分別依 API Contract 與 Schema 驗證後同步更新。
