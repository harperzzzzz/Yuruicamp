# G-4 Admin Coupons／Campground Closures Swagger 驗證

## 準備

啟動 PostgreSQL 與後端，設定 `FIREBASE_ENABLED=false` 並開啟 `http://localhost:8080/swagger-ui.html`。先呼叫 `POST /api/admin/auth/firebase/session`：

```json
{
  "idToken": "dev:booking-seed-admin:booking-seed@example.test:google:Booking Seed Admin"
}
```

在 Swagger `Authorize` 輸入同一 token（不用加 `Bearer`）。

## 優惠券

1. `POST /api/admin/coupons`，使用契約中的 `SUMMER26` 範例；預期 200，code 為大寫、`claimedQuantity=0`。
2. 重送相同 code；預期 409，列表不可出現第二筆。
3. `GET /api/admin/coupons?q=SUMMER26&status=active`；預期分頁 meta 與資料正確。
4. `PATCH /api/admin/coupons/{id}` 傳 `{"status":"disabled","issueQuantity":120}`；預期其他欄位保留。
5. 對有 `coupon_claims` 的 Seed 優惠券將 `issueQuantity` 改到低於已領取數，或呼叫 DELETE；預期分別 400、409，資料不變。
6. DELETE 本次建立且未領取的優惠券；預期 200，後續 GET 為 404。

## 營區公休

1. 從 `GET /api/booking/campgrounds` 取得有效 `campgroundId`。
2. `POST /api/admin/campground-closures` 建立 `date_range`，例如 `2026-08-01` 到 `2026-08-04`；預期建立者為登入管理員。
3. `GET /api/booking/closures`；預期公開端立即可見同一筆規則，開始日公休、結束日不公休。
4. `PATCH /api/admin/campground-closures/{id}` 切換為 weekly 並提供 `weekday`、`effectiveFrom`、`effectiveTo`；預期 `startDate/endDate` 清為 null。
5. 建立 `startDate=endDate`、weekly 缺 weekday、停用／不存在營區；預期 400 或 404，不得留下部分資料。
6. DELETE 後重新查公開 closures；該規則應消失。

## RBAC 與完成標準

- 只有 `discounts.view` 可讀優惠券、`discounts.edit` 可寫。
- 只有 `booking-calendar.view` 可讀公休、`booking-calendar.edit` 可寫。
- view-only 管理員讀取為 200，POST／PATCH／DELETE 為 403。
- 優惠券領取歷程不被硬刪或覆寫；公休建立者不可由 Request 偽造。
- 所有成功回應使用共用 Envelope，列表具有 `meta`。

這些驗證不可只看後台成功回應：重複 code、已有領取歷程、安全刪除、公開 closures 同步與 view-only RBAC 都跨越資料庫約束或另一個讀取入口，必須逐項確認才能排除前端假成功與權限繞過。
