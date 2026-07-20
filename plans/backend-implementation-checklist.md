# Backend 實作代辦清單（線 A～J）

| 欄位 | 內容 |
|------|------|
| **狀態** | Active |
| **日期** | 2026-07-20 |
| **對齊** | [`java-backend-architecture-proposal.md`](./java-backend-architecture-proposal.md) §8 |
| **API 契約索引** | [`docs/api/README.md`](../docs/api/README.md)（P0+P1 已寫死，欄位策略甲） |
| **商品契約** | [`docs/api/product-api-contract.md`](../docs/api/product-api-contract.md) |

> 勾選規則：驗收通過再打勾。Schema 變更另見 [`backend-schema-change-checklist.md`](./backend-schema-change-checklist.md)。

---

## 總覽

| 階段 | 名稱 | 狀態 |
|------|------|------|
| Schema | DB 欄位／ENUM／保留逾時 | ✅ |
| **契約** | P0+P1 API Contracts（甲） | ✅ 見 [`docs/api/README.md`](../docs/api/README.md) |
| **A** | 骨架（Security／Session／Envelope／OpenAPI） | ✅ |
| **B** | Catalog 公開讀（商品） | 🔄 B-1／B-2 落地；B-3～B-7 待做 |
| **C** | Checkout + 庫存保留 + 15 分排程 | ⬜（契約已鎖） |
| **D** | Payment（ECPay + COD） | ⬜（契約已鎖） |
| **E** | Booking（營位 + 租借） | ⬜（契約已鎖） |
| **F** | Coupon 三種規則 | ⬜（契約已鎖） |
| **G** | Admin 細 RBAC + 後台 CRUD | ⬜（契約已鎖） |
| **H** | calendar／文章／評價 | ⬜（可延後；契約未寫） |
| **I** | 前端切真後端 | ⬜（可穿插） |
| **J** | GCP／Flyway／ADR 收尾 | ⬜ |

---

## Schema（備查）

- [x] `customers`／`admin_users.firebase_uid`
- [x] `payment_method` → ECPay + `cod`
- [x] `bookings` 付款欄位、禁 COD
- [x] `checkout_expires_at`、`payment_notifications`
- [x] Docker 整檔重建可跑

---

## 線 A — 骨架

- [x] package 分層、`ddl-auto=validate`、CORS
- [x] `ApiResponse`／錯誤碼／`GlobalExceptionHandler`
- [x] Firebase ID Token（含 `dev:` stub）
- [x] Customer／Admin session、`GET /api/me`、`GET /api/health`、Swagger
- [x] MapStruct；架構書認證 Mode B（不自簽 JWT）

---

## 線 B — Catalog 公開讀

**定案（2026-07-20）**

| # | 決策 |
|---|------|
| 1 | 階段劃分 A～J OK |
| 2 | 先做可通流程當範例 + 教學註解 |
| 3 | 欄位採 **甲**：對齊 DB／View 的精簡契約（見 Product API Contract） |
| 4 | 本輪做 **B-1 + B-2** + 教學註解 |

| 編號 | 項目 | 狀態 |
|------|------|------|
| B-1 | `GET /api/products` 列表（active） | ✅ |
| B-2 | `GET /api/products/{id}` 詳情 | ✅ |
| B-3 | 分頁 `page`／`size`／`sort` | ⬜（見 `ProductCatalogService` 教學註解） |
| B-4 | 篩選 category／brand／價格 | ⬜（見 Service 教學註解） |
| B-5 | 加深 variants／可賣庫存（View） | ⬜（見 Service 教學註解） |
| B-6 | Security：`GET /api/products/**` 公開 | ✅ |
| B-7 | （作業）`GET /api/branches` 同套路 | ⬜ |

**驗收**

- [x] Postman／curl：`GET /api/products` → Envelope + 契約欄位
- [x] Postman／curl：`GET /api/products/{id}` → 單筆；不存在 → `NOT_FOUND`（404）
- [x] Swagger Tag：`Catalog`
- [x] Mock／後端皆對齊 [`product-api-contract.md`](../docs/api/product-api-contract.md)（Mock 以 `_toProductContract` 正規化）

---

## 線 C — Checkout + 庫存保留（P0）

- [ ] C-1 Entity：`orders`／`order_items`／`product_stock_reservations`
- [ ] C-2 `POST /api/checkout/sessions`（D1.A 待付款 + 保留帳）
- [ ] C-3 交易內悲觀鎖／防超賣
- [ ] C-4 `PATCH .../sessions/{orderId}`
- [ ] C-5 `POST .../cancel`
- [ ] C-6 `@Scheduled` 15 分鐘逾時釋放
- [ ] C-7 金額後端重算
- [ ] C-8 整合測試：鎖庫、超賣、逾時

---

## 線 D — Payment（P0）

- [ ] D-1 ECPay Gateway + 本機 stub
- [ ] D-2 `POST .../ecpay`
- [ ] D-3 `POST /api/payments/ecpay/notify`（冪等）
- [ ] D-4 Return URL 導頁
- [ ] D-5 COD（僅商城）
- [ ] D-6 預約禁止 COD

---

## 線 E — Booking（P1）

- [ ] E-1 公開讀：營區／裝備／policy
- [ ] E-2 可用性查詢
- [ ] E-3 `POST /api/booking/checkout/sessions`
- [ ] E-4 租借加購綁預約
- [ ] E-5 `GET /api/booking/bookings`（僅自己的）
- [ ] E-6 逾時取消／釋放
- [ ] E-7 前端 `booking-api.js` 路徑統一

---

## 線 F — Coupon（P1）

- [ ] F-1 可領列表／我的券
- [ ] F-2 結帳三種券規則（後端重算）
- [ ] F-3 與 DB Trigger 不打架
- [ ] F-4 測試：灌水／重複用券

---

## 線 G — Admin（P1）

- [ ] G-1 細 RBAC
- [ ] G-2 customers／orders／bookings／products
- [ ] G-3 庫存異動
- [ ] G-4 優惠券／營區關閉日
- [ ] G-5 `POST /api/admin/users`
- [ ] G-6 `AdminAPI.configure({ useBackend: true })`

---

## 線 H — 可延後（P2）

- [ ] H-1 `calendar_dates` API
- [ ] H-2 文章 API
- [ ] H-3 評價 API

---

## 線 I — 前端接真後端

- [ ] I-1 `USE_MOCK_API = false`（可先只開 products）
- [ ] I-2 寫入帶 Firebase Bearer
- [ ] I-3 結帳金額綁後端 `pricing`
- [ ] I-4 Booking／Admin 切換

---

## 線 J — GCP／工程收尾（P3）

- [ ] J-1 部署草圖
- [ ] J-2 Secret Manager、Cloud Storage
- [ ] J-3 Flyway
- [ ] J-4 ADR + 關鍵交易整合測試補齊
