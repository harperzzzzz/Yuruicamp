# 請先讀取:
- README.md
- \docs\seed\README.md
- \docs\latest_schema.sql
- \plans\frontend-folder-migration-spec.md
- \plans\frontend-root-absolute-path-and-api-contract-spec.md

# 任務目標:

# 限制條件:
- 如果在cmd 和powershell 有受到中文影響播壞了程式，那就不要將那條程序完成避免破壞專案。
- 執行完任務將所有相關文件更新。
- 根目錄的README.md 也要更新。
- 所有任務新增的程式都要加上中文註解用簡單易懂的方式說明程式功能。
- 不要產生因為錯誤紀錄的log 檔案。
- 程式的排版使用以下條件完成:
    - 註解必須單獨一行，不要跟宣告擠在一起。
    - 流式 API（Stream / Functional）的斷行，在點記號（.）前斷行並縮排。
    - 成員變數與方法之間：一定要空一行。
    - 方法與方法之間：一定要空一行。
    - 方法內部的邏輯區塊：用一個空行隔開「參數驗證」、「業務邏輯」、「回傳結果」。
- 不要破壞frontend 文件層架構，嚴格遵守
- spring boot 使用現有的依賴和套件不要新增其他的
- frontend/data/* 同步都要依/docs/seed/* 的資料為準去同步。
- 所有文件敘述都用/docs/seed/README.md 的方式去參考。
- 所有前端行為都要以後端為主。

# 預期目標:
- 嚴格遵守限制條件完成任務
