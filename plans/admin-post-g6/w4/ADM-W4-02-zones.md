# ADM-W4-02 — 營位／區域主檔 CRUD（K6）

| 欄位 | 內容 |
|------|------|
| **波次** | W4｜P2 |
| **狀態** | ⬜ 未開始 |
| **總覽** | [`../../admin-post-g6-task-list.md`](../../admin-post-g6-task-list.md) § ADM-W4-02 |
| **索引** | [`../README.md`](../README.md) |
| **Dependencies** | **硬依賴** [`ADM-W4-01-campgrounds.md`](./ADM-W4-01-campgrounds.md) |

---

## 0. 開工前必讀

- [ ] 確認專案中「營位／區域」實際表名（zones／campground_zones 等）
- [ ] **容量調降**：不得造成已占用 pending／confirmed「幽靈超訂」— 契約必須寫是否允許、如何拒絕

---

## 1. 契約

- [ ] Admin zones CRUD（容量、啟停、所屬營區）
- [ ] 與 `check-availability` 行為文件化

---

## 2. Schema

- [ ] 通常不需改；不足才加

---

## 3. 後端

- [ ] CRUD＋容量變更驗證（對照占用）
- [ ] RBAC

---

## 4. 前端

- [ ] 營位維護 UI

---

## 5. 測試與驗收

- [ ] 新建 zone 後 availability 反映
- [ ] 降容量低於占用 → 409（若契約如此）
- [ ] check-availability 案例回歸

---

## 6. 收尾

- [ ] 總覽 W4-02；本檔 ✅

---

## 驗收紀錄

| 日期 | 執行者 | 結果 | 備註 |
|------|--------|------|------|
|  |  | ⬜／✅ |  |
