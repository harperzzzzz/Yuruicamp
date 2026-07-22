# 高風險問題

本文件彙整 `docs/database-documents` 各資料表文件中標記為高風險的問題。純低風險問題不納入。


## 使用者與管理員

來源：`user-and-admin/customers.md`

- `customers.email` 全表 UNIQUE 可能阻止軟刪除會員重新註冊。引入第三方登入後仍需制定會員回復規則；若產品規則不允許復原，則此設計可以保留。目前 `customers.status` 只有 `active`、`deleted`、`suspended` 三種狀態。


## 庫存

來源：`inventory/inventory-locations.md`

- 正式表以 `product_variants.id` 或 `rental_sku_variants.id` 與 `inventory_locations.id` 組合；正式串接前必須定義明確的 ID 對應與遷移規則。


來源：`inventory/inventory-movements.md`

- 現行前端 Mock 資料仍可含「進貨」、「損耗」、「移轉」等中文類型；正式 API 串接前必須改為送出 canonical 值。
- `inventory_movements.status` 為 `posted` 或 `cancelled` 時的不可變性，需由後端執行。


來源：`inventory/stock-reservations.md`

- 兩種保留帳目前缺少後端執行期寫入與狀態轉換實作；
- 保留、扣庫存、釋放與到期清理必須在同一交易中鎖定對應實體庫存，否則併發請求可能超賣。


## 營區

來源：`camp/calendar.md`

- 前台假日判定固定為週五、週六，未使用 `calendar_dates`；國定假日與日曆資料庫的價格可能不一致。


## 租借

來源：`rentals/rentals.md`

- `rental_listings.active` 與 `rental_skus`、`rental_sku_variants` 的狀態已由 E-4 Booking Checkout 同步驗證；後續其他租借寫入端點也必須沿用相同規則。
- 結構本身未限制 `inventory_locations` 必須是 rental 領域的營區庫位；建立或更新對照時應由服務層驗證庫位類型與領域。


## 訂單與優惠券

來源：`orders-and-coupons/orders-and-coupons.md`

- 前端沒有驗證優惠券有效期間與剩餘數量，屬於前端／後端整合問題。
- 前端沒有真正消耗優惠券，屬於前端／後端整合問題。


## 預約

來源：`bookings/bookings.md`

- 前端目前寫入巢狀 Mock DTO，與正式四張正規化資料表並行；正式 API 必須負責拆寫與交易一致性。
