# E-2 Booking 可用性 Swagger 驗證

## 測試前確認

- PostgreSQL 已載入最新 schema 與 dev seed。
- 後端已啟動，開啟 `http://localhost:8080/swagger-ui.html`。
- 本端點是公開查詢，不需要按 `Authorize`。

## Swagger 驗證流程

1. 展開 `POST /api/booking/check-availability`，按 `Try it out`。
2. 正常查詢可輸入：

   ```json
   {
     "campgroundId": "C002",
     "checkIn": "2026-08-01",
     "checkOut": "2026-08-03",
     "zones": [
       { "zoneId": "C002-Z-A", "quantity": 2 }
     ]
   }
   ```

   預期 HTTP 200、`available=true`、`availableQuantity=8`。若驗證日期已超過，改成 Asia/Taipei 今天起 1～90 天內、最多 7 晚且不含 2026-09-01 的日期。

3. 將 `checkOut` 改成和 `checkIn` 相同，預期 HTTP 400、`BOOKING_DATE_INVALID`。
4. 將 `checkIn` 改成 Asia/Taipei 今天後第 91 天，預期 HTTP 400、`BOOKING_WINDOW_EXCEEDED`。
5. 使用 dev seed 公休範例 `2026-09-01` 至 `2026-09-02`，預期 HTTP 200、`available=false`、reasons 包含 `CAMPGROUND_CLOSED`，最低剩餘量為 0。

## 完成標準

- 正常與不可訂結果都符合目前的 Booking Contract v0.6。
- 查詢前後不會新增 `bookings`。
- 日期錯誤與政策窗口錯誤使用各自穩定錯誤碼。

Swagger 驗證用來確認公開路徑、Request JSON 與前端實際會收到的 Envelope；zone block、pending 占用及跨晚最低量仍由 PostgreSQL 整合測試保障，因為這些情境需要受控資料才能可靠重現。
