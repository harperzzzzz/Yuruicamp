# Yuruicamp Booking AI Style Sheet

**適用範圍** Booking website  
**最後更新** 2026-07-02  
**用途** 提供 AI 與開發者建立、檢查、延伸 booking 頁面時使用的 style token 與 UI 規則。此文件只作為設計規格，不會被任何 HTML、CSS、JS 匯入。

---

## 概要

Booking 網站採用「soft outdoor lifestyle commerce」方向：溫和戶外、露營旅宿、可安心完成預訂的商務介面。視覺基底維持現有 sage / cream / warm gold 系統，不引入與目前網站衝突的黑金、藍橘或高彩度旅遊平台色系。

本文件格式對齊 `docs/ai-style-sheet.md`：先定義設計原則，再列出 token 表、字體、布局、元件規則、AI prompt 與檢查清單。若日後要實作，應從此文件抽取 token 到 CSS，而不是直接把本 Markdown 當 stylesheet 引入。

## 設計原則

* 使用 `--yc-*` 作為 booking 網站的 source of truth。
* `--bk-*` 只作為 booking 現有 selector 的相容 alias，不應獨立漂移。
* `--yui-*` 目前屬於 member center 系統，若要合併進 booking token，需先做命名與色彩審核。
* CTA 使用 warm gold，但文字必須使用 `--yc-on-cta`，避免白字金底造成對比不足。
* 互動元件最小觸控高度為 `44px`。
* Hover 狀態只能使用 color、border、shadow、opacity、transform，不應使用 width / padding transition 造成 layout shift。
* Focus 狀態必須可見；只有在搭配 focus ring 時才允許移除 default outline。
* Motion 必須支援 `prefers-reduced-motion`。

## 核心 Token

| Token | 值 | 用途 |
| --- | ---: | --- |
| `--yc-bg` | `#f8f5ee` | Booking 頁面主背景 |
| `--yc-surface` | `#fffdf9` | Card、panel、modal、form surface |
| `--yc-surface-soft` | `#f0ece3` | 次層背景、區塊底色 |
| `--yc-border` | `#d8cfc3` | 預設邊線 |
| `--yc-sage-soft` | `#eef2ec` | chip、tag、filter、hover soft 背景 |
| `--yc-sage-light` | `#b7c3b3` | hover border、低強度品牌色 |
| `--yc-sage-action` | `#73816e` | 主品牌 action、header |
| `--yc-sage-dark` | `#62705d` | 深色品牌、footer bottom |
| `--yc-cta-soft` | `#fbf3d1` | CTA soft background |
| `--yc-cta-line` | `#d9c98f` | CTA soft border |
| `--yc-cta` | `#e2d39a` | Conversion CTA |
| `--yc-cta-hover` | `#d4c27e` | CTA hover / active |
| `--yc-on-cta` | `#4a4537` | CTA 文字 |
| `--yc-text` | `#3e473d` | 主要文字 |
| `--yc-text-secondary` | `#625e56` | 次要文字 |
| `--yc-text-muted` | `#7b756d` | 輔助文字、disabled、metadata |
| `--yc-on-dark` | `#fffdf9` | 深色背景文字 |
| `--yc-on-dark-muted` | `rgb(255 253 249 / 76%)` | 深色背景輔助文字 |

## 狀態 Token

| Token | 值 | 用途 |
| --- | ---: | --- |
| `--yc-success-soft` | `#e7efe3` | 成功狀態背景 |
| `--yc-success` | `#73816e` | 成功主色 |
| `--yc-success-text` | `#4f624a` | 成功文字 |
| `--yc-warning-soft` | `#f4ece2` | 警告背景 |
| `--yc-warning` | `#9a7455` | 警告主色 |
| `--yc-warning-text` | `#6b4d32` | 警告文字 |
| `--yc-error-soft` | `#f4e7e4` | 錯誤背景 |
| `--yc-error` | `#a65f58` | 錯誤主色 |
| `--yc-error-text` | `#8a4842` | 錯誤文字 |

## 結構 Token

| Token | 值 | 用途 |
| --- | ---: | --- |
| `--yc-header-bg` | `#73816e` | Booking header |
| `--yc-header-bg-solid` | `#62705d` | 深色 header fallback |
| `--yc-header-border` | `rgb(255 253 249 / 14%)` | Header bottom border |
| `--yc-footer-bg` | `#71806d` | Footer 主背景 |
| `--yc-footer-bottom` | `#62705d` | Footer bottom bar |
| `--yc-header-height` | `64px` | Header 高度 |
| `--yc-sticky-offset` | `90px` | Sticky sidebar / booking card offset |
| `--yc-container-sm` | `900px` | FAQ、窄內容 |
| `--yc-container-md` | `1100px` | Checkout、cart |
| `--yc-container-lg` | `1200px` | Search、detail、rental |
| `--yc-container-page` | `min(1200px, calc(100vw - 48px))` | 頁面主要容器 |

## 字體與排版

| Token | 值 | 用途 |
| --- | ---: | --- |
| `--yc-font-heading` | `"Noto Serif TC", "Source Han Serif TC", serif` | Hero、section heading、品牌語氣 |
| `--yc-font-body` | `"Noto Sans TC", "Source Han Sans TC", system-ui, sans-serif` | 內文、表單、列表 |
| `--yc-font-ui` | `"Noto Sans TC", "Source Han Sans TC", system-ui, sans-serif` | Button、chip、tab、nav |
| `--yc-text-xs` | `0.75rem` | Caption、helper text |
| `--yc-text-sm` | `0.875rem` | Label、metadata、chip |
| `--yc-text-md` | `1rem` | Body、form control |
| `--yc-text-lg` | `1.125rem` | Card title、section intro |
| `--yc-text-xl` | `1.25rem` | Panel heading |
| `--yc-text-2xl` | `1.5rem` | Page heading |
| `--yc-text-3xl` | `1.875rem` | Hero subtitle / major section |
| `--yc-text-4xl` | `2.25rem` | Hero title |

* Body line-height 使用 `1.5` 到 `1.8`。
* 表單與 UI 文字使用 sans-serif，避免 serif 在密集操作介面降低掃描效率。
* Heading 可保留 serif，維持 Yuruicamp 的溫和戶外品牌感。
* Button、chip、filter、tab 建議 `600` 到 `700`，不要使用過重的 `900`。

## 間距、圓角、陰影

| Token | 值 | 用途 |
| --- | ---: | --- |
| `--yc-space-1` | `4px` | 最小 gap |
| `--yc-space-2` | `8px` | Icon gap、small inset |
| `--yc-space-3` | `12px` | Compact padding |
| `--yc-space-4` | `16px` | Base spacing |
| `--yc-space-6` | `24px` | Card / grid gap |
| `--yc-space-8` | `32px` | Section compact |
| `--yc-space-12` | `48px` | Section gap |
| `--yc-space-16` | `64px` | Page section |
| `--yc-space-24` | `96px` | Large hero / footer spacing |
| `--yc-radius-control` | `12px` | Input、select、button secondary shape |
| `--yc-radius-button` | `12px` | Button |
| `--yc-radius-card` | `19px` | Camp card、summary card |
| `--yc-radius-section` | `24px` | Large content band |
| `--yc-radius-modal` | `8px` | Modal / dialog |
| `--yc-radius-pill` | `9999px` | Chip、badge、pill button |
| `--yc-shadow-soft` | `0 5px 20px rgb(60 70 59 / 6.5%)` | Default card |
| `--yc-shadow-hover` | `0 16px 38px rgb(60 70 59 / 13%)` | Interactive card hover |
| `--yc-shadow-cta` | `0 8px 22px rgb(129 111 54 / 14%)` | Conversion CTA |
| `--yc-shadow-modal` | `0 24px 60px rgb(0 0 0 / 22%)` | Modal、drawer |

## 動態與互動

| Token | 值 | 用途 |
| --- | ---: | --- |
| `--yc-duration-instant` | `80ms` | Press feedback |
| `--yc-duration-fast` | `180ms` | Hover、focus |
| `--yc-duration-normal` | `220ms` | Card、drawer micro-interaction |
| `--yc-duration-slow` | `320ms` | Drawer / modal transition |
| `--yc-ease-soft` | `cubic-bezier(0.2, 0.7, 0.2, 1)` | Soft outdoor motion |
| `--yc-ease-standard` | `cubic-bezier(0.4, 0, 0.2, 1)` | Modal、drawer |
| `--yc-target-min` | `44px` | Touch target minimum |
| `--yc-icon-button-size` | `44px` | Icon button |
| `--yc-control-height-md` | `44px` | Input / select |
| `--yc-focus-ring` | `0 0 0 3px rgb(115 129 110 / 24%)` | Default keyboard focus |
| `--yc-focus-ring-strong` | `0 0 0 4px rgb(115 129 110 / 30%)` | Modal / high-risk action focus |

* Hover 可以讓 card `translateY(-2px)`，但不得 scale 到影響排版。
* Floating button 展開文字時應使用固定容器搭配 opacity / transform，不應 transition width。
* 所有 `outline: none` 必須搭配 `box-shadow: var(--yc-focus-ring)` 或等效 focus ring。
* Loading 狀態應 disable button，避免重複送出 booking / checkout 行為。

## Z-index Scale

| Token | 值 | 用途 |
| --- | ---: | --- |
| `--yc-z-base` | `0` | Default |
| `--yc-z-raised` | `10` | Raised card、hero overlay |
| `--yc-z-sticky` | `100` | Sticky filter / booking card |
| `--yc-z-header` | `1000` | Header |
| `--yc-z-dropdown` | `1100` | User dropdown |
| `--yc-z-floating` | `1200` | Floating actions |
| `--yc-z-offcanvas-backdrop` | `1990` | Offcanvas backdrop |
| `--yc-z-offcanvas` | `2000` | Mobile menu / side panel |
| `--yc-z-modal-backdrop` | `2990` | Modal backdrop |
| `--yc-z-modal` | `3000` | Modal |
| `--yc-z-toast` | `3100` | Toast |

## Booking Alias Token

`--bk-*` 是相容層，不是新的 source token。若需要保留現有 selector 命名，可使用下列 mapping：

| Alias | Source |
| --- | --- |
| `--bk-primary` | `var(--yc-sage-action)` |
| `--bk-primary-hover` | `var(--yc-sage-action)` |
| `--bk-primary-light` | `var(--yc-sage-soft)` |
| `--bk-on-dark` | `var(--yc-on-dark)` |
| `--bk-cta` | `var(--yc-cta)` |
| `--bk-cta-hover` | `var(--yc-cta-hover)` |
| `--bk-white` | `var(--yc-surface)` |
| `--bk-bg` | `var(--yc-bg)` |
| `--bk-card-bg` | `var(--yc-surface)` |
| `--bk-border` | `var(--yc-border)` |
| `--bk-border-strong` | `var(--yc-sage-action)` |
| `--bk-text` | `var(--yc-text)` |
| `--bk-text-muted` | `var(--yc-text-muted)` |
| `--bk-accent` | `var(--yc-sage-action)` |
| `--bk-gold` | `var(--yc-on-cta)` |
| `--bk-sage` | `var(--yc-sage-light)` |
| `--bk-orange` | `var(--yc-warning)` |
| `--bk-success` | `var(--yc-success)` |
| `--bk-danger` | `var(--yc-error)` |
| `--bk-shadow` | `var(--yc-shadow-soft)` |
| `--bk-shadow-hover` | `var(--yc-shadow-hover)` |
| `--bk-radius` | `var(--yc-radius-card)` |
| `--bk-radius-sm` | `var(--yc-radius-control)` |

## 元件規則

### Button

* Conversion CTA：`--yc-cta` 背景、`--yc-on-cta` 文字、`--yc-shadow-cta` 陰影。
* Brand action：`--yc-sage-action` 背景、`--yc-on-dark` 文字。
* Secondary action：`--yc-surface` 背景、`--yc-sage-action` 文字、`--yc-border` 邊線。
* Danger action：`--yc-error` 背景、`--yc-on-dark` 文字。
* Button 高度不得低於 `--yc-target-min`。
* Icon-only button 使用 `--yc-icon-button-size`，並需要 accessible label。

### Card

* Card 使用 `--yc-surface`、`--yc-border`、`--yc-radius-card`、`--yc-shadow-soft`。
* Interactive card hover 使用 `--yc-shadow-hover` 與最多 `translateY(-2px)`。
* Camp card 圖片應保留固定 aspect-ratio，避免 async content jumping。
* Card 內不再包另一層裝飾 card；只保留必要的內容分組。

### Form

* Input、select、textarea 使用 `--yc-control-height-md`、`--yc-radius-control`、`--yc-sage-light`。
* Focus 使用 `--yc-focus-ring`。
* Error 使用 `--yc-error-soft`、`--yc-error`、`--yc-error-text`，並在欄位附近顯示文字。
* Checkbox / radio accent 使用 `--yc-sage-action`。
* 表單 label 不應只依賴 placeholder。

### Header / Footer

* Header 使用 `--yc-header-bg`，文字使用 `--yc-on-dark`。
* Header hover 使用 `rgb(255 253 249 / 12%)` 或 `--yc-sage-dark` 的低強度變化。
* Footer 使用 `--yc-footer-bg`，bottom bar 使用 `--yc-footer-bottom`。
* Dropdown、offcanvas、modal 必須遵守 z-index scale。

### Tags / Chips / Status

* Filter chip default：`--yc-surface` + `--yc-border` + `--yc-text-secondary`。
* Filter chip hover：`--yc-sage-soft` + `--yc-sage-light`。
* Selected chip：`--yc-sage-action` + `--yc-on-dark`。
* Status 不可只靠顏色區分，應搭配文字或 icon。

## AI 撖虫 Prompt

實作或檢查 booking 頁面時，請使用：

`請讀取 booking/booking-style-tokens.md，並以其中的 --yc-* token 作為 booking 網站 source of truth。不要新增與 --yc-* 衝突的色彩系統；--bk-* 只能作為相容 alias。請檢查互動元件是否有 44px touch target、可見 focus-visible、150ms 到 300ms motion、prefers-reduced-motion、WCAG AA 對比，以及 hover 不造成 layout shift。不要修改 HTML class 或 JavaScript selector，除非需求明確要求。`

## 檢查清單

* [ ] Booking 頁面使用 `--yc-*` token，不新增任意 hex 色。
* [ ] `--bk-*` alias 沒有脫離 `--yc-*` source。
* [ ] Body 文字至少 `16px` 或等效 rem。
* [ ] 正文對比達 WCAG AA。
* [ ] CTA 使用 `--yc-on-cta` 文字。
* [ ] 所有 button、chip、input、select 觸控高度至少 `44px`。
* [ ] 所有互動元件有 hover、focus-visible、active、disabled 狀態。
* [ ] Focus ring 清楚可見。
* [ ] Hover 不 transition width、height、padding 或造成 layout shift。
* [ ] Motion 落在 `150ms` 到 `300ms`，大型 drawer / modal 可到 `320ms`。
* [ ] 支援 `prefers-reduced-motion`。
* [ ] Z-index 使用文件定義的 scale。
* [ ] Responsive 至少檢查 `375px`、`768px`、`1024px`、`1440px`。
* [ ] 不使用 emoji 當 UI icon。
