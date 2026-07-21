# Backend 實作代辦清單（線 A～J）

| 欄位             | 內容                                                                                  |
| ---------------- | ------------------------------------------------------------------------------------- |
| **狀態**         | Active                                                                                |
| **日期**         | 2026-07-20                                                                            |
| **對齊**         | [`java-backend-architecture-proposal.md`](./java-backend-architecture-proposal.md) §8 |
| **API 契約索引** | [`docs/api/README.md`](../docs/api/README.md)（P0+P1 已寫死，欄位策略甲）             |
| **商品契約**     | [`docs/api/product-api-contract.md`](../docs/api/product-api-contract.md)             |

> 勾選規則：驗收通過再打勾。Schema 變更另見 [`backend-schema-change-checklist.md`](./backend-schema-change-checklist.md)。

---

## 總覽

| 階段     | 名稱                                         | 狀態                                                |
| -------- | -------------------------------------------- | --------------------------------------------------- |
| Schema   | DB 欄位／ENUM／保留逾時                      | ✅                                                  |
| **契約** | P0+P1 API Contracts（甲）                    | ✅ 見 [`docs/api/README.md`](../docs/api/README.md) |
| **A**    | 骨架（Security／Session／Envelope／OpenAPI） | ✅                                                  |
| **B**    | Catalog 公開讀（商品）                       | 🔄 B-4 已驗收；B-5b、B-7 已實作，待完整驗收           |
| **C**    | Checkout + 庫存保留 + 15 分排程              | ✅ C-1～C-8 已驗收；C-4 優惠券套用另待 F-2          |
| **D**    | Payment（ECPay + COD）                       | ⬜（契約已鎖）                                      |
| **E**    | Booking（營位 + 租借）                       | ✅ E-0～E-7 已完成；Payment Confirmation 延後至線 D |
| **F**    | Coupon 三種規則                              | ⬜（契約已鎖）                                      |
| **G**    | Admin 細 RBAC + 後台 CRUD                    | ⬜（契約已鎖）                                      |
| **H**    | calendar／文章／評價                         | ⬜（可延後；契約未寫）                              |
| **I**    | 共用 REST 基礎 + 商城 Checkout 前端接線      | 🔄 I-2a～I-6 已完成；I-1、I-7～I-8 待完成           |
| **J**    | GCP／Flyway／ADR 收尾                        | ⬜                                                  |

---

## Schema（備查）

- [x] `customers`／`admin_users.firebase_uid`
- [x] `payment_method` → ECPay + `cod`
- [x] `bookings` 付款欄位、禁 COD
- [x] `bookings` Checkout 冪等 key、request hash、會員範圍唯一約束（E-3 Service 已完成回放與 payload 衝突判斷）
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

| #   | 決策                                                               |
| --- | ------------------------------------------------------------------ |
| 1   | 階段劃分 A～J OK                                                   |
| 2   | 先做可通流程當範例 + 教學註解                                      |
| 3   | 欄位採 **甲**：對齊 DB／View 的精簡契約（見 Product API Contract） |
| 4   | 本輪做 **B-1 + B-2** + 教學註解                                    |

| 編號 | 項目                                  | 狀態                                                                              |
| ---- | ------------------------------------- | --------------------------------------------------------------------------------- |
| B-1  | `GET /api/products` 列表（active）    | ✅                                                                                |
| B-2  | `GET /api/products/{id}` 詳情         | ✅                                                                                |
| B-3  | 分頁 `page`／`size`／`sort`           | ✅ PostgreSQL／Controller 整合驗收通過（Product API Contract v0.2）               |
| B-4  | 篩選 category／brand／價格            | ✅ PostgreSQL 實際端點驗收通過；無篩選、品牌、價格與錯誤區間皆符合契約            |
| B-5a | 基本商品規格 `variants[]`             | ✅ 已隨 B-1／B-2 落地；只回 active variant，包含 SKU／顏色／尺寸／規格／價格      |
| B-5b | 規格層級可售庫存（View／Read Model）  | 🔄 Product API Contract v0.3 與程式已完成；待 PostgreSQL 驗收                     |
| B-6  | Security：`GET /api/products/**` 公開 | ✅                                                                                |
| B-7  | （作業）`GET /api/branches` 同套路    | 🔄 已實作公開 Envelope、固定排序與 Swagger；待實際端點驗收                        |

**驗收**

- [x] Postman／curl：`GET /api/products` → Envelope + 契約欄位
- [x] Postman／curl：`GET /api/products/{id}` → 單筆；不存在 → `NOT_FOUND`（404）
- [x] Swagger Tag：`Catalog`
- [x] Mock／後端皆對齊 [`product-api-contract.md`](../docs/api/product-api-contract.md)（Mock 以 `_toProductContract` 正規化）
- [x] 基本 `variants[]` 隨列表／詳情回傳，只包含 active variant，價格為兩位小數字串
- [ ] 規格層級可售庫存：讀模型與 API 欄位已完成，待 PostgreSQL 驗證後勾選
- [x] B-3：非空分頁、跨頁無重複／遺漏、`id`／`name` 雙向 PostgreSQL 排序、參數錯誤 Envelope、超頁 meta 與實際 Controller 驗收

> B-3 驗收細節與執行指令見 [`b3-product-pagination-validation.md`](../docs/backend-specs/catalog/b3-product-pagination-validation.md)。
> B-4／B-5b／B-7 流程見 [`b4-b5b-b7-catalog-public-read.md`](../docs/backend-specs/catalog/b4-b5b-b7-catalog-public-read.md)，Swagger 見 [`b-catalog-public-swagger.md`](../docs/backend-specs/test/b-catalog-public-swagger.md)。

---

## 線 C — Checkout + 庫存保留（P0）

- [x] C-1 Entity：`orders`／`order_items`／`product_stock_reservations`（Hibernate `ddl-auto=validate` + Docker PostgreSQL 整合測試通過）
- [x] C-2 `POST /api/checkout/sessions`（D1.A 待付款 + 保留帳；會員層冪等、Payload 指紋與空值保障已驗收）
- [x] C-3 交易內悲觀鎖／防超賣（PostgreSQL 雙執行緒競爭最後一件庫存，只有一筆成功）
- [x] C-4 `PATCH .../sessions/{orderId}`（收件資料、付款方式、本人限制、期限檢查與悲觀鎖已完成；**優惠券功能尚未完成，等待 F-2**）
- [x] C-5 `POST .../cancel`（PostgreSQL 驗證保留帳由 `active` 改為 `released`）
- [x] C-6 `@Scheduled` 15 分鐘逾時釋放（每分鐘掃描；訂單鎖定、取消、保留帳 `expired` 與歷程同交易完成）
- [x] C-7 金額後端重算（偽造 `unitPrice`／`total` 不會覆蓋資料庫價格）
- [x] C-8 整合測試：鎖庫、超賣、逾時取消、庫存恢復與重複執行冪等皆通過真正 PostgreSQL 驗證

> C-1／C-2／C-3／C-5／C-7 已於 2026-07-20 通過 PostgreSQL 驗收；C-4／C-6／C-8 已於 2026-07-21 通過。C-1 見 [`c1-entity-schema-validation.md`](../docs/backend-specs/order/c1-entity-schema-validation.md)；C-2～C-8 的唯一整合流程與驗收文件見 [`checkout/README.md`](../docs/backend-specs/checkout/README.md)。

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

- [x] E-0 Booking Checkout 冪等 Schema（key、request hash、會員範圍唯一約束）
- [x] E-1 公開讀：營區／裝備／policy／closures（PostgreSQL + Controller 7 項整合測試通過）
- [x] E-2 `POST /api/booking/check-availability`（日期／政策驗證、跨晚最低量、公休、zone block、pending／confirmed 占用；PostgreSQL 11 項整合測試通過）
- [x] E-3 `POST /api/booking/checkout/sessions`（會員冪等、固定順序悲觀鎖、後端日曆計價、pending／unpaid 快照；PostgreSQL 7 項整合測試通過）
- [x] E-4 租借加購綁預約（營區庫位解析、實體庫存鎖、跨日 active 保留、快照與並發防超租；PostgreSQL 8 項整合測試通過）
- [x] E-5 會員預約讀取：列表分頁、詳情、Checkout 快照、本人限制與 404 隔離（PostgreSQL 7 項；E-1～E-5 回歸 40 項通過）
- [x] E-6 主動取消／15 分鐘逾時釋放（Booking 鎖定、營位恢復、active 租借保留改 released、歷程冪等與付款競爭；PostgreSQL 6 項，E-1～E-6 回歸 46 項通過）
- [x] E-7 前端接線（`/api/booking/**`、Bearer、Envelope／meta、後端可用性與價格、Booking ID、倒數、本人列表／詳情／取消；2 組 E-7 自動測試與既有回歸通過）

> 線 E 完成的是 Booking Prepare／Reservation。ECPay 表單、Notify 驗簽、`paid`、`confirmed`、租借 fulfilled 與付款後導頁仍由線 D 負責。

---

## 線 F — Coupon（P1）

- [x] F-1 可領列表／我的券
- [ ] F-2 結帳三種券規則（商城 C-4 套用／切換／清除已完成；Booking 缺少 Coupon 關聯 Schema，仍維持拒絕非 null）
- [x] F-3 與 DB Trigger 不打架（Service 管資格與折扣；Trigger 僅原子配置名額）
- [x] F-4 測試：名額、重複領券、售罄、資格、後端折扣快照與取消規則通過 PostgreSQL 驗證

> 線 F 的領券與商城套券已完成；F-2 要完整勾選前，需先決定 Booking Coupon 關聯 Schema。付款成功或 COD 成立後將 claim 改為 `consumed`，由線 D 在同一付款交易呼叫。流程見 [`coupon/README.md`](../docs/backend-specs/coupon/README.md)，Swagger 見 [`f-coupon-swagger.md`](../docs/backend-specs/test/f-coupon-swagger.md)。

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

## 線 I — 共用 REST 基礎 + 商城 Checkout 前端接線

- [ ] I-1 全域 Mock／Backend 模式基線（不能只看 `USE_MOCK_API=false`；各目標 API client 必須實際依設定分流）
- [x] I-2a Firebase／dev Token provider（`AppAuth.getIdToken()`；未在頁面寫死 Token）
- [x] I-2b 共用 REST request helper（`ApiClient._restRequest()`；Bearer、Envelope、meta 與錯誤處理）
- [x] I-3a 新增 `API.checkout` facade（六個契約方法、Bearer、orderId 編碼與無重複 `/api` 路徑測試通過）
- [x] I-3b 建立契約一致的 Checkout Mock adapter（後端價格、完整 Session、冪等、獨立儲存與 Legacy Backend 封鎖測試通過）
- [x] I-4 `checkout.js` 改呼叫 `createSession`（精簡 Request、UUID 冪等鍵、重試／連點共用、購物車變更與取消／逾時清除）
- [x] I-5 Backend 成交狀態改由 CheckoutSession 掌管
  - [x] I-5a 建立成功後以 `CheckoutSession.pricing` 覆蓋摘要；送出前金額只標示為預估
  - [x] I-5b Backend 模式不寫 Legacy Order／前端狀態，頁面暫存改為 `sessionStorage.lastCheckoutSession`
  - [x] I-5c 移除信用卡欄位與驗證，ECPay 僅顯示下一步提示
  - [x] I-5d Backend 模式停用前端優惠券交易與折扣，等待線 F
- [x] I-6 CheckoutSession／錯誤／倒數 UI（Draft PATCH、Ready 15 分倒數、Expired／Cancelled 清理與錯誤操作已完成）
- [ ] I-7 COD 或 ECPay 接線（依賴線 D）
- [ ] I-8 商城 Checkout 前端整合驗收與文件

> **責任邊界**：I-1 是全域模式基線；I-2a～I-2b 是全前端共用 API 基礎；I-3a～I-8 只負責商城 Checkout。E-7 負責 Booking 前端接線，必須重用 I-2a／I-2b，不可另建 Token、REST、Envelope 或錯誤處理流程。

---

## 線 J — GCP／工程收尾（P3）

- [ ] J-1 部署草圖
- [ ] J-2 Secret Manager、Cloud Storage
- [ ] J-3 Flyway
- [ ] J-4 ADR + 關鍵交易整合測試補齊
