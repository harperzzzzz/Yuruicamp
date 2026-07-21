# Coupon 後端流程

## 完成範圍

- `GET /api/coupons`：公開有效且仍有名額的優惠券。
- `GET /api/me/coupons`：會員自己的領券紀錄。
- `POST /api/me/coupons/claims`：依優惠券 `id` 領券。
- Checkout 建立與更新可傳 `couponClaimId`，後端重新計算折扣並寫入 `order_coupons` 快照。
- Checkout 更新傳空內容 `{}` 時清除目前套用的券；claim 仍保留為 `claimed`。

## 三種資格

- `promotion`：有效期間與名額符合即可。
- `birthday`：固定使用 `Asia/Taipei`，會員生日月份等於目前月份。
- `firstPurchase`：`customers.first_purchase_used=false`。

## Trigger 分工

Service 負責會員資格、最低消費、折扣計算及訂單歸屬。既有 `trg_coupon_claims_allocate_capacity` 只負責原子配置名額，避免多人同時領取超過 `issue_quantity`。

套券時 claim 不會提前改成 `consumed`。付款成功或 COD 成立後的消耗由線 D 的付款交易完成；取消或逾時不退還已占用的領券名額。

目前 Schema 只有 `order_coupons`，沒有 Booking 對應的 Coupon 關聯表。為避免只改金額卻沒有 claim 歸屬與折扣快照，Booking 仍拒絕非 `null couponClaimId`；完整 F-2 需先完成 Schema 決策。

## 自動驗證

`CouponPostgreSqlIntegrationTest` 使用真正 PostgreSQL 驗證名額 Trigger、重複領券、售罄、資格、後端折扣快照，以及取消後 claim 狀態。
