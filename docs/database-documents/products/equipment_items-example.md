關聯如下：

```text
product_categories ─┐
                    ├─ 1:N equipment_items
brands ─────────────┘
                         ├─ 1:N equipment_images
                         ├─ 1:N equipment_specifications
                         ├─ 1:N equipment_tags
                         └─ 1:N equipment_interest_tags
```

假設裝備主檔資料為：

```text
product_categories
id  code  name
1   tent  帳篷

brands
id  name        logo_url
1   Coleman     /assets/brands/coleman.svg

equipment_items
id    category_id  brand_id  name              description       active
E001  1            1         氣候達人六人帳     適合家庭露營        true
```

附屬資料：

```text
equipment_images
item_id  sort_order  url                               alt_text
E001     0           /assets/images/tent-main.jpg      帳篷主圖
E001     1           /assets/images/tent-inside.jpg    帳篷內部

equipment_specifications
item_id  spec_key    value
E001     capacity    6 人
E001     weight      8.4 kg
E001     waterproof  3000 mm

equipment_tags
item_id  tag
E001     親子適用
E001     防水
E001     六人帳

equipment_interest_tags
item_id  tag
E001     family
E001     tent
```

後端組合步驟：

1. 篩選 `equipment_items.active = true` 的裝備主檔。
2. 以 `category_id`、`brand_id` 分別取得分類與品牌；這是 1:1 合併。
3. 以 `item_id` 批次取得四個附屬表資料。
4. 將圖片依 `sort_order` 排序；`sort_order = 0` 可指定為主圖。
5. 將規格的 `spec_key`、`value` 轉成物件；兩種 tag 表轉成字串陣列。
6. 用 `item_id` 將結果掛回各裝備物件，回傳 DTO 給前端。

組合後的前端資料可為：

```json
{
  "id": "E001",
  "name": "氣候達人六人帳",
  "description": "適合家庭露營",
  "category": {
    "id": 1,
    "code": "tent",
    "name": "帳篷"
  },
  "brand": {
    "id": 1,
    "name": "Coleman",
    "logoUrl": "/assets/brands/coleman.svg"
  },
  "image": "/assets/images/tent-main.jpg",
  "images": [
    {
      "url": "/assets/images/tent-main.jpg",
      "altText": "帳篷主圖"
    },
    {
      "url": "/assets/images/tent-inside.jpg",
      "altText": "帳篷內部"
    }
  ],
  "specifications": {
    "capacity": "6 人",
    "weight": "8.4 kg",
    "waterproof": "3000 mm"
  },
  "tags": ["親子適用", "防水", "六人帳"],
  "interestTags": ["family", "tent"]
}
```

實作時不建議將四個 1:N 附屬表直接全部 `JOIN` 成一個查詢，否則圖片、規格、標籤會彼此交叉相乘而產生重複列。較穩定的方式是：先查主檔與分類、品牌，再依全部 `item_id` 分批查四張附屬表，於後端以 `item_id` 分組組裝。這正是會員範例中把偏好、地址、標籤匯入同一位會員資料的相同概念。