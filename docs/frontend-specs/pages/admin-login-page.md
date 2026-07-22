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

- Source: `admin/login.html`
- Helpers: `admin/js/admin-auth.js`（`AdminAuth.loginWithGoogle`／`logout`／`restoreAppAuthIfNeeded`）
- Scripts required: `/storefront/js/config.js`, `/storefront/js/api-client.js`, `js/permissions.js`, `js/admin-auth.js`
- Dashboard logout should call `AdminAuth.logout()` then redirect to `login.html`
- Password／employee-ID demo login has been removed
- Do NOT commit real Google emails into seed SQL

---

## Acceptance Criteria

- [ ] Google login with whitelisted email → dashboard, sidebar shows admin name
- [ ] Non-whitelisted email → clear error（不進 dashboard）
- [ ] `typeof window.YuruiApiHttp === 'undefined'`
- [ ] Network：`POST .../admin/auth/firebase/session` → 200
- [ ] Logout clears session and returns to login page
- [ ] Development-only Dev Token path documented（needs stub Firebase on backend）
