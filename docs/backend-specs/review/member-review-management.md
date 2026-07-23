# 會員評論管理

會員中心在完成訂單商品旁顯示「查看／修改評論」，同一個評論 Modal 會載入既有星等、完整內容與照片。

- 儲存修改：`PATCH /api/me/reviews/{reviewId}`
- 刪除評論：`DELETE /api/me/reviews/{reviewId}`
- 可保留、移除既有照片，也可上傳新照片，總數仍限制 `5` 張。
- 所有權由 Firebase Principal 與訂單 `customer_id` 驗證。
- 刪除後該訂單明細可重新建立評論。
- Modal 顯示評論字數、欄位錯誤與後端業務錯誤，送出期間鎖定控制以避免重複請求。
- 空白內容送出為 `null`；內容最多 `1000` 字。
