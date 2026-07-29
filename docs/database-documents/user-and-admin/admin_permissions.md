# admin_permissions
    定義後台可授予的功能權限。
* admin_role_permissions
    定義 admin、operator、warehouse 三種角色的預設權限。
* admin_user_permissions
    定義個別管理員相對於角色預設值的允許或禁止設定。


## 關聯與資料流

G-1 已實作角色預設與個人覆寫合併。後端將最終權限碼放入 Spring Security authorities，Controller 以 `@PreAuthorize` 檢查；`permissions.view`／`permissions.edit` 負責管理員帳號與權限頁。
admin_users
├─ N:1 角色預設權限
│     └─ 透過 admin_role_permissions
│           └─ N:1 admin_permissions
└─ 1:N admin_user_permissions
      └─ N:1 admin_permissions

### 關聯
* admin_permissions：權限主檔，每一列代表一個後台功能的 view 或 edit 權限。
* admin_role_permissions：角色與權限的多對多關聯表，同一角色可以有多個預設權限。
* admin_user_permissions：管理員與權限的多對多關聯表，以 allowed 覆寫該管理員角色的預設權限。
* admin_users：透過 role 取得角色預設權限，透過 id 取得個別權限覆寫。

### 資料流程
建立權限設定後：
1. 在 admin_permissions 建立系統允許使用的權限代碼。
2. 在 admin_role_permissions 建立 admin、operator、warehouse 的預設權限。
3. 管理員登入時，後端先依 admin_users.role 讀取角色預設權限。
4. 後端再依 admin_users.id 讀取 admin_user_permissions。
5. admin_user_permissions.allowed = true 時，額外授予該權限。
6. admin_user_permissions.allowed = false 時，明確移除該權限。
7. 後端將最終權限組合成前端需要的 permissions 物件。
8. 每次呼叫後台 API 時，後端必須重新檢查帳號是否啟用及是否擁有對應權限。

---
* 刪除權限：
DELETE admin_permissions
        ↓
admin_role_permissions、admin_user_permissions
        ↓
由外鍵 ON DELETE CASCADE 一併刪除角色設定與個人覆寫

* 刪除管理員：
DELETE admin_users
        ↓
admin_user_permissions
        ↓
由外鍵 ON DELETE CASCADE 一併刪除該管理員的個人權限覆寫


## 欄位說明
### admin_permissions
* code                  權限代碼，也是主鍵，最長 64 字元。
                        建議使用「功能.action」格式，例如 orders.view、orders.edit。

* section               前端功能代碼，最長 32 字元。
                        對應 admin/js/permissions.js 的 ADMIN_SECTIONS key。

* action                操作類型，只允許 view 或 edit。

*(section, action) 複合 UNIQUE，同一功能不能重複建立相同操作權限。*

### admin_role_permissions
* role                  角色代碼，只允許 admin、operator、warehouse。
                        *pk_admin_role_permissions*

* permission_code       權限代碼，外鍵至 admin_permissions.code。
                        *pk_admin_role_permissions*
                        *idx_admin_role_permissions_permission*

*(role, permission_code) 是複合主鍵，同一角色不能重複取得相同權限。*

### admin_user_permissions
* admin_user_id         管理員識別碼，外鍵至 admin_users.id。
                        *pk_admin_user_permissions*

* permission_code       權限代碼，外鍵至 admin_permissions.code。
                        *pk_admin_user_permissions*
                        *idx_admin_user_permissions_permission*

* allowed               個別覆寫結果。
                        true 表示額外允許；false 表示明確禁止。

*(admin_user_id, permission_code) 是複合主鍵，同一管理員對同一權限只能有一筆覆寫。*


## 權限代碼
目前前端共有 10 個後台功能，每個功能各有 view 與 edit：

* analytics             分析報表
* orders                訂單管理
* movement              庫存異動紀錄
* products              商品與庫存
* customers             客戶管理
* discounts             折扣管理
* reviews               評論管理
* booking-calendar      預約排程面板
* bookings              預約／租借管理
* permissions           權限管理

應建立的 20 個權限代碼：
* analytics.view、analytics.edit
* orders.view、orders.edit
* movement.view、movement.edit
* products.view、products.edit
* customers.view、customers.edit
* discounts.view、discounts.edit
* reviews.view、reviews.edit
* booking-calendar.view、booking-calendar.edit
* bookings.view、bookings.edit
* permissions.view、permissions.edit


## 運作模式
* 權限字典 > admin_permissions
* 角色預設權限 > admin_role_permissions
* 管理員個別覆寫 > admin_user_permissions

### 最終權限判斷
* admin_users.active = false 時，後端應拒絕登入及所有後台 API。
* 沒有個別覆寫時，使用 admin_role_permissions 的角色預設值。
* allowed = true 時，個別覆寫結果為允許。
* allowed = false 時，個別覆寫結果為禁止。
* edit 應隱含 view；授予 edit 時應同時授予 view，移除 view 時也應移除 edit。
* 前端的按鈕隱藏或停用只用於操作體驗，真正的權限判斷必須由後端 API 執行。

### 前端 DTO
後端登入成功後，應將資料庫權限轉成目前前端使用的格式：

```json
{
  "id": "ADM001",
  "displayName": "王小明",
  "role": "operator",
  "isActive": true,
  "permissions": {
    "orders": { "view": true, "edit": true },
    "products": { "view": false, "edit": false }
  }
}
```


## 程式碼追蹤
* 後台權限定義
    `admin/js/permissions.js`
        ↓
    window.ADMIN_SECTIONS
        ↓
    定義 10 個功能頁面的 key 與名稱
        ↓
    getDefaultPermissions(allTrue)
        ↓
    產生每個功能的 view／edit 權限物件

    * 目前實際執行時：
        - 員工與權限資料保存於 localStorage.adminEmployees。
        - 權限管理頁修改的仍是 localStorage，不會寫入 PostgreSQL。
        - 登入後將 permissions 寫入 sessionStorage.adminPermissions。

* 後台登入
    `admin/login.html`
        ↓
    findEmployeeById(employeeId)
        ↓
    讀取 localStorage.adminEmployees
        ↓
    將 employee.permissions 寫入 sessionStorage
        ↓
    進入 admin/dashboard.html

    * 正式串接後：
        - POST /api/admin/login 應驗證 admin_users 帳號與密碼。
        - 後端應從三張權限表計算最終權限。
        - 前端不應再以 localStorage.adminEmployees 作為帳號或權限來源。
        - sessionStorage 中的權限只能控制畫面，不能取代後端 API 授權。


## 可能的問題
* 中風險：資料庫無法用單一資料列約束 edit 必須同時具有 view；建立、更新與計算權限時，應由後端 Service 保證此規則。
* 中風險：admin_permissions.section 尚未限制只能使用前端既有的 10 個功能代碼；後端應以固定常數驗證，並確保資料庫與 ADMIN_SECTIONS 同步。
