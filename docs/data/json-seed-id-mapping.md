# JSON 與 Seed 固定 ID 對照表

| 欄位 | 內容 |
|---|---|
| 文件狀態 | Active（reference、會員周邊、庫存、交易保留與可追溯評論已搬移） |
| 更新日期 | 2026-07-22 |
| 權威順序 | PostgreSQL Schema／Seed → 本文件 → 前端 Mock JSON |
| 適用範圍 | 商品、商城規格、品牌、營區、營位、門市、會員地址／偏好／標籤、租借 SKU、租借規格、優惠券與交易固定 ID |
| 不包含 | 無法追溯交易的 37 筆評論、庫存異動、最低庫存與 coupon claim |

> **簡單說**：本文件只回答「同一筆資料在 JSON 與 Seed 應使用哪個固定 ID」。欄位、ENUM、外鍵與金額仍以 [`latest_schema.sql`](../latest_schema.sql) 與 API 契約為準；Seed 載入與交易規則仍以 [`docs/seed/README.md`](../seed/README.md) 為準。

## 1. 固定 ID 規則

| 領域 | Canonical 格式 | 範例 | 說明 |
|---|---|---|---|
| 商品 | `P` + 三位數 | `P001` | 對應 `products.id` |
| 共用商品內容 | `E` + 三位數 | `E001` | 對應 `equipment_items.id` |
| 商城規格 | 既有 Seed variant ID | `V001`、`V003-02` | 對應 `product_variants.id`；禁止再建立 `v-P...` |
| 品牌 | 小寫 kebab-case | `snow-peak` | 對應 `brands.id` |
| 營區 | `C` + 三位數 | `C002` | `C001` 保留為租借主倉語意，不是可預約營區 |
| 營位 | `Z` + 三位數 | `Z001` | 對應 `campground_zones.id` |
| 租借 SKU | `R` + 三位數 | `R001` | 對應 `rental_skus.id` |
| 租借規格 | `RSV-` + 租借 SKU + 兩位序號 | `RSV-R001-01` | 對應 `rental_sku_variants.id`；與商城規格分開 |

既有 `C002-Z-A`、`C002-Z-HIDDEN`、`RS-DEV-001`、`RSV-DEV-001` 與 `RL-DEV-C002-001` 是 E 線 Swagger 的獨立開發驗收資料，不是前端完整展示資料的別名。`C002-Z-A` 與 `C002-Z-HIDDEN` 已保留但停用；原本占用正式 `C009` 的停用營區 fixture 已改為 `DEV-CAMP-INACTIVE`。後續完整 Seed 搬移不得把交易資料默默指向這些開發 ID。

## 2. 商品與商城規格

商品固定 ID 已完成第一階段對齊：

- Seed 保留 `P001`～`P030` 與 `E001`～`E030`。
- `frontend/data/catalog/products.json` 只呈現 28 筆 active 商品；`P010`、`P030` 是 Seed 的 inactive 商品。
- 商城規格以 [`product-catalog-mapping.md`](./product-catalog-mapping.md) 的 `V...` ID、SKU 與價格為準。
- `frontend/data/catalog/products.json` 已使用 canonical variant ID。
- `frontend/data/admin/rental-skus.json`、`frontend/data/catalog/camp-equipment.json` 與預約租借快照已使用 canonical `RSV-Rxxx-xx`；商城訂單也已轉成 canonical 商品 variant／SKU。評論仍含商品規格用的 `v-P...`，後續轉換必須經本文件對照，不可直接寫入 FK。

`products.json` 沒有獨立商品 `P010`、`P030` 是預期結果，不得為了補連號在前端建立假 active 商品。

下列舊交易參照需特別處理：

| Legacy variant | Canonical product variant | 狀態 | 說明 |
|---|---|---|---|
| `v-P001-2` | `V003` | Seed 已有 | P001 太空灰 active variant，固定 SKU 為 `TENT-GRAY` |
| `v-P010-0` | `V010-01` | Seed 已有 | P010 為 inactive 商品，僅供歷史快照／FK |
| `v-P030-0` | `V030-01` | Seed 已有 | P030 為 inactive 商品，僅供歷史快照／FK |

`V003` 已同步建立於 `030-catalog.sql`、商品 manifest 與前端商品契約；商城訂單使用同一 ID 與 `TENT-GRAY` SKU。

## 3. 品牌 ID

| Frontend legacy ID | 品牌名稱 | Canonical `brands.id` | 目前 Seed | 後續動作 |
|---|---|---|---|---|
| `brand-001` | Snow Peak | `snow-peak` | 已加入 | 前端已改用 canonical ID |
| `brand-002` | Osprey | `osprey` | 已加入 | 前端已改用 canonical ID |
| `brand-003` | MSR | `msr` | 已加入 | 前端已改用 canonical ID |
| `brand-004` | Coleman | `coleman` | 已加入 | 前端已改用 canonical ID |
| `brand-005` | Patagonia | `patagonia` | 已加入 | 前端已改用 canonical ID |
| `brand-006` | Deuter | `deuter` | 已加入 | 前端已改用 canonical ID |
| `brand-007` | Sawyer | `sawyer` | 已加入 | 前端已改用 canonical ID |
| `brand-008` | Black Diamond | `black-diamond` | 已加入 | 前端已改用 canonical ID |
| `brand-009` | Helinox | `helinox` | 已加入 | 前端已改用 canonical ID |
| `brand-010` | Columbia | `columbia` | 已加入 | 前端已改用 canonical ID |
| `brand-011` | Ogawa | `ogawa` | 已加入 | 前端已改用 canonical ID |
| `brand-012` | Therm-a-Rest | `therm-a-rest` | 已加入 | 前端已改用 canonical ID |
| 無獨立品牌列 | Yuruicamp | `yuruicamp` | 已保留 | 站內自有品牌，不列入前端 12 品牌 |

品牌名稱是顯示文字，不可當 FK。商品寫入 Seed 時一律使用上表 canonical `brands.id`。

## 4. 營區 ID

| Frontend ID | Canonical ID | 前端名稱 | 目前 Seed | 身分決策 |
|---|---|---|---|---|
| `C002` | `C002` | 雲海仙境露營區 | 已加入 | Seed 與前端一致 |
| `C003` | `C003` | 溪谷秘境野營地 | 已加入 | Seed 與前端一致 |
| `C004` | `C004` | 太平山森林豪華露營 | 已加入 | Seed 與前端一致 |
| `C005` | `C005` | 南台灣星空草原營地 | 已加入 | Seed 與前端一致 |
| `C006` | `C006` | 花蓮海岸風露營區 | 已加入 | Seed 與前端一致 |
| `C007` | `C007` | 阿里山雲霧繚繞營地 | 已加入 | Seed 與前端一致 |
| `C008` | `C008` | 宜蘭礁溪湯泉露營 | 已加入 | Seed 與前端一致 |
| `C009` | `C009` | 台中武陵溪流野營 | 已加入 | 停用 fixture 已移至 `DEV-CAMP-INACTIVE` |

`C001` 只代表租借主倉語意。它不應新增到 `campgrounds`，應轉成 `inventory_locations` 的 rental 主倉。

## 5. Zone ID

| Campground | Frontend Zone | Canonical Zone | 類型 | 目前 Seed |
|---|---|---|---|---|
| `C002` | `Z001` | `Z001` | 草皮區 | 已加入 |
| `C002` | `Z002` | `Z002` | 雨棚區 | 已加入 |
| `C003` | `Z003` | `Z003` | 碎石區 | 已加入 |
| `C003` | `Z004` | `Z004` | 棧板區 | 已加入 |
| `C004` | `Z005` | `Z005` | 免搭帳／豪華露營 | 已加入 |
| `C005` | `Z006` | `Z006` | 草皮區 | 已加入 |
| `C006` | `Z007` | `Z007` | 草皮區 | 已加入 |
| `C006` | `Z008` | `Z008` | 雨棚區 | 已加入 |
| `C007` | `Z009` | `Z009` | 棧板區 | 已加入 |
| `C008` | `Z010` | `Z010` | 草皮區 | 已加入 |
| `C008` | `Z011` | `Z011` | 免搭帳／豪華露營 | 已加入 |
| `C009` | `Z012` | `Z012` | 碎石區 | 已加入 |
| `C009` | `Z013` | `Z013` | 棧板區 | 已加入 |

前端 90 筆預約已引用 `Z001`～`Z013`，`010-reference.sql` 現已建立這 13 個 canonical zone；不得把它們依序猜成 `C002-Z-A`。

### 5.1 標籤與門市 ID

| 領域 | 固定 ID／code | 顯示值 |
|---|---|---|
| 環境標籤 | `high-altitude`、`cloud-sea`、`forest`、`low-altitude`、`stream` | 高海拔、有雲海、森林系、低海拔、有溪流 |
| 設施標籤 | `private-bathroom`、`equipment-rental`、`rain-shelter`、`playground`、`pet-friendly`、`cabin`、`private-area` | 獨立衛浴、裝備租借、有雨棚、兒童遊樂設施、寵物友善、小木屋、可包區 |
| 門市 | `branch-001`～`branch-003` | 台北旗艦店、台中中港店、高雄左營店 |

標籤資料庫主鍵固定為環境 `1`～`5`、設施 `1`～`7`；跨層傳輸或篩選優先使用穩定 `code`，顯示使用 `label`。門市 features 已寫入 `branch_features`，但公開 Branch API 是否回傳仍以 API 契約為準。

## 6. 租借 SKU

| Canonical Rental SKU | Product | 名稱 | Variant 數 |
|---|---|---|---:|
| `R001` | `P001` | Coleman 六人帳篷 | 3 |
| `R002` | `P002` | MSR 超輕量帳篷 | 1 |
| `R003` | `P011` | Snow Peak 客廳帳 | 1 |
| `R004` | `P012` | 四季保暖睡袋 | 2 |
| `R005` | `P004` | 羽絨睡袋 | 3 |
| `R006` | `P005` | Coleman 氣化爐 | 1 |
| `R007` | `P006` | Snow Peak 鈦合金杯組 | 1 |
| `R008` | `P009` | 折疊桌椅組 | 1 |
| `R009` | `P013` | 折疊蛋捲桌 | 1 |
| `R010` | `P014` | 高背月亮椅 | 1 |
| `R011` | `P007` | LED 露營燈 | 2 |
| `R012` | `P015` | 充電式頭燈 | 1 |
| `R013` | `P008` | 防水登山背包 | 2 |
| `R014` | `P016` | 65L 重裝背包 | 1 |
| `R015` | `P017` | 露營拖車 | 1 |
| `R016` | `P018` | 大型天幕 | 1 |
| `R017` | `P019` | 營柱與營繩組 | 1 |
| `R018` | `P003` | 充氣式睡墊 | 3 |
| `R019` | `P020` | 行動電源站 | 1 |
| `R020` | `P021` | 保冷冰桶 45L | 1 |
| `R021` | `P022` | 雙層防風外套 | 1 |
| `R022` | `P023` | 快煮鍋 1.5L | 1 |
| `R023` | `P024` | 碳纖維登山杖 | 1 |
| `R024` | `P025` | 防水戶外手錶 | 1 |
| `R025` | `P026` | 輕量吊床 | 1 |
| `R026` | `P027` | 戶外淋浴袋 | 1 |
| `R027` | `P028` | 折疊式焚火台 | 1 |
| `R028` | `P029` | 防蚊帳篷內帳 | 1 |

`rental_skus.item_id` 連到共用 `equipment_items`，不是直接連 `products.id`。`030-catalog.sql` 已依本表的 Product 對應至 [`product-catalog-mapping.md`](./product-catalog-mapping.md) 的 `E...`。

## 7. 租借規格與舊 `v-P...` 對照

| Rental SKU | Product | Legacy Mock variant | Canonical rental variant | Product variant | Spec |
|---|---|---|---|---|---|
| R001 | P001 | `v-P001-0` | `RSV-R001-01` | `V001` | 深橄欖綠 |
| R001 | P001 | `v-P001-1` | `RSV-R001-02` | `V002` | 沙漠棕 |
| R001 | P001 | `v-P001-2` | `RSV-R001-03` | `V003` | 太空灰 |
| R002 | P002 | `v-P002-0` | `RSV-R002-01` | `V002-01` | 沙漠卡其 |
| R018 | P003 | `v-P003-0` | `RSV-R018-01` | `V003-01` | S |
| R018 | P003 | `v-P003-1` | `RSV-R018-02` | `V003-02` | M |
| R018 | P003 | `v-P003-2` | `RSV-R018-03` | `V003-03` | L |
| R005 | P004 | `v-P004-0` | `RSV-R005-01` | `V004-01` | -10°C |
| R005 | P004 | `v-P004-1` | `RSV-R005-02` | `V004-02` | -5°C |
| R005 | P004 | `v-P004-2` | `RSV-R005-03` | `V004-03` | 0°C |
| R006 | P005 | `v-P005-0` | `RSV-R006-01` | `V005-01` | 標準版 |
| R007 | P006 | `v-P006-0` | `RSV-R007-01` | `V006-01` | 鈦金屬原色 |
| R011 | P007 | `v-P007-0` | `RSV-R011-01` | `V007-01` | 暖白光 |
| R011 | P007 | `v-P007-1` | `RSV-R011-02` | `V007-02` | 冷白光 |
| R013 | P008 | `v-P008-0` | `RSV-R013-01` | `V008-01` | 森林綠 / 35L |
| R013 | P008 | `v-P008-1` | `RSV-R013-02` | `V008-02` | 森林綠 / 45L |
| R008 | P009 | `v-P009-0` | `RSV-R008-01` | `V009-01` | 鋁合金輕量版 |
| R003 | P011 | `v-P011-0` | `RSV-R003-01` | `V011-01` | 象牙白 |
| R004 | P012 | `v-P012-0` | `RSV-R004-01` | `V012-01` | 深藍 / M |
| R004 | P012 | `v-P012-1` | `RSV-R004-02` | `V012-02` | 深藍 / L |
| R009 | P013 | `v-P013-0` | `RSV-R009-01` | `V013-01` | 胡桃木紋 |
| R010 | P014 | `v-P014-0` | `RSV-R010-01` | `V014-01` | 軍綠 |
| R012 | P015 | `v-P015-0` | `RSV-R012-01` | `V015-01` | USB-C |
| R014 | P016 | `v-P016-0` | `RSV-R014-01` | `V016-01` | 岩石灰 |
| R015 | P017 | `v-P017-0` | `RSV-R015-01` | `V017-01` | 折疊式 |
| R016 | P018 | `v-P018-0` | `RSV-R016-01` | `V018-01` | 4x4m |
| R017 | P019 | `v-P019-0` | `RSV-R017-01` | `V019-01` | 標準套組 |
| R019 | P020 | `v-P020-0` | `RSV-R019-01` | `V020-01` | 500Wh |
| R020 | P021 | `v-P021-0` | `RSV-R020-01` | `V021-01` | 深藍 |
| R021 | P022 | `v-P022-0` | `RSV-R021-01` | `V022-01` | L號 |
| R022 | P023 | `v-P023-0` | `RSV-R022-01` | `V023-01` | 不鏽鋼 |
| R023 | P024 | `v-P024-0` | `RSV-R023-01` | `V024-01` | 一對 |
| R024 | P025 | `v-P025-0` | `RSV-R024-01` | `V025-01` | GPS版 |
| R025 | P026 | `v-P026-0` | `RSV-R025-01` | `V026-01` | 雙人 |
| R026 | P027 | `v-P027-0` | `RSV-R026-01` | `V027-01` | 20L |
| R027 | P028 | `v-P028-0` | `RSV-R027-01` | `V028-01` | 不鏽鋼 |
| R028 | P029 | `v-P029-0` | `RSV-R028-01` | `V029-01` | 通用型 |

商城規格與租借規格可以描述相同顏色／尺寸，但它們分屬 `product_variants` 與 `rental_sku_variants`，不可共用主鍵。商城 variant `V003` 已建立，既有訂單的 `v-P001-2` 已轉成 `V003`；租借快照仍使用獨立的 `RSV-R001-03`。

租借庫位固定使用 `RENTAL-C001`～`RENTAL-C009`；其中 `RENTAL-C001` 是主倉，C002～C009 各自透過 `campground_rental_locations` 對應同號營區。現有 16 筆 `camp-equipment.json` listing 保留 `E010`～`E025` 作為 `rental_listings.id`，避免破壞既有預約快照；這些 ID 與 `equipment_items.id` 位於不同資料表，不代表同一筆主檔。

前端 listing 的 `pricing.discount` 原本是固定折抵金額，資料庫 `rental_listings.discount` 則是 0.00～0.30 比率。兩者無法無損換算，因此本輪 Seed 與同步後 Mock 固定為 `0`；未另行定義折扣率前不得猜測轉換。

### 7.1 優惠券固定 ID

| `coupons.id` | Code | Category | 狀態 |
|---:|---|---|---|
| 1 | `YURUIKAMP20` | promotion | active |
| 2 | `CAMPFUN50` | promotion | active（目前已過有效期） |
| 3 | `SUMMER100` | promotion | active |
| 4 | `NEWCAMP300` | promotion | active（尚未生效） |
| 5 | `OLDCAMP10` | promotion | disabled |
| 6 | `YURUIHBD` | birthday | active |
| 7 | `YRUIFIRST` | firstPurchase | active |

優惠券時間一律將前端本地時間解讀為 `Asia/Taipei`（`+08:00`）。目前已有 50 位展示會員，但沒有任何領券案例，所以尚未建立 `coupon_claims`，`claimed_quantity`／Mock `used` 固定為 `0`；後續不得只改主檔計數而不建立對應 claim。

建立 claim 的最低證據是 `customerId + couponId/code + claimedAt + status`；若狀態為 `consumed`，還必須有可對應的 `orderId`、折扣金額與 `order_coupons` 快照。只有資格、券有效期、訂單金額或推測使用時間都不構成可追溯來源。

### 7.2 會員周邊固定 ID

- `customers.id` 固定為 `U001`～`U050`。
- `preference_options.id` 固定為 1～18：1～8 是 `style`，9～18 是 `equipment`。
- `customer_shipping_addresses.id` 固定為 1～50，分別對應同號 U001～U050；每位展示會員一筆預設地址。
- `customer_tags.id` 固定為 1「高消費」、2「高退貨率」、3「新會員」。
- 偏好與標籤關聯採複合鍵，不另建前端 surrogate ID。
- 地址 JSON 的 `email` 來自同會員 `customers.email`；資料庫 `customer_shipping_addresses` 沒有 email 欄位。

### 7.3 交易固定 ID 與時間規則

- `customers.id` 沿用 `U001`～`U050`。
- `orders.id` 與 `bookings.id` 在資料庫保存為前端數字 ID 的字串，例如前端 `1` 對應資料庫 `'1'`；畫面格式 `ORD-0001` 仍只是 display ID。
- 訂單商品快照一律使用 `product_variants.id` 與該 variant 的 canonical `sku`，不再保存 `v-P...`。
- 預訂以 `[checkIn, checkOut)` 計夜；週五、週六為假日夜，其餘為平日夜。`weekdayCount + holidayCount` 必須等於日期差，金額以 zone／listing 主檔價格重算。
- `060`、`070` 的明細與歷程使用 `600000`～`729999` 固定 identity 範圍，避免與一般開發資料混淆。

## 8. 後續轉換順序

1. ✅ 已擴充 `010-reference.sql`：12 公開品牌、C002～C009、Z001～Z013、標籤與 3 門市。
2. ✅ 已擴充 `030-catalog.sql`：R001～R028 與 37 個 RSV-Rxxx-xx；保留既有 Swagger dev fixture。
3. ✅ 已擴充 `040-inventory.sql`：9 個租借庫位、8 組營區對照、16 筆既有 listing 與 333 筆規格庫存；最低庫存尚未搬移。
4. ✅ 品牌、租借 SKU、衍生 listing 與預約租借快照已同步 canonical ID。
5. ✅ 已建立 `050-coupons.sql`：固定優惠券 ID 1～7，尚未建立會員 claim。
6. ✅ 已在 `020-identity.sql` 建立 U001～U050，以及地址、偏好與會員標籤；另建立 `060-orders.sql`（222 筆 JSON 對照訂單，加上 Firebase 測試會員「粉紅雞」3 筆固定隨機訂單，共 225 筆）與 `070-bookings.sql`（90 筆），交易商品規格已改為 canonical ID。
7. 後續只有出現可追溯的領券／使用案例時才建立 `coupon_claims` 與必要的 `order_coupons`，並由 Trigger 維護已領數。
8. ✅ `reviews.json` 的 38 筆 `v-P...` variant／SKU 已全數轉為 canonical ID；只有明確 `orderId=208` 的 `REV031` 建立 Seed verified-purchase 關聯。
9. ✅ 已建立 442 筆訂單庫存保留與 40 筆租借庫存保留；新增的 7 筆商城保留皆為已履約狀態，不影響商城 active 商品可用量 399，租借 active 區間無重疊超賣。
10. `movement.json` 暫不搬移：141 筆明細都沒有 variantId，24 筆無法由 productId 唯一推導，26 張表頭混合異動語意，員工 01～03 也缺 `admin_users` 對照。

## 9. 本輪完成標準

- 商品、商城規格、品牌、營區、zone、租借 SKU 與租借規格都有唯一 canonical ID。
- 開發驗收 fixture 與完整展示資料的身分已分開。
- 已標示既有 Seed 缺口與 ID 衝突，不把資料值差異誤當成 ID 對照完成。
- Reference、會員與周邊資料、商品／租借主檔、實體庫存、訂單／預訂、庫存保留與可追溯評論 Seed 已完成；Schema 未修改，領券 claim、最低庫存、無交易證據評論與庫存異動維持不搬移。
