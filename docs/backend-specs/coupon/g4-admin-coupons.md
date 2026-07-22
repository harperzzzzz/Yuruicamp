# G-4 Admin Coupons

## 用途

以 PostgreSQL `coupons` 為後台優惠券主檔真相，取代 Discounts 頁先寫 cache 再非同步送 API 的假成功流程。

## 流程

`AdminCouponController` 以 `discounts.view`／`discounts.edit` 保護列表、詳情、建立、部分更新與刪除。Service 驗證折扣、期間、發行量與狀態後，Repository 使用參數化 SQL 寫入；更新會先以 `FOR UPDATE` 鎖定主檔。

前端 Backend 模式使用 `mapAdminCouponResponse()` 建立 ViewModel，送出時由 `buildAdminCouponRequest()` 白名單挑選欄位。只有 API 成功才更新 cache、重繪表格或清空表單；失敗保留原畫面與輸入。

## 核心規則

- code 建立後不可修改，後端轉成大寫並保證唯一。
- 百分比不得超過 100，固定折扣與百分比均須大於 0。
- `validUntil` 必須晚於 `validFrom`。
- `issueQuantity` 不得小於資料庫 `claimedQuantity`；已領取數量不接受前端寫入。
- 有任何領取紀錄的優惠券不可硬刪，必須停用。
- 列表排序只接受白名單欄位，金額以字串回應。

## 驗證

`AdminG4PostgreSqlIntegrationTest` 覆蓋 CRUD、重複 code、發行量下修、安全刪除及 view-only RBAC。前端 `npm run test:admin-g4` 覆蓋 facade 路由、Request 白名單與 backend-first 更新順序。
