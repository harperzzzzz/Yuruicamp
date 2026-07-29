# G-2b 後台預約管理

## 用途

提供具備 `bookings.view`／`bookings.edit` 的管理員查詢預約、讀取營位／租借快照與歷程，以及確認已付款預約和完成住宿。

## 流程

```text
Admin Token → RBAC → ID 分頁 → 載入預約摘要
開啟詳情 → 營位 + 租借 + 狀態歷程
確認／完成 → 悲觀鎖 → 驗證 paid 與日期 → 更新狀態 + history
```

只有 `paid + pending` 可以確認。只有已到退房日的 `paid + confirmed` 可以完成；完成時將 active `rental_stock_reservations` 改為 fulfilled。Admin 不得把 unpaid 改成 paid，已付款取消與退款留給線 D。

W1-01：`PATCH /api/admin/bookings/{id}/internal-note` 覆寫內部備註；詳情回 `internalNote`；不改履約／付款狀態。

`hasRental` 使用 EXISTS 篩選，不直接 JOIN 租借明細後分頁。

`AdminBookingController` 使用 `firebaseBearer` OpenAPI Security Requirement，讓 Swagger `Authorize` 保存的 Firebase ID Token 自動加入 `Authorization: Bearer` Header。這項宣告只描述 API 認證需求，實際安全邊界仍由 Firebase Filter 與 `bookings.view`／`bookings.edit` RBAC 負責。

## 驗證

- Maven 完整測試通過。
- `AdminBookingServiceTest` 通過。
- `AdminOpenApiSecurityTest` 通過，確認受保護 Admin Controller 宣告 `firebaseBearer`。
- `AdminFulfillmentPostgreSqlIntegrationTest` 已連線 PostgreSQL 驗收通過。
- Admin facade、JavaScript 語法與 Vite production build 通過。
- Swagger 履約流程已驗收通過。
