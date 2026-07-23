# 會員商品評論 API 驗證

## 自動測試

在 `backend/`：

```powershell
.\mvnw.cmd -Dtest=MemberReviewServiceTest test
```

在 `frontend/`：

```powershell
npm.cmd run test:member-reviews
```

## Swagger／HTTP 驗證

1. 使用有 `completed` 商城訂單明細的會員 Bearer Token。
2. 呼叫 `GET /api/me/orders`，取得一個尚未評價的 `items[].id`。
3. 呼叫 `POST /api/me/reviews`，body 只送 `orderItemId`、`rating`、`comment`。
4. 預期 `2xx`，回傳 `verifiedPurchase=true`，且會員、訂單、商品與建立時間都由後端產生。
5. 重送相同 `orderItemId`，預期 `409 REVIEW_ALREADY_EXISTS`。
6. 換另一位會員的 Token 使用同一 `orderItemId`，預期 `403 REVIEW_ORDER_FORBIDDEN`。
7. 使用未完成訂單明細，預期 `409 REVIEW_ORDER_NOT_COMPLETED`。
8. 不帶 Token，預期 `401 UNAUTHORIZED`。
9. 呼叫 `GET /api/me/reviews`，新評論應存在；另一位會員不得讀到。
10. 送出只包含空白的 `comment`，確認 Response 與資料庫保存為 `null`。
11. 送出超過 `1000` 字的 `comment`，預期 `400 VALIDATION_ERROR`，且 `details` 包含 `comment`。

這些驗證能確認所有權、訂單狀態與重複評論具有不同的穩定錯誤碼，
讓前端不必依賴英文訊息猜測失敗原因。
