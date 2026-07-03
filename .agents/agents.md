請先讀取：
* `docs/itcss-architecture.md`
* `booking/booking-style-tokens.md`
* booking/css/ 的所有檔案
* css/ 的所有檔案

## 任務目標:
將 [booking/css](/D:/githubdesk/Yuruicamp/booking/css) 從目前的 CSS `@import + @layer` 結構，漸進轉為與 [css](/D:/githubdesk/Yuruicamp/css) 相同的 SCSS ITCSS 架構，並保持現有 Vite、HTML、JS 載入方式可運作。

## 流程步驟:
1. 建立 SCSS 入口  
   新增 `booking-main.scss`、`member-center-main.scss`，載入順序對齊 [docs/itcss-architecture.md](/D:/githubdesk/Yuruicamp/docs/itcss-architecture.md)：`settings -> generic -> elements -> objects -> components -> pages -> utilities`。輸出檔名先維持 `booking-main.css`、`member-center-main.css`，避免大量修改 HTML。

2. 搬移 settings  
   將 [booking/css/settings.css](/D:/githubdesk/Yuruicamp/booking/css/settings.css) 拆成 `_tokens.scss` 與 `_settings.scss`。所有 `--yc-*` 保持 source of truth，`--bk-*` 僅保留 alias。不得新增未定義色碼、字體、間距。

3. 拆分 generic / elements  
   [booking/css/base.css](/D:/githubdesk/Yuruicamp/booking/css/base.css) 目前混有 reset、motion utility、modal 基礎。需拆成：
   `generic/_reset.scss`：`*`、form control reset  
   `generic/_motion.scss`：`reveal`、`zoomBox`、reduced motion  
   `components/_modal.scss` 或既有 auth modal：`.modal` 基礎

4. 整理 objects  
   將 [booking/css/layout.css](/D:/githubdesk/Yuruicamp/booking/css/layout.css) 與 [booking/css/objects/booking-layout.css](/D:/githubdesk/Yuruicamp/booking/css/objects/booking-layout.css) 收斂到 objects。只放 container、grid、page shell、layout spacing，不放品牌色、卡片視覺或互動狀態。

5. 整理 components  
   將 `booking/css/components/*.css` 逐一改為 `_*.scss`，由 `components/_components.scss` 統一 `@use`。同時檢查 page-only selector，不該留在 components 的搬到 pages。

6. 整理 pages  
   將 `camp-search.css`、`camp-detail.css`、`rental-guide.css`、`booking-cart.css`、`booking-checkout.css`、`booking-faq.css`、`member-center.css` 搬進 `pages/`。每個頁面用頁面根 class 限定範圍，例如 `.campSearchPage`、`.campDetailPage`、`.bookingCartPage`。

7. 命名與相容策略  
   任務要求 class/id 使用駝峰式命名，但目前大量存在 `bk-cart-*`、`faq-*`、`rg-*`、BEM `__`。這不能只改 CSS，必須同步盤點 HTML 與 JS selector。建議分頁分批改名，每批都跑 `rg` 確認舊 selector 已無 runtime 依賴。

8. 編譯與 Vite  
   目前 Vite 只透過 [src/styles.js](/D:/githubdesk/Yuruicamp/src/styles.js) 編譯主站 [css/main.scss](/D:/githubdesk/Yuruicamp/css/main.scss)。booking 若要納入 Vite build，需要新增 booking style entry，或保留 Sass CLI 產出靜態 `booking-main.css` / `member-center-main.css`。建議先採 Sass CLI 輸出，降低 Vite 多頁輸入變更風險。

9. README 更新  
   實作完成後，在 [README.md](/D:/githubdesk/Yuruicamp/README.md) 補上 booking 已改為 SCSS ITCSS、入口檔、編譯指令、驗證結果。

## 預期結果：
**建議目標結構**
```text
booking/css/
  booking-main.scss
  member-center-main.scss
  settings/
    _settings.scss
    _tokens.scss
  generic/
    _generic.scss
    _reset.scss
    _motion.scss
  elements/
    _elements.scss
  objects/
    _objects.scss
    _booking-layout.scss
  components/
    _components.scss
    _booking-header.scss
    _booking-button.scss
    ...
  pages/
    _pages.scss
    _camp-search.scss
    _camp-detail.scss
    _rental-guide.scss
    _booking-cart.scss
    _booking-checkout.scss
    _booking-faq.scss
    _member-center.scss
  utilities/
    _utilities.scss
  overrides/
    _flatpickr.scss
```

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
執行 `npm run stylelint`、`npm run format`、`npm run build`。再以 375px、768px、1024px、1440px 檢查 booking 頁面，確認無水平捲動、focus-visible 可見、鍵盤可操作、無 inline style、無 `!important`、無新增未定義 token。
