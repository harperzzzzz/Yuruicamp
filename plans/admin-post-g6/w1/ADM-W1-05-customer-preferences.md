# ADM-W1-05 — 會員偏好可編輯

| 欄位 | 內容 |
|------|------|
| **波次** | W1｜P0 |
| **狀態** | ✅ 完成（2026-07-23） |
| **總覽** | [`../../admin-post-g6-task-list.md`](../../admin-post-g6-task-list.md) § ADM-W1-05 |
| **索引** | [`../README.md`](../README.md) |
| **Dependencies** | 無；可與 W1-04 同迭代，**契約段落分開** |
| **權限** | `customers.edit`（寫）／`customers.view`（lookup） |

---

## 0. 開工前必讀

- [x] 弄清偏好關聯表（會員 ↔ `preference_options`）
- [x] 本季**不做** preference_options 主檔 Admin CRUD → 只能勾選既有 active options
- [x] 與地址 API 分開驗收

**為什麼（一句）**：偏好來自問卷／營運標註，應可由後台校正。

---

## 1. 契約

- [x] 升版：`PUT /api/admin/customers/{id}/preferences` `{ "optionIds": [...] }`（**v0.14**）
- [x] 非法／inactive optionId → 400
- [x] 詳情 `preferences` 回應形狀：`{ styles: code[], equipment: code[] }`
- [x] Lookup：`GET /api/admin/preference-options`（`customers.view`）
- [x] 更新 [`docs/api/README.md`](../../../docs/api/README.md)

---

## 2. Schema

- [x] 通常不需改表

---

## 3. 後端

- [x] 集合取代（與 W1-03 tags 同語意）
- [x] 只允許 active options
- [x] RBAC `customers.edit`（寫）／`customers.view`（lookup）＋OpenAPI

---

## 4. 前端

- [x] 詳情偏好編輯 UI（Backend 模式啟用）
- [x] 選項來源：`GET /preference-options`；readiness `customers.preferences=true`
- [x] 成功後才更新 cache／畫面

---

## 5. 測試與驗收

- [x] 更新後詳情正確
- [x] 塞假／inactive optionId → 400
- [x] 403
- [x] 前端 facade／g6 readiness
- [x] PostgreSQL IT（`AdminCustomerPreferencesPostgreSqlIntegrationTest`）

---

## 6. 收尾

- [x] 總覽 ADM-W1-05 DoD 勾選
- [x] 本檔狀態 ✅

---

## 驗收紀錄

| 日期 | 執行者 | 結果 | 備註 |
|------|--------|------|------|
| 2026-07-23 | Agent | ✅ | 契約 v0.14；單元＋PostgreSQL IT＋前端 facade／g6 通過 |
