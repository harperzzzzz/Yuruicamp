# admin_users
* 後台角色帳號主檔


## 關聯與資料流
admin_users
├─ 1:N inventory_movements      （employee_id，必填）
├─ 1:N order_status_history     （actor_id，可空）
├─ 1:N order_event_history      （actor_id，可空）
├─ 1:N booking_status_history   （actor_id，可空）
├─ 1:N campground_closures      （created_by，必填）
└─ 1:N zone_blocks               （created_by，必填）

### 關聯
* admin_users：後台人員與角色的主檔。
* inventory_movements：每筆庫存異動必須記錄執行人員 employee_id。
* order_status_history：訂單狀態變更可記錄操作者 actor_id；允許空值，代表可能是系統或舊資料。
* order_event_history：非訂單生命週期的事件紀錄，可記錄操作者。
* booking_status_history：預約狀態變更可記錄操作者。
* campground_closures：營地關閉規則必須記錄建立者。
* zone_blocks：營地區域封鎖必須記錄建立者。
上述外鍵皆為 ON UPDATE CASCADE ON DELETE RESTRICT：管理員 ID 異動時會同步；只要仍有歷史紀錄，就不能刪除該管理員。

### 資料流程
* 後台人員建立後：
- 在 admin_users 建立人員基本資料與角色。
- 人員執行庫存異動時，在 inventory_movements.employee_id 寫入其 admin_users.id。
- 人員變更訂單或預約狀態時，在相應 history 表的 actor_id 寫入其 ID。
- 人員建立營地關閉規則或區域封鎖時，在 created_by 寫入其 ID。
- 人員若不再使用，應將 admin_users.active 設為 false，而非刪除，以保留稽核歷史。



## 欄位說明
### admin_users
* id                  管理員識別碼
* name                管理員姓名
* email               登入或聯絡信箱；UNIQUE

* role                系統角色；
                      只允許 admin、operator、warehouse

* active              帳號是否啟用；預設 true
* created_at          建立時間；預設 now()。
* updated_at          最後更新時間；預設 now()，
                      但 schema 沒有自動更新 Trigger。

*idx_admin_users_role_active ON (role, active)*：
依角色篩選啟用／停用人員時可使用。



## 運作模式
* admin_users 本身不是權限明細表，而是只有三種粗粒度角色的帳號主檔。
admin：預期為完整後台管理權限。
operator：預期處理訂單、預約等營運工作。
warehouse：預期處理庫存異動。

* 人員操作流程 :
啟用的 admin_users
        ↓
執行後台操作
        ↓
目標業務資料表更新
        ↓
寫入歷程／異動表的 actor_id、employee_id 或 created_by
        ↓
日後可從歷程回查操作者



## 程式碼追蹤
* 後台登入
    `admin/login.html`
            ↓
    登入表單 submit
    [admin/login.html 第 156 行]
            ↓
    讀取 employeeId 與 password
    [admin/login.html 第 159–160 行]
            ↓
    findEmployeeById(employeeId)
    [admin/login.html 第 178 行]
            ↓
    localStorage.adminEmployees
    [`admin/js/permissions.js` 第 18、82–104 行]
            ↓
    確認員工存在且 isActive = true
    [admin/login.html 第 179 行]
            ↓
    寫入 sessionStorage：
    adminLoggedIn、adminId、adminName、
    isSuperAdmin、adminPermissions
    [admin/login.html 第 190–194 行]
            ↓
    導向 `admin/dashboard.html`
    [admin/login.html 第 195 行]

    * 目前實際執行時：
        - 不讀 admin_users。
        - 不寫 admin_users。
        - 不讀取任何正式資料庫表。
        - 密碼只驗證「不可為空」，不驗證內容。
        - 員工資料首次使用時由 admin/js/permissions.js 建立 Demo 帳號 01、02，保存到 localStorage.adminEmployees。
        - POST /api/admin/login 僅是預留註解，尚未實作。
        - backend 目前可見 Flyway migration，但沒有對應的登入 Controller／Service／Repository。

* 後台建立庫存異動
    `admin/js/products.js`
            ↓
    產生異動紀錄 record
    [admin/js/products.js 第 1395–1399 行]
            ↓
    employeeId: getCurrentAdminId()
            ↓
    sessionStorage.adminId
    [admin/js/products.js 第 3220–3221 行]
            ↓
    window.addMovementRecord(record)
    [admin/js/products.js 第 1402–1403 行]

    * 目前實際執行時：
        - 前端只把目前登入者的 sessionStorage.adminId 寫進 Mock 異動紀錄。
        - 不寫入正式 inventory_movements.employee_id。
        - 因此雖然前端有「操作者 ID」概念，但它尚未與資料庫 admin_users.id 實際串接。



## 可能的問題

* 高風險｜資料庫人員資料與實際登入帳號會分裂
    後台登入完全未使用 admin_users
    前端使用 localStorage.adminEmployees

* 高風險｜不能直接支援正式驗證。
    資料庫＋後端：admin_users 沒有 password_hash、外部身分提供者 ID、登入失敗次數、鎖定時間、最後登入時間、token/session 管理；

* 高風險｜前端：目前密碼任意非空即可登入

* 高風險｜前端和資料庫，兩套授權模型無法對應
    資料庫只有 role 三選一
    前端有 10 個功能頁面的 view/edit 細部權限物件

* 中風險｜正式後端必須在登入、發 token、每次授權判斷都確認 active = true
    資料庫：active 只是一個欄位，沒有資料庫層的存取控制；

* 中風險｜資料庫: 更新資料時不會自動更新。
    需由 Service 統一寫入，或加 Trigger。

* 中風險｜資料庫： 可能出現大小寫不同但語意相同的帳號。
    email UNIQUE 改成 UNIQUE (lower(email))

* 中風險｜資料庫：id 沒有預設產生策略，建立人員時必須由後端自行提供

* 中風險｜資料庫：role 是可變文字欄位

* 低風險｜資料庫：歷程表允許 actor_id 為空，稽核上可接受系統自動操作，但後端應清楚區分「系統操作」與「缺失的操作者資料」。