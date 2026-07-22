# ECPay 綠界測試環境資料

## ECPay ReturnURL 設定

請在專案根目錄的 `application.properties` 檔修改：



ecpay.return-url=${ECPAY_RETURN_URL:https://你的-ngrok網址/api/payments/ecpay/return}

> 本文件整理 ECPay AIO 全方位金流測試環境所需資料，僅供開發與測試使用，不可用於正式環境。

---

## 1. 測試特店管理後台

- 後台網址：<https://vendor-stage.ecpay.com.tw/>
- 主要功能：
  1. 查詢訂單
  2. 模擬付款

### 模擬付款操作路徑

```text
綠界特店管理後台
→ 一般訂單查詢
→ 全方位金流訂單
→ 輸入查詢條件
→ 在查詢結果中點擊「模擬付款」
```

模擬付款可用來測試特店主機是否能接收到綠界後端送出的付款結果通知。

---

## 2. 3D 驗證測試資料

- 測試環境 3D 驗證簡訊固定驗證碼：`1234`
- 不需要使用手機接收簡訊。

---

## 3. 一般信用卡測試卡號

### 卡號一

- 信用卡號：`4311-9511-1111-1111`
- 安全碼：任意三位數字
- 有效期限：必須晚於目前年月

### 卡號二

- 信用卡號：`4311-9522-2222-2222`
- 安全碼：任意三位數字
- 有效期限：必須晚於目前年月

---

## 4. 海外信用卡測試卡號

- 信用卡號：`4000-2011-1111-1111`
- 安全碼：任意三位數字
- 有效期限：必須晚於目前年月

---

## 5. 美國運通信用卡測試卡號

> 限閘道商使用。

### 國內

- 信用卡號：`3403-532780-80900`

### 國外

- 信用卡號：`3712-222222-22222`

---

## 6. 永豐 30 期信用卡測試卡號

- 信用卡號：`4938-1777-7777-7777`
- 安全碼：任意三位數字
- 適用情境：永豐 30 期服務測試

---

## 7. 信用卡有效期限注意事項

測試用信用卡的有效月／年必須晚於目前時間。

例如：

```text
目前日期：2016/04/20
可輸入：05/2016 或更晚
```

若輸入的有效月／年已過期，測試環境會回應刷卡失敗。

---

## 8. ReturnURL 注意事項

若使用綠界特店管理後台的「模擬付款」功能，卻無法收到付款通知，請檢查：

- ReturnURL 是否為公開可存取網址
- ReturnURL 是否能被綠界伺服器連線
- ReturnURL 是否正確接收 `POST`
- ReturnURL 是否接收 `application/x-www-form-urlencoded`
- Spring Security 是否放行該 endpoint
- CSRF 是否已針對該 callback endpoint 排除
- 成功處理後是否回傳純文字：

```text
1|OK
```

---

## 9. 特店測試資料

### 基本資料

- 特店編號 MerchantID：`3002607`
- 特店後台登入帳號：`stagetest3`
- 特店後台登入密碼：`test1234`
- 統一編號：`00000000`

### 串接金鑰

- HashKey：`pwFHCqoQZGmho4w6`
- HashIV：`EkRm7iFT261dpevs`

### 適用測試

- 模擬銀行 3D 驗證
- 中租無卡分期
- ECPay AIO Sandbox 串接

---

## 10. 平台商測試資料

### 基本資料

- 平台商特店編號 PlatformID：`3002599`
- 特店後台登入帳號：`stagetest2`
- 特店後台登入密碼：`test1234`
- 身分證末四碼：`3609`

### 串接金鑰

- HashKey：`spPjZn66i0OhqJsQ`
- HashIV：`hT5OJckN45isQTTs`

---

## 11. Sandbox 付款網址

ECPay AIO 測試環境付款網址：

```text
https://payment-stage.ecpay.com.tw/Cashier/AioCheckOut/V5
```

---

## 12. 信用卡一次付清常用參數

```text
PaymentType=aio
ChoosePayment=Credit
EncryptType=1
```

---

## 13. 安全注意事項

- 測試用 HashKey、HashIV 只能用於 Sandbox。
- 不要把正式環境 HashKey、HashIV 放在前端。
- 不要在系統中保存信用卡號、CVV、有效期限。
- 正式環境憑證應使用環境變數或 Secret Manager。
- 測試資料不可用於正式收款。
