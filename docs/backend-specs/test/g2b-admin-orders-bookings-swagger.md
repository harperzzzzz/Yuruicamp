# G-2b Admin Orders／Bookings Swagger 驗證

### Swagger 驗證流程

測試前確認：

- PostgreSQL 與後端已啟動。
- `FIREBASE_ENABLED=false`。
- 已載入最新開發 Seed。
- 測試管理員具備 `orders.view`、`orders.edit`、`bookings.view`、`bookings.edit`。

#### 1. 建立 Admin Session 並授權

```http
POST /api/admin/auth/firebase/session
```

```json
{
  "idToken": "dev:booking-seed-admin:booking-seed@example.test:google:Booking Seed Admin"
}
```

在 Swagger `Authorize` 輸入同一段 Token，不自行加上 `Bearer`。

執行受保護端點後，Swagger 產生的 Curl 必須包含：

```http
Authorization: Bearer dev:booking-seed-admin:booking-seed@example.test:google:Booking Seed Admin
```

若 Swagger 顯示 `Authorized`，但 Curl 沒有此 Header，代表該 Controller 缺少 `firebaseBearer` OpenAPI Security Requirement，並非 Firebase Token 驗證失敗。

#### 2. 查詢訂單

```http
GET /api/admin/orders?page=0&size=20&sort=placedAt,desc
GET /api/admin/orders/{id}
```

預期 HTTP `200`，列表有分頁 meta；詳情包含 `items` 與 `history`，不包含 Checkout hash 或付款通知原始內容。

#### 3. 出貨與完成訂單

```http
POST /api/admin/orders/{id}/ship
POST /api/admin/orders/{id}/complete
```

Request Body 可使用：

```json
{
  "note": "Swagger 履約驗證"
}
```

預期 paid 線上訂單或 unpaid COD 可以出貨；只有 shipped 可以完成。COD 完成後 `paymentStatus=paid`。重送相同命令不新增第二筆歷程。

#### 4. 查詢預約

```http
GET /api/admin/bookings?page=0&size=20&sort=createdAt,desc
GET /api/admin/bookings/{id}
```

預期詳情包含 `zones`、`rentals` 與 `history`。

#### 5. 確認與完成預約

```http
POST /api/admin/bookings/{id}/confirm
POST /api/admin/bookings/{id}/complete
```

只有 paid pending 可以確認；unpaid 必須回 `409`。只有已到退房日的 paid confirmed 可以完成。

#### 6. DBeaver 核對

```sql
SELECT id, status, payment_status, refund_status, paid_at, updated_at
FROM orders
WHERE id = '<orderId>';

SELECT status, occurred_at, actor_id, note
FROM order_status_history
WHERE order_id = '<orderId>'
ORDER BY occurred_at, id;

SELECT id, status, payment_status, check_out, updated_at
FROM bookings
WHERE id = '<bookingId>';

SELECT status, occurred_at, actor_id, note
FROM booking_status_history
WHERE booking_id = '<bookingId>'
ORDER BY occurred_at, id;
```

#### Swagger 驗收完成標準

- 列表、詳情、出貨、完成、確認端點符合 RBAC。
- 非法狀態轉換回 `409`。
- Admin 操作歷程具有 `actor_id`。
- Admin 無法人工建立 ECPay paid 或退款結果。
- Swagger 產生的所有受保護 Admin 請求都包含 Firebase Bearer Token。

此驗證確保後台只能改變履約狀態，付款真相仍由可信付款流程管理，並確認狀態與歷程在同一交易保存。
