# 會員評論圖片上傳

本機 MVP 使用檔案系統 adapter，儲存於 `REVIEW_UPLOAD_DIR`，預設 `backend/data/uploads/reviews`，公開 URL 為 `/assets/uploads/reviews/**`。

流程：

1. 前端限制數量、格式與容量並建立本機預覽。
2. 後端確認 Firebase Principal 對應會員擁有該已完成訂單明細。
3. 後端檢查 JPEG、PNG、WebP 特徵碼後產生 UUID 檔名。
4. 建立評論時驗證 URL 所有權並寫入 `review_photos`。
5. 公開商品評論回傳照片；商品頁只接受同源評論路徑或 `HTTPS`，載入失敗顯示替代狀態。

正式雲端部署可將 `ReviewPhotoStorageService` 替換為 Cloud Storage，不變更 Controller 與評論資料契約。
