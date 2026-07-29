# Order Facade 前端接線

| 欄位            | 內容                                                |
| --------------- | --------------------------------------------------- |
| **狀態**        | 已完成                                              |
| **Facade**      | `window.API.orders`                                 |
| **Backend API** | `GET /api/me/orders`                                |
| **認證入口**    | `ApiClient._restRequest()` → `AppAuth.getIdToken()` |

## 1. 模式分流

### Mock 模式

`AppConfig.USE_MOCK_API !== false` 時：

- `getAll()` 合併 `/data/commerce/orders.json` 與 `localStorage.mockOrders`。
- `getByCustomerId(customerId, status)` 依傳入會員 ID 與狀態篩選。
- 不呼叫 Spring REST。

### Backend 模式

`AppConfig.USE_MOCK_API === false` 時：

- `getAll()` 透過 `ApiClient._restRequest('/me/orders', { auth: 'required' })` 查詢。
- `getByCustomerId()` 不使用前端傳入的 `customerId` 限定資料；會員身分由 Firebase Principal 決定。
- 不讀 `orders.json`，也不寫入 `mockOrders`。
- 完成訂單的點數發放不在前端執行，交由後端交易處理。

## 2. 顯示欄位正規化

後端契約欄位會保留，並補上會員中心既有顯示別名：

| 後端欄位                | 會員中心欄位          |
| ----------------------- | --------------------- |
| `placedAt`              | `createdAt`           |
| `paymentMethod`         | `payment`             |
| `shippingAddress`       | `address`             |
| `shippingPhone`         | `buyerPhone`          |
| `items[].id`            | `items[].orderItemId` |
| `items[].productName`   | `items[].name`        |
| `items[].imageUrl`      | `items[].image`       |
| `items[].unitPrice`     | `items[].price`       |
| `items[].specification` | `items[].specLabel`   |

## 3. 自動驗證

執行：

```powershell
cd frontend
npm.cmd run test:member-orders
```

測試確認 Backend 路徑、必要認證、Principal 邊界、欄位正規化、不寫 Mock Storage，以及 Mock 模式不呼叫 REST。

網頁人工驗證見 [`member-orders-backend-validation.md`](../test/member-orders-backend-validation.md)。
