分析與任務有關的所有js 檔案並找出問題，給予解決步驟，不修改任何程式碼。

## 分析目標
* button.siteLoginButton 在login 後要隱藏，logout 後要顯示
* div.siteUserMenu 不是預設隱藏，點擊button.siteUserTrigger 才顯示
* form.siteSearchForm 預設隱藏，點擊button.siteSearchToggle 才顯示
* button.floating-top-btn 要套用圓形並且設置在網頁右側的樣式，參考在member-center 時的樣式
* floatingLineBtn 也要要套用圓形並且設置在網頁右側的樣式


## 技術限制：
- 保留現有 Vite 專案結構。
- 使用目前的 HTML、SCSS、JavaScript 架構。
- 遵守 ITCSS 分層。
- 不可修改與此任務無關的檔案。
- 不可新增未定義的新色碼、字體、間距系統。
- 不可自行增加 docs/frontend-specs 中沒有的功能。
- 所有互動需可由鍵盤操作。
- 手機版寬度 375px 不可水平捲動。
- 不可使用 inline style。
- 不可使用 !important。
- 所有class 和id 命名都要使用駝峰式命名法，且都要語意化。
- CSS、SCSS 同一個元件功能的區塊要用「中文」註解標註功能及套用在哪個元件。
- HTML 每個元件區塊都要用「中文」註解標註功能。
- Javascript 每個函式都要「中文」註解功能及套用在哪個元件。
- 將更新的程式內容簡述到根目錄的README.md。

## 完成輸出：
