# Product API 正式評分統計

`GET /api/products` 與 `GET /api/products/{id}` 都回傳：

```json
{
  "rating": "4.6",
  "reviewCount": 35
}
```

統計來源是 `reviews` 經 `order_items.product_id` 關聯商品。平均值四捨五入至一位小數；無正式評論時為 `"0.0"` 與 `0`。列表只針對當頁商品 ID 執行一次批次聚合，避免 N+1。
