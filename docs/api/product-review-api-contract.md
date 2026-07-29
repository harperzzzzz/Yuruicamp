# 商品公開評論 API 契約

`GET /api/products/{productId}/reviews` 是不需登入的公開端點，只讀取正式 `reviews` 與 `review_photos`。

- `page`：從 `0` 開始，預設 `0`
- `size`：`1` 至 `100`，預設 `20`
- `sort`：`latest`、`highest`、`lowest`
- `rating`：選填，精確篩選 `1` 至 `5` 星
- `hasPhotos`：預設 `false`；設為 `true` 時只回傳至少有一張照片的評論

`data.items` 是目前篩選條件的評論。`data.summary` 永遠統計整個商品，
包含 `totalCount`、`averageRating` 與 `ratingCounts`；`meta.totalElements`
則代表目前篩選結果的總筆數，供前端判斷是否能繼續載入。公開回應不包含會員與訂單識別資訊。

商品不存在或不可公開販售時回傳 `404 NOT_FOUND`；參數不合法回傳 `400 VALIDATION_ERROR`。

所有欄位均視為不可信 API 資料。前端必須使用 `textContent` 或安全的 DOM property，不能把買家姓名、評論、日期或圖片 URL 拼接進 `innerHTML`。
