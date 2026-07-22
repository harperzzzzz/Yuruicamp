# G-2a Admin Customers Swagger 驗證

## 驗證目的

- `customers.view` 可讀列表與詳情，但不可更新。
- `customers.edit` 可更新基本資料、停權與恢復會員。
- 會員等級與消費總額採資料庫摘要，不由前端計算。
- 停權後會員舊 Token 立即不能使用會員 API。
- deleted 會員不能透過 reactivate 恢復。

## 驗證前準備

1. 載入最新開發 Seed 並啟動 PostgreSQL 與 Spring Boot。
2. 確認 `yuruicamp.firebase.enabled=false`，開啟 `http://localhost:8080/swagger-ui.html`。
3. 使用 Seed 中具備完整權限的管理員 Token：

```text
dev:booking-seed-admin:booking-seed@example.test:google:Booking Seed Admin
```

4. 在 Swagger `Authorize` 設定 Token。

## 流程

### 1. 查詢列表

```http
GET /api/admin/customers?page=0&size=20&sort=registeredAt,desc
```

預期 HTTP `200`，Envelope 包含 `data` 與分頁 `meta`。沒有完成付款訂單的會員應回 `totalSpent="0.00"`、`tier="explorer"`。

再分別驗證 `q`、`status`、`tier`、`tagId` 與 `sort=totalSpent,desc`；同一會員即使有多個標籤，也只能出現一次。

### 2. 查詢詳情

```http
GET /api/admin/customers/{customerId}
```

預期回傳 Email、電話、生日、唯讀標籤／偏好／預設地址與 summary，但只回 `firebaseUidBound`，不回完整 Firebase UID。

完整開發 Seed 的 U001 應回 2 個 `styles`、2 個 `equipment`、1 個會員標籤與地址 ID `1`。2026-07-22 已用 Admin API 實際驗證成功；全批 Seed 為 18 個偏好選項、200 筆會員偏好、50 筆預設地址、3 個標籤與 56 筆指派。

### 3. 更新基本資料

```http
PATCH /api/admin/customers/{customerId}
Content-Type: application/json

{
  "name": "G2A 驗證會員",
  "phone": "0912345678",
  "birthday": "1995-05-20",
  "points": 200
}
```

預期 HTTP `200`。傳入負點數或未來生日應回 `400`；Email、狀態、Firebase UID、等級與消費總額不在此契約內。

### 4. 停權與恢復

```http
POST /api/admin/customers/{customerId}/suspend
POST /api/admin/customers/{customerId}/reactivate
```

預期第一次依序回 `suspended`、`active`；對相同狀態重送會回放目前資料。deleted 會員呼叫任一端點回 `409`。

停權後，以該會員原本的 Token 呼叫：

```http
GET /api/me
```

預期立即拒絕；恢復後可再次通過會員身分驗證。

## DBeaver 核對

```sql
SELECT id, name, email, status, points, deleted_at, updated_at
FROM customers
WHERE id = '<customerId>';

SELECT customer_id, total_spent, tier_code, tier_name
FROM customer_tier_summary
WHERE customer_id = '<customerId>';
```

確認停權不刪除會員關聯資料，且等級與消費總額和 View 一致。
