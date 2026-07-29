# 會員配送地址 Swagger 驗證

## 前置

1. 啟動 Docker PostgreSQL 與 Spring Boot。
2. 呼叫 `POST /api/auth/firebase/session` 建立測試會員。
3. Swagger `Authorize` 輸入同一個 `dev:...` Token 本體。

## 驗證

1. `GET /api/me/shipping-address`：新會員應回 `200` 且 `data: null`。
2. `PUT /api/me/shipping-address`：使用 API 契約範例，Email 改為測試會員信箱；應回 `200` 與完整地址。
3. 再次 `GET`：內容應與 PUT 結果一致。
4. 修改地址後再次 `PUT`：應更新同一筆預設地址，不新增第二筆。
5. 將 Email 換成其他信箱：應回 `400`、`error.code = VALIDATION_ERROR`。
6. 移除 Authorization：應回 `401`。

```sql
SELECT customer_id, recipient_name, postal_code, city, district,
       address_line, phone, is_default
FROM customer_shipping_addresses
WHERE customer_id = '<測試會員 ID>';
```

測試完成後使用專案既有 soft-delete 流程清理測試會員，不直接硬刪 `customers`。
