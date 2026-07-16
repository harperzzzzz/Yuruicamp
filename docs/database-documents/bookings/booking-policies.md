# booking-policies
    預約政策主檔；保存可預約窗口、提前天數、最長住宿、時區、日期邊界與低可用量門檻。
* booking_policy_availability_statuses
    預約政策與「可用性結果可呈現」狀態的關聯表。
* booking_policy_occupying_statuses
    預約政策與「會占用營位庫存」狀態的關聯表。


## 關聯與資料流
booking_policies（固定單例 id = 1）
├─ 1:N booking_policy_availability_statuses
└─ 1:N booking_policy_occupying_statuses
                 ↓
        預約日期窗口與營位可用量計算
                 ↓
 bookings.status、booking_selected_zones、zone_blocks、campground_closures

### 關聯
* booking_policies：全站預約規則的中心；資料庫限制只能有 `id = 1` 的單一政策。
* booking_policy_availability_statuses：定義哪些預約狀態會被納入可用性相關呈現；以 `(policy_id, status)` 作為複合主鍵，同一狀態不得重複設定。
* booking_policy_occupying_statuses：定義哪些預約狀態會扣除營位可用量；以 `(policy_id, status)` 作為複合主鍵。
* 兩張狀態表均以 `policy_id` 參照 booking_policies.id。政策刪除時，狀態設定會以 `CASCADE` 一併刪除。

### 資料流程
可用性計算時：
1. 讀取 booking_policies 的預約窗口、提前天數、最長住宿與低量門檻。
2. 讀取 booking_policy_occupying_statuses，判斷哪些 bookings.status 應計入營位占用。
3. 依住宿區間 `[check_in, check_out)` 加總 booking_selected_zones 的數量。
4. 扣除 zone_blocks 的人工保留量；若 campground_closures 命中，該晚可用量為 0。
5. 以低可用量門檻判斷可用性顯示狀態。



## 欄位說明
### booking_policies
* id                          政策識別碼；smallint 主鍵，資料庫限制只能是 `1`。
* booking_window_days         最遠可預約天數；必須大於 0。
* advance_days                最少提前預約天數；必須大於等於 0。
* max_nights                  單筆預約最長住宿晚數；必須大於 0。
* timezone                    預約日期採用的時區；預設 `Asia/Taipei`，且資料庫只允許此值。
* date_boundary_hour          日期邊界的小時；預設 0，必須介於 0 至 23。

* low_availability_threshold  補貨門檻；整數百分比，必須介於 0 至 100。
                              相容 DTO 會除以 100，對應前端 `lowThresholdRatio`。

* created_at                  建立時間；預設 `now()`。
* updated_at                  更新時間；預設 `now()`
                              沒有自動更新 Trigger。

*`ck_booking_policies_ranges` 同時限制各數值欄位的有效範圍。*
*`ck_booking_policies_singleton` 限制 `id = 1`。*

### booking_policy_availability_statuses
* policy_id                   所屬預約政策

* status                      可用性相關呈現使用的預約狀態；不得為空白字串。
                              *idx_booking_policy_availability_statuses_status*

*(policy_id, status) 是複合主鍵；同一政策不能重複設定同一狀態。*

### booking_policy_occupying_statuses
* policy_id                   所屬預約政策

* status                      會占用營位庫存的預約狀態；不得為空白字串。
                              *idx_booking_policy_occupying_statuses_status*

*(policy_id, status) 是複合主鍵；同一政策不能重複設定同一狀態。*



## 運作模式
* 預約窗口、住宿限制與顯示門檻 > booking_policies
* 可用性呈現狀態規則 > booking_policy_availability_statuses
* 營位占用狀態規則 > booking_policy_occupying_statuses

### 政策單例
此設計以 `booking_policies.id = 1` 表示全站唯一政策。正式後端應更新既有單例，不應新增第二筆；更新政策與兩張狀態關聯表時應包在同一交易中。



## 程式碼追蹤
* 前台載入預約政策
    `js/booking-api.js`
        `BookingAPI.getPolicy()` 讀取 `data/admin/booking-policy.json`
                ↓
    `js/booking-availability.js`
        `normalizePolicy()` 與預設政策合併
                ↓
        `getBookingWindow()` 計算最早與最晚可預約日期
                ↓
        `isOccupyingBooking()` 依 `occupyingStatuses` 判斷預約是否占用庫存

    * 目前實際執行時：
        - 不直接讀取 PostgreSQL booking_policies 或兩張狀態關聯表。
        - 使用 JSON 的 `occupyingStatuses[]`；目前 JSON 沒有 `availabilityStatuses[]`。
        - 前端固定使用 `Asia/Taipei` 作為預設時區，且以入住日含、退房日不含的區間計算。

* 營位可用性判斷
    `js/booking-availability.js`
        載入營區、預約、人工保留量、公休與政策
                ↓
        依 occupyingStatuses 篩選預約
                ↓
        計算各營位／日期的占用量與剩餘量
                ↓
        以 availabilityStatus.lowThresholdRatio 回傳 `available`、`low` 或 `sold_out`



## 可能的問題
* 高風險：目前前端只讀 JSON 政策，正式資料庫的三張政策表尚未成為實際資料來源。
* 高風險：前端 JSON 目前未提供 `availabilityStatuses[]`，因此 booking_policy_availability_statuses 無法由現行前端契約直接完整回填或驗證。
* 中風險：兩張狀態表僅限制狀態不可空白，未限制為 bookings.status 的正式枚舉；應在 Service 或資料庫型別／參照表中統一狀態字典。
* 中風險：`date_boundary_hour` 已在資料庫保存，但目前前端日期計算未使用它；需明確定義跨日切換是否應影響預約窗口與可用量。
* 中風險：updated_at 不會在 UPDATE 時自動刷新，應由 Spring Boot Service 統一更新。
* 低風險：單例限制只保證 `id = 1`，不保證一定存在一筆政策；正式部署應以 seed migration 建立初始資料。
