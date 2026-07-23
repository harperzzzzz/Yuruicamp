# W2 前端延後項（刻意未做／後端已可用）

| 欄位 | 內容 |
|------|------|
| **狀態** | Open（後續 UI 遷移） |
| **日期** | 2026-07-23 |
| **關聯** | [`ADM-W2-04`](./ADM-W2-04-rental-listings.md)、[`ADM-W2-05`](./ADM-W2-05-inventory-conversion.md) |
| **總覽** | [`../../admin-post-g6-task-list.md`](../../admin-post-g6-task-list.md) § W2 |
| **索引** | [`../README.md`](../README.md) |

---

## 為什麼要單獨標註？

W2 後端／契約／`AdminAPI`／readiness **可以先就緒**，但舊版商品頁 UI 的資料模型與新契約不一致。  
下列兩項是**刻意延後**，**不算** W2 後端未完成；也**不要**誤以為後台畫面上的按鈕已打到真 API。

> 驗收後端：用 Swagger 或 `AdminAPI.*`。  
> 驗收完整營運 UX：必須先做完本檔兩項 UI 遷移。

---

## 延後項 A — 租借整頁（定價／上架）尚未改新資料模型

| 項目 | 說明 |
|------|------|
| **對應任務** | 主要屬 [`ADM-W2-04`](./ADM-W2-04-rental-listings.md)（依賴 W2-03 SKU） |
| **程式位置** | `frontend/admin/js/products.js` 租借 tab／相關表單；`partials/products.html` |
| **後端已可用** | `GET`／`PUT /api/admin/rentals/{id}/listings`；`AdminAPI.rentals.listListings`／`replaceListings`；裝備規格／標籤 `/api/admin/equipment-items/{itemId}/specs`／`tags` |
| **現況問題** | 舊 UI 用 `category`／`brand` **顯示名稱字串**、`variants[].camp` **庫存數量** 等模型；新契約要的是 `categoryId`／`brandId`、`campgroundId` × `rentalSkuVariantId` × 日租價 × `active` |
| **風險** | 若舊 UI 直接呼叫新 API，容易因欄位不符回 `400`；Backend 模式可能仍隱藏／半殘租借編輯體驗 |
| **後續要做** | 把租借維護畫面改成：選 SKU／規格 → 依營區編 listing 定價／上架 → 規格／標籤走 equipment-items API；成功後才刷新畫面 |

**刻意不做（本波）**：在舊資料模型上硬接新 API。

---

## 延後項 B —「調撥到租借」Modal 仍是前端記憶體

| 項目 | 說明 |
|------|------|
| **對應任務** | 主要屬 [`ADM-W2-05`](./ADM-W2-05-inventory-conversion.md) |
| **程式位置** | `frontend/admin/js/products.js`：`submitTransferToRental`／`submitBranchToCampTransfer`／`submitCampTransfer` 等；`#transferToRentalModal` |
| **後端已可用** | `/api/admin/inventory-conversions`（create draft／post／cancel）；`AdminAPI.inventoryConversions.*`；readiness `movement.conversion`（若已開啟） |
| **現況問題** | Modal 仍用前端 `branchId`／`campKey`／自行組出的 variant 概念，改 **記憶體 cache**，**不會**寫 `inventory_conversions`，也不會成對建立 `conversion_out`＋`conversion_in` |
| **風險** | 營運以為已調撥，DB 庫存其實沒變；與 G-3／W2-05 正式流程不一致 |
| **後續要做** | Modal（或改到庫存異動頁）改打 `AdminAPI.inventoryConversions.createDraft` → `post`；參數改為真實 `sourceLocationId`／`destinationLocationId`／`sourceVariantId`／`destinationRentalVariantId`／`quantity`／`idempotencyKey`；成功後重抓庫存唯讀摘要 |

**刻意不做（本波）**：繼續用前端假異動假裝跨領域轉換。

---

## 驗收對照（給新手）

| 你想驗證什麼 | 應該怎麼驗 | 不要怎麼驗 |
|--------------|------------|------------|
| 租借 listing／定價 API | Swagger 或 `AdminAPI.rentals.*`；公開 `GET /api/booking/equipment` | 只靠舊租借 tab 畫面 |
| 跨領域轉換 API | Swagger 或 `AdminAPI.inventoryConversions.*`；查兩邊 on_hand | 只點商品頁「調撥到租借」確認記憶體數字 |

---

## 勾選進度（UI 遷移完成後再勾）

- [ ] A：`products.js` 租借整頁改用新 listing／規格／標籤資料模型並接真 API  
- [ ] B：「調撥到租借」改打 `inventory-conversions`；移除前端假異動路徑  
- [ ] 手動：Backend 模式下完成「上架一筆到營區」＋「store→rental 過帳一筆」畫面流程  
- [ ] 回總覽／本索引標註「W2 UI follow-up 完成」

---

## 變更紀錄

| 日期 | 說明 |
|------|------|
| 2026-07-23 | 建立本檔：明確標註 W2-04／W2-05 刻意延後的兩項舊 UI |
