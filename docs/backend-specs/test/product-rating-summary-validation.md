# Product API 評分統計驗證

在 Swagger 分別執行：

- `GET /api/products?page=0&size=20&sort=id,asc`
- `GET /api/products/P001`
- `GET /api/products/P001/reviews`

確認 Product API 的 `rating`、`reviewCount` 與公開評論 API 的 `summary.averageRating`、`summary.totalCount` 使用相同正式評論資料。

前端執行 `npm.cmd run test:product-rating` 驗證 `v0.4` 契約與 Backend facade 不再用 Mock 評論覆寫正式統計。
