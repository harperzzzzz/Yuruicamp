# orders

## problems :
1. subtotal、shipping_fee、discount、total 與order_items、order_coupons存在可推導/重複保存問題。


## 主要改動 :
1. 完全正規化 :
orders
保留：subtotal, shipping_fee, discount, total
定義為「下單當下由系統計算出的金額快照」，不是人工可任意修改欄位。
total = max(subtotal + shipping_fee - discount, 0)

order_items
保留：product_id, variant_id, sku, name, spec_label, price, quantity, image
不保存 subtotal 欄位；顯示時用 price * quantity。

order_coupons
保留：code, type, discount, amount, coupon_code
discount 是券面額/百分比快照。
amount 是本訂單實際折抵金額，必須保存。
orders.discount 等於所有 order_coupons.amount 加總。

* 後端/API 重新計算 subtotal / shipping_fee / discount / total。
* 前端送來的金額只能當 UI 顯示參考，不當資料庫真相。