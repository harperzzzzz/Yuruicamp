# 請先讀取:
- /plans/java-backend-architecture-proposal.md 
- /plans/data-integration-spec.md
- /docs/api/README.md
- /backend/README.md
- /docs/seed/README.md
- README.md
- \plans\backend-implementation-checklist.md
- \plans\frontend-folder-migration-spec.md
- \plans\frontend-root-absolute-path-and-api-contract-spec.md


# 限制條件:
- 執行完任務將所有相關文件更新。
- 根目錄的README.md 也要更新。
- 所有任務新增的程式都要加上中文註解用簡單易懂的方式說明程式功能。
- 任務新增的有關後端的程式流程、用途的說明寫清楚重點步驟的流程就好不要全部的原因都解說，都要在docs/backend-specs 創建或新增到相關的文件進行記錄和更新，格式參考/backend/README.md，文件命名和歸類依照後端分類的架構區分。
- 不要產生因為錯誤紀錄的log 檔案。
- 程式的排版使用以下條件完成:
    - 註解必須單獨一行，不要跟宣告擠在一起。
    - 流式 API（Stream / Functional）的斷行，在點記號（.）前斷行並縮排。
    - 成員變數與方法之間：一定要空一行。
    - 方法與方法之間：一定要空一行。
    - 方法內部的邏輯區塊：用一個空行隔開「參數驗證」、「業務邏輯」、「回傳結果」。
    - Controller 的每個端口都要用中文註解標註在做什麼功能，簡短描述就好。
- 不要破壞backend 文件層架構，嚴格遵守
- 不要破壞frontend 文件層架構，嚴格遵守
- 只使用spring boot 現有的依賴和套件不要新增其他的。
- 所有前端行為都要以後端為主。

- 有新增seed 資料的話遵守以下架構不要破壞。
docs/seed/
├── README.md
├── 002-dev-seed.sql          # 統一入口，只負責依序載入
└── dev/
    ├── 010-reference.sql     # 品牌、分類、分店、庫位等基礎資料
    ├── 020-identity.sql      # 開發會員、管理員
    ├── 030-catalog.sql       # equipment、products、variants、images
    ├── 040-inventory.sql     # inventory_stocks
    ├── 050-coupons.sql       # 優惠券展示資料
    ├── 060-orders.sql        # 可選：開發展示訂單
    └── 070-bookings.sql      # 可選：開發展示預約

- frontend/data/* 同步都要依/docs/seed/* 的資料為準去同步。
- 所有文件敘述都用/docs/seed/README.md 的方式去參考

# 預期目標:
- 嚴格遵守限制條件完成任務
- 完成任務後，後端在/docs/backend-specs/test/ 下建立一個給開發者手動在swagger 建立驗證的流程，前端在/docs/frontend-specs/test/ 下建立網頁的驗證流程，詳細說明步驟，在文件結尾解說驗證的必要和原因，如果沒有實際完成的線程則不要建立test 文件，test 文件參考以下格式。
    ### swagger 驗證流程

    測試前確認：

    - PostgreSQL 與後端已啟動。
    - `FIREBASE_ENABLED=false`。
    填入其他確認項目...

    #### 1. 建立開發會員並授權

    先執行：

    ```http
    POST /api/auth/firebase/session
    ```

    Request Body：

    ```json
    {
    "idToken": "dev:uid-c2:c2@example.com:google:C2Tester"
    }
    ```

    預期 HTTP 200，建立或取得開發會員。

    接著點 Swagger 右上角綠色 `Authorize` 按鈕，輸入：

    ```text
    dev:uid-c2:c2@example.com:google:C2Tester
    ```

    不需要自行加上 `Bearer`。

    #### 2. C-2：建立 Checkout

    執行：

    ```http
    POST /api/checkout/sessions
    ```

    每次建立新測試時遞增 `idempotencyKey`：

    ```json
        填入測試json
    ```

    預期：

    - HTTP 200。
    填入其他預期...

    回應範例：

    ```json
        填入回應json
    ```

    若回 HTTP 409 且 `error.code=STOCK_INSUFFICIENT`，表示 `V001` 沒有足夠的可用庫存，或有其他 Checkout 正在保留庫存。

    #### 3. C-2：驗證冪等重送

    ...
    
    #### 填入其他必要步驟...

    如果需要添加docker 或DBeaver 的指令
    - 開啟 DBeaver，連上 yuruicamp 資料庫。
    
    ```SQL or powershell
        填入必要的手動操作指令
    ```

    驗證：
    ```SQL or powershell
        填入必要的手動操作指令
    ```

    預期：
    - HTTP 409。
    填入其他預期...

    #### Swagger 驗收完成標準

    - 建立 Checkout：HTTP 200。
    填入其他標準...