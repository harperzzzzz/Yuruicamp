# Admin API Contract（v0.8）

| 欄位 | 內容 |
|------|------|
| **狀態** | Locked（G-1～G-6 已實作） |
| **日期** | 2026-07-22 |
| **版本** | 0.8 |
| **共用** | [`common-api-conventions.md`](./common-api-conventions.md) |
| **Base** | `/api/admin` |
| **認證** | Bearer Firebase ID Token + `admin_users` 白名單 + `active=true` |

---

## 0. 一句話

後台所有 API 走 `/api/admin/**`；每次請求都從角色預設與個人覆寫計算有效權限，管理員帳號管理固定使用 `permissions.view`／`permissions.edit`。

---

## 1. 認證

| 方法 | 路徑 | 說明 |
|------|------|------|
| `POST` | `/api/admin/auth/firebase/session` | 見 [`auth-api-contract.md`](./auth-api-contract.md) |

其餘 `/api/admin/**`：無有效 Admin → `401`／`403`（`ADMIN_NOT_WHITELISTED`／`ADMIN_INACTIVE`）。

### RBAC（G）

| 概念 | DB |
|------|-----|
| 權限碼 | `admin_permissions.code`（如 `orders.view`） |
| 角色映射 | `admin_role_permissions` |
| 檢查時機 | 每個寫入／敏感讀 |

每個 Admin Controller 端點都必須以 `@PreAuthorize` 標註所需 permission；`ROLE_ADMIN` 只代表白名單身分，不代表擁有全部細權限。

---

## 2. 管理員帳號

| 方法 | 路徑 | 權限（建議） | 說明 |
|------|------|--------------|------|
| `POST` | `/api/admin/users` | `permissions.edit` | 用 email 建白名單列（`active=true`，`firebase_uid=null`） |
| `GET` | `/api/admin/users` | `permissions.view` | 分頁列表 |
| `GET` | `/api/admin/users/{id}` | `permissions.view` | 詳情、個別覆寫與有效權限 |
| `PATCH` | `/api/admin/users/{id}` | `permissions.edit` | 改 `active`／`role`／`name` |
| `PUT` | `/api/admin/users/{id}/permissions` | `permissions.edit` | 以完整權限集合取代個別覆寫 |
| `GET` | `/api/admin/permissions` | `permissions.view` | 權限字典與角色預設 |

### `AdminUser`（回應）

| JSON | DB |
|------|-----|
| `id` | `admin_users.id` |
| `email` | `email` |
| `name` | `name` |
| `role` | `admin` \| `operator` \| `warehouse` |
| `active` | boolean |
| `firebaseUid` | string \| null |
| `createdAt` | string |
| `updatedAt` | string |
| `permissionOverrides` | object；詳情回傳 |
| `effectivePermissions` | string[]；詳情回傳 |

**不**回傳密鑰；無密碼欄位。

建立 Request 固定為 `name`、`email`、`role`；ID 由後端產生。Email 建立後不可由一般 PATCH 修改。個別覆寫只保存與角色預設不同的項目，`edit=true` 時同 section 的 `view` 必須也是 true。

禁止停用自己、停用或降級最後一位啟用中的 `admin`，也不提供管理員 DELETE。

---

## 3. Customers

| 方法 | 路徑 | 權限 | 說明 |
|------|------|------|------|
| `GET` | `/api/admin/customers` | `customers.view` | 分頁、篩選與排序 |
| `GET` | `/api/admin/customers/{id}` | `customers.view` | 詳情與唯讀關聯摘要 |
| `PATCH` | `/api/admin/customers/{id}` | `customers.edit` | 更新姓名、電話、生日與點數 |
| `POST` | `/api/admin/customers/{id}/suspend` | `customers.edit` | `active` → `suspended` |
| `POST` | `/api/admin/customers/{id}/reactivate` | `customers.edit` | `suspended` → `active` |

列表參數：`page` 從 `0` 開始，`size` 為 `1`～`100`，並支援 `q`、`status`、`tier`、可重複的 `tagId` 及 `sort`。排序白名單為 `registeredAt`、`totalSpent`、`name`、`points`、`updatedAt`，預設 `registeredAt,desc`。

### `AdminCustomer`（甲）

| JSON | DB |
|------|-----|
| `id` | `customers.id` |
| `name` | `name` |
| `email` | `email` |
| `phone` | string \| null |
| `status` | `active` \| `suspended` \| `deleted` |
| `tier`／`tierName` | |
| `points` | integer |
| `authProvider` | |
| `firebaseUidBound` | boolean；不回傳完整 UID |
| `registeredAt` | |
| `firstPurchaseUsed` | boolean |
| `totalSpent` | `customer_tier_summary.total_spent`，無消費時為 `0.00` |
| `tags` | 詳情與列表的唯讀標籤 |
| `preferences` | 詳情的唯讀偏好 |
| `defaultShippingAddress` | 詳情的唯讀預設地址 |

`tier`、`tierName` 與 `totalSpent` 由資料庫 View 計算，前端不得自行覆蓋。PATCH 不接受 Email、登入來源、Firebase UID、狀態、等級、消費總額或首購狀態。

本切片不提供管理員建立會員、修改 Email、刪除或恢復 deleted 會員；標籤、偏好與地址只讀。停權與恢復使用語意化端點，禁止硬刪。

---

## 4. Orders

| 方法 | 路徑 | 權限 | 說明 |
|------|------|------|------|
| `GET` | `/api/admin/orders` | `orders.view` | 分頁、篩選與排序 |
| `GET` | `/api/admin/orders/{id}` | `orders.view` | 收件快照、商品明細與狀態歷程 |
| `POST` | `/api/admin/orders/{id}/ship` | `orders.edit` | `unshipped` → `shipped` |
| `POST` | `/api/admin/orders/{id}/complete` | `orders.edit` | `shipped` → `completed`；COD 同交易標記 paid |

列表支援 `q`、可重複的 `status`／`paymentStatus`／`paymentMethod`、`placedFrom`／`placedTo` 與 `sort`。排序白名單為 `placedAt`、`total`、`updatedAt`。

線上付款只有 `paid` 且 `refundStatus=none` 才可出貨；COD 可在 unpaid 時出貨，完成時才同步收款。Admin 不得直接改寫 ECPay 付款、退款、訂單內容或任意狀態。

訂單本體欄位對齊 [`order-api-contract.md`](./order-api-contract.md) 的 `Order`。  
狀態轉換必須走狀態機；禁止任意字串 PATCH。

---

## 5. Bookings

| 方法 | 路徑 | 權限 | 說明 |
|------|------|------|------|
| `GET` | `/api/admin/bookings` | `bookings.view` | 分頁、篩選與排序 |
| `GET` | `/api/admin/bookings/{id}` | `bookings.view` | 營位、租借快照與狀態歷程 |
| `POST` | `/api/admin/bookings/{id}/confirm` | `bookings.edit` | 已付款 `pending` → `confirmed` |
| `POST` | `/api/admin/bookings/{id}/complete` | `bookings.edit` | 已退房 `confirmed` → `completed` |

列表支援 `q`、可重複的 `status`／`paymentStatus`／`campgroundId`／`region`、`hasRental`、入住／建立日期範圍與 `sort`。排序白名單為 `createdAt`、`checkIn`、`checkOut`、`finalAmount`、`updatedAt`。

Admin 不能把 unpaid 預約改成 paid。完成預約時會將 active 租借保留標記為 fulfilled；已付款取消與退款留給線 D。

欄位對齊 Booking 契約精簡形狀。

---

## 6. Products（後台寫）

| 方法 | 路徑 | 權限 | 說明 |
|------|------|------|------|
| `GET` | `/api/admin/products` | `products.view` | 含 inactive 商品、規格、圖片與唯讀庫存摘要 |
| `GET` | `/api/admin/products/lookups` | `products.view` | 表單分類與品牌選項，回傳正式 ID |
| `GET` | `/api/admin/products/{id}` | `products.view` | 完整詳情，包含 inactive variants |
| `POST` | `/api/admin/products` | `products.edit` | 同交易建立裝備主檔、商品、規格與圖片 |
| `PUT` | `/api/admin/products/{id}` | `products.edit` | 同交易同步商品、規格與圖片 |
| `POST` | `/api/admin/products/{id}/activate` | `products.edit` | 至少一個 active variant 才能上架 |
| `POST` | `/api/admin/products/{id}/deactivate` | `products.edit` | 下架但保留既有資料與訂單快照 |

列表支援 `page`、`size`、`q`、`status`、`categoryId`、`brandId` 與 `sort`。排序白名單為 `id`、`name`、`createdAt`、`updatedAt`，預設 `id,asc`。

### 建立／更新 Request

```json
{
  "name": "Coleman 六人帳篷",
  "description": "<p>適合露營使用。</p>",
  "categoryId": 1,
  "brandId": "coleman",
  "status": "active",
  "images": [
    {
      "url": "/assets/images/products/P001-1.jpg",
      "altText": "Coleman 六人帳篷"
    }
  ],
  "variants": [
    {
      "id": "V001",
      "sku": "TENT-OLIVE",
      "color": "深橄欖綠",
      "size": null,
      "specification": "深橄欖綠",
      "price": "3200.00",
      "status": "active"
    }
  ]
}
```

- 建立商品時不傳商品、裝備與規格 ID；ID 全由後端產生。
- 更新時既有規格必須帶回 `id`，新規格省略 `id`；DB 已存在但 Request 未出現的規格改為 `inactive`，不硬刪。
- `categoryId` 與 `brandId` 使用 lookup ID。SKU 不可重複，價格不可為負數，同一商品的規格組合不可重複。
- 圖片依陣列順序寫入 `sort_order`，第一張是主圖；G-2c 只接受 `/assets/**` 或 HTTP(S) URL，不處理檔案上傳。
- Request 僅接受上例欄位，**不接受** `branch`、`totalStock`、`inventory`、`rentalEnabled`、`camp`、評價或銷售衍生欄位。

### 回應與資料責任

回應以 `equipment_items` → `products` → `product_variants` → `equipment_images` 組合，並多回 `itemId`、分類／品牌名稱、`createdAt`／`updatedAt`。`variants[]` 會包含 inactive variant，以及由 `inventory_stocks` 與 active reservation 計算的 `onHandQuantity`、`reservedQuantity`、`availableQuantity`、`stockLocations[]`。

庫存欄位在 G-2c **一律唯讀**；建立商品不建立初始庫存，盤點、進貨、損耗與調撥由 G-3 的庫存異動負責。前端只有在後端成功回應後才能更新 cache，錯誤時必須保留原 cache 與 Modal 輸入。

公開讀形狀仍見 Product 契約；inactive 商品的 `GET /api/products/{id}` 回 `404`，既有訂單繼續使用自己的商品與規格快照。

---

## 7. Inventory movements

| 方法 | 路徑 | 權限 | 說明 |
|------|------|------|------|
| `GET` | `/api/admin/inventory-movements` | `movement.view` | 分頁列表，包含 draft／posted／cancelled |
| `GET` | `/api/admin/inventory-movements/lookups` | `movement.view` | active 庫位與商城／租借規格 ID |
| `GET` | `/api/admin/inventory-movements/{id}` | `movement.view` | 表頭、操作者與 SKU／品名快照明細 |
| `POST` | `/api/admin/inventory-movements` | `movement.edit` | 建立 draft，不改庫存 |
| `POST` | `/api/admin/inventory-movements/{id}/items` | `movement.edit` | 只對 draft 新增明細 |
| `POST` | `/api/admin/inventory-movements/{id}/post` | `movement.edit` | 悲觀鎖後原子過帳；重送冪等 |
| `POST` | `/api/admin/inventory-movements/{id}/cancel` | `movement.edit` | 作廢 draft；重送冪等 |

列表支援 `page`、`size`、`q`、`inventoryDomain`、`status`、`movementType` 與 `sort`。排序白名單為 `occurredAt`、`createdAt`、`updatedAt`、`movementNo`，預設 `occurredAt,desc`。

### 建立 draft

```json
{
  "inventoryDomain": "store",
  "movementType": "transfer",
  "sourceLocationId": "STORE-MAIN",
  "destinationLocationId": "STORE-TAIPEI",
  "reason": "門市補貨",
  "occurredAt": "2026-07-22T04:00:00Z"
}
```

`inventoryDomain` 支援 `store`、`rental`。G-3 開放同領域 `receipt`、`write_off`、`transfer`：入庫只有目的庫位、出庫／損耗只有來源庫位、調撥必須有兩個不同且同領域的庫位。跨領域 `conversion_out`／`conversion_in` 不在本契約內。

### 新增明細

```json
{
  "variantId": "V001",
  "quantity": 5
}
```

商城使用 `product_variants.id`，租借使用 `rental_sku_variants.id`。同一異動單不得重複加入同一規格；後端寫入當下 SKU 與品名快照。posted／cancelled 後不得新增明細。

### 過帳規則

- 交易先悲觀鎖定異動表頭，再依 `variantId`、`locationId` 固定順序建立零庫存列並鎖定。
- 所有明細驗證通過後才更新 `inventory_stocks` 或 `rental_sku_variant_stocks`，最後把表頭改為 posted 並記錄 `employeeId`、`postedAt`。
- 來源庫存扣減後不得小於 0，也不得低於 active 保留量；任何一筆不足會回 `409 CONFLICT` 並整筆 rollback。
- posted 重送回放目前結果，不重複加減；cancelled 不得過帳。posted 不可取消，cancelled 重送回放目前結果。
- G-2c 不建立初始庫存；新商品必須由 receipt 草稿加入明細後過帳。
- 租借 active 保留跨日期，G-3 採保守下限：所有 active 租借保留量都視為不可扣除。

異動單本身是不可變庫存歷程；Schema 現有 `employee_id` 保存最後執行過帳或作廢的管理員。若要完整保存建立者與每次狀態事件，需另立 audit history Schema，不在 G-3 現有表結構內。

---

## 8. Coupons（後台）

| 方法 | 路徑 | 權限 | 說明 |
|------|------|------|------|
| `GET` | `/api/admin/coupons` | `discounts.view` | 分頁列表；`q`、`status`、`category`、`sort` |
| `GET` | `/api/admin/coupons/{id}` | `discounts.view` | 詳情與已領取數量 |
| `POST` | `/api/admin/coupons` | `discounts.edit` | 建立 |
| `PATCH` | `/api/admin/coupons/{id}` | `discounts.edit` | 部分更新；`code` 不可修改 |
| `DELETE` | `/api/admin/coupons/{id}` | `discounts.edit` | 只刪除從未領取的優惠券 |

建立 Request：

```json
{
  "code": "SUMMER26",
  "name": "夏日優惠",
  "discountType": "percent",
  "discountValue": "15.00",
  "minimumAmount": "1000.00",
  "issueQuantity": 100,
  "validFrom": "2026-08-01T00:00:00Z",
  "validUntil": "2026-09-01T00:00:00Z",
  "status": "active",
  "category": "promotion"
}
```

回應另含 `id`、`claimedQuantity`、`remainingClaimable`、`createdAt`、`updatedAt`。`discountType` 只接受 `fixed|percent`；`category` 只接受 `promotion|birthday|firstPurchase`。後端統一將 code 正規化為大寫並驗證唯一。`issueQuantity` 不得低於既有 `claimedQuantity`，已有領取歷程時刪除回 `409`，應改用 `PATCH status=disabled`。

---

## 9. Campground closures

| 方法 | 路徑 | 權限 | 說明 |
|------|------|------|------|
| `GET` | `/api/admin/campground-closures` | `booking-calendar.view` | 分頁列表；`q`、`campgroundId`、`closureType`、`sort` |
| `GET` | `/api/admin/campground-closures/{id}` | `booking-calendar.view` | 詳情與建立者 |
| `POST` | `/api/admin/campground-closures` | `booking-calendar.edit` | 建立指定期間或每週公休 |
| `PATCH` | `/api/admin/campground-closures/{id}` | `booking-calendar.edit` | 部分更新 |
| `DELETE` | `/api/admin/campground-closures/{id}` | `booking-calendar.edit` | 刪除並立即停止套用 |

指定期間 Request：

```json
{
  "campgroundId": "C001",
  "closureType": "date_range",
  "startDate": "2026-08-01",
  "endDate": "2026-08-04",
  "weekday": null,
  "effectiveFrom": null,
  "effectiveTo": null,
  "reason": "設備維護"
}
```

每週固定 Request 將 `closureType` 設為 `weekly`，提供 `weekday`（0=日、6=六）及 `effectiveFrom`／`effectiveTo`，日期區間欄位設為 null。指定期間採 `[startDate, endDate)`，結束日不公休且必須晚於開始日；每週生效邊界均包含當日。建立者固定取目前登入管理員，前端不得傳入。

---

## 10. G-6 前端正式 Runtime

- `AppConfig.ADMIN.USE_BACKEND=true` 時，`AdminRuntime` 統一啟用 `/api/admin`，頁面不得各自切換。
- 登入只使用 Firebase Google；development 可用後端 `dev:` stub。登入後呼叫 `POST /api/admin/auth/firebase/session`，以 `effectivePermissions` 初始化 UI。
- Firebase ID Token 不寫入 Web Storage；受保護請求 401 時強制刷新並重送一次，仍失敗才重新登入。
- Reviews 整個模組，以及新增會員、標籤池、seller note、租借商品寫入等未有正式契約的子功能，必須由 readiness gate 停用且不得發出 404 請求。
- SessionStorage 權限只控制 UI；後端每次請求仍依資料庫 RBAC 判斷。

---

## 11. 共用列表慣例

- 分頁：`page`／`size`／`meta`（common）  
- 篩選：各資源自訂 query，白名單欄位  
- 回應 Envelope 與前台相同  

---

## 12. v0.1 不做

| 項目 | 原因 |
|------|------|
| HTML partial 當 API | 前端 `core.js` 舊路徑；後端只供 JSON |
| 圖檔上傳 Cloud Storage | P3 |
| 完整 analytics 報表 API | 可後補；先用既有列表聚合 |

---

## Changelog

| 版本 | 日期 | 說明 |
|------|------|------|
| 0.1 | 2026-07-20 | 後台資源路徑與甲欄位；RBAC 標註要求 |
| 0.2 | 2026-07-21 | G-1、G-5：細 RBAC、管理員建立／列表／詳情／更新與個別覆寫 |
| 0.3 | 2026-07-21 | G-2a：Customers 查詢、更新與停權／恢復 |
| 0.4 | 2026-07-21 | G-2b：Orders／Bookings 查詢與履約狀態命令 |
| 0.5 | 2026-07-22 | G-2c：Products 正規化寫入、規格／圖片同步、唯讀庫存與前端乾淨 Request |
| 0.6 | 2026-07-22 | G-3：商城／租借庫存異動 draft、明細、悲觀鎖過帳、作廢、冪等與 RBAC |
| 0.7 | 2026-07-22 | G-4：優惠券與營區公休 CRUD、安全刪除、RBAC、後端優先前端流程與 PostgreSQL 驗收 |
| 0.8 | 2026-07-22 | G-6：Firebase Admin Session、有效權限初始化、Token 刷新、Backend readiness 與全站正式切換 |
