# 會員中心 Order Backend 網頁驗證

## 1. 前置條件

- PostgreSQL 已套用最新 Schema 與開發 seed。
- 後端已啟動於 `http://localhost:8080`。
- 前端 `AppConfig.USE_MOCK_API=false`。
- 前端使用 `npm.cmd run dev` 啟動。
- 已透過 Firebase 或 development Token 登入有訂單的會員。

## 2. 驗證請求來源

1. 開啟 `/storefront/pages/member-center.html`。
2. 開啟 DevTools → Network。
3. 勾選 `Preserve log`。
4. 重新整理頁面並切到購買紀錄。
5. 找到 `GET /api/me/orders`。

預期：

- Request URL 是後端 `/api/me/orders`，不是 `/data/commerce/orders.json`。
- Request Headers 有 `Authorization: Bearer ...`。
- Response 為 `{ success: true, data: [...], meta: ... }`。
- 沒有發出 `/api/orders?customerId=...`。

## 3. 驗證畫面資料

1. 比對 Network Response 第一筆訂單 ID、狀態、金額和商品數量。
2. 確認會員中心訂單卡顯示相同資料。
3. 點擊訂單詳情。
4. 比對商品名稱、規格、圖片、數量、明細金額、付款方式與配送地址。

預期：

- `placedAt` 正確顯示為訂單時間。
- `paymentMethod` 正確顯示付款方式。
- 商品使用後端 `productName`、`specification`、`imageUrl` 與 `unitPrice` 快照。
- 訂單明細的評價識別使用後端 `order_items.id`。

## 4. 驗證 Checkout 後可見

1. 使用同一會員完成一次 Checkout Session 建立。
2. 保留 Network Log，導向會員中心。
3. 確認重新呼叫 `GET /api/me/orders`。
4. 確認新建立的訂單出現在列表最上方。

此階段只代表待付款訂單已由真後端建立並可讀取；Payment 線完成前，不可將 ECPay 訂單標記為已付款。

## 5. 驗證 Mock 隔離

在 Console 檢查：

```javascript
localStorage.getItem("mockOrders");
```

Backend 模式讀取會員訂單不應新增或更新這個 key。既有 Mock 資料即使存在，也不能混入後端列表。

## 6. 驗證失敗狀態

- 清除登入後重新整理：`GET /api/me/orders` 應回 `401`，會員中心不得退回顯示 Mock 訂單。
- 暫停後端後重新整理：訂單領域可顯示空狀態並記錄載入失敗，但 Booking、Coupon 等其他領域仍可獨立處理。

## 7. 為什麼需要驗證

這項驗證確保 Checkout 建立的真實訂單能在會員中心被同一位會員看見，也確認前端不會因 Backend 請求失敗而偷偷回退到 JSON 或 `localStorage`，避免畫面顯示與資料庫不一致。Principal 邊界則確保會員資料來源是後端驗證的登入身分，而不是可由瀏覽器竄改的會員 ID。
