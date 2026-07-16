## 建議 API 傳給前端的 admin_users DTO :
{
  "id": "ADM001",
  "name": "王小明",
  "email": "admin@example.com",
  "role": "admin",
  "active": true,
  "createdAt": "2026-07-15T10:00:00+08:00",
  "updatedAt": "2026-07-16T09:30:00+08:00",
  "permissions": {
    "analytics": { "view": true, "edit": true },
    "orders": { "view": true, "edit": true },
    "movement": { "view": true, "edit": true },
    "products": { "view": true, "edit": true },
    "customers": { "view": true, "edit": true },
    "discounts": { "view": true, "edit": true },
    "reviews": { "view": true, "edit": true },
    "booking-calendar": { "view": true, "edit": true },
    "bookings": { "view": true, "edit": true },
    "permissions": { "view": true, "edit": true }
  }
}

* 代表：
    ADM001 是王小明的後台帳號。
    帳號啟用中，角色為 admin。
    permissions 是前端目前需要的細部權限格式。
    但要注意：permissions 目前不在 admin_users 資料表內；必須由後端依 role 推導，或未來新增權限資料表後組合。
    不應傳送密碼或 password_hash 給前端。

* 對應規則:
    admin_users.name        → displayName
    admin_users.active      → isActive
    admin_users.role=admin  → isSuperAdmin=true（暫定映射，不是資料庫既有欄位）
    admin_users.created_at  → createdAt
    admin_users.updated_at  → updatedAt
    權限規則／權限表         → permissions

## dmin_users 與訂單、庫存、預約歷程的關聯資料
{
  "id": 501,
  "movementNo": "MOV-20260716-001",
  "employee": {
    "id": "ADM001",
    "name": "王小明"
  },
  "movementType": "adjustment_in",
  "status": "posted",
  "occurredAt": "2026-07-16T14:00:00+08:00"
}