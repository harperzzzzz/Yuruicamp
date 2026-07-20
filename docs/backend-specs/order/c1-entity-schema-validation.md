# C-1 Entity Schema 驗證

## 用途

確認訂單與庫存保留 Entity 符合 `docs/latest_schema.sql`。

檢查範圍：

- `orders`
- `order_items`
- `product_stock_reservations`

## 流程

1. 啟動 PostgreSQL。
2. 設定正確的 `DB_PASSWORD`。
3. 執行整合測試。
4. Hibernate 使用 `ddl-auto=validate` 檢查 Entity。

```powershell
docker compose up -d
Set-Location -LiteralPath D:\GithubDesk\Yuruicamp\backend
$env:RUN_BACKEND_IT = "true"
$env:DB_PASSWORD = "與 Docker .env 相同的密碼"
.\mvnw.cmd test
```

## 注意

- `ddl-auto` 必須保持 `validate`。
- `password authentication failed` 代表密碼錯誤，不是 Entity 錯誤。
- `latest_schema.sql` 只會在 Docker Volume 第一次建立時自動匯入。

## 驗證結果

- PostgreSQL、Hibernate Schema 驗證通過。
- C-1 已完成。
