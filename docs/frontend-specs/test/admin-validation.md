# 後台前端實際驗證

## 1. 自動驗證

在 `frontend/` 執行：

```powershell
npm run test:api-client
npm run test:admin-g6
npm run test:admin-rbac
npm run test:admin-customers
npm run test:admin-orders-bookings
npm run test:admin-products
npm run test:admin-inventory
npm run test:admin-g4
npm run smoke
```

這些測試驗證 `AdminRuntime` 開關、Session 權限映射、readiness、facade URL／payload 與未就緒功能零網路請求。

## 2. Admin Session

確認 `AppConfig.ADMIN.USE_BACKEND === true`，開啟 `/admin/login.html`。Development 可使用 dev Token；正式路徑使用 Firebase Google。

登入後 Network 必須出現：

```http
POST /api/admin/auth/firebase/session
```

Dashboard 每次重新整理都要重新建立 Session，再依 `effectivePermissions` 載入第一個可讀模組。不能只依 `sessionStorage.adminLoggedIn` 放行。

Console 檢查：

```javascript
AdminRuntime.isBackendMode();
typeof window.AdminAPI;
typeof window.ApiClient;
typeof window.AppAuth;
typeof window.YuruiApiHttp;
```

預期 Backend mode 為 `true`，前三個物件存在，`YuruiApiHttp` 為 `undefined`。

## 3. RBAC 與 Storage

- view-only 管理員可讀、不可寫；即使人工顯示按鈕，後端寫入仍回 `403`。
- 無 view 權限的模組不得出現在可操作導覽。
- 修改角色或個別覆寫後，前端重新建立 Admin Session，再用最新權限重建 Sidebar。
- 允許保存 UI 快取：`adminId`、`adminName`、`adminRole`、`adminEmail`、`adminPermissions`。
- 不得建立 `adminToken`、`backendJwt`、`accessToken` 等應用自管 Token。

## 4. Readiness 邊界

| 模組 | 目前可驗證 | 必須阻擋 |
| --- | --- | --- |
| Orders | 列表、詳情、出貨、完成 | seller note |
| Bookings | 列表、詳情、確認、完成 | seller note |
| Products | 商品／規格／圖片、上下架、唯讀庫存 | 租借商品寫入、直接改庫存 |
| Inventory | draft、明細、過帳、作廢 | 直接改商品庫存、跨 domain conversion |
| Customers | 列表、詳情、基本更新、停權／恢復 | 新增會員、tag pool |
| Coupons | 列表、建立、更新、刪除 | 已領券資料的破壞性刪除 |
| Booking Calendar | 公休 CRUD | 瀏覽器自行改容量 |
| Permissions | 管理員與個別權限 | 無後端契約的欄位 |
| Reviews | 無 | 整個模組，不得發 `/api/admin/reviews` |

可用 `AdminRuntime.getReadiness()` 與 `isFeatureReady()` 驗證。未就緒功能應顯示停用或回 `ADMIN_FEATURE_NOT_READY`，Network 不得發不存在的 API。

## 5. 各模組實際流程

### Customers

列表與詳情使用 `/api/admin/customers`；更新成功後才刷新畫面。停權後該會員的 `/api/me` 應立即被拒絕，恢復後可再次登入。

### Orders／Bookings

確認列表、詳情、items／zones／rentals／history 來自後端。Orders 只允許 ship、complete；Bookings 只允許 confirm、complete。非法狀態轉換顯示後端 `409`，不可前端假改狀態。

### Products

先取得 `/api/admin/products/lookups`，建立／更新只送分類 ID、品牌 ID、圖片與 variants；不得送庫存、branch、camp 或 rental 欄位。下架後公開詳情為 `404`，後台仍可讀。

### Inventory

建立 draft、加入明細、過帳；draft 不改庫存，post 後才更新。重送 post 不得重複加減；posted 不可再改或取消。商城與租借只寫各自 domain。

### Coupons／Closures

重複券碼、低於已領數量與刪除已有 claim 的券必須失敗且畫面保持原值。公休建立／更新／刪除後，以公開 `/api/booking/closures` 交叉確認。

## 6. Backend-first 失敗驗證

對專用測試資料執行一次成功與一次可預期失敗：

1. 記錄操作前畫面。
2. 送出正式 API。
3. 只有 2xx 才用 Response 更新畫面。
4. 4xx／5xx 時列表、Modal 與 cache 不得顯示成功。
5. 重新整理後畫面應與資料庫一致。

## 7. 真 Firebase、逾期與登出

- Google Email 必須先存在於 `admin_users` 白名單且 active；首次登入綁定 UID。
- Reload 後等待 Firebase currentUser 還原，再重新建立 Admin Session。
- 第二次 401 觸發 `app-auth-expired`，清除 UI Session 並導回 login。
- 登出呼叫 Firebase signOut、清除 Admin UI keys；上一頁不可恢復可操作 Dashboard。

## 8. 通過標準

- G-6 與所有 Admin facade 自動測試通過。
- Session、Bearer、有效權限與 readiness 都來自正式主幹。
- 所有已開放模組能完成至少一次讀取；寫入模組另驗證成功、拒絕與刷新一致性。
- 前端快取或人工改 DOM 不能繞過後端 RBAC。
- 未實作功能不產生 404 請求，也不列為完成。

