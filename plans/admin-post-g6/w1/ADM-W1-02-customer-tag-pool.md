# ADM-W1-02 — 會員標籤池 CRUD

| 欄位 | 內容 |
|------|------|
| **波次** | W1｜P0 |
| **狀態** | ✅ 完成（2026-07-23） |
| **總覽** | [`../../admin-post-g6-task-list.md`](../../admin-post-g6-task-list.md) § ADM-W1-02 |
| **索引** | [`../README.md`](../README.md) |
| **Dependencies** | 無（W1-03 依賴本項） |
| **權限（定案）** | 沿用 `customers.view`（讀）／`customers.edit`（寫）；**不**另開 permission code |

---

## 0. 開工前必讀

- [x] 表已存在：`customer_tags`（name／color／sort_order／active）
- [x] 定案：有指派時**禁硬刪**，改 `active=false`
- [x] 刻意不做：本項不實作會員身上的 assign（見 W1-03）

**為什麼（一句）**：列表已能用 `tagId` 篩，但字典只能靠 seed。

---

## 1. 契約

- [x] Admin 契約升版：標籤池資源路徑寫死（建議 `/api/admin/customer-tags`，並註明前端舊名 `tag-pool` 對應）→ **v0.10**
- [x] 端點：
  - [x] `GET` 列表（可含 inactive 參數）
  - [x] `GET /{id}`
  - [x] `POST` 建立
  - [x] `PATCH /{id}` 改 name／color／sort_order／active
  - [x] `DELETE /{id}`：無 assignment 才允許；有 assignment → `409`，訊息指引改停用
- [x] `name` 唯一、color 格式（契約寫死允許值或自由字串上限）→ 自由字串 max 32
- [x] 更新 API README

---

## 2. Schema

- [x] **通常不需改表**（確認 `customer_tags` 欄位足夠）
- [x] 若契約要新欄位才走 schema checklist（預設跳過）

---

## 3. 後端

- [x] Repository／Service／Controller（package 建議 `customer`）
- [x] 建立／更新驗證：空白名稱、重複名稱
- [x] 刪除前 `COUNT` assignment；>0 → CONFLICT
- [x] `@PreAuthorize` customers.view／edit
- [x] OpenAPI Tag（例如 Admin Customers 或 Admin Customer Tags）

---

## 4. 前端

- [x] `AdminAPI.tags.savePool`（或改名 list／create／update／remove）接真 API
- [x] 解除 `unsupported('customers.tagPool')` 中「池」相關部分（若與指派共用 feature flag，可等 W1-03 一起開，或拆成兩個 feature key——**建議拆** `customers.tagPool`／`customers.tagAssign` 並更新 runtime）
- [x] Customers 頁標籤池 UI：成功後才改 cache
- [x] 無 edit 權限時隱藏寫入按鈕（沿用 `applyEditPermission('customers')`）

---

## 5. 測試與驗收

- [x] 建立→列表可見
- [x] 重複名稱 400／409（與契約一致）→ `409 CONFLICT`
- [x] 有 assignment 時 DELETE → 409；改 active=false 成功
- [x] RBAC：無 edit 無法 POST

---

## 6. 收尾

- [x] 總覽 W1-02 勾選；本檔 ✅
- [x] 通知可開工 [`ADM-W1-03-customer-tag-assign.md`](./ADM-W1-03-customer-tag-assign.md)

---

## 驗收紀錄

| 日期 | 執行者 | 結果 | 備註 |
|------|--------|------|------|
| 2026-07-23 | Agent | ✅ | 契約 v0.10；PostgreSQL IT＋前端 facade／g6 通過；`tagAssign` 仍 false |
