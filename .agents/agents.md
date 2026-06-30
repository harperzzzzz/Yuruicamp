請先讀取：
* `docs/ai-style-sheet.md`
* `docs/ai-style-tokens.css`
* `components/header.partial`
* `scss/components/_header.scss`
* `js/components/header.js`
* `js/components/modal.js`
* `js/components/auth.js`
* `js/components/cart.js`
* `js/main.js`
* `pages/home.html`
* 與搜尋結果導向相關的商品列表 JS、產品 API 或 mock API 檔案
* css/componenets/content/pages 裡面所有scss 檔案
* pages 裡面所有html 檔案
* 與home.html 有相關的js 檔案
* products.html 有相關的js 檔案

## 任務
* 使用$frontend-design skill 執行以下1.~8.的任務:

目前 `header.partial` 已被 `main.js` 動態注入 `home.html`，且漢堡選單與購物車已正常運作；但登入、搜尋、使用者下拉選單全部失效。

不要重構 `header.partial` 的既有 `site*` class 命名，不要改動購物車既有資料流程、`AppState`、localStorage key、`YuruiAuth` 資料契約、首頁商品載入流程或 `cart.js` 的既有功能。不要建立第二套 Header 系統，也不要把功能寫進 `home.js`。

## 主要目標
補齊並統一 `header.js` 的新版 Header 互動邏輯，使其完全支援目前 `header.partial` 使用的 class、id、`hidden` 與 `isOpen` 狀態。

所有初始化必須在 Header partial 注入完成後執行，且可安全重複呼叫，不得重複綁定事件。

---

## 1. 登入視窗

目前登入按鈕為：

```html
<button class="siteLoginButton" type="button" data-modal-target="loginModal">
```

請在 `header.js` 或適當的共用初始化邏輯中：

1. 綁定所有 `[data-modal-target]` 按鈕。
2. 點擊 `.siteLoginButton` 時呼叫既有 `window.openModal('loginModal')`。
3. 不要複製、重寫或取代 `modal.js` 內既有的社群登入流程。
4. 確保登入視窗關閉按鈕、Backdrop 點擊、Escape 關閉仍由既有 `modal.js` 處理。
5. 不要使用舊版 `.active` 狀態；Modal 必須維持 `.modal.isOpen` 契約。

---

## 2. 登入狀態與會員下拉選單

目前 Header 使用：

* `.siteLoginButton`
* `.siteUserMenu[hidden]`
* `.siteUserTrigger`
* `.siteUserDropdown[hidden]`
* `.siteUserAvatar`
* `.siteUserName`
* `.siteLogoutButton`

請實作或修正 `window.updateNavbarLoginState()`，使其：

1. 透過既有 `window.YuruiAuth.getUser()` 取得目前會員；若不可用，再相容讀取 `window.AppState.currentUser`。
2. 未登入時：

   * 顯示 `.siteLoginButton`
   * 設定 `.siteUserMenu.hidden = true`
   * 關閉 `.siteUserDropdown`
3. 已登入時：

   * 隱藏 `.siteLoginButton`
   * 設定 `.siteUserMenu.hidden = false`
   * 顯示會員名稱
   * 顯示使用者名稱第一個字作為 `.siteUserAvatar` 內容
4. 初始化 Header 後立刻執行一次登入狀態更新。
5. 監聽既有 `yurui:auth-changed` 事件，登入或登出後立即更新 Header。
6. `.siteUserTrigger` 點擊時切換 `.siteUserDropdown.hidden`，並同步更新 `aria-expanded`。
7. 點擊頁面其他區域、按 Escape、開啟搜尋、開啟漢堡選單或開啟購物車時，關閉會員下拉選單。
8. `.siteLogoutButton` 點擊時呼叫既有 `window.logout()` 或 `window.YuruiAuth.logout()`；不可自行刪除或改名現有 localStorage key。
9. 登出後關閉會員下拉選單、重新顯示登入按鈕。

---

## 3. 搜尋功能

目前搜尋元件為：

* `.siteSearchToggle`
* `#siteSearchForm[hidden]`
* `.siteSearchInput`
* `.siteSearchSubmit`
* `.siteSearchDropdown[hidden]`

請實作以下互動：

1. 點擊 `.siteSearchToggle`：

   * 切換 `#siteSearchForm.hidden`
   * 同步 `aria-expanded`
   * 開啟後自動 focus `.siteSearchInput`
   * 開啟搜尋時關閉會員下拉選單
2. 搜尋表單關閉時：

   * 清除或隱藏 `.siteSearchDropdown`
   * 將 `.siteSearchToggle` 的 `aria-expanded` 設回 `false`
3. 點擊搜尋區以外、按 Escape、開啟漢堡選單或購物車時，關閉搜尋表單與下拉區。
4. 表單 submit 時：

   * `preventDefault()`
   * `trim()` 搜尋字串
   * 空字串不可導頁
   * 使用 `encodeURIComponent()` 處理關鍵字
   * 導向既有商品列表頁支援的搜尋 query 參數
5. 先檢查現有商品列表頁與 API/mock API 的搜尋參數命名；必須沿用既有契約，不可自行發明不被商品列表處理的 query key。
6. 若目前沒有即時搜尋 API，不要杜撰假資料；下拉區可以維持隱藏，只需完成開啟、輸入、送出與導頁流程。
7. 路徑必須同時支援專案根目錄頁面與 `/pages/` 子頁。沿用專案既有的相對路徑策略，不可只硬編碼一種頁面位置。

---

## 4. Header 開關狀態統一

建立或補齊全域函式：

```js
window.closeMainHeaderDialogs = function () { ... };
```

它至少要關閉：

* 搜尋表單與搜尋下拉區
* 使用者下拉選單
* 漢堡選單（若目前 Header 已有既有 close 函式，直接重用）
* 不可意外關閉登入 Modal，Modal 仍由 `modal.js` 管理

`cart.js` 已呼叫 `window.closeMainHeaderDialogs?.()`，因此這個函式必須存在且不能破壞購物車開啟流程。

---

## 5. 可存取性與狀態要求

依照既有樣式規範維持：

* 所有按鈕可鍵盤操作。
* 所有可展開元件正確更新 `aria-expanded`。
* 隱藏的搜尋、會員選單必須保留 `hidden`，不要只用透明度隱藏。
* Escape 關閉目前開啟的 Header 浮層。
* 不可修改 `.modal.isOpen`、`.siteCartDrawer.isOpen`、`.siteOffcanvas.isOpen` 的既有狀態命名。
* 不可使用新的 emoji 作為互動圖示。
* 不可新增外部套件或框架。

### 6. 對pages/ 所有html 設置共用佈局
 1. 對pages 檔案裡面的所有網頁進行可以共用的佈局。

### 7. home.html 細部更改
 1. section.brandCarouselSection 讓品牌跑馬燈無限捲動。
   * 外層隱藏超出的內容
   * 內層放一排品牌
   * 重複同一組品牌兩次，避免動畫接回起點時出現空白
   * 用 CSS transform: translateX() 做無限動畫
 2. div.homeProductRating 的starRating 要支援 4.1、4.3、4.8 這種每 0.1 顆星的顯示。
   * 底層：5 顆空星
   * 上層：5 顆實心星
   * 上層依評分百分比裁切寬度
 3. article.homeProductCard 不要只有img hover 會放大圖示，要整個卡片都有放大的效果。
   * 設定動畫過渡，讓放大、上移、陰影變化不是瞬間跳動，而是平滑發生。
   * 滑鼠移到卡片時，稍微放大，放大幅度不要太大，約 1% 到 2% 就夠，太大會像按鈕跳動。
   * 同時往上移一點並加深陰影，往上移大約 4 到 6 像素，陰影變大一點，視覺上就像卡片被拿起來。
4. section.homeSection 裡面的h2.sr-only 要置中於畫面正中間，並且font-size 改為2.5em。

### 8. products.html 細部更改
1. div.adCarouselSlides 沒有與div.adCarouselSlides 對齊width 每一頁都會稍微偏移，且最後一張會瞬間跳回第一張，用以下方式修正問題。
   * 重新計算位移距離
      * 卡片間距只用 gap
      * 不要再額外加左右 margin
      * 輪播容器和滑動軌道的 padding 要明確分開
      * 卡片寬度使用一致規則
   * 做「無限輪播」
      * 先讓使用者看到滑到複製 A 的動畫。
      * 動畫結束後，暫時關閉 transition，立刻把位置跳回真正的 A。
2. div.productCardRating 的starRating 要支援 4.1、4.3、4.8 這種每 0.1 顆星的顯示。
   * 底層：5 顆空星
   * 上層：5 顆實心星
   * 上層依評分百分比裁切寬度
3. button.mobileFilterReset、button.mobileFilterApply 要套用與button.productCardAddBtn 一樣的樣式。
4. div.filterPriceInputs 的input#mobilePriceMin、mobilePriceMax 每次增加的數量最低為100。


## 驗收條件

* 使用$pre-review-checklist skill
* 在 `pages/home.html` 實際測試：
   1. 漢堡選單、購物車功能維持正常。
   2. 點擊登入可開啟 `loginModal`。
   3. Google、Facebook、LINE 任一登入成功後，登入按鈕消失，會員名稱與頭像出現。
   4. 點擊會員區可開啟與關閉下拉選單。
   5. 點擊登出後回到未登入 Header 狀態。
   6. 點擊搜尋圖示可開啟搜尋欄並自動聚焦。
   7. 搜尋可送出並導向商品列表現有搜尋結果。
   8. 點擊頁面空白處或按 Escape 可關閉搜尋與會員下拉選單。
   9. 重新整理頁面後，登入狀態與會員 Header 顯示仍正確。
   10. Console 不得出現找不到元素、重複事件綁定或 undefined function 錯誤。
* 使用cmd 在css 資料夾下面使用npx sass --watch main.scss:main.css 指令更新main.css 檔案並進行驗證。


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
- CSS、SCSS 同一個元件功能的區塊要用註解標註功能及套用在哪個元件。
- HTML 每個元件區塊都要用註解標註功能。
- Javascript 每個函式都要註解功能及套用在哪個元件。
- 將更新的程式內容簡述到根目錄的README.md。

## 完成條件：
* header 所有modal 初始狀態都為隱藏，只有點擊了相對應的按鈕後才會顯示。
* 所有pages html 頁面在各種RWD 的頁面下不會有超出視窗或跑板問題。
