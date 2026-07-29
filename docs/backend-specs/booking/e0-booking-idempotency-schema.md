# E-0 Booking Checkout 冪等 Schema

## 用途

避免網路重試或重複點擊建立兩筆 `pending` 預約，造成營位與租借庫存重複占用。

## 流程

```text
會員提交 idempotencyKey
→ bookings 保存 key 與 request hash
→ DB 限制同一會員不能重複 key
→ E-3 Service 比較 hash，決定回放或回傳衝突
```

## 規則

- 唯一範圍是 `(customer_id, checkout_idempotency_key)`。
- 不同會員可以使用相同 key。
- `checkout_request_hash` 保存正規化 payload 的 SHA-256 指紋。
- 相同 key、相同 hash 應回放原預約。
- 相同 key、不同 hash 應回 `IDEMPOTENCY_CONFLICT`。
- 本切片只完成 Schema；回放與衝突判斷在 E-3 Application Service 實作。

## 驗證結果

- 獨立暫存 PostgreSQL 已用完整 `latest_schema.sql` 從空資料庫建立成功。
- 同會員重複 key 被 `uq_bookings_customer_checkout_idempotency` 拒絕。
- 不同會員使用相同 key 可以建立，測試最後保留兩筆預約。
- 驗證完成後已移除暫存容器，未修改既有 `yuruicamp-db` 與資料卷。
- 尚未建立 Booking API，因此本切片沒有 Swagger 驗證流程。
