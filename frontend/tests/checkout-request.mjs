import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const rootDir = dirname(dirname(fileURLToPath(import.meta.url)));
const source = readFileSync(join(rootDir, 'storefront/js/pages/checkout.js'), 'utf8');
const sessionValues = new Map();
const localValues = new Map();
let uuidSequence = 0;
let createSessionCalls = 0;
let shouldFailCreate = false;
const documentListeners = new Map();

const sessionStorage = {
  getItem: key => sessionValues.get(key) || null,
  setItem: (key, value) => sessionValues.set(key, value),
  removeItem: key => sessionValues.delete(key),
};

const localStorage = {
  getItem: key => localValues.get(key) || null,
  setItem: (key, value) => localValues.set(key, value),
  removeItem: key => localValues.delete(key),
};

const window = {
  AppState: {
    cart: [
      {
        id: 'P001',
        variantId: 'V001',
        sku: 'TENT-OLIVE',
        name: 'Coleman 六人帳篷',
        price: 3200,
        quantity: 1,
      },
    ],
  },
  crypto: {
    randomUUID: () => (
      uuidSequence++ === 0
        ? '8ca3d465-1111-4111-8111-111111111111'
        : '8ca3d465-2222-4222-8222-222222222222'
    ),
  },
  API: {
    checkout: {
      createSession: async request => {
        createSessionCalls += 1;
        if (shouldFailCreate) throw new Error('NETWORK_ERROR');
        return {
          orderId: `O-${createSessionCalls}`,
          paymentMethod: request.paymentMethod,
          pricing: {
            subtotal: '3200.00',
            shippingFee: '0.00',
            discount: '0.00',
            total: '3200.00',
          },
          request,
        };
      },
    },
  },
  calculateCartTotal: cart => cart.reduce((sum, item) => sum + item.price * item.quantity, 0),
  calculateShippingFee: () => 0,
  formatCurrency: value => `NT$${Number(value).toFixed(2)}`,
};

const document = {
  readyState: 'loading',
  getElementById: () => null,
  addEventListener: (eventName, listener) => {
    const listeners = documentListeners.get(eventName) || [];
    listeners.push(listener);
    documentListeners.set(eventName, listeners);
  },
  dispatchEvent: event => {
    (documentListeners.get(event.type) || []).forEach(listener => listener(event));
  },
  querySelector: selector => (
    selector === 'input[name="paymentMethod"]:checked'
      ? { value: 'cod' }
      : null
  ),
};

const context = vm.createContext({
  window,
  document,
  sessionStorage,
  localStorage,
  console,
  Date,
  Math,
  JSON,
  Number,
  String,
});

vm.runInContext(source, context, { filename: 'checkout.js' });

const formData = {
  buyerName: 'Amy',
  buyerPhone: '0912345678',
  buyerEmail: 'amy@example.com',
  deliveryAddress: '台北市信義區測試路 1 號',
  userNote: '不要在 Request 內傳送',
};
const request = context._buildCheckoutRequest(formData);

assert.deepEqual(
  Object.keys(request).sort(),
  ['items', 'shipping', 'paymentMethod', 'idempotencyKey'].sort(),
);
assert.deepEqual(
  JSON.parse(JSON.stringify(request.items)),
  [{ variantId: 'V001', quantity: 1 }],
);
assert.deepEqual(
  JSON.parse(JSON.stringify(request.shipping)),
  {
    recipientName: 'Amy',
    phone: '0912345678',
    address: '台北市信義區測試路 1 號',
  },
);
assert.equal(request.paymentMethod, 'cod');
assert.equal(request.idempotencyKey, '8ca3d465-1111-4111-8111-111111111111');
assert.equal(sessionStorage.getItem('checkoutIdempotencyKey'), request.idempotencyKey);

const replay = context._buildCheckoutRequest(formData);
assert.equal(replay.idempotencyKey, request.idempotencyKey);

const changedShipping = context._buildCheckoutRequest({
  ...formData,
  buyerPhone: '0987654321',
});
assert.equal(changedShipping.idempotencyKey, request.idempotencyKey);

const [firstSubmit, doubleClickSubmit] = await Promise.all([
  context._createCheckoutSession(request),
  context._createCheckoutSession(request),
]);
assert.equal(createSessionCalls, 1);
assert.equal(firstSubmit.orderId, doubleClickSubmit.orderId);
assert.equal(sessionStorage.getItem('checkoutCompletedOrderId'), firstSubmit.orderId);
sessionStorage.setItem('lastCheckoutSession', JSON.stringify(firstSubmit));

const completedReplay = await context._createCheckoutSession(request);
assert.equal(completedReplay.orderId, firstSubmit.orderId);
assert.equal(createSessionCalls, 1);

context._initCheckoutIdempotencyListener();
window.AppState.cart[0].quantity = 2;
document.dispatchEvent({ type: 'yurui:cart-changed' });
assert.equal(sessionStorage.getItem('checkoutIdempotencyKey'), null);
assert.equal(sessionStorage.getItem('checkoutCompletedOrderId'), null);
assert.equal(sessionStorage.getItem('lastCheckoutSession'), null);

const changedCartRequest = context._buildCheckoutRequest(formData);
assert.equal(changedCartRequest.idempotencyKey, '8ca3d465-2222-4222-8222-222222222222');

shouldFailCreate = true;
await assert.rejects(context._createCheckoutSession(changedCartRequest), /NETWORK_ERROR/);
assert.equal(
  sessionStorage.getItem('checkoutIdempotencyKey'),
  changedCartRequest.idempotencyKey,
);

shouldFailCreate = false;
const networkRetry = context._buildCheckoutRequest(formData);
assert.equal(networkRetry.idempotencyKey, changedCartRequest.idempotencyKey);
await context._createCheckoutSession(networkRetry);
assert.equal(createSessionCalls, 3);

window.CheckoutIdempotency.clear();
assert.equal(sessionStorage.getItem('checkoutIdempotencyKey'), null);
assert.equal(sessionStorage.getItem('checkoutCartFingerprint'), null);
assert.equal(sessionStorage.getItem('checkoutCompletedOrderId'), null);
assert.equal(sessionStorage.getItem('lastCheckoutSession'), null);

const forbiddenFields = [
  'customerId',
  'id',
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
  'points',
];
const requestText = JSON.stringify(request);
for (const field of forbiddenFields) {
  assert(!requestText.includes(`"${field}"`), `Checkout Request must not contain ${field}`);
}

assert(source.includes('window.API.checkout.createSession(request)'));
assert(!source.includes('window.API.orders.create(orderData)'));

console.log('Checkout Request contract checks passed');
