# Checkout I-5 Backend 狀態手動驗證

## 用途

確認 Backend 模式的成交金額、Session 暫存、ECPay 提示與優惠券邊界符合 Checkout 契約。

## 前置條件

- `frontend/storefront/js/config.js` 設為 `USE_MOCK_API: false`。
- Spring Boot 已啟動，測試會員可取得 Bearer Token。
- PostgreSQL 有可售商品與庫存，購物車至少有一個有效 `variantId`。

## 驗證流程

1. 開啟 `/storefront/pages/checkout.html`，確認摘要提示「送出前為預估金額」。
2. 選擇信用卡，確認只顯示「下一步將前往 ECPay」，頁面沒有卡號、到期日或 CVV 欄位。
3. 確認優惠券輸入與套用按鈕停用，並顯示「優惠券功能開發中」。
4. 填妥資料後建立 Session，對照 Network 回應的 `data.pricing` 與頁面小計、運費、折扣、合計，四項必須一致。
5. 檢查 Session Storage，應有 `lastCheckoutSession`，內容是完整 CheckoutSession；Local Storage 不應新增 `lastCheckoutOrder` 或 `mockOrders`。
6. 重新整理頁面，應從 `lastCheckoutSession` 還原後端金額與已建立狀態，不再建立新訂單。
7. 確認頁面未清空購物車、未標記付款、未消耗優惠券或首購資格；付款下一步等待 I-7。

## 自動檢查

```powershell
cd frontend
npm run test:checkout-backend
npm run smoke
```

預期分別顯示 `checkout backend state test passed` 與 `Smoke checks passed.`。
