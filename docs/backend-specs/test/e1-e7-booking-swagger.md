# E-1～E-7 Booking Swagger 整合驗證

### swagger 驗證流程

測試前確認：

- PostgreSQL 與後端已啟動。
- PostgreSQL 已載入最新 `docs/latest_schema.sql` 與 `docs/seed/002-dev-seed.sql`。
- `FIREBASE_ENABLED=false`，本機才能使用 `dev:` Token。
- Swagger 位於 `http://localhost:8080/swagger-ui.html`。
- 測試日期必須落在 `Asia/Taipei` 今天起算的可預約窗口內，預設為提前 `1` 天、未來 `90` 天內、最多 `7` 晚。
- Dev Seed 的 `C002`、`Z001`、`RL-DEV-C002-001` 與 `RSV-DEV-001` 已存在。
- 每次建立新的 Booking Checkout 時使用未重複的 `idempotencyKey`。

#### 1. E-1：驗證營區公開列表

E-1 與 E-2 是公開 API，不需要先按 Swagger 的 `Authorize`。

執行：

```http
GET /api/booking/campgrounds
```

預期：

- HTTP `200`。
- `success=true`。
- `data` 包含啟用中的營區 `C002`。
- `data` 不包含停用的營區 `DEV-CAMP-INACTIVE`。
- 列表回應包含單頁 `meta`。

#### 2. E-1：驗證營區詳情與停用資料過濾

執行：

```http
GET /api/booking/campgrounds/C002
```

預期：

- HTTP `200`。
- `data.id="C002"`。
- `zones` 包含 `Z001`。
- `Z001` 的平日價格為 `"1000.00"`。
- `Z001` 的假日價格為 `"1500.00"`。
- 金額使用固定兩位小數字串。

再執行：

```http
GET /api/booking/campgrounds/UNKNOWN
```

預期：

- HTTP `404`。
- `error.code="NOT_FOUND"`。

#### 3. E-1：驗證租借裝備、政策與公休

依序執行：

```http
GET /api/booking/equipment?campgroundId=C002
GET /api/booking/policy
GET /api/booking/closures
```

預期：

- Equipment 回應包含 `RL-DEV-C002-001`。
- Equipment 公開回應不包含內部實體庫存 `stock` 欄位。
- Policy 的 `occupyingStatuses` 包含 `pending` 與 `confirmed`。
- Closures 回應包含 `C002` 的 `date_range` Dev Seed 範例。
- 三個成功回應都有 `success=true`。
- 列表回應都有 `meta`。

#### 4. E-2：查詢正常可用性

執行：

```http
POST /api/booking/check-availability
```

Request Body：

```json
{
  "campgroundId": "C002",
  "checkIn": "2026-08-01",
  "checkOut": "2026-08-03",
  "zones": [
    {
      "zoneId": "Z001",
      "quantity": 2
    }
  ]
}
```

如果範例日期已超出預約窗口，將日期改為 `Asia/Taipei` 明天起算、最多 `7` 晚，而且不要包含 Dev Seed 公休 `2026-09-01`。

預期：

- HTTP `200`。
- `data.available=true`。
- `data.reasons` 為空陣列。
- `data.zones[0].requested=2`。
- 沒有其他 Booking 占用時，`availableQuantity=10`。
- 查詢不會新增 `bookings` 或租借保留資料。

#### 5. E-2：驗證日期與政策錯誤

將 `checkOut` 改成與 `checkIn` 相同後重送。

預期：

- HTTP `400`。
- `error.code="BOOKING_DATE_INVALID"`。

再將 `checkIn` 改為 `Asia/Taipei` 今天後第 `91` 天，並使用有效的 `checkOut`。

預期：

- HTTP `400`。
- `error.code="BOOKING_WINDOW_EXCEEDED"`。

若同一個 `zoneId` 在 `zones` 中重複傳入，預期 HTTP `400 VALIDATION_ERROR`。

#### 6. E-2：驗證營區公休

使用 Dev Seed 公休日期：

```json
{
  "campgroundId": "C002",
  "checkIn": "2026-09-01",
  "checkOut": "2026-09-02",
  "zones": [
    {
      "zoneId": "Z001",
      "quantity": 1
    }
  ]
}
```

預期：

- HTTP `200`，不可訂不是 HTTP 錯誤。
- `data.available=false`。
- `data.reasons` 包含 `CAMPGROUND_CLOSED`。
- 該段日期的最低剩餘量為 `0`。

若 `2026-09-01` 已超出政策窗口，這項情境改由 PostgreSQL 整合測試驗證；不要為了 Swagger 測試放寬正式政策。

#### 7. 建立開發會員並授權

先執行：

```http
POST /api/auth/firebase/session
```

Request Body：

```json
{
  "idToken": "dev:booking-e-swagger:booking-e-swagger@example.test:google:BookingTester"
}
```

預期 HTTP `200`，建立或取得開發會員。

接著點 Swagger 右上角綠色 `Authorize` 按鈕，輸入：

```text
dev:booking-e-swagger:booking-e-swagger@example.test:google:BookingTester
```

不需要自行加上 `Bearer`。

#### 8. E-3：建立純營位 Booking Checkout

執行：

```http
POST /api/booking/checkout/sessions
```

Request Body：

```json
{
  "campgroundId": "C002",
  "checkIn": "2026-08-01",
  "checkOut": "2026-08-03",
  "guestCount": 2,
  "zones": [
    {
      "zoneId": "Z001",
      "quantity": 1
    }
  ],
  "rentals": [],
  "couponClaimId": null,
  "paymentMethod": "ecpay-credit",
  "idempotencyKey": "booking-e-swagger-001"
}
```

若日期已失效，需同時修改本步驟與後續可用性、租借及取消測試日期。

預期：

- HTTP `200`。
- `data.bookingId` 有值，後續以 `BOOKING_ID` 表示。
- `data.status="pending"`。
- `data.paymentStatus="unpaid"`。
- `data.checkoutStep="ready_to_pay"`。
- `data.checkoutExpiresAt` 約為建立後 `15` 分鐘。
- `pricing`、平假日晚數與 `zones` 快照都由後端產生。
- `rentals` 為空陣列。

回應重點範例：

```json
{
  "success": true,
  "data": {
    "bookingId": "BOOKING_ID",
    "status": "pending",
    "paymentStatus": "unpaid",
    "paymentMethod": "ecpay-credit",
    "checkoutStep": "ready_to_pay",
    "pricing": {
      "zoneTotal": "2000.00",
      "rentalTotal": "0.00",
      "discount": "0.00",
      "finalAmount": "2000.00"
    },
    "rentals": []
  }
}
```

實際金額會依日期的平假日組合而不同，以後端回應為準。

#### 9. E-3：驗證冪等重送與 Payload 衝突

使用完全相同的 Request Body 與 `idempotencyKey` 再送一次。

預期：

- HTTP `200`。
- 回傳與第一次相同的 `bookingId`。
- 不會新增第二筆 Booking 或第二組保留資料。

保留相同 `idempotencyKey`，但將 `guestCount` 或 `zones[0].quantity` 修改後重送。

預期：

- HTTP `409`。
- `error.code="IDEMPOTENCY_CONFLICT"`。

#### 10. E-3：驗證 Booking 禁止 COD

將 `paymentMethod` 改成 `cod`，並使用新的 `idempotencyKey`：

```json
{
  "campgroundId": "C002",
  "checkIn": "2026-08-01",
  "checkOut": "2026-08-03",
  "guestCount": 2,
  "zones": [
    {
      "zoneId": "Z001",
      "quantity": 1
    }
  ],
  "rentals": [],
  "couponClaimId": null,
  "paymentMethod": "cod",
  "idempotencyKey": "booking-e-swagger-cod-001"
}
```

預期：

- HTTP `400`。
- `error.code="VALIDATION_ERROR"`。
- 不會建立 Booking。

#### 11. E-4：建立包含租借的 Booking Checkout

執行：

```http
POST /api/booking/checkout/sessions
```

Request Body：

```json
{
  "campgroundId": "C002",
  "checkIn": "2026-08-04",
  "checkOut": "2026-08-06",
  "guestCount": 2,
  "zones": [
    {
      "zoneId": "Z001",
      "quantity": 1
    }
  ],
  "rentals": [
    {
      "rentalListingId": "RL-DEV-C002-001",
      "rentalSkuVariantId": "RSV-DEV-001",
      "quantity": 1
    }
  ],
  "couponClaimId": null,
  "paymentMethod": "ecpay-credit",
  "idempotencyKey": "booking-e-swagger-rental-001"
}
```

預期：

- HTTP `200`。
- `rentals[0]` 包含 `rentalListingId`、`rentalSkuVariantId`、SKU、名稱、規格、價格與折扣快照。
- `pricing.rentalTotal` 由後端依平假日晚數、數量與 listing 折扣計算。
- `pricing.finalAmount` 等於營位與租借金額扣除優惠後的後端結果。
- 建立 active `rental_stock_reservations`。

記下這一筆回傳的 `bookingId`，後續以 `RENTAL_BOOKING_ID` 表示。

#### 12. E-4：驗證租借庫存與關聯錯誤

使用新 `idempotencyKey`，將租借 `quantity` 改成 `7`。

預期：

- HTTP `409`。
- `error.code="RENTAL_STOCK_INSUFFICIENT"`。

再使用新 `idempotencyKey`，將 `rentalListingId` 改成其他營區的 listing，或將 variant 改成不相符 ID。

預期：

- HTTP `404`。
- `error.code="NOT_FOUND"`。

省略 `rentals` 或傳空陣列時，應仍可建立純營位 Booking。

#### 13. E-5：讀取自己的 Booking 列表

執行：

```http
GET /api/booking/bookings?page=0&size=20
```

預期：

- HTTP `200`。
- `success=true`。
- `data` 只包含目前 Token 對應會員的 Booking。
- `data` 包含前面建立的 `BOOKING_ID` 與 `RENTAL_BOOKING_ID`。
- 回應包含 `meta.page`、`meta.size`、`meta.totalElements` 與 `meta.totalPages`。

將 `page` 改成 `-1` 或 `size` 改成 `101`，預期 HTTP `400 VALIDATION_ERROR`。

#### 14. E-5：讀取 Booking 詳情與 Checkout 快照

執行：

```http
GET /api/booking/bookings/{BOOKING_ID}
```

預期：

- HTTP `200`。
- 詳情包含 `pricing`、`zones`、`rentals`、`paymentMethod`、`paymentStatus` 與狀態欄位。
- 欄位取自建立當下的快照，不會因主檔後續變更而改寫。

再執行：

```http
GET /api/booking/checkout/sessions/{BOOKING_ID}
```

預期：

- HTTP `200`。
- 回傳完整 Checkout Session。
- 未付款且未取消時 `checkoutStep="ready_to_pay"`。

#### 15. E-5：驗證未授權與會員隔離

先在 Swagger 右上角 `Authorize` 清除 Token，再執行：

```http
GET /api/booking/bookings?page=0&size=20
```

預期 HTTP `401 UNAUTHORIZED`。

接著建立第二位開發會員：

```http
POST /api/auth/firebase/session
```

```json
{
  "idToken": "dev:booking-e-other:booking-e-other@example.test:google:OtherBookingTester"
}
```

將 Swagger `Authorize` 改為：

```text
dev:booking-e-other:booking-e-other@example.test:google:OtherBookingTester
```

使用第二位會員讀取第一位會員的 `BOOKING_ID`：

```http
GET /api/booking/bookings/{BOOKING_ID}
GET /api/booking/checkout/sessions/{BOOKING_ID}
```

預期兩者都是：

- HTTP `404`。
- `error.code="NOT_FOUND"`。

不存在的 Booking ID 也回相同 `404 NOT_FOUND`，避免外部判斷別人的 Booking 是否存在。

完成後，將 Swagger `Authorize` 改回第一位會員 Token。

#### 16. E-6：主動取消 Booking

建立一筆新的 `pending + unpaid` Booking，或使用仍未逾時的 `BOOKING_ID`，執行：

```http
POST /api/booking/checkout/sessions/{BOOKING_ID}/cancel
```

預期：

- HTTP `200`。
- `data.status="cancelled"`。
- `data.paymentStatus="unpaid"`。
- `data.checkoutStep="closed"`。
- 該 Booking 的 active 租借保留改為 `released`。

再次送出相同取消請求。

預期：

- HTTP `200`。
- 狀態仍為 `cancelled`。
- 不會重複新增狀態歷程。

#### 17. E-6：驗證取消後恢復可用量

使用取消 Booking 的相同日期與營位，重新執行：

```http
POST /api/booking/check-availability
```

預期取消的 Booking 不再占用營位，可用量恢復。

若取消的是含租借 Booking，可在 DBeaver 執行：

```sql
SELECT
    booking_id,
    status,
    released_at
FROM rental_stock_reservations
WHERE booking_id = 'RENTAL_BOOKING_ID';
```

預期：

- `status='released'`。
- `released_at` 不為 `NULL`。

#### 18. E-6：驗證其他會員不可取消

將 Swagger `Authorize` 改成第二位會員 Token，執行：

```http
POST /api/booking/checkout/sessions/{BOOKING_ID}/cancel
```

預期：

- HTTP `404`。
- `error.code="NOT_FOUND"`。

完成後改回第一位會員 Token。

#### 19. E-6：人工驗證逾時排程

Swagger 不提供修改 `checkout_expires_at` 或直接觸發排程的 API。只有在可丟棄的本機資料庫才能使用以下方式，不可在正式或共用環境操作。

先建立一筆新的 Booking 並記下 `bookingId`，再於 DBeaver 執行：

```sql
UPDATE bookings
SET checkout_expires_at = now() - interval '1 minute'
WHERE id = 'BOOKING_ID'
  AND status = 'pending'
  AND payment_status = 'unpaid';
```

等待排程執行，預設最多約 `60` 秒，再呼叫：

```http
GET /api/booking/checkout/sessions/{BOOKING_ID}
```

預期：

- HTTP `200`。
- `status="cancelled"`。
- `paymentStatus="unpaid"`。
- `checkoutStep="closed"`。

使用 DBeaver 驗證租借保留與狀態歷程：

```sql
SELECT status, released_at
FROM rental_stock_reservations
WHERE booking_id = 'BOOKING_ID';

SELECT status, occurred_at, note
FROM booking_status_history
WHERE booking_id = 'BOOKING_ID'
ORDER BY occurred_at;
```

預期：

- active 租借保留已改為 `released`。
- Booking 只新增一次取消狀態歷程。
- 重複等待排程不會再新增相同歷程。

付款與逾時同時競爭的結果無法用 Swagger 穩定重現，必須由 `BookingLifecycleIntegrationTest` 驗證。

#### 20. E-7：前端 Backend 模式對照

完成 E-1～E-6 Swagger 驗證後，啟動前端並設定：

```text
USE_MOCK_API=false
```

使用與 Swagger 相同的第一位會員 Token 設定 `AppAuth`，從前端完成：

1. 搜尋 `C002`。
2. 查詢營位可用性。
3. 選擇營位與租借裝備。
4. 建立待付款 Booking。
5. 進入會員中心查看 Booking。
6. 主動取消 Booking。

將前端顯示結果與 Swagger 比對：

```http
GET /api/booking/bookings/{BOOKING_ID}
GET /api/booking/checkout/sessions/{BOOKING_ID}
```

預期：

- 前端與 Swagger 的 `bookingId` 相同。
- 前端金額與 `pricing.finalAmount` 相同。
- 前端 `paymentStatus` 使用後端值，不會自行標記為 `paid`。
- 前端取消後，Swagger 查到 `status="cancelled"`。
- Backend 模式不寫入 `mockBookings`。
- API 路徑沒有重複 `/api/api`。

#### Swagger 驗收完成標準

- E-1 公開讀：營區、營位、裝備、政策與公休皆為 HTTP `200`，停用資料不外洩。
- E-2 可用性：正常查詢 HTTP `200`，日期與政策錯誤使用正確錯誤碼，公休以 `available=false` 回應。
- 會員 Session：HTTP `200`，Swagger Authorize 使用 Token 本體，不自行加 `Bearer`。
- E-3 Checkout：建立 HTTP `200`，狀態為 `pending + unpaid`，保留期限約 `15` 分鐘。
- E-3 冪等：相同內容回傳相同 `bookingId`，不同內容回 `409 IDEMPOTENCY_CONFLICT`。
- E-3 付款方式：Booking 使用 COD 時回 `400 VALIDATION_ERROR`。
- E-4 租借：成功建立快照，超量回 `409 RENTAL_STOCK_INSUFFICIENT`，關聯錯誤回 `404 NOT_FOUND`。
- E-5 會員讀取：列表、詳情與 Checkout 快照皆為 HTTP `200`，未授權回 `401`，他人資料回 `404`。
- E-6 取消：第一次與重送皆為 HTTP `200`，狀態維持 `cancelled`，營位與租借保留恢復。
- E-6 逾時：本機人工調整期限後由排程取消，重跑不重複寫歷程。
- E-7 前端：Backend 模式的 ID、金額、狀態與 Swagger 完全一致，不寫 Mock 成交資料。

Swagger 驗證用來確認公開路徑、Firebase principal、Request JSON、Response Envelope、會員隔離及前端串接可以人工走通。跨晚最低可用量、兩筆交易同時搶營位或租借庫存、逾時與付款競爭等併發行為，仍由 Booking PostgreSQL 整合測試保障，因為 Swagger 無法可靠製造同時競爭交易。
