# G-2c Admin Products 前端驗收

| 欄位 | 內容 |
|------|------|
| 驗收範圍 | Products 頁 Mock／Backend 雙模式、Admin Products API 與瀏覽器互動 |
| 驗收日期 | 2026-07-22 |
| 本次結果 | API 與 Mock UI 通過；Backend UI 仍需人工執行 Console 切換後完成 |
| 測試資料 | `Pc64b9dbc461c44d4b943b4c4159adea`，最終為 inactive |

## 驗證目的

確認商品管理頁不再把前端 Mock 的胖物件直接送到後端，並符合以下責任邊界：

- Backend 模式只寫商品基本資料、圖片與規格。
- `branch`、`totalStock`、`rentalEnabled`、`camp`、評價與銷售衍生欄位不進入 Request。
- 庫存只顯示後端摘要，不在商品編輯流程調整。
- API 成功後才更新 `adminProductsCache`；錯誤時保留 Modal 與原列表。
- Mock 模式繼續保留既有庫存、檔案圖片與租借操作。

## 測試前確認

### 1. 啟動服務

在 repo 根目錄啟動 PostgreSQL：

```powershell
docker compose up -d
docker compose ps
```

預期 `yuruicamp-db` 為 `healthy`，並映射 `5433 -> 5432`。

啟動後端：

```powershell
$env:DB_PASSWORD = "<與 .env 相同的 POSTGRES_PASSWORD>"
cd backend
.\mvnw.cmd spring-boot:run
```

啟動前端：

```powershell
cd frontend
npm run dev
```

確認以下網址回應成功：

```text
http://127.0.0.1:8080/api/health
http://127.0.0.1:5173/admin/dashboard.html
```

### 2. 登入後台

開啟 `http://127.0.0.1:5173/admin/login.html`，使用開發登入：

```text
員工 ID：01
密碼：任意非空文字
```

登入後點左側「商品與庫存」。預期頁面能顯示商品表格、上下架 badge、庫存欄與「新增商品」按鈕。

### 3. 啟用 Backend 模式

G-6 尚未完成全站永久切換，因此每次重新整理頁面後，都要在瀏覽器 DevTools Console 執行：

```js
AdminAPI.configure({
  useBackend: true,
  baseUrl: 'http://localhost:8080/api/admin'
});

initProducts();
```

執行後不要立刻重新整理；重新整理會讓 `useBackend` 回到預設的 `false`。若頁面仍顯示租借頁籤、最低庫存按鈕或可編輯的庫存欄，表示 Backend 模式尚未生效。

> 本次自動 Browser 驗收不能代替使用者執行 DevTools Console 指令，因此 Backend UI 的視覺與 Network 操作仍列為人工待驗；API 與 Mock UI 已實際驗證。

## A. Mock 模式回歸

先維持預設 `useBackend:false`，進入「商品與庫存」。

### A-1. 商品列表

確認：

- 商店與租借頁籤都存在。
- 商品列可顯示「上架」或「下架」badge。
- 表格包含總庫存、商店主倉與各分店欄位。
- 多規格商品可展開規格明細。
- 「設定最低庫存」與「產生異動紀錄」仍存在。

### A-2. 新增商品 Modal

點「新增商品」，確認：

- 圖片使用檔案選擇器，說明為「可一次選多張；第一張為主圖」。
- 分類與品牌允許選擇「＋ 新增自訂…」。
- 顯示主倉進貨量、規格進貨量與商品總庫存。
- 顯示「是否為租借商品」開關。
- 規格卡包含顏色、尺寸、SKU、規格說明、售價與狀態。

以上欄位在 Mock 模式出現是正確行為，不應因 G-2c 被移除。

## B. Backend 模式列表與表單

完成「啟用 Backend 模式」後，重新進入商品管理。

### B-1. 列表資料

在 Network 找到：

```http
GET /api/admin/products?page=0&size=100&sort=id,asc
GET /api/admin/products/lookups
```

預期：

- HTTP `200`，並帶 Admin Bearer Token。
- 列表可同時顯示 active 與 inactive 商品。
- 庫存數字來自 Response 的 `totalOnHand`／`stockLocations`，僅供顯示。
- 同一商品不會因多張圖片或多個規格重複成多列。
- 分類與品牌下拉選項來自 lookup；Backend 模式沒有「＋ 新增自訂…」。

### B-2. Backend UI 邊界

點「新增商品」，確認：

- 租借頁籤、「是否為租借商品」與「調至租借」操作隱藏。
- 最低庫存操作、初始庫存與分店庫存輸入隱藏或不可編輯。
- 檔案圖片選擇器隱藏，改為圖片 URL 輸入。
- 圖片 URL 只接受 `/assets/**` 或 `http://`、`https://`。
- 規格仍可編輯 SKU、顏色、尺寸、規格說明、價格與狀態。
- 規格區顯示「庫存由庫存異動功能管理」提示。

## C. 建立商品

### C-1. 表單資料

可使用以下測試值，SKU 每次要換成新的時間字串：

```text
商品名稱：G2C Browser Validation 20260722120000
分類：帳篷
品牌：Yuruicamp
狀態：上架
圖片：/assets/images/products/g2c-browser.jpg

規格 1：
SKU：G2C-BROWSER-20260722120000-A
顏色：Olive
尺寸：L
規格說明：Olive / L
售價：3200.00
狀態：啟用

規格 2：
SKU：G2C-BROWSER-20260722120000-B
顏色：Sand
尺寸：L
規格說明：Sand / L
售價：3300.00
狀態：啟用
```

### C-2. Network Request

按「建立商品」後檢查：

```http
POST /api/admin/products
Content-Type: application/json
```

Request 的最外層只能有：

```text
name, description, categoryId, brandId, status, images, variants
```

Request 範例：

```json
{
  "name": "G2C Browser Validation 20260722120000",
  "description": "<p>Frontend acceptance validation.</p>",
  "categoryId": 1,
  "brandId": "yuruicamp",
  "status": "active",
  "images": [
    {
      "url": "/assets/images/products/g2c-browser.jpg",
      "altText": "G2C Browser Validation 20260722120000"
    }
  ],
  "variants": [
    {
      "id": null,
      "sku": "G2C-BROWSER-20260722120000-A",
      "color": "Olive",
      "size": "L",
      "specification": "Olive / L",
      "price": "3200.00",
      "status": "active"
    }
  ]
}
```

必須確認 Request 沒有：

```text
branch, totalStock, rentalEnabled, camp, rating, salesCount
```

### C-3. 成功結果

預期 HTTP `200`，並確認：

- Response 產生 `id`、`itemId` 與每個 variant 的 `id`。
- `totalOnHand`、`totalReserved`、`totalAvailable` 都是 `0`。
- 商品列表使用 Response 內容新增資料，不使用前端暫編 ID。
- Modal 關閉並顯示成功 Toast。
- 資料庫不會新增該商品的 `inventory_stocks`。

## D. 更新商品與規格停用

打開剛建立的商品：

1. 修改商品名稱與第一個規格價格。
2. 加入第二張圖片 URL。
3. 保留第一個規格。
4. 從表單移除第二個既有規格。
5. 儲存並檢查 `PUT /api/admin/products/{productId}`。

預期：

- 第一個既有規格 Request 帶原本的 `id`。
- 新規格不帶 `id` 或送 `null`。
- Response 的圖片 `sortOrder` 依序為 `0`、`1`。
- 被移除的既有規格仍存在，但 `status=inactive`，不會硬刪。
- 庫存摘要仍為唯讀，Request 沒有庫存欄位。

## E. 失敗狀態與 cache 保護

### E-1. 重複 SKU

把某個規格 SKU 改成資料庫已存在的 SKU 後送出。

預期：

```text
HTTP 409
error.code = CONFLICT
```

### E-2. 負價格

將規格售價設為負數。若瀏覽器 number input 阻擋送出，可在 Swagger 或 API 工具送出 `-1.00` 驗證後端。

預期：

```text
HTTP 400
error.code = VALIDATION_ERROR
```

### E-3. UI 狀態

上述任一失敗發生後確認：

- Modal 保持開啟。
- 已填內容仍在，可修正後直接重送。
- 列表沒有先出現失敗的名稱、價格或規格。
- `adminProductsCache` 維持最後一次成功 Response。
- 錯誤 Toast 顯示後端訊息。

## F. 上下架與公開商品

### F-1. 下架

將商品狀態改為「下架」並儲存，或呼叫：

```http
POST /api/admin/products/{productId}/deactivate
```

預期：

- 後台詳情仍回 HTTP `200`，`status=inactive`。
- 公開 `GET /api/products/{productId}` 回 HTTP `404`。
- 商品、規格、圖片與既有訂單快照沒有被刪除。

### F-2. 重新上架

將商品改回 active，或呼叫：

```http
POST /api/admin/products/{productId}/activate
```

預期公開詳情恢復 HTTP `200`。如果所有規格都是 inactive，上架應回 HTTP `409`。

人工測試完成後，建議再次下架測試商品，避免它留在公開商城。

## G. 資料庫核對

在 DBeaver 執行：

```sql
SELECT p.id, p.item_id, p.status, e.name, e.category_id, e.brand_id
FROM products p
JOIN equipment_items e ON e.id = p.item_id
WHERE p.id = '<productId>';

SELECT id, sku, specification, price, status
FROM product_variants
WHERE product_id = '<productId>'
ORDER BY id;

SELECT item_id, sort_order, url, alt_text
FROM equipment_images
WHERE item_id = '<itemId>'
ORDER BY sort_order;

SELECT count(*)
FROM inventory_stocks s
JOIN product_variants v ON v.id = s.variant_id
WHERE v.product_id = '<productId>';
```

最後一段預期為 `0`。G-2c 建立或更新商品時，不可繞過 G-3 建立或調整庫存。

## H. 自動檢查

```powershell
cd frontend
npm run test:admin-products
npm run build
```

預期：

- `Admin Products facade and mapping tests passed.`
- Vite 顯示 `built` 並以 exit code `0` 結束。
- 現有非 module `<script>` 訊息為既有 build warning，不等同 build 失敗。

## 2026-07-22 實測紀錄

### 環境

- PostgreSQL Docker：healthy，`5433 -> 5432`。
- `GET /api/health`：HTTP `200`。
- Admin dashboard：HTTP `200`。
- Browser：開發員工 `01` 登入成功。

### 已通過

| 項目 | 結果 |
|------|------|
| Mock 商品列表、上下架 badge、庫存欄與租借頁籤 | PASS |
| Mock 新增 Modal 的檔案圖片、庫存、租借與規格欄位 | PASS |
| Product lookups | PASS；6 個分類、13 個品牌 |
| 建立商品與後端產生商品／裝備／規格 ID | PASS |
| 建立 Request 最外層欄位白名單 | PASS |
| 建立時庫存摘要為 0 | PASS |
| DB `inventory_stocks` 筆數 | PASS；0 筆 |
| 更新兩張圖片排序 | PASS；`0,1` |
| 省略既有規格 | PASS；變為 inactive |
| 重複 SKU | PASS；HTTP `409`、`CONFLICT` |
| 負價格 | PASS；HTTP `400`、`VALIDATION_ERROR` |
| 下架後後台詳情 | PASS；inactive、HTTP `200` |
| 下架後公開詳情 | PASS；HTTP `404` |
| 重新上架後公開詳情 | PASS；HTTP `200` |
| `npm run test:admin-products` | PASS |
| Vite production build | PASS |

本次正式測試商品：

```text
productId: Pc64b9dbc461c44d4b943b4c4159adea
itemId: Ef4ed2266652d41acb604fc8edc1fe40
final status: inactive
```

測試過程誤建的 `P15e854e202ca420da532357c0b10beb` 已下架，未留在公開商城。

### 尚待人工完成

- 在 DevTools Console 啟用 Backend 模式後，確認租借與庫存編輯 UI 隱藏。
- 從 Products Modal 實際送出 Backend Request，使用 Network 面板核對 payload。
- 驗證 API 失敗後 Modal 輸入與列表 cache 未改變。

這三項不能只靠 API 或 facade 測試取代，因為它們涉及瀏覽器執行期模式、DOM 顯示與 Modal 狀態。完成後才能把整份「Frontend Backend UI」驗收標記為完整 PASS。

## 驗收完成標準

- Mock 模式功能沒有被 G-2c 破壞。
- Backend 模式只顯示可由 Products API 維護的欄位。
- 建立／更新 Request 沒有庫存、租借、評價或銷售衍生欄位。
- 商品／規格／圖片由後端成功 Response 決定；錯誤不會造成假成功 cache。
- 省略規格只停用、不硬刪。
- 庫存只讀，商品建立不產生 `inventory_stocks`。
- 下架後公開 404，重新上架後公開 200。
- facade test 與 production build 通過。

這套驗證的必要性在於：G-2c 同時跨越前端 Modal、API 契約與四組正規化資料。只看畫面可能漏掉胖物件誤送與假成功 cache；只測 API 又無法確認庫存／租借欄位是否真的從 Backend UI 隱藏，因此自動測試、Network、Browser 與 DB 核對缺一不可。
