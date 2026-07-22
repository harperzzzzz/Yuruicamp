# B-4／B-5b／B-7 Catalog 公開讀

## 用途

完成商品篩選、規格即時可售量與公開門市列表。

## 商品篩選

`GET /api/products` 可搭配 `category`、`brand`、`minPrice`、`maxPrice`，並繼續支援分頁與排序。分類與品牌採完整名稱、忽略大小寫；價格條件採包含邊界，只要商品至少一個 active variant 落在區間內就會保留。

負數價格或 `minPrice > maxPrice` 回傳 `400 VALIDATION_ERROR`。

未傳 `category`／`brand` 時，Service 會使用空字串代表不篩選；未傳價格時使用 `0.00` 到 `9999999999.99`。Repository 因此不會收到無型別的 `null`，可避免 PostgreSQL 將 `lower()` 參數誤判成 `bytea`，同時保留四種可選篩選的組合能力。

## 規格可售量

後端以 variant 為粒度加總 `inventory_stocks.on_hand_quantity`，再扣除 `product_stock_reservations.status = active` 的數量。結果最低為 `0`，並回傳：

- `availableQuantity`：目前可售數量。
- `inStock`：可售數量大於 `0` 時為 `true`。

此查詢是 Catalog 唯讀模型；Checkout 仍會在交易內重新鎖定庫存，不能以公開讀取結果取代防超賣檢查。

## 門市列表

`GET /api/branches` 讀取 `branches`，依 `id` 遞增回傳。Controller 只包裝 Envelope，Service 負責 Entity 到 DTO 的轉換。

## 驗證結果

- `mvnw.cmd test -DskipTests=false`：通過，共 `80` 項；`18` 項一般測試執行成功，`62` 項 PostgreSQL 整合測試因未設定 `RUN_BACKEND_IT=true` 而跳過。
- 實際 PostgreSQL API：無篩選回 `200`；`brand=Coleman` 回 `2` 筆；`minPrice=3000&maxPrice=3500` 回 `2` 筆；反向價格區間回 `400`。
- 上述無篩選請求未再出現 `lower(bytea)`，B-4 已完成實際端點驗收。
- 完整 PostgreSQL 情境仍應依 Swagger 文件手動驗證商品篩選、保留量與門市資料。
