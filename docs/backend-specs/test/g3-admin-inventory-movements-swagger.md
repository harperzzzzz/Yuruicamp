# G-3 Admin Inventory Movements Swagger 驗證

### Swagger 驗證流程

測試前確認：

- PostgreSQL 與後端已啟動。
- `FIREBASE_ENABLED=false`。
- 已載入最新開發 Seed。
- 開啟 `http://localhost:8080/swagger-ui.html`。

#### 1. 建立管理員 Session 並授權

執行：

```http
POST /api/admin/auth/firebase/session
```

Request Body：

```json
{
  "idToken": "dev:booking-seed-admin:booking-seed@example.test:google:Booking Seed Admin"
}
```

預期 HTTP 200。點 Swagger 右上角 `Authorize`，輸入：

```text
dev:booking-seed-admin:booking-seed@example.test:google:Booking Seed Admin
```

不需要自行加上 `Bearer`。

#### 2. 取得正式庫位與規格 ID

```http
GET /api/admin/inventory-movements/lookups
```

預期 HTTP 200。從 `locations[]` 選一個 `inventoryDomain=store` 的 active 庫位，從 `variants[]` 選一個 `inventoryDomain=store` 的規格。以下以 `<storeLocationId>` 與 `<storeVariantId>` 表示，請勿直接用顯示名稱代替 ID。

#### 3. 建立商城入庫 draft

```http
POST /api/admin/inventory-movements
```

```json
{
  "inventoryDomain": "store",
  "movementType": "receipt",
  "sourceLocationId": null,
  "destinationLocationId": "<storeLocationId>",
  "reason": "G3 Swagger 商城入庫",
  "occurredAt": null
}
```

預期 HTTP 200、`status=draft`，請記錄 `data.id` 與 `data.movementNo`。此時 `items=[]`，庫存數量尚未改變。

#### 4. 新增異動明細

```http
POST /api/admin/inventory-movements/{movementId}/items
```

```json
{
  "variantId": "<storeVariantId>",
  "quantity": 5
}
```

預期 HTTP 200，明細包含後端取得的 SKU 與品名快照。同一 movement 再加入相同 variant 預期 HTTP 409。

#### 5. 確認 draft 不會先改庫存

開啟 DBeaver，執行：

```sql
SELECT on_hand_quantity
FROM inventory_stocks
WHERE location_id = '<storeLocationId>'
  AND variant_id = '<storeVariantId>';
```

記錄過帳前數量；若沒有資料列，視為 0。建立 draft 與新增明細都不應改變它。

#### 6. 過帳與冪等重送

```http
POST /api/admin/inventory-movements/{movementId}/post
```

預期 HTTP 200、`status=posted`、`postedAt` 非空，DBeaver 數量增加 5。立刻再送一次相同 POST，仍回 HTTP 200，但庫存不能再增加。

posted 後再執行：

```http
POST /api/admin/inventory-movements/{movementId}/items
POST /api/admin/inventory-movements/{movementId}/cancel
```

兩者都預期 HTTP 409。

#### 7. 驗證負庫存與 active 保留下限

建立 `movementType=write_off` 的 draft，`sourceLocationId=<storeLocationId>`、目的地為 null，再加入大於現有可扣數量的明細並過帳。

預期 HTTP 409、錯誤碼 `CONFLICT`，庫存與 movement 狀態維持不變。即使 on hand 足夠，只要扣除後低於 active `product_stock_reservations`，也必須回 409。

#### 8. 作廢 draft

```http
POST /api/admin/inventory-movements/{draftMovementId}/cancel
```

預期 HTTP 200、`status=cancelled`。重送 cancel 冪等回 200；再呼叫 post 預期 HTTP 409。

#### 9. 同領域調撥

選兩個不同的 store 庫位，建立：

```json
{
  "inventoryDomain": "store",
  "movementType": "transfer",
  "sourceLocationId": "<sourceLocationId>",
  "destinationLocationId": "<destinationLocationId>",
  "reason": "G3 Swagger 門市調撥"
}
```

新增明細並過帳後，來源減少、目的增加相同數量，總 on hand 不變。來源與目的相同、領域不一致都預期 HTTP 400。

#### 10. 租借庫存入庫

從 lookup 選 `inventoryDomain=rental` 的庫位與規格，以 receipt 建立、加明細並過帳。DBeaver 核對：

```sql
SELECT on_hand_quantity
FROM rental_sku_variant_stocks
WHERE location_id = '<rentalLocationId>'
  AND rental_sku_variant_id = '<rentalVariantId>';
```

商城表 `inventory_stocks` 不應出現 rental variant。`conversion_out`／`conversion_in` 不在 G-3 API 允許值內，Swagger 送入應回 400。

#### 11. 查詢與 RBAC

```http
GET /api/admin/inventory-movements?page=0&size=20&status=posted&sort=occurredAt,desc
GET /api/admin/inventory-movements/{movementId}
```

預期分頁與快照明細正確。只有 `movement.view` 的管理員可讀但不能建立、加明細、過帳或作廢；沒有 view 則不可讀。

#### Swagger 驗收完成標準

- draft 與新增明細不改庫存。
- posted 單一交易更新庫存並記錄操作者；重送不重複加減。
- 負庫存與低於 active 保留量都回 409 且 rollback。
- posted 不可改明細或作廢；cancelled 不可過帳。
- 商城與租借只寫各自的庫存表；transfer 不跨 domain。
- `movement.view`／`movement.edit` RBAC 正確。

這些驗證必要，因為只看 HTTP 200 無法證明庫存只更新一次、交易失敗有 rollback，或商城／租借沒有寫錯資料表；必須搭配重送、負庫存與 DBeaver 數量核對。
