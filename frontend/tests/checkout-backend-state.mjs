import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const checkoutSource = readFileSync(
  new URL('../storefront/js/pages/checkout.js', import.meta.url),
  'utf8',
);
const checkoutHtml = readFileSync(
  new URL('../storefront/pages/checkout.html', import.meta.url),
  'utf8',
);

const createClassList = () => {
  const values = new Set();
  return {
    add: value => values.add(value),
    remove: value => values.delete(value),
    toggle: (value, force) => {
      if (force === true) values.add(value);
      else if (force === false) values.delete(value);
      else if (values.has(value)) values.delete(value);
      else values.add(value);
    },
    contains: value => values.has(value),
  };
};

const element = () => ({
  classList: createClassList(),
  disabled: false,
  hidden: false,
  placeholder: '',
  textContent: '',
});

const elements = new Map([
  ['checkoutSubtotal', element()],
  ['checkoutShipping', element()],
  ['checkoutDiscountRow', element()],
  ['checkoutDiscount', element()],
  ['checkoutTotal', element()],
  ['checkoutPricingSource', element()],
  ['checkoutCouponInput', element()],
  ['checkoutApplyCouponBtn', element()],
  ['checkoutCouponMsg', element()],
  ['checkoutAppliedCouponTexts', element()],
  ['ecpayPaymentNotice', element()],
  ['codPaymentNotice', element()],
  ['checkoutActionStatus', element()],
  ['confirmOrderBtn', element()],
]);

let selectedPayment = 'credit';
let couponCatalogLoads = 0;
const sessionStorage = new Map();
const context = vm.createContext({
  console,
  sessionStorage: {
    getItem: key => sessionStorage.get(key) ?? null,
    setItem: (key, value) => sessionStorage.set(key, String(value)),
    removeItem: key => sessionStorage.delete(key),
  },
  document: {
    readyState: 'loading',
    addEventListener() {},
    getElementById: id => elements.get(id) || null,
    querySelector: selector => (
      selector === 'input[name="paymentMethod"]:checked' ? { value: selectedPayment } : null
    ),
  },
  window: {
    AppConfig: { USE_MOCK_API: false },
    AppState: { cart: [] },
    YuruiCoupons: {
      loadCoupons: async () => {
        couponCatalogLoads += 1;
        return [];
      },
    },
    formatCurrency: value => `NT$${Number(value).toFixed(2)}`,
    setInterval: () => 1,
    clearInterval() {},
  },
});
context.window.window = context.window;
context.window.sessionStorage = context.sessionStorage;
context.window.document = context.document;

vm.runInContext(checkoutSource, context, { filename: 'checkout.js' });

context._applyCheckoutSessionPricing({
  subtotal: '3200.00',
  shippingFee: '100.00',
  discount: '200.00',
  total: '3100.00',
});
assert.equal(elements.get('checkoutSubtotal').textContent, 'NT$3200.00');
assert.equal(elements.get('checkoutShipping').textContent, 'NT$100.00');
assert.equal(elements.get('checkoutDiscount').textContent, '-NT$200.00');
assert.equal(elements.get('checkoutTotal').textContent, 'NT$3100.00');
assert.equal(elements.get('checkoutDiscountRow').hidden, false);
assert.equal(elements.get('checkoutPricingSource').classList.contains('isConfirmed'), true);
assert.match(elements.get('checkoutPricingSource').textContent, /Spring Boot/);

sessionStorage.set('checkoutCompletedOrderId', 'O001');
sessionStorage.set('lastCheckoutSession', JSON.stringify({
  orderId: 'O001',
  pricing: {
    subtotal: '3200.00',
    shippingFee: '100.00',
    discount: '200.00',
    total: '3100.00',
  },
}));
context._updateCheckoutSummary();
assert.equal(elements.get('checkoutTotal').textContent, 'NT$3100.00');

context._initCheckoutCoupon();
assert.equal(elements.get('checkoutCouponInput').disabled, true);
assert.equal(elements.get('checkoutApplyCouponBtn').disabled, true);
assert.equal(elements.get('checkoutCouponInput').placeholder, '優惠券功能開發中');
assert.equal(elements.get('checkoutCouponMsg').classList.contains('isInfo'), true);
assert.equal(couponCatalogLoads, 0, 'Backend mode must not load or consume frontend coupon state');

context._syncPaymentNoticeState();
assert.equal(elements.get('ecpayPaymentNotice').hidden, false);
assert.equal(elements.get('codPaymentNotice').hidden, true);
selectedPayment = 'cod';
context._syncPaymentNoticeState();
assert.equal(elements.get('ecpayPaymentNotice').hidden, true);
assert.equal(elements.get('codPaymentNotice').hidden, false);

const confirmButton = element();
context._showCheckoutSessionReady(
  {
    orderId: 'O001',
    paymentMethod: 'ecpay-credit',
    checkoutStep: 'ready_to_pay',
    checkoutExpiresAt: new Date(Date.now() + 15 * 60 * 1000).toISOString(),
    pricing: {
      subtotal: '3200.00',
      shippingFee: '100.00',
      discount: '200.00',
      total: '3100.00',
    },
  },
  confirmButton,
);
assert.equal(confirmButton.disabled, true);
assert.equal(confirmButton.textContent, '等待 ECPay 串接');
assert.match(elements.get('checkoutActionStatus').textContent, /O001/);

context._showCheckoutEstimateState();
assert.equal(elements.get('checkoutPricingSource').classList.contains('isConfirmed'), false);
assert.match(elements.get('checkoutPricingSource').textContent, /預估金額/);
assert.equal(elements.get('checkoutActionStatus').hidden, true);
assert.equal(elements.get('confirmOrderBtn').disabled, false);
assert.equal(elements.get('confirmOrderBtn').textContent, '確認結帳');

assert(!checkoutHtml.includes('id="cardNumber"'));
assert(!checkoutHtml.includes('id="cardExpiry"'));
assert(!checkoutHtml.includes('id="cardCvv"'));
assert(checkoutHtml.includes('下一步將前往 ECPay'));
assert(!checkoutSource.includes('lastCheckoutOrder'));
assert(!checkoutSource.includes('markFirstPurchaseUsed'));
assert(!checkoutSource.includes('API.orders.create'));

console.log('checkout backend state test passed');
