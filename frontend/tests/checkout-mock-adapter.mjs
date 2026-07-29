import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const rootDir = dirname(dirname(fileURLToPath(import.meta.url)));
const facadeSource = readFileSync(join(rootDir, 'storefront/js/api-mock.js'), 'utf8');
const products = JSON.parse(readFileSync(join(rootDir, 'data/catalog/products.json'), 'utf8'));
const storage = new Map();
let checkoutIdempotencyClears = 0;

class TestApiRequestError extends Error {
  constructor(code, message, details = [], status = 0) {
    super(message);
    this.name = 'ApiRequestError';
    this.code = code;
    this.details = details;
    this.status = status;
  }
}

const localStorage = {
  getItem: (key) => storage.get(key) || null,
  setItem: (key, value) => storage.set(key, value),
  removeItem: (key) => storage.delete(key),
};

const window = {
  AppConfig: {
    USE_MOCK_API: true,
    API_BASE_URL: 'http://localhost:8080/api',
    CACHE_DURATION: 3600000,
  },
  AppState: {
    currentUser: {
      id: 'U-MOCK-CHECKOUT',
      name: 'Mock 會員',
      phone: '0900000000',
    },
  },
  ApiRequestError: TestApiRequestError,
  ApiClient: {
    _restRequest: async () => {
      throw new Error('Mock Checkout must not call Spring REST');
    },
  },
  CheckoutIdempotency: {
    clear: () => {
      checkoutIdempotencyClears += 1;
    },
  },
};

vm.runInNewContext(facadeSource, {
  window,
  localStorage,
  fetch: async (url) => {
    assert.equal(url, '/data/catalog/products.json');

    return {
      ok: true,
      json: async () => products,
    };
  },
  URLSearchParams,
  CustomEvent: class CustomEvent {},
  console,
}, { filename: 'api-mock.js' });

const request = {
  items: [{ variantId: 'V001', quantity: 1, unitPrice: '0.01' }],
  paymentMethod: 'cod',
  shipping: {
    recipientName: 'Mock 收件人',
    phone: '0912345678',
    address: '台北市測試路 1 號',
  },
  idempotencyKey: 'mock-checkout-contract-1',
};
const createdAt = Date.now();
const session = await window.API.checkout.createSession(request);

assert.deepEqual(
  Object.keys(session).sort(),
  [
    'checkoutExpiresAt',
    'checkoutStep',
    'couponClaimId',
    'items',
    'orderId',
    'paymentMethod',
    'paymentStatus',
    'pricing',
    'shipping',
    'status',
  ].sort(),
);
assert.deepEqual(
  Object.keys(session.pricing).sort(),
  ['subtotal', 'shippingFee', 'discount', 'total'].sort(),
);
assert.deepEqual(
  Object.keys(session.items[0]).sort(),
  [
    'orderItemId',
    'productId',
    'variantId',
    'sku',
    'productName',
    'specification',
    'brandName',
    'imageUrl',
    'unitPrice',
    'quantity',
    'lineTotal',
  ].sort(),
);
assert.deepEqual(
  Object.keys(session.shipping).sort(),
  ['method', 'recipientName', 'phone', 'address', 'pickupBranchId', 'pickupBranchName'].sort(),
);
assert.equal(session.status, 'unshipped');
assert.equal(session.paymentStatus, 'unpaid');
assert.equal(session.paymentMethod, 'cod');
assert.equal(session.checkoutStep, 'ready_to_pay');
assert.equal(session.pricing.subtotal, '3200.00');
assert.equal(session.pricing.shippingFee, '0.00');
assert.equal(session.pricing.discount, '0.00');
assert.equal(session.pricing.total, '3200.00');
assert.equal(session.items[0].unitPrice, '3200.00');
assert.equal(session.items[0].lineTotal, '3200.00');
assert.equal(session.couponClaimId, null);
assert(Date.parse(session.checkoutExpiresAt) >= createdAt + (14 * 60 * 1000));
assert(Date.parse(session.checkoutExpiresAt) <= createdAt + (16 * 60 * 1000));

const replay = await window.API.checkout.createSession(request);
assert.equal(replay.orderId, session.orderId);

await assert.rejects(
  window.API.checkout.createSession({
    ...request,
    items: [{ variantId: 'V001', quantity: 2 }],
  }),
  (error) => error.code === 'CONFLICT',
);

await assert.rejects(
  window.API.checkout.updateSession(session.orderId, { paymentMethod: '' }),
  (error) => error.code === 'VALIDATION_ERROR',
);

const updated = await window.API.checkout.updateSession(session.orderId, {
  shipping: { address: '新北市更新路 2 號' },
  paymentMethod: 'ecpay-credit',
  couponClaimId: null,
});
assert.equal(updated.shipping.address, '新北市更新路 2 號');
assert.equal(updated.paymentMethod, 'ecpay-credit');
assert.equal(updated.checkoutStep, 'ready_to_pay');

const loaded = await window.API.checkout.getSession(session.orderId);
assert.equal(loaded.orderId, session.orderId);
assert.equal(loaded.shipping.address, '新北市更新路 2 號');

const cancelled = await window.API.checkout.cancelSession(session.orderId);
assert.equal(cancelled.status, 'cancelled');
assert.equal(checkoutIdempotencyClears, 1);
assert.equal(localStorage.getItem('mockOrders'), null);
assert.notEqual(localStorage.getItem('mockCheckoutSessions'), null);

const expiring = await window.API.checkout.createSession({
  ...request,
  idempotencyKey: 'mock-checkout-expired-1',
});
const records = JSON.parse(localStorage.getItem('mockCheckoutSessions'));
const expiringRecord = records.find(record => record.session.orderId === expiring.orderId);
expiringRecord.session.checkoutExpiresAt = new Date(Date.now() - 1000).toISOString();
localStorage.setItem('mockCheckoutSessions', JSON.stringify(records));
await assert.rejects(
  window.API.checkout.updateSession(expiring.orderId, { paymentMethod: 'cod' }),
  error => error.code === 'CHECKOUT_EXPIRED',
);
assert.equal(checkoutIdempotencyClears, 2);

await assert.rejects(
  window.API.checkout.confirmCod(session.orderId),
  (error) => error.code === 'CONFLICT',
);
const codSession = await window.API.checkout.createSession({
  ...request,
  idempotencyKey: 'mock-checkout-cod-confirm-1',
});
const codConfirmed = await window.API.checkout.confirmCod(codSession.orderId);
assert.equal(codConfirmed.checkoutStep, 'completed');
assert.equal(codConfirmed.checkoutExpiresAt, null);
await assert.rejects(
  window.API.checkout.createEcpayForm(session.orderId),
  (error) => error.code === 'PAYMENT_NOT_IMPLEMENTED',
);

window.AppConfig.USE_MOCK_API = false;
await assert.rejects(
  window.API.orders.create({}),
  (error) => error.code === 'LEGACY_ORDER_CREATE_DISABLED',
);

console.log('Checkout Mock adapter checks passed');
