# LINE n8n 訂單狀態客服 MVP — 執行紀錄

> 本文件記錄依照 `message.txt`（LINE n8n 依據訂單客服 MVP 程式端執行規格）實際執行任務時的完整流程：讀取了什麼、思考重點、新增／修改了哪些檔案、如何驗證。屬於一次性執行紀錄，非長期維護文件。

---

## 1. 執行前必讀（依 message.txt 第 0 節要求）

任務開始前依序讀取並遵守以下檔案的限制條件：

1. `.agents/agents.md`
2. `.agents/mapping-agents.md`
3. `AGENTS.md`
4. `docs/stream/line-n8n-order-status-mvp-plan.md`（message.txt 原指 `docs/line-n8n-order-status-mvp-plan.md`，實際檔案位於 `docs/stream/` 下，已確認並讀取此份既有計畫文件）
5. `plans/java-backend-architecture-proposal.md`
6. `plans/backend-implementation-checklist.md`
7. `plans/data-integration-spec.md`
8. `docs/api/README.md`
9. `backend/README.md`
10. `docs/seed/README.md`
11. `README.md`

讀取後確認的關鍵限制條件（節錄）：

- 不修改主資料庫 schema、不新增 seed、不修改 `docs/latest_schema.sql`。
- 不新增 Spring Boot 依賴，只用既有套件。
- 正式 HTTP 只走 `AppAuth + ApiClient`，禁止另開 `fetch()`／localStorage token。
- 新增程式一律加中文註解；Controller 每個端點要有簡短中文說明其功能。
- 排版規則：註解獨立一行、方法間空行、方法內用空行區隔「參數驗證／業務邏輯／回傳結果」。
- 後端流程文件集中寫在 `docs/backend-specs/`；根目錄與 `backend/README.md` 需同步更新。
- 若沒有實際完成的驗證流程，不建立 `docs/backend-specs/test/` 文件。

---

## 2. 探索既有程式碼慣例

由於此功能會新增一個全新的後端 package（`integration.line`）與前端呼叫路徑，執行前先派出一個唯讀探索 Agent，確認以下既有慣例，避免自創風格：

| 探索目標 | 找到的參考檔案 |
|---|---|
| 設定檔巢狀類別寫法 | `backend/.../config/YuruicampProperties.java`（`Ecpay`、`EcpayLogistics` 巢狀 class） |
| `application.properties` 分段慣例 | 既有 ECPay／Logistics 區塊格式 |
| Security 白名單寫法 | `backend/.../config/SecurityConfig.java`（ECPay Notify `permitAll` 註解風格） |
| 會員 Principal 解析、本人訂單查詢 | `CustomerPrincipal`、`MemberOrderController`、`MemberOrderService`、`OrderRepository.findForCustomer` |
| 統一錯誤與回應格式 | `BusinessException`、`ErrorCode`、`GlobalExceptionHandler`、`ApiResponse` |
| Controller 註解風格範例 | `MeController.java` |
| 前端 LINE 按鈕與 Modal 呼叫模式 | `frontend/storefront/js/components/member-center.js`、`frontend/components/member-center.partial`、`frontend/storefront/js/api-mock.js` |
| 文件格式範本 | `docs/backend-specs/order/member-order-read.md`、`docs/backend-specs/test/member-shipping-address-api-validation.md` |

確認重點：專案目前**沒有**任何對外呼叫 HTTP（如呼叫 n8n Webhook）的既有範例，也沒有 `X-Internal-Api-Key` 這類 header 驗證的既有寫法，因此這兩塊是本次新增的第一個先例，需自行依既有風格延伸設計。另外確認 `spring-boot-starter-webmvc` 已內含 `RestClient`，不需新增依賴即可呼叫外部 Webhook。

---

## 3. 後端實作（package：`com.yuruicamp.backend.integration.line`）

### 3.1 設定

- `YuruicampProperties.java`：新增巢狀類別 `LineIntegration`，欄位 `internalApiKey`／`bindingCodeWebhookUrl`／`officialAccountUrl`。
- `application.properties`：新增對應三個 `yuruicamp.line-integration.*` 設定鍵，皆可用環境變數覆寫。

### 3.2 會員端：產生一次性綁定碼

- `api/LineBindingCodeRequest.java`、`api/LineBindingCodeResponse.java`
- `api/LineBindingController.java` — `POST /api/me/line-binding/code`
- `application/LineBindingCodeService.java` — 確認訂單屬於本人（沿用 `OrderRepository.findForCustomer`）、產生 6 位數綁定碼、10 分鐘後過期、呼叫 Webhook Client
- `infrastructure/LineBindingCodePayload.java`、`infrastructure/LineBindingCodeWebhookClient.java` — 用 `RestClient` 呼叫 n8n Webhook，帶 `X-Internal-Api-Key`；Webhook 網址未設定回 `409 CONFLICT`，呼叫失敗回 `500 INTERNAL_ERROR`

### 3.3 n8n 端：查詢來源訂單狀態

- `api/InternalLineOrderResponse.java`
- `api/InternalLineOrderController.java` — `GET /api/internal/line/orders/{orderId}?customerId=`，以 `@RequestHeader(required = false)` 讀取 `X-Internal-Api-Key`
- `application/InternalLineOrderService.java` — 驗證 API Key（`403`）、必填參數（`400`）、本人歸屬（`404`，訊息固定「查無此訂單」），組裝不含個資的訂單摘要

### 3.4 Security

- `SecurityConfig.java`：新增 `.requestMatchers("/api/internal/line/**").permitAll()`，實際驗證交給 Controller 內的 API Key 檢查。

### 3.5 驗證

執行 `mvnw.cmd -q -o compile`，兩次（新增程式後、文件與前端調整後各一次），皆為 `EXIT_CODE=0`，確認未破壞既有編譯。

---

## 4. 前端實作

- `frontend/components/member-center.partial`：新增 `lineBindOverlay` Modal（標題、關閉鈕、內容容器）。
- `frontend/storefront/js/components/member-center.js`：
  - 商品訂單（`type === 'purchase'`）的 LINE 按鈕由原本寫死的 `<a href="https://line.me/...">` 改成 `<button data-line-bind-order="訂單ID">`；預約（rental）維持原本官方帳號連結，不變動。
  - 新增 `window.requestLineBindCode()`：呼叫 `window.API.lineBinding.createCode()`，成功後用後端回傳的 `bindText`／`lineUrl` 組出 Modal 內容（`renderLineBindBody`），並提供複製按鈕（`copyLineBindText`）。
  - 事件委派新增 `[data-line-bind-order]` 分支；Modal 關閉清單、Escape 鍵清單、`bindModals()` 對照表都補上 `lineBindOverlay`／`lineBindClose`。
- `frontend/storefront/js/api-mock.js`：新增 `memberLineBindingApi.createCode()`，只透過 `window.ApiClient._restRequest('/me/line-binding/code', ...)` 呼叫，掛到 `window.API.lineBinding`。

驗證：`node --check` 對 `member-center.js`、`api-mock.js` 皆通過語法檢查。

---

## 5. 文件更新

| 檔案 | 異動內容 |
|---|---|
| `docs/api/line-integration-api-contract.md`（新增） | 兩個端點的完整 Request／Response／規則契約 |
| `docs/api/README.md` | 契約索引新增一列 |
| `docs/backend-specs/integration/line-n8n-order-status-mvp.md`（新增） | 用途、主要流程、回應規則、分層責任、n8n 端資料表、本輪不做範圍 |
| `docs/backend-specs/test/line-n8n-order-status-swagger-validation.md`（新增） | 兩個端點的人工 Swagger 驗證步驟與必要性說明 |
| `backend/README.md` | 後端進度表新增一列；設定鍵段落新增三個環境變數 |
| `README.md`（根目錄） | 後端實作狀態新增一條說明；新增 `v1.3.77` 版本紀錄 |

---

## 6. 本輪刻意不做（依計畫文件與限制條件）

- 不修改 Yuruicamp 主資料庫 schema，也未新增 seed。
- 不做 LINE Login／LIFF、解除綁定、任意欄位查詢、最近多筆訂單列表。
- 預約（Booking）LINE 詢問維持原本官方帳號連結，未接綁定碼流程。
- n8n Workflow 本身（綁定分支、查詢分支）屬於 n8n 環境設定，不在本專案程式碼範圍內，只在文件中記錄其資料表與串接方式供對接。
