關聯為：
```text
products（SPU，商品）
└─ product_variants（SKU，商品規格）1:N
```

例如資料庫查到：
```text
products
id    status
P001  active

product_variants
id    product_id  sku          color  size  price  specification  status
V001  P001        TENT-BL-M    藍色   M     1200   藍色／M         active
V002  P001        TENT-GR-L    綠色   L     1300   綠色／L         active
```

後端流程是：

1. 先篩選 `products.status = 'active'` 的商品。
2. 以 `product_variants.product_id = products.id` 找出該商品的規格。
3. 再篩選 `product_variants.status = 'active'`，避免停售規格仍被購買。
4. 依 `product_id` 將查詢結果分組；每個 `products` 資料列只建立一個商品物件，各規格放進 `variants` 陣列。
5. 將組合好的 JSON 回傳給前端，而不是讓前端自行串接兩張表。

回傳格式可設計為：

```json
{
  "id": "P001",
  "status": "active",
  "variants": [
    {
      "id": "V001",
      "sku": "TENT-BL-M",
      "color": "藍色",
      "size": "M",
      "price": 1200,
      "specification": "藍色／M"
    },
    {
      "id": "V002",
      "sku": "TENT-GR-L",
      "color": "綠色",
      "size": "L",
      "price": 1300,
      "specification": "綠色／L"
    }
  ]
}
```

前端商品頁以外層資料顯示商品，使用者選擇顏色、尺寸或規格文字後，從 `variants` 找到對應 SKU；加入購物車時應保存：

```json
{
  "productId": "P001",
  "variantId": "V001",
  "sku": "TENT-BL-M",
  "price": 1200
}
```

要注意：僅靠這兩張表只能提供商品 ID、販售狀態與規格價格等資訊。商品名稱、圖片、分類、品牌與說明在 `equipment_items`，因此完整商城商品 API 還需要再串接該表。