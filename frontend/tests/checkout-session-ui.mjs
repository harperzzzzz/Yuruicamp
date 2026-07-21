import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(
  new URL('../storefront/js/pages/checkout.js', import.meta.url),
  'utf8',
);

const createClassList = () => {
  const values = new Set();

  return {
    add: (...names) => names.forEach(name => values.add(name)),
    remove: (...names) => names.forEach(name => values.delete(name)),
    toggle: (name, force) => {
      if (force === true) values.add(name);
      else if (force === false) values.delete(name);
      else if (values.has(name)) values.delete(name);
      else values.add(name);
    },
    contains: name => values.has(name),
  };
};

const createElement = () => ({
  attributes: new Map(),
  children: [],
  classList: createClassList(),
  dataset: {},
  disabled: false,
  hidden: false,
  textContent: '',
  appendChild(child) {
    this.children.push(child);
  },
  replaceChildren() {
    this.children = [];
  },
  setAttribute(name, value) {
    this.attributes.set(name, String(value));
  },
});

const elementIds = [
  'checkoutSessionPanel',
  'checkoutSessionIcon',
  'checkoutSessionBadge',
  'checkoutSessionTitle',
  'checkoutSessionMessage',
  'checkoutSessionDetails',
  'checkoutSessionTimer',
  'checkoutCountdown',
  'cancelCheckoutBtn',
  'returnToCartBtn',
  'confirmOrderBtn',
  'checkoutActionStatus',
  'checkoutSubtotal',
  'checkoutShipping',
  'checkoutDiscountRow',
  'checkoutDiscount',
  'checkoutTotal',
  'checkoutPricingSource',
  'buyerName',
  'buyerPhone',
  'checkoutShippingAddressDisplay',
  'checkoutShippingAddressEditBtn',
  'panelPayment',
];
const elements = new Map(elementIds.map(id => [id, createElement()]));
const storageValues = new Map();
const sessionStorage = {
  getItem: key => storageValues.get(key) ?? null,
  setItem: (key, value) => storageValues.set(key, String(value)),
  removeItem: key => storageValues.delete(key),
};

let openedCart = 0;
let openedModal = '';
let cancelledOrderId = '';
const window = {
  AppConfig: { USE_MOCK_API: false },
  AppState: { cart: [{ variantId: 'V001', quantity: 1 }] },
  API: {
    checkout: {
      cancelSession: async orderId => {
        cancelledOrderId = orderId;
        return { orderId, status: 'cancelled' };
      },
    },
  },
  clearInterval() {},
  formatCurrency: value => `NT$${Number(value).toFixed(2)}`,
  openCartDrawer: () => {
    openedCart += 1;
  },
  openModal: modalId => {
    openedModal = modalId;
  },
  setInterval: () => 7,
};
const document = {
  readyState: 'loading',
  addEventListener() {},
  createElement,
  getElementById: id => elements.get(id) || null,
  querySelector: () => ({ value: 'credit' }),
};
const context = vm.createContext({
  console,
  Date,
  document,
  JSON,
  Math,
  Number,
  sessionStorage,
  String,
  window,
});
window.document = document;
window.sessionStorage = sessionStorage;
window.window = window;

vm.runInContext(source, context, { filename: 'checkout.js' });

const pricing = {
  subtotal: '3200.00',
  shippingFee: '0.00',
  discount: '0.00',
  total: '3200.00',
};
const confirmButton = elements.get('confirmOrderBtn');

context._renderCheckoutSessionState({
  orderId: 'O-DRAFT',
  checkoutStep: 'draft',
  checkoutExpiresAt: new Date(Date.now() + 15 * 60 * 1000).toISOString(),
  paymentMethod: null,
  pricing,
}, confirmButton);
assert.equal(elements.get('checkoutSessionPanel').dataset.state, 'isDraft');
assert.equal(elements.get('checkoutSessionTitle').textContent, '結帳資料尚未完整');
assert.equal(elements.get('checkoutSessionTimer').hidden, true);
assert.equal(confirmButton.disabled, false);
assert.equal(confirmButton.textContent, '更新結帳資料');
assert.equal(elements.get('cancelCheckoutBtn').hidden, false);

context._renderCheckoutSessionState({
  orderId: 'O-READY',
  checkoutStep: 'ready_to_pay',
  checkoutExpiresAt: new Date(Date.now() + 15 * 60 * 1000).toISOString(),
  paymentMethod: 'ecpay-credit',
  pricing,
}, confirmButton);
assert.equal(elements.get('checkoutSessionPanel').dataset.state, 'isReady');
assert.equal(elements.get('checkoutSessionTimer').hidden, false);
assert.match(elements.get('checkoutCountdown').textContent, /^1[45]:[0-5][0-9]$/);
assert.equal(confirmButton.disabled, true);
assert.equal(elements.get('checkoutTotal').textContent, 'NT$3200.00');

storageValues.set('checkoutIdempotencyKey', 'KEY-1');
storageValues.set('checkoutCompletedOrderId', 'O-READY');
storageValues.set('lastCheckoutSession', '{}');
context._handleCheckoutExpired();
assert.equal(storageValues.has('checkoutIdempotencyKey'), false);
assert.equal(storageValues.has('checkoutCompletedOrderId'), false);
assert.equal(elements.get('checkoutSessionPanel').dataset.state, 'isExpired');
assert.match(elements.get('checkoutSessionMessage').textContent, /庫存已釋放/);
assert.equal(window.AppState.cart.length, 1);
assert.equal(confirmButton.textContent, '重新建立 Checkout');

storageValues.set('lastCheckoutSession', JSON.stringify({ orderId: 'O-CANCEL' }));
await context._cancelCheckoutSession(elements.get('cancelCheckoutBtn'));
assert.equal(cancelledOrderId, 'O-CANCEL');
assert.equal(elements.get('checkoutSessionPanel').dataset.state, 'isCancelled');
assert.equal(openedCart, 1);
assert.equal(window.AppState.cart.length, 1);

context._handleCheckoutError({ code: 'UNAUTHORIZED' }, confirmButton);
assert.equal(openedModal, 'loginModal');
assert.equal(elements.get('checkoutSessionTitle').textContent, '請先登入');

context._handleCheckoutError({
  code: 'STOCK_INSUFFICIENT',
  message: 'Insufficient stock for variant: V001',
}, confirmButton);
assert.equal(elements.get('checkoutSessionDetails').children[0].textContent, 'Insufficient stock for variant: V001');
assert.equal(elements.get('returnToCartBtn').hidden, false);

context._handleCheckoutError({
  code: 'VALIDATION_ERROR',
  details: [{ field: 'shipping.phone', reason: 'must not be blank' }],
}, confirmButton);
assert.equal(elements.get('buyerPhone').classList.contains('isInvalid'), true);
assert.equal(elements.get('buyerPhone').attributes.get('aria-invalid'), 'true');

storageValues.set('checkoutIdempotencyKey', 'CONFLICT-KEY');
context._handleCheckoutError({
  code: 'CONFLICT',
  message: 'Idempotency key was already used with a different checkout request',
}, confirmButton);
assert.equal(storageValues.has('checkoutIdempotencyKey'), false);
assert.equal(confirmButton.textContent, '重新建立 Checkout');

context._handleCheckoutError({ code: 'INTERNAL_ERROR' }, confirmButton);
assert.match(elements.get('checkoutSessionMessage').textContent, /稍後再試/);

assert(source.includes('API.checkout.updateSession('));
assert(source.includes('_buildCheckoutUpdateRequest'));

console.log('checkout session UI checks passed');
