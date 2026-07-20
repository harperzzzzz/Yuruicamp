# Booking CSS Semantic Selector Map

這份文件記錄 booking CSS 語意化時的主要 selector 對照。原則是：外觀樣式使用 booking 語意 class，既有 ID 只保留給 JavaScript hook、anchor、表單 label 或 shared partial runtime contract。

| 舊 selector | 新 selector | JS 使用 | 可直接改 | 說明 |
| --- | --- | --- | --- | --- |
| `.stepProgress` | `.bookingStepProgress` | 否 | 是 | Booking 流程進度條，避免與泛用 step 命名撞名。 |
| `.step` | `.bookingStep` | 否 | 是 | Booking 流程步驟項目。 |
| `.step.completed` | `.bookingStep.isCompleted` | 否 | 是 | 狀態統一改用 `is*` 命名。 |
| 舊步驟選取狀態 | `.bookingStep.isSelected` | 否 | 是 | 目前步驟使用 `isSelected`。 |
| `.breadcrumb` | `.bookingBreadcrumb` | 否 | 是 | `#breadcrumbName` 保留給 JS 更新文字。 |
| `.tag` | `.bookingTag` | 是 | 是 | 營區、設施、推薦標籤的共用 base class。 |
| `.tagEnv` | `.bookingTagEnv` | 是 | 是 | 環境標籤。 |
| `.tagFacility` | `.bookingTagFacility` | 是 | 是 | 設施標籤。 |
| `.tagRecommend` | `.bookingTagRecommend` | 是 | 是 | 推薦標籤。 |
| `.priceSummary` | `.bookingPriceSummary` | 否 | 是 | 價格摘要元件。 |
| `.priceSummaryLabel` | `.bookingPriceSummaryLabel` | 否 | 是 | 價格摘要 label。 |
| `.priceSummaryAmount` | `.bookingPriceSummaryAmount` | 否 | 是 | 價格摘要金額。 |
| `.detailRow` | `.bookingSummaryRow` | 是 | 是 | Checkout 明細列語意化。 |
| `.detailRowMeta` | `.bookingSummaryRowMeta` | 是 | 是 | Checkout 明細 meta 列語意化。 |
| `.costRow` | `.bookingCostRow` | 是 | 是 | Cart / checkout 金額列語意化。 |
| `.costRowDiscount` | `.bookingCostRowDiscount` | 是 | 是 | 折扣金額列語意化。 |
| `.noRental` | `.bookingNoRental` | 是 | 是 | 無租借裝備提示語意化。 |
| `.paymentOption` | `.bookingPaymentOption` | 否 | 是 | Checkout 付款選項語意化。 |
| `.paymentOptionTitle` | `.bookingPaymentOptionTitle` | 否 | 是 | 付款選項標題。 |
| `.paymentOptionDesc` | `.bookingPaymentOptionDesc` | 否 | 是 | 付款選項說明。 |
| `.isFieldInvalid` | `.isInvalid` | 是 | 是 | 表單錯誤狀態統一。 |
| `.isCheckoutSuccess` | `.isSuccess` | 是 | 是 | 結帳成功狀態統一。 |
| `.isAdded` | `.isSelected` | 是 | 是 | 租借項目已選狀態統一。 |
| `.ycFilterChip.isActive` | `.ycFilterChip.isSelected` | 是 | 是 | 篩選 chip 狀態統一。 |
| `#bookingCartContent` | `.bookingCartContent` | 是 | 是 | ID 保留為 JS hook，CSS 改用 class。 |
| `#bookingCartEmpty` | `.bookingCartEmptyState` | 是 | 是 | 空背包狀態樣式改用 class。 |
| `#bookingCartCostRows` | `.bookingCartCostRows` | 是 | 是 | 金額列容器樣式改用 class。 |
| `#bookingCartCheckoutButton` | `.bookingCartCheckoutButton` | 是 | 是 | 背包結帳 CTA 樣式改用 class。 |
| `#dateSummary` | `.dateSummary` | 是 | 是 | 日期摘要樣式改用 class。 |
| `#priceSummary` | `.bookingPriceSummary` | 是 | 是 | 價格摘要樣式改用 class。 |
| `#loginNotice` | `.loginNoticeBooking` | 是 | 是 | 登入提示樣式改用 class。 |
| `#creditCardSection` | `.creditCardSectionBooking` | 是 | 是 | 信用卡欄位區塊樣式改用 class。 |
| `#confirmPayBtn` | `.confirmPayButtonBooking` | 是 | 是 | 結帳送出 CTA 樣式改用 class。 |
| `#upsellSection` | `.checkoutUpsellSection` | 是 | 是 | Checkout 加購區塊樣式改用 class。 |
| `#upsellBanner` | `.checkoutUpsellBannerBooking` | 是 | 是 | Checkout 加購提示樣式改用 class。 |
| `#priceMin.isRangeThumbRaised` | `.priceRangeThumbMin.isRaised` | 是 | 是 | range thumb 狀態改用 `isRaised`。 |
| `#resetFilterBtn` | `.resetFilterButtonBooking` | 是 | 是 | 搜尋重設按鈕樣式改用 class。 |
| `#recommendationBanner` | `.recommendationBannerBooking` | 是 | 是 | 租借推薦區塊樣式改用 class。 |
| `#rentalCount` | `.rentalCountBooking` | 是 | 是 | 租借數量樣式改用 class。 |
| `#damage` | `.faqDamageSection` | 否 | 是 | FAQ anchor ID 保留，樣式改用 class。 |
| `#bookingToastContainer` | `.bookingToastContainer` | 是 | 是 | Toast container 保留 ID 作 runtime hook，CSS 改用 class。 |
| `#bookingHeader` | `.bookingHeaderMount` | 是 | 是 | Layout injection hook 保留 ID，sticky mount 樣式改用 class。 |
| `#bookingHeader #loginModal.modal` | `.bookingLoginModal.bookingAuthModal` | 是 | 是 | Shared auth modal 保留 ID 給 modal API，booking CSS 改用注入後 class。 |
| `#bookingHeader #personalizationModal.modal` | `.bookingPersonalizationModal.bookingAuthModal` | 是 | 是 | Shared personalization modal 樣式改用 booking class。 |
| `#bookingHeader #surveyCloseConfirmModal.modal` | `.bookingSurveyCloseConfirmModal.bookingAuthModal` | 是 | 是 | Shared survey confirm modal 樣式改用 booking class。 |
| `#bookingHeader .modalContent` | `.bookingAuthModalContent` | 是 | 是 | Shared auth partial class 保留，booking CSS 使用注入後 class。 |
| `#bookingHeader .modalHeader` | `.bookingAuthModalHeader` | 是 | 是 | Shared auth partial class 保留，booking CSS 使用注入後 class。 |
| `#bookingHeader .modalTitle` | `.bookingAuthModalTitle` | 是 | 是 | Shared auth partial class 保留，booking CSS 使用注入後 class。 |
| `#bookingHeader .modalClose` | `.bookingAuthModalClose` | 是 | 是 | Shared auth close button 保留原 class，booking CSS 使用注入後 class。 |
| `#bookingHeader .modalBody` | `.bookingAuthModalBody` | 是 | 是 | Shared auth partial class 保留，booking CSS 使用注入後 class。 |

## 保留項目

- `.btn` 與 `.modal` 仍是主站與 booking 共用 runtime contract，不在本輪強制移除。
- `flatpickr-*` 與 Bootstrap Icons class 是外部套件 selector，不改名。
- `#bookingCartContent`、`#priceSummary`、`#loginNotice` 等 ID 保留作為 JS hook；CSS 已改由語意 class 承接。
- `--yc-*` 是唯一 runtime token source；不再新增 `--yui-*` 或 `--bk-*` alias。
