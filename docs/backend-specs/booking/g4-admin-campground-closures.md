# G-4 Admin Campground Closures

## 用途

將後台公休設定由 `mockCampgroundClosures` overlay 移至 PostgreSQL `campground_closures`，讓公開 closures 與可用性查詢立即使用同一份資料。

## 流程

Controller 提供分頁列表、詳情、建立、部分更新與刪除，分別以 `booking-calendar.view`／`booking-calendar.edit` 保護。建立時從登入 Principal 記錄 `created_by`；Service 驗證營區存在且啟用，再依公休類型驗證互斥欄位。更新先鎖定原列並將另一類型的欄位清為 null。

前端 Backend 模式直接讀 Admin API。建立或刪除成功後重新查詢資料庫再渲染；失敗不寫入 overlay。Mock 模式仍保留 overlay，供 G-6 全站切換前本機展示。

## 核心規則

- `date_range` 必須提供 `startDate`、`endDate`，採 `[startDate,endDate)`。
- `weekly` 必須提供 `weekday` 0～6 與 `effectiveFrom`／`effectiveTo`，生效日期兩端均包含。
- 日期公休不可同時保存 weekly 欄位，weekly 亦不可保存日期區間欄位。
- 建立者由後端記錄，Request 不接受 `createdBy`。
- 刪除後，公開 closures 與可用性查詢不再套用該規則。

## 驗證

`AdminG4PostgreSqlIntegrationTest` 覆蓋日期公休建立、公開端可見、切換 weekly、非法空區間、刪除及 view-only RBAC。前端 facade test 覆蓋正式 API 路由與乾淨 Request mapping。
