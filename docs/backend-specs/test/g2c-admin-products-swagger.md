# G-2c Admin Products Swagger 驗證

## 驗證目的

- `products.view` 可讀商品、lookup 與唯讀庫存，`products.edit` 才能建立、更新及上下架。
- 建立／更新會同步正規化的商品、規格與圖片，不寫入庫存或租借資料。
- 更新時未送出的既有規格會停用，後端錯誤不應造成前端假成功。
- 商品下架後公開詳情回 `404`，但後台仍可讀取。

## 驗證前準備

1. 載入最新開發 Seed，啟動 PostgreSQL 與 Spring Boot。
2. 確認 `yuruicamp.firebase.enabled=false`，開啟 `http://localhost:8080/swagger-ui.html`。
3. 在 Swagger `Authorize` 輸入具完整權限的 Seed 管理員 Token：

```text
dev:booking-seed-admin:booking-seed@example.test:google:Booking Seed Admin
```

Swagger 會自行加上 `Bearer`，不要在欄位內再輸入 `Bearer `。

## 流程

### 1. 取得分類與品牌 ID

```http
GET /api/admin/products/lookups
```

預期 HTTP `200`。從 `data.categories[]` 與 `data.brands[]` 選擇存在的 `id`，後續 Request 必須傳 ID，不傳顯示名稱讓後端猜測。

### 2. 建立商品

SKU 請加入當次時間或個人縮寫，避免與既有資料重複。

```http
POST /api/admin/products
Content-Type: application/json

{
  "name": "G2C Swagger 測試帳篷",
  "description": "<p>G-2c 正規化寫入驗證。</p>",
  "categoryId": 1,
  "brandId": "coleman",
  "status": "active",
  "images": [
    {
      "url": "/assets/images/products/g2c-swagger.jpg",
      "altText": "G2C 測試帳篷"
    }
  ],
  "variants": [
    {
      "sku": "G2C-SWAGGER-001",
      "color": "橄欖綠",
      "size": null,
      "specification": "橄欖綠",
      "price": "3200.00",
      "status": "active"
    }
  ]
}
```

請將實際 lookup ID 代入。預期 HTTP `200`，回應會產生 `data.id`、`data.itemId` 與 `data.variants[0].id`；所有庫存摘要為 `0`，資料庫不應新增 `inventory_stocks`。

### 3. 查詢列表與詳情

```http
GET /api/admin/products?page=0&size=20&q=G2C&status=active&sort=updatedAt,desc
GET /api/admin/products/{productId}
```

預期後台可看到商品、圖片、規格與唯讀庫存。列表分頁 `meta` 正確，同一商品不因圖片或規格數量而重複。

### 4. 更新規格與圖片

既有規格要帶回步驟 2 的 variant ID；新規格不傳 `id`。

```http
PUT /api/admin/products/{productId}
Content-Type: application/json

{
  "name": "G2C Swagger 測試帳篷（更新）",
  "description": "<p>更新完成。</p>",
  "categoryId": 1,
  "brandId": "coleman",
  "status": "active",
  "images": [
    {
      "url": "/assets/images/products/g2c-swagger-main.jpg",
      "altText": "更新主圖"
    },
    {
      "url": "https://example.com/g2c-detail.jpg",
      "altText": "更新細節圖"
    }
  ],
  "variants": [
    {
      "id": "<existingVariantId>",
      "sku": "G2C-SWAGGER-001",
      "color": "深橄欖綠",
      "size": null,
      "specification": "深橄欖綠",
      "price": "3300.00",
      "status": "active"
    },
    {
      "sku": "G2C-SWAGGER-002",
      "color": "沙色",
      "size": null,
      "specification": "沙色",
      "price": "3400.00",
      "status": "active"
    }
  ]
}
```

預期圖片 `sortOrder` 依序為 `0`、`1`，新規格取得後端 ID。再次更新時移除第二個 variant，預期它仍存在但 `status=inactive`，而不是被刪除。

### 5. 驗證錯誤不污染資料

重送同一 SKU、負價格、重複規格組合或不存在的分類／品牌，預期回 `400` 或 `409`。重新 GET 詳情，資料應維持最後一次成功版本。

Request 額外傳入 `totalStock`、`branch`、`rentalEnabled` 或 `camp` 時不會成為可寫 DTO 欄位；前端正式模式也不會產生這些欄位。

### 6. 下架與重新上架

```http
POST /api/admin/products/{productId}/deactivate
GET /api/products/{productId}
GET /api/admin/products/{productId}
POST /api/admin/products/{productId}/activate
```

下架預期依序為 `200`、公開 `404`、後台 `200`；重新上架後公開詳情恢復 `200`。若所有規格皆 inactive，上架應回 `409`。

## DBeaver 核對

```sql
SELECT p.id, p.item_id, p.status, e.name, e.category_id, e.brand_id
FROM products p
JOIN equipment_items e ON e.id = p.item_id
WHERE p.id = '<productId>';

SELECT id, sku, color, size, specification, price, status
FROM product_variants
WHERE product_id = '<productId>'
ORDER BY id;

SELECT item_id, sort_order, url, alt_text
FROM equipment_images
WHERE item_id = '<itemId>'
ORDER BY sort_order;

SELECT s.*
FROM inventory_stocks s
JOIN product_variants v ON v.id = s.variant_id
WHERE v.product_id = '<productId>';
```

最後一段應為空；G-2c 不建立或調整庫存。人工驗證資料可保留為 inactive，若需清除請只在專用測試資料庫依 FK 關係處理。
