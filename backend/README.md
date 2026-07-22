# Yuruicamp Backend（線 A 骨架）

Spring Boot **4.1.0** / Java **25** / PostgreSQL 16。

## 認證定案（重要）

- 前端使用 **Firebase Auth** 登入後取得 **ID Token**。
- 後端用 **Firebase Admin SDK**（或本機 `dev:` stub）**只驗證** Token。
- 後端**不簽發**自家 JWT。
- 後續 API：`Authorization: Bearer <Firebase ID Token>`。

## 啟動前

1. 本機 Postgres（repo 根目錄）：

   ```powershell
   docker compose up -d
   ```

2. 設定 DB 密碼環境變數（與 `.env` 的 `POSTGRES_PASSWORD` 一致），例如：

   ```powershell
   $env:DB_PASSWORD = "你的密碼"
   ```

3. （可選）啟用真 Firebase：

   ```powershell
   $env:FIREBASE_ENABLED = "true"
   $env:FIREBASE_CREDENTIALS = "C:\path\to\serviceAccount.json"
   $env:FIREBASE_PROJECT_ID = "yuruicamp-2026"   # 建議與前端／service account 一致
   ```

## 啟動

```powershell
cd backend
.\mvnw.cmd spring-boot:run
```

- Health：`GET http://localhost:8080/api/health`
- Swagger：`http://localhost:8080/swagger-ui.html`

## Dev stub Token（`FIREBASE_ENABLED=false`，預設）

格式：

```text
dev:<uid>:<email>:<provider>:<displayName>
```

`provider` 只能是 `google` / `facebook` / `line`。

範例：

```powershell
# 建立／綁定會員 session
curl -X POST http://localhost:8080/api/auth/firebase/session `
  -H "Content-Type: application/json" `
  -d "{\"idToken\":\"dev:uid-amy:amy@example.com:google:Amy\"}"

# 之後帶同一個 token
curl http://localhost:8080/api/me `
  -H "Authorization: Bearer dev:uid-amy:amy@example.com:google:Amy"
```

## 後台 session

- Email 必須**事先**存在於 `admin_users`（白名單）。
- `active=true`；首次登入綁定 `firebase_uid`。
- 端點：`POST /api/admin/auth/firebase/session`

## 測試

```powershell
# 單元測試（不需 DB）
.\mvnw.cmd test

# 含 contextLoads（需 Docker Postgres + 密碼）
$env:RUN_BACKEND_IT = "true"
$env:DB_PASSWORD = "你的 POSTGRES_PASSWORD"
.\mvnw.cmd test
```

## 後端進度

後端流程文件放在 `docs/backend-specs/`，使用「用途、流程、規則、驗證結果」的簡短格式。

| 項目 | 狀態 |
|------|------|
| package 分層、CORS、OpenAPI | ✅ |
| 統一 Envelope／錯誤 | ✅ |
| Firebase ID Token Security | ✅ |
| Customer／Admin session | ✅ |
| MapStruct | ✅ |
| **B-1～B-3 商品公開讀** | ✅ 列表、詳情、PostgreSQL 分頁／排序與錯誤 Envelope；見 [`B-3 驗收文件`](../docs/backend-specs/catalog/b3-product-pagination-validation.md) |
| **B-5a 基本商品規格** | ✅ `variants[]` 已隨商品列表／詳情回傳；只含 active variant 與字串價格 |
| **B-5b 規格可售庫存** | ⬜ 尚未建立 variant 層級庫存讀模型與 API 欄位；見 [`B-5 狀態文件`](../docs/backend-specs/catalog/b5-product-variants-stock-status.md) |
| **C-1 訂單／明細／庫存保留 Entity** | ✅ Hibernate `ddl-auto=validate` 已通過；見 [`C-1 驗收文件`](../docs/backend-specs/order/c1-entity-schema-validation.md) |
| **C-2～C-8 Checkout** | ✅ 建立冪等、防超賣、更新、取消、後端計價、15 分鐘逾時與 PostgreSQL 整合驗收均完成；優惠券套用尚待 F-2；見 [`Checkout 整合文件`](../docs/backend-specs/checkout/README.md) |
| API 契約索引（P0+P1） | [`docs/api/README.md`](../docs/api/README.md) |
| 商品契約（已實作） | [`docs/api/product-api-contract.md`](../docs/api/product-api-contract.md) |
| 代辦清單 A～J | [`plans/backend-implementation-checklist.md`](../plans/backend-implementation-checklist.md) |
| 結帳／ECPay／細 RBAC | 🔄 Checkout 線 C 已完成；優惠券、Payment 與細 RBAC 待實作 |

### Schema 整合驗證

`RUN_BACKEND_IT=true` 時，`BackendApplicationTests` 會連線 Docker PostgreSQL 並載入完整 Spring Context；因 `ddl-auto=validate`，Context 成功即代表目前所有 JPA Entity 已通過 Schema 驗證。

`DB_PASSWORD` 必須與 Docker `.env` 的 `POSTGRES_PASSWORD` 相同。若出現 `password authentication failed`，先修正連線密碼；不要修改 Entity，也不要將 `ddl-auto` 改成 `update`。

### 開發用資料種子

全新 Docker volume 會自動跑 [`docs/seed/002-dev-seed.sql`](../docs/seed/002-dev-seed.sql)，依序建立商品參考資料、商品目錄，以及 `V001` 的 `10` 件 Checkout 開發庫存。結構與 AI／開發者維護規則見 [`docs/seed/README.md`](../docs/seed/README.md)。
既有資料庫請手動灌一次：

```powershell
# 先讓 compose 套用 runner 與 dev/ 的唯讀掛載，再執行唯一入口
docker compose up -d
docker exec yuruicamp-db psql -U postgres -d yuruicamp -f /docker-entrypoint-initdb.d/002-dev-seed.sql
```

重跑會將 `DEV-STORE-MAIN` 的 `V001` 現有庫存更新為 `10`，請先確認不需要保留手動測試狀態。

驗收：

```powershell
curl.exe http://localhost:8080/api/products
curl.exe http://localhost:8080/api/products/P001
```

## 設定鍵

見 `src/main/resources/application.properties`：

- `DB_URL` / `DB_USERNAME` / `DB_PASSWORD`
- `FIREBASE_ENABLED` / `FIREBASE_CREDENTIALS`
- `YURUICAMP_CHECKOUT_EXPIRATION_SCAN_MS` 對應 `yuruicamp.checkout.expiration-scan-ms`（預設 `60000` 毫秒）
- `YURUICAMP_CHECKOUT_EXPIRATION_ENABLED` 對應 `yuruicamp.checkout.expiration-enabled`（預設 `true`）
- `CORS_ALLOWED_ORIGINS`
