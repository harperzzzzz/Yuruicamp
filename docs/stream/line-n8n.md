# LINE n8n 來源訂單狀態客服 MVP：程式端執行規格

## 0. 執行前必讀文件

請在開始寫程式前，依序閱讀以下文件，並遵守其中限制：

1. `.agents/agents.md`
2. `.agents/mapping-agents.md`
3. `AGENTS.md`
4. `docs/line-n8n-order-status-mvp-plan.md`
5. `plans/java-backend-architecture-proposal.md`
6. `plans/backend-implementation-checklist.md`
7. `plans/data-integration-spec.md`
8. `docs/api/README.md`
9. `backend/README.md`
10. `docs/seed/README.md`
11. `README.md`

本任務不修改 Yuruicamp 主資料庫 schema，不新增 seed，不修改 `docs/latest_schema.sql`，不新增 Spring Boot dependency。

---

## 1. 任務目標

完成 LINE n8n 訂單狀態客服最小 MVP 的網站端程式。

流程：

```text
會員登入網站
→ 進入會員中心某筆商品訂單詳情
→ 點「使用 LINE 詢問訂單」
→ 後端產生一次性綁定碼
→ 後端呼叫 n8n webhook 保存 bindCode/customerId/orderId
→ 前端顯示後端回傳的 bindText，例如「綁定 839201」
→ 使用者到 LINE 輸入綁定碼
→ n8n 記住 lineUserId/customerId/lastOrderId
→ 使用者問「訂單狀態」
→ n8n 呼叫 internal API 查該筆訂單
```

本任務只做商品訂單，不做 Booking 預約。

---

## 2. 必須遵守的實作邊界

- 不動 Yuruicamp 主資料庫 schema。
- 不新增 `line_user_id` 到主 DB。
- 不新增 JPA Entity 對應 LINE 綁定表。
- 不新增第二個 datasource。
- 不新增 Spring Boot dependency。
- 前端正式 HTTP 只能走 `AppAuth + ApiClient`。
- 不新增第二套 `fetch` / Bearer token 包裝。
- 不改既有 `/api/me/orders` 行為。
- 不讓 n8n 呼叫 `/api/me/orders`。
- internal API 不回地址、電話、email。
- 所有新增後端程式加簡短中文註解。
- Controller 每個端口加中文註解。
- 後端流程文件放到 `docs/backend-specs/`。
- 根目錄 `README.md` 與 `backend/README.md` 要更新。
- 不產生錯誤 log 檔案。

---

## 3. 後端實作步驟

### 3.1 新增設定

修改：

```text
backend/src/main/resources/application.properties
backend/src/main/java/com/yuruicamp/backend/config/YuruicampProperties.java
```

新增設定：

```properties
yuruicamp.line-integration.internal-api-key=${YURUICAMP_LINE_INTERNAL_API_KEY:dev-line-key}
yuruicamp.line-integration.binding-code-webhook-url=${YURUICAMP_LINE_BINDING_CODE_WEBHOOK_URL:}
yuruicamp.line-integration.official-account-url=${YURUICAMP_LINE_OFFICIAL_ACCOUNT_URL:https://lin.ee/NkgGfc4}
```

在 `YuruicampProperties` 新增 `LineIntegration` nested class，包含：

```text
internalApiKey
bindingCodeWebhookUrl
officialAccountUrl
```

### 3.2 新增 package

建立：

```text
backend/src/main/java/com/yuruicamp/backend/integration/line/api
backend/src/main/java/com/yuruicamp/backend/integration/line/application
backend/src/main/java/com/yuruicamp/backend/integration/line/infrastructure
```

### 3.3 新增會員產生綁定碼 API

新增 endpoint：

```text
POST /api/me/line-binding/code
```

Request：

```json
{
  "orderId": "1"
}
```

Response：

```json
{
  "bindCode": "839201",
  "bindText": "綁定 839201",
  "expiresAt": "2026-07-30T15:30:00Z",
  "lineUrl": "https://lin.ee/NkgGfc4"
}
```

實作要求：

- 從 `CustomerPrincipal.customerId()` 取得會員 ID。
- 不接受前端傳 `customerId`。
- 使用 `OrderRepository.findForCustomer(orderId, customerId)` 確認訂單屬於本人。
- 訂單不存在或不屬於本人，HTTP 維持 `404 NOT_FOUND`，但 `error.message` 必須是：
  ```text
  查無此訂單
  ```
- 產生 6 位數隨機綁定碼。
- `expiresAt = now + 10 minutes`。
- 呼叫 n8n webhook，送出：

```json
{
  "bindCode": "839201",
  "customerId": "U001",
  "orderId": "1",
  "expiresAt": "2026-07-30T15:30:00Z"
}
```

HTTP header：

```text
X-Internal-Api-Key: {yuruicamp.line-integration.internal-api-key}
```

若 `binding-code-webhook-url` 空白，回可理解錯誤，例如 `CONFLICT` 或 `INTERNAL_ERROR`，message 為「LINE 綁定服務尚未設定」。

### 3.4 綁定碼顯示規則

文件中的 `839201` 只是示意碼，實作時不可寫死。

前端和文件範例可以顯示：

```text
綁定 839201
```

但程式必須使用後端回傳值：

```js
result.bindText
```

或用後端回傳的 `bindCode` 組出：

```js
'綁定 ' + result.bindCode
```

禁止在前端寫死：

```js
const bindText = '綁定 839201';
```

### 3.5 新增 internal 訂單狀態 API

新增 endpoint：

```text
GET /api/internal/line/orders/{orderId}?customerId=U001
```

Header：

```text
X-Internal-Api-Key: dev-line-key
```

Response：

```json
{
  "id": "1",
  "displayNo": "ORD-0001",
  "status": "completed",
  "paymentStatus": "unpaid",
  "paymentMethod": "cod",
  "total": "680.00",
  "placedAt": "2026-07-26T11:02:51Z",
  "items": [
    {
      "productName": "戶外清涼袋",
      "quantity": 1
    }
  ]
}
```

實作要求：

- Controller 內檢查 `X-Internal-Api-Key`。
- key 不符合回 `403`。
- `orderId` 或 `customerId` 空白回 `400`。
- 使用 `OrderRepository.findForCustomer(orderId, customerId)` 查詢。
- 訂單不存在或不屬於該 `customerId` 時，HTTP 維持 `404 NOT_FOUND`，但 `error.message` 必須是：
  ```text
  查無此訂單
  ```
- 不回 buyerEmail、recipientName、shippingAddress、shippingPhone。
- 商品摘要只回 `productName` 與 `quantity`。
- 金額維持字串兩位小數。
- 時間維持 ISO-8601。
- n8n 收到此錯誤時，對 LINE 使用者顯示：
  ```text
  查無此訂單
  ```

### 3.6 調整 SecurityConfig

修改：

```text
backend/src/main/java/com/yuruicamp/backend/config/SecurityConfig.java
```

在：

```java
.requestMatchers("/api/admin/**").hasRole("ADMIN")
.requestMatchers("/api/**").hasRole("CUSTOMER")
```

之前新增：

```java
.requestMatchers("/api/internal/line/**").permitAll()
```

注意：放行只是讓 n8n 無 Firebase Bearer 可進 Controller，真正授權由 `X-Internal-Api-Key` 檢查。

---

## 4. 前端實作步驟

### 4.1 修改會員中心 LINE 按鈕

主要檔案：

```text
frontend/storefront/js/components/member-center.js
```

目前訂單詳情中有：

```html
<a class="memberDetailLineButton" href="https://lin.ee/NkgGfc4" target="_blank" rel="noopener">
```

改為商品訂單才顯示 button：

```html
<button class="memberDetailLineButton" type="button" data-line-bind-order="ORDER_ID">
```

第一版只支援：

```text
type === 'purchase'
```

Booking/rental 預約先不要接。

### 4.2 新增點擊事件

在既有全域事件綁定區加入處理：

```text
點擊 [data-line-bind-order]
→ 取得 orderId
→ 呼叫 ApiClient
→ 顯示綁定碼提示
```

必須使用：

```js
const result = await window.ApiClient._restRequest('/me/line-binding/code', {
  method: 'POST',
  auth: 'required',
  body: {
    orderId: orderId
  }
});
```

禁止：

```text
fetch()
localStorage token
手動組 Authorization Bearer
```

### 4.3 顯示綁定碼 UI

使用既有會員中心 modal / overlay 風格，不做大型新 UI。

文案中的綁定文字必須來自：

```js
result.bindText
```

若沒有 `bindText`，才使用：

```js
'綁定 ' + result.bindCode
```

文案：

```text
用 LINE 詢問這筆訂單

為了讓 LINE 客服知道你要詢問哪一筆訂單，請先完成綁定。

請到 LINE 官方帳號輸入：
{後端回傳的 bindText}

完成後可直接輸入「訂單狀態」查詢這筆訂單。
```

按鈕：

```text
複製綁定文字
前往 LINE
```

複製內容：

```text
{後端回傳的 bindText}
```

「前往 LINE」連結使用後端回傳的：

```js
result.lineUrl
```

預設會是：

```text
https://lin.ee/NkgGfc4
```

若 API 失敗，顯示後端 `error.message`。若沒有 message，顯示：

```text
暫時無法產生 LINE 綁定碼，請稍後再試。
```

---

## 5. n8n 需配合的內容

這部分不是網站程式，但後端會依此 contract 呼叫。

### 5.1 QA PostgreSQL 表

```sql
create table if not exists line_binding_codes (
  bind_code text primary key,
  customer_id text not null,
  order_id text not null,
  expires_at timestamptz not null,
  used_at timestamptz null,
  created_at timestamptz not null default now()
);

create table if not exists line_user_bindings (
  line_user_id text primary key,
  customer_id text not null,
  last_order_id text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

### 5.2 n8n 建立綁定碼 Webhook

後端會呼叫：

```text
POST {YURUICAMP_LINE_BINDING_CODE_WEBHOOK_URL}
X-Internal-Api-Key: {YURUICAMP_LINE_INTERNAL_API_KEY}
Content-Type: application/json
```

Body：

```json
{
  "bindCode": "839201",
  "customerId": "U001",
  "orderId": "1",
  "expiresAt": "2026-07-30T15:30:00Z"
}
```

n8n 回：

```json
{
  "ok": true
}
```

---

## 6. 文件更新

必須新增/更新：

```text
docs/api/line-integration-api-contract.md
docs/api/README.md
docs/backend-specs/integration/line-n8n-order-status-mvp.md
docs/backend-specs/test/line-n8n-order-status-swagger-validation.md
backend/README.md
README.md
```

文件內容要求：

- 說明用途、API、認證方式、流程、驗證步驟。
- 明確註明 LINE 官方帳號連結為：
  ```text
  https://lin.ee/NkgGfc4
  ```
- 明確註明文件中的 `839201` 是示意碼，實作不可寫死，必須顯示後端回傳的 `bindText` 或 `bindCode`。
- 明確註明查無訂單時 HTTP 維持 `404 NOT_FOUND`，但 `error.message` 必須是「查無此訂單」。
- `docs/backend-specs/test/...` 要寫 Swagger 手動驗證流程。
- 不要寫過長原因，只寫重點步驟。
- 若沒有實作完成，不要新增 test 文件。

---

## 7. 驗收清單

### 7.1 後端驗收

- 無 Bearer 呼叫 `POST /api/me/line-binding/code` 回 `401`。
- 有 Bearer 且 orderId 屬於本人，回 `bindCode/bindText/expiresAt/lineUrl`。
- `lineUrl` 必須是：
  ```text
  https://lin.ee/NkgGfc4
  ```
- 有 Bearer 但 orderId 不存在或非本人，回 `404 NOT_FOUND`，且 message 為「查無此訂單」。
- 無 `X-Internal-Api-Key` 呼叫 internal API，回 `403`。
- 錯誤 key 呼叫 internal API，回 `403`。
- 正確 key 呼叫：
  ```text
  GET /api/internal/line/orders/{orderId}?customerId=U001
  ```
  回訂單摘要。
- internal API 查不到或不屬於該 `customerId` 時，回 `404 NOT_FOUND`，且 message 為「查無此訂單」。
- internal API 不包含 email、地址、電話。

### 7.2 前端驗收

- 會員中心商品訂單詳情可點「使用 LINE 詢問訂單」。
- 成功顯示後端回傳的 `bindText`，例如 `綁定 123456`。
- 前端不可寫死 `綁定 839201`。
- 複製按鈕內容等於後端回傳的 `bindText`。
- 前往 LINE 連結使用後端回傳的 `lineUrl`。
- 前往 LINE 連結應為：
  ```text
  https://lin.ee/NkgGfc4
  ```
- API 失敗時畫面不崩潰，有錯誤提示。
- 若後端回「查無此訂單」，前端顯示「查無此訂單」。

### 7.3 n8n 串接驗收

- 後端產碼後，QA PostgreSQL 有 `line_binding_codes`。
- LINE 輸入 `綁定 123456`，n8n 寫入 `line_user_bindings.last_order_id`。
- LINE 輸入 `訂單狀態`，n8n 呼叫 internal API 並回覆來源訂單狀態。
- internal API 回 `404 NOT_FOUND` 且 message 為「查無此訂單」時，LINE 回覆「查無此訂單」。
- 未綁定直接問 `訂單狀態`，n8n 引導回網站訂單詳情產生綁定碼。

---

## 8. 不做項目

本分支不要做：

- 查最近三筆訂單。
- FAQ / public API 查詢。
- 指定其他訂單查詢。
- Booking 預約 LINE 詢問。
- LINE Login。
- LIFF。
- 解除綁定。
- 主動訂單狀態事件推播。
- 修改配送地址。
- 修改付款方式。
- 修改主資料庫 schema。
- 新增 seed。
- 新增依賴。

---

## 9. 實作建議順序

1. 先改後端設定 `YuruicampProperties` / `application.properties`。
2. 新增 LINE integration DTO / Service / Controller。
3. 新增 internal order status API。
4. 修改 `SecurityConfig` 放行 `/api/internal/line/**`。
5. 用 Swagger/curl 驗證後端。
6. 改 `member-center.js` LINE 按鈕與 modal。
7. 用瀏覽器驗證前端產碼。
8. 串 n8n Workflow A。
9. 串 n8n LINE Webhook 綁定與訂單狀態分支。
10. 補文件。
11. 最後跑後端測試與前端基本驗收。

