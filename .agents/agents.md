請先讀取：
- `docs/ai-style-sheet.md`
- `docs/ai-style-tokens.css`
- `booking/booking-style-tokens.md`
- booking/css/ 下的所有檔案
- css/ 下的所有檔案


## 任務目標:
整合booking/booking-style-tokens.md 和docs/ai-style-sheet.md, docs/ai-style-tokens.md 的規範，顏色、間距、圓角、陰影、z-index、motion 以booking 為主。
整合完通過完整的style 規範將樣式套用到booking/css 和主站的css 統一兩邊網站的樣式。 

## 問題解決流程:
1. 文件層先統合把 docs/ai-style-tokens.css 的有效內容合併進 booking-style-tokens.md，但 token 名稱改成 --yc-*。
例如：
--yui-space-4 對應 --yc-space-4
--yui-radius-lg 對應 --yc-radius-button 或 --yc-radius-card
--yui-shadow-md 對應 --yc-shadow-soft
--yui-z-modal 對應 --yc-z-modal

2. 保留 alias，不直接刪主站 CSS 還大量使用 --yui-*，所以短期不能刪。
應該改成：
--yui-primary: var(--yc-sage-action);
--yui-bg: var(--yc-bg);
--yui-surface: var(--yc-surface);

3. runtime 層分階段，每一階段都要使用$pre-review-checklist 驗證結果。
第一階段只讓 css/settings/_tokens.scss 和 booking/css/settings/_tokens.scss 都有同一套 --yc-*。
第二階段再把主站 css/**/*.scss 從 --yui-* 逐步改成 --yc-*。
第三階段才考慮移除 docs/ai-style-tokens.css 或改成 alias 文件。

## 預期結果：
booking-style-tokens.md
  ↓ 作為唯一設計規格
css/settings/_tokens.scss
  ↓ 定義 --yc-*，並輸出 --yui-* alias
booking/css/settings/_tokens.scss
  ↓ 定義 --yc-*，並輸出 --yui-* / --bk-* alias
主站與 booking CSS
  ↓ 新程式使用 --yc-*，舊程式可暫時使用 alias

## 技術限制：
- 保留現有 Vite 專案結構。
- 使用目前的 HTML、SCSS、JavaScript 架構。
- 遵守 `docs/itcss-architecture.md` 架構規範的架構。
- 不可修改與此任務無關的檔案。
- 不可新增未定義的新色碼、字體、間距系統。
- 不可自行增加 `docs/frontend-specs/` 中沒有的功能。
- 不要強制用疊加CSS 的手法去修改樣式。
- 所有互動需可由鍵盤操作。
- 手機版寬度 375px 不可水平捲動。
- 不可使用 inline style。
- 不可使用 !important。
- 所有class 和id 命名都要使用駝峰式命名法，且都要語意化。
- 將更新的程式內容簡述到根目錄的README.md。

## 驗收方式：
- 實際跑過booking/pages 和pages/ 裡面的網站測試是否每個功能正常運行，且pages/ 的樣式與booking 樣式統一。
