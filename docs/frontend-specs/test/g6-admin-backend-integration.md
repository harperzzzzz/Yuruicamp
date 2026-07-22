# G-6 Admin 正式 Backend 全站驗收

## 準備

1. 啟動 PostgreSQL、Spring Boot 與 `frontend/` Vite。
2. 確認 `AppConfig.ADMIN.USE_BACKEND=true`。
3. 正式 Firebase 驗收需填妥 `frontend/.env.local`；本機 stub 可使用登入頁 development dev Token。
4. 清除舊 Admin sessionStorage，重新開啟 `/admin/login.html`。

## 正式登入

1. 登入頁只顯示 Google 管理員登入；員工 ID／任意密碼表單不可見。
2. Google 登入後 Network 必須先送 `POST /api/admin/auth/firebase/session`。
3. 未白名單、停用或 UID 不一致時留在登入頁並顯示後端訊息。
4. 成功後進入 Dashboard，Sidebar 只開放 `effectivePermissions` 允許且 readiness 已完成的模組。
5. Application Storage 不應出現 Firebase ID Token；sessionStorage 只含 Admin UI Session。development dev Token 例外，只存在目前分頁。

## Readiness 與模組操作

- Topbar 顯示綠色 `Backend` badge。
- Reviews 導覽灰階並標示「未接」，點擊不應產生 `/api/admin/reviews`。
- Orders／Bookings seller note 為停用狀態；Customers 不顯示新增會員與標籤池維護；Products 不顯示租借商品寫入。
- RBAC、Customers、Orders／Bookings、Products、Inventory、Coupons、Closures 與 Permissions 均只呼叫 `/api/admin/**` 正式端點。
- 任一寫入失敗時保留原畫面，不先修改 cache。

## Token、權限與登出

1. 將第一個受保護請求模擬為 401，確認會以 Firebase 強制刷新 Token 重送一次。
2. 第二次仍為 401 時應返回登入頁並顯示「登入已逾期」。
3. 在 Permissions 修改自己的角色或權限後，頁面重新取得 Admin Session 並重載 Sidebar。
4. 點登出後 Firebase 使用者與 Admin sessionStorage 都被清除，直接開 Dashboard 會回登入頁。

## 自動檢查

```powershell
cd frontend
npm run test:api-client
npm run test:admin-g6
npm run test:admin-rbac
npm run test:admin-customers
npm run test:admin-orders-bookings
npm run test:admin-products
npm run test:admin-inventory
npm run test:admin-g4
npm run smoke
npm run build
```

人工驗收仍必要，因為 Firebase popup、瀏覽器 Token 持久化、401 導頁、Sidebar readiness 樣式及修改自身權限後重載都屬於真實瀏覽器生命週期；單純 facade 測試無法證明整條登入與導覽流程。
