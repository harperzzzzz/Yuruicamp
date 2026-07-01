# ITCSS 架構規範

本文記錄 `css/main.scss` 的分層契約，新增或搬移 SCSS 時需依照此順序判斷責任邊界。

## 載入順序

```scss
@use 'settings/settings';
@use 'generic/generic';
@use 'base/base';
@use 'layouts/layouts';
@use 'components/components';
@use 'pages/pages';
@use 'utilities/utilities';
```

## 分層責任

- `settings`：全站設計 token、Sass 設定值與不綁定 UI 的基礎變數。目前 `--yui-*` runtime token 放在 `css/settings/_tokens.scss`。
- `generic`：reset、normalize 與瀏覽器預設一致化規則。
- `base`：`body`、`a`、`button`、`img` 等原生元素基礎樣式。
- `layouts`：container、grid、stack 等不帶品牌視覺的版面物件。
- `components`：跨頁可重用 UI，例如 header、drawer、modal、button、footer、floating actions。
- `pages`：單一頁面專屬樣式，例如 `home`、`products`、`checkout`、`faq`。
- `utilities`：單一職責工具類，權重最高，應保持少量且可預期。

## 新增樣式規則

- 新增頁面樣式時放在 `css/pages/_頁面.scss`，並從 `css/pages/_pages.scss` 以 `@use` 載入。
- 頁面樣式需盡量用頁面根 class 限定範圍，例如 `.homePage`、`.productsPage`、`.checkoutPage`。
- 可跨頁重用的 UI 才放進 `components`，避免讓 components 混入單一頁面規則。
- 新增色彩、間距、圓角、陰影時，優先使用 `--yui-*` token；需要新 token 時先補在 `settings`。
- `css/abstracts/_abstracts.scss` 只保留舊路徑相容，不再作為新設定入口。
- Components 層的共用元件應直接使用 `--yui-*` token，避免依賴其他 partial 先宣告的 Sass 變數。

## 本輪尚未處理

- `booking/css/*.css` 與 `admin/css/admin.css` 仍是獨立 CSS 系統，後續可再拆成各自的 ITCSS entry。
- `css/components/_header.scss` 仍保留檔案內部 `$header-*` alias，屬於局部變數；後續若要抽成 module token，需搭配 `@use ... as *` 或命名空間引用。
