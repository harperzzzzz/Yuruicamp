# Admin API Contract（v0.15）

| 欄位 | 內容 |
|------|------|
| **狀態** | Locked（G-1～G-6 已實作；W1-01～W1-07 已定案） |
| **日期** | 2026-07-23 |
| **版本** | 0.15 |
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
| `GET` | `/api/admin/customers/{id}` | `customers.view` | 詳情與關聯摘要 |
| `PATCH` | `/api/admin/customers/{id}` | `customers.edit` | 更新姓名、電話、生日與點數 |
| `PUT` | `/api/admin/customers/{id}/tags` | `customers.edit` | **完整集合取代**會員標籤指派（W1-03） |
| `PUT` | `/api/admin/customers/{id}/default-shipping-address` | `customers.edit` | 覆寫預設收件地址（W1-04） |
| `PUT` | `/api/admin/customers/{id}/preferences` | `customers.edit` | **完整集合取代**會員偏好（W1-05） |
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
| `tags` | 詳情與列表的標籤（寫入見 W1-03） |
| `defaultShippingAddress` | 詳情的預設地址；寫入見下方 W1-04 |
| `preferences` | 詳情偏好；寫入見下方 W1-05 |

`tier`、`tierName` 與 `totalSpent` 由資料庫 View 計算，前端不得自行覆蓋。PATCH 不接受 Email、登入來源、Firebase UID、狀態、等級、消費總額或首購狀態。

本切片不提供管理員建立會員、修改 Email、刪除或恢復 deleted 會員。停權與恢復使用語意化端點，禁止硬刪。

### 會員標籤池（Customer Tags／W1-02）

前端舊 Mock 路徑名為 `tag-pool`；正式資源固定為 **`/api/admin/customer-tags`**（對應表 `customer_tags`）。

| 方法 | 路徑 | 權限 | 說明 |
|------|------|------|------|
| `GET` | `/api/admin/customer-tags` | `customers.view` | 標籤池列表；預設只回 `active=true` |
| `GET` | `/api/admin/customer-tags/{id}` | `customers.view` | 單筆詳情 |
| `POST` | `/api/admin/customer-tags` | `customers.edit` | 建立標籤 |
| `PATCH` | `/api/admin/customer-tags/{id}` | `customers.edit` | 更新 name／color／sortOrder／active |
| `DELETE` | `/api/admin/customer-tags/{id}` | `customers.edit` | 硬刪；**有指派時禁止** |

列表參數：

| 參數 | 說明 |
|------|------|
| `includeInactive` | boolean，預設 `false`；`true` 時含停用標籤 |
| 排序 | 固定 `sort_order ASC, id ASC`（本版不開放自訂 sort） |

#### `AdminCustomerTag`（甲）

| JSON | DB | 規則 |
|------|-----|------|
| `id` | `customer_tags.id` | |
| `name` | `name` | 必填；trim 後 1～100 字；**UNIQUE**；重複 → `409 CONFLICT` |
| `color` | `color` | 必填；自由字串上限 **32**（常用 Bootstrap badge class，例如 `bg-success`） |
| `sortOrder` | `sort_order` | integer ≥ 0；建立時可省略，預設 `0` |
| `active` | `active` | boolean；建立時可省略，預設 `true` |
| `createdAt`／`updatedAt` | | Instant |

建立 Request：

```json
{ "name": "VIP", "color": "bg-success", "sortOrder": 10, "active": true }
```

更新 Request（皆可選；未傳的欄位保留原值）：

```json
{ "name": "高消費", "color": "bg-warning text-dark", "sortOrder": 1, "active": false }
```

| 規則 | 說明 |
|------|------|
| 刪除 | 無任何 `customer_tag_assignments` 列才允許硬刪 |
| 有指派 | `DELETE` → `409 CONFLICT`，訊息指引改 `PATCH` 設 `active=false` |
| 停用 | `active=false` 後，會員詳情／列表既有讀模型只顯示 active 標籤（與 G-2a 一致） |
| 權限 | 沿用 `customers.*`，不另開 permission code |

### 會員標籤指派（W1-03）

對單一會員做**集合取代**（replace），寫入表 `customer_tag_assignments`。標籤字典 CRUD 見上方「會員標籤池」。

```http
PUT /api/admin/customers/{id}/tags
```

Request：

```json
{ "tagIds": [1, 3] }
```

| 規則 | 說明 |
|------|------|
| 語意 | body 出現的 id → 建立指派；未出現的既有指派 → 刪除；`tagIds: []` → 清空全部 |
| 去重 | 重複 id 視為同一個（後端可去重） |
| 驗證 | 每個 id 必須存在且 `active=true`；否則 → `400 VALIDATION_ERROR` |
| 不存在會員 | `404` |
| deleted 會員 | `409 CONFLICT`（與基本資料 PATCH 一致） |
| 回應 | 成功後回**完整** `AdminCustomer` 詳情（含更新後 `tags[]`） |
| 列表篩選 | 既有 `GET /customers?tagId=` 兩段式讀模型不變；指派後立即生效 |
| 併發 | 交易內鎖定會員主檔（`FOR UPDATE`）再改 assignment |

### 會員預設地址（W1-04）

寫入表 `customer_shipping_addresses` 中該會員 `is_default=true` 的那一列。**不得**改寫既有訂單的 `shipping_*_snapshot`／`recipient_name_snapshot`。

```http
PUT /api/admin/customers/{id}/default-shipping-address
```

Request（全部必填；完整覆寫，非 PATCH 局部欄位）：

```json
{
  "recipientName": "王小華",
  "postalCode": "100",
  "city": "臺北市",
  "district": "中正區",
  "addressLine": "忠孝西路一段 1 號",
  "phone": "0912345678"
}
```

| JSON | DB | 規則 |
|------|-----|------|
| `recipientName` | `recipient_name` | trim 後 1～100 字 |
| `postalCode` | `postal_code` | trim 後 1～10 字 |
| `city` | `city` | trim 後 1～50 字 |
| `district` | `district` | trim 後 1～50 字 |
| `addressLine` | `address_line` | trim 後 1～300 字 |
| `phone` | `phone` | 必須符合 `^09\d{8}$`（台灣手機 09 開頭 10 碼） |

| 規則 | 說明 |
|------|------|
| 語意 | 有預設列 → `UPDATE`；無預設列 → `INSERT` 且 `is_default=true` |
| 不存在會員 | `404` |
| deleted 會員 | `409 CONFLICT` |
| 非法／缺必填 | `400 VALIDATION_ERROR`（含 Bean Validation） |
| 回應 | 成功後回**完整** `AdminCustomer` 詳情（含更新後 `defaultShippingAddress`） |
| 鐵則 | 本 API **只**動 `customer_shipping_addresses`；已成立訂單快照地址不變 |
| 併發 | 交易內鎖定會員主檔（`FOR UPDATE`）再改地址 |

詳情讀取形狀（`AdminCustomerAddress`）：

| JSON | DB |
|------|-----|
| `id` | `customer_shipping_addresses.id` |
| `recipientName` | `recipient_name` |
| `postalCode` | `postal_code` |
| `city` | `city` |
| `district` | `district` |
| `addressLine` | `address_line` |
| `phone` | `phone` |

### 會員偏好（W1-05）

對單一會員做**集合取代**（replace），寫入表 `customer_preferences`。偏好選項主檔 `preference_options` **本季不做 Admin CRUD**；前端只能勾選既有 active 選項（lookup 見下）。

```http
PUT /api/admin/customers/{id}/preferences
```

Request：

```json
{ "optionIds": [2, 5, 9, 11] }
```

| 規則 | 說明 |
|------|------|
| 語意 | body 出現的 id → 建立關聯；未出現的既有關聯 → 刪除；`optionIds: []` → 清空全部 |
| 去重 | 重複 id 視為同一個（後端可去重） |
| 驗證 | 每個 id 必須存在且 `active=true`；否則 → `400 VALIDATION_ERROR` |
| 不存在會員 | `404` |
| deleted 會員 | `409 CONFLICT`（與基本資料 PATCH／標籤指派一致） |
| 回應 | 成功後回**完整** `AdminCustomer` 詳情（含更新後 `preferences`） |
| 併發 | 交易內鎖定會員主檔（`FOR UPDATE`）再改關聯 |

詳情讀取形狀（`preferences`）：依 `preference_options.type` 分組，值為 **code**（不是 id／label）：

```json
{
  "styles": ["backpacking", "hiking"],
  "equipment": ["tent", "backpack"]
}
```

| JSON key | `preference_options.type` | 值 |
|----------|---------------------------|-----|
| `styles` | `style` | `code` 陣列，依 `sort_order, id` |
| `equipment` | `equipment` | 同上 |

#### 偏好選項 Lookup（唯讀）

| 方法 | 路徑 | 權限 | 說明 |
|------|------|------|------|
| `GET` | `/api/admin/preference-options` | `customers.view` | 可勾選清單；預設只回 `active=true` |

列表參數：

| 參數 | 說明 |
|------|------|
| `includeInactive` | boolean，預設 `false`；`true` 時含停用選項（一般編輯 UI 不需要） |
| 排序 | 固定 `type ASC, sort_order ASC, id ASC` |

#### `AdminPreferenceOption`（甲）

| JSON | DB |
|------|-----|
| `id` | `preference_options.id` |
| `type` | `style` \| `equipment` |
| `code` | `code` |
| `label` | `label` |
| `sortOrder` | `sort_order` |
| `active` | `active` |

---

## 4. Orders

| 方法 | 路徑 | 權限 | 說明 |
|------|------|------|------|
| `GET` | `/api/admin/orders` | `orders.view` | 分頁、篩選與排序 |
| `GET` | `/api/admin/orders/{id}` | `orders.view` | 收件快照、商品明細、狀態歷程與 `internalNote` |
| `POST` | `/api/admin/orders/{id}/ship` | `orders.edit` | `unshipped` → `shipped` |
| `POST` | `/api/admin/orders/{id}/complete` | `orders.edit` | `shipped` → `completed`；COD 同交易標記 paid |
| `PATCH` | `/api/admin/orders/{id}/internal-note` | `orders.edit` | 覆寫主檔內部備註；不改履約／付款狀態 |

列表支援 `q`、可重複的 `status`／`paymentStatus`／`paymentMethod`、`placedFrom`／`placedTo` 與 `sort`。排序白名單為 `placedAt`、`total`、`updatedAt`。

線上付款只有 `paid` 且 `refundStatus=none` 才可出貨；COD 可在 unpaid 時出貨，完成時才同步收款。Admin 不得直接改寫 ECPay 付款、退款、訂單內容或任意狀態。

訂單本體欄位對齊 [`order-api-contract.md`](./order-api-contract.md) 的 `Order`。  
狀態轉換必須走狀態機；禁止任意字串 PATCH。

### 內部備註（Orders）

Request：

```json
{ "internalNote": "已電聯客人，改週三出貨" }
```

| 規則 | 說明 |
|------|------|
| 欄位 | 只接受 `internalNote`（string｜null） |
| 長度 | 最多 **2000** 字元；超過 → `400 VALIDATION_ERROR` |
| 空白 | 空白字串或只含空白 → 存成 DB `null`（清除備註） |
| 寫入 | 只更新 `orders.internal_note` 與 `updated_at` |
| 讀取 | **詳情必回** `internalNote`（string｜null）；**列表省略** |
| 錯誤 | 不存在 → `404`；無權限 → `403` |

`internalNote` **不是** `order_status_history.note`（後者僅在 ship／complete 等狀態轉換時寫入）。

---

## 5. Bookings

| 方法 | 路徑 | 權限 | 說明 |
|------|------|------|------|
| `GET` | `/api/admin/bookings` | `bookings.view` | 分頁、篩選與排序 |
| `GET` | `/api/admin/bookings/{id}` | `bookings.view` | 營位、租借快照、狀態歷程與 `internalNote` |
| `POST` | `/api/admin/bookings/{id}/confirm` | `bookings.edit` | 已付款 `pending` → `confirmed` |
| `POST` | `/api/admin/bookings/{id}/complete` | `bookings.edit` | 已退房 `confirmed` → `completed` |
| `PATCH` | `/api/admin/bookings/{id}/internal-note` | `bookings.edit` | 覆寫主檔內部備註；不改履約／付款狀態 |

列表支援 `q`、可重複的 `status`／`paymentStatus`／`campgroundId`／`region`、`hasRental`、入住／建立日期範圍與 `sort`。排序白名單為 `createdAt`、`checkIn`、`checkOut`、`finalAmount`、`updatedAt`。

Admin 不能把 unpaid 預約改成 paid。完成預約時會將 active 租借保留標記為 fulfilled；已付款取消與退款留給線 D。

欄位對齊 Booking 契約精簡形狀。

### 內部備註（Bookings）

規則與 Orders 相同：`PATCH .../internal-note`、最多 2000 字、空白清成 `null`、詳情必回、列表省略。  
寫入目標為 `bookings.internal_note`，**不是** `booking_status_history.note`。

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

### 最低庫存閾值（Min-stocks／W1-07）

> 只寫 `product_variant_min_stocks`／`rental_sku_variant_min_stocks` 的 `minimum_quantity`。  
> **不**改 `inventory_stocks`／`rental_sku_variant_stocks` 的 `on_hand`，也**不**建立庫存異動單。

| 方法 | 路徑 | 權限 | 說明 |
|------|------|------|------|
| `GET` | `/api/admin/min-stocks` | `products.view` | 依 domain／規格／庫位查詢閾值 |
| `PUT` | `/api/admin/min-stocks` | `products.edit` | 批次 upsert（variant × location） |

**定案 RBAC**：讀 `products.view`、寫 `products.edit`（門檻屬商品營運；**不**用 `movement.edit`）。

#### Query（GET）

| 參數 | 必填 | 說明 |
|------|------|------|
| `inventoryDomain` | 是 | `store` \| `rental` |
| `variantId` | 否 | 商城＝`product_variants.id`；租借＝`rental_sku_variants.id` |
| `locationId` | 否 | `inventory_locations.id`（租借為 `RENTAL-C00x`，不是營區 `C00x`） |
| `productId` | 否 | 商城＝`products.id`；租借＝`rental_skus.id`（縮短列表範圍） |

#### Response item

```json
{
  "inventoryDomain": "store",
  "variantId": "V001",
  "productId": "P001",
  "locationId": "main",
  "minimumQuantity": 5,
  "updatedAt": "2026-07-23T02:00:00Z"
}
```

`GET`／`PUT` 的 `data` 皆為 item 陣列。沒有列＝尚未設定（前端可用預設值，例如 5）。

#### Upsert Request（PUT）

```json
{
  "inventoryDomain": "store",
  "items": [
    {
      "variantId": "V001",
      "locationId": "main",
      "minimumQuantity": 5
    }
  ]
}
```

| 規則 | 行為 |
|------|------|
| `minimumQuantity` | 整數且 ≥ 0；負數 → `400 VALIDATION_ERROR` |
| `items` 空白 | `400 VALIDATION_ERROR` |
| 同一請求重複 `(variantId, locationId)` | `400 VALIDATION_ERROR` |
| variant 不存在 | `404 NOT_FOUND` |
| location 不存在／停用 | `404 NOT_FOUND` |
| location 的 `inventory_domain` 與請求 domain 不符 | `400 VALIDATION_ERROR` |
| 已存在列 | 更新 `minimum_quantity` 與 `updated_at` |
| 不存在列 | INSERT |

商城寫入時固定 `inventory_domain='store'`（對齊表 CHECK）。本 API **禁止**夾帶或回寫任何 on-hand／異動欄位。

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

## 8. Reviews（後台／W1-06）

定案 **A**：列表＋詳情＋**硬刪整則**。不做回覆、不做軟隱藏／visible 旗標。  
讀模型可對齊線 H 公開評價（`review_dto_view` 概念）；本版 Admin 回扁平 JSON。

| 方法 | 路徑 | 權限 | 說明 |
|------|------|------|------|
| `GET` | `/api/admin/reviews` | `reviews.view` | 分頁、篩選與排序 |
| `GET` | `/api/admin/reviews/{id}` | `reviews.view` | 詳情（含 photos） |
| `DELETE` | `/api/admin/reviews/{id}` | `reviews.edit` | 硬刪整則；`review_photos` 依 FK CASCADE 一併刪 |

列表參數：`page`（預設 0）、`size`（1～100，預設 20）、`q`（比對 id／買家／商品名／評論）、`productId`、`rating`（1～5 精確值）、`createdFrom`／`createdTo`（Instant，含邊界）、`sort`。  
排序白名單：`createdAt`、`rating`；預設 `createdAt,desc`。

#### `AdminReview`（甲）

| JSON | 來源 |
|------|------|
| `id` | `reviews.id` |
| `orderItemId` | `reviews.order_item_id` |
| `orderId` | `order_items.order_id` |
| `customerId` | `orders.customer_id` |
| `productId`／`variantId`／`sku` | 訂單明細快照／欄位 |
| `productName` | `order_items.product_name_snapshot` |
| `buyerName` | `orders.buyer_name_snapshot` |
| `buyerAvatar` | `customers.avatar_url`（可 null） |
| `rating` | 1～5 |
| `comment` | string｜null |
| `photos` | `string[]`（URL，依 `sort_order`） |
| `verifiedPurchase` | 固定 `true`（正式評價皆已購） |
| `createdAt` | Instant |

| 規則 | 說明 |
|------|------|
| 列表 | 兩段式：先分頁取 review id，再組 photos（避免 N:M 放大列數） |
| 刪除 | `DELETE FROM reviews`；photos 由 `ON DELETE CASCADE` 清除 |
| 不存在 | `404` |
| 本版不做 | reply、軟刪、visible、管理員代客寫評價 |

---

## 9. Coupons（後台）

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

## 10. Campground closures

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

## 11. G-6 前端正式 Runtime

- `AppConfig.ADMIN.USE_BACKEND=true` 時，`AdminRuntime` 統一啟用 `/api/admin`，頁面不得各自切換。
- 登入只使用 Firebase Google；development 可用後端 `dev:` stub。登入後呼叫 `POST /api/admin/auth/firebase/session`，以 `effectivePermissions` 初始化 UI。
- Firebase ID Token 不寫入 Web Storage；受保護請求 401 時強制刷新並重送一次，仍失敗才重新登入。
- 新增會員、租借商品寫入等未有正式契約的子功能，必須由 readiness gate 停用且不得發出 404 請求。
- Reviews 列表／詳情／硬刪已就緒（`reviews` section ready；feature `reviews.manage=true`）。不做回覆／軟隱藏。
- 訂單／預約內部備註（`internal-note`）已就緒；前端可用 `orders.sellerNote`／`bookings.sellerNote` feature readiness。
- 會員標籤池與指派均已就緒（`customers.tagPool=true`、`customers.tagAssign=true`）。
- 會員預設地址可編已就緒（`customers.defaultAddress=true`）；成功後刷新詳情，失敗保留草稿。
- 會員偏好可編已就緒（`customers.preferences=true`）；選項來源 `GET /preference-options`。
- 最低庫存閾值已就緒（`products.minStock=true`）；on-hand 仍唯讀，須經 G-3 異動。
- SessionStorage 權限只控制 UI；後端每次請求仍依資料庫 RBAC 判斷。
- **已知延後（W2 UI，詳見 [`plans/admin-post-g6/w2/W2-ui-followups.md`](../../plans/admin-post-g6/w2/W2-ui-followups.md)）**：舊版 `products.js` 租借整頁（定價／上架）尚未改新資料模型；「調撥到租借」Modal 仍是前端記憶體、尚未打 `inventory-conversions`。

---

## 12. 共用列表慣例

- 分頁：`page`／`size`／`meta`（common）  
- 篩選：各資源自訂 query，白名單欄位  
- 回應 Envelope 與前台相同  

---

## 13. v0.1 不做

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
| 0.2 | 2026-07-21 | G-1、G-5：細 RBAC、管理員建立／列表／詳情與個別覆寫 |
| 0.3 | 2026-07-21 | G-2a：Customers 查詢、更新與停權／恢復 |
| 0.4 | 2026-07-21 | G-2b：Orders／Bookings 查詢與履約狀態命令 |
| 0.5 | 2026-07-22 | G-2c：Products 正規化寫入、規格／圖片同步、唯讀庫存與前端乾淨 Request |
| 0.6 | 2026-07-22 | G-3：商城／租借庫存異動 draft、明細、悲觀鎖過帳、作廢、冪等與 RBAC |
| 0.7 | 2026-07-22 | G-4：優惠券與營區公休 CRUD、安全刪除、RBAC、後端優先前端流程與 PostgreSQL 驗收 |
| 0.8 | 2026-07-22 | G-6：Firebase Admin Session、有效權限初始化、Token 刷新、Backend readiness 與全站正式切換 |
| 0.9 | 2026-07-23 | W1-01：Orders／Bookings `PATCH .../internal-note`；詳情回 `internalNote`；空白清成 null |
| 0.10 | 2026-07-23 | W1-02：`/api/admin/customer-tags` CRUD；有指派禁硬刪改停用；readiness 拆 `tagPool`／`tagAssign` |
| 0.11 | 2026-07-23 | W1-03：`PUT /api/admin/customers/{id}/tags` 集合取代指派；只能掛 active 標籤 |
| 0.12 | 2026-07-23 | W1-07：`GET`／`PUT /api/admin/min-stocks`；RBAC `products.view`／`products.edit`；不改 on_hand |
| 0.13 | 2026-07-23 | W1-04：`PUT /api/admin/customers/{id}/default-shipping-address`；不改訂單 snapshot；readiness `customers.defaultAddress` |
| 0.14 | 2026-07-23 | W1-05：`PUT /api/admin/customers/{id}/preferences` 集合取代；`GET /preference-options` lookup；只能掛 active options |
| 0.15 | 2026-07-23 | W1-06：`GET`／`DELETE /api/admin/reviews`；硬刪整則；不做回覆／軟隱藏 |