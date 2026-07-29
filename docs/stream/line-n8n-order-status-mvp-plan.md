# LINE n8n 訂單狀態客服 MVP 計畫

## 1. 目標

本 MVP 要完成的不是「在 LINE 查最近三筆訂單」，而是讓會員可以從網站某一筆訂單詳情頁進入 LINE，完成綁定後，在 LINE 針對該筆訂單詢問狀態。

核心流程：

```text
會員登入 Yuruicamp
→ 進入會員中心訂單詳情
→ 點擊「使用 LINE 詢問訂單」
→ 產生一次性綁定碼
→ 使用者到 LINE 官方帳號輸入「綁定 839201」
→ n8n 綁定 lineUserId ↔ customerId，並記住來源 orderId
→ 使用者在 LINE 問「訂單狀態」
→ n8n 呼叫 Yuruicamp internal API 查該筆訂單
→ LINE 回覆該訂單目前狀態
```

## 2. 為什麼改成查來源訂單狀態

使用者如果已經在網站會員中心看到訂單詳情，再點「使用 LINE 詢問訂單」，他通常不是想再拿一次訂單列表，而是想針對這筆訂單問後續問題，例如：

```text
這筆訂單目前狀態是什麼？
什麼時候會出貨？
之後可以用 LINE 通知我嗎？
商品有問題可以退換貨嗎？
這筆訂單可以取消嗎？
```

因此 MVP 應定位為：

```text
LINE 訂單客服與通知綁定
```

而不是：

```text
LINE 查詢最近訂單列表
```

## 3. MVP 功能範圍

本階段要做：

```text
1. 從訂單詳情頁產生一次性綁定碼
2. 綁定 LINE lineUserId 與 Yuruicamp customerId
3. 保存這次來源訂單 orderId
4. 使用者在 LINE 詢問「訂單狀態」時，回覆來源訂單狀態
5. 未綁定時，引導使用者回網站訂單詳情產生綁定碼
```

本階段先不做：

```text
1. LINE Login / LIFF
2. 從 LINE 點連結回網站登入 callback
3. 任意自然語言查詢所有訂單欄位
4. 查最近三筆訂單列表
5. 修改配送地址
6. 修改取貨方式
7. 真正自動訂單狀態事件推播
8. 解除綁定
```

## 4. 資料儲存策略

為降低主系統風險，MVP 不修改 Yuruicamp 主資料庫 schema。

LINE 綁定資料與一次性綁定碼存放在 n8n 使用的 QA PostgreSQL 或獨立業務資料庫。

### line_binding_codes

用途：暫存網站產生的一次性綁定碼。

```text
bind_code
customer_id
order_id
expires_at
used_at
created_at
```

說明：

```text
customer_id：由 Yuruicamp 後端從 Firebase 登入 principal 取得
order_id：使用者按下 LINE 詢問的來源訂單
bind_code：給使用者到 LINE 輸入
expires_at：建議 10 分鐘後過期
used_at：綁定成功後標記，避免重複使用
```

### line_user_bindings

用途：保存 LINE 使用者與 Yuruicamp 會員的對應關係，並記住最近一次來源訂單。

```text
line_user_id
customer_id
last_order_id
created_at
updated_at
```

說明：

```text
line_user_id：LINE Webhook source.userId
customer_id：Yuruicamp 會員 ID
last_order_id：最近一次從網站訂單詳情帶入的訂單 ID
```

## 5. 前端流程

位置：會員中心訂單詳情 Modal 的「使用 LINE 詢問訂單」按鈕。

目前按鈕直接連到 LINE 官方帳號，MVP 改成：

```text
點擊按鈕
→ 呼叫 POST /api/me/line-binding/code
→ 傳入目前訂單 orderId
→ 顯示綁定碼提示
→ 使用者可複製文字或前往 LINE
```

建議提示文案：

```text
用 LINE 詢問這筆訂單

為了讓 LINE 客服知道你要詢問哪一筆訂單，請先完成綁定。

請到 LINE 官方帳號輸入：
綁定 839201

完成後可直接輸入「訂單狀態」查詢這筆訂單。
```

## 6. 後端 API 規劃

### POST /api/me/line-binding/code

用途：登入會員從訂單詳情頁產生一次性綁定碼。

認證：

```text
Firebase Bearer
```

Request：

```json
{
  "orderId": "Oa3038932f8844dc58e41b2a8a12f8bf"
}
```

後端行為：

```text
1. 從 CustomerPrincipal 取得 customerId
2. 確認 orderId 屬於該 customerId
3. 產生 6 位數 bindCode
4. 將 bindCode、customerId、orderId 寫入 n8n/QA PostgreSQL，或呼叫 n8n webhook 建立資料
5. 回傳 bindCode、expiresAt、lineUrl
```

Response：

```json
{
  "bindCode": "839201",
  "expiresAt": "2026-07-30T15:30:00Z",
  "lineUrl": "https://line.me/R/ti/p/@yuruicamp"
}
```

### GET /api/internal/line/orders/{orderId}?customerId=xxx

用途：n8n 用已綁定的 customerId 與來源 orderId 查詢該筆訂單狀態。

認證：

```text
X-Internal-Api-Key
```

後端行為：

```text
1. 檢查 internal API key
2. 確認 orderId 屬於 customerId
3. 查詢該筆訂單摘要
4. 回傳狀態、付款、金額與必要商品摘要
```

Response：

```json
{
  "id": "Oa3038932f8844dc58e41b2a8a12f8bf",
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

## 7. n8n Workflow 規劃

### 綁定分支

觸發：LINE 使用者輸入：

```text
綁定 839201
```

流程：

```text
LINE Webhook
→ 取得 lineUserId
→ 解析 bindCode
→ 查 line_binding_codes
→ 檢查存在、未過期、未使用
→ 取得 customerId、orderId
→ upsert line_user_bindings(lineUserId, customerId, lastOrderId)
→ 標記 line_binding_codes.used_at
→ LINE 回覆綁定成功
```

回覆文案：

```text
綁定成功！你現在可以輸入「訂單狀態」，查詢剛剛從網站帶入的那筆訂單。
```

### 訂單狀態分支

觸發文字範例：

```text
訂單狀態
查狀態
這筆訂單
出貨了嗎
```

流程：

```text
LINE Webhook
→ 取得 lineUserId
→ 查 line_user_bindings
→ 若未綁定：回覆請先到網站訂單詳情產生綁定碼
→ 若已綁定：取得 customerId、lastOrderId
→ 呼叫 GET /api/internal/line/orders/{lastOrderId}?customerId=xxx
→ 依 status/paymentStatus 組合回覆文字
```

回覆文案範例：

```text
這筆訂單目前狀態是「已完成」。
付款方式：貨到付款
訂單金額：NT$680
商品：戶外清涼袋 x 1
```

若找不到來源訂單：

```text
目前沒有可查詢的來源訂單。請回網站會員中心開啟訂單詳情，點選「使用 LINE 詢問訂單」重新產生綁定碼。
```

## 8. 狀態文字對應

可先用固定對照：

```text
unshipped：待出貨
shipped：已出貨
completed：已完成
returned：已退貨
cancelled：已取消
```

付款狀態：

```text
unpaid：未付款
paid：已付款
refunded：已退款
```

付款方式：

```text
cod：貨到付款
ecpay-credit：線上付款（綠界信用卡）
ecpay-atm：線上付款（綠界 ATM）
ecpay-cvs：線上付款（綠界超商）
```

## 9. 驗收流程

```text
1. 使用者未綁定，在 LINE 輸入「訂單狀態」
→ 回覆請先從網站訂單詳情產生綁定碼

2. 使用者登入網站，開啟某筆訂單詳情
→ 點「使用 LINE 詢問訂單」
→ 顯示「綁定 839201」

3. 使用者在 LINE 輸入「綁定 839201」
→ n8n 建立 lineUserId ↔ customerId，並保存 lastOrderId
→ LINE 回覆綁定成功

4. 使用者在 LINE 輸入「訂單狀態」
→ LINE 回覆該筆訂單的狀態、付款方式、金額與商品摘要
```

## 10. 報告用描述

本 MVP 採用一次性綁定碼完成 LINE 官方帳號使用者與 Yuruicamp 會員身份的配對。會員從網站訂單詳情頁點擊「使用 LINE 詢問訂單」後，系統產生短效綁定碼並保存該筆來源訂單。使用者於 LINE 官方帳號輸入綁定碼後，n8n 建立 `lineUserId ↔ customerId` 的對應關係，並記錄來源 `orderId`。後續使用者在 LINE 詢問「訂單狀態」時，n8n 會透過受 API Key 保護的 Yuruicamp internal API 查詢該筆訂單摘要並回覆。

此設計避免修改 Yuruicamp 主資料庫 schema，降低專題整合階段的回歸風險；同時也讓 LINE 客服能取得網站訂單上下文，提供比單純列出訂單列表更貼近使用者情境的客服體驗。

