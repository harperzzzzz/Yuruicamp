# ADM-W1-06 — Reviews 列表／詳情／刪除

| 欄位 | 內容 |
|------|------|
| **波次** | W1｜P0 |
| **狀態** | ✅ 完成（2026-07-23） |
| **總覽** | [`../../admin-post-g6-task-list.md`](../../admin-post-g6-task-list.md) § ADM-W1-06 |
| **索引** | [`../README.md`](../README.md) |
| **Dependencies** | 無硬依賴；建議準備驗收 fixture |
| **權限** | `reviews.view`／`reviews.edit` |

---

## 0. 開工前必讀

- [x] 定案 **A**：列表＋詳情＋**硬刪整則**；不做回覆、不做軟隱藏
- [x] 表：`reviews`（FK `order_item_id`）、`review_photos`；可參考 `review_dto_view`
- [x] Seed 可能幾乎沒資料 → 必須自備測試用 review
- [x] 刻意不做：`POST .../reply`、visible 旗標

**為什麼（一句）**：後台要能查／下架不當評論；權限與 UI 已有，但此前被 readiness 整段封鎖。

---

## 1. 契約

- [x] Admin 契約新增 Reviews 章節並升版（v0.15）
- [x] `GET /api/admin/reviews`：分頁；篩選 `productId`／`rating`／日期／`q`
- [x] `GET /api/admin/reviews/{id}`
- [x] `DELETE /api/admin/reviews/{id}`：刪整則（含 photos）
- [x] 回應欄位對齊 view／訂單快照（buyer、product、rating、comment、photos、createdAt）
- [x] 更新 API README；註明與線 H 公開讀可共用讀模型

---

## 2. Schema

- [x] 本定案**不改表**（硬刪即可）
- [x] 確認 `review_photos` FK：`ON DELETE CASCADE`

---

## 3. 後端

- [x] AdminReviewController＋Service＋ReadRepository
- [x] 列表兩段式分頁（避免 photos 放大列數）
- [x] DELETE 交易：photos CASCADE／硬刪 review
- [x] `@PreAuthorize` reviews.view／edit
- [x] OpenAPI Tag：Admin Reviews

---

## 4. 前端

- [x] `AdminAPI.reviews.list`／`getById`／`remove` 接真 API
- [x] 移除 `unsupported('reviews.manage')`
- [x] `admin-runtime`：`reviews.ready = true`；`reviews.manage = true`
- [x] Reviews 頁刪除：**API 成功後**才關 Modal／刷新；錯誤 toast
- [x] 僅 edit 可刪（既有 `applyEditPermission`）

---

## 5. 測試與驗收

- [x] Fixture：IT 自備合法 `order_item_id` review（+ photo）
- [x] 列表分頁／篩選（productId＋rating）
- [x] DELETE 後 GET 404；photos 一併不在
- [x] 無 edit → 刪除 403（viewer override）
- [x] `npm run test:admin-g6`、`test:admin-reviews` 通過

---

## 6. 收尾

- [x] 總覽 W1-06；本檔 ✅
- [ ]（可選）與線 H 公開評價任務互列連結，避免兩套 DTO

---

## 驗收紀錄

| 日期 | 執行者 | 結果 | 備註 |
|------|--------|------|------|
| 2026-07-23 | Agent | ✅ | 契約 v0.15；PostgreSQL IT＋facade／g6；硬刪＋RBAC |
