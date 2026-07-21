# E-1 Booking 公開讀 Swagger 驗證

## 測試前確認

- PostgreSQL 已載入最新 schema 與 dev seed。
- 後端已啟動。
- 開啟 `http://localhost:8080/swagger-ui.html`。
- E-1 全部是公開 GET，不需要按 `Authorize`。

## 驗證步驟

1. 執行 `GET /api/booking/campgrounds`：預期 HTTP 200，包含 `C002`，不包含停用的 `C009`。
2. 執行 `GET /api/booking/campgrounds/C002`：預期只包含 `C002-Z-A`，價格為 `"1200.00"`、`"1500.00"`。
3. 執行 `GET /api/booking/campgrounds/UNKNOWN`：預期 HTTP 404、`error.code=NOT_FOUND`。
4. 執行 `GET /api/booking/equipment?campgroundId=C002`：預期包含 `RL-DEV-C002-001`，不會出現 `stock` 欄位。
5. 執行 `GET /api/booking/policy`：預期 `occupyingStatuses` 只有 `confirmed`、`pending`。
6. 執行 `GET /api/booking/closures`：預期包含 C002 的 `date_range` 範例。

## 完成標準

- 所有成功回應都有 `success=true` 與契約欄位。
- 列表回應包含單頁 `meta`。
- 金額都是固定兩位字串。
- 停用資料不會出現在公開 API。

手動 Swagger 驗證可確認文件、路徑與實際回應適合前端操作；active 過濾和 read-model SQL 仍由 PostgreSQL 整合測試保障，兩者缺一不可。
