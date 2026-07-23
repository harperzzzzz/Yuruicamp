# ADM-W1-04 — 會員預設地址可編輯

| 欄位 | 內容 |
|------|------|
| **波次** | W1｜P0 |
| **狀態** | ✅ 完成（2026-07-23） |
| **總覽** | [`../../admin-post-g6-task-list.md`](../../admin-post-g6-task-list.md) § ADM-W1-04 |
| **索引** | [`../README.md`](../README.md) |
| **Dependencies** | 無（G-2a 已唯讀預設地址） |
| **權限** | `customers.edit` |

---

## 0. 開工前必讀

- [x] 確認現有「預設地址」落在哪張表／哪些欄位（讀 G-2a 與 database-documents）→ `customer_shipping_addresses`（`is_default=true`）
- [x] **鐵則**：已成立訂單的 `shipping_*_snapshot` **不得**被本 API 改掉
- [x] 刻意不做：管理員代建會員；改 Email／firebase_uid

**為什麼（一句）**：客服常需幫客人改預設收件資料；目前只能看不能改。

---

## 1. 契約

- [x] 升版：寫清可寫欄位（收件人、電話、地址明細等以 DB 為準）→ **v0.13**
- [x] 端點寫死：`PUT /api/admin/customers/{id}/default-shipping-address`
- [x] 驗證規則：必填、電話格式、長度 → `^09\d{8}$`；其餘 trim 後長度對齊 DB
- [x] Response：詳情 `defaultShippingAddress` 形狀
- [x] 更新 [`docs/api/README.md`](../../../docs/api/README.md)

---

## 2. Schema

- [x] 預設不改表；若缺欄位才走 schema checklist

---

## 3. 後端

- [x] Service 更新預設地址列／欄位（無預設列則 INSERT）
- [x] 單元／IT：更新後舊訂單詳情 snapshot 地址不變
- [x] RBAC `customers.edit`＋OpenAPI

---

## 4. 前端

- [x] Customers 詳情：打開地址編輯表單（Backend 模式不再隱藏）→ readiness `customers.defaultAddress=true`
- [x] 成功後刷新詳情；失敗保留輸入
- [x] view-only 不可送出（`applyEditPermission('customers')`）

---

## 5. 測試與驗收

- [x] PUT 後詳情地址更新
- [x] 同會員一筆舊訂單 Admin GET，snapshot 地址仍是舊值
- [x] 非法電話／缺必填 → 400
- [x] 403／404
- [x] 前端 facade／g6 readiness

---

## 6. 收尾

- [x] 總覽 ADM-W1-04 DoD 勾選
- [x] 本檔狀態 ✅

---

## 驗收紀錄

| 日期 | 執行者 | 結果 | 備註 |
|------|--------|------|------|
| 2026-07-23 | Agent | ✅ | 契約 v0.13；單元＋PostgreSQL IT＋前端 facade／g6 通過 |
