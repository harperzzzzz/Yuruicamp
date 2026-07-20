# B-3 商品分頁與排序

## 用途

讓 `GET /api/products` 支援分頁與排序。

## 流程

1. Controller 接收 `page`、`size`、`sort`。
2. Service 檢查排序欄位是否允許。
3. Repository 先查本頁商品 ID。
4. Repository 再載入商品完整資料。
5. Controller 回傳商品與分頁資訊。

這樣可以避免商品規格 Join 造成重複資料或分頁錯誤。

## 支援排序

- `id,asc`
- `id,desc`
- `name,asc`
- `name,desc`

其他排序值回傳 `400 VALIDATION_ERROR`。

## 執行測試

```powershell
$env:RUN_BACKEND_IT = "true"
$env:DB_PASSWORD = "與 Docker .env 相同的密碼"
.\mvnw.cmd '-Dtest=ProductCatalogServiceTest,ProductPaginationIntegrationTest' test
```

## 驗證結果

- 分頁沒有重複或遺漏。
- 排序結果與 PostgreSQL 相同。
- 錯誤參數會回傳 `400`。
- Maven 測試 `8` 個通過。
- B-3 已完成。
