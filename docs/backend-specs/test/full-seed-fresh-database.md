# 完整 Seed 全新資料庫驗證

## 驗證目的

確認全新 PostgreSQL 16 資料庫能先載入 `docs/latest_schema.sql`，再由 `docs/seed/002-dev-seed.sql` 依 `010`～`070` 順序載入完整展示資料，且所有 Seed 只在全部成功後一次提交。

## 2026-07-22 實際結果

- 使用獨立容器 `yuruicamp-seed-verify-20260722` 與獨立 volume `yuruicamp_seed_verify_20260722`。
- 既有 `yuruicamp-db` 與 `yuruicamp_data` 沒有停止、重建或清除。
- PostgreSQL 初始化輸出依序完成 Schema 與 Seed，Seed 輸出包含 `BEGIN`、`COMMIT`，沒有 `ERROR`／`FATAL`。
- 第二個資料庫連線可讀到 `010`～`070` 的全部資料，且沒有 `idle in transaction`。

主要筆數：

| 領域 | 實際筆數 |
|------|---------:|
| 品牌／active 營區／active zone／門市／會員 | 13／8／13／3／50 |
| 商品／商城規格 | 30／39 |
| 租借 SKU／租借規格／listing／租借庫存 | 29／38／17／334 |
| 優惠券 | 7 |
| 訂單／明細／狀態歷程／事件 | 222／435／431／607 |
| 預訂／zone 快照／租借快照／狀態歷程 | 90／90／40／190 |

其中租借總數包含前端對照的 28 SKU、37 規格、16 listing、333 庫存，以及既有 Swagger／整合驗收各 1 筆開發資料。

以下一致性檢查全部為 `0`：

- 訂單找不到會員。
- 訂單明細找不到相同 `product_id + variant_id`。
- 預訂找不到會員或營區。
- 預訂 zone 找不到營位。
- 預訂租借快照找不到 listing 或租借規格。
- 優惠券 `claimed_quantity` 非 `0`。
- 連線停留在未結束交易。

## 手動重做流程

測試前確認：

- Docker Desktop 已啟動。
- 使用新的專用容器名稱與 volume 名稱。
- 不對既有 `yuruicamp-db` 執行 `docker compose down -v`。

#### 1. 建立隔離資料庫

在 repository 根目錄設定本次專用名稱，並以暫時密碼啟動 PostgreSQL 16。掛載位置必須保持：

```text
docs/latest_schema.sql              -> /docker-entrypoint-initdb.d/001-schema.sql
docs/seed/002-dev-seed.sql          -> /docker-entrypoint-initdb.d/002-dev-seed.sql
docs/seed/dev/                      -> /docker-entrypoint-initdb.d/dev/
```

資料庫名稱建議使用 `yuruicamp_seed_verify`。不要掛載正式開發使用的 `yuruicamp_data`。

#### 2. 確認初始化與單一提交

執行：

```powershell
docker logs <專用驗證容器名稱>
```

預期：

- Schema 建立完成。
- Seed 區段依序執行 `010-reference.sql` 到 `070-bookings.sql`。
- Seed 區段最後出現 `COMMIT`。
- 不得出現 `ERROR` 或 `FATAL`。

#### 3. 從新連線驗證資料

執行：

```powershell
docker exec <專用驗證容器名稱> psql -U postgres -d yuruicamp_seed_verify
```

至少確認：

```sql
SELECT count(*) FROM customers;
SELECT count(*) FROM orders;
SELECT count(*) FROM order_items;
SELECT count(*) FROM bookings;
SELECT count(*) FROM booking_selected_zones;
SELECT count(*) FROM booking_selected_rentals;
```

預期依序為 `50`、`222`、`435`、`90`、`90`、`40`。

#### 4. 清理專用測試資源

完成後只移除本次明確命名的驗證容器與 volume。清理前先用 `docker inspect` 與 `docker volume inspect` 確認名稱，不可使用專案的 `yuruicamp-db` 或 `yuruicamp_data`。

## 驗收完成標準

- `latest_schema.sql` 成功建立完整 Schema。
- `002-dev-seed.sql` 依 `010`～`070` 載入並出現一次成功 `COMMIT`。
- 新連線能讀到所有主要展示資料。
- 交易主檔的會員、商品規格、營區、zone 與租借 FK 沒有孤兒。
- 驗證與清理都不影響既有開發資料庫。

這項驗證是必要的，因為單獨檢查 SQL 語法無法證明跨片段的 FK 順序、CHECK、Trigger 與大量交易快照可以在全新環境一次成立；只有從空資料庫完整載入，才能確認新成員或 CI 不會在首次初始化時得到半套展示資料。
