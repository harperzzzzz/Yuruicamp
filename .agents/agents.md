請先讀取：
* `docs/ai-style-sheet.md`
* `js/components/member-center.js`
* `components/member-center.partial`
* `css/pages/member-center.scss`
* `data/orders.json`
* `data/rentalOrders.json`


## 任務目標:
會員中心的查看明細跑出來的div.memberModalOverlay 內的div#orderDetailBody資訊不完整，購買訂單參考purchase.json、rental參考rentalOrders.json

## 問題現象：
查看訂單明細顯示的資訊不夠詳細，先依照我給予的兩張圖片作為購買、租借訂單的參考，先更改member-center.js 的渲染欄位不要更動樣式和member-center.parital。

## 預期結果：
將以下資訊通過js渲染到div#memberDetailBody
購買訂單:
訂單編號、訂單日期、訂單狀態、商品項目、商品小記、運費、訂單總額、回饋點數、付款方式、配送地址、物流追蹤碼
租借訂單:
訂單編號、訂單日期、訂單狀態、商品項目、租借費用、押金、訂單總額、租借日期、取貨/歸還門市、付款方式

## 技術限制：
- 保留現有 Vite 專案結構。
- 使用目前的 HTML、SCSS、JavaScript 架構。
- 遵守 ITCSS 分層架構。
- 不可修改與此任務無關的檔案。
- 不可新增未定義的新色碼、字體、間距系統。
- 不可自行增加 docs/frontend-specs 中沒有的功能。
- 不要強制用疊加CSS 的手法去修改樣式。
- 所有互動需可由鍵盤操作。
- 手機版寬度 375px 不可水平捲動。
- 不可使用 inline style。
- 不可使用 !important。
- 所有class 和id 命名都要使用駝峰式命名法，且都要語意化。
- CSS/HTML/JS 函式都要添加說明那個函式是在做什麼的的註解使用中文
- 將更新的程式內容簡述到根目錄的README.md。

## 驗收方式：
* 確認member-center.partial 的訂單明細畫面有正常顯示新增加的資訊。
