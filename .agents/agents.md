請先讀取：
* `docs/ai-style-sheet.md`
* `components/header.partial`
* `css/widgets/_drawer.scss`
* `css/components/_auth-modal.scss`

## 任務目標:
- div#loginModal 的button.btnGoogleLogin、button.btnFacebookLogin、button.btnLineLogin 三個按鈕之間要留有空格。
- 變更成右側滑動視窗
- button.siteMenuButton 點擊後不要跳轉到視窗最上方
- button.siteCartButton 點擊後不要跳轉到視窗最上方

## 問題現象：
#loginModal 現在是從視窗正中間顯示，變更為右側滑動視窗

## 預期結果：
#loginModal 從右側往左側滑動顯示，高度放大至視窗高度，button.btnFacebookLogin background-color 改成淺藍色，button.btnLineLogin background-color 改成--yui-success
button.siteMenuButton 彈出視窗方式不變，但是視窗畫面停留在原地
button.siteCartButton 彈出視窗方式不變，但是視窗畫面停留在原地

## 技術限制：
- 保留現有 Vite 專案結構。
- 使用目前的 HTML、SCSS、JavaScript 架構。
- 遵守 ITCSS 分層架構。
- 不可修改與此任務無關的檔案。
- 不可新增未定義的新色碼、字體、間距系統。
- 不可自行增加 docs/frontend-specs 中沒有的功能。
- 不要強制用疊加CSS 的手法去修改樣式。
- 所有互動需可由鍵盤操作。
- 手機版寬度 375px 不可水平捲動。
- 不可使用 inline style。
- 不可使用 !important。
- 所有class 和id 命名都要使用駝峰式命名法，且都要語意化。
- CSS/HTML/JS 函式都要添加說明那個函式是在做什麼的的註解使用中文
- 將更新的程式內容簡述到根目錄的README.md。
- 不要更動js 檔案

## 驗收方式：

