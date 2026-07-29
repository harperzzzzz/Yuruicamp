# AdminLoginPage Spec

**Status:** Active（階段 3：Firebase Google）  
**Category:** Page  
**Design Ref:** N/A - derived from existing source file `admin/login.html`

---

## Overview

Seller admin login via **Firebase Google** (no password). The Google account email must already exist in `admin_users` (whitelist). On success the page stores the existing dashboard `sessionStorage` keys and redirects to `dashboard.html`.

Optional **Dev Token** button appears only when `AppConfig.ENVIRONMENT === 'development'` (backend must accept `dev:` tokens, typically `FIREBASE_ENABLED=false`).

---

## Auth flow

```text
Google popup (YuruiFirebase)
  → POST /api/admin/auth/firebase/session { idToken }   (ApiClient, auth: none)
  → sessionStorage（adminLoggedIn / adminId / adminName / isSuperAdmin / adminPermissions）
  → AppAuth.configure({ auth })
  → dashboard.html
```

Whitelist helper (local only, do not commit real emails):  
[`docs/seed/dev/021-admin-google-whitelist.example.sql`](../../seed/dev/021-admin-google-whitelist.example.sql)

Related contract: [`docs/api/auth-api-contract.md`](../../api/auth-api-contract.md)

---

## TypeScript Interface (conceptual)

```typescript
export interface AdminLoginPageData {
  title: string;
  sourcePath: 'admin/login.html';
  keyAreas: string[];
}

export interface AdminLoginPageProps {
  shell: 'admin';
  data: AdminLoginPageData;
  loading?: boolean;
  errorMessage?: string | null;
}
```

---

## States

| State | Trigger | Visual Change |
|-------|---------|---------------|
| Default | Page loaded | Google CTA + whitelist hint |
| Loading | Login in progress | Spinner on button, buttons disabled |
| Error | Session／Firebase failure | `#loginError` alert with friendly message |
| Dev panel | `ENVIRONMENT === 'development'` | Shows Dev Token button |

---

## Implementation Notes

- Source file: `admin/login.html`.
- G-6 正式模式以 Google Firebase popup 登入，再呼叫 `/api/admin/auth/firebase/session`；不接受員工 ID／任意密碼。
- development 顯示 dev Token 驗收入口；正式環境隱藏。Firebase 未設定、白名單拒絕、停用與 Token 逾期都使用既有 alert／disabled 狀態呈現。
- Firebase ID Token 不寫入 Web Storage；Dashboard 重新載入時由 Firebase SDK 還原使用者並向後端重取有效權限。
- Shared CSS source: `admin/css/admin.css`.
- Shared components: admin/dashboard.html shell and admin partial loader.
- Key UI areas: loginForm, togglePassword, loginError.
- Use `docs/ai-style-sheet.md` and `docs/ai-style-tokens.css` before generating new UI.
- Open question: no Figma reference is present, so existing code is the design source of truth.
- Do NOT replace the existing shell, storage keys, mock data contracts, or partial loader pattern while implementing this spec.

## Acceptance Criteria

- [ ] Google login with whitelisted email → dashboard, sidebar shows admin name
- [ ] Non-whitelisted email → clear error（不進 dashboard）
- [ ] `typeof window.YuruiApiHttp === 'undefined'`
- [ ] Network：`POST .../admin/auth/firebase/session` → 200
- [ ] Logout clears session and returns to login page
- [ ] Development-only Dev Token path documented（needs stub Firebase on backend）
