# Checkout 狀態頁規格

**狀態：** COD 狀態已完成；ECPay 線 D 待完成
**原始檔：** `frontend/storefront/pages/checkout-success.html`

## 目的與責任邊界

此頁是 Checkout Session 狀態確認頁，不是付款成功頁。頁面以 `API.checkout.getSession(orderId)` 讀取後端 `GET /api/checkout/sessions/{orderId}`，不得根據 ECPay Return query string、`localStorage` 或前端推測宣告付款成功。

目前：

- 可顯示訂單已建立、`unpaid`、金額、保留倒數、取消、逾時與讀取錯誤。
- COD `checkoutStep=completed` 可顯示訂單成立，但 `paymentStatus` 仍為 `unpaid`。
- COD 成立說明會提示「取消訂單可以前往會員中心的訂單紀錄取消訂單」。
- ECPay 不可由返回參數宣稱已付款；仍等待後端 Notify 驗簽與付款後資源落帳。

## 資料來源

訂單 ID 依序取自：

1. query string `orderId`，並相容舊 `orderNum`。
2. `sessionStorage.checkoutCompletedOrderId`。
3. `sessionStorage.lastCheckoutSession.orderId`。

ID 只用來發出讀取請求；畫面狀態與價格一律採後端回應。正式 HTTP 經既有 `API.checkout` facade、`ApiClient` 與 `AppAuth`，不可新增原生 `fetch()` 或 Bearer 包裝。

## 顯示狀態

| 狀態          | 判斷                                            | 標題                 |
| ------------- | ----------------------------------------------- | -------------------- |
| Loading       | API 尚未完成                                    | 正在確認訂單狀態     |
| Pending       | `unpaid` 且未取消、未逾時                       | 訂單已建立，等待付款 |
| Paid          | 後端明確回傳 `paymentStatus=paid`               | 付款狀態已由後端確認 |
| COD confirmed | `paymentMethod=cod` 且 `checkoutStep=completed` | 貨到付款訂單已成立   |
| Cancelled     | `status=cancelled` 且期限未過                   | 此訂單已取消         |
| Expired       | `checkoutExpiresAt <= now`                      | 結帳保留已逾時       |
| Error         | 無 ID、`404` 或 API 失敗                        | 無法確認訂單狀態     |

## UI 與無障礙

- 沿用既有 `--yc-*` Token、卡片與按鈕樣式，不建立第二套 Design System。
- `aria-busy` 表達讀取狀態；主要描述與訂單編號使用 live region。
- 狀態不能只靠顏色辨識，必須同時顯示文字 Badge、標題與說明。
- 手機版金額、付款狀態與倒數改為單欄，不產生水平捲動。
- 未付款頁不播放成功彩帶效果。

## 驗收標準

- [x] 透過 Checkout facade 讀取 Session，沒有第二套 HTTP 封裝。
- [x] Pending、Paid、Cancelled、Expired 與 Error 有不同文字與視覺狀態。
- [x] 顯示後端訂單編號、付款狀態、總額與保留倒數。
- [x] 不以返回參數或前端快取宣告付款成功。
- [x] 單元測試涵蓋狀態解析與訂單 ID 來源。
- [x] COD 確認後顯示訂單成立與「未付款」，期限顯示不適用。
- [x] COD 成立後提示可前往會員中心的訂單紀錄取消訂單。
- [ ] 線 D：完成 ECPay／Notify 後，驗證付款返回與付款後狀態輪詢。
