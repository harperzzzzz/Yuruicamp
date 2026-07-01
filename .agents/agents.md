先讀文件 :
* `docs/ai-style-sheet.md`
* `docs/ai-style-tokens.md`
* `components/header.partial`
* `css/components/content/pages/_header.scss`
* `js/main.js`
* `pages/branches.html`
* `css/components/content/pages/branches.scss`
* `pages/product-detail.html`
* `css/components/content/pages/product-detail.scss`

# Codex 任務：Header 固定、浮動按鈕、分店 Modal 捲動、商品詳情 CTA 樣式修復

## Summary

依 `.agents/agents.md` 分析目前結構後，請修復 4 個前台 UI / 互動問題。保留現有 Vite、ITCSS、SCSS partial 架構，不新增功能、不改 HTML 架構，避免 inline style 與 `!important`。

注意：`.agents/agents.md` 指定的 `docs/ai-style-tokens.md` 不存在，實際存在檔案是 `docs/ai-style-tokens.css`。`branches.scss` 與 `product-detail.scss` 實際為 `_branches.scss`、`_product-detail.scss`。

## Key Changes

- Header 固定顯示：
  - 在 `css/components/content/pages/_header.scss` 檢查 `.siteHeader, .bookingHeader`。
  - 目前已是 `position: sticky; top: 0; z-index: var(--yui-z-sticky);`。
  - 若實測在部分頁面失效，改為 `position: fixed; top: 0; inset-inline: 0;`，並補頁面上方 offset，避免內容被 header 遮住。
  - 優先維持現有 sticky；只有確認 sticky 因父層或頁面結構失效時才改 fixed。

- 浮動按鈕樣式：
  - `js/main.js` 只負責產生 `.floating-actions`、`button.floating-top-btn`、`a.floatingLineBtn`，不要在 JS 加 inline style。
  - 在既有 SCSS 合適層級新增或補齊 `.floating-actions` 樣式：
    - `position: fixed`
    - `right: var(--yui-space-4)`
    - `bottom: var(--yui-space-4)`
    - `z-index: var(--yui-z-tooltip)`
    - 垂直排列，`.floating-top-btn` 在 `.floatingLineBtn` 上方。
  - `.floating-top-btn`：
    - 圓形，建議 `width/height: 48px`
    - 背景使用 `var(--yui-orange)`，不要硬寫 `#e07b39`
    - 文字色使用 `var(--yui-surface-muted)`，對應 `#f2f2f2`
  - `.floatingLineBtn`：
    - 圓形，建議 `width/height: 48px`
    - 背景使用 `var(--yui-success)`，不要硬寫 `#4caf50`
    - 文字色使用 `var(--yui-surface-muted)`
  - 保留 hover / focus-visible，並確保 375px 不造成水平捲動。

- 分店合作夥伴卡片點擊不拉到頁首：
  - 檢查 `js/pages/branches.js` 的 `bindPartnerGrid()` 與 `openPartnerDetail()`。
  - 目前 `.partnerCardTrigger` 是 `button type="button"`，理論上不應造成頁面跳到頂端。
  - 問題可能來自 `window.openModal('partnerModal')` 聚焦 modal 第一個元素時導致 scroll jump。
  - 修復方向：
    - 在開啟 `partnerModal` 前記錄 `window.scrollY`。
    - 開啟後若頁面被拉到頂端，立即用 `window.scrollTo({ top: previousScrollY, behavior: 'auto' })` 還原。
    - 或調整 `modal.js` 的 focus 行為，避免對已在 DOM 中但位置靠前的 modal focus 造成跳動；需確認不影響其他 modal。
  - 不要移除 keyboard focus，可用 `preventScroll: true`：`focus({ preventScroll: true })`。

- 商品詳情頁 CTA 套用商品列表按鈕樣式：
  - 參考 `css/components/content/pages/_products.scss` 的 `.productCardAddBtn`：
    - primary 背景
    - primary border
    - 8px radius
    - 白字
    - 700 weight
    - min-height 44px
    - hover 時透明背景、primary 文字
  - 在 `css/components/content/pages/_product-detail.scss` 調整 `#addToCartBtn`、`#buyNowBtn` 或 `.cartBtn`。
  - 不建議直接把 `productCardAddBtn` class 加到 HTML，避免跨頁 class 語意混用。
  - 建議在 `_product-detail.scss` 中複製相同視覺規則到 `.cartBtn`，並保留商品詳情頁既有 layout：`flex: 1; min-width: 140px; width: 100%` 等響應式設定。

## Files To Inspect / Touch

- 必讀：
  - `docs/ai-style-sheet.md`
  - `docs/ai-style-tokens.css`
  - `components/header.partial`
  - `css/components/content/pages/_header.scss`
  - `js/main.js`
  - `pages/branches.html`
  - `css/components/content/pages/_branches.scss`
  - `js/pages/branches.js`
  - `pages/product-detail.html`
  - `css/components/content/pages/_product-detail.scss`
  - `css/components/content/pages/_products.scss`

- 預期可修改：
  - `css/components/content/pages/_header.scss`
  - `css/components/content/pages/_branches.scss`
  - `css/components/content/pages/_product-detail.scss`
  - `js/components/modal.js` 或 `js/pages/branches.js`
  - `README.md`

- 不建議修改：
  - `components/header.partial`
  - `pages/branches.html`
  - `pages/product-detail.html`
  - `js/main.js`，除非確認 markup class 命名錯誤

## Test Plan

- 靜態檢查：
  - `node --check js/components/modal.js`
  - `node --check js/pages/branches.js`
  - 若有改其他 JS，也跑對應 `node --check`
  - `npm run stylelint` 或針對修改 SCSS 執行 stylelint

- Header：
  - 在 `pages/home.html`、`pages/branches.html`、`pages/product-detail.html` 往下捲動，header 仍停留視窗上方。
  - 375px、768px、1024px 皆不可水平捲動。
  - Header dropdown、search、cart drawer 的 z-index 不被 floating buttons 壓住。

- Floating actions：
  - `.floating-top-btn` 固定在右側，位於 `.floatingLineBtn` 上方。
  - `.floating-top-btn` 圓形、橘色 token 背景、淺色文字。
  - `.floatingLineBtn` 圓形、成功色 token 背景、淺色文字。
  - 兩者 z-index 高於一般頁面內容。

- Branches：
  - 捲動到合作夥伴區。
  - 點擊 `.partnerCardTrigger` 開啟 `#partnerModal`。
  - 頁面不可跳到最上方。
  - 鍵盤 Tab 可進入 modal，Esc 或關閉按鈕依既有 modal 邏輯關閉。

- Product detail：
  - `#addToCartBtn`、`#buyNowBtn` 視覺與 `.productCardAddBtn` 一致。
  - hover / focus-visible 狀態可見。
  - 375px 下兩個按鈕不溢出、不互相擠壓。

## Assumptions
- 新顏色不可硬編碼，需使用既有 token：`--yui-orange`、`--yui-success`、`--yui-surface-muted`。
- 若 header sticky 已符合需求，實作時不應改成 fixed，避免產生內容 offset 與 overlay 回歸問題。
- README 只有在真正實作後才更新；本次只產出解決方案不更新 README。

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

