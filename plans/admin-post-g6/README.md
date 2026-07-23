# Admin G-6 之後 — 實作 Checklist 索引

| 欄位 | 內容 |
|------|------|
| **狀態** | Active |
| **日期** | 2026-07-23 |
| **總覽（需求／波次／依賴）** | [`../admin-post-g6-task-list.md`](../admin-post-g6-task-list.md) |
| **契約** | [`../../docs/api/admin-api-contract.md`](../../docs/api/admin-api-contract.md) |
| **Schema 變更流程** | [`../backend-schema-change-checklist.md`](../backend-schema-change-checklist.md) |

---

## 這資料夾是做什麼的？

- [`admin-post-g6-task-list.md`](../admin-post-g6-task-list.md)＝**為什麼做、波次、依賴、DoD 摘要**（產品／規劃視角）
- **本資料夾**＝每個 `ADM-W*` 任務拆成可勾選的**實作步驟**（契約 → Schema → 後端 → 前端 → 測試 → 收尾）

> 驗收通過後：先勾本檔 checklist，再回總覽把該任務／波次標完成。

---

## 每個 checklist 固定結構（給新手）

| 章節 | 意義 |
|------|------|
| **0. 開工前** | 依賴、Blocked、刻意不做 |
| **1. 契約** | 先改文件升版，禁止直接寫 code |
| **2. Schema** | 有欄位／表變更才做；走 schema checklist |
| **3. 後端** | Controller／Service／RBAC／OpenAPI |
| **4. 前端** | AdminAPI、readiness、頁面 |
| **5. 測試與驗收** | 單元／整合／手動 |
| **6. 收尾** | README、契約索引、總覽勾選 |

**統一改約流程（強制）**

```text
契約升版 → Schema（若需要）→ 後端 → 前端 → 測試驗收 → 更新總覽
```

---

## 波次與檔案一覽

### W1 — P0 營運半套補齊

| ID | 檔案 | 摘要 |
|----|------|------|
| ADM-W1-01 | [`w1/ADM-W1-01-internal-note.md`](./w1/ADM-W1-01-internal-note.md) | ✅ 訂單／預約 `internal_note` |
| ADM-W1-02 | [`w1/ADM-W1-02-customer-tag-pool.md`](./w1/ADM-W1-02-customer-tag-pool.md) | ✅ 會員標籤池 CRUD |
| ADM-W1-03 | [`w1/ADM-W1-03-customer-tag-assign.md`](./w1/ADM-W1-03-customer-tag-assign.md) | ✅ 標籤指派（依賴 W1-02） |
| ADM-W1-04 | [`w1/ADM-W1-04-customer-address.md`](./w1/ADM-W1-04-customer-address.md) | ✅ 預設地址可編 |
| ADM-W1-05 | [`w1/ADM-W1-05-customer-preferences.md`](./w1/ADM-W1-05-customer-preferences.md) | ✅ 偏好可編 |
| ADM-W1-06 | [`w1/ADM-W1-06-reviews.md`](./w1/ADM-W1-06-reviews.md) | ✅ Reviews 列表／詳情／刪除 |
| ADM-W1-07 | [`w1/ADM-W1-07-min-stock.md`](./w1/ADM-W1-07-min-stock.md) | ✅ 最低庫存閾值 |

> 本機手動點測：[`w1/W1-manual-qa.md`](./w1/W1-manual-qa.md)（固定 ID：`W1-ORD-NOTE`／`W1-BK-NOTE`／`W1-REV-DEL`）

### W2 — P1 目錄與庫存進階

| ID | 檔案 | 摘要 |
|----|------|------|
| ADM-W2-01 | [`w2/ADM-W2-01-categories.md`](./w2/ADM-W2-01-categories.md) | 分類主檔 |
| ADM-W2-02 | [`w2/ADM-W2-02-brands.md`](./w2/ADM-W2-02-brands.md) | 品牌主檔 |
| ADM-W2-03 | [`w2/ADM-W2-03-rental-skus.md`](./w2/ADM-W2-03-rental-skus.md) | 租借 SKU／規格 |
| ADM-W2-04 | [`w2/ADM-W2-04-rental-listings.md`](./w2/ADM-W2-04-rental-listings.md) | listing＋裝備規格／標籤 |
| ADM-W2-05 | [`w2/ADM-W2-05-inventory-conversion.md`](./w2/ADM-W2-05-inventory-conversion.md) | 跨領域轉換 |
| ADM-W2-06 | [`w2/ADM-W2-06-inventory-locations.md`](./w2/ADM-W2-06-inventory-locations.md) | 庫位主檔 |
| ADM-W2-07 | [`w2/ADM-W2-07-branches.md`](./w2/ADM-W2-07-branches.md) | 門市主檔 |

> **⚠️ 刻意延後的前端（後端可用）**：見 [`w2/W2-ui-followups.md`](./w2/W2-ui-followups.md)  
> 1. 舊版 `products.js` **租借整頁**（定價／上架）尚未改新資料模型  
> 2. 舊版「**調撥到租借**」Modal 仍是前端記憶體，尚未打真的 `inventory-conversions` API  


### W3 — P1 Blocked by 線 D

| ID | 檔案 | 摘要 |
|----|------|------|
| Gate | [`w3/ADM-W3-00-payment-gate.md`](./w3/ADM-W3-00-payment-gate.md) | 線 D 開工閘門（先勾完才能做 W3） |
| ADM-W3-01 | [`w3/ADM-W3-01-order-cancel.md`](./w3/ADM-W3-01-order-cancel.md) | 訂單未出貨取消 O1 |
| ADM-W3-02 | [`w3/ADM-W3-02-order-refund.md`](./w3/ADM-W3-02-order-refund.md) | 訂單退款推進 O3 |
| ADM-W3-03 | [`w3/ADM-W3-03-booking-cancel.md`](./w3/ADM-W3-03-booking-cancel.md) | 預約已付款取消 B1 |

### W4 — P2～P3 主檔與內容

| ID | 檔案 | 摘要 |
|----|------|------|
| ADM-W4-01 | [`w4/ADM-W4-01-campgrounds.md`](./w4/ADM-W4-01-campgrounds.md) | 營區 |
| ADM-W4-02 | [`w4/ADM-W4-02-zones.md`](./w4/ADM-W4-02-zones.md) | 營位／區域 |
| ADM-W4-03 | [`w4/ADM-W4-03-calendar-dates.md`](./w4/ADM-W4-03-calendar-dates.md) | 假日曆 |
| ADM-W4-04 | [`w4/ADM-W4-04-articles.md`](./w4/ADM-W4-04-articles.md) | 文章 |
| ADM-W4-05 | [`w4/ADM-W4-05-image-upload.md`](./w4/ADM-W4-05-image-upload.md) | 圖檔上傳 |
| ADM-W4-06 | [`w4/ADM-W4-06-analytics-api.md`](./w4/ADM-W4-06-analytics-api.md) | Analytics 彙總 API |

---

## 建議開工順序（精簡）

見總覽 §6。W1 可平行：`01`／`02`／`04`／`05`／`07`；`03` 等 `02`。  
W3 **必須先**勾完 [`w3/ADM-W3-00-payment-gate.md`](./w3/ADM-W3-00-payment-gate.md)。

---

## 變更紀錄

| 日期 | 說明 |
|------|------|
| 2026-07-23 | 自總覽拆出本資料夾與各 ADM-W* 實作 checklist |
| 2026-07-23 | W1-01～05、W1-07 checklist 標完成；文件格式對齊 01～03（changelog／DoD／契約段落順序） |
| 2026-07-23 | 新增 [`w2/W2-ui-followups.md`](./w2/W2-ui-followups.md)：標註租借整頁／調撥 Modal 兩項刻意延後 UI |
