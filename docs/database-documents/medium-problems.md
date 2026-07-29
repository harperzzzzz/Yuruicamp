# 中風險問題

本文件彙整 `docs/database-documents` 各資料表文件中標記為中風險

## 文章

來源：`articles/articles.md`

- `articles.updated_at` 沒有自動更新 Trigger；更新文章時必須由後端 Service 明確寫入。
- `article_dto_view` 會輸出所有狀態的文章；若前台直接使用 View，查詢層必須加上 `status = 'published'` 條件。


## 使用者與管理員

來源：`user-and-admin/customers.md`

- 前端 `customers.json` 仍有 `totalSpent`，但資料庫已將消費總額統一由 `customer_spending_summary.total_spent` 計算。
- `updated_at` 不會自動更新，需由 Spring Boot Service 處理。


來源：`user-and-admin/admin_users.md`

- 更新資料時不會自動更新時間，需由 Service 統一寫入或加上 Trigger。


## 庫存

來源：`inventory/inventory-conversions.md`

- `inventory_conversions` 沒有 `updated_at`；建立後若允許修改，無法記錄最後更新時間。實務上轉換完成後應視為不可修改。


來源：`inventory/inventory-locations.md`

- 四張庫存／最低庫存表的 `updated_at` 只有預設值，更新數量或門檻時不會自動刷新時間。


來源：`inventory/inventory-movements.md`

- 三張異動相關資料表的 `updated_at` 只有預設值，更新時不會自動刷新。


來源：`inventory/stock-reservations.md`

- 商城保留帳允許 `expires_at` 為 NULL；服務層必須定義無到期時間的有效使用情境，避免永久 `active` 保留。
- 租借可用性依日期區間重疊計算，必須固定使用 `[check_in, check_out)` 語意，否則相鄰租期可能被錯誤判定為衝突。


## 營區

來源：`camp/camps.md`

- `updated_at` 僅有預設值，更新資料時不會由資料庫自動改寫；應由後端服務統一處理。


來源：`camp/calendar.md`

- `updated_at` 僅有預設值，後續更新不會由資料庫自動更新；應由後端服務統一處理。


## 租借

來源：`rentals/rentals.md`

- `updated_at` 不會自動更新，應由 Spring Boot Service 在更新時一併寫入。


## 訂單與優惠券

來源：`orders-and-coupons/orders-and-coupons.md`

- 後端 Service 現在狀態與狀態歷程要同步更新



## 預約

來源：`bookings/booking-policies.md`

- `updated_at` 不會在 UPDATE 時自動刷新，應由 Spring Boot Service 統一更新。


來源：`bookings/bookings.md`

- 資料庫未強制每次 `status` 更新都要新增歷程；應由 Service 在同一交易內處理，或設計受控的資料庫函式。
- `bookings.created_at` 沒有預設值，所有新增流程都必須明確提供時間。
- `bookings.updated_at` 預設只在 INSERT 生效，UPDATE 不會自動刷新；應由 Spring Boot Service 統一更新。
- `booking_selected_zones` 與 `booking_selected_rentals` 沒有明細小計欄位；表頭金額須由Service 依日期、價格、數量與折扣計算並驗證。


## 分店

來源：`branches/branches.md`

- `admin_users` 與 `branches` 的 `updated_at` 不會自動更新。
