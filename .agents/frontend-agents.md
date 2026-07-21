# 請先讀取:
- /plans/data-integration-spec.md
- /backend/README.md
- /docs/api/README.md
- /docs/seed/README.md
- README.md
- \plans\backend-implementation-checklist.md
- \plans\frontend-folder-migration-spec.md
- \plans\frontend-root-absolute-path-and-api-contract-spec.md


# 限制條件:
- 執行完任務將所有相關文件更新。
- 根目錄的README.md 也要更新。
- 所有任務新增的程式都要加上中文註解用簡單易懂的方式說明程式功能。
- 任務新增的有關前端的程式流程、用途的說明要簡單易懂不要長篇大論，都要在docs/frontend-specs 創建或新增到相關的文件進行記錄和更新，格式參考/backend/README.md，文件命名和歸類依照後端分類的架構區分。
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
- 完成任務後，在/docs/frontend-specs/test/ 下建立一個給開發者手動在frontend 驗證的流程，簡單的說重點步驟就好，在文件結尾解說驗證的必要和原因，如果沒有實際完成的線程則不要建立test 文件，test 文件參考\docs\backend-specs\checkout\README.md 的### swagger 驗證流程格式去填寫。