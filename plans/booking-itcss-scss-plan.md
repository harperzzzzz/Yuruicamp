# Booking ITCSS SCSS 轉換計畫

## 目標

將 `booking/css/` 從目前的 CSS `@import` 與 cascade layer 架構，漸進轉換為與主站 `css/` 相同的 SCSS ITCSS 架構，同時保留現有 Vite 專案結構、HTML 載入路徑與 JavaScript selector 行為。

## 依據文件

- `docs/itcss-architecture.md`：ITCSS 層級、載入順序與 selector 歸層規則。
- `booking/booking-style-tokens.md`：Booking `--yc-*` token source of truth 與 `--bk-*` 相容 alias 規則。
- `booking/css/`：Booking 現有 runtime CSS 入口與頁面、元件、物件樣式。
- `css/`：主站目前採用的 SCSS partial、聚合 partial 與 `@use` 載入模式。

## 現況判斷

Booking 目前保留一個 runtime 入口：

- `booking/css/booking-main.css`：公開 booking 頁入口。

會員中心已改由主站 `css/main.scss` 與 `css/pages/_member-center.scss` 統一維護，`booking/pages/member-center.html` 保留 booking header/footer shell，並載入共用會員中心 partial。主站使用 `css/main.scss` 依序 `@use settings/generic/elements/objects/components/pages`，各層再由聚合 partial 載入子檔。Booking 要與主站一致，核心工作是建立同樣的 SCSS partial 邊界，再將既有公開頁 CSS 逐檔搬入正確 ITCSS 層級。

## 本輪實作狀態

- 已新增 `booking/css/booking-main.scss`，作為 booking 公開頁的 SCSS 入口。
- 已建立 settings、generic、elements、objects、components、pages、overrides 的 SCSS partial 結構；utilities 已空化並移除，唯一 `.srOnly` 由 generic reset 管理。
- 已將現有 booking CSS 內容機械轉入對應 SCSS partial，並把 `base.css` 中的 reset、motion helper、modal 基礎拆入對應層級。
- 已移除不再由 runtime 載入的舊平面 CSS source，保留 SCSS source 與公開頁 CSS 編譯輸出。
- 已完成 components 歸層審查，搜尋、詳情、結帳支援與租借流程等單頁 selector 已移入 pages layer，components layer 僅保留跨頁可重用 UI。
- 已確認 `booking/css/settings/_tokens.scss` 內 `--yc-*` 為 source of truth，`--bk-*` 僅作相容 alias；後續新增 token 不應在 page/component partial 中另立一次性色碼。
- 已用 Sass 重新產出 `booking/css/booking-main.css`，保留既有公開頁 HTML link 路徑。
- 已移除 booking 會員中心專用 SCSS/CSS 入口，會員中心樣式統一由主站 `css/pages/_member-center.scss` 維護。
- 已同步將 booking 自有 class/id 轉為語意化 camelCase，並同步更新 HTML、SCSS、JavaScript selector 與 shared booking header/footer partial；Bootstrap Icons 與 Flatpickr 等外部類別保留原套件命名。
- 已移除 booking JS 以 `.css()` 寫入 inline style 的做法，改由 `isCheckoutSuccess`、`isFieldInvalid`、`isRangeThumbRaised` 等狀態 class 驅動樣式。
- 已在 elements 層補上原生互動元素的 `:focus-visible` 保底樣式。
- 已完成第二輪 ITCSS 精修：objects 層不再載入頁面語意 layout，floating actions 移至 components，camp-search hero 移至 pages，toast 改採 `bookingToast*` 新命名並保留 `bkToast*` 相容。

## 目標結構

```text
booking/css/
  booking-main.scss
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
  components/
    _components.scss
    _booking-auth-modal.scss
    _booking-breadcrumb.scss
    _booking-button.scss
    _booking-card.scss
    _booking-drawer.scss
    _booking-footer.scss
    _booking-form.scss
    _booking-header.scss
    _booking-progress.scss
    _booking-summary.scss
    _booking-tag.scss
    _booking-tags-status.scss
    _booking-toast.scss
    _floating-actions.scss
    _booking-feedback.scss
    _modal.scss
  pages/
    _pages.scss
    _camp-search.scss
    _camp-detail.scss
    _camp-rental.scss
    _rental-guide.scss
    _booking-cart.scss
    _booking-checkout.scss
    _booking-faq.scss
  overrides/
    _flatpickr.scss
```

編譯輸出仍維持：

- `booking/css/booking-main.css`

如此可避免一次修改所有 booking HTML link 路徑。

## 分階段流程

### 1. 建立 SCSS 入口與聚合 partial

新增 `booking-main.scss`，載入順序固定為：

```scss
@use 'settings/settings';
@use 'generic/generic';
@use 'elements/elements';
@use 'objects/objects';
@use 'components/components';
@use 'overrides/flatpickr';
@use 'pages/pages';
```

會員中心不再建立 booking 專用入口，避免 `member-center` 樣式在主站與 booking 之間分叉。

### 2. Settings 層

將 `booking/css/settings.css` 拆成：

- `settings/_tokens.scss`：輸出 `:root` token。
- `settings/_settings.scss`：只 `@use 'tokens'`。

規則：

- `--yc-*` 是 booking source of truth。
- `--bk-*` 只能映射到 `--yc-*`，不得獨立漂移。
- 不新增未定義色碼、字體、間距系統。
- 若發現現有 CSS 使用文件未定義 token，先回到 `booking/booking-style-tokens.md` 與 `settings/_tokens.scss` 做一致性審核，不直接在元件檔補一次性色碼。

### 3. Generic 與 Elements 層

拆分 `booking/css/base.css`：

- `generic/_reset.scss`：`*`、`*::before`、`*::after`、button/input/select/textarea reset。
- `generic/_motion.scss`：`.reveal`、`.zoomBox`、scroll indicator、`prefers-reduced-motion`。
- `.modal` 基礎規則移出 generic，放入 component 層。

`elements/_elements.scss` 只保留原生元素基底，例如 `body`、`a`、`button`、`img`、表單元素預設 focus 狀態。

### 4. Objects 層

將 `layout.css` 與 `objects/booking-layout.css` 合併整理到 objects。Objects 只處理：

- page shell。
- container。
- grid。
- sticky column 的位置結構。
- spacing 與 layout rhythm。

不放品牌色、卡片陰影、按鈕狀態、表單外觀。

### 5. Components 層

將 `booking/css/components/*.css` 轉成 `_*.scss`，由 `components/_components.scss` 統一載入；本輪已將只服務單頁的 partial 搬出 components layer。

歸層檢查：

- 可跨頁重用的 UI 留在 components，例如 header、footer、button、form、card、drawer、toast、summary、progress、breadcrumb。
- 只服務單頁流程的 selector 移到 pages；已移入 pages 的代表包含搜尋頁 search bar/filter/results/camp card、詳情頁 camp detail/zone card/zone table、結帳 checkout support、租借頁 summary bar/recommendation/rental item/rental cart。
- 第三方套件樣式覆寫不要混入 components，移到 `overrides/_flatpickr.scss`。

### 6. Pages 層

將下列頁面檔搬入 `pages/`：

- `camp-search.css` -> `_camp-search.scss`
- `camp-detail.css` -> `_camp-detail.scss`
- `camp-rental.css` 或租借流程元件 partial -> `_camp-rental.scss`
- `rental-guide.css` -> `_rental-guide.scss`
- `booking-cart.css` -> `_booking-cart.scss`
- `booking-checkout.css` -> `_booking-checkout.scss`
- `booking-faq.css` -> `_booking-faq.scss`

每個頁面 partial 需盡量以頁面根 class 限定範圍，例如 `.campSearchPage`、`.campDetailPage`、`.rentalGuidePage`、`.bookingCartPage`、`.bookingCheckoutPage`、`.bookingFaqPage`、`.memberCenterPage`。

### 7. 命名轉換策略

任務要求 class 與 id 使用駝峰式命名法；本輪已完成 booking 自有 selector 同步轉換。原先存在的 hyphen、BEM 與縮寫命名包含：

- `.bk-cart-layout`
- `.bk-cart-card__header`
- `.faq-hero`
- `.rg-section`
- `.step-progress`
- `.payment-option`

此類改名不能只改 CSS，必須同步 HTML 與 JS selector。本輪採用受限機械轉換後，再用 selector 盤點確認 booking 自有 class/id 無 hyphen、underscore 或 BEM 殘留。後續若新增 selector，仍需遵守：

1. 先用 `rg` 找出目標 selector 在 HTML、CSS、JS 的所有引用。
2. 同一批只改一個頁面或一組元件。
3. CSS、HTML、JS 同步改成語意化 camelCase。
4. 每批完成後再次用 `rg` 確認舊 selector 無 runtime 引用。

### 8. 編譯策略

第一階段建議使用 Sass CLI 輸出，降低 Vite 多入口調整風險：

```bash
npx sass --no-source-map booking/css/booking-main.scss:booking/css/booking-main.css
```

若後續要納入 Vite build，再新增 booking style entry，而不是改動主站 `src/styles.js` 的既有用途。

### 9. README 與變更紀錄

完成實作後需更新根目錄 `README.md`，至少包含：

- Booking 已改為 SCSS ITCSS 架構。
- Booking 公開頁 SCSS 入口與 CSS 輸出。
- 會員中心樣式改由主站 `css/pages/_member-center.scss` 統一維護。
- 編譯指令。
- 驗證指令與結果。

可同步補充 `booking/BookingChangeLog.md`，但不以取代 README 為準。

## 驗收清單

- `booking/css/booking-main.scss` 存在。
- `booking/css/booking-main.css` 可由 SCSS 編譯產生。
- `booking/css/` 已按 ITCSS 分層：settings、generic、elements、objects、components、overrides、pages。
- `@use` 載入順序符合 `docs/itcss-architecture.md`。
- 沒有新增未定義色碼、字體、間距系統。
- 沒有 inline style。
- 沒有 `!important`。
- 互動元件具備鍵盤可操作與可見 `:focus-visible`。
- 375px viewport 無水平捲動。
- class 與 id 已完成語意化 camelCase；外部套件 class 不納入專案命名轉換。
- CSS/HTML/JS 新增或調整的函式與複雜區塊需有中文用途註解。
- 根目錄 `README.md` 已簡述本次更新內容。

## 建議驗證指令

```bash
npm run stylelint
npm run format
npm run build
```

`npm run format` 已收斂為 booking code 與本輪更新文件範圍；若需要檢查全專案既有檔案，可另外執行 `npm run format:all`。

另需以瀏覽器或自動化檢查下列寬度：

- 375px
- 768px
- 1024px
- 1440px

檢查重點為無水平捲動、焦點狀態可見、抽屜與 modal 可鍵盤操作、hover 不造成 layout shift。
