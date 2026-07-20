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

## 線 A／B 進度

| 項目 | 狀態 |
|------|------|
| package 分層、CORS、OpenAPI | ✅ |
| 統一 Envelope／錯誤 | ✅ |
| Firebase ID Token Security | ✅ |
| Customer／Admin session | ✅ |
| MapStruct | ✅ |
| **B-1／B-2 商品公開讀** | ✅ `GET /api/products`、`GET /api/products/{id}` |
| API 契約索引（P0+P1） | [`docs/api/README.md`](../docs/api/README.md) |
| 商品契約（已實作） | [`docs/api/product-api-contract.md`](../docs/api/product-api-contract.md) |
| 代辦清單 A～J | [`plans/backend-implementation-checklist.md`](../plans/backend-implementation-checklist.md) |
| 結帳／ECPay／細 RBAC | ❌ 線 C 起 |

### 開發用商品種子

全新 Docker volume 會自動跑 `docs/seed/002-dev-catalog-min.sql`。  
既有資料庫請手動灌一次：

```powershell
# PowerShell 管線可能弄壞 UTF-8 中文，請用 docker cp
docker cp ..\docs\seed\002-dev-catalog-min.sql yuruicamp-db:/tmp/002-dev-catalog-min.sql
docker exec yuruicamp-db psql -U postgres -d yuruicamp -v ON_ERROR_STOP=1 -f /tmp/002-dev-catalog-min.sql
```

驗收：

```powershell
curl.exe http://localhost:8080/api/products
curl.exe http://localhost:8080/api/products/P001
```

## 設定鍵

見 `src/main/resources/application.properties`：

- `DB_URL` / `DB_USERNAME` / `DB_PASSWORD`
- `FIREBASE_ENABLED` / `FIREBASE_CREDENTIALS`
- `CORS_ALLOWED_ORIGINS`
