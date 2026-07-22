# G-2a 後台會員管理

## 用途

提供具備 `customers.view`／`customers.edit` 的管理員查詢會員主檔、更新基本資料，以及停權或恢復 suspended 會員。Email、Firebase UID、登入來源、會員等級與消費總額均不可由後台任意修改。

## 後端流程

```text
Admin Firebase Token
→ RBAC 檢查 customers.view 或 customers.edit
→ 第一階段依篩選與排序查 customer ID 分頁
→ 第二階段載入本頁會員、消費摘要與標籤
→ 詳情另載入偏好、預設地址與訂單／預約筆數
```

列表支援 `q`、`status`、`tier`、可重複的 `tagId` 與排序白名單。N:M 標籤不直接參與最終分頁列，避免同一會員重複或 `totalElements` 被放大。

`totalSpent`、`tier`、`tierName` 來自 `customer_tier_summary`。無消費會員以 LEFT JOIN 補為 `0.00`、`explorer`、`探險家`。

## 寫入規則

- PATCH 只允許姓名、電話、生日與點數。
- 生日不可晚於今天，點數不可小於 `0`。
- suspend 對已 suspended 會員採冪等回放；deleted 回 `409`。
- reactivate 對已 active 會員採冪等回放；只允許 suspended 回 active，deleted 回 `409`。
- 狀態更新與會員讀取使用交易及悲觀鎖。

## 前端

`AdminAPI.customers` 提供 list、getById、update、suspend、reactivate。Mock 模式保留既有 JSON／localStorage 流程；Backend 模式不讀 Mock 會員資料，隱藏新增會員與關聯資料編輯，並以後端回傳的等級與消費總額為準。

既有 Bootstrap 表格、卡片與展開詳情樣式維持不變，只補上狀態徽章、停權／恢復操作、載入及唯讀狀態。

## 驗證

- `mvnw.cmd -q -DskipTests compile`
- `mvnw.cmd -q -Dtest=AdminCustomerServiceTest test`
- `npm.cmd run test:admin-customers`
- `node --check admin/js/customers.js`
- `node --check admin/js/admin-api.js`
- `AdminCustomerPostgreSqlIntegrationTest` 已連線 PostgreSQL 驗收通過

G-2a 已完成程式、前端雙模式、自動測試與 PostgreSQL 整合驗收。
