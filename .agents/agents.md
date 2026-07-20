請先讀取：
- `docs/latest_schema.sql`（現行 DDL 真相來源）
- 需要導覽時可輔以 `docs/database-schema-guide.md`、`docs/schema-enums.md`

## 任務目標:
要使用Trigger 和View 的地方如果不符合技術限制，留著給後端Sprint boot 擴充，不要直接寫在資料庫。

## 問題解決流程:
依照技術限制的要求滿足任務目標。

## 預期結果：
避免將多餘的Trigger, View 寫在資料庫，先不要寫後端。

## 技術限制：
* 以下情境留給資料庫做 Trigger :
- created_at / updated_at 自動更新
- audit log / 異動紀錄
- 防止刪除重要資料
- 資料異動時自動寫入 log table
- 確保某些欄位一定同步

* 以下情境留給資料庫做 View :
- 報表查詢
- 複雜 JOIN
- 很多 API 都需要同一個查詢結果
- 其他系統也要查這個整理後資料
- 想把固定查詢邏輯放在資料庫

* 以上都沒有達成，建議 :
- Trigger → 優先用 Spring Boot Service
- View → 優先用 DTO / Projection
