# payment_notifications

ECPay（綠界）Webhook／Notify 的冪等紀錄表。  
**業務付款真相**仍在 `orders.payment_status`／`bookings.payment_status`；本表只防止重複通知造成重複入帳。

## 關聯與資料流

```text
orders ──1:N── payment_notifications   （order_id 有值時）
bookings ──1:N── payment_notifications （booking_id 有值時）
```

同一列必須 **剛好** 關聯訂單或預約其中一個（`ck_payment_notifications_order_xor_booking`）。

### 資料流程

1. 後端收到 ECPay Notify（Server-to-Server）。
2. 驗簽後寫入 `payment_notifications`（`provider = ecpay`）。
3. 若 `(provider, merchant_trade_no, COALESCE(provider_trade_no,''))` 已存在 → `result = ignored_duplicate`，不重覆更新訂單／預約。
4. 首次成功處理 → 更新對應 `orders`／`bookings` 的 `payment_status`／`paid_at`，並寫歷程；`result = success`。
5. 驗簽或業務失敗 → `result = failed`（可保留 raw_payload 供排查；勿把卡號寫進應用 log）。

## 欄位說明

| 欄位 | 說明 |
|------|------|
| `id` | 流水號，IDENTITY |
| `provider` | 固定 `ecpay` |
| `merchant_trade_no` | 商店交易編號（對應訂單／預約） |
| `provider_trade_no` | 綠界交易號，可空 |
| `order_id` | 關聯 `orders.id`，可空 |
| `booking_id` | 關聯 `bookings.id`，可空 |
| `raw_payload` | 原始通知 JSON |
| `result` | `success` / `ignored_duplicate` / `failed` |
| `processed_at` | 處理時間，預設 `now()` |

### 索引

- `uq_payment_notifications_provider_trade`：冪等唯一鍵  
- `idx_payment_notifications_order` / `idx_payment_notifications_booking`：依關聯查詢
