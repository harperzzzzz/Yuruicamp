

## 一、啟動環境

### 1. 啟動 PostgreSQL

在專案根目錄執行：

```powershell
cd D:\githubdesk\Yuruicamp
docker compose up -d
docker compose ps
```

確認 `yuruicamp-db` 為 healthy。

如果目前資料庫尚未載入 Booking 開發資料，可以執行：

```powershell
docker exec yuruicamp-db psql -U postgres -d yuruicamp -f /docker-entrypoint-initdb.d/002-dev-seed.sql
```

Booking 開發資料包含：

- 營區：`C002`
- 營位：`C002-Z-A`
- 可用營位數：`8`
- 租借 listing：`RL-DEV-C002-001`
- 租借 variant：`RSV-DEV-001`
- 租借庫存：`6`
- 停用營區：`C009`，公開列表不應出現

注意：重跑 seed 會重設部分開發庫存。

### 2. 啟動後端

開另一個 PowerShell：

```powershell
cd D:\githubdesk\Yuruicamp\backend

$env:DB_PASSWORD = "你的 POSTGRES_PASSWORD"
.\mvnw.cmd spring-boot:run
```

確認：

```text
http://localhost:8080/api/health
http://localhost:8080/swagger-ui.html
```

Health API 應回成功。

### 3. 啟動前端

再開一個 PowerShell：

```powershell
cd D:\githubdesk\Yuruicamp\frontend
npm run dev
```

通常網址為：

```text
http://127.0.0.1:5173
```

確認 [config.js](D:/githubdesk/Yuruicamp/frontend/storefront/js/config.js) 目前是：

```javascript
USE_MOCK_API: false
```

API Base URL 應是：

```javascript
API_BASE_URL: "http://localhost:8080/api"
```

---

## 二、準備瀏覽器工具

開啟：

```text
http://127.0.0.1:5173/booking/pages/camp-search.html
```

按 `F12` 開啟 DevTools。

在 Network 頁籤：

1. 勾選 `Preserve log`。
2. 勾選 `Disable cache`。
3. 選擇 `Fetch/XHR`。
4. 清除目前紀錄。

先在 Console 記錄 Mock Booking 狀態：

```javascript
localStorage.getItem("mockBookings");
```

正常情況應為 `null`，或是先前既有內容。記住這個結果，完成後要再次比較。

---

## 三、建立開發會員 Session

在 Console 執行：

```javascript
window.bookingDevToken =
  "dev:booking-front:booking-front@example.com:google:BookingFront";

AppAuth.configure({ devToken: window.bookingDevToken });

const profile = await ApiClient._restRequest(
  "/auth/firebase/session",
  {
    method: "POST",
    auth: "none",
    body: {
      idToken: window.bookingDevToken,
    },
  }
);

console.log(profile);
```

預期回傳類似：

```json
{
  "customerId": "某個會員ID",
  "email": "booking-front@example.com",
  "name": "BookingFront",
  "authProvider": "google",
  "firebaseUid": "booking-front",
  "status": "active",
  "created": true
}
```

為了讓會員中心的前端登入判斷能找到會員，繼續執行：

```javascript
localStorage.setItem(
  "yuruiUser",
  JSON.stringify({
    id: profile.customerId,
    customerId: profile.customerId,
    name: profile.name,
    email: profile.email,
    status: profile.status,
  })
);
```

重要：`AppAuth.configure()` 只保存在目前頁面的 JavaScript 記憶體。Booking 是多頁式流程，進入 Checkout、成功頁或會員中心等完整換頁後，Token 與 Console 變數都不會保留。

每次進入需要會員認證的新頁面，都要重新執行完整區塊：

```javascript
window.bookingDevToken =
  "dev:booking-front:booking-front@example.com:google:BookingFront";

AppAuth.configure({ devToken: window.bookingDevToken });
```

使用 `window.bookingDevToken` 是為了讓同一頁可以安全重跑；不要反覆使用 `const devToken`，否則 Console 可能出現重複宣告錯誤。正式環境不得使用開發 Token。

---

## 四、驗證營區公開讀取

重新整理營區搜尋頁：

```text
http://127.0.0.1:5173/booking/pages/camp-search.html
```

公開 API 不需要 Token。

### Network 預期

應看到後端請求，例如：

```http
GET /api/booking/campgrounds
GET /api/booking/policy
GET /api/booking/closures
```

不應看到：

```text
/data/catalog/campgrounds.json
/data/commerce/camp-bookings.json
/data/admin/booking-policy.json
```

### 畫面預期

- 應看到營區 `C002`「悠旅森林露營區」。
- 不應看到停用營區 `C009`。
- 頁面不應顯示「營區載入失敗」。

也可以在 Network 點開 `/api/booking/campgrounds`，確認 Response 使用統一 Envelope：

```json
{
  "success": true,
  "data": [
    {
      "id": "C002",
      "name": "悠旅森林露營區",
      "region": "南投縣",
      "active": true
    }
  ]
}
```

---

## 五、驗證日期與可用性

選擇符合以下條件的日期：

- 入住日至少是明天。
- 退房日晚於入住日。
- 不超過 90 天預約窗口。
- 不超過 7 晚。

例如以目前日期為基準，可以選未來 2～3 天後入住，住宿一晚。

選擇日期後，Network 應出現：

```http
POST /api/booking/check-availability
```

Request Payload 應類似：

```json
{
  "campgroundId": "C002",
  "checkIn": "2026-07-24",
  "checkOut": "2026-07-25",
  "zones": [
    {
      "zoneId": "C002-Z-A",
      "quantity": 1
    }
  ]
}
```

Response 應類似：

```json
{
  "success": true,
  "data": {
    "available": true,
    "reasons": [],
    "zones": [
      {
        "zoneId": "C002-Z-A",
        "requested": 1,
        "availableQuantity": 8
      }
    ]
  }
}
```

驗收重點：

- 可用性由後端回傳。
- 前端沒有載入所有 Booking JSON 自行計算。
- 這一步不應建立 Booking。
- 這一步不應鎖定庫存。

---

## 六、選擇營位與租借品

點擊 `C002` 進入營區詳情：

```text
/booking/pages/camp-detail.html?id=C002
```

Network 應看到：

```http
GET /api/booking/campgrounds/C002
GET /api/booking/equipment?campgroundId=C002
```

營區詳情應包含：

- active 營位 `C002-Z-A`
- 平日價格 `"1200.00"`
- 假日價格 `"1500.00"`
- 總營位數 `8`

停用營位 `C002-Z-HIDDEN` 不應顯示。

選擇：

- 營位：`C002-Z-A`
- 數量：`1`

租借品可以：

- 略過；或
- 選擇 `RL-DEV-C002-001`，數量 `1`

繼續進入預約背包與 Checkout：

```text
/booking/pages/booking-cart.html
/booking/pages/booking-checkout.html
```

`bookingCart` 存在 localStorage 是正常的，因為它只是尚未結帳的前端暫存；禁止的是後端模式新增 `mockBookings`。

---

## 七、建立待付款預約

進入 Checkout 頁後，先重新設定 Token：

```javascript
window.bookingDevToken =
  "dev:booking-front:booking-front@example.com:google:BookingFront";

AppAuth.configure({ devToken: window.bookingDevToken });
```

填寫畫面要求的資料：

- 姓名：`Booking Front`
- 電話：`0912345678`
- Email：`booking-front@example.com`
- 付款方式：ECPay 信用卡

按下「建立待付款預約」。

### Network 預期

應出現：

```http
POST /api/booking/checkout/sessions
```

Request Headers 應包含：

```http
Authorization: Bearer dev:booking-front:booking-front@example.com:google:BookingFront
Content-Type: application/json
```

Request Payload 應類似：

```json
{
  "campgroundId": "C002",
  "checkIn": "2026-07-24",
  "checkOut": "2026-07-25",
  "guestCount": 2,
  "zones": [
    {
      "zoneId": "C002-Z-A",
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
  "idempotencyKey": "瀏覽器產生的 UUID"
}
```

### Request 中不應存在

確認 Payload 沒有：

```text
customerId
price
zoneTotal
rentalTotal
finalAmount
status
paymentStatus
campgroundName
region
```

這些欄位必須由後端會員身份、資料庫價格與業務規則決定。

### Response 預期

應回傳 2xx，內容類似：

```json
{
  "success": true,
  "data": {
    "bookingId": "B...",
    "status": "pending",
    "paymentStatus": "unpaid",
    "paymentMethod": "ecpay-credit",
    "checkoutExpiresAt": "ISO-8601時間",
    "campgroundId": "C002",
    "campgroundName": "悠旅森林露營區",
    "region": "南投縣",
    "pricing": {
      "zoneTotal": "1200.00",
      "rentalTotal": "180.00",
      "discount": "0.00",
      "finalAmount": "1380.00"
    },
    "checkoutStep": "ready_to_pay"
  }
}
```

實際價格會依住宿日期是否為假日、住宿晚數及是否選租借品而不同。

請記下 `bookingId`。

---

## 八、驗證成功頁

成功後應導向：

```text
/booking/pages/booking-success.html?bookingNum=...
```

頁面應顯示：

- 後端產生的 Booking 編號。
- `pricing.finalAmount`。
- `paymentStatus=unpaid`。
- `checkoutExpiresAt` 倒數。
- 不應顯示「付款成功」。
- 不應把 Booking 偽造為 `paid` 或 `confirmed`。

因為線 D 尚未完成，正確狀態是：

```text
pending + unpaid
```

若成功頁重新查詢 Checkout Session 時因換頁後 Token 遺失而出現 401，可在 Console 重新執行：

```javascript
window.bookingDevToken =
  "dev:booking-front:booking-front@example.com:google:BookingFront";

AppAuth.configure({ devToken: window.bookingDevToken });

const bookingId = JSON.parse(
  sessionStorage.getItem("lastCheckoutBooking")
).bookingId;

const session = await BookingAPI.getCheckoutSession(bookingId);

console.log(session);
```

應能取得剛才建立的 Checkout Session。

---

## 九、驗證冪等

從第一次 POST Request 複製：

- 完整 Payload
- `idempotencyKey`

在 Console 使用同一個 Payload 再送一次：

```javascript
AppAuth.configure({ devToken: window.bookingDevToken });

const sameRequest = {
  campgroundId: "C002",
  checkIn: "2026-07-24",
  checkOut: "2026-07-25",
  guestCount: 2,
  zones: [
    {
      zoneId: "C002-Z-A",
      quantity: 1,
    },
  ],
  rentals: [],
  couponClaimId: null,
  paymentMethod: "ecpay-credit",
  idempotencyKey: "換成第一次 Request 使用的 key",
};

const replay = await ApiClient._restRequest(
  "/booking/checkout/sessions",
  {
    method: "POST",
    auth: "required",
    body: sameRequest,
  }
);

console.log(replay);
```

預期：

- 回傳同一個 `bookingId`。
- 不會建立第二筆 Booking。
- 營位不會重複扣除。

接著保留相同 `idempotencyKey`，但修改 `guestCount` 或營位數量再送一次。

預期：

```text
409 Conflict
```

代表同一冪等鍵不能搭配不同 Payload。

---

## 十、驗證會員中心

開啟：

```text
http://127.0.0.1:5173/booking/pages/member-center.html
```

在 Console 重新設定 Token：

```javascript
window.bookingDevToken =
  "dev:booking-front:booking-front@example.com:google:BookingFront";

AppAuth.configure({ devToken: window.bookingDevToken });

window.initMemberCenterComponent();
```

如果登入外殼仍沒有辨識會員，確認：

```javascript
JSON.parse(localStorage.getItem("yuruiUser"));
```

應包含剛才的 `customerId`。

### Network 預期

應出現：

```http
GET /api/booking/bookings?page=0&size=20
```

Request 不應帶：

```text
customerId=...
```

會員身份應由 Bearer Token 決定。

列表應看到剛建立的 Booking，狀態為：

```text
pending
unpaid
```

點擊 Booking 詳情後，應出現：

```http
GET /api/booking/bookings/{bookingId}
```

詳情應包含：

- 營區快照
- 入住／退房日期
- 人數
- zones
- rentals
- 後端計算金額
- `pending`
- `unpaid`

會員中心其他尚未完成的 Orders、Coupons 或 Reviews 請求可能出現警告；只要 Booking API 成功且預約能顯示，就不應判定 Booking 驗收失敗。

---

## 十一、驗證會員隔離

建立第二個開發會員：

```javascript
window.bookingSecondToken =
  "dev:booking-other:booking-other@example.com:google:BookingOther";

AppAuth.configure({ devToken: window.bookingSecondToken });

const secondProfile = await ApiClient._restRequest(
  "/auth/firebase/session",
  {
    method: "POST",
    auth: "none",
    body: {
      idToken: window.bookingSecondToken,
    },
  }
);

console.log(secondProfile);
```

使用第二位會員查列表：

```javascript
const secondList = await BookingAPI.getBookingsPage({
  page: 0,
  size: 20,
});

console.log(secondList);
```

預期：

- 第二位會員看不到第一位會員的 Booking。

嘗試讀取第一位會員的 Booking：

```javascript
await BookingAPI.getBookingById("第一位會員的 bookingId");
```

預期回傳：

```text
404 NOT_FOUND
```

不應回傳第一位會員資料，也不應讓前端傳 `customerId` 繞過限制。

完成後切回第一位會員：

```javascript
AppAuth.configure({ devToken: window.bookingDevToken });
```

---

## 十二、取消待付款預約

以第一位會員身份，在會員中心按下取消。

Network 應出現：

```http
POST /api/booking/checkout/sessions/{bookingId}/cancel
```

Request 必須帶第一位會員的 Bearer Token。

Response 應顯示：

```json
{
  "status": "cancelled",
  "paymentStatus": "unpaid"
}
```

取消後再次查詢：

```javascript
const cancelled = await BookingAPI.getBookingById("bookingId");
console.log(cancelled);
```

預期：

```text
status = cancelled
paymentStatus = unpaid
```

若有租借品，後端應同步釋放租借保留。

重複按取消或再次呼叫取消端點，不應重複釋放庫存或產生錯誤狀態。

---

## 十三、檢查 localStorage

在 Console 執行：

```javascript
localStorage.getItem("mockBookings");
localStorage.getItem("lastCheckoutBooking");
localStorage.getItem("bookingCart");
sessionStorage.getItem("lastCheckoutBooking");
```

Backend 模式預期：

| Key | 預期 |
|---|---|
| `mockBookings` | 不新增、不修改 |
| `lastCheckoutBooking`（localStorage） | 不保存 |
| `bookingCart` | 建立成功後移除 |
| `lastCheckoutBooking`（sessionStorage） | 可暫時存在，供成功頁顯示 |

也可以在 Application → Local Storage 直接檢查。

---

## 十四、通過標準

全部符合以下條件即可判定前端 Booking 接線通過：

- 營區、政策、公休、租借品來自後端。
- Network 沒有讀取 Booking Mock JSON。
- 可用性使用 `POST /api/booking/check-availability`。
- 建立預約使用 `POST /api/booking/checkout/sessions`。
- Request 不包含會員 ID、價格、付款狀態或預約狀態。
- 金額由後端 Response 決定。
- Booking 初始狀態是 `pending + unpaid`。
- 成功頁使用後端 `bookingId` 與 `checkoutExpiresAt`。
- 會員只能查看自己的 Booking。
- 取消後狀態變成 `cancelled`。
- Backend 模式沒有新增 `mockBookings`。
- 線 D 未完成前，畫面沒有假的「付款成功」。
