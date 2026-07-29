# G-1／G-5 管理員 RBAC

## 用途

管理員先以 Firebase ID Token 通過白名單與啟用狀態，再由後端合併角色預設和個人覆寫。`ROLE_ADMIN` 只代表管理員身分，端點仍以 `permissions.view`／`permissions.edit` 判斷操作權限。

## 流程

```text
Firebase Token
→ 比對 admin_users email、active、firebase_uid
→ 讀取 admin_role_permissions
→ 套用 admin_user_permissions.allowed
→ 建立 Spring Security authorities
→ @PreAuthorize 檢查端點權限
```

建立管理員時只建立白名單，固定為 `active=true`、`firebase_uid=null`。第一次 Admin Session 成功後才綁定 Firebase UID；已綁定帳號若 UID 不同會拒絕。

權限更新傳入完整權限集合，Service 只保存和角色預設不同的覆寫。`edit=true` 必須同時具備同 section 的 `view=true`。

## 保護規則

- 不提供管理員 DELETE，離職改為 `active=false`。
- 不可停用自己。
- 不可停用或降級最後一位啟用中的 `admin`。
- 不可移除自己的 `permissions.edit`。
- 更新管理員時以悲觀鎖避免狀態互相覆蓋。

## 前端

`AdminAPI.users` 與 `AdminAPI.permissions` 提供正式 REST facade。Mock 模式保留原本的 `localStorage.adminEmployees`；Backend 模式只讀寫正式 API。全站 AdminAPI 切換仍屬 G-6。

## 驗證

- `mvnw.cmd -q -DskipTests compile`
- `mvnw.cmd -q -Dtest=AdminPermissionServiceTest test`
- `npm.cmd run test:admin-rbac`
- `node --check admin/js/permissions.js`
- 設定正確 `DB_PASSWORD` 後執行 `AdminRbacPostgreSqlIntegrationTest`
