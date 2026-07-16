# `latest_schema.sql` 全專案運用評估報告

## 1. 評估結論

`docs/latest_schema.sql` **可以作為 Yuruicamp 新建 PostgreSQL 資料庫的完整結構基線**，但目前**不能單獨取代整個專案的 JSON 資料層，也不能讓前端直接切換成資料庫模式**。

目前最準確的定位如下：

- 可作為本機、測試環境與新部署環境的「空資料庫初始化檔」。
- 可作為後端開發 Entity、Repository、Service、Controller 與 DTO 的資料模型依據。
- 不適合直接套用到含有資料的既有資料庫，因為檔案會刪除 `public` 與 `migration` schema 及其中全部資料。
- 不能代替 API、認證授權、資料轉換、初始資料匯入與版本升級機制。
- 現階段前台及後台仍主要依賴 `data/**/*.json`、`js/api-mock.js` 與瀏覽器儲存空間；即使資料庫成功建立，畫面也不會自動改讀 PostgreSQL。

綜合評估：

> `latest_schema.sql` 的「資料結構可用度」高，但「全專案直接接入可用度」低。應把它視為後端實作的起點，而不是已完成的資料庫版本網站。

## 2. 評估範圍與現況

本報告以目前 repository 中實際存在的檔案為準，主要檢查：

- `docs/latest_schema.sql`
- `docker-compose.yml`
- `backend/pom.xml`
- `backend/src/main/resources/application.properties`
- `backend/src/main/java/com/yuruicamp/backend/BackendApplication.java`
- `js/api-mock.js`、`js/data-paths.js` 與頁面資料讀取流程
- `admin/js/admin-api.js` 與各後台模組
- `data/**/*.json`
- `admin/scripts/*.cjs`

目前舊的 `docs/schema.sql`、`docs/schema_copy.sql`、Flyway migration 目錄及多數舊驗證工具已不存在於工作目錄。本報告因此評估的是目前採用 `latest_schema.sql` 初始化的方案，不把已刪除的 Flyway 流程視為現行能力。

## 3. `latest_schema.sql` 已具備的能力

### 3.1 結構規模

靜態盤點結果：

| 物件 | 數量 |
| --- | ---: |
| 資料表 | 62 |
| View | 12 |
| ENUM type | 16 |
| Function | 9 |
| Trigger | 16 |
| 一般與唯一索引 | 100 |
| `ADD CONSTRAINT` 約束 | 45 |
| Seed `INSERT` 或 `COPY` | 0 |

這表示檔案包含相當完整的 PostgreSQL DDL，但完全不包含業務初始資料。

### 3.2 業務領域涵蓋度

Schema 已涵蓋目前專案的主要領域：

| 領域 | 主要資料表或 View | 評估 |
| --- | --- | --- |
| 客戶與會員 | `customers`、地址、偏好、標籤、`active_customers` | 結構可用 |
| 管理員 | `admin_users` | 結構可用，但未完成登入 API |
| 商品目錄 | `equipment_items`、分類、品牌、圖片、規格、`products`、`product_variants` | 結構可用 |
| 商品庫存 | `inventory_locations`、`inventory_stocks`、最低庫存、保留帳 | 結構可用 |
| 租借品 | `rental_skus`、variants、營區庫存、listings、保留帳 | 結構可用 |
| 營區 | `campgrounds`、zones、環境與設施標籤、關閉與封鎖日期 | 結構可用 |
| 預約 | `bookings`、選擇營位、租借品、狀態歷程、政策 | 結構可用 |
| 訂單 | `orders`、items、狀態與事件歷程 | 結構可用 |
| 優惠券 | `coupons`、claims、order coupons、統計 View | 結構可用 |
| 評論 | `reviews`、photos、`review_dto_view` | 結構可用 |
| 文章 | `articles`、content blocks、tags、related products、DTO View | 結構可用 |
| 庫存異動 | movement header、商售與租借明細、conversion、DTO View | 結構可用 |

從領域範圍看，這份 schema 足以作為整個專案後端資料模型的主幹。

### 3.3 已封裝的資料庫規則

Schema 不只是資料表，還包含部分重要規則：

- `get_zone_availability(...)`：計算營位日期區間的可用數量。
- `soft_delete_customer(...)`：客戶軟刪除。
- `suspend_customer(...)` 與 `reactivate_customer(...)`：會員狀態操作。
- 客戶 hard delete 防護 Trigger。
- 優惠券 claim 容量配置與同步 Trigger。
- 商品目錄子表異動時更新 equipment item 時間戳。
- 商品、品牌、分類等 updated time Trigger。
- 商品、租借、文章、評論與庫存異動 DTO View。

這些物件能降低後端重複查詢與部分資料一致性風險。不過後端仍應提供 transaction 邊界、輸入驗證、權限判斷與錯誤轉換，不能直接把資料庫 Function 或 View 暴露給瀏覽器。

## 4. 可直接運用的範圍

### 4.1 Docker 新建本機資料庫

`docker-compose.yml` 已將 `docs/latest_schema.sql` 掛載到 PostgreSQL 的 `/docker-entrypoint-initdb.d/001-schema.sql`。在全新的 named volume 第一次啟動時，PostgreSQL 會執行它。

因此以下用途成立：

- 新進開發者建立一致的空資料庫。
- 重建可丟棄的本機開發資料庫。
- 建立 CI 或 integration test 的暫存資料庫。
- 驗證後端 mapping 是否符合最新結構。

限制是 PostgreSQL init script 只會在資料目錄第一次初始化時執行。單純重新啟動 container 不會重新套用 schema。

### 4.2 Spring Boot 連線與 mapping 驗證

`application.properties` 已設定：

- 由 `DB_URL`、`DB_USERNAME`、`DB_PASSWORD` 取得連線。
- `spring.jpa.hibernate.ddl-auto=validate`。
- 註明資料庫必須先由 `docs/latest_schema.sql` 初始化。

這個方向適合作為 database-first 專案：Hibernate 只驗證 Entity mapping，不負責建立或修改 schema。

但目前後端只有 Spring Boot 啟動類別，沒有任何 Entity。換句話說，現在的 `ddl-auto=validate` 幾乎沒有應用資料模型可以驗證。必須完成 Entity 後，這項設定才會真正發揮作用。

### 4.3 後端開發契約

可依下列順序建立後端：

1. 優先以 View 建立唯讀 DTO 查詢：商品、租借 listing、文章、評論及 movement。
2. 再建立 customers、orders、bookings、coupons 的寫入服務。
3. 最後建立庫存、保留帳、優惠券 claim 等需要 transaction 與併發控制的流程。

這樣可以先讓前端取得與現有 JSON 接近的 response shape，再逐步導入高風險寫入流程。

## 5. 目前不能直接運用於整個專案的原因

### 5.1 後端尚未實作

目前 `backend/src/main/java` 只有 `BackendApplication.java`，未找到：

- JPA Entity
- Repository
- Service
- REST Controller
- API DTO
- exception handler
- Security configuration
- 登入、session 或 token 流程
- seed/import service

因此資料庫即使建立成功，也沒有 `/api/**` 可以提供資料給前端。

### 5.2 前台仍由 JSON 與 Mock API 驅動

目前前台主要流程仍為：

```text
頁面 JavaScript
  → window.API / BookingAPI
  → js/api-mock.js 或直接 fetch DataPaths
  → data/**/*.json
  → localStorage / sessionStorage 儲存部分變更
```

例如商品、文章、分店、優惠券及部分會員流程仍會直接讀取 JSON。`latest_schema.sql` 不會改變這些程式碼，也不會自動把 SQL row 轉換成前端需要的巢狀物件。

### 5.3 後台預設停用真實 Backend

`admin/js/admin-api.js` 的預設值是：

```js
useBackend: false
```

因此後台目前仍優先使用 JSON cache 或瀏覽器端狀態。雖然檔案已定義 `/api/admin/customers`、orders、bookings、products、rentals、reviews 等預期 endpoint，但 Spring Boot 端沒有對應 Controller。

若直接改成 `useBackend: true`，請求會送出，但目前會得到不存在 endpoint 的錯誤。

### 5.4 Schema 沒有 Seed 資料

`latest_schema.sql` 中沒有 `INSERT INTO` 或 `COPY`。初始化後會得到 62 張空表，不會包含：

- 商品與 variant
- 營區與 zone
- 租借品
- 客戶
- 訂單與預約
- 文章、品牌及分店
- 優惠券
- 管理員帳號

因此必須另做可重複執行的 JSON-to-SQL importer 或正式 seed 機制。尤其管理員登入資料與密碼雜湊不能直接沿用不安全的前端假資料。

### 5.5 JSON 與關聯資料庫的資料形狀不同

目前 JSON 常以巢狀結構提供資料，例如：

- 商品內嵌 variants、圖片、規格與 branch stock。
- 營區內嵌 zones、tags 與設備。
- 訂單內嵌 items、status history 與 coupon snapshot。
- 預約內嵌 zones、rentals 與狀態資訊。

Schema 已將這些內容正規化成多張表。後端必須透過 query、View 或 DTO assembler 重建前端契約，不能直接回傳單張資料表。

### 5.6 缺少版本升級機制

目前 `latest_schema.sql` 明確採用完整重建模式，而且 repository 已沒有 Flyway migration 目錄。這代表：

- 新資料庫可以初始化。
- 既有資料庫無法安全地從版本 A 升級到版本 B。
- 無法追蹤每次正式 schema change 的順序與 checksum。
- 團隊成員若已有資料，只能手工修改或破壞性重建。

這對純 bootcamp 或可丟棄環境可以接受，但不適合保存正式資料的系統。

## 6. 主要風險

### 6.1 破壞性最高風險

檔案開頭會執行：

```sql
DROP SCHEMA IF EXISTS migration CASCADE;
DROP SCHEMA IF EXISTS public CASCADE;
```

因此它不是 fallback migration，也不是可重複安全套用的 update script。套用到任何含有資料的環境都會刪除全部應用資料。

建議：

- 只允許在空資料庫或明確可丟棄的環境執行。
- 執行工具必須要求明確環境名稱與二次確認。
- 正式環境資料庫帳號不應擁有任意 drop schema 的權限。

### 6.2 `psql` 相容性

檔案包含 `\restrict` 與 `\unrestrict`，它是 `pg_dump` 產生的 `psql` meta-command，不是一般 JDBC SQL。

因此：

- 適合由 PostgreSQL container init 或 `psql -f` 執行。
- 不應直接交給 Spring JDBC、Hibernate、一般 SQL migration runner 或逐句 SQL executor。

### 6.3 Schema 與後端漂移

目前沒有 migration checksum，也沒有 schema contract test。未來若直接手改 `latest_schema.sql`，既有資料庫與新建資料庫可能得到不同結構。

至少應加入：

- 在暫存資料庫執行整份 schema 的 CI。
- Entity mapping 啟動驗證。
- `information_schema` / `pg_catalog` 結構快照比較。
- 關鍵 Function、Trigger、View 的 smoke test。
- JSON importer 的筆數與外鍵驗證。

### 6.4 Business rule 分散

部分規則位於 Function 與 Trigger，部分未來會存在 Service。若沒有明確責任表，容易發生：

- 後端重複扣庫存，Trigger 又執行一次。
- 後端以為 hard delete 成功，但資料庫拒絕。
- 優惠券 claim 容量與訂單 transaction 不在同一責任邊界。
- 測試只覆蓋 Java，卻未覆蓋資料庫 Function。

每一條規則應標明由 DB、Backend 或兩者共同負責。

### 6.5 文件與 npm 指令漂移

目前 README 仍有 `docs/schema.sql` 等已不存在檔案的連結，`package.json` 也保留多個指向已刪除腳本的指令。這不會改變 schema 本身，但會讓開發者誤判現行初始化及驗證流程。

在正式採用 `latest_schema.sql` 前，必須同步整理 README、package scripts 與開發指引。

## 7. 建議的導入方案

### 階段 A：把 schema 固定成可驗證基線

目標：確認每次都能建立相同的空資料庫。

- 保留 `latest_schema.sql` 作為完整 snapshot。
- 在 disposable PostgreSQL 16 執行 `psql -f docs/latest_schema.sql`。
- 驗證 62 tables、12 views、16 types、9 functions、16 triggers 與 100 indexes。
- 執行關鍵 Function、Trigger 與 FK smoke test。
- 建立 schema checksum 或 canonical catalog 輸出。
- 修正 README 中舊 schema 路徑。

通過條件：全新資料庫可以自動建立，且結構驗證為固定結果。

### 階段 B：建立 Seed 與資料轉換

目標：將現有 JSON 轉成可供網站測試的 SQL 資料。

- 建立獨立 importer，不把 seed 混入完整 schema。
- 按 FK 順序匯入基礎資料、主檔、交易資料與歷程資料。
- 保留原始 ID，避免前端 URL、購物車與文章引用失效。
- 產生匯入筆數、拒絕資料、缺失 FK 與金額對帳報告。
- 匯入完成後比較 JSON 與 SQL DTO 的關鍵欄位。

通過條件：重要 JSON 資料全部有對應 SQL row，且關聯與總額驗證通過。

### 階段 C：先完成唯讀 Backend API

建議優先 endpoint：

- 商品列表與商品詳情
- 營區列表、營區詳情與 availability
- 租借 listing
- 文章列表與詳情
- 分店、品牌、評論與優惠券查詢

先以 DTO View 或 projection 對齊既有 JSON response shape，可降低前端修改量。

通過條件：同一筆資料由 Mock 與 Backend 回傳時，頁面需要的欄位名稱、型別及巢狀結構一致。

### 階段 D：完成寫入與 transaction

依風險由低至高導入：

1. 會員資料、地址與偏好。
2. 評論與文章管理。
3. 商品及租借目錄管理。
4. 訂單與預約。
5. 商品與租借庫存保留。
6. 優惠券 claim 與付款狀態。

所有寫入流程應具備 transaction、權限、輸入驗證、重複請求處理與衝突回應。

### 階段 E：切換前端與後台

- 為 Mock API 與 Backend API 建立明確環境設定。
- 先讓讀取走 Backend，寫入維持受控測試。
- 後台 `AdminAPI.useBackend` 由環境設定控制，不在程式碼中手動切換。
- 移除頁面直接讀取 `DataPaths` 的旁路，避免同一頁混用 DB 與 JSON。
- 驗證登入、會員中心、購物車、結帳、預約及後台 CRUD。

通過條件：網站在 Backend 模式下不再依賴業務 JSON 或 localStorage 作為權威資料源。

### 階段 F：補上升級策略

若資料需要長期保存，建議恢復 migration 工具。可採用 Flyway，但不要求把完整 snapshot 拆回所有歷史版本：

- 將目前 `latest_schema.sql` 定為新系統 baseline snapshot。
- 後續每一項變更新增不可改寫的 versioned migration。
- `latest_schema.sql` 由已套用 migration 的乾淨資料庫重新 dump，而不是手工各自修改兩份 DDL。
- CI 比較「baseline 加全部 migration」與「最新 snapshot」的結構等價性。

如果專案明確只用於可重建 demo，則可不導入 migration，但必須承認資料不可保證升級保存。

## 8. Fallback 定位

檔名雖為 `databaseFallback.md`，但 `latest_schema.sql` 本身不應被定義成正式環境 rollback 或 fallback 工具。

它適合的 fallback 情境：

- 本機資料庫損壞後，刪除 disposable volume 並重建空資料庫。
- CI 測試資料庫每次從零建立。
- Demo 環境可接受清空後重新 seed。

它不適合的 fallback 情境：

- 正式資料庫故障後保留既有資料回復。
- 新版本部署失敗後回到舊 schema。
- 在不停止寫入的情況下切換版本。
- 直接取代 database backup。

正式環境 fallback 必須依賴 PostgreSQL backup / restore、PITR、版本化 migration 與經過演練的 rollback/runbook。

## 9. 最終判定

| 問題 | 判定 |
| --- | --- |
| 能否建立完整空資料庫結構 | 可以 |
| 能否用於 Docker 第一次初始化 | 可以 |
| 能否作為後端 Entity 與 API 開發基準 | 可以 |
| 能否直接讓現有網站改讀 PostgreSQL | 不可以 |
| 能否自動匯入現有 JSON | 不可以 |
| 能否直接套用到有資料的既有 DB | 不可以，會清除資料 |
| 能否取代版本化 migration | 不建議 |
| 能否作為正式 rollback / backup | 不可以 |
| 完成 Backend、Seed、API 與切換後能否支撐全專案 | 可以 |

最終建議為「**採用 schema，暫不切換 runtime**」：先保留 `latest_schema.sql` 作為乾淨資料庫基線，完成自動驗證與 seed/importer，再實作後端 API，最後才逐頁把 JSON mock runtime 切換到 PostgreSQL。若跳過中間層，資料庫雖然存在，整個專案仍不會真正使用它。
