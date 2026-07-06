# ITCSS (Inverted Triangle CSS) 架構規範

通用樣式規則放在最前面，覆蓋規則放在最後，按照優先順序排列成一個倒三角形。

- 由上至下，七個層級:
  - `settings` > 配置顏色、字體、大小等各種參數的變數配置。
  - `tools` > 全球通用的 mixin 和函數。
  - `generic` > CSS 重設和規範化規則，為您的樣式奠定基礎。
  - `elements` > 原生 HTML 元素的樣式規則。
  - `objects` > 用於佈局或結構化元素的樣式規則。
  - `components`(元件) > UI元件的樣式規則。
  - `trumps`(核心覆寫) > 輔助或實用規則，透過調整和覆寫現有規則來微調物件或元件。
    ![alt text](Layers.png)
- 三種特性的覆蓋範圍 (越上面影響越多):
  - Reach (影響範圍) : 影響多少html 元素越多越上層。
  - Specificity (權重) : 選擇器權重越低越上層。
    原生標籤 > class > id > !important
  - Explicitness (具體意圖) : 模糊、通用 (上層)，明確、專一 (下層)
    ![alt text](Reach.png)

## 載入順序

```scss
@use 'settings/settings';
@use 'generic/generic';
@use 'elements/elements';
@use 'objects/objects';
@use 'components/components';
@use 'pages/pages';
```

Booking 子系統已改用 SCSS `@use` 與主站 ITCSS 對齊，公開頁入口為 `booking/css/booking-main.scss`。會員中心樣式已收斂為主站唯一來源，由 `css/main.scss` 載入 `css/pages/_member-center.scss`；`booking/pages/member-center.html` 保留 booking header/footer shell，並載入主站會員中心樣式與共用會員中心 partial：

```scss
@use 'settings/settings';
@use 'generic/generic';
@use 'elements/elements';
@use 'objects/objects';
@use 'components/components';
@use 'overrides/flatpickr';
@use 'pages/pages';
```

Booking runtime 頁面載入編譯輸出 `booking/css/booking-main.css`。舊的 `booking/css/base.css` 與 `booking/css/booking.css` 已移除，不再作為 legacy bridge 保留；booking 不再維護會員中心專用 CSS 入口。

## 分層責任 (由上至下 ITCSS排列)

- settings (全站共用顏色、尺寸樣式表)
- generic (覆蓋預設樣式)
  - `reset.scss` <html>、<body>、<img>、<button>、`*` 的覆蓋
- elements (html 原始標籤通用樣式)
- objects (「 共用 」佈局樣式)
- components (「 主站 」共用元件)
  - /widgets 資料夾 (「 全站 」共用元件)
    - `footer.scss` 頁腳樣式，套用至buyer, booking。
    - `floating-actions.scss` 套用至主站與 booking 右下角的 Line 客服、top up 按鈕。
    - `header.scss` 目前只套用buyer
  * `button.scss` 定義共用按鈕「 基本樣式 」。
  * `modal.scss` modal 「 對話窗內容 」樣式。
    - modal 背景遮罩、Title、Body、關閉按鈕等等。
  * `auth-modal.scss`
    - 登入/註冊/喜好問卷樣式
  * `drawer.scss` (抽屜動畫)
    - modal 滑動動畫控制、控制顯示/隱藏、透明度控制
  * `offcanvas.scss` 補充導覽列連結樣式
  * `cart-drawer.scss`
    - 購物車全部樣式 + 購物車滑動動畫
- pages (根據「 頁面 」特別設計的樣式)

## 新增樣式規則

- 新增頁面樣式時放在 `css/pages/_頁面.scss`，並從 `css/pages/_pages.scss` 以 `@use` 載入。
- 頁面樣式需盡量用頁面根 class 限定範圍，例如 `.homePage`、`.productsPage`、`.checkoutPage`。
- 原生元素的全站基底與互動狀態放在 `elements`，例如 `body`、`a`、`a:hover`、`a:focus-visible`。
- 可跨頁重用的 UI 才放進 `components`，避免讓 components 混入單一頁面規則。
- Booking 單頁流程 selector 需放在 `booking/css/pages/`；例如搜尋頁篩選側欄、營地詳情圖牆、結帳加購提示與裝備租借側欄不放在 `booking/css/components/`。
- Booking objects 層目前不保留頁面 shell 或 grid；若 selector 帶有 `.searchPage`、`.detailPage`、`.rentalPage`、`.bookingCartPage` 等頁面語意，必須放回 `booking/css/pages/`。
- Booking 跨頁懸浮操作屬於 component，與主站共用 `css/components/widgets/_floating-actions.scss` 作為唯一樣式來源。
- 新增色彩、間距、圓角、陰影時，優先使用 `--yc-*` token；需要新 token 時先補在 `settings`，不再輸出 `--yui-*` 或 `--bk-*` alias。
- 原生元素基礎樣式需放在 `css/elements/`。
- 大量重複佈局需放在 `css/objects/`。
- Components 層的共用元件應直接使用 `--yc-*` token，避免依賴其他 partial 先宣告的 Sass 變數或舊 alias。
- Components 層目前不保留 Sass `$...` alias；若需要新 token，先回到 `settings` 定義 runtime custom property。

## 樣式歸層判斷表

| 新增 selector 或規則                                      | 放置層級     | 判斷理由                                               |
| --------------------------------------------------------- | ------------ | ------------------------------------------------------ |
| `:root`、全站 `--yc-*` token                              | `settings`   | 只提供設計設定或 runtime token，不直接描述元件外觀。   |
| `*`、`*::before`、reset、normalize                        | `generic`    | 用來消除瀏覽器預設差異，權重應低於所有專案樣式。       |
| `body`、`a`、`button`、`img`、`a:hover`                   | `elements`   | 直接套用原生 HTML 元素，沒有綁定 component class。     |
| `.container`、`.stack`、`.cluster`、`.grid`               | `objects`    | 只管理寬度、排列、節奏與結構，不放品牌顏色或元件狀態。 |
| `.btn`、`.modal`、`.drawer`、`.siteHeader`、`.siteFooter` | `components` | 可跨頁重用，具備明確 UI 語意與互動狀態。               |
| `.homePage`、`.productsPage`、`.checkoutPage` 底下的區塊  | `pages`      | 只服務單一頁面流程或單一頁面的視覺組合。               |

## 尚未處理

- Booking 自有 selector 已同步改成語意化 camelCase；Bootstrap Icons、Flatpickr 等外部套件 class 保留原套件命名。
- `admin/css/admin.css` 仍是獨立 CSS 系統，後續可再拆成自己的 ITCSS entry。
- `css/pages/*.scss` 仍可保留頁面局部 Sass alias，用來讓大型頁面 partial 維持可讀性；局部 alias 應對應到 `--yc-*`。
