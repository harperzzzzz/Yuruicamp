# booking_policies

## problems :
1. occupying_statuses、
2. date_rule、
3. availability_status 以 JSONB 存放規則集合。
違反1NF
(判斷可接受，即便違反1NF，如果有嚴格遵守以下規則的話)


### 主要更動 :
1. 確認這三個欄位的責任邊界
occupying_statuses：哪些訂單狀態會占用營位。
date_rule：入住日、退房日是否包含在可住晚數裡，目前語意是 [checkIn, checkOut)。
availability_status：可用性顯示規則，例如低庫存門檻。

2. 不建議現在拆成 booking_policy_statuses、booking_policy_date_rules 等子表，`除非未來要支援多套政策、歷史版本、或後台頻繁查詢單一規則`。

3. 明確定義對應的JSON 詳細欄位 :
---
{
  "occupyingStatuses": ["pending", "confirmed", "completed"],
  "dateRule": {
    "checkInInclusive": true,
    "checkOutExclusive": true
  },
  "availabilityStatus": {
    "lowThresholdRatio": 0.3
  }
}
---
* 對應 DB 欄位
occupyingStatuses → occupying_statuses
dateRule → date_rule
availabilityStatus → availability_status

4. 加 DB 層驗證規則
後續實作 migration 時，建議加 CHECK 約束，避免 JSONB 被塞錯型別：
occupying_statuses 必須是 JSON array
date_rule 必須是 JSON object
availability_status 可以是 NULL 或 JSON object
booking_window_days > 0
max_stay_nights > 0
timezone 不可空字串

5. 規定 singleton 策略
booking_policies 應該只允許一筆有效政策。
實作時可採其中一種：
固定 id = 1
加 singleton_key BOOLEAN DEFAULT true 並設唯一約束
或用 app/service 層保證只讀最新一筆

6. 訂房占用查詢規則
SQL 邏輯應是：
booking status 在 occupying_statuses
booking.check_in < 查詢結束日
booking.check_out > 查詢開始日
退房日不占用當晚，符合目前文件中的 [checkIn, checkOut) 語意

7. `後台更新時做 application validation，有要更新嗎`
後台若允許改政策，要驗證：
occupying_statuses 裡的值必須存在於訂單狀態 enum / 文件允許清單
lowThresholdRatio 必須介於 0 到 1
date_rule.checkOutExclusive 不建議被改成 false，除非整個可用性查詢同步調整

8. 文件同步
要同步更新三處文件：[docs/schema.sql (line 462)](D:/githubdesk/Yuruicamp/docs/schema.sql:462)
[docs/database-er.md (line 239)](D:/githubdesk/Yuruicamp/docs/database-er.md:239)
[docs/mock-json-to-sql-seed.md (line 165)](D:/githubdesk/Yuruicamp/docs/mock-json-to-sql-seed.md:165)
