# ADM-W1-01 — 訂單／預約賣家備註（`internal_note`）

| 欄位 | 內容 |
|------|------|
| **波次** | W1｜P0 |
| **狀態** | ✅ 完成（2026-07-23） |
| **總覽** | [`../../admin-post-g6-task-list.md`](../../admin-post-g6-task-list.md) § ADM-W1-01 |
| **索引** | [`../README.md`](../README.md) |
| **Dependencies** | 無 |
| **權限** | `orders.edit`／`bookings.edit`（寫）；view 可讀詳情欄位 |

---

## 0. 開工前必讀

- [x] 已讀總覽定案：主檔加 `internal_note`，可 PATCH **覆蓋**（不是 history 追加）
- [x] 理解：`order_status_history.note`／`booking_status_history.note` **不是**本功能
- [x] 刻意不做：用任意 `PATCH` 改 status；把備註寫進 status history

**為什麼（一句）**：客服要記「已電聯／延後出貨」，且不改變履約狀態。

---

## 1. 契約

- [x] 在 [`docs/api/admin-api-contract.md`](../../../docs/api/admin-api-contract.md) 新增 Orders／Bookings 備註段落並**升版**（v0.9）
- [x] 寫死端點：
  - [x] `PATCH /api/admin/orders/{id}/internal-note`
  - [x] `PATCH /api/admin/bookings/{id}/internal-note`
- [x] Request：`{ "internalNote": "string｜可空字串清掉" }`（上限 2000）
- [x] Response：詳情必回 `internalNote`；列表省略
- [x] 錯誤：404／403／400 超長
- [x] 更新 [`docs/api/README.md`](../../../docs/api/README.md)

---

## 2. Schema

- [x] `orders.internal_note text`（可空）+ COMMENT
- [x] `bookings.internal_note text`（可空）+ COMMENT
- [x] 更新 database-documents（orders／bookings）
- [x] `docker compose down -v && up -d`；欄位存在已確認
- [x] Hibernate `ddl-auto=validate`（整合測試啟動通過）

---

## 3. 後端

- [x] Order／Booking Command／Read 支援 `internal_note`
- [x] Service：只更新備註與 `updated_at`
- [x] Controller：`@PreAuthorize` + OpenAPI
- [x] 詳情 DTO 帶 `internalNote`
- [x] 空白正規化為 `null`

---

## 4. 前端

- [x] `AdminAPI.orders`／`bookings.updateInternalNote`
- [x] readiness：`orders.sellerNote`／`bookings.sellerNote` = true
- [x] Modal：Backend 可編輯；成功後才更新 baseline
- [x] view-only 依 `canEdit` 控制

---

## 5. 測試與驗收

- [x] 單元：`AdminOrderServiceTest`／`AdminBookingServiceTest`
- [x] 整合：`AdminFulfillmentPostgreSqlIntegrationTest.internalNoteCanBeUpdatedAndClearedWithoutChangingStatus`
- [x] 前端：`npm run test:admin-g6`、`test:admin-orders-bookings`
- [ ] 手動：存備註後 ship／complete（建議本機再開後端時點一次）

---

## 6. 收尾

- [x] 總覽 ADM-W1-01 DoD 勾選
- [x] 本檔狀態 ✅
- [x] g2b／g6 規格補註

---

## 驗收紀錄（填寫）

| 日期 | 執行者 | 結果 | 備註 |
|------|--------|------|------|
| 2026-07-23 | Agent | ✅ | 單元＋PostgreSQL IT＋前端 facade／g6；DB 已重建含 `internal_note` |
