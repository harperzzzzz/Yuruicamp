# CSS 規範
- 設計CSS時，遵守mockdown 中的ITCSS 架構。
- 不要新增預擴充的CSS 架構、現在不會使用到的CSS。
- 不要在html 內建立任何CSS 程式碼，例如: elements 的內聯style、<head> 裡面的<style>，一律通過scss 架構CSS 檔案。
- 在javascript 有建立html 的區塊也不能出現elements 的內聯style，一律通過scss 架構CSS 檔案。
    - 只允許catBlock.style.display = visibleItems.length > 0 ? '' : 'none'; 這種形式的添加方式出現在javascript裡面。
- class, id 命名規則以駝峰式方法命名，組成以用語意化單詞為主，不要連續使用標點符號。
    - 最佳命名範例: class="userName", id="firstName"
- 新增CSS 樣式時先搜尋有無class存在，不要以疊加方式強硬更改CSS
    - 有存在 -> 寫入同一個區塊內。
    - 不存在 -> 在對應ITCSS 架構的scss 內新增樣式區塊。
- 設置class 和id 的時機: 
    - 設置樣式通過class 設定。
    - id 在頁面只能唯一，且不能為了設置樣式而使用id。
- 有相同相應條件的CSS 都要寫在一起，並且放置在scss, CSS 檔案最下方。
    - 例如: @media (width <= 600px>) 這種條件。
- 沒有使用樣式時，不要設定html 元素的class。
- 更新CSS 時，有偵測到未使用的CSS 將其刪除。

# ITCSS 架構
## abstracts（抽象層）
    - 存放不會直接產生 CSS 碼的工具與設定。
    - variables/（變數）
        - 全域，顏色、字體大小、中斷點（Breakpoints）、間距（Spacing）等。
    - mixins/（混入）
        - 存放可以重複使用的 CSS 程式碼，清除浮動、置中設定、媒體查詢的 Helper 等

## base (基層)
    - 負責定義整個專案最底層、最通用的樣式與全域設定，只會針對 HTML 原生標籤（Tag）做設定，而不會寫任何自訂的 CSS Class
    - elements/（原生元素）
        - 針對基本的 HTML 標籤設定預設樣式
        - <a>、<ul> 、或是 <table>、<form>
    - typography/（文字排版）
        - 管理專案的字體與標題。
        - <h1> 到 <h6> 與行高（line-height）、<p> 、以字體族群（font-family）的宣告。

## components（組件層）
    - 存放非常具體的 CSS Class，而且「盡可能不互相依賴，方便你在網站的任何地方直接拔起來套用」。
    - comments/（迴響/評論區）
        - 評論列表、留言表單（Form）與頭像（Avatar）等。
    - content/（內容區塊）
        - 文章列表、單篇文章內文、分頁導覽（Pagination）等。
    - media/（媒體元件）
        - 圖片、影片、畫廊（Gallery）以及圖片說明（Captions）等。
    - navigation/（導覽列）
        - 處理主選單、下拉式選單、行動裝置的漢堡選單等。
    - widgets/（小工具）
        - 側邊欄（Sidebar）或頁尾小工具樣式（例如近期文章、分類列表、日曆等）。

## generic（通用層）
    - 專案最基礎、最全局的 CSS 設定。比 base/ 還要更底層，不涉及任何具體的設計風格（如字體、顏色），而是純粹用來「規範瀏覽器的行為」和「重設環境」。
    - 例如: 
        1. box-sizing: border-box; 
            - 限制所有的元素在計算寬高時，把內距（padding）和邊框（border）也算進去。
        2. Normalize.css
            - 設定「統一口徑」，修復瀏覽器的 Bug，讓網頁在所有瀏覽器上看渲染出來的基準線都長得一模一樣。
    * 不要擅自新增.col- ,.flex- 功能性工具。

## layouts/（佈局層）
    - 處理網頁大型骨架與不同頁面整體的版面配置。
    - 例如: 
        - 「內容在左、側邊欄（Sidebar）在右」的傳統兩欄式版面。
        - 「全寬滿版、沒有側邊欄」的單欄式佈局。

## plugins/（外掛層）
    - 用來相容與整合第三方熱門外掛的樣式覆寫區，每有一個第三方外掛就在plugins 多設立一個資料夾管理。

## utilities/（輔助層）
    - 強調「功能性 Class」，極度單一，一個 Class 只專心做好一件事，通常會加上 !important，用來強行覆寫網頁上任何元素的樣式。
    * 不要擅自新增.col- ,.flex- 功能性工具。