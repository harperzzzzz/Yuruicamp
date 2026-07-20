# 請先讀取:
- /plans/java-backend-architecture-proposal.md 
- /docs/api/README.md
- /backend/README.md
- /docs/api/order-api-contract.md
- /plans/backend-implementation-checklist.md

# 限制條件:
- 執行完任務將所有相關文件更新。
- 根目錄的README.md 也要更新。
- 所有任務新增的程式都要加上中文註解用簡單易懂的方式說明程式功能。
- 任務新增的有關後端的程式流程、用途的說明要簡單易懂不要長篇大論，都要在docs/backend-specs 創建或新增到相關的文件進行記錄和更新，格式參考/backend/README.md，文件命名和歸類依照後端分類的架構區分。
- 不要產生因為錯誤紀錄的log 檔案。
- 程式的排版使用以下條件完成:
    - 註解必須單獨一行，不要跟宣告擠在一起。
    - 流式 API（Stream / Functional）的斷行，在點記號（.）前斷行並縮排。
    - 成員變數與方法之間：一定要空一行。
    - 方法與方法之間：一定要空一行。
    - 方法內部的邏輯區塊：用一個空行隔開「參數驗證」、「業務邏輯」、「回傳結果」。