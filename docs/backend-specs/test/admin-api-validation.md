# Admin API 實際驗證

## 1. 建立 Admin Session

使用資料庫已存在、active 且具測試權限的白名單管理員：

```http
POST /api/admin/auth/firebase/session
Content-Type: application/json

{
  "idToken": "dev:<uid>:<whitelist-email>:google:<name>"
}
```

在 Swagger `Authorize` 輸入 Token 本體。預期 Session 回傳 `adminUserId`、role、UID 綁定狀態與資料庫計算的 `effectivePermissions`，不簽發自家 JWT。

負向案例：未白名單、inactive、同 Email 已綁其他 UID 都必須拒絕。

## 2. RBAC 基線

準備 full、view-only、無 view 三種測試管理員：

- full：讀寫端點依契約成功。
- view-only：GET 成功，POST／PATCH／PUT／DELETE 回 `403`。
- 無 view：列表與詳情皆回 `403`。
- 直接修改前端 SessionStorage 權限不得影響結果。

Swagger 產生的受保護 Curl 必須帶 Bearer；缺 Header 時先檢查 Controller OpenAPI `firebaseBearer` 宣告。

## 3. 管理員與權限

```http
GET /api/admin/users
GET /api/admin/users/{id}
POST /api/admin/users
PATCH /api/admin/users/{id}
PUT /api/admin/users/{id}/permissions
GET /api/admin/permissions
```

驗證 Email／角色／active／UID 綁定保護、個別權限覆寫與更新後重新建立 Session。不得停用最後一位必要管理員或用 Request 偽造有效權限。

## 4. Customers

```http
GET /api/admin/customers?page=0&size=20
GET /api/admin/customers/{id}
PATCH /api/admin/customers/{id}
POST /api/admin/customers/{id}/suspend
POST /api/admin/customers/{id}/reactivate
```

列表多標籤會員只能出現一次；詳情不回完整 Firebase UID。負點數、未來生日回 `400`。停權／恢復重送冪等；deleted 會員狀態操作回 `409`。停權後原會員 Token 呼叫 `/api/me` 應立即被拒絕。

## 5. Orders／Bookings 履約

```http
GET /api/admin/orders
GET /api/admin/orders/{id}
POST /api/admin/orders/{id}/ship
POST /api/admin/orders/{id}/complete

GET /api/admin/bookings
GET /api/admin/bookings/{id}
POST /api/admin/bookings/{id}/confirm
POST /api/admin/bookings/{id}/complete
```

確認詳情快照與 history。Orders 僅 paid 線上單或 unpaid COD 可出貨，只有 shipped 可完成；COD 完成後才標 paid。Bookings 只有 paid pending 可確認，且到退房日後的 paid confirmed 才可完成。非法轉換回 `409`，重送不新增第二筆歷程。Admin 不得人工製造 ECPay paid／refund。

## 6. Products

1. `GET /api/admin/products/lookups` 取得分類與品牌 ID。
2. `POST /api/admin/products` 建立唯一 SKU 的商品與規格。
3. 用列表／詳情確認圖片、variants 與唯讀庫存。
4. `PUT /api/admin/products/{id}` 更新；未送回的既有規格應轉 inactive，不硬刪。
5. 重複 SKU、負價格、重複規格或不存在 lookup 回 `400`／`409`，成功前版本保持不變。
6. deactivate 後公開詳情 `404`、Admin 詳情仍 `200`；activate 前至少一個 active variant。

Request 不接受 totalStock、branch、camp、租借寫入或直接庫存欄位。

## 7. Inventory Movements

1. `GET /api/admin/inventory-movements/lookups` 取得相同 domain 的 location／variant。
2. `POST /api/admin/inventory-movements` 建立 draft。
3. `POST .../{id}/items` 加入明細；draft 階段庫存不變。
4. `POST .../{id}/post` 後庫存才改變；重送 post 不再加減。
5. posted 後加明細／cancel 回 `409`；draft cancel 重送冪等。
6. 超過 on-hand 或低於 active 保留下限回 `409` 且 rollback。
7. transfer 只允許同 domain、不同庫位，來源減少與目的增加相同數量。
8. 商城與租借只寫各自庫存表；跨 domain conversion 尚未開放。

HTTP 回應需搭配專用測試資料庫查詢前後數量，才能證明沒有重複過帳。

## 8. Coupons／Campground Closures

Coupons：建立唯一 code、驗證重複 `409`、PATCH 保留未提供欄位；issueQuantity 不可低於 claimed；有 claim 不可刪除；無 claim 測試券可刪除並回 404。

Closures：從公開營區取得有效 ID，建立 date_range 後用 `GET /api/booking/closures` 交叉確認；切換 weekly 時互斥欄位應清空；非法日期、缺 weekday、停用／不存在營區不得留下部分資料；DELETE 後公開讀立即消失。

建立者、claimedQuantity 與有效權限都由後端決定，Request 不得偽造。

## 9. 資料庫交叉核對

寫入驗證至少核對：

- 對應主表狀態與 `updated_at`。
- Order／Booking history 的 `actor_id` 與筆數。
- 商品規格／圖片是否正規化，G-2c 沒有新增庫存。
- Inventory post 前後 on-hand 與 movement status。
- Coupon claim 存在時主檔未被破壞。
- Closure 公開讀與 Admin 寫入一致。

## 10. 通過標準

- Admin Session、UID 白名單與全部細權限符合預期。
- view／edit 在 UI 與直接 API 呼叫都無法繞過。
- 成功寫入、錯誤 rollback、重送冪等及歷程操作者皆通過。
- 未實作 Reviews、tag pool、seller note、租借商品寫入不列入完成，前端 readiness 必須阻擋。

