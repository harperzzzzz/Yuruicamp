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

| 項目                                | 狀態                                                                                                                                                                                                                                                     |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| package 分層、CORS、OpenAPI         | ✅                                                                                                                                                                                                                                                       |
| 統一 Envelope／錯誤                 | ✅                                                                                                                                                                                                                                                       |
| Firebase ID Token Security          | ✅                                                                                                                                                                                                                                                       |
| Customer／Admin session             | ✅                                                                                                                                                                                                                                                       |
| MapStruct                           | ✅                                                                                                                                                                                                                                                       |
| **B-1～B-4 商品公開讀**             | ✅ 列表、詳情、分頁、排序及分類／品牌／價格篩選；未指定篩選會使用明確型別預設值，避免 PostgreSQL `lower(bytea)`；見 [`Catalog 文件`](../docs/backend-specs/catalog/b4-b5b-b7-catalog-public-read.md)                                                      |
| **B-5a 基本商品規格**               | ✅ `variants[]` 已隨商品列表／詳情回傳；只含 active variant 與字串價格                                                                                                                                                                                   |
| **B-5b 規格可售庫存**               | ✅ variant 層級加總商城庫存並扣除 active 保留量；回傳 `availableQuantity`／`inStock`                                                                                                                                                                  |
| **B-7 門市公開讀**                  | ✅ `GET /api/branches`；見 [`Branch 契約`](../docs/api/branch-api-contract.md) 與 [`Swagger 流程`](../docs/backend-specs/test/b-catalog-public-swagger.md)                                                                                              |
| **C-1 訂單／明細／庫存保留 Entity** | ✅ Hibernate `ddl-auto=validate` 已通過；見 [`C-1 驗收文件`](../docs/backend-specs/order/c1-entity-schema-validation.md)                                                                                                                                 |
| **C-2～C-8 Checkout**               | ✅ 建立冪等、防超賣、更新、取消、後端計價、15 分鐘逾時與 PostgreSQL 整合驗收均完成；F-2 已補齊優惠券套用；見 [`Checkout 整合文件`](../docs/backend-specs/checkout/README.md)                                                                              |
| **F Coupon**                        | 🔄 F-1、F-3、F-4 與商城 F-2 完成；Booking 缺少 Coupon 關聯 Schema，付款後消耗待線 D；見 [`Coupon 流程`](../docs/backend-specs/coupon/README.md)                                                                                                     |
| **E-0 Booking 冪等 Schema**         | ✅ `bookings` 已具備 Checkout key、request hash 與會員範圍唯一約束；見 [`E-0 文件`](../docs/backend-specs/booking/e0-booking-idempotency-schema.md)                                                                                                      |
| **E-1 Booking 公開讀**              | ✅ 營區、有效營位、租借裝備、policy、closures；見 [`E-1 文件`](../docs/backend-specs/booking/e1-booking-public-read.md) 與 [`Swagger 流程`](../docs/backend-specs/test/e1-booking-public-swagger.md)                                                     |
| **E-2 Booking 可用性**              | ✅ 公開 POST 查詢跨晚最低剩餘量；包含日期窗口、公休、zone block 與 pending／confirmed 占用；見 [`E-2 文件`](../docs/backend-specs/booking/e2-booking-availability.md) 與 [`Swagger 流程`](../docs/backend-specs/test/e2-booking-availability-swagger.md) |
| **E-3 Booking Checkout**            | ✅ 會員冪等、固定順序悲觀鎖、跨晚重查、後端平假日計價與 pending／unpaid 快照；見 [`E-3 文件`](../docs/backend-specs/booking/e3-booking-checkout.md) 與 [`Swagger 流程`](../docs/backend-specs/test/e3-booking-checkout-swagger.md)                       |
| **E-4 Booking 租借保留**            | ✅ 營區庫位解析、跨日 active 保留、後端租借計價與並發防超租；見 [`E-4 文件`](../docs/backend-specs/booking/e4-booking-rental-reservation.md) 與 [`Swagger 流程`](../docs/backend-specs/test/e4-booking-rental-swagger.md)                                |
| **E-5 會員預約讀取**                | ✅ 本人列表、分頁、詳情與 Checkout 快照；他人與不存在統一 404；見 [`E-5 文件`](../docs/backend-specs/booking/e5-booking-member-read.md) 與 [`Swagger 流程`](../docs/backend-specs/test/e5-booking-member-swagger.md)                                     |
| **E-6 Booking 取消與逾時**          | ✅ 主動取消、每分鐘逾時掃描、營位恢復、租借保留釋放與鎖定競爭；見 [`E-6 文件`](../docs/backend-specs/booking/e6-booking-cancellation-expiration.md) 與 [`Swagger 流程`](../docs/backend-specs/test/e6-booking-cancellation-swagger.md)                   |
| **E-7 Booking 前端接線**            | ✅ Booking facade、後端可用性／價格、本人列表／詳情／取消及 15 分鐘倒數已接線；Payment Confirmation 延後線 D；見 [`E-7 文件`](../docs/backend-specs/booking/e7-booking-frontend-integration.md)                                                          |
| API 契約索引（P0+P1）               | [`docs/api/README.md`](../docs/api/README.md)                                                                                                                                                                                                            |
| 商品契約（已實作）                  | [`docs/api/product-api-contract.md`](../docs/api/product-api-contract.md)                                                                                                                                                                                |
| 代辦清單 A～J                       | [`plans/backend-implementation-checklist.md`](../plans/backend-implementation-checklist.md)                                                                                                                                                              |
| 結帳／ECPay／細 RBAC                | 🔄 Checkout 線 C 與商城 Coupon 已完成；Booking Coupon、Payment 與細 RBAC 待實作                                                                                                                                                                         |

### Schema 整合驗證

`RUN_BACKEND_IT=true` 時，`BackendApplicationTests` 會連線 Docker PostgreSQL 並載入完整 Spring Context；因 `ddl-auto=validate`，Context 成功即代表目前所有 JPA Entity 已通過 Schema 驗證。

`DB_PASSWORD` 必須與 Docker `.env` 的 `POSTGRES_PASSWORD` 相同。若出現 `password authentication failed`，先修正連線密碼；不要修改 Entity，也不要將 `ddl-auto` 改成 `update`。

### 開發用資料種子

全新 Docker volume 會自動跑 [`docs/seed/002-dev-seed.sql`](../docs/seed/002-dev-seed.sql)，依序建立商品與 Booking E-1 參考資料，以及商城／租借開發庫存。結構與 AI／開發者維護規則見 [`docs/seed/README.md`](../docs/seed/README.md)。
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
- `YURUICAMP_BOOKING_EXPIRATION_SCAN_MS` 對應 `yuruicamp.booking.expiration-scan-ms`（預設 `60000` 毫秒）
- `YURUICAMP_BOOKING_EXPIRATION_ENABLED` 對應 `yuruicamp.booking.expiration-enabled`（預設 `true`）
- `CORS_ALLOWED_ORIGINS`
