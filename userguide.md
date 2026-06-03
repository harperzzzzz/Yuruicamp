# Yuruicamp 開發者使用說明書（User Guide）

> 這份文件是給**開發者**看的工作手冊。  
> 不管是新加功能、改樣式、修 bug，都可以從這裡快速找到「要動哪個檔案」。

---

## 目錄

1. [專案資料夾全覽](#1-專案資料夾全覽)
2. [我要改 HTML 頁面 → `pages/`](#2-我要改-html-頁面--pages)
3. [我要改樣式 CSS → `css/`](#3-我要改樣式-css--css)
4. [我要改 JavaScript 邏輯 → `js/`](#4-我要改-javascript-邏輯--js)
5. [我要改假資料 → `data/`](#5-我要改假資料--data)
6. [我要改共用 HTML 片段 → `components/`](#6-我要改共用-html-片段--components)
7. [我要改多媒體資源 → `assets/`](#7-我要改多媒體資源--assets)
8. [快速任務查找表（最常用）](#8-快速任務查找表最常用)
9. [JS 全局函數速查](#9-js-全局函數速查)
10. [CSS 設計系統速查](#10-css-設計系統速查)
11. [開發流程建議](#11-開發流程建議)
12. [常見問題 FAQ](#12-常見問題-faq)

---

## 1. 專案資料夾全覽

```
Yuruicamp/                         ← 專案根目錄
│
├── index.html                     ← 入口頁（自動跳轉到 pages/home.html）
├── README.md                      ← 專案說明（給外部人看）
├── userguide.md                   ← 本文件（給開發者看）
├── .gitignore                     ← Git 忽略設定
│
├── pages/                         ← 所有功能 HTML 頁面（共 12 個）
├── css/                           ← 所有樣式檔案（SCSS 原始碼 + 編譯後 CSS）
├── js/                            ← 所有 JavaScript 邏輯
│   ├── components/                ← 跨頁面共用的 UI 元件 JS
│   └── pages/                    ← 每個頁面專屬的 JS
├── data/                          ← Mock 假資料（JSON 格式）
├── components/                    ← 共用 HTML 片段（navbar、footer）
├── assets/                        ← 圖片、影片等靜態資源
│   └── videos/
├── color/                         ← 品牌色彩規範文件
├── plans/                         ← 開發規劃文件
└── thought/                       ← 開發思考筆記
```

---

## 2. 我要改 HTML 頁面 → `pages/`

每個 `.html` 對應一個網站頁面。找到對應的頁面改就好。

| 檔案路徑 | 這是什麼頁面 | 對應的 JS |
|----------|------------|-----------|
| `pages/home.html` | 首頁（Hero Banner、精選商品） | `js/pages/home.js` |
| `pages/products.html` | 商品列表（網格、篩選、分頁） | `js/pages/product-list.js` |
| `pages/product-detail.html` | 商品詳情（圖集、規格、數量） | `js/pages/product-detail.js` |
| `pages/cart.html` | 購物車（品項增刪改查） | `js/pages/cart.js` |
| `pages/checkout.html` | 結帳（收件人表單、運費計算） | `js/pages/checkout.js` |
| `pages/checkout-success.html` | 結帳成功（訂單確認畫面） | —（靜態頁，無專屬 JS）|
| `pages/member-center.html` | 會員中心（訂單/折價券/通知） | `js/pages/member-center.js` |
| `pages/blog.html` | 部落格文章列表 | `js/pages/blog.js` |
| `pages/blog-detail.html` | 單篇文章詳情 + 內嵌商品卡 | `js/pages/blog-detail.js` |
| `pages/branches.html` | 分店地圖 + 合作店家 | `js/pages/branches.js` |
| `pages/faq.html` | 常見問題（Accordion + NPS 問卷） | `js/pages/faq.js` |
| `pages/verify.html` | 功能驗證清單（51 項測試） | 內嵌 script（獨立運作）|

> 💡 **注意**：每個 HTML 頁面底部都用 `<script>` 引入對應的 JS 檔，順序固定為：
> `config.js` → `api-mock.js` → `main.js` → `components/*.js` → `pages/xxx.js`

### 入口頁

| 檔案 | 說明 |
|------|------|
| `index.html` | 網站根入口，只有一行跳轉邏輯，不需要常改 |

---

## 3. 我要改樣式 CSS → `css/`

### 檔案分工

| 檔案 | 說明 | 什麼情況改這裡 |
|------|------|--------------|
| `css/variables.scss` | **所有設計 Token**：色彩、字體大小、間距、陰影、圓角、斷點 | 改品牌顏色、調整全站字體大小、修改陰影 |
| `css/base.scss` | CSS Reset + 全局基礎樣式（body、a、img、h1-h6 等） | 改全站預設字體、連結顏色、表格基礎樣式 |
| `css/components.scss` | **可重用 UI 元件**：按鈕 `.btn`、徽章 `.badge`、卡片 `.card`、Toast、Modal、表單等 | 改按鈕外觀、調整卡片陰影、修 Modal 樣式 |
| `css/layout.scss` | **佈局系統**：Navbar、Footer、Grid、Sidebar、Hero Section | 改 Navbar 高度/顏色、調整 Grid 欄位數 |
| `css/main.scss` | SCSS 入口檔，只負責 `@import` 上面四個檔，**不寫任何樣式** | 調整 import 順序時 |
| `css/main.css` | ⭐ **編譯後的最終 CSS**，瀏覽器實際讀取這個 | 直接在這裡改也可以（但建議改 .scss 後重新編譯）|

### 要改什麼樣式？找這裡

| 你想改… | 去哪個檔案 | 搜尋關鍵字 |
|---------|-----------|-----------|
| 品牌主色 `#244d4d` | `variables.scss` | `$primary` |
| 按鈕樣式（`.btn-primary`） | `components.scss` | `.btn-primary` |
| 商品卡片外觀 | `components.scss` | `.product-card` |
| Navbar 高度 / 背景色 | `layout.scss` | `.navbar` |
| Footer 樣式 | `layout.scss` | `.footer` |
| 手機版 RWD 斷點 | `variables.scss` | `$sm` / `$md` / `$lg` |
| Toast 提示框樣式 | `components.scss` | `.toast` |
| Modal 對話框樣式 | `components.scss` | `.modal` |
| 表單輸入框 | `components.scss` | `.form-control` |
| Hero Banner 區塊 | `layout.scss` | `.hero` |
| 全域字體設定 | `variables.scss` | `$font-family-base` |
| 頁面最大寬度 | `layout.scss` | `.container` |
| Z-index 層級 | `variables.scss` | `$z-modal` / `$z-navbar` |

### SCSS 變數對應表（最常用）

```scss
/* 色彩 */
$primary: #244d4d          /* 品牌深青綠，用於按鈕、連結 */
$secondary: #779999        /* 淺青灰綠，用於次要元素 */
$danger: #d32f2f           /* 紅色，刪除/錯誤 */
$success: #4caf50          /* 綠色，成功訊息 */

/* 斷點（手機優先 mobile-first） */
$sm: 576px                 /* 大型手機 */
$md: 768px                 /* 平板 iPad */
$lg: 992px                 /* 筆電 */
$xl: 1200px                /* 桌機 */

/* 間距 */
$spacing-sm: 0.5rem        /* 8px */
$spacing: 1rem             /* 16px（基礎單位） */
$spacing-xl: 1.5rem        /* 24px */
$spacing-2xl: 2rem         /* 32px */
```

---

## 4. 我要改 JavaScript 邏輯 → `js/`

### 核心檔案（每頁都會載入）

| 檔案 | 說明 | 什麼情況改這裡 |
|------|------|--------------|
| `js/config.js` | **全局狀態（AppState）+ 全局設定（AppConfig）**<br>包含登入狀態、購物車、API 網址、免運門檻等 | 改 API 網址、調整免運門檻金額、修改版本號 |
| `js/api-mock.js` | **Mock API 層**，所有頁面都透過 `window.API.xxx()` 取得資料，資料來源是 `data/*.json` | 改資料邏輯（篩選/排序）、日後切換真實後端 API |
| `js/main.js` | **應用初始化**，負責啟動 Navbar、Modal、購物車、Lazy Loading Fallback、Scroll Lock | 加新的全局事件監聽、修初始化順序問題 |

### 元件 JS（`js/components/`）跨頁複用

| 檔案 | 說明 | 什麼情況改這裡 |
|------|------|--------------|
| `js/components/navbar.js` | Navbar 互動（漢堡選單開關、Offcanvas 手機版） | 改 Navbar 點擊行為、修漢堡選單動畫 |
| `js/components/modal.js` | Modal 對話框（登入 Modal + 個人化問卷 Stepper） | 修登入流程、改問卷步驟 |
| `js/components/cart.js` | 購物車 Badge 更新、加入/移除商品邏輯 | 改購物車計算邏輯、修 Badge 不更新的 bug |
| `js/components/toast.js` | Toast 提示（右下角彈出的成功/錯誤訊息） | 改提示持續時間、修改位置 |
| `js/components/carousel.js` | 品牌輪播（CSS animation 驅動） | 改輪播速度、新增輪播項目 |
| `js/components/filter.js` | 商品篩選器（CustomEvent 驅動，解耦合） | 修篩選邏輯、新增篩選條件 |

### 頁面 JS（`js/pages/`）每頁獨立

| 檔案 | 說明 | 什麼情況改這裡 |
|------|------|--------------|
| `js/pages/home.js` | 首頁：精選商品渲染、「加入購物車」按鈕 | 改首頁商品顯示數量、修加入購物車 bug |
| `js/pages/product-list.js` | 商品列表：網格渲染、分頁切換 | 改每頁顯示幾個商品、修分頁 bug |
| `js/pages/product-detail.js` | 商品詳情：縮圖點擊切換大圖、數量 Stepper | 改圖集互動、修規格選擇 bug |
| `js/pages/cart.js` | 購物車頁：品項列表渲染、數量增減、刪除 | 改購物車 UI 邏輯、修未登入攔截行為 |
| `js/pages/checkout.js` | 結帳：手風琴表單、運費即時計算 | 改結帳表單欄位、修運費計算邏輯 |
| `js/pages/member-center.js` | 會員中心：訂單歷史、評價、折價券、通知 Tab | 改 Tab 切換邏輯、新增會員功能區塊 |
| `js/pages/blog.js` | 部落格列表：文章卡片動態渲染 | 改文章排版、新增分類篩選 |
| `js/pages/blog-detail.js` | 文章詳情：內嵌商品導購卡片 | 改文章版面、修相關商品卡片邏輯 |
| `js/pages/branches.js` | 分店地圖：Google Maps iframe 切換、合作店家 Modal | 改地圖嵌入網址、新增分店 |
| `js/pages/faq.js` | FAQ：Accordion 開關、NPS 問卷送出 | 改 Accordion 動畫、修 NPS 送出行為 |

---

## 5. 我要改假資料 → `data/`

這裡是所有的模擬資料，都是 JSON 格式，可以直接用文字編輯器修改。

| 檔案 | 說明 | 資料結構 |
|------|------|---------|
| `data/products.json` | **商品資料**（50+ 筆），包含名稱、價格、圖片、分類、規格 | `[{ id, name, price, category, image, specs, ... }]` |
| `data/users.json` | **模擬用戶**，用於登入測試 | `[{ id, email, password, name, ... }]` |
| `data/orders.json` | **訂單資料**，會員中心顯示用 | `[{ id, userId, items, total, status, ... }]` |
| `data/articles.json` | **部落格文章**（標題、內文、標籤、圖片） | `[{ id, title, content, tags, image, ... }]` |
| `data/branches.json` | **分店資訊**（店名、地址、Google Maps 連結）+ 合作店家 | `[{ id, name, address, mapUrl, partners: [...] }]` |

> 💡 **如何新增商品？** 打開 `data/products.json`，複製一筆資料，改掉 `id`（要唯一）、`name`、`price`、`image` 等欄位，存檔即可。頁面會自動讀取。

---

## 6. 我要改共用 HTML 片段 → `components/`

這裡放的是「所有頁面都一樣」的區塊。

| 檔案 | 說明 | 注意事項 |
|------|------|---------|
| `components/navbar.html` | Navbar 的 HTML 結構（含漢堡選單） | 改這裡，所有頁面 Navbar 都會變 |
| `components/footer.html` | Footer 的 HTML 結構 | 改這裡，所有頁面 Footer 都會變 |

> ⚠️ **重要**：這兩個檔案是「參考用的靜態範本」，實際上每個 `pages/*.html` 內都有直接內嵌的 Navbar/Footer HTML。如果要改 Navbar/Footer，**每個頁面都要同步手動更新**，或改用 JS 動態注入。

---

## 7. 我要改多媒體資源 → `assets/`

| 路徑 | 說明 |
|------|------|
| `assets/videos/hero_video.mp4` | 首頁 Hero Banner 的背景影片 |

> 💡 商品圖片目前使用的是外部 CDN 網址（`picsum.photos` / `via.placeholder.com`），定義在 `data/products.json` 的 `image` 欄位。替換成真實圖片只需改 JSON 的 `image` 欄位網址。

---

## 8. 快速任務查找表（最常用）

> 直接查這張表，找到任務後去對應檔案。

| 我想做的事 | 去哪裡改 |
|-----------|---------|
| 改品牌主色 | `css/variables.scss` → `$primary` |
| 改按鈕顏色/圓角 | `css/components.scss` → `.btn-primary` |
| 改 Navbar 背景色 | `css/layout.scss` → `.navbar` |
| 改 Navbar 互動行為 | `js/components/navbar.js` |
| 首頁精選商品顯示幾個 | `js/pages/home.js` |
| 商品列表每頁幾筆 | `js/pages/product-list.js` |
| 新增 / 修改商品資料 | `data/products.json` |
| 新增 / 修改分店資訊 | `data/branches.json` |
| 新增 / 修改文章 | `data/articles.json` |
| 改 Toast 提示樣式 | `css/components.scss` → `.toast` |
| 改 Toast 提示行為 | `js/components/toast.js` |
| 改 Modal 樣式 | `css/components.scss` → `.modal` |
| 改登入 Modal 行為 | `js/components/modal.js` |
| 改購物車計算邏輯 | `js/components/cart.js` |
| 改結帳表單欄位 | `pages/checkout.html` + `js/pages/checkout.js` |
| 改免運費門檻金額 | `js/config.js` → `AppConfig.CART.FREE_SHIPPING_THRESHOLD` |
| 改 API 伺服器網址 | `js/config.js` → `AppConfig.API_BASE_URL` |
| 切換真實後端 API | `js/api-mock.js`（把 fetch JSON 改成 fetch 真實 API）|
| 改 FAQ 內容 | `pages/faq.html`（直接改 HTML 的 Accordion 內容）|
| 改 Footer 內容 | 每個 `pages/*.html` 裡的 footer 區塊 |
| 新增一個全新頁面 | 新增 `pages/xxx.html` + `js/pages/xxx.js`，並在 Navbar 加連結 |
| 改手機版 RWD 斷點 | `css/variables.scss` → `$sm` / `$md` / `$lg` |
| 改動畫速度 | `css/variables.scss` → `$transition-base` |

---

## 9. JS 全局函數速查

以下函數都掛在 `window` 上，任何 JS 檔都可以直接呼叫。

### 應用狀態（定義於 `js/config.js`）

```javascript
window.AppState.isLoggedIn          // Boolean - 使用者是否已登入
window.AppState.currentUser         // Object  - 當前用戶資料（null 表示未登入）
window.AppState.cart                // Array   - 購物車商品列表
window.AppState.preferences         // Object  - 個人化問卷結果

window.saveAppState()               // 把 AppState 存進 localStorage（記得改完要呼叫）
window.resetAppState()              // 清除所有狀態 + localStorage（等同登出並清空購物車）
```

### Mock API（定義於 `js/api-mock.js`）

```javascript
// 都是 async 函數，要用 await 呼叫
await window.API.products.getAll(filters)       // 取得商品列表
await window.API.products.getById(productId)    // 取得單一商品

await window.API.users.login(email, password)   // 登入（回傳用戶資料或 null）
await window.API.users.getProfile(userId)       // 取得用戶資料

await window.API.orders.getAll(userId)          // 取得用戶的所有訂單
await window.API.orders.create(orderData)       // 建立新訂單

await window.API.articles.getAll()              // 取得所有文章
await window.API.articles.getById(articleId)   // 取得單篇文章

await window.API.branches.getAll()              // 取得所有分店資料
```

### 購物車（定義於 `js/components/cart.js`）

```javascript
window.addToCart(product, quantity)         // 加入購物車（product 是商品物件）
window.removeFromCart(productId)            // 從購物車移除
window.updateCartQuantity(productId, qty)   // 更新某商品的數量
window.clearCart()                          // 清空整個購物車
window.calculateCartTotal()                 // 計算購物車總金額（回傳數字）
window.calculateShippingFee(total)          // 計算運費（滿門檻回傳 0，否則回傳 60）
```

### UI 元件（定義於各 components JS）

```javascript
window.showToast(message, type)   // 顯示 Toast 提示
// type 可以是 'success' | 'error' | 'warning' | 'info'
// 範例：window.showToast('已加入購物車', 'success')

window.openModal(modalId)         // 開啟 Modal（帶入 HTML 元素的 id）
window.closeModal(modalId)        // 關閉 Modal
// 範例：window.openModal('loginModal')
```

### 工具函數（定義於 `js/config.js`）

```javascript
window.formatCurrency(3500)           // → 'NT$3,500'（金額格式化）
window.formatDate('2026-06-03')       // → '2026/06/03'（日期格式化）
window.generateId()                   // → 產生唯一 ID 字串
window.isValidEmail('a@b.com')        // → true / false（驗證 Email 格式）
window.isValidPhone('0912345678')     // → true / false（驗證手機號碼）
window.debounce(fn, 300)              // 防抖：連續觸發只執行最後一次（搜尋框用）
window.throttle(fn, 100)              // 節流：固定間隔最多執行一次（滾動事件用）
```

---

## 10. CSS 設計系統速查

### 常用 CSS Class 清單

> 這些 class 都已定義在 `css/components.scss` 或 `css/layout.scss`，可以直接在 HTML 裡使用。

**按鈕**

| Class | 樣式 |
|-------|------|
| `.btn` | 按鈕基礎樣式（必須搭配下面的變體） |
| `.btn-primary` | 品牌綠色實心按鈕 |
| `.btn-secondary` | 淺青灰綠按鈕 |
| `.btn-outline-primary` | 綠色外框按鈕（透明背景） |
| `.btn-danger` | 紅色刪除按鈕 |
| `.btn-sm` | 小型按鈕 |
| `.btn-lg` | 大型按鈕 |

**卡片**

| Class | 樣式 |
|-------|------|
| `.card` | 卡片容器（白色背景 + 陰影 + 圓角） |
| `.card-img` | 卡片頂部圖片 |
| `.card-body` | 卡片內容區 |
| `.product-card` | 商品專用卡片（含 hover 效果） |

**排版工具**

| Class | 說明 |
|-------|------|
| `.container` | 頁面最大寬度容器（自動水平置中） |
| `.grid-cols-2` | 2 欄 Grid |
| `.grid-cols-3` | 3 欄 Grid |
| `.grid-cols-4` | 4 欄 Grid |

**狀態顏色**

| Class | 說明 |
|-------|------|
| `.text-primary` | 品牌綠色文字 |
| `.text-danger` | 紅色文字（錯誤、必填提示） |
| `.text-muted` | 灰色淡化文字（次要資訊） |
| `.badge` | 徽章基礎（數量標示） |
| `.badge-primary` | 品牌綠色徽章 |

### 色彩規範（所有顏色定義於 `css/variables.scss`）

| 用途 | SCSS 變數 | 色碼 | 說明 |
|------|-----------|------|------|
| 主色 | `$primary` | `#244d4d` | 品牌深青綠，主要按鈕、連結 |
| 副色 | `$secondary` | `#779999` | 淺青灰綠，次要按鈕 |
| 成功 | `$success` | `#4caf50` | 成功 Toast、勾選狀態 |
| 警告 | `$warning` | `#ff9800` | 警告提示 |
| 危險 | `$danger` | `#d32f2f` | 刪除按鈕、錯誤訊息 |
| 資訊 | `$info` | `#2196f3` | 資訊提示 |
| 輕背景 | `$light-bg` | `#f6fbf6` | 頁面淺綠背景色 |
| 懸停 | `$dark-hover` | `#316868` | 按鈕 hover 狀態 |

---

## 11. 開發流程建議

### 新增一個功能的標準流程

```
1. 確認功能屬於哪個頁面
   → 找到 pages/xxx.html（HTML 結構）
   → 找到 js/pages/xxx.js（互動邏輯）

2. 需要新資料？
   → 先在 data/*.json 新增測試資料
   → 確認 api-mock.js 的對應函數能讀到資料

3. 寫 HTML 結構
   → 先在 HTML 刻好靜態版面（不用管 JS）

4. 寫 CSS 樣式
   → 純樣式 → components.scss 或 layout.scss
   → 顏色/間距用 variables.scss 的變數，不要直接寫死顏色值

5. 寫 JS 邏輯
   → 在對應的 pages/xxx.js 實作
   → 全局功能（Toast、Modal、購物車）直接呼叫 window.xxx() 函數

6. 測試
   → 打開 pages/verify.html 確認沒有破壞既有功能
   → 手機瀏覽器或 DevTools 手機模式測試 RWD
```

### 修改 SCSS 樣式的流程

目前 `css/main.css` 是「已編譯好的 CSS」，瀏覽器讀的是這個：

- **方法 A（直接改 main.css）**：快速但不建議長期使用，下次編譯 SCSS 會被覆蓋
- **方法 B（改 .scss 後編譯）**：正確做法
  ```bash
  # 安裝 sass（只需一次）
  npm install -g sass
  
  # 在 css/ 目錄下執行，把 main.scss 編譯成 main.css
  sass main.scss main.css
  
  # 或開啟監聽模式（改 scss 自動重新編譯）
  sass --watch main.scss:main.css
  ```

---

## 12. 常見問題 FAQ

**Q：為什麼 JSON 資料讀不到？出現 CORS 錯誤？**  
A：不能直接點兩下開 HTML 檔案。要用本機伺服器：
- VS Code 安裝 Live Server 擴充套件，右鍵 → Open with Live Server
- 或 `python -m http.server 8000`

---

**Q：我改了 JS，但頁面沒有變化？**  
A：按 `Ctrl + Shift + R`（強制清除快取重整），或開 DevTools → Network → 勾選 Disable Cache。

---

**Q：加入購物車沒反應？**  
A：打開 DevTools → Console，看有沒有錯誤訊息。常見原因：
1. 商品資料的 `id` 欄位是 undefined → 檢查 `data/products.json` 的 id 欄位
2. `window.addToCart` 未載入 → 確認 HTML 有引入 `js/components/cart.js`

---

**Q：Navbar 在手機上點了沒反應？**  
A：確認 HTML 有引入 `js/components/navbar.js`，且 CSS 的 `.navbar-offcanvas` 樣式有正確載入。

---

**Q：要怎麼換掉 Mock 假資料，接真實後端？**  
A：只需改一個檔案：`js/api-mock.js`。  
把每個函數裡的 `fetch('../data/xxx.json')` 改成 `fetch(AppConfig.API_BASE_URL + '/xxx')`。  
頁面 JS 完全不需要動，因為它們都是透過 `window.API.xxx()` 呼叫，不管底層怎麼實作。

---

**Q：新頁面要怎麼設定？**  
A：複製任一現有的 `pages/*.html`，修改 `<title>` 和 body 內容，並在底部把頁面 JS 換成你的新 JS 檔案。注意 `<script src>` 的相對路徑要用 `../js/` 開頭（因為在 pages/ 子目錄下）。

---

**最後更新**：2026/06/03  
**對應版本**：v1.0.2
