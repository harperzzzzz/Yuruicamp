# Admin API Contract（v0.4）

| 欄位 | 內容 |
|------|------|
| **狀態** | Locked（G-1、G-2a、G-2b、G-5 已實作） |
| **日期** | 2026-07-21 |
| **版本** | 0.4 |
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

| 方法 | 路徑 | 說明 |
|------|------|------|
| `GET` | `/api/admin/products` | 含 inactive |
| `GET` | `/api/admin/products/{id}` | |
| `POST` | `/api/admin/products` | 建立 SPU（需 `itemId` 或同時建 equipment—實作選一種並升版說明） |
| `PUT`／`PATCH` | `/api/admin/products/{id}` | 改 `status` 等 |
| `POST`／`PATCH` | `/api/admin/products/{id}/variants` | 規格維護 |

公開讀形狀見 Product 契約；後台可多回 `createdAt`／`updatedAt`／inactive variants。

---

## 7. Inventory movements

| 方法 | 路徑 | 說明 |
|------|------|------|
| `GET` | `/api/admin/inventory-movements` | 列表 |
| `POST` | `/api/admin/inventory-movements` | 建立異動（不可變帳；對齊既有 movement 表） |

Request 精簡欄位（實作前對 `store_inventory_movements` 表再鎖一版 v0.1.1 若需要）：

| JSON | 說明 |
|------|------|
| `variantId` | |
| `locationId` | |
| `quantityDelta` | 有號整數或分 in/out |
| `reason` | 非空文字 |

---

## 8. Coupons（後台）

| 方法 | 路徑 | 說明 |
|------|------|------|
| `GET`／`POST` | `/api/admin/coupons` | 列表／建立 |
| `PATCH` | `/api/admin/coupons/{id}` | 改狀態／期間等 |

本體對齊 Coupon 契約主檔欄位。

---

## 9. Campground closures

| 方法 | 路徑 | 說明 |
|------|------|------|
| `GET`／`POST` | `/api/admin/campground-closures` | |
| `PATCH`／`DELETE` | `/api/admin/campground-closures/{id}` | 依表結構 |

欄位對齊 `campground_closures`（`closure_type` 等 ENUM）。

---

## 10. 共用列表慣例

- 分頁：`page`／`size`／`meta`（common）  
- 篩選：各資源自訂 query，白名單欄位  
- 回應 Envelope 與前台相同  

---

## 11. v0.1 不做

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
