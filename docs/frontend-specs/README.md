# Yuruicamp 前端規格文件

**狀態：** 草稿
**產生日期：** 2026-06-30
**設計參考：** 無－以現有程式碼庫為準

---

## 使用方式

1. 先閱讀 `docs/ai-style-sheet.md` 與 `docs/ai-style-tokens.css`。
2. 開啟 `docs/frontend-specs/pages/` 中對應頁面的規格文件。
3. 保留既有的資料契約、localStorage key、共用 header/footer 載入方式、訂房版面載入方式，以及後台 partial 載入方式。
4. 訂房系統頁面腳本：見 [Booking 共用腳本](booking-shared-scripts.md)（`config.js`／`AppConfig` 必載，避免漏頁）。
5. 將這些檔案視為 AI 實作指示，而不是執行時期的程式碼。

## API 接線規格

- [**Firebase 合併進 main 後注意事項（協作者必讀）**](firebase-merge-into-main-notes.md)
- [**Firebase 主線完成後：後續 Checklist（BK／CK 業務債）**](../../plans/post-firebase-roadmap-checklist.md)
- [前端認證與 REST 共用層](api/auth-rest-client.md)
- [認證與 REST 手動驗證](test/auth-rest-client-manual.md)
- [Admin 登入頁（Firebase Google）](pages/admin-login-page.md)
- [Checkout API facade](api/checkout-facade.md)
- [Checkout facade 手動驗證](test/checkout-facade-manual.md)
- [Checkout Mock 契約手動驗證](test/checkout-mock-contract-manual.md)
- [Checkout Request 手動驗證](test/checkout-request-manual.md)
- [Checkout I-5 Backend 狀態手動驗證](test/checkout-backend-state-manual.md)
- [Checkout I-6 Session UI 手動驗證](test/checkout-session-ui-manual.md)
- [Booking API facade](api/booking-facade.md)
- [Booking Backend 接線手動驗證](test/booking-backend-integration-manual.md)

## 假設條件

- 主要用途：協助 AI 工具一致地實作或重構 Yuruicamp 頁面。
- 所需狀態版本：預設、載入中、空狀態、錯誤、手機版、桌面版。
- Figma 參考：目前沒有。
- 上層技術背景：既有的原生 HTML／CSS／JavaScript 專案；為了讓 AI 更容易理解，文件中會使用 React／TypeScript 風格的介面描述。
- 無障礙目標：符合 WCAG AA 基準。

## 頁面規格索引

### 主網站

- [IndexRedirectPage](pages/index-redirect-page.md)－`index.html`
- [HomePage](pages/home-page.md)－`pages/home.html`
- [ProductsPage](pages/products-page.md)－`pages/products.html`
- [ProductDetailPage](pages/product-detail-page.md)－`pages/product-detail.html`
- [CheckoutPage](pages/checkout-page.md)－`pages/checkout.html`
- [CheckoutSuccessPage](pages/checkout-success-page.md)－`pages/checkout-success.html`
- [MemberCenterPage](pages/member-center-page.md)－`pages/member-center.html`
- [BlogPage](pages/blog-page.md)－`pages/blog.html`
- [BlogDetailPage](pages/blog-detail-page.md)－`pages/blog-detail.html`
- [BranchesPage](pages/branches-page.md)－`pages/branches.html`
- [FaqPage](pages/faq-page.md)－`pages/faq.html`

### 訂房系統

- [Booking 共用腳本](booking-shared-scripts.md)－`booking/partials/booking-core-scripts.partial` + `booking/js/booking-core-scripts.js`
- [CampSearchPage](pages/camp-search-page.md)－`booking/pages/camp-search.html`
- [CampDetailPage](pages/camp-detail-page.md)－`booking/pages/camp-detail.html`
- [CampRentalPage](pages/camp-rental-page.md)－`booking/pages/camp-rental.html`
- [BookingCartPage](pages/booking-cart-page.md)－`booking/pages/booking-cart.html`
- [BookingCheckoutPage](pages/booking-checkout-page.md)－`booking/pages/booking-checkout.html`
- [BookingFaqPage](pages/booking-faq-page.md)－`booking/pages/booking-faq.html`
- [RentalGuidePage](pages/rental-guide-page.md)－`booking/pages/rental-guide.html`
- [BookingMemberCenterPage](pages/booking-member-center-page.md)－`booking/pages/member-center.html`

### 後台管理系統

- [AdminLoginPage](pages/admin-login-page.md)－`admin/login.html`
- [AdminDashboardPage](pages/admin-dashboard-page.md)－`admin/dashboard.html`
- [AdminAnalyticsPage](pages/admin-analytics-page.md)－`admin/partials/analytics.html`
- [AdminOrdersPage](pages/admin-orders-page.md)－`admin/partials/orders.html`
- [AdminBookingsPage](pages/admin-bookings-page.md)－`admin/partials/bookings.html`
- [AdminProductsPage](pages/admin-products-page.md)－`admin/partials/products.html`
- [AdminMovementPage](pages/admin-movement-page.md)－`admin/partials/movement.html`
- [AdminCustomersPage](pages/admin-customers-page.md)－`admin/partials/customers.html`
- [AdminDiscountsPage](pages/admin-discounts-page.md)－`admin/partials/discounts.html`
- [AdminReviewsPage](pages/admin-reviews-page.md)－`admin/partials/reviews.html`
- [AdminPermissionsPage](pages/admin-permissions-page.md)－`admin/partials/permissions.html`
