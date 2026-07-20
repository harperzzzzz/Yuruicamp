# B-5 商品規格與可售庫存狀態

## 用途

記錄 B-5 已完成與尚未完成的邊界，避免把「active 商品規格」誤認為「目前仍有庫存可販售」。

## B-5a 基本商品規格

狀態：已完成。

- `GET /api/products` 與 `GET /api/products/{id}` 都會回傳 `variants[]`。
- 只回傳 `product_variants.status = 'active'` 的規格。
- 欄位包含 `id`、`sku`、`color`、`size`、`specification`、`price`。
- `price` 由後端 `BigDecimal` 格式化為固定兩位小數字串。
- 沒有 active variant 的商品不會出現在列表，詳情回傳 `NOT_FOUND`。

## B-5b 規格層級可售庫存

狀態：未實作。

- Product API v0.2 尚未定義 `availableQuantity` 或 `inStock`。
- Catalog 尚未建立庫存 Repository、Projection 或 View Entity。
- `sellable_product_variants` 只過濾 active 狀態，不包含庫存數量。
- `product_stock_summary` 以 `product_id` 聚合，不能判斷單一 variant 的可售量。

## 後續流程

1. 將 Product API Contract 升版，寫死 variant 庫存欄位與缺貨商品顯示規則。
2. 建立以 `variant_id` 為粒度的讀模型。
3. 可售量以 `inventory_stocks.on_hand_quantity` 扣除 active `product_stock_reservations.quantity` 計算。
4. 後端 DTO、OpenAPI、前端 Mock 與頁面同步更新。
5. 補上零庫存、部分保留、多庫位加總與已釋放保留帳的 PostgreSQL 整合測試。

## 驗證結論

- B-5a 可標記完成。
- B-5b 維持未完成，不能因 API 已有 `variants[]` 就宣稱可售庫存已接通。
