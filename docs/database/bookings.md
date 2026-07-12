# bookings
# booking_selected_rentals
# customers
# booking_history

## OneToMany
customer 1 : bookings N
bookings 1 : booking_selected_rentals N
bookings 1 : booking_history N


1. customers
id 
avater
name
phone
email
birthday
registered_at
total_spent 累積消費金額，可用於會員分級或後台分析
tier
tier_name
points
first_purchase_used 是否已使用首購優惠
preferences
shipping_address
tags
auth_provider ，OAuth 登入來源
created_at
updated_at



2. bookings
id
customer_id
submitted_at 預約送出時間
payment_status
status
equipment_returned 租借裝備是否已歸還
campground_id
campground_name 快照 (保證資料不變動的話可以刪除)
region 區域快照，例如北部、中部 (保證資料不變動的話可以刪除)
check_in
check_out
`total_days 總晚數／天數統計，用於金額與顯示，可以用check_in, check_out 計算，在前端計算一次用於顯示，後端重新計算一次防止竄改`
    `保險加上CHECK (check_out > check_in)`
weekday_count 給「營位價格計算」和「事後查核」用，只知道天數不會知道假日平日總數
holiday_count 給「營位價格計算」和「事後查核」用
guest_count 入住人數
zone_total 營位小計
rental_total 租借裝備小計
applied_discount 已套用折扣金額
final_amount
customer_note
seller_note 後台／客服備註
 


3. booking_selected_rentals
id 
booking_id
equipment_id
rental_sku_id
product_id
variant_id
sku ，快照 (保證資料不變動的話可以刪除)，規格識別碼
name，快照
`spec_label 快照文字顯示快照，用於顯示文字`
quantity
subtotal


4. booking_history
id
booking_id
time 歷程發生時間
action 歷程文字，「已付款」、「已取消」、「已退款」。

