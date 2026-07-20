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
| **B** | Catalog 公開讀（商品） | 🔄 B-1～B-3、B-5a 已完成；B-4、B-5b～B-7 待做 |
| **C** | Checkout + 庫存保留 + 15 分排程 | 🔄 C-1／C-2／C-3／C-5／C-7 已驗收；C-4／C-6／C-8 待完成 |
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
| B-3 | 分頁 `page`／`size`／`sort` | ✅ PostgreSQL／Controller 整合驗收通過（Product API Contract v0.2） |
| B-4 | 篩選 category／brand／價格 | ⬜（見 Service 教學註解） |
| B-5a | 基本商品規格 `variants[]` | ✅ 已隨 B-1／B-2 落地；只回 active variant，包含 SKU／顏色／尺寸／規格／價格 |
| B-5b | 規格層級可售庫存（View／Read Model） | ⬜ 尚未實作；需先升版 Product API Contract，再加入 `availableQuantity`／`inStock` |
| B-6 | Security：`GET /api/products/**` 公開 | ✅ |
| B-7 | （作業）`GET /api/branches` 同套路 | ⬜ |

**驗收**

- [x] Postman／curl：`GET /api/products` → Envelope + 契約欄位
- [x] Postman／curl：`GET /api/products/{id}` → 單筆；不存在 → `NOT_FOUND`（404）
- [x] Swagger Tag：`Catalog`
- [x] Mock／後端皆對齊 [`product-api-contract.md`](../docs/api/product-api-contract.md)（Mock 以 `_toProductContract` 正規化）
- [x] 基本 `variants[]` 隨列表／詳情回傳，只包含 active variant，價格為兩位小數字串
- [ ] 規格層級可售庫存：`inventory_stocks - active product_stock_reservations`，尚未建立 Catalog 讀模型與 API 欄位
- [x] B-3：非空分頁、跨頁無重複／遺漏、`id`／`name` 雙向 PostgreSQL 排序、參數錯誤 Envelope、超頁 meta 與實際 Controller 驗收

> B-3 驗收細節與執行指令見 [`b3-product-pagination-validation.md`](../docs/backend-specs/catalog/b3-product-pagination-validation.md)。

---

## 線 C — Checkout + 庫存保留（P0）

- [x] C-1 Entity：`orders`／`order_items`／`product_stock_reservations`（Hibernate `ddl-auto=validate` + Docker PostgreSQL 整合測試通過）
- [x] C-2 `POST /api/checkout/sessions`（D1.A 待付款 + 保留帳；會員層冪等、Payload 指紋與空值保障已驗收）
- [x] C-3 交易內悲觀鎖／防超賣（PostgreSQL 雙執行緒競爭最後一件庫存，只有一筆成功）
- [ ] C-4 `PATCH .../sessions/{orderId}`
- [x] C-5 `POST .../cancel`（PostgreSQL 驗證保留帳由 `active` 改為 `released`）
- [ ] C-6 `@Scheduled` 15 分鐘逾時釋放
- [x] C-7 金額後端重算（偽造 `unitPrice`／`total` 不會覆蓋資料庫價格）
- [ ] C-8 整合測試：鎖庫與超賣已完成；逾時排程仍待 C-6

> C-1／C-2／C-3／C-5／C-7 已於 2026-07-20 通過 PostgreSQL 驗收。C-1 見 [`c1-entity-schema-validation.md`](../docs/backend-specs/order/c1-entity-schema-validation.md)，C-2 見 [`c2-create-checkout-idempotency.md`](../docs/backend-specs/checkout/c2-create-checkout-idempotency.md)，庫存與金額見 [`c3-c5-c7-postgresql-validation.md`](../docs/backend-specs/checkout/c3-c5-c7-postgresql-validation.md)。

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
