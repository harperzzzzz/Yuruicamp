# Storefront 商城結帳流程

1. 使用者把商品加入購物車，資料保存在前端購物車狀態。
2. 進入 [checkout.html](/D:/githubdesk/Yuruicamp/frontend/storefront/pages/checkout.html)：
    購物車空白會導回商品頁。
    必須先登入。
    買家資訊、物流、付款三個面板目前預設全部展開。

3. 使用者填寫：
    - 買家姓名、電話、Email，進入checkout.html 網頁時一開始應該為空白，點擊#fillProfileBtn 後才會帶入會員資料(包括姓名、電話、Email)。
    - 運送方式: 宅配地址、門市取貨，門市取貨下方應該要有selet 選項給使用者選擇分店，分店資料從資料庫拉，資料庫如果沒資料則先創建欄位預留功能。
    - ECPay 信用卡或 COD。

4. 前端驗證表單後，組成精簡 Request：
    items[].variantId
    items[].quantity
    shipping.recipientName
    shipping.phone
    shipping.address
    paymentMethod
    idempotencyKey

5. 呼叫：
    POST /api/checkout/sessions

6. 後端負責：
    從 Bearer Token 判斷會員。
    重新查商品價格。
    悲觀鎖定庫存。
    建立 unpaid 訂單。
    建立 active 庫存保留帳。
    設定約 15 分鐘期限。
    回傳後端計算的 pricing。

7. 若回傳 checkoutStep=draft，使用者補齊資料後呼叫：
    PATCH /api/checkout/sessions/{orderId}

8. 前端把 Session 存在：
    sessionStorage.lastCheckoutSession 保存後端回傳的完整結帳資料
    sessionStorage.checkoutCompletedOrderId 防止使用者重新整理或連點時重複建立訂單
    sessionStorage.checkoutIdempotencyKey 保存本次建立訂單使用的唯一冪等鍵

9. 若為 ready_to_pay：
    畫面改用後端金額。
    啟動 15 分鐘倒數。
    留在 Checkout 頁。
    按鈕顯示「等待 ECPay 串接」或「等待貨到付款確認」。
    目前不會導向商城成功頁，也不會真的付款。

10. 若取消：
POST /api/checkout/sessions/{orderId}/cancel