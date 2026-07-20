# Admin API Contract（v0.1）

| 欄位 | 內容 |
|------|------|
| **狀態** | Locked（線 G 待實作；auth session 已有） |
| **日期** | 2026-07-20 |
| **版本** | 0.1 |
| **共用** | [`common-api-conventions.md`](./common-api-conventions.md) |
| **Base** | `/api/admin` |
| **認證** | Bearer Firebase ID Token + `admin_users` 白名單 + `active=true` |

---

## 0. 一句話

後台所有 API 走 `/api/admin/**`；骨架已能登入；本契約鎖 **資源路徑與精簡欄位（甲）**；細 RBAC（`section.view`／`section.edit`）為 G 必做。

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

v0.1 契約要求：實作時 **每個端點**標註所需 permission；未標註不得上線。  
過渡期（僅白名單）須在 OpenAPI description 註明 `RBAC: whitelist-only`。

---

## 2. 管理員帳號

| 方法 | 路徑 | 權限（建議） | 說明 |
|------|------|--------------|------|
| `POST` | `/api/admin/users` | `admins.edit` | 用 email 建白名單列（`active=true`，`firebase_uid=null`） |
| `GET` | `/api/admin/users` | `admins.view` | 列表 |
| `PATCH` | `/api/admin/users/{id}` | `admins.edit` | 改 `active`／`role`／`name` |

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

**不**回傳密鑰；無密碼欄位。

---

## 3. Customers

| 方法 | 路徑 | 說明 |
|------|------|------|
| `GET` | `/api/admin/customers` | 列表（分頁） |
| `GET` | `/api/admin/customers/{id}` | 詳情 |
| `POST` | `/api/admin/customers` | 建立（若業務需要；OAuth 會員多半由前台 session 建） |
| `PATCH` | `/api/admin/customers/{id}` | 更新可編輯欄位／停權 |

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
| `firebaseUid` | string \| null |
| `registeredAt` | |
| `firstPurchaseUsed` | boolean |

舊 Mock 的 tags／preferences 矩陣：**另端點或 v0.2**；v0.1 可不嵌。

軟刪：走狀態，禁止硬刪。

---

## 4. Orders

| 方法 | 路徑 | 說明 |
|------|------|------|
| `GET` | `/api/admin/orders` | 列表（篩選 status／paymentStatus） |
| `GET` | `/api/admin/orders/{id}` | 詳情（同 Order 契約 + 可加 history） |
| `PATCH` | `/api/admin/orders/{id}/ship` | → `shipped` |
| `PATCH` | `/api/admin/orders/{id}/complete` | → `completed`；COD 可於此標 `paid`（規則寫死在 Service） |
| `PATCH` | `/api/admin/orders/{id}` | 有限欄位（如備註，若 DB 有對應欄；**無則 v0.2**） |

訂單本體欄位對齊 [`order-api-contract.md`](./order-api-contract.md) 的 `Order`。  
狀態轉換必須走狀態機；禁止任意字串 PATCH。

---

## 5. Bookings

| 方法 | 路徑 | 說明 |
|------|------|------|
| `GET` | `/api/admin/bookings` | 列表 |
| `GET` | `/api/admin/bookings/{id}` | 詳情 |
| `PATCH` | `/api/admin/bookings/{id}` | 允許的狀態轉換／備註（狀態機） |

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
