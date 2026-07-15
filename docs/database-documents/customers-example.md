# 資料表實際互動
customers
preference_options
customer_preferences
customer_shipping_addresses
customer_tags
customer_tag_assignments


## 建立會員
* customers
id                    = U001
name                  = Amy Chen
phone                 = 0912345678
email                 = amy@example.com
birthday              = 1992-03-18
registered_at         = 2026-07-15 10:00:00+08
tier                  = guide
tier_name             = 嚮導
points                = 100
first_purchase_used   = false
auth_provider         = google
avatar_url            = /assets/images/avatar-01.jpg
active                = true
deleted_at            = NULL
---
代表：
會員 U001 是 Amy Chen
目前帳號啟用
尚未軟刪除
使用 Google 登入
目前有 100 點
---

## 建立可選偏好
* preference_options
id  type       code          label       active
1   style      family        親子露營     true
2   style      glamping      豪華露營     true
3   equipment  tent          帳篷         true
4   equipment  cooking       炊事用品     true

## Amy 選擇偏好
* customer_id  preference_id
U001         1
U001         3
U001         4
---
Amy + 親子露營
Amy + 帳篷
Amy + 炊事用品
---

## Amy 建立收件地址
customer_shipping_addresses
* 第一筆地址：
id                = 101
customer_id       = U001
recipient_name    = 陳艾咪
postal_code       = 100
city              = 台北市
district          = 中正區
address_line      = 忠孝西路一段 1 號
phone             = 0912345678
is_default        = true
* 第二筆地址：
id                = 102
customer_id       = U001
recipient_name    = 陳艾咪
postal_code       = 220
city              = 新北市
district          = 板橋區
address_line      = 縣民大道二段 7 號
phone             = 0912345678
is_default        = false


## 建立會員標籤
id  name          color       sort_order  active
1   VIP           bg-warning  1           true
2   親子客群       bg-success  2           true
3   高消費會員     bg-danger   3           true

## 將標籤套用到 Amy
* customer_tag_assignments
customer_id  tag_id
U001         1
U001         2


## 六張表組合後的完整資料
{
  "id": "U001",
  "name": "Amy Chen",
  "email": "amy@example.com",
  "phone": "0912345678",
  "points": 100,
  "authProvider": "google",
  "preferences": {
    "styles": ["family"],
    "equipment": ["tent", "cooking"]
  },
  "shippingAddress": {
    "recipientName": "陳艾咪",
    "postalCode": "100",
    "city": "台北市",
    "district": "中正區",
    "addressLine": "忠孝西路一段 1 號",
    "phone": "0912345678"
  },
  "tags": ["VIP", "親子客群"]
}