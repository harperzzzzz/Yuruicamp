# Review Facade

`window.API.reviews` 依 `AppConfig.USE_MOCK_API` 分流：

| 方法 | Mock | Backend |
| --- | --- | --- |
| `getAll()` | 合併 `/data/admin/reviews.json` 與 `localStorage.mockReviews` | `GET /api/me/reviews` |
| `create(payload)` | 驗證 Mock 訂單明細後寫入 `localStorage.mockReviews` | `POST /api/me/reviews` |

Backend Request 只送：

```json
{
  "orderItemId": 602081,
  "rating": 5,
  "comment": "商品很實用"
}
```

會員、訂單、商品、規格、已購狀態與建立時間都由後端決定。正式 HTTP 必須透過 `ApiClient._restRequest()`，不得新增第二套 Bearer 或直接 `fetch()`。

