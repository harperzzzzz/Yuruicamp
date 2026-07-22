# 開發 Seed 指南

本目錄只放 PostgreSQL 的「本機開發展示資料」。資料表結構以 [`../latest_schema.sql`](../latest_schema.sql) 為唯一真相；測試案例應自行建立並清除測試資料，不依賴本目錄。

| 欄位 | 內容 |
|------|------|
| **目前定位** | PostgreSQL 本機開發展示資料的結構、載入與維護規格 |
| **更新日期** | 2026-07-22 |
| **前端 Mock 規格** | [`../../plans/data-integration-spec.md`](../../plans/data-integration-spec.md) |
| **固定 ID 對照** | [`../data/json-seed-id-mapping.md`](../data/json-seed-id-mapping.md) |

> **簡單說**：本文件回答「資料怎麼灌進 PostgreSQL」；[`data-integration-spec.md`](../../plans/data-integration-spec.md) 回答「前端 Mock JSON 怎麼維持一致」。兩者可以共用固定 ID 與業務語意，但不是同一份資料來源，也不會自動同步。

跨 JSON／Seed 的商品、規格、品牌、營區、zone、標籤、門市與租借 SKU 身分，以 [`json-seed-id-mapping.md`](../data/json-seed-id-mapping.md) 為唯一對照。對照表只決定身分；實際欄位與限制仍以 Schema 為準。

## 文件邊界與閱讀路徑

| 要處理的事情 | 先讀哪裡 |
|-------------|-----------|
| 修改資料表、ENUM、FK、CHECK | [`../latest_schema.sql`](../latest_schema.sql) |
| 確認 API Request／Response 欄位 | [`../api/README.md`](../api/README.md) 與對應 API Contract |
| 修改前端 Mock JSON 或衍生資料 | [`data-integration-spec.md`](../../plans/data-integration-spec.md) |
| 確認 JSON／Seed 固定 ID | [`json-seed-id-mapping.md`](../data/json-seed-id-mapping.md) |
| 修改 PostgreSQL 開發展示資料或載入順序 | 本文件 |
| 建立整合測試專用資料 | `backend/src/test/**` 的對應測試 |

建議閱讀順序：

1. 先讀對應 API Contract，確認功能需要哪些資料。
2. 再讀 `latest_schema.sql`，確認實際欄位、ENUM 與外鍵順序。
3. 依本文件修改 `docs/seed/dev/*.sql` 與唯一入口。
4. 若前端 Mock 也要呈現同一案例，再依 `data-integration-spec.md` 個別更新 `frontend/data/**`。

## 給開發者

### 目前結構

```text
docs/seed/
├── README.md
├── 002-dev-seed.sql       # 唯一執行入口與交易邊界
└── dev/
    ├── 010-reference.sql  # 權限字典、角色預設、商品分類、品牌、營區、營位、Booking policy、日曆
    ├── 020-identity.sql   # 開發管理員與 Booking 公休範例
    ├── 021-admin-google-whitelist.example.sql  # 範例：本機把 Google email 加入白名單（不進 002 入口、勿提交真實 email）
    ├── 030-catalog.sql    # 商品與租借 SKU／variant
    ├── 040-inventory.sql  # 商城／租借庫位、listing 與庫存
    ├── 050-coupons.sql    # 優惠券主檔（claim 尚未建立）
    ├── 060-orders.sql     # 222 筆展示訂單、435 筆明細與歷程
    └── 070-bookings.sql   # 90 筆展示預訂、zone／租借快照與歷程
```

### 後台 Google 白名單（本機）

正式 seed 只含 `booking-seed@example.test`（給 Swagger／Dev Token）。  
真 Firebase Google 登入後台時，請依 [`dev/021-admin-google-whitelist.example.sql`](./dev/021-admin-google-whitelist.example.sql) **在本機**把你的 Google email 寫入 `admin_users`（不要把真實 email commit 進 git）。

`docker compose down -v` 會清空 volume：白名單與既有 `customers` 都會消失，需重新執行白名單 SQL，並請會員重新登入（重建 Firebase session）。  
後續業務診斷清單見 [`../../plans/post-firebase-roadmap-checklist.md`](../../plans/post-firebase-roadmap-checklist.md)。

`002-dev-seed.sql` 依外鍵順序載入片段，並以單一交易包住整批資料。任何一個片段失敗時，PostgreSQL 會停止並回滾，不應直接把片段當作正式入口。

`010-reference.sql` 目前包含 12 個前端公開品牌（另保留 `yuruicamp` 站內品牌）、8 個 active 營區 `C002`～`C009`、13 個 active zone `Z001`～`Z013`、5 個環境標籤、7 個設施標籤與 3 個門市。資料值與固定 ID 對齊 `frontend/data/catalog/campgrounds.json`、`frontend/data/marketing/brands.json`、`frontend/data/marketing/branches.json`；跨層 ID 仍以 [`json-seed-id-mapping.md`](../data/json-seed-id-mapping.md) 為準。

`030-catalog.sql` 已包含 28 個租借 SKU 與 37 個 canonical 租借規格。`040-inventory.sql` 已包含 C001～C009 的 9 個租借庫位、8 組營區對照、16 筆有明確前端定價的 listing，以及 37 規格 × 9 庫位的 333 筆實體庫存。沒有定價來源的 SKU 不會自行建立 listing；最低庫存仍待獨立搬移。

`020-identity.sql` 已包含固定會員 U001～U050；資料使用 `example.com` 與固定假電話，不含 Firebase UID。`050-coupons.sql` 已包含固定 ID 1～7 的 7 張優惠券，但目前沒有領券案例，因此不建立 `coupon_claims`，`claimed_quantity` 為 `0`。Seed 重跑只更新券主檔，不覆寫既有已領數。

`060-orders.sql` 已包含訂單 1～222、435 筆商品快照、431 筆狀態歷程與 607 筆舊付款／建立事件；商品 FK／SKU 已轉為 canonical variant。`070-bookings.sql` 已包含預訂 1～90、90 筆 zone、40 筆租借快照與 190 筆狀態歷程。這兩批展示交易刻意不建立庫存保留、庫存異動、評論或領券 claim；這些領域要等各自來源完成後再獨立搬移。

### 全新資料庫實灌結果（2026-07-22）

已使用獨立 PostgreSQL 16 容器與獨立暫存 volume，對空資料庫依序執行 `latest_schema.sql` 與 `002-dev-seed.sql`。初始化輸出包含同一批 Seed 的 `BEGIN` 與 `COMMIT`，沒有 `ERROR`／`FATAL`；另開資料庫連線後可讀到 `010`～`070` 的全部資料，證明交易已完整提交。

主要驗證筆數：

- Reference／Identity：13 品牌、8 個 active 營區、13 個 active zone、3 門市、50 會員。
- Catalog／Inventory：30 商品、39 商城規格、29 租借 SKU、38 租借規格、17 listing、334 筆租借庫存。租借總數包含 28／37／16／333 筆前端對照資料，以及各 1 筆既有開發驗收資料。
- Coupon／Order／Booking：7 優惠券、222 訂單、435 訂單明細、431 狀態歷程、607 事件、90 預訂、90 zone 快照、40 租借快照、190 預訂歷程。
- 訂單會員、訂單規格、預訂會員、營區、zone、租借 listing／variant 的孤兒檢查皆為 `0`；沒有連線停留在 `idle in transaction`。

可重做的隔離驗證流程見 [`../backend-specs/test/full-seed-fresh-database.md`](../backend-specs/test/full-seed-fresh-database.md)。驗證只使用專用容器與 volume，不會停止、重建或清除既有 `yuruicamp-db`。

### 執行方式

全新 Docker volume 在第一次 `docker compose up -d` 時會依序執行 schema 與開發 seed。若 volume 已存在，PostgreSQL 不會再次執行初始化腳本；更新 compose 掛載後，可手動執行：

```powershell
docker compose up -d
docker exec yuruicamp-db psql -U postgres -d yuruicamp -f /docker-entrypoint-initdb.d/002-dev-seed.sql
```

也可從 repository 根目錄使用本機 `psql`：

```powershell
psql -U postgres -d yuruicamp -f docs/seed/002-dev-seed.sql
```

入口已設定 `ON_ERROR_STOP`。若自訂了 `POSTGRES_USER` 或 `POSTGRES_DB`，請同步替換指令參數。

> 注意：重跑 seed 會以 reference 主檔覆寫同 ID 的品牌、營區、zone、標籤與門市欄位，並重建 C002～C009 的標籤關聯及 3 門市 features；舊 `C002-Z-A`、`C002-Z-HIDDEN` 只會改為 inactive，不會刪除。它也會覆寫 U001～U050、訂單 1～222、預訂 1～90 及其固定明細／歷程，覆寫 333 筆租借規格庫存、把 `DEV-STORE-MAIN` 的 `V001` 更新為 `10`，並在 `RENTAL-C002` 保留 `RSV-DEV-001` 的 `6` 件驗收庫存。優惠券主檔會更新，但既有 `claimed_quantity` 不會被重設。交易 Seed 不會刪除多出的人工明細，也不建立庫存保留。不要在需要保留同 ID 手動測試資料時重跑。`docker compose down -v` 會刪除整個本機資料卷，只能在確定資料可捨棄時使用。

### 維護規則

- `latest_schema.sql` 只放 DDL；展示資料只放在本目錄。
- 片段不可包含 `BEGIN`、`COMMIT` 或 `\set ON_ERROR_STOP`，交易與錯誤處理由入口統一管理。
- 檔名數字就是相依順序。新增片段後，必須明確加入 `002-dev-seed.sql`。
- 使用固定、可辨識的開發 ID；可重跑的寫入應使用適當的 `ON CONFLICT`。
- 不得放真實 email、電話、Token、密碼或其他個資。
- `frontend/data/**` 是前端 Mock 契約資料，不是 PostgreSQL seed 的真相來源。
- Mock JSON 與 SQL Seed 不會自動同步；需要共用案例時，兩邊都必須依各自契約驗證。
- 整合測試資料留在 `backend/src/test/**`，由測試自行建立與清理，避免測試互相污染。
- 商品 ID、variant 與價格異動時，同步更新 [`../data/product-catalog-seed-manifest.md`](../data/product-catalog-seed-manifest.md)。
- 完成修改後，至少驗證 compose 設定、入口引用檔案存在，並在可丟棄的空資料庫執行一次完整 schema + seed。

## 給 AI／Codex

修改本目錄前必須先閱讀本檔、[`../latest_schema.sql`](../latest_schema.sql) 與受影響領域的 API 契約。若需求來自前端 Mock，還必須閱讀 [`data-integration-spec.md`](../../plans/data-integration-spec.md)，先區分要同步的是業務案例還是 API 欄位。請遵守以下限制：

1. 不可從前端 JSON 猜測資料庫欄位、ENUM 或外鍵；一律以 `latest_schema.sql` 為準。
2. 不可把 seed 混入 schema，也不可把 dev seed 當成測試 fixture。
3. 保留 `002-dev-seed.sql` 作為唯一入口、唯一交易邊界；片段內不得自行開關交易。
4. 新增領域片段前先確認已有實際資料需求與外鍵依賴；沒有資料就只保留編號說明，不建立空檔。
5. 修改載入順序或新增片段時，同步更新入口、`docker-compose.yml`、本 README 及相關 manifest／後端文件。
6. 使用固定假資料，不得生成或提交真實憑證與個資；敏感值只能由環境變數提供。
7. 不可為了讓 seed 通過而放寬 schema 約束、改動正式業務規則，或把 Hibernate `ddl-auto` 改成 `update`。
8. 驗證時不得清除使用者既有資料卷。需要 fresh-init 測試時，使用獨立且可辨識的暫存資料庫／volume，並只清理該暫存資源。

AI 完成 seed 修改時，回報內容至少要包含：異動片段、載入順序、是否會覆寫既有開發資料、實際執行的驗證，以及未執行驗證的原因。
