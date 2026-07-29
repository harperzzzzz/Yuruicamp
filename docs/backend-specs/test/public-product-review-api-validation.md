# 商品公開評論 API 驗證

執行 `.\mvnw.cmd -q -Dtest=PublicProductReviewServiceTest,MemberReviewCreateRequestValidationTest test`。

Swagger 測試：

1. 呼叫 `GET /api/products/P001/reviews?page=0&size=6&sort=latest`，記錄整體 `data.summary`。
2. 改用 `sort=highest` 與 `sort=lowest`，確認順序正確。
3. 加上 `rating=5`，確認每筆都是 `5` 星，且 `meta.totalElements` 是篩選後數量。
4. 加上 `hasPhotos=true`，確認每筆 `photos` 至少有一張。
5. 確認套用篩選前後的 `data.summary` 相同，評分分布不受瀏覽條件影響。
6. 使用不存在商品確認回傳 `404 NOT_FOUND`。

前端執行 `npm.cmd run test:product-reviews` 與
`npm.cmd run test:product-review-xss`，確認評論瀏覽參數及安全 DOM renderer。

這些驗證可確認整體評分統計和篩選分頁沒有混用，避免前端錯誤顯示載入更多按鈕，
同時確保公開評論資料不會直接進入 `innerHTML`。
