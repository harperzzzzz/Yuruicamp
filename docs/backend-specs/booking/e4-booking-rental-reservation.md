# E-4 Booking 租借加購

## 用途

讓會員建立 Booking Checkout 時一併保留住宿期間的租借裝備，避免日期重疊時超租。

## 流程

```text
POST /api/booking/checkout/sessions
→ 驗證 listing、variant、營區與啟用狀態
→ 解析營區 rental location
→ 固定順序鎖定 rental_sku_variant_stocks
→ 扣除日期重疊的 active reservations
→ 後端計算租借金額
→ 建立租借快照與 active rental_stock_reservations
```

## 規則

- 可租量是實體庫存減去相同庫位、variant、重疊日期的 active 保留數量。
- 日期採 `[checkIn, checkOut)`；相鄰租期可以共用同一批庫存。
- listing 必須屬於 request 營區，且 listing、equipment item、SKU、variant、營區庫位都必須有效。
- 租借金額使用資料庫平假日價格；`discount` 依 Schema 視為 `0.00～0.30` 折扣比率。
- 租借不足會回滾整筆 Booking，不留下表頭、明細或保留帳。
- E-4 建立的保留帳固定為 `active`；後續主動取消與逾時釋放已由 E-6 接手處理。

## 驗證結果

- `BookingRentalCheckoutIntegrationTest` 在只有完整 Schema、沒有 dev seed 的 PostgreSQL 執行 8 項，全部通過。
- 已驗證無租借、庫存足夠／不足、日期不重疊可共用、重疊不可超租、營區／variant 關係、停用狀態與冪等指紋。
- 兩個交易搶最後一件租借品時只有一筆成功；E-3～E-4 共 15 項回歸測試通過。
