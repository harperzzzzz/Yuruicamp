# Booking 營區標籤篩選驗證

## 目的

確認公開營區 API 會回傳 PostgreSQL 已建立的環境與設施標籤，前台不會因欄位缺失而把所有營區正規化成空標籤陣列。

## Swagger 驗證

1. 開啟 `http://localhost:8080/swagger-ui.html`，執行 `GET /api/booking/campgrounds`。
2. 確認每筆 `data[]` 都有 `environmentTags`、`facilityTags`；無關聯時應為 `[]`，不可省略或回 `null`。
3. 以目前開發 Seed 的 `C002` 為例，確認 `environmentTags` 包含「高海拔」，`facilityTags` 包含「有雨棚」。
4. 執行 `GET /api/booking/campgrounds/C002`，確認詳情的兩組標籤與列表一致。
5. 停用標籤不應出現在任何一組回應；標籤順序應依 `sort_order`、`id` 保持穩定。

## 前台驗證

1. 重新啟動後端並重新整理 `http://127.0.0.1:5173/booking/pages/camp-search.html`。
2. 勾選「高海拔」，目前 Seed 預期保留 `C002`、`C004`、`C007`、`C009`。
3. 取消後勾選「有雨棚」，目前 Seed 預期保留 `C002`、`C006`、`C007`、`C009`。
4. 同時勾選「高海拔」與「有雨棚」，目前 Seed 預期保留 `C002`、`C007`、`C009`。

## 自動化驗證

```powershell
$env:RUN_BACKEND_IT = "true"
$env:DB_PASSWORD = "<與 .env 的 POSTGRES_PASSWORD 相同>"
.\mvnw.cmd -Dtest=BookingPublicIntegrationTest test
```

`BookingPublicIntegrationTest` 共 7 項，會驗證列表與詳情包含 active 標籤，且停用標籤不會洩漏。

這項驗證是必要的，因為前端正規化會把缺少的標籤欄位轉成空陣列；只檢查資料庫關聯或畫面能否載入，無法發現 API 契約遺漏。
