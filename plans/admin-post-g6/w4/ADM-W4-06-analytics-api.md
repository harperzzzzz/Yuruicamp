# ADM-W4-06 — Analytics 專用彙總 API（K11）

| 欄位 | 內容 |
|------|------|
| **波次** | W4｜P3 |
| **狀態** | ⬜ 未開始 |
| **總覽** | [`../../admin-post-g6-task-list.md`](../../admin-post-g6-task-list.md) § ADM-W4-06 |
| **索引** | [`../README.md`](../README.md) |
| **Dependencies** | 建議 **W3 之後**（退款／取消口徑穩定）；訂單／預約資料可用 |

---

## 0. 開工前必讀

- [ ] 現況：Dashboard 用 Orders／Products／Bookings 列表在瀏覽器聚合
- [ ] 目標：伺服器端彙總，減少拉全量與權限過粗
- [ ] 契約必須寫死口徑：是否含 cancelled／refunded

---

## 1. 契約

- [ ] 例如 `GET /api/admin/analytics/summary?from=&to=`
- [ ] 回應：營收、單量、預約數、熱銷等（精簡甲欄位）
- [ ] 權限：`orders.view` 或新建 `analytics.view`（若新建需改 seed／RBAC）
- [ ] 快取：可先無快取，但註明未來可加

---

## 2. Schema

- [ ] 通常不需新表；用 SQL 聚合既有 orders／bookings
- [ ]（可選）物化視圖 — 非本波必須

---

## 3. 後端

- [ ] AnalyticsService 查詢（注意時區 Asia/Taipei）
- [ ] 口徑與契約一致
- [ ] RBAC＋OpenAPI

---

## 4. 前端

- [ ] Analytics 頁改打彙總端點
- [ ] readiness note：由 list 聚合改為 API
- [ ] 載入／錯誤狀態

---

## 5. 測試與驗收

- [ ] 已知 fixture 區間數字與手工 SQL／試算一致
- [ ] 無權限 403
- [ ] 大區間不超時（可接受的上限寫進契約或限制 max range）

---

## 6. 收尾

- [ ] 總覽 W4-06；本檔 ✅
- [ ] W4 全完成 → 勾總覽 W4 門檻＋「主檔改後台 vs 仍需工程師」短說明

---

## 驗收紀錄

| 日期 | 執行者 | 結果 | 備註 |
|------|--------|------|------|
|  |  | ⬜／✅ |  |
