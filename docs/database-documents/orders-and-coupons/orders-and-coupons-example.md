## 七張表組合後提供前端的訂單資料
前端不應分別讀取七張資料表；後端應以 orders 為主體，依 order_id 組合訂單明細、
狀態歷程、事件歷程與優惠券交易快照後，再回傳單一訂單物件。

### 建立訂單主檔
* orders
id                        = ORD-20260716-001
customer_id               = U001
buyer_name_snapshot       = Amy Chen
buyer_email_snapshot      = amy@example.com
recipient_name_snapshot   = 陳艾咪
shipping_address_snapshot = 台北市中正區忠孝西路一段 1 號
shipping_phone_snapshot   = 0912345678
subtotal                  = 3200
shipping_fee              = 100
discount                  = 300
total                     = 3000
payment_method            = online
payment_status            = paid
refund_status             = none
status                    = shipped
placed_at                 = 2026-07-16 10:00:00+08
paid_at                   = 2026-07-16 10:02:00+08

### 建立訂單商品明細
* order_items
id    order_id             sku_snapshot  product_name_snapshot  specification_snapshot  unit_price_snapshot  quantity
1001  ORD-20260716-001     TENT-2P-GR    雙人帳篷                綠色／雙人               3200                 1

### 建立訂單履約狀態歷程
* order_status_history
id    order_id             status     occurred_at                  actor_id  note
2001  ORD-20260716-001     unshipped  2026-07-16 10:00:00+08       NULL      訂單成立
2002  ORD-20260716-001     shipped    2026-07-16 14:00:00+08       A001      已交由物流配送

### 建立非履約事件歷程
* order_event_history
id    source_history_id  order_id             event_type        occurred_at                  actor_id  note
3001  19001              ORD-20260716-001     payment_received  2026-07-16 10:02:00+08       NULL      線上付款完成

### 建立優惠券主檔與會員領券紀錄
* coupons
id   code       name              discount_type  discount_value  minimum_amount  status
10   SUMMER300  夏日滿額折扣券     fixed          300             2000            active

* coupon_claims
id    coupon_id  customer_id  status    claimed_at                  consumed_at
5001  10         U001         consumed  2026-07-01 09:00:00+08      2026-07-16 10:00:00+08

### 建立訂單優惠券交易快照
* order_coupons
id    order_id             coupon_id  coupon_claim_id  code_snapshot  discount_type_snapshot  discount_value_snapshot  amount  applied_at
4001  ORD-20260716-001     10         5001             SUMMER300      fixed                   300                      300     2026-07-16 10:00:00+08

### 後端組合流程
orders（依 id 查詢）
        ↓
以 orders.id 查詢 order_items、order_status_history、order_event_history、order_coupons
        ↓
以 order_coupons.coupon_claim_id 查詢 coupon_claims
        ↓
以 order_coupons.coupon_id 查詢 coupons；coupon_id 為 NULL 時，仍使用 order_coupons 的快照欄位
        ↓
後端依 occurred_at 排序 histories、events，依 id 排序 items、coupons
        ↓
組合為單一 Order Detail API 回應，提供會員中心、訂單成功頁與後台訂單詳情使用

### 提供前端的完整資料
```json
{
  "id": "ORD-20260716-001",
  "customerId": "U001",
  "buyer": {
    "name": "Amy Chen",
    "email": "amy@example.com"
  },
  "recipient": {
    "name": "陳艾咪",
    "address": "台北市中正區忠孝西路一段 1 號",
    "phone": "0912345678"
  },
  "amounts": {
    "subtotal": 3200,
    "shippingFee": 100,
    "discount": 300,
    "total": 3000
  },
  "payment": {
    "method": "online",
    "status": "paid",
    "paidAt": "2026-07-16T10:02:00+08:00"
  },
  "fulfillmentStatus": "shipped",
  "refundStatus": "none",
  "placedAt": "2026-07-16T10:00:00+08:00",
  "items": [
    {
      "id": 1001,
      "sku": "TENT-2P-GR",
      "productName": "雙人帳篷",
      "specification": "綠色／雙人",
      "unitPrice": 3200,
      "quantity": 1,
      "lineTotal": 3200
    }
  ],
  "statusHistory": [
    {
      "status": "unshipped",
      "occurredAt": "2026-07-16T10:00:00+08:00",
      "actorId": null,
      "note": "訂單成立"
    },
    {
      "status": "shipped",
      "occurredAt": "2026-07-16T14:00:00+08:00",
      "actorId": "A001",
      "note": "已交由物流配送"
    }
  ],
  "events": [
    {
      "type": "payment_received",
      "occurredAt": "2026-07-16T10:02:00+08:00",
      "actorId": null,
      "note": "線上付款完成"
    }
  ],
  "coupons": [
    {
      "code": "SUMMER300",
      "name": "夏日滿額折扣券",
      "discountType": "fixed",
      "discountValue": 300,
      "amount": 300,
      "claimStatus": "consumed",
      "appliedAt": "2026-07-16T10:00:00+08:00"
    }
  ]
}
```

前端顯示訂單時，商品、金額與已使用優惠券應以 orders、order_items、order_coupons 的快照欄位為準；
不得因 coupons 主檔後續改名、停用或刪除而改寫已成立訂單的交易內容。

