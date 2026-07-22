# 完整 Seed 全新資料庫驗證

## 驗證目的

確認全新 PostgreSQL 16 資料庫能先載入 `docs/latest_schema.sql`，再由 `docs/seed/002-dev-seed.sql` 依 `010`～`070` 順序載入完整展示資料，且所有 Seed 只在全部成功後一次提交。

## 2026-07-22 實際結果

- 使用獨立容器 `yuruicamp-seed-verify-20260722` 與獨立 volume `yuruicamp_seed_verify_20260722`。
- 既有 `yuruicamp-db` 與 `yuruicamp_data` 沒有停止、重建或清除。
- PostgreSQL 初始化輸出依序完成 Schema 與 Seed，Seed 輸出包含 `BEGIN`、`COMMIT`，沒有 `ERROR`／`FATAL`。
- 第二個資料庫連線可讀到 `010`～`070` 的全部資料，且沒有 `idle in transaction`。
- 完成隔離驗證後，另對目前 healthy 的 `yuruicamp-db` 複驗：會員／訂單／訂單明細／預訂／zone／租借快照為 `50／222／435／90／90／40`，10 組 FK 孤兒檢查全部為 `0`。
- 補入會員周邊資料後，另建暫存資料庫 `yuruicamp_member_seed_verify_20260722` 重跑相同 schema + 完整 Seed；一次 `COMMIT` 成功後取得偏好選項／會員偏好／預設地址／會員標籤／標籤指派 `18／200／50／3／56`，周邊 FK 孤兒與重複預設地址皆為 `0`，驗證後已刪除暫存資料庫。
- 2026-07-22 13:23（Asia/Taipei）再對目前 healthy 的 `yuruicamp` 完整執行 `002-dev-seed.sql`；`010`～`070` 同一交易出現 `BEGIN`／`COMMIT`。下列 28 組主要筆數符合預期，11 組 FK／重複預設地址檢查皆為 `0`，`coupon_claims`、`order_coupons`、折扣訂單與 `claimed_quantity` 亦維持 `0`。

主要筆數：

| 領域 | 實際筆數 |
|------|---------:|
| 品牌／active 營區／active zone／門市／會員 | 13／8／13／3／50 |
| 偏好選項／會員偏好／預設地址／會員標籤／標籤指派 | 18／200／50／3／56 |
| 商品／商城規格 | 30／39 |
| 租借 SKU／租借規格／listing／租借庫存 | 29／38／17／334 |
| 優惠券／claim／訂單券快照／折扣訂單 | 7／0／0／0 |
| 訂單／明細／狀態歷程／事件 | 222／435／431／607 |
| 預訂／zone 快照／租借快照／狀態歷程 | 90／90／40／190 |

其中租借總數包含前端對照的 28 SKU、37 規格、16 listing、333 庫存，以及既有 Swagger／整合驗收各 1 筆開發資料。

以下一致性檢查全部為 `0`：

- 訂單找不到會員。
- 訂單明細找不到相同 `product_id + variant_id`。
- 預訂找不到會員或營區。
- 預訂 zone 找不到營位。
- 預訂租借快照找不到 listing 或租借規格。
- `coupon_claims`、`order_coupons`、正折扣訂單或優惠券 `claimed_quantity` 非 `0`。
- 會員偏好找不到會員或偏好選項。
- 會員地址找不到會員，或同會員存在多筆預設地址。
- 會員標籤指派找不到會員或標籤主檔。
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
SELECT count(*) FROM preference_options;
SELECT count(*) FROM customer_preferences;
SELECT count(*) FROM customer_shipping_addresses WHERE is_default;
SELECT count(*) FROM customer_tags;
SELECT count(*) FROM customer_tag_assignments;
SELECT count(*) FROM coupon_claims;
SELECT count(*) FROM order_coupons;
SELECT count(*) FROM orders WHERE discount <> 0;
SELECT count(*) FROM coupons WHERE claimed_quantity <> 0;
SELECT count(*) FROM orders;
SELECT count(*) FROM order_items;
SELECT count(*) FROM bookings;
SELECT count(*) FROM booking_selected_zones;
SELECT count(*) FROM booking_selected_rentals;
```

周邊資料預期為 `18`、`200`、`50`、`3`、`56`；四項優惠券關聯檢查皆為 `0`；原核心資料仍為 `50`、`222`、`435`、`90`、`90`、`40`。

庫存與保留另應確認：

```sql
SELECT count(*), sum(on_hand_quantity) FROM inventory_stocks;
SELECT status, count(*), sum(quantity) FROM product_stock_reservations GROUP BY status;
SELECT status, count(*), sum(quantity) FROM rental_stock_reservations GROUP BY status;
SELECT count(*) FROM reviews;
SELECT count(*) FROM inventory_movements;
```

預期商城庫存 `156／499`；商城保留 active／expired／fulfilled 為 `68／28／339`；租借保留 active／released／fulfilled 為 `22／4／14`；評論 1；庫存異動 0。active catalog 扣除保留後的可用量總計應為 399，租借 active 區間的任一重疊需求不得超過 on-hand。

#### 4. 清理專用測試資源

完成後只移除本次明確命名的驗證容器與 volume。清理前先用 `docker inspect` 與 `docker volume inspect` 確認名稱，不可使用專案的 `yuruicamp-db` 或 `yuruicamp_data`。

## 驗收完成標準

- `latest_schema.sql` 成功建立完整 Schema。
- `002-dev-seed.sql` 依 `010`～`070` 載入並出現一次成功 `COMMIT`。
- 新連線能讀到所有主要展示資料。
- 交易主檔的會員、商品規格、營區、zone 與租借 FK 沒有孤兒。
- 會員偏好、地址與標籤指派沒有孤兒，且每位展示會員只有一筆預設地址。
- 沒有來源證據時，`coupon_claims`、`order_coupons`、訂單折扣與 `claimed_quantity` 全部維持 `0`。
- 435 筆商城保留與 40 筆租借保留的交易明細／variant 與 location／domain 複合 FK 孤兒為 `0`。
- 商城無負可用量，租借無 active 區間重疊超賣；`REV031` 在 `review_dto_view` 顯示 order 208、V001、verified purchase。
- 驗證與清理都不影響既有開發資料庫。

## 2026-07-22 庫存／評論 Seed 實灌結果

使用現有 PostgreSQL 16 容器內的全新獨立資料庫 `yuruicamp_inventory_verify_final_0722`，先執行 `latest_schema.sql`，再完整執行 `002-dev-seed.sql`。`010` → `070` 從空庫一次成功 `COMMIT`；另在 `yuruicamp_inventory_verify_0722` 連續重跑，驗證冪等性。

- 商城庫存／on-hand／active 保留／全規格可用量：`156／499／98／401`；排除 P010、P030 兩個 inactive 規格後為 399。
- 商城保留：435 筆，active／expired／fulfilled = `68／28／339`。
- 租借保留：40 筆，active／released／fulfilled = `22／4／14`；區間重疊超賣 = 0。
- 保留、地點、交易明細與評論 FK 孤兒全部為 0。
- `REV031` 投影為 order 208／customer U027／variant V001／SKU TENT-OLIVE／verified purchase。
- 相同 Seed 隨後已套用到目前 `yuruicamp`；該庫的 active catalog 可用量 399、負庫存 0、租借區間超賣 0，舊 `DEV-STORE-MAIN` 已停用且 V001 fixture 庫存列為 0 筆。

這項驗證是必要的，因為單獨檢查 SQL 語法無法證明跨片段的 FK 順序、CHECK、Trigger 與大量交易快照可以在全新環境一次成立；只有從空資料庫完整載入，才能確認新成員或 CI 不會在首次初始化時得到半套展示資料。
