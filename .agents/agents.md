請先讀取：
- docs/ai-style-sheet.md
- docs/ai-style-tokens.css
- css/components/content/pages/_product-detail.scss
- css/components/content/pages/_header.scss
- css/components/content/pages/_member-center.scss
- css/components/content/pages/_home.scss
- pages/product-detail.html
- pages/member-center.html

## 任務目標:
修改網頁CSS 細節，不更動html, js檔案。

## 問題現象：
* product-detail.html 的div.productTabsNav 右側有捲動視窗清除掉。
* member-center.partial 的header 的logo 文字不要套用@font-face樣式
* member-center.partial 的button.floating-top-btn 背景色更改為background: var(--yui-orange); width=48px height=48px

## 預期結果：
* member-center.partial 的header 與其他頁面外觀一致
* member-center.partial 的button.floating-top-btn 與其他頁面外觀一致

## 技術限制：
- 保留現有 Vite 專案結構。
- 使用目前的 HTML、SCSS、JavaScript 架構。
- 遵守 ITCSS 分層架構。
- 不可修改與此任務無關的檔案。
- 不可新增未定義的新色碼、字體、間距系統。
- 不可自行增加 docs/frontend-specs 中沒有的功能。
- 所有互動需可由鍵盤操作。
- 手機版寬度 375px 不可水平捲動。
- 不可使用 inline style。
- 不可使用 !important。
- 所有class 和id 命名都要使用駝峰式命名法，且都要語意化。
- CSS/HTML/JS 函式都要添加註解並使用中文
- 將更新的程式內容簡述到根目錄的README.md。

## 驗收方式：
不可有元件功能失去效力。
