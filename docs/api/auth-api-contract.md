# Auth API Contract（v0.1）

| 欄位 | 內容 |
|------|------|
| **狀態** | Locked（線 A 已實作） |
| **日期** | 2026-07-20 |
| **版本** | 0.1 |
| **共用** | [`common-api-conventions.md`](./common-api-conventions.md) |
| **DB** | `customers`、`admin_users` |

---

## 0. 一句話

前端用 Firebase 登入拿 **ID Token** → 打 session 綁定／upsert DB → 之後請求帶同一個 Bearer Token；**後端不簽發 JWT**。

---

## 1. 端點

| 方法 | 路徑 | 認證 | 說明 |
|------|------|------|------|
| `POST` | `/api/auth/firebase/session` | 公開（body／可另帶 Bearer） | 會員建立／綁定 session |
| `GET` | `/api/me` | 會員 Bearer | 目前會員 profile |
| `POST` | `/api/admin/auth/firebase/session` | 公開 | 後台綁定；email 必須已在白名單 |

---

## 2. 請求

### 2.1 `FirebaseSessionRequest`

```json
{
  "idToken": "dev:uid-amy:amy@example.com:google:Amy"
}
```

| 欄位 | 型別 | 必填 |
|------|------|------|
| `idToken` | string | 是 |

真環境：Firebase SDK 取得的 ID Token。  
Dev：`dev:<uid>:<email>:<provider>:<displayName>`。

---

## 3. 回應

### 3.1 會員 session / me — `CustomerSession`

| JSON | 型別 | DB 來源 |
|------|------|---------|
| `customerId` | string | `customers.id` |
| `email` | string | `customers.email` |
| `name` | string | `customers.name` |
| `authProvider` | string | `customers.auth_provider`（`google`\|`facebook`\|`line`） |
| `firebaseUid` | string | `customers.firebase_uid` |
| `status` | string | `customers.status` |
| `created` | boolean | **僅 session 回應**：本次是否新建列；`GET /api/me` **不含**此欄 |

範例（session）：

```json
{
  "success": true,
  "data": {
    "customerId": "…",
    "email": "amy@example.com",
    "name": "Amy",
    "authProvider": "google",
    "firebaseUid": "uid-amy",
    "status": "active",
    "created": true
  }
}
```

### 3.2 後台 session — `AdminSession`

| JSON | 型別 | DB 來源 |
|------|------|---------|
| `adminUserId` | string | `admin_users.id` |
| `email` | string | `admin_users.email` |
| `name` | string | `admin_users.name` |
| `role` | string | `admin_users.role`（`admin`\|`operator`\|`warehouse`） |
| `firebaseUid` | string \| null | `admin_users.firebase_uid` |
| `firebaseUidBound` | boolean | 本次是否完成／已有綁定 |
| `effectivePermissions` | string[] | 角色預設套用個別覆寫後的有效權限 |

### 3.3 後台帳號生命週期

| `active` | `firebase_uid` | 意義 |
|----------|----------------|------|
| `true` | `NULL` | 已建白名單、待首次登入綁定 |
| `true` | 有值 | 正常使用 |
| `false` | 任意 | **停用**（拒絕登入） |

失敗：`ADMIN_NOT_WHITELISTED`／`ADMIN_INACTIVE`。

---

## 4. 業務規則

1. 會員：依 `firebase_uid` 找人；沒有則依 email／新建並綁定。  
2. `status=suspended` 或 `deleted` → 拒絕後續 API（`CUSTOMER_SUSPENDED`／未授權）。  
3. 後台：email 必須預先存在於 `admin_users`；登入與每次 Admin API 都檢查 `active` 及 Firebase UID 綁定，細 RBAC 見 Admin 契約。
4. **不**回傳任何後端自簽 JWT。

---

## 5. v0.1 不做

| 項目 | 原因 |
|------|------|
| 密碼登入 | 產品僅 OAuth |
| Refresh token API | Firebase 客戶端處理 |

---

## Changelog

| 版本 | 日期 | 說明 |
|------|------|------|
| 0.1 | 2026-07-20 | 對齊線 A 實作 |
| 0.2 | 2026-07-21 | Admin session 回傳有效權限，並鎖定 Firebase UID 一致性 |
