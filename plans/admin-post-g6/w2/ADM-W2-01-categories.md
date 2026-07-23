# ADM-W2-01 — 分類主檔 CRUD（K1）

| 欄位 | 內容 |
|------|------|
| **波次** | W2｜P1 |
| **狀態** | ⬜ 未開始 |
| **總覽** | [`../../admin-post-g6-task-list.md`](../../admin-post-g6-task-list.md) § ADM-W2-01 |
| **索引** | [`../README.md`](../README.md) |
| **Dependencies** | 無硬依賴（W1 建議完成） |
| **權限（建議）** | `products.view`／`products.edit` |

---

## 0. 開工前必讀

- [ ] 弄清 `categories` 表欄位與 Products lookups 用法（G-2c）
- [ ] 定案：被商品引用時**禁硬刪**或僅停用（契約寫死一種）
- [ ] 本項只做分類，品牌見 W2-02

---

## 1. 契約

- [ ] `/api/admin/categories` CRUD 寫進 Admin 契約並升版
- [ ] 列表／建立／更新／刪除或停用規則
- [ ] 與 `GET /api/admin/products/lookups` 的關係：新分類必須出現在 lookups

---

## 2. Schema

- [ ] 通常不需改；若無 `active` 而契約要停用，才加欄位

---

## 3. 後端

- [ ] AdminCategoryController＋Service
- [ ] 刪除前檢查 products／equipment 引用 → 409
- [ ] RBAC＋OpenAPI
- [ ] lookups 查詢含新資料

---

## 4. 前端

- [ ] 分類維護 UI（獨立小頁或 Products 設定區）＋ AdminAPI
- [ ] 建立商品時 lookups 重抓

---

## 5. 測試與驗收

- [ ] CRUD 快樂路徑
- [ ] 有引用時刪除 409
- [ ] 新建後 products/lookups 看得到
- [ ] RBAC

---

## 6. 收尾

- [ ] 總覽 W2-01；本檔 ✅

---

## 驗收紀錄

| 日期 | 執行者 | 結果 | 備註 |
|------|--------|------|------|
|  |  | ⬜／✅ |  |
