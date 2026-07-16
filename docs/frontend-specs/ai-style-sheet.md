# Yuruicamp AI Style Sheet

- **適用範圍：** Yuruicamp 主站、Booking website、租借結帳與後台 UI
- **最後更新：** 2026-07-06
- **用途：** 提供 AI 與開發者建立、檢查、延伸 Yuruicamp UI 時使用的設計 token、版面規則、元件規則與無障礙檢查清單。此文件只作為設計規格，不會被任何 HTML、CSS、JS 匯入。

---

## 目的

這份文件是 Yuruicamp 目前的 AI 樣式規範 source of truth。主站與 booking 新增或重構 SCSS 時，都應直接使用 `--yc-*` token，不再新增 `--yui-*` 或 `--bk-*` 相容 alias。

文件目標是提供 AI 程式設計工具一份簡化、可直接實作的視覺合約：保留戶外電商與露營訂房的品牌識別，同時將設計語言整理為可重複使用的 token、版面規則、元件類別與無障礙檢查項目。

## 設計方向

- 產品類型：戶外電商、營地訂房、租借結帳、會員中心、賣家後台管理。
- 視覺氛圍：平靜、自然、實用、可靠、容易瀏覽。
- 建議風格：節制的工具型 UI，搭配戶外編輯風格的溫度。
- 避免使用：強烈漸層、裝飾性 blob 圖形、以 emoji 作為 UI 圖示、一次性的顏色、流程頁面中過大的行銷區塊。
- 新增 UI 時，請使用同一套 SVG 圖示庫的圖示。既有 emoji 若屬於文章或行銷內容可以保留，但新的互動控制項必須使用圖示。

## 設計原則

- 使用 `--yc-*` 作為主站與 booking 的 source of truth。
- 不輸出新的 `--bk-*` 或 `--yui-*` 相容 alias；新增或重構 SCSS 都必須直接使用 `--yc-*`。
- CTA 使用 warm gold，但文字必須使用 `--yc-on-cta`，hover 文字必須使用 `--yc-on-cta-hover`，避免白字金底造成對比不足。
- 互動元件最小觸控高度為 `44px`。
- Hover 狀態只能使用 color、border、shadow、opacity、transform，不應使用 width / height / padding transition 造成 layout shift。
- Focus 狀態必須可見；只有在搭配 focus ring 時才允許移除 default outline。
- Motion 必須支援 `prefers-reduced-motion`。
- 不新增未定義色碼、字體、間距系統；若缺 token，先補本文件與 runtime token，再使用。

## 核心 Token

| Token                 |                       值 | 用途                               |
| --------------------- | -----------------------: | ---------------------------------- |
| `--yc-bg`             |                `#f8f5ee` | 頁面主背景                         |
| `--yc-surface`        |                `#fffdf9` | Card、panel、modal、form surface   |
| `--yc-surface-soft`   |                `#f0ece3` | 次層背景、區塊底色                 |
| `--yc-border`         |                `#d8cfc3` | 預設邊線                           |
| `--yc-sage-soft`      |                `#eef2ec` | chip、tag、filter、hover soft 背景 |
| `--yc-sage-light`     |                `#b7c3b3` | hover border、低強度品牌色         |
| `--yc-sage-action`    |                `#73816e` | 主品牌 action、header              |
| `--yc-sage-dark`      |                `#62705d` | 深色品牌、footer bottom            |
| `--yc-cta-soft`       |                `#fbf3d1` | CTA soft background                |
| `--yc-cta-line`       |                `#d9c98f` | CTA soft border                    |
| `--yc-cta`            |                `#e2d39a` | Conversion CTA                     |
| `--yc-cta-hover`      |                `#d4c27e` | CTA hover / active                 |
| `--yc-on-cta`         |                `#4a4537` | CTA 文字                           |
| `--yc-on-cta-hover`   |                `#4a4537` | CTA hover 文字                     |
| `--yc-text`           |                `#3e473d` | 主要文字                           |
| `--yc-text-secondary` |                `#625e56` | 次要文字                           |
| `--yc-text-muted`     |                `#7b756d` | 輔助文字、disabled、metadata       |
| `--yc-on-dark`        |                `#fffdf9` | 深色背景文字                       |
| `--yc-on-dark-muted`  | `rgb(255 253 249 / 76%)` | 深色背景輔助文字                   |

## 狀態 Token

| Token               |        值 | 用途         |
| ------------------- | --------: | ------------ |
| `--yc-success-soft` | `#e7efe3` | 成功狀態背景 |
| `--yc-success`      | `#73816e` | 成功主色     |
| `--yc-success-text` | `#4f624a` | 成功文字     |
| `--yc-warning-soft` | `#f4ece2` | 警告背景     |
| `--yc-warning`      | `#9a7455` | 警告主色     |
| `--yc-warning-text` | `#6b4d32` | 警告文字     |
| `--yc-error-soft`   | `#f4e7e4` | 錯誤背景     |
| `--yc-error`        | `#a65f58` | 錯誤主色     |
| `--yc-error-text`   | `#8a4842` | 錯誤文字     |

## 結構 Token

| Token                  |                                值 | 用途                                 |
| ---------------------- | --------------------------------: | ------------------------------------ |
| `--yc-header-bg`       |                         `#73816e` | Header                               |
| `--yc-header-bg-solid` |                         `#62705d` | 深色 header fallback                 |
| `--yc-header-border`   |          `rgb(255 253 249 / 14%)` | Header bottom border                 |
| `--yc-footer-bg`       |                         `#71806d` | Footer 主背景                        |
| `--yc-footer-bottom`   |                         `#62705d` | Footer bottom bar                    |
| `--yc-header-height`   |                            `64px` | Header 高度                          |
| `--yc-sticky-offset`   |                            `90px` | Sticky sidebar / booking card offset |
| `--yc-container-sm`    |                           `900px` | FAQ、窄內容                          |
| `--yc-container-md`    |                          `1100px` | Checkout、cart                       |
| `--yc-container-lg`    |                          `1200px` | Search、detail、rental               |
| `--yc-container-page`  | `min(1200px, calc(100vw - 48px))` | 頁面主要容器                         |

## 字體與排版

| Token               |                                                            值 | 用途                            |
| ------------------- | ------------------------------------------------------------: | ------------------------------- |
| `--yc-font-heading` |               `"Noto Serif TC", "Source Han Serif TC", serif` | Hero、section heading、品牌語氣 |
| `--yc-font-body`    | `"Noto Sans TC", "Source Han Sans TC", system-ui, sans-serif` | 內文、表單、列表                |
| `--yc-font-ui`      | `"Noto Sans TC", "Source Han Sans TC", system-ui, sans-serif` | Button、chip、tab、nav          |
| `--yc-text-xs`      |                                                     `0.75rem` | Caption、helper text            |
| `--yc-text-sm`      |                                                    `0.875rem` | Label、metadata、chip           |
| `--yc-text-md`      |                                                        `1rem` | Body、form control              |
| `--yc-text-lg`      |                                                    `1.125rem` | Card title、section intro       |
| `--yc-text-xl`      |                                                     `1.25rem` | Panel heading                   |
| `--yc-text-2xl`     |                                                      `1.5rem` | Page heading                    |
| `--yc-text-3xl`     |                                                    `1.875rem` | Hero subtitle / major section   |
| `--yc-text-4xl`     |                                                     `2.25rem` | Hero title                      |

- Body line-height 使用 `1.5` 到 `1.8`。
- 表單與 UI 文字使用 sans-serif，避免 serif 在密集操作介面降低掃描效率。
- Heading 可保留 serif，維持 Yuruicamp 的溫和戶外品牌感。
- Button、chip、filter、tab 建議 `600` 到 `700`，不要使用過重的 `900`。
- 資料密集的後台表格可使用 `14px` 到 `15px`，但可點擊元素仍應保持至少 `44px` 高。

## 間距、圓角、陰影

| Token                 |                                 值 | 用途                                  |
| --------------------- | ---------------------------------: | ------------------------------------- |
| `--yc-space-1`        |                              `4px` | 最小 gap                              |
| `--yc-space-2`        |                              `8px` | Icon gap、small inset                 |
| `--yc-space-3`        |                             `12px` | Compact padding                       |
| `--yc-space-4`        |                             `16px` | Base spacing                          |
| `--yc-space-6`        |                             `24px` | Card / grid gap                       |
| `--yc-space-8`        |                             `32px` | Section compact                       |
| `--yc-space-12`       |                             `48px` | Section gap                           |
| `--yc-space-16`       |                             `64px` | Page section                          |
| `--yc-space-24`       |                             `96px` | Large hero / footer spacing           |
| `--yc-radius-control` |                             `12px` | Input、select、button secondary shape |
| `--yc-radius-button`  |                             `12px` | Button                                |
| `--yc-radius-card`    |                             `19px` | Camp card、summary card               |
| `--yc-radius-section` |                             `24px` | Large content band                    |
| `--yc-radius-modal`   |                              `8px` | Modal / dialog                        |
| `--yc-radius-pill`    |                           `9999px` | Chip、badge、pill button              |
| `--yc-shadow-soft`    |  `0 5px 20px rgb(60 70 59 / 6.5%)` | Default card                          |
| `--yc-shadow-hover`   |  `0 16px 38px rgb(60 70 59 / 13%)` | Interactive card hover                |
| `--yc-shadow-cta`     | `0 8px 22px rgb(129 111 54 / 14%)` | Conversion CTA                        |
| `--yc-shadow-modal`   |     `0 24px 60px rgb(0 0 0 / 22%)` | Modal、drawer                         |

## 動態與互動

| Token                    |                                              值 | 用途                              |
| ------------------------ | ----------------------------------------------: | --------------------------------- |
| `--yc-duration-instant`  |                                          `80ms` | Press feedback                    |
| `--yc-duration-fast`     |                                         `180ms` | Hover、focus                      |
| `--yc-duration-normal`   |                                         `220ms` | Card、drawer micro-interaction    |
| `--yc-duration-slow`     |                                         `320ms` | Drawer / modal transition         |
| `--yc-ease-soft`         |                `cubic-bezier(0.2, 0.7, 0.2, 1)` | Soft outdoor motion               |
| `--yc-ease-standard`     |                  `cubic-bezier(0.4, 0, 0.2, 1)` | Modal、drawer                     |
| `--yc-transition-fast`   |   `var(--yc-duration-fast) var(--yc-ease-soft)` | Hover、focus transition shorthand |
| `--yc-transition-base`   | `var(--yc-duration-normal) var(--yc-ease-soft)` | Card、drawer transition shorthand |
| `--yc-target-min`        |                                          `44px` | Touch target minimum              |
| `--yc-icon-button-size`  |                                          `44px` | Icon button                       |
| `--yc-control-height-md` |                                          `44px` | Input / select                    |
| `--yc-focus-ring`        |              `0 0 0 3px rgb(115 129 110 / 24%)` | Default keyboard focus            |
| `--yc-focus-ring-strong` |              `0 0 0 4px rgb(115 129 110 / 30%)` | Modal / high-risk action focus    |

- Hover 可以讓 card `translateY(-2px)`，但不得 scale 到影響排版。
- Floating button 展開文字時應使用固定容器搭配 opacity / transform，不應 transition width。
- 所有 `outline: none` 必須搭配 `box-shadow: var(--yc-focus-ring)` 或等效 focus ring。
- Loading 狀態應 disable button，避免重複送出 booking / checkout 行為。

## Z-index Scale

| Token             |   值 | 用途                         |
| ----------------- | ---: | ---------------------------- |
| `--yc-z-base`     |  `0` | Default                      |
| `--yc-z-raised`   |  `1` | Raised card、hero overlay    |
| `--yc-z-sticky`   | `10` | Sticky filter / booking card |
| `--yc-z-header`   | `20` | Header                       |
| `--yc-z-dropdown` | `30` | User dropdown、menu          |
| `--yc-z-overlay`  | `40` | Modal / offcanvas backdrop   |
| `--yc-z-modal`    | `50` | Modal、offcanvas panel       |
| `--yc-z-toast`    | `60` | Toast、global feedback       |

## 版面規則

- 前台網站主容器：`min(1120px, calc(100vw - 32px))`。
- Booking 大型頁面容器：優先使用 `--yc-container-page` 或 `--yc-container-lg`。
- 商品與文章網格：`repeat(auto-fit, minmax(240px, 1fr))`。
- 結帳與詳細頁面：桌面版使用雙欄版面；低於 `768px` 時折疊為單欄。
- 訂房頁面：摘要面板僅在桌面版使用 sticky；手機版摘要必須回到一般文流中。
- 後台頁面：優先考慮密集掃讀、表格、篩選器與 modal；避免使用行銷風格卡片。

## 元件規則

### Button

- Conversion CTA：`--yc-cta` 背景、`--yc-on-cta` 文字、`--yc-shadow-cta` 陰影；hover 使用 `--yc-cta-hover` 與 `--yc-on-cta-hover`。
- Brand action：`--yc-sage-action` 背景、`--yc-on-dark` 文字。
- Secondary action：`--yc-surface` 背景、`--yc-sage-action` 文字、`--yc-border` 邊線。
- Danger action：`--yc-error` 背景、`--yc-on-dark` 文字。
- Button 高度不得低於 `--yc-target-min`。
- Icon-only button 使用 `--yc-icon-button-size`，並需要 accessible label。
- 載入中的操作需停用點擊功能、維持按鈕寬度穩定，並顯示文字或 loading spinner。

### Card

- Card 使用 `--yc-surface`、`--yc-border`、`--yc-radius-card`、`--yc-shadow-soft`。
- Interactive card hover 使用 `--yc-shadow-hover` 與最多 `translateY(-2px)`。
- Camp card 圖片應保留固定 aspect-ratio，避免 async content jumping。
- Card 內不再包另一層裝飾 card；只保留必要的內容分組。

### Form

- Input、select、textarea 使用 `--yc-control-height-md`、`--yc-radius-control`、`--yc-sage-light`。
- Focus 使用 `--yc-focus-ring`。
- Error 使用 `--yc-error-soft`、`--yc-error`、`--yc-error-text`，並在欄位附近顯示文字。
- Checkbox / radio accent 使用 `--yc-sage-action`。
- 每個輸入欄位都必須有可見標籤；若標籤文字視覺上隱藏，則必須提供關聯的 `aria-label`。
- 表單 label 不應只依賴 placeholder。
- 付款與結帳區塊應持續顯示使用者目前選擇的值。

### Header / Footer

- Header 使用 `--yc-header-bg`，文字使用 `--yc-on-dark`。
- Header hover 使用 `rgb(255 253 249 / 12%)` 或 `--yc-sage-dark` 的低強度變化。
- Footer 使用 `--yc-footer-bg`，bottom bar 使用 `--yc-footer-bottom`。
- 頁首控制項必須依照視覺順序維持鍵盤可達性。
- 僅有圖示的按鈕必須提供 `aria-label`。
- Dropdown、offcanvas、modal 必須遵守 z-index scale。
- Offcanvas 與 modal 開啟時必須鎖定焦點；關閉後必須將焦點還原至原本觸發的元素。

### Tags / Chips / Status

- Filter chip default：`--yc-surface` + `--yc-border` + `--yc-text-secondary`。
- Filter chip hover：`--yc-sage-soft` + `--yc-sage-light`。
- Selected chip：`--yc-sage-action` + `--yc-on-dark`。
- Status 不可只靠顏色區分，應搭配文字或 icon。
- 訂單、訂房、租借或評價狀態不可只依賴顏色來區分。

## AI 實作 Prompt

實作或檢查 Yuruicamp UI 時，請使用：

`請讀取 docs/ai-style-sheet.md 與 docs/ai-style-tokens.css，並以其中的 --yc-* token 作為主站與 booking 網站 source of truth。不要新增與 --yc-* 衝突的色彩系統；不要新增 --bk-* 或 --yui-* alias。請檢查互動元件是否有 44px touch target、可見 focus-visible、150ms 到 300ms motion、prefers-reduced-motion、WCAG AA 對比，以及 hover 不造成 layout shift。不要修改 HTML class 或 JavaScript selector，除非需求明確要求。`

## 檢查清單

- [ ] 使用 `--yc-*` token，不新增任意 hex 色。
- [ ] 沒有新增 `--bk-*` 或 `--yui-*` alias。
- [ ] Body 文字至少 `16px` 或等效 rem。
- [ ] 正文對比達 WCAG AA。
- [ ] CTA 使用 `--yc-on-cta` 文字。
- [ ] 所有 button、chip、input、select 觸控高度至少 `44px`。
- [ ] 所有互動元件有 hover、focus-visible、active、disabled 狀態。
- [ ] Focus ring 清楚可見。
- [ ] Hover 不 transition width、height、padding 或造成 layout shift。
- [ ] Motion 落在 `150ms` 到 `300ms`，大型 drawer / modal 可到 `320ms`。
- [ ] 支援 `prefers-reduced-motion`。
- [ ] Z-index 使用文件定義的 scale。
- [ ] Responsive 至少檢查 `375px`、`768px`、`1024px`、`1440px`。
- [ ] 新增的互動控制項不可使用 emoji 圖示。
