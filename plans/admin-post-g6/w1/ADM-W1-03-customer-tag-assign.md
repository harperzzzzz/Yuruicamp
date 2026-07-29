# ADM-W1-03 — 會員標籤指派／取消指派

| 欄位 | 內容 |
|------|------|
| **波次** | W1｜P0 |
| **狀態** | ✅ 完成（2026-07-23） |
| **總覽** | [`../../admin-post-g6-task-list.md`](../../admin-post-g6-task-list.md) § ADM-W1-03 |
| **索引** | [`../README.md`](../README.md) |
| **Dependencies** | **硬依賴** [`ADM-W1-02-customer-tag-pool.md`](./ADM-W1-02-customer-tag-pool.md) |
| **權限** | `customers.edit` |

---

## 0. 開工前必讀

- [x] W1-02 已驗收（或至少 seed 標籤 + 池 API 可讀）
- [x] 定案：詳情用「**完整 tagId 集合取代**」較不易殘留
- [x] 只能指派 `active=true` 的標籤
- [x] 列表 N:M **不可**直接 JOIN 放大分頁（維持 G-2a 兩段式）

**為什麼（一句）**：只有池沒有指派，營運仍無法把標籤掛到會員身上。

---

## 1. 契約

- [x] 升版 Admin 契約：`PUT /api/admin/customers/{id}/tags` body `{ "tagIds": [1,2,3] }`（changelog **v0.11**；目前文件總版次可能已更高）
- [x] 語意：集合取代（未出現的 id 解除指派；出現的建立）
- [x] 含 inactive／不存在 tagId → 400
- [x] 詳情 GET 已回 `tags[]` 行為不變，僅資料會變
- [x] 更新 [`docs/api/README.md`](../../../docs/api/README.md)

---

## 2. Schema

- [x] 不需改表（使用 `customer_tag_assignments`）

---

## 3. 後端

- [x] 交易內：刪除不在集合的 assignment、插入新的
- [x] 驗證每個 tagId 存在且 active
- [x] 悲觀鎖或等效方式避免併發寫髒（至少同一 customer 序列化）→ `findByIdForUpdate`
- [x] RBAC `customers.edit`

---

## 4. 前端

- [x] Customers 詳情：標籤多選／儲存打 PUT（`AdminAPI.customers.replaceTags`）
- [x] 成功後重載詳情或以回應更新
- [x] readiness：`customers.tagAssign=true`（與 `tagPool` 分開）
- [x] 列表 `tagId` 篩選：IT 覆蓋；前端本地篩選仍以名稱運作

---

## 5. 測試與驗收

- [x] 指派 A+B → 詳情有 A、B；列表 tagId=A 找得到
- [x] 改為只剩 A → B 消失
- [x] 指派 inactive tag → 400
- [x] 無 edit → 403

---

## 6. 收尾

- [x] 總覽 W1-03 勾選；本檔 ✅

---

## 驗收紀錄

| 日期 | 執行者 | 結果 | 備註 |
|------|--------|------|------|
| 2026-07-23 | Agent | ✅ | `AdminCustomerTagAssignPostgreSqlIntegrationTest`＋前端 facade／g6 通過 |
