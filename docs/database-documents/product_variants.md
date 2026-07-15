# products
    products 對應一個 equipment_items 裝備項目。
* product_variants
    product_variants 保存商品的定價、選購、下單及管理庫存的規格



## 關聯與資料流
equipment_items
└─ 1:0..1 products
      └─ 1:N product_variants
### 關聯
* equipment_items：共用裝備主檔
* products：商城商品的 SPU，狀態。
* product_variants：商品的 SKU，規格、價格。
* 一筆 products 可以有多筆 product_variants
### 資料流程
* 建立商城商品時：
- 先在 equipment_items 建立裝備共用資料，例如商品名稱、分類、品牌與說明。
- 在 products 建立販售身分，並以 item_id 指向該裝備。
- 在 product_variants 建立一筆或多筆規格。
- 每個規格有自己的 SKU、顏色、尺寸、規格名稱、價格與狀態。



## 欄位說明
### products
* id            商城商品 SPU 識別碼 (由程式或匯入資料指定)
* status        商品販售狀態，預設 active，('active', 'inactive')
                *idx_products_status INDEX (status)*
                
* created_at    建立時間，預設 now()
* updated_at    最後更新時間，預設 now()，自動更新時間。
* item_id       對應的裝備共用主檔 ID，UNIQUE


### product_variants
* id             商品規格識別碼

* product_id     所屬商品 SPU
                 ON UPDATE CASCADE
                 ON DELETE RESTRICT
                 *idx_product_variants_product_status (product_id, status)*

* sku            全系統唯一的庫存單位編號，UNIQUE
  color          顏色，null
  size           尺寸，null
* price          此規格的售價，必須大於或等於 0
* specification  規格顯示文字
* status         規格狀態，預設 active，('active', 'inactive')
* created_at     建立時間，預設 now()

* updated_at     最後更新時間，預設 now()
                 由 trg_product_variants_set_updated_at 自動更新

*UNIQUE (product_id, id)*
        防止訂單同時寫入商品 P001，卻搭配屬於 P002 的規格。
*UNIQUE (product_id, color, size, specification)*
        避免相同規格


## 運作模式
- 商品頁可以先讀 products，再列出其所有有效規格。
- 使用者選規格後，購物車與訂單應記錄 product_id + variant_id。
- 規格停用時，可保留商品上架，但不能再購買該規格。
- 商品停用時，整個商品及其所有規格都不應在商城販售。



## 程式碼追蹤
* 前台商品列表載入
    `pages/products.html`
            ↓
    載入 `js/data-paths.js`
    [pages/products.html 第 130 行]
            ↓
    載入 `js/api-mock.js`
    [pages/products.html 第 133 行]
            ↓
    載入 `js/pages/product-list.js`
    [pages/products.html 第 140 行]
            ↓
    initProductListPage()
    [js/pages/product-list.js 第 793 行]
            ↓
    window.API.products.getAll()
    [js/pages/product-list.js 第 801 行]
            ↓
    _loadProductsRaw()
    [js/api-mock.js 第 155 行]
            ↓
    DataPaths.products
    [js/data-paths.js 第 12 行]
            ↓
    `data/catalog/products.json`
            ↓
    過濾 status = active
    [js/api-mock.js 第 353 行]
            ↓
    加入評論數、評分與銷售數
    [js/api-mock.js 第 348 行]
            ↓
    分類、品牌、價格、標籤及關鍵字篩選
    [js/pages/product-list.js 第 298 行]
            ↓
    商品排序並建立商品卡片
    [js/pages/product-list.js 第 200 行]

* 使用者從商品列表選規格並加入購物車
    商品卡片「加入購物車」
            ↓
    依使用者選擇的 color、size 尋找規格
    findProductVariant(product, color, size)
    [js/pages/product-list.js 第 584 行]
            ↓
    建立購物車明細
    buildCartLineFromProduct(product, variant)
    [js/pages/product-list.js 第 587 行]
            ↓
    購物車保存 productId、variantId、sku 等資料
            ↓
    結帳建立訂單快照
    variantId: item.variantId
    sku: item.sku || item.variantId
    [js/pages/checkout.js 第 580 行]

    * 目前實際執行狀況
        - 不讀資料庫的 products。
        - 不讀資料庫的 product_variants。
        - 不讀資料庫的 equipment_items。
        - 不寫入任何上述資料表。
        - 直接讀取 `[data/catalog/products.json (line 1)]`
        - 前端 `products.json` 把商品、規格及庫存資料包在同一筆物件內。
        - 前端商品層級直接有 name、category、brand、price、totalStock 及 branch。
        - 前端 variants[] 有 color、size、label 與分店庫存，但目前沒有完整對應資料庫要求的 sku、price、specification、status。
        - 因此前端現在的資料結構，並不是 schema_copy.sql 中三張表正規化後的直接輸出。



## 可能的問題
* 高風險：資料庫與前端存在兩套商品模型
    products.json 和資料庫

* 中風險：商品與規格各自有狀態，前端只檢查商品狀態
    資料庫可販售條件至少包含：
        products.status = active
        product_variants.status = active

* 中風險：status 的意義需要明確定義
    三層可能影響販售的狀態：
        equipment_items.active
        products.status
        product_variants.status
