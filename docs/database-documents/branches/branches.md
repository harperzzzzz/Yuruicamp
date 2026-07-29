# branches 
* admin_users
    會被訂單歷程、預約歷程、庫存異動等功能引用。
* branch_features
    記錄每間分店的特色或服務


## 尚未應用
* 目前讀取 data/marketing/branches.json，沒有查詢資料庫
* 後台登入目前讀取瀏覽器 localStorage.adminEmployees，沒有查詢 admin_users
* backend 目前主要是啟動類別；schema 以 `docs/latest_schema.sql` 建庫，沒有分店或登入的 Controller、Service、Repository。


## 關聯與資料流
branches
   1
   │
   └──── N branch_features

admin_users
   ├──── N inventory_movements
   ├──── N order_status_history
   ├──── N booking_status_history
   ├──── N campground_closures
   └──── N zone_blocks
### branches → branch_features
* 一間分店可以有多筆特色。
* 每筆特色只能屬於一間分店。
* 修改 branches.id 時，特色的 branch_id 會跟著更新。
* 刪除分店時，該分店的所有特色會一起刪除。
* (branch_id, feature) 是複合主鍵，同一間分店不能重複加入相同特色。
#### branches 的其他關聯
* inventory_locations.branch_id
* 也可能是門市庫存位置的主檔。關聯使用 ON DELETE RESTRICT
### admin_users 連接 inventory_movements.employee_id 關聯
* 關聯使用 ON DELETE RESTRICT (有操作歷程的管理員不能直接刪除)

### 資料流
1. branches 建立分店主檔。
2. branch_features 補充分店特色。
3. inventory_locations 將分店對應到門市庫存位置。
4. 管理員執行訂單、預約、庫存或排程操作。
5. admin_users.id 被寫入歷程或異動表，留下操作者紀錄。



## 資料欄位說明
### branches
* id                分店識別碼
* name
* address           完整地址
* phone       
latitude            緯度，null，限制在 -90 至 90
longitude           經度，null，限制在 -180 至 180
map_query           地圖搜尋文字，null
* business_hours    營業時間
image_url           null
* active             是否啟用，預設 `true`（ADM-W2-07 新增，軟停用旗標）
* created_at        建立時間，now()
* updated_at        最後更新時間，now()，沒有自動更新機制

### branch_features
* id                自動流水號，UNIQUE (branch_id, feature)
* branch_id
* feature           分店特色
*(branch_id, feature) 是複合主鍵*

### admin_users
* id            員工識別碼
* name  
* email         登入或聯絡信箱，唯一
* role          角色，只允許 admin、operator、warehouse
* active        帳號是否啟用，true，與 role 組成索引
* created_at    建立時間，now()
* updated_at    最後更新時間，now()，沒有自動更新機制



## 運作模式
### branch_features
* 讀取分店及特色：
    SELECT
        branch.id,
        branch.name,
        branch.address,
        branch.phone,
        branch.business_hours,
        branch.image_url,
        array_agg(feature.feature ORDER BY feature.feature) AS features
    FROM branches branch
    LEFT JOIN branch_features feature
        ON feature.branch_id = branch.id
    WHERE branch.active = true  -- 公開 API 只回啟用門市（ADM-W2-07）
    GROUP BY branch.id;



## 程式碼追蹤
* 分店頁載入
    pages/branches.html
            ↓
    js/pages/branches.js (line 124)
            ↓
    fetchBranches()
            ↓
    window.API.branches.getAll()
            ↓
    js/api-mock.js (line 484)
            ↓
    data/marketing/branches.json
            ↓
    建立分店卡片與更新地圖 
    [js/pages/branches.js (line 54)]
    [js/pages/branches.js (line 65)]
    [js/pages/branches.js (line 57)]

    * 目前實際執行時：
    1. 不讀 branches。
    2. 不讀 branch_features。
    3. 不寫任何資料庫。
    4. 只讀 [data/marketing/branches.json (line 1)]

* 後台登入
    admin/login.html
            ↓
    讀取員工 ID 與密碼  
    [admin/js/permissions.js (line 26)] 員工資料來源
    [admin/js/permissions.js (line 103)]
            ↓
    findEmployeeById(employeeId)
    [admin/js/permissions.js (line 142)]
            ↓
    localStorage.adminEmployees
            ↓
    確認員工存在且 isActive = true
    [admin/login.html (line 178)]

            ↓
    寫入 sessionStorage
    [admin/login.html (line 190)]
            ↓
    進入 dashboard.html

    * 目前登入實際上：
    1. 不讀 admin_users。
    2. 不寫 admin_users。
    3. 讀取 localStorage.adminEmployees。
    4. 寫入 sessionStorage。
    5. 密碼只檢查是否為空，沒有驗證密碼。



## 可能的問題
* 高風險：資料庫與前端有兩套分店來源
資料庫 ： branches, branch_features
前端 ： data/marketing/branches.json

* 高風險：後台登入完全沒有使用 admin_users
程式使用 localStorage.adminEmployees
資料庫使用 admin_users

* 高風險：登入沒有真正驗證密碼
admin_users 沒有：
    password_hash
    外部認證身分
    登入失敗次數
    帳號鎖定時間
    最後登入時間

* 中風險：feature 使用自由文字 (只有顯示用可以接受)

* ~~中風險：刪除 branches.active 後無法軟停用分店~~（ADM-W2-07 已解決）
    2026-07-23 補回 `branches.active boolean DEFAULT true NOT NULL`：
    - 停用門市：`PATCH /api/admin/branches/{id}` body `{"active": false}`
    - 公開 `GET /api/branches` 只回 `active=true`；後台 `GET /api/admin/branches` 仍看得到全部（含停用）
    - 有 `orders.pickup_branch_id` 或 `inventory_locations.branch_id` 引用時，`DELETE` 禁止硬刪（回 `409`），
      引導改用上面的軟停用；無引用才允許硬刪

* 中風險：business_hours 是非結構化文字 (只用於顯示，文字欄位可以接受)

* 中風險：updated_at 不會自動更新
admin_users
branches

* 中風險：管理員信箱大小寫可能重複

* 低至中風險：分店名稱、電話沒有唯一限制