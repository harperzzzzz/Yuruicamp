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

狀態：已完成。

- Product API v0.3 已定義 `availableQuantity` 與 `inStock`。
- Catalog 已建立 variant 粒度的 Repository Projection。
- `sellable_product_variants` 只過濾 active 狀態，不包含庫存數量。
- `product_stock_summary` 以 `product_id` 聚合，不能判斷單一 variant 的可售量。

## 實作流程

1. Product API Contract 已升至 v0.3。
2. 已建立以 `variant_id` 為粒度的讀模型。
3. 可售量以 `inventory_stocks.on_hand_quantity` 扣除 active `product_stock_reservations.quantity` 計算。
4. 後端 DTO 與 OpenAPI 已同步更新。
5. Swagger 驗證流程見 `docs/backend-specs/test/b-catalog-public-swagger.md`。

## 驗證結論

- B-5a 可標記完成。
- B-5b 已完成；Checkout 仍須在交易內重新鎖庫存，公開可售量不能取代防超賣驗證。
