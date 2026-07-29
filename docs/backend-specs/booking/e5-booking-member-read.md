# E-5 會員預約讀取

## 用途

提供會員查看自己的預約列表、詳情與待付款 Checkout。會員身分只從 Firebase principal 取得，不接受前端指定 `customerId`。

## 流程

1. Security 驗證會員 Token。
2. Controller 取出 principal 的 `customerId`。
3. Repository 使用 `customer_id` 限制列表與單筆 SQL。
4. 詳情讀取營位、租借快照並組成字串金額。
5. 不存在與別人的預約都回 `404 NOT_FOUND`。

## 規則

- 列表支援 `page`、`size`，固定依 `created_at desc, id desc`。
- `page` 從 0 起算；`size` 範圍為 1～100。
- 列表只回摘要；詳情包含付款、金額、營位與租借快照。
- 公開 GET 白名單不包含會員預約與 Checkout 查詢。
- 本階段只讀資料，不修改付款、預約或保留帳狀態。

## 驗證

- `BookingMemberIntegrationTest` 使用獨立 PostgreSQL fixture，7 項全部通過，覆蓋分頁、完整快照、Checkout 讀取、匿名拒絕、參數驗證，以及他人／不存在統一 404。
- E-1～E-5 共 40 項 PostgreSQL 回歸測試全部通過，公開營區端點與既有 Checkout 流程不受 Security 白名單調整影響。
