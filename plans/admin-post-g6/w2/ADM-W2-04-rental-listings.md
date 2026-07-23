# ADM-W2-04 — 租借 listing＋裝備規格／標籤（方案 C 後半）

| 欄位 | 內容 |
|------|------|
| **波次** | W2｜P1 |
| **狀態** | ⬜ 未開始 |
| **總覽** | [`../../admin-post-g6-task-list.md`](../../admin-post-g6-task-list.md) § ADM-W2-04 |
| **索引** | [`../README.md`](../README.md) |
| **Dependencies** | **硬依賴** [`ADM-W2-03-rental-skus.md`](./ADM-W2-03-rental-skus.md)；營區可用 seed（新營區見 W4-01） |
| **權限** | 同 W2-03 |

---

## 0. 開工前必讀

- [ ] 表：`rental_listings`；`equipment_specifications`；`equipment_tags`
- [ ] 契約需定義：依 `itemId` 更新規格／標籤時，**不與商城商品 PUT 互相覆蓋的規則**（同交易或明確「最後寫入勝出」並文件化）
- [ ] 新營區未有 Admin 前，用既有 C00x seed 驗收即可

---

## 1. 契約

- [ ] listing：campgroundId × rentalSkuVariantId × 日租價 × active
- [ ] CRUD 或同步 API 寫死
- [ ] 裝備規格／標籤：key-value／tag 列表更新 API
- [ ] 公開 `GET /api/booking/equipment` 應反映 active listing

---

## 2. Schema

- [ ] 通常不需改

---

## 3. 後端

- [ ] listing 寫入＋驗證營區／variant 存在
- [ ] 規格／標籤同步（刪除未出現的 key／tag 或軟策略寫死）
- [ ] 價格非負、小數位與金額慣例一致

---

## 4. 前端

- [ ] 營區定價／上架 UI
- [ ] 規格／標籤編輯
- [ ] `products.rentalWrite` **全就緒**；移除 unsupported

> **⚠️ 刻意延後（後端可用）**  
> 舊版 `frontend/admin/js/products.js` **租借整頁**（定價／上架畫面）資料模型與新契約不符（名稱字串／camp 庫存 vs `campgroundId`×variant×日租價），本波**不**在舊 UI 上硬接。  
> 詳見專檔：[`W2-ui-followups.md`](./W2-ui-followups.md) § 延後項 A。  
> 驗收本項後端請用 Swagger／`AdminAPI.rentals.*`＋公開 `GET /api/booking/equipment`。

---

## 5. 測試與驗收

- [ ] 建立 listing → 公開 equipment 看得到價格
- [ ] 停用 listing → 公開不可見或不予選擇
- [ ] 規格／標籤更新後詳情正確
- [ ] 與商城同 item 的衝突案例依契約驗證

---

## 6. 收尾

- [ ] 總覽 W2-04；本檔 ✅

---

## 驗收紀錄

| 日期 | 執行者 | 結果 | 備註 |
|------|--------|------|------|
|  |  | ⬜／✅ |  |
