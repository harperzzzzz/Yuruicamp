import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const rootDir = dirname(dirname(fileURLToPath(import.meta.url)));
const cartSource = readFileSync(join(rootDir, 'storefront/js/pages/cart.js'), 'utf8');
const checkoutSource = readFileSync(join(rootDir, 'storefront/js/pages/checkout.js'), 'utf8');
const cartPageSource = readFileSync(join(rootDir, 'storefront/pages/cart.html'), 'utf8');
const sessionValues = new Map();
let uuidSequence = 0;
let createSessionCalls = 0;
let cancelledOrderId = '';

const sessionStorage = {
  getItem: (key) => sessionValues.get(key) || null,
  setItem: (key, value) => sessionValues.set(key, String(value)),
  removeItem: (key) => sessionValues.delete(key),
};

const window = {
  AppState: {
    cart: [
      {
        id: 'P001',
        variantId: 'V001',
        name: 'Coleman 六人帳篷',
        price: 3200,
        quantity: 1,
      },
    ],
  },
  crypto: {
    randomUUID: () =>
      uuidSequence++ === 0 ? '8ca3d465-1111-4111-8111-111111111111' : '8ca3d465-2222-4222-8222-222222222222',
  },
  API: {
    checkout: {
      createSession: async (request) => {
        createSessionCalls += 1;
        return {
          orderId: `O-${createSessionCalls}`,
          checkoutStep: 'draft',
          checkoutExpiresAt: new Date(Date.now() + 15 * 60 * 1000).toISOString(),
          pricing: {
            subtotal: String(request.items[0].quantity * 3200),
            shippingFee: '0.00',
            discount: '0.00',
            total: String(request.items[0].quantity * 3200),
          },
          request,
        };
      },
      cancelSession: async (orderId) => {
        cancelledOrderId = orderId;
        return { orderId, status: 'cancelled' };
      },
    },
  },
  calculateCartTotal: (cart) => cart.reduce((sum, item) => sum + item.price * item.quantity, 0),
  calculateShippingFee: () => 0,
  formatCurrency: (value) => `NT$${Number(value).toFixed(2)}`,
  addEventListener: () => {},
};

const document = {
  body: { dataset: {} },
  readyState: 'loading',
  addEventListener: () => {},
  createElement: () => ({ textContent: '' }),
  getElementById: () => null,
};

const context = vm.createContext({
  window,
  document,
  sessionStorage,
  console,
  Date,
  JSON,
  Math,
  Number,
  String,
});

vm.runInContext(cartSource, context, { filename: 'cart.js' });

const request = context._buildStorefrontCartCheckoutRequest(window.AppState.cart);
assert.deepEqual(Object.keys(request).sort(), ['items', 'idempotencyKey'].sort());
assert.deepEqual(JSON.parse(JSON.stringify(request.items)), [{ variantId: 'V001', quantity: 1 }]);
assert.equal(request.idempotencyKey, '8ca3d465-1111-4111-8111-111111111111');

await context._prepareStorefrontCartSession(false);
assert.equal(createSessionCalls, 1);
assert.equal(sessionStorage.getItem('checkoutCompletedOrderId'), 'O-1');
assert.equal(JSON.parse(sessionStorage.getItem('lastCheckoutSession')).checkoutStep, 'draft');

window.AppState.cart[0].quantity = 2;
await context._prepareStorefrontCartSession(true);
assert.equal(cancelledOrderId, 'O-1');
assert.equal(createSessionCalls, 2);
assert.equal(JSON.parse(sessionStorage.getItem('lastCheckoutSession')).request.items[0].quantity, 2);
assert.equal(
  JSON.parse(sessionStorage.getItem('lastCheckoutSession')).request.idempotencyKey,
  '8ca3d465-2222-4222-8222-222222222222'
);

const forbiddenFields = [
  'customerId',
  'productId',
  'sku',
  'name',
  'price',
  'unitPrice',
  'subtotal',
  'shippingFee',
  'discount',
  'total',
  'status',
  'paymentStatus',
];
const requestText = JSON.stringify(request);
for (const field of forbiddenFields) {
  assert(!requestText.includes(`"${field}"`), `Checkout Request must not contain ${field}`);
}

assert(cartPageSource.includes('id="storefrontCartSessionStatus"'));
assert(cartPageSource.includes('id="storefrontCartCheckoutLink"'));
assert(cartPageSource.includes('class="checkoutSteps storefrontCartStepProgress"'));
assert(cartSource.includes('window.API.checkout.createSession(request)'));
assert(cartSource.includes('class="storefrontCartQuantityInput" type="number"'));
assert(cartSource.includes("addEventListener('change'"));
assert(cartSource.includes('商品剩餘數量不足請重新調整數量'));
assert(!checkoutSource.includes('API.checkout.createSession('));
assert(checkoutSource.includes('API.checkout.updateSession('));
assert(!checkoutSource.includes('_createCheckoutSession('));

console.log('Storefront Cart Checkout Request checks passed');
