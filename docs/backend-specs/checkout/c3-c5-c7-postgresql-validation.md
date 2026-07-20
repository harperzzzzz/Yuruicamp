# C-3、C-5、C-7 Checkout 整合驗收

## 用途

確認 Checkout 在真正的 PostgreSQL 中不會超賣，取消後會釋放庫存，而且金額只相信資料庫。

## 流程

```text
建立測試商品與庫存
→ 建立 Checkout
→ 檢查訂單、明細快照與庫存保留
→ 取消 Checkout 並檢查 released
→ 兩位會員同時搶最後一件庫存
→ 傳入偽造價格並比對資料庫價格
```

## 規則

- 庫存列使用 `PESSIMISTIC_WRITE`，同一件庫存一次只讓一個交易判斷。
- 可用量是現有庫存扣除 `active` 保留量。
- 取消未付款 Checkout 時，保留狀態改為 `released` 並寫入釋放時間。
- Request DTO 不接受商品單價與總額作為計價依據。
- `payment_method` 寫入時明確轉成 PostgreSQL ENUM。

## 開發資料

`docs/seed/002-dev-catalog.sql` 會建立：

- 庫位 `DEV-STORE-MAIN`。
- `V001` 現有庫存 `10` 件。

既有資料庫需手動重新執行 Seed；不必刪除 Docker volume。

## 驗證結果

- `orders` 與 `order_items` 寫入成功。
- 商品名稱、SKU、規格、品牌、單價及數量快照正確。
- `product_stock_reservations` 建立為 `active`。
- 取消後保留狀態變成 `released`。
- 兩位會員同時搶最後一件庫存時，只有一筆成功，另一筆回傳 `STOCK_INSUFFICIENT`。
- 偽造 `unitPrice=0.01` 與 `total=0.01` 時，訂單仍使用資料庫單價 `1234.56`。
- `RUN_BACKEND_IT=true` 執行 Maven：`19` 個測試全部通過，沒有跳過。

## 尚未完成

- C-6 的 `15` 分鐘逾時釋放排程。
- C-8 的逾時整合測試，需等 C-6 完成。
