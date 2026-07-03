請先讀取：
* `booking/booking-style-tokens.md`
* booking/css 的所有檔案

## 任務目標:
將booking/css 裡面全部的顏色進行簡化

## 問題現象：
--yc-surface-muted 合併到 --yc-surface-soft
--yc-oat	合併到 --yc-surface-soft
--yc-border-strong	合併到 --yc-sage-light
--yc-sage-mist	合併到 --yc-sage-soft
--yc-sage	合併到 --yc-sage-action
--yc-cta-active	合併到 --yc-cta-hover
--yc-gold-text	合併到 --yc-on-cta
--yc-text-subtle	合併到 --yc-text-muted
--yc-border-soft	可刪或 alias
--yc-sage-soft	更換成 #eef2ec
–yc-success-line 合併到 –yc-success
–yc-warning-line 合併到 –yc-warning
–yc-warning-dark 改名為 –yc-warning-text
–yc-error-line 合併到 –yc-error
–yc-info-soft 改用 –yc-sage-soft
–yc-info-line 改用 –yc-sage-light
–yc-info 改用 –yc-sage-dark

## 預期結果：
被改用或刪除的color 必須進行移除

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

