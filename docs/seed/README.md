# 開發 Seed 指南

本目錄只放 PostgreSQL 的「本機開發展示資料」。資料表結構以 [`../latest_schema.sql`](../latest_schema.sql) 為唯一真相；測試案例應自行建立並清除測試資料，不依賴本目錄。

| 欄位 | 內容 |
|------|------|
| **目前定位** | PostgreSQL 本機開發展示資料的結構、載入與維護規格 |
| **更新日期** | 2026-07-21 |
| **前端 Mock 規格** | [`../../plans/data-integration-spec.md`](../../plans/data-integration-spec.md) |

> **簡單說**：本文件回答「資料怎麼灌進 PostgreSQL」；[`data-integration-spec.md`](../../plans/data-integration-spec.md) 回答「前端 Mock JSON 怎麼維持一致」。兩者可以共用固定 ID 與業務語意，但不是同一份資料來源，也不會自動同步。

## 文件邊界與閱讀路徑

| 要處理的事情 | 先讀哪裡 |
|-------------|-----------|
| 修改資料表、ENUM、FK、CHECK | [`../latest_schema.sql`](../latest_schema.sql) |
| 確認 API Request／Response 欄位 | [`../api/README.md`](../api/README.md) 與對應 API Contract |
| 修改前端 Mock JSON 或衍生資料 | [`data-integration-spec.md`](../../plans/data-integration-spec.md) |
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
    ├── 010-reference.sql  # 商品分類、品牌
    ├── 030-catalog.sql    # equipment、products、variants、images、tags
    └── 040-inventory.sql  # 開發庫位與 V001 庫存
```

`002-dev-seed.sql` 依外鍵順序載入片段，並以單一交易包住整批資料。任何一個片段失敗時，PostgreSQL 會停止並回滾，不應直接把片段當作正式入口。

目前保留的編號為：`020-identity.sql`、`050-coupons.sql`、`060-orders.sql`、`070-bookings.sql`。只有真正需要該領域的固定展示資料時才建立檔案，建立後也要加入入口檔；不要預先建立空檔。

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

> 注意：重跑 seed 會把 `DEV-STORE-MAIN` 的 `V001` 現有庫存更新為 `10`。不要在需要保留手動測試庫存狀態時重跑。`docker compose down -v` 會刪除整個本機資料卷，只能在確定資料可捨棄時使用。

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
