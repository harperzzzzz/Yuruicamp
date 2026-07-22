# G-1／G-5 Admin RBAC Swagger 驗證

## 驗證目的

這份流程驗證以下行為：

- Admin Firebase Token 必須通過 email 白名單、`active` 與 Firebase UID 檢查。
- `ROLE_ADMIN` 只代表管理員身分，端點仍會檢查 `permissions.view`／`permissions.edit`。
- 建立管理員只建立白名單，第一次登入時才綁定 Firebase UID。
- 角色預設與個人覆寫會合併成 `effectivePermissions`。
- 停用自己、移除自己的管理權限，以及移除最後一位啟用中管理員都有後端保護。

## 驗證前準備

1. 依 [`docs/seed/README.md`](../../seed/README.md) 載入最新開發 Seed。
2. 確認 PostgreSQL 已啟動，並啟動 Spring Boot Backend。
3. 開啟 `http://localhost:8080/swagger-ui.html`。
4. 確認 `yuruicamp.firebase.enabled=false`，本機才能使用 `dev:` Token。
5. 本流程使用 Seed 內的管理員：

```text
email: booking-seed@example.test
role: admin
active: true
```

首次驗證建議使用固定 Token，避免同一個 email 被不同 UID 重複綁定：

```text
dev:booking-seed-admin:booking-seed@example.test:google:Booking Seed Admin
```

如果此資料庫曾用其他 UID 登入該 email，應重新載入乾淨 Seed，或改用原本已綁定的 UID。已綁定帳號使用不同 UID 時，後端會拒絕登入。

## 第一階段：建立 Admin Session

### 1. 呼叫 Admin Session

在 `Admin Auth` 執行：

```http
POST /api/admin/auth/firebase/session
```

Request Body：

```json
{
  "idToken": "dev:booking-seed-admin:booking-seed@example.test:google:Booking Seed Admin"
}
```

預期結果：

- HTTP `200`。
- `success=true`。
- `data.email` 為 `booking-seed@example.test`。
- `data.role` 為 `admin`。
- `data.firebaseUid` 為 `booking-seed-admin`。
- `data.firebaseUidBound=true`。
- `data.effectivePermissions` 包含 `permissions.view` 與 `permissions.edit`。

這個端點只建立／確認 Admin Session，不會簽發後端 JWT。後續 API 仍使用同一個 Firebase／`dev:` Token。

### 2. 設定 Swagger Authorize

點選 Swagger 右上角 `Authorize`，輸入：

```text
dev:booking-seed-admin:booking-seed@example.test:google:Booking Seed Admin
```

若 Swagger 欄位說明要求完整 Header，再輸入：

```text
Bearer dev:booking-seed-admin:booking-seed@example.test:google:Booking Seed Admin
```

專案的 Bearer Security Scheme 通常只需 Token 本體，Swagger 會自動補上 `Bearer`。

## 第二階段：驗證權限字典

執行：

```http
GET /api/admin/permissions
```

預期結果：

- HTTP `200`。
- `success=true`。
- `data` 共 `20` 筆權限，也就是 `10` 個 section 各有 `view`／`edit`。
- 每筆包含 `code`、`section`、`action` 與 `defaultRoles`。
- `permissions.view` 與 `permissions.edit` 的 `defaultRoles` 包含 `admin`。

預期的完整 permission code：

```text
analytics.view
analytics.edit
orders.view
orders.edit
movement.view
movement.edit
products.view
products.edit
customers.view
customers.edit
discounts.view
discounts.edit
reviews.view
reviews.edit
booking-calendar.view
booking-calendar.edit
bookings.view
bookings.edit
permissions.view
permissions.edit
```

如果回傳不是 `20` 筆，先確認 `docs/seed/dev/010-reference.sql` 是否已載入，不要直接繼續權限覆寫測試。

## 第三階段：建立 Operator 白名單

執行：

```http
POST /api/admin/users
```

Request Body：

```json
{
  "name": "Swagger RBAC Operator",
  "email": "swagger-rbac-operator@example.test",
  "role": "operator"
}
```

預期結果：

- HTTP `200`。
- `data.id` 為後端產生的 `32` 字元 ID，後續以 `OPERATOR_ID` 表示。
- `data.email` 已正規化為小寫。
- `data.role="operator"`。
- `data.active=true`。
- `data.firebaseUid=null`。
- `data.firebaseUidBound=false`。
- `data.permissionOverrides` 初始為空物件。
- `data.effectivePermissions` 是 operator 角色預設權限。

記下回傳的 `data.id`。再次用相同 email 建立時，預期回傳 HTTP `409 CONFLICT`，不能建立重複白名單。

## 第四階段：驗證列表與詳情

### 1. 分頁列表

執行：

```http
GET /api/admin/users?page=0&size=20
```

預期結果：

- HTTP `200`。
- `data` 包含剛建立的 operator。
- `meta.page=0`。
- `meta.size=20`。
- `meta.totalElements` 至少為 `2`。
- 列表是摘要資料，因此 `permissionOverrides` 與 `effectivePermissions` 可以是空集合。

再以 `page=-1` 或 `size=101` 呼叫，預期 HTTP `400 VALIDATION_ERROR`。

### 2. 管理員詳情

將路徑中的 `{id}` 替換成 `OPERATOR_ID`：

```http
GET /api/admin/users/{id}
```

預期結果：

- HTTP `200`。
- `permissionOverrides` 為目前個人覆寫。
- `effectivePermissions` 為角色預設與個人覆寫合併後的結果。
- operator 預設不應擁有 `permissions.view` 或 `permissions.edit`。

不存在的 ID 預期回傳 HTTP `404 NOT_FOUND`。

## 第五階段：設定只讀權限覆寫

`PUT /api/admin/users/{id}/permissions` 使用「完整集合取代」語意，Request 必須包含全部 `20` 個 code，不能只傳要修改的兩個欄位。

執行：

```http
PUT /api/admin/users/{OPERATOR_ID}/permissions
```

Request Body：

```json
{
  "permissions": {
    "analytics.view": true,
    "analytics.edit": false,
    "orders.view": true,
    "orders.edit": true,
    "movement.view": false,
    "movement.edit": false,
    "products.view": false,
    "products.edit": false,
    "customers.view": true,
    "customers.edit": false,
    "discounts.view": true,
    "discounts.edit": false,
    "reviews.view": true,
    "reviews.edit": true,
    "booking-calendar.view": true,
    "booking-calendar.edit": false,
    "bookings.view": true,
    "bookings.edit": true,
    "permissions.view": true,
    "permissions.edit": false
  }
}
```

預期結果：

- HTTP `200`。
- `effectivePermissions` 包含 `permissions.view`。
- `effectivePermissions` 不包含 `permissions.edit`。
- `permissionOverrides` 只保存與 operator 角色預設不同的項目，不一定完整回傳 `20` 個欄位。

額外驗證：

- 少傳任一 permission code，預期 HTTP `400 VALIDATION_ERROR`。
- 多傳不存在的 code，預期 HTTP `400 VALIDATION_ERROR`。
- 將任一 `.edit` 設為 `true`，但同 section 的 `.view` 設為 `false`，預期 HTTP `400 VALIDATION_ERROR`。

## 第六階段：使用 Operator Token 驗證 RBAC

### 1. 第一次登入並綁定 UID

先在 Swagger 的 `Authorize` 清除原本 Admin Token。

執行：

```http
POST /api/admin/auth/firebase/session
```

Request Body：

```json
{
  "idToken": "dev:swagger-rbac-operator:swagger-rbac-operator@example.test:google:Swagger RBAC Operator"
}
```

預期 HTTP `200`，並確認：

- `firebaseUid="swagger-rbac-operator"`。
- `firebaseUidBound=true`。
- `effectivePermissions` 包含 `permissions.view`。
- `effectivePermissions` 不包含 `permissions.edit`。

接著在 Swagger `Authorize` 改用：

```text
dev:swagger-rbac-operator:swagger-rbac-operator@example.test:google:Swagger RBAC Operator
```

### 2. 驗證只讀成功

使用 Operator Token 呼叫：

```http
GET /api/admin/users?page=0&size=20
GET /api/admin/permissions
GET /api/admin/users/{OPERATOR_ID}
```

三個端點都應回 HTTP `200`，證明 `permissions.view` 已在每次請求重新解析並生效。

### 3. 驗證寫入被阻擋

仍使用 Operator Token 呼叫：

```http
POST /api/admin/users
PATCH /api/admin/users/{OPERATOR_ID}
PUT /api/admin/users/{OPERATOR_ID}/permissions
```

預期三者都回 HTTP `403 FORBIDDEN`。這一步是 RBAC 的核心驗證：即使前端顯示或誤觸寫入按鈕，後端仍必須阻擋沒有 `permissions.edit` 的帳號。

## 第七階段：驗證帳號停用即時生效

### 1. 改回 Admin Token

在 Swagger `Authorize` 清除 Operator Token，改回 Seed Admin Token：

```text
dev:booking-seed-admin:booking-seed@example.test:google:Booking Seed Admin
```

### 2. 停用 Operator

執行：

```http
PATCH /api/admin/users/{OPERATOR_ID}
```

Request Body：

```json
{
  "active": false
}
```

預期 HTTP `200`，且 `data.active=false`。

### 3. 使用舊 Operator Token 重試

再次將 Swagger `Authorize` 換成 Operator Token，呼叫：

```http
GET /api/admin/users?page=0&size=20
```

預期回 HTTP `401` 或 `403`，錯誤代碼依 Filter 進入點可能為 `UNAUTHORIZED`、`FORBIDDEN` 或 `ADMIN_INACTIVE`。重點是舊 Token 不得繼續存取 Admin API，證明後端每次請求都會重查帳號啟用狀態。

## 第八階段：驗證管理員保護規則

以下操作必須改回 Seed Admin Token。

### 1. 不可停用自己

先由 `GET /api/admin/users` 找到 `booking-seed@example.test` 的 ID，以下以 `SEED_ADMIN_ID` 表示。

執行：

```http
PATCH /api/admin/users/{SEED_ADMIN_ID}
```

Request Body：

```json
{
  "active": false
}
```

預期 HTTP `409 CONFLICT`，訊息指出不可停用自己的管理員帳號。

### 2. 不可移除自己的 permissions.edit

呼叫：

```http
PUT /api/admin/users/{SEED_ADMIN_ID}/permissions
```

Request 必須仍傳完整 `20` 個 code，但將：

```json
"permissions.view": true,
"permissions.edit": false
```

預期 HTTP `409 CONFLICT`，且原本的 `permissions.edit` 仍然有效。

### 3. 不可移除最後一位啟用中的 admin

只有一位啟用中 `admin` 時，對該帳號執行下列任一操作：

```json
{
  "role": "operator"
}
```

或：

```json
{
  "active": false
}
```

預期 HTTP `409 CONFLICT`。如果資料庫已有其他啟用中的 `admin`，這個情境不成立；應使用乾淨 Seed，或先確認目前啟用中的 admin 數量。

## 驗收完成標準

- Admin Session 能綁定固定 UID，且有效權限包含 `permissions.view／edit`。
- 權限字典完整回傳 `20` 個 code。
- 建立 operator 後維持 `active=true`、`firebaseUid=null`，首次登入才綁定 UID。
- 完整權限集合可讓 operator 取得 `permissions.view`、明確失去 `permissions.edit`。
- Operator 能讀取管理員資料，但所有管理員寫入端點都回 `403`。
- 停用後，舊 Token 立即失效。
- 停用自己、移除自己的管理權限，以及移除最後一位 admin 都回 `409`。

Swagger 驗證可確認 Token、Request JSON、Response Envelope 與端點層 `@PreAuthorize` 能人工串通。角色覆寫合併、悲觀鎖與兩個請求同時修改最後管理員的競爭情境，仍應由 `AdminRbacPostgreSqlIntegrationTest` 驗證，因為 Swagger 無法可靠製造並行交易。
