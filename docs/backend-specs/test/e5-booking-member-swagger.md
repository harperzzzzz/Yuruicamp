# E-5 會員預約 Swagger 驗證

## 前置條件

- 後端與 PostgreSQL 已啟動。
- Swagger：`http://localhost:8080/swagger-ui.html`。
- 先呼叫 `POST /api/auth/firebase/session` 建立或綁定開發會員。
- 點右上角 **Authorize**，輸入同一個 `dev:<uid>:<email>:google:<name>` Token。
- 該會員至少先用 `POST /api/booking/checkout/sessions` 建立一筆預約。

## Swagger 驗證流程

1. 呼叫 `GET /api/booking/bookings?page=0&size=20`，確認 HTTP 200、列表只含目前會員資料，並有 `meta`。
2. 複製列表中的 `bookingId`，呼叫 `GET /api/booking/bookings/{id}`，確認包含 `pricing`、`zones`、`rentals`、付款與狀態欄位。
3. 使用同一個 ID 呼叫 `GET /api/booking/checkout/sessions/{bookingId}`，確認回傳 Checkout 快照與 `checkoutStep`。
4. 清除 Swagger Authorize 後重打列表，預期 HTTP 401。
5. 使用另一個會員的 Booking ID 或不存在的 ID，預期都為 HTTP 404、`NOT_FOUND`。
6. 將 `page` 設為 `-1` 或 `size` 設為 `101`，預期 HTTP 400、`VALIDATION_ERROR`。

這項驗證用來確認會員隔離不只存在於畫面，而是由 Security principal 與 SQL 條件共同保護；統一 404 可避免外部利用 ID 判斷別人的預約是否存在。
