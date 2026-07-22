# G-3 Admin Inventory 前端驗收

## 驗證目的

確認正式庫存只能從 Movement 頁建立 draft 並過帳，Products 頁與前端記憶體不會直接修改資料庫庫存。

## 準備

1. 啟動 PostgreSQL、Spring Boot 與 `frontend/` Vite。
2. 使用具有 `movement.view`／`movement.edit` 的管理員登入。
3. G-6 完成前，在 DevTools Console 啟用：

```js
AdminAPI.configure({
  useBackend: true,
  baseUrl: 'http://localhost:8080/api/admin'
});
```

4. 重新進入「庫存異動紀錄」頁。

## 建立 draft

1. 點「建立異動草稿」。
2. 切換商城／租借時，來源、目的與規格選項應只顯示相同 inventory domain 的 lookup。
3. 入庫只顯示目的庫位；出庫／損耗只顯示來源；調撥同時顯示兩者。
4. 加入兩筆不同規格，填寫原因後建立。
5. Network 應先送 `POST /inventory-movements`，再逐筆送 `POST /{id}/items`；Request 不含目前庫存、前端總庫存或 employeeId。
6. 成功後列表顯示草稿 badge；此時商品頁庫存仍不變。

若表頭成功但其中一筆明細失敗，畫面應提示草稿已建立，可從詳情繼續補明細，不應在前端假裝整張成功。

## 草稿詳情、過帳與作廢

- 點 movementNo 開啟詳情，草稿可新增尚未存在的規格明細。
- 點「確認過帳」後，只有 API 成功才把列表狀態改成「已過帳」並隱藏新增、過帳與作廢按鈕。
- 快速連點或 Network 重送 post，不得讓庫存增加兩次。
- 建立另一張 draft 後作廢，狀態顯示「已作廢」，且不能再過帳。
- 負庫存或低於 active 保留量時顯示後端錯誤，Modal 保持可檢查，列表不能先改成已過帳。

## Products 頁邊界

Backend 模式下，Products 頁庫存輸入與舊「產生異動紀錄」流程不可成為正式寫入入口。若舊程式嘗試呼叫 `addMovementRecord()`，應提示改到 Movement 頁建立草稿，而不是把胖 Mock 紀錄送入後端。

商城轉租借不應出現在一般 transfer 選項；G-3 只允許同領域調撥。

## Mock 模式回歸

切回 `useBackend:false`，原本 JSON 紀錄、日期篩選、員工與類型篩選、明細 Modal 維持可用，不呼叫正式 draft／post API。

## 自動檢查

```powershell
cd frontend
npm run test:admin-inventory
npm run smoke
npm run build
```

自動測試保護 API 路徑、Bearer、canonical mapping 與 Backend 正式入口；人工驗收仍必要，因為欄位顯示切換、Modal 狀態、快速連點與錯誤後輸入保留屬於瀏覽器互動狀態。
