請先讀取：
- `components/footer.partial`
- `components/header.partial`
- `booking/css/components/_booking-footer.scss`
- `booking/css/components/_booking-header.scss`
- `css/components/widgets/_footer.scss`
- `css/components/widgets/_header.scss`
- `booking/js/booking-header.js`
- `booking/js/layout.js`
- `booking/js/camp-search.js`
- `js/components/cart.js`
- `js/components/header.js`
- `js/components/modal.js`
- `js/main.js`


## 任務目標:
- 目標是讓主站與 booking 共用 header/footer 的「結構樣式與互動基底」，但仍各自顯示不同內容、連結、入口與業務功能。
- 維持現有 `components/header.partial`、`components/footer.partial` 的 `data-layout-part` 分流模式：主站載入 `main-header/main-footer`，booking 載入 `bookingHeader/bookingFooter`。
- 不合併成同一份 HTML 內容；只統一樣式骨架，避免主站購物車、搜尋與 booking 預約背包互相干擾。


## 問題解決流程:
- Footer 先做：
  - 以主站 `css/components/widgets/_footer.scss` 作為共用 footer 樣式來源。
  - 保留 `.siteFooter*` 與 `.bookingFooter*` 各自 class，但共用 grid、spacing、link、social、bottom bar、RWD、focus-visible 規則。
  - booking 只保留必要差異，例如背景 token、文案、服務連結、FAQ 路徑。
  - 清查並移除 booking footer SCSS 中已無 runtime 使用的舊 `.bkFooter*` 相容樣式。

- Header 後做：
  - 以主站 `css/components/widgets/_header.scss` 作為共用 header 樣式骨架來源。
  - 共用容器高度、版心、品牌區、操作按鈕、badge、會員選單、focus-visible、RWD 基礎。
  - 主站保留搜尋、商城購物車、商品/文章/門市導覽；booking 保留商城切換、預約背包、預約選單、booking 會員中心入口。
  - booking header SCSS 只保留 booking 專屬外觀差異與預約背包 panel 樣式，移除已不用的 `.bk*` 舊 header 相容規則。

- 載入與架構：
  - 主站仍由 `js/main.js` 載入 `main-header/main-footer/shared-auth`。
  - booking 仍由 `booking/js/layout.js` 載入 `bookingHeader/bookingFooter/shared-auth`。
  - 不新增 inline style、不使用 `!important`、不新增未定義色碼；差異全部走既有 `--yui-*` 或 booking 已定義 token。
  - 若需要新增共用 token，先補在 settings，再由兩邊 SCSS 使用。

## 預期結果：
- 內容分流沿用目前 partial 架構，不改成單一 header/footer HTML。
- 共用的是樣式基底，不共用業務行為；主站 cart 與 booking cart 仍分開。
- 實作時以 footer 優先，因為 footer 幾乎無互動，風險最低；header 分階段處理。


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
1. 盤點 selector 使用：用 `rg` 確認 `.site*`、`.booking*`、`.bk*`、`.bkFooter*` 在 HTML/SCSS/JS 的實際引用。
2. 先統一 footer：把可共用規則集中到主站 widgets footer，booking footer SCSS 只留必要差異或刪除重複。
3. 驗證 footer 後再統一 header 靜態外觀：版心、brand、actions、button、badge、RWD。
4. 最後處理 header 互動區：offcanvas、cart drawer、booking 預約背包、會員 dropdown、shared auth focus/scroll lock。
5. 更新 README，簡述 header/footer 已改為樣式共用、內容由 `data-layout-part` 各自顯示。

- 靜態檢查：
  - `rg` 確認移除的舊 `.bk*` / `.bkFooter*` selector 沒有 runtime 引用。
  - Stylelint 檢查主站與 booking SCSS。
  - Prettier check。
  - Vite build。

- 視覺與互動檢查：
  - 主站頁面：home、products、member-center。
  - booking 頁面：camp-search、booking-cart、member-center。
  - 375px、768px、1024px、1440px 檢查無水平捲動。
  - 鍵盤操作確認：主站選單、搜尋、購物車、會員選單、booking 選單、預約背包、登入 modal 都能 focus 且可關閉。

