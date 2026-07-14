# docs/schema_copy.sql and schema.sql
* schema.sql 舊版資料庫的定版，不再修改
* schema_copy.sql 最終要代表完成 P1～P7 後的新資料庫完整結構


## admin/scripts/lib
* admin/scripts/lib/data-contracts.cjs
    - 4 個資料驗證／修復腳本共用的函式庫
    - validate-data-fk.cjs
    - sync-rental-listings.cjs
    - fix-articles-product-ids.cjs
    - normalize-phase1-data.cjs
    - 資料驗證腳本正式退役，或先把共用函式合併進各腳本後，才可以封存。



## admin/scripts
* `audit-p0-completion` P0 最終總驗收
* `generate-p0-baseline` 把 P0 當下的資料現況保存
* `generate-p0-target-dictionary` 產生「新資料庫目標結構的機器可讀規格」
* `generate-p1-backfill` 把現有 JSON 主檔轉成 P1 的 SQL 回填 migration。
* `generate-p2-backfill` 負責 P2 商品目錄、裝備資訊與販售庫存的 SQL 回填。
* `normalize-phase1-data` 「JSON 格式正規化工具」
* `sync-rental-listings` 同步「租借庫存權威資料」與「前台商品列表」
* `validate-data-fk` JSON 假資料的完整外鍵與資料契約驗證器
-------- 以上可移到 tools/database-archive/ --------

* `fix-articles-product-ids.cjs` 修正文章 JSON 裡「舊格式的商品 ID」
* `generate-p3-backfill.cjs` 把「租借裝備」的 JSON 假資料轉成 P3 的 Flyway 回填 migration。
* `generate-p4-backfill.cjs` 將舊 JSON 的「訂單、優惠券、預約」資料轉成交易領域的 migration
* `generate-p4-financial-report.cjs` P4 的財務對帳報告
* `generate-p5-backfill.cjs` P5 處理「預約政策、庫存最低量、庫存異動」
* `generate-p6-backfill.cjs` P6 處理評論與文章資料
* `validate-p5-availability.cjs` 「前後端規則一致性」測試


## docs/database/baseline/
* `p0-baseline.json` 紀錄就的快照資料，以核對重構完的json 檔案一致性
* `p0-completion-audit.json` 紀錄P0 驗收階段
* docs/database/baseline/ 用來證明資料庫與遷移前狀態。
    - 用完封存到 docs/archive/database-baseline/
    - 不再需要稽核時，才可連同相關腳本與文件引用一起移除。



## docs/database/validation/  (migration 一旦曾經在任何環境執行過，就必須永久保留，而且不能修改內容)
* docs/database/validation/ 「可重跑的驗證工具」
    - [p0-schema-inventory.sql] 查詢目前 PostgreSQL 的表、欄位、ENUM、PK/FK、CHECK、UNIQUE、索引與 FK 的 ON DELETE/ON UPDATE，輸出 JSON 結構清單。
    - [p0-business-baseline.sql] 檢查訂單／預約金額、負庫存、孤兒 FK、租借庫位映射等業務資料差異，輸出每筆問題的 ID、欄位、原因與處置狀態。
    - 在 P7 完成、驗證流程正式移交並建立版本封存後，將它們移到 docs/archive/database-validation/



## docs/database/
* docs/database/p0-*.json
    - [p0-json-sql-mapping.json]記錄各個 JSON 資料檔要遷移到哪些目標表，以及轉換規則。主要是遷移設計文件。
    - [p0-migration-allocation.json] 記錄 P1–P7 每個階段負責哪些資料庫物件。audit:p0 會直接讀它；刪除後稽核會失敗。
    - [p0-target-dictionary.json] 71 個目標物件的正式欄位字典，包含欄位、型別、PK/FK、約束、索引、刪除策略與驗證規則。audit:p0 和字典產生器都會直接讀它，是最重要的一份。
    - P7 完成後：可將前兩份移到 docs/archive/database/
    - p0-target-dictionary.json 建議長期保留


## backend/src/main/resources/application.properties
* `spring.application.name` 設定 Spring Boot application 的名稱

* 資料庫連線設定
* `spring.datasource.url=${DB_URL}`
* `spring.datasource.username=${DB_USERNAME}`
* `spring.datasource.password=${DB_PASSWORD}` 

* Flyway 設定
* `spring.flyway.enabled` 啟用 Flyway
* `spring.flyway.locations` migration 檔案位置
* `spring.flyway.default-schema` 預設 schema
* `spring.flyway.schemas` 設定同時管理的migration
* `spring.flyway.validate-on-migrate` 執行前驗證 migration
* `spring.flyway.validate-migration-naming` 驗證命名格式
* `spring.flyway.baseline-on-migrat` 是否啟動自動 baseline
* `spring.flyway.clean-disabled` 禁止 clean
* `spring.flyway.fail-on-missing-locations` migration 位置不存在就失敗
* `spring.flyway.out-of-order` 不允許 out-of-order (表示 migration 只能照版本順序執行)
* `spring.flyway.execute-in-transaction` 每個 migration 在 transaction 裡執行

* Hibernate 設定
* `spring.jpa.hibernate.ddl-auto` 設定默認模式

* 新舊資料模型切換，控制後端讀哪個模型、是否繼續寫入舊模型。
* `database.migration.p7.read-new` 讀取p7 verion 的資料模型，false 切回就模型
* `database.migration.p7.write-legacy` 新寫入同時保留舊模型，發現問題時可以切回舊模型。

### flyway 的大致作用
* `migration` 升級資料庫版本，保持自最新
* `validate` 依照migration, checksum, 版本, 失敗紀錄進行偵錯，避免資料庫不正常修改
* `info` 列出資料庫狀態
* `clean` 刪除schema, 整個資料庫
* 資料庫管理，紀錄版本追蹤。

## docs/database/validation/  migration 驗收、測試
### 類型
* `*-structure.sql` 表、欄位、PK、FK、UNIQUE、CHECK、Index、Trigger、View 是否正確
* `*-data.sql` 回填後資料是否完整、無孤兒、金額／數量／對應關係是否正確
* `*-compatibility.sql` 舊 API／DTO／前端仍需要的相容輸出是否正確
* `*-business-rules.sql` 實際 SQL 測試正向與負向業務情境

### P0 (紀錄需要解決的問題，提供後續版本參考)
* `p0-schema-inventory.sql` 將舊schema.sql 轉換成可讀的json
* `p0-business-baseline.sql` 紀錄舊資料問題

### P1 主檔、會員、地點
* `p1-structure.sql` 驗證主檔、會員、地點主檔結構
* `p1-data.sql` 驗證資料筆數、建立location mapping (新舊對照)
* `p1-compatibility.sql` 驗證舊資料、路徑是否可對應主檔
* `p1-business-rules.sql` 設定並測試業務規則

### P2 商品目錄與販售庫存
* `p2-structure.sql` 驗證裝備資料結構與索引
* `p2-data.sql` 驗證裝備資料筆數
* `p2-compatibility.sql` 驗證舊資料、路徑是否可對應主檔
* `p2-business-rules.sql` 設定並測試業務規則

### P3 租借 SKU、租借庫存、營地租借清單
* `p3-structure.sql`
* `p3-data.sql`
* `p3-compatibility.sql`
* `p3-business-rules.sql`

### P4 訂單、優惠券、預約、交易歷程
* `p4-structure.sql`
* `p4-data.sql`
* `p4-compatibility.sql`
* `p4-business-rules.sql`
* `p4-financials.sql` 獨立檢查訂單與預約的金額公式、折扣、租借與營位加總

### P5 預約政策、可用性、庫存異動
* `p5-structure.sql`
* `p5-data.sql`
* `p5-compatibility.sql`
* `p5-business-rules.sql`

### P6 評論與文章
* `p6-structure.sql`
* `p6-data.sql`
* `p6-compatibility.sql`
* `p6-business-rules.sql`

### P7 全域最終驗收
* `validate_schema.sql` 全域 Schema 驗收
* `validate_seed.sql` 整合 P1～P6 的 data.sql
* `validate_business.sql` 整合 P1～P6 的 business rule 測試
* `validate_contract.sql` 整合 P1～P6 compatibility
* `validate_inventory.sql` 整合 P5 資料與業務規則
* `validate_financials.sql` 執行 P4 財務驗證
* `validate_performance.sql` 用 EXPLAIN ANALYZE 檢查關鍵查詢速度 (EXPLAIN ANALYZE 檢查一段 SQL 效能)
* `p7-canonical-catalog.sql` 將資料庫的表、欄位、constraint、Index、ENUM、Trigger 輸出成可比較的結構
* `p7-canonical-data.sql` 對重要資料做邏輯內容核對
* `p7-exact-data.sql` 做備份／還原用的嚴格核對
