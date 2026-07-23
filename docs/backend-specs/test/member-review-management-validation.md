# 會員評論管理驗證

- 本人可讀取完整評論並修改星等、內容與照片。
- 非本人 `PATCH`、`DELETE` 回傳 `404 NOT_FOUND`。
- 超過 `5` 張照片或內容超過 `1000` 字元回傳 `400`。
- 刪除成功回傳 `204`，`reviews` 與 `review_photos` 關聯消失。
- 會員中心刪除後恢復「評價此商品」操作。
- 未選星等時 Modal 顯示欄位錯誤並將焦點移到星等。
- 送出期間表單控制與送出按鈕停用，文字顯示「送出中...」。
- `REVIEW_ALREADY_EXISTS`、`REVIEW_ORDER_FORBIDDEN`、
  `REVIEW_ORDER_NOT_COMPLETED` 與 `VALIDATION_ERROR` 顯示不同提示。
