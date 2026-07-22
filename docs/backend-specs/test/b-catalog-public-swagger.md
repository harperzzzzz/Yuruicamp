# 線 B Catalog 公開讀 Swagger 驗證

## Swagger 驗證流程

1. 啟動 PostgreSQL 與 Spring Boot，開啟 `http://localhost:8080/swagger-ui.html`。
2. 在 `Catalog` 執行 `GET /api/products`，加入 `category`、`brand`、`minPrice`、`maxPrice`，確認資料符合條件且保留 `meta`。
3. 不傳任何篩選參數執行一次，確認商品正常載入且後端沒有 `lower(bytea)` 錯誤。
4. 將 `minPrice` 設得大於 `maxPrice`，確認回傳 `400 VALIDATION_ERROR`。
5. 執行商品列表與詳情，確認每個 variant 都有非負整數 `availableQuantity`，且 `inStock` 與數量是否大於 `0` 一致。
6. 建立 active 庫存保留帳後再次查詢，確認對應 variant 可售量下降；改成 released 後不再扣除。
7. 在 `Branches` 執行 `GET /api/branches`，確認不需 Token、Envelope 成功且資料依 `id` 排序。

這些驗證可確認查詢參數、即時保留量與公開權限都經過實際 HTTP 與 PostgreSQL，而不只是在 Java 單元測試中成立。
