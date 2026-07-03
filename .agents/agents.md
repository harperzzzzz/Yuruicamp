請先讀取：
- `pages/member-center.html`
- `booking/pages/member-center.html`
- `css/pages/_member-center.scss`
- `booking/css/member-center-main.scss`
- `booking/css/pages/_member-center.scss`
- `booking/css/member-center-main.css`
- 相關 JS：`js/pages/member-center.js`、`booking/js/member-center.js`

## 任務目標:
將booking 會員中心樣式整合到主站

## 問題解決流程:
1. 決定唯一樣式來源  
   建議主站成為唯一來源：
   - 主站入口：`css/main.scss`
   - 主站 partial：`css/pages/_member-center.scss`
   - Booking 不再有 `member-center-main.scss`
   - Booking 不再有 `booking/css/pages/_member-center.scss`

2. 比對兩份會員中心樣式  
   將：
   - `booking/css/pages/_member-center.scss`
   - `css/pages/_member-center.scss`

   做 diff，分辨：
   - 主站已經有的樣式
   - booking 版本才有但仍需要的會員中心樣式
   - booking 專屬 header/footer 或預約流程樣式，這些不要搬進主站 member-center

3. 合併到主站 partial  
   把必要會員中心樣式合併進：

   ```text
   css/pages/_member-center.scss
   ```

   原則：
   - 用 `.memberCenterPage` 作為頁面根 class 限定。
   - token 優先用主站 `--yui-*`。
   - 不把 booking `--yc-*` / `--bk-*` 依賴帶進主站，除非本來就是共用 token。
   - 不搬 booking header/footer/drawer/toast 這類預約子系統元件樣式。

4. 調整 HTML 載入  
   `booking/pages/member-center.html` 如果保留，應改成載入主站 CSS，而不是：

   ```html
   <link rel="stylesheet" href="../css/member-center-main.css">
   ```

   改成主站已建置/現有 CSS 載入方式，例如載入主站 `css/main.css` 或跟 `pages/member-center.html` 對齊。

5. 調整 JS 依賴  
   如果 booking 的 member center JS 只是複製主站功能，應統一使用主站 JS：
   - 優先保留 `js/pages/member-center.js`
   - 移除或停止載入 `booking/js/member-center.js`
   - 確認 selector 都是 camelCase 且和主站 HTML 一致

6. 移除 booking 會員中心樣式入口  
   確認沒有 HTML 還引用後，刪除：
   - `booking/css/member-center-main.scss`
   - `booking/css/member-center-main.css`
   - `booking/css/pages/_member-center.scss`

   並從任何 aggregator 移除 `@use 'pages/member-center'` 或 `@use 'components/...` 中只為會員中心存在的載入。

7. 更新 scripts/docs  
   更新：
   - `README.md`
   - `docs/itcss-architecture.md`
   - `plans/booking-itcss-scss-plan.md`
   - `package.json` 的 `format` 範圍如果有寫死 booking CSS 輸出


## 預期結果：
如果 `booking/pages/member-center.html` 只是歷史路徑，最好最後改成 redirect/link 到 `pages/member-center.html`，而不是維護兩個會員中心頁。這樣樣式、JS、HTML 都能少一份分叉。


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
- CSS/HTML/JS 函式都要添加說明那個函式是在做什麼的的註解使用中文
- 將更新的程式內容簡述到根目錄的README.md。

## 驗收方式：
- Sass 編譯主站 `css/main.scss -> css/main.css`
- booking Sass 編譯 `booking-main.scss -> booking-main.css`
- `npm run stylelint`
- `npm run format` 只需針對有更動的範圍
- `npm run build`
- 瀏覽器檢查 `pages/member-center.html` 和 `booking/pages/member-center.html`，375/768/1024/1440 無水平捲動、互動可用、focus-visible 可見
