# G-4 Admin 優惠券／公休前端驗收

## 準備

啟動 PostgreSQL、Spring Boot 與 `frontend/` Vite，使用具 G-4 權限的管理員登入。G-6 完成前，在 DevTools Console 啟用：

```js
AdminAPI.configure({
  useBackend: true,
  baseUrl: 'http://localhost:8080/api/admin'
});
```

## 優惠券頁

1. 進入優惠券頁，Network 應呼叫 `GET /coupons`，表格顯示名稱、類別、發行與已領取數。
2. 建立優惠券時 Request 只含正式契約欄位，不得包含 `used`、前端計算剩餘量或 ID。
3. 成功後才新增表格列並清空表單；以 DevTools 阻擋請求時，表單與原 cache 應保留，不可顯示假成功。
4. 切換狀態與刪除亦須 API 成功後才更新；已領取優惠券的刪除按鈕停用，直接呼叫 API 仍應收到 409。
5. 快速連點操作時按鈕會暫時停用，不送重複請求。

## 預約排程公休

1. 進入排程頁，公休列表應呼叫 `GET /campground-closures`，不讀寫 `mockCampgroundClosures` overlay。
2. 建立日期公休，確認 Network 使用 `closureType=date_range` 且只送日期區間；建立成功後重新查詢並顯示。
3. 建立每週公休，確認只送 `weekday/effectiveFrom/effectiveTo`；多選星期會建立多筆正式規則。
4. 阻擋 POST 或 DELETE 時，原列表不應先變動；若多星期中部分成功，頁面必須重新查資料庫呈現實際結果並顯示錯誤。
5. 刪除成功後重新查詢，公開預約 closures 與可用性也不再套用該規則。

Backend 模式目前只完成 G-4 公休規則管理；正式月份可用量聚合仍依既有 Booking API 能力，不在本任務新增另一份前端推算真相。

## Mock 回歸與自動檢查

切回 `useBackend:false`，優惠券 JSON 與公休 overlay 流程仍可操作，不呼叫 Admin G-4 API。

```powershell
cd frontend
npm run test:admin-g4
npm run smoke
npm run build
```

自動測試保護 API 路徑、Bearer、乾淨 Request 與 backend-first 程式順序；錯誤後表單保留、多星期部分成功與 RBAC 顯示仍需瀏覽器人工驗收。
