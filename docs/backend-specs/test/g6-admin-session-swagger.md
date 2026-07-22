# G-6 Admin Session／全線 RBAC Swagger 驗證

### Swagger 驗證流程

測試前確認：

- PostgreSQL 與後端已啟動。
- `FIREBASE_ENABLED=false`。
- 已載入最新開發 Seed。
- 開啟 `http://localhost:8080/swagger-ui.html`。

#### 1. 建立管理員 Session

```http
POST /api/admin/auth/firebase/session
```

```json
{
  "idToken": "dev:booking-seed-admin:booking-seed@example.test:google:Booking Seed Admin"
}
```

預期 HTTP 200，`data` 包含 `adminUserId`、`role`、`firebaseUid` 與 `effectivePermissions`。後端不回傳自家 JWT。

#### 2. 使用 Firebase ID Token 授權

點 Swagger 右上角 `Authorize`，輸入：

```text
dev:booking-seed-admin:booking-seed@example.test:google:Booking Seed Admin
```

不需要自行加 `Bearer`。

#### 3. 驗證 G 線正式端點

依登入回應具有的權限呼叫：

```http
GET /api/admin/users?page=0&size=20
GET /api/admin/customers?page=0&size=20
GET /api/admin/orders?page=0&size=20
GET /api/admin/bookings?page=0&size=20
GET /api/admin/products?page=0&size=20
GET /api/admin/inventory-movements?page=0&size=20
GET /api/admin/coupons?page=0&size=20
GET /api/admin/campground-closures?page=0&size=20
```

有對應 view 權限時預期 200 與共用 Envelope；沒有權限時預期 403。不得因前端 SessionStorage 有權限字樣而繞過後端。

#### 4. 驗證停用與 UID 綁定

- 使用不在 `admin_users` 白名單的 Email 建立 Session，預期 `ADMIN_NOT_WHITELISTED`。
- 停用管理員後再建立 Session，預期 `ADMIN_INACTIVE`。
- 已綁定其他 Firebase UID 的相同 Email，預期 403。

#### 5. 驗證未就緒端點邊界

G-6 readiness 會在前端阻擋 Reviews、tag pool、seller note、租借商品寫入。Swagger 中沒有這些 Admin 契約，不能把 404 當成可用功能；後續必須先補契約與後端實作，再調整 readiness。

#### Swagger 驗收完成標準

- Admin Session 回傳資料庫計算的有效權限，不簽發自家 JWT。
- G-1～G-4 正式端點依細權限回 200 或 403。
- 未白名單、停用及 UID 不一致均無法建立 Session。
- 前端 readiness 清單與 Swagger 實際存在端點一致。

這項驗證必要，因為 G-6 不是單一開關；必須同時證明登入身分、有效權限、正式端點範圍及未就緒邊界一致，才不會出現 UI 顯示可用但後端 404／403 的假接線。
