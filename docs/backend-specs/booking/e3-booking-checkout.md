# E-3 Booking Checkout

## 用途

會員進入預約結帳時，由後端鎖定營位、重算金額並建立 15 分鐘有效的待付款預約。

## 流程

```text
POST /api/booking/checkout/sessions
→ 驗證會員與冪等鍵
→ 鎖定營區，依 zoneId 排序鎖定營位
→ 同一交易內重查跨晚可用量
→ 依 calendar_dates 計算平日／假日晚數與金額
→ 建立 pending + unpaid Booking、營位快照、狀態歷程
→ 回傳 ready_to_pay 與 checkoutExpiresAt
```

## 規則

- 相同會員、相同 key 與相同內容回放原預約；不同內容回 `IDEMPOTENCY_CONFLICT`。
- 金額只採資料庫營位價格與日曆結果，忽略前端自算金額。
- 營位不足或公休回 `ZONE_UNAVAILABLE`，交易不留下半成品。
- 初始狀態固定為 `pending`、`unpaid`，期限為建立時間加 15 分鐘。
- 預約禁止 COD；租借加購已由 E-4 補上，優惠券仍等待線 F。

## 驗證結果

- `BookingCheckoutIntegrationTest` 在只有完整 Schema、沒有 dev seed 的 PostgreSQL 執行 7 項，全部通過。
- 已驗證會員保護、價格防竄改、平假日計價、快照與歷程、15 分鐘期限、冪等回放／衝突、延期功能邊界及 pending 占用。
- 兩個會員以相反 zone 順序並發搶最後營位時只有一筆成功，沒有超賣或死鎖。
