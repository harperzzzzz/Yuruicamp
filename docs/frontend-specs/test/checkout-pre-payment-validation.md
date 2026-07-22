# Checkout 線 D 前置驗證

驗證日期：2026-07-22

## 本次完成範圍

- Checkout `ready_to_pay` 明確顯示「等待付款」，不宣稱 ECPay 已導向或 COD 已成立。
- Checkout 狀態頁使用 `API.checkout.getSession(orderId)` 讀取後端最新 Session。
- 顯示訂單編號、`paymentStatus`、`pricing.total`、`checkoutExpiresAt` 倒數。
- 顯示 Loading、Pending、Paid、Cancelled、Expired 與 Error 狀態。
- 未付款頁移除成功彩帶，不以 query string 判定付款成功。

## 自動驗證

在 `frontend/` 執行：

```powershell
npm.cmd run test:checkout-success
npm.cmd run test:checkout-session-ui
npm.cmd run test:checkout-facade
npx.cmd eslint storefront/js/pages/checkout-success.js storefront/js/pages/checkout.js tests/checkout-success-state.mjs
npx.cmd stylelint storefront/css/pages/_checkout-success.scss
npm.cmd run build
```

結果：全部通過；ESLint 僅保留 `checkout.js` 既有的未使用變數 warning，無 error。Vite 仍輸出專案既有的非 module script 提示，但 build 成功。

## 尚未通過

- COD 成立。
- ECPay 表單建立與導向。
- Notify 驗簽與冪等。
- 後端付款成功狀態。
- 優惠券 claim 改為 `consumed`。
- 庫存／租借 fulfilled。

## 為什麼需要這份驗證

建單成功與付款成功是兩個不同狀態。此驗證可避免線 D 尚未完成時，前端把 `unpaid` 訂單錯誤呈現成已付款或已進入備貨，也保留日後付款串接的清楚驗收邊界。
