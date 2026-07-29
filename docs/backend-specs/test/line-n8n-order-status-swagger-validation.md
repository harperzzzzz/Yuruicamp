# LINE n8n 訂單狀態客服 Swagger 驗證

## 前置

1. 啟動 Docker PostgreSQL 與 Spring Boot。
2. 設定環境變數（未設定時使用 `application.properties` 預設值）：
   ```powershell
   $env:YURUICAMP_LINE_INTERNAL_API_KEY = "dev-line-key"
   $env:YURUICAMP_LINE_BINDING_CODE_WEBHOOK_URL = "<可先留空以驗證失敗分支，或指向可接收 POST 的測試端點>"
   ```
3. 呼叫 `POST /api/auth/firebase/session` 建立測試會員，取得可查到既有訂單的 `dev:` Token（可沿用種子資料會員 `U001` 對應的訂單 `1`）。
4. Swagger `Authorize` 輸入同一個 `dev:...` Token 本體。

## 驗證：`POST /api/me/line-binding/code`

1. 未設定 `binding-code-webhook-url` 時呼叫，帶入本人訂單 `orderId`：應回 `409`、`error.code = CONFLICT`、`error.message = "LINE 綁定服務尚未設定"`。
2. 設定 `binding-code-webhook-url` 指向可接收 POST 的測試端點後重啟服務，再次呼叫：應回 `200`，`data.bindCode` 為 6 位數字串，`data.bindText` 為 `"綁定 " + bindCode`，`data.lineUrl = "https://lin.ee/NkgGfc4"`，`data.expiresAt` 約為呼叫時間 +10 分鐘。
3. 帶入不屬於本人或不存在的 `orderId`：應回 `404`、`error.code = NOT_FOUND`、`error.message = "查無此訂單"`。
4. 移除 Authorization 呼叫：應回 `401`。

```sql
-- 驗證訂單本人限制對照的來源訂單仍未被本功能修改
SELECT id, customer_id, status, payment_status FROM orders WHERE id = '<測試訂單 ID>';
```

## 驗證：`GET /api/internal/line/orders/{orderId}?customerId=`

1. 不帶 `X-Internal-Api-Key`：應回 `403`、`error.code = FORBIDDEN`。
2. 帶錯誤的 `X-Internal-Api-Key`：應回 `403`。
3. 帶正確 `X-Internal-Api-Key`（與 `YURUICAMP_LINE_INTERNAL_API_KEY` 相同）、正確 `orderId` 與該訂單的 `customerId`：應回 `200`，`data` 包含 `id`／`displayNo`／`status`／`paymentStatus`／`paymentMethod`／`total`／`placedAt`／`items[]`，且**不含** `buyerEmail`、`recipientName`、`shippingAddress`、`shippingPhone`。
4. `customerId` 留空：應回 `400`、`error.code = VALIDATION_ERROR`。
5. 正確 Key，但 `orderId` 與帶入的 `customerId` 不屬於同一筆訂單：應回 `404`、`error.message = "查無此訂單"`。

此端點在 `SecurityConfig` 中對 `/api/internal/line/**` 設定 `permitAll`，因此 Swagger 測試不需要（也不能）帶 Firebase Bearer；驗證重點在於 Controller 內的 `X-Internal-Api-Key` 檢查是否確實擋下未授權呼叫。

## 為什麼要驗證

這兩個端點是唯一會讓外部系統（n8n）直接讀到會員訂單資料的入口：綁定碼建立端點若沒有本人限制，會讓任意會員猜測他人 `orderId` 觸發 Webhook；internal 查單端點若 API Key 檢查失效，等於讓任何人不需登入就能查詢訂單狀態。因此必須逐項驗證 404／403／400 邊界情境，並確認個資欄位（Email、電話、地址）確實未出現在 internal 回應中，才能認定此 MVP 可以安全串接 n8n。
