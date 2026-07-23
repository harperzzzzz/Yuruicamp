# G-6 Admin 正式 Runtime 與全站接線

## 用途

讓後台依 `AppConfig.ADMIN.USE_BACKEND` 正式啟用 Admin API，完成 Firebase 管理員登入、後端 Session、有效權限初始化、Token 刷新及各模組 Backend readiness gate。

## 啟動流程

```text
登入頁載入 Firebase
→ Google popup 取得 Firebase ID Token
→ POST /api/admin/auth/firebase/session
→ 後端驗證 Email 白名單、active 與 Firebase UID
→ 回傳 effectivePermissions
→ 前端建立 Sidebar view/edit 矩陣
→ Dashboard 每次重整重新驗證 Session 與權限
```

Firebase ID Token 只由 Firebase SDK 的 `currentUser.getIdToken()` 提供，不寫入 localStorage 或 sessionStorage。SessionStorage 只保存管理員顯示資料與 UI 權限快取；所有 API 仍由後端逐次執行 RBAC。

本機 `FIREBASE_ENABLED=false` 時可在 development 登入區輸入完整 `dev:` Token。此 Token 只保存於該分頁的 sessionStorage，正式環境不顯示此入口。

## Token 與登出

- 受保護 API 回 401 時，`ApiClient` 呼叫 Firebase 強制刷新並重送一次。
- 第二次仍為 401 時發出 `app-auth-expired`，清除 Admin UI Session 並導回登入頁。
- 403 不自動重試，保留後端 RBAC 錯誤供頁面顯示。
- 登出同時清除 Admin Session 並呼叫 Firebase `signOut()`。

## Backend readiness

| 模組 | 狀態 | G-6 行為 |
|------|------|----------|
| Analytics | Read | 使用正式 Orders／Products／Bookings 聚合 |
| Orders | Partial | 查詢、出貨、完成、內部備註可用；取消／退款待 W3 |
| Inventory | Full | draft、明細、過帳與作廢可用 |
| Products | Partial | 商城商品與最低庫存閾值可用；租借寫入／跨領域調撥 UI 見下方「已知延後」 |
| Customers | Partial | 查詢、基本更新、停權可用；新增會員、Email／地址與標籤池停用 |
| Coupons | Full | 正式 CRUD 可用 |
| Reviews | Blocked | Sidebar 標示「未接」，不呼叫 `/api/admin/reviews` |
| Booking Calendar | Partial | 公休 CRUD 可用；月份容量不在瀏覽器自行推算 |
| Bookings | Partial | 查詢、確認、完成、內部備註可用；已付款取消待 W3 |
| Permissions | Full | 管理員、角色與個別權限可用 |

未就緒 facade 回 `ADMIN_FEATURE_NOT_READY`，不發送網路請求，也不先修改 cache。G-6 完成代表後台已正式接線，不代表 Reviews、租借商品維護或 seller note 已取得新的後端契約。

### 已知延後（W2 前端 UI，後端可另開）

專檔：[`plans/admin-post-g6/w2/W2-ui-followups.md`](../../plans/admin-post-g6/w2/W2-ui-followups.md)

1. **租借整頁**（`products.js` 定價／上架）：舊資料模型尚未改接 listing／規格 API。  
2. **調撥到租借 Modal**：仍改前端記憶體，尚未打 `inventory-conversions`。

## 驗證

`npm run test:admin-g6` 驗證模式切換、Session 權限映射、列表 meta 與未就緒功能零網路請求；`npm run test:api-client` 驗證 401 強制刷新。RBAC、Customers、Orders／Bookings、Products、Inventory 與 G-4 facade 亦已一併回歸通過。

2026-07-22 以 `RUN_BACKEND_IT=true` 同批執行 G-1～G-4 六個 PostgreSQL 整合測試類別，結果為 **14 tests、0 failure、0 error、0 skipped**。G-1 與 G-4 使用固定 fixture，因此測試類別強制同執行緒，避免平行方法互相清除資料。
