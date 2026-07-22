# 請先讀取:
- /plans/java-backend-architecture-proposal.md 
- /plans/data-integration-spec.md
- /docs/api/README.md
- /docs/seed/README.md
- README.md
- \plans\frontend-folder-migration-spec.md
- \plans\frontend-root-absolute-path-and-api-contract-spec.md


# 限制條件:
- 執行完任務將所有相關文件更新。
- 根目錄的README.md 也要更新。
- 不要產生因為錯誤紀錄的log 檔案。
- 所有前端行為都要以後端為主。

- 有新增seed 資料的話遵守以下架構不要破壞。
docs/seed/
├── README.md
├── 002-dev-seed.sql          # 統一入口，只負責依序載入
└── dev/
    ├── 010-reference.sql     # 品牌、分類、分店、庫位等基礎資料
    ├── 020-identity.sql      # 開發會員、管理員
    ├── 030-catalog.sql       # equipment、products、variants、images
    ├── 040-inventory.sql     # inventory_stocks
    ├── 050-coupons.sql       # 優惠券展示資料
    ├── 060-orders.sql        # 可選：開發展示訂單
    └── 070-bookings.sql      # 可選：開發展示預約

- frontend/data/* 同步都要依/docs/seed/* 的資料為準去同步。
- 所有文件敘述都用/docs/seed/README.md 的方式去參考

# 預期目標:
- 嚴格遵守限制條件完成任務
