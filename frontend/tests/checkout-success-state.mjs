import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source = fs.readFileSync(
  new URL('../storefront/js/pages/checkout-success.js', import.meta.url),
  'utf8'
);
const storage = new Map();
let domReadyHandler = null;

const window = {
  location: { search: '' },
  sessionStorage: {
    getItem: (key) => storage.get(key) || null,
  },
  clearInterval: () => {},
  setInterval: () => 1,
};
const document = {
  readyState: 'loading',
  addEventListener: (_event, handler) => {
    domReadyHandler = handler;
  },
};

vm.runInNewContext(source, { window, document, URLSearchParams, Date, Number, String });
assert.equal(typeof domReadyHandler, 'function', '頁面應等待 DOMContentLoaded 後才讀取 Session');

const page = window.CheckoutSuccessPage;
const future = '2026-08-01T00:15:00.000Z';
const past = '2026-07-01T00:00:00.000Z';
const now = Date.parse('2026-07-22T00:00:00.000Z');

assert.equal(
  page.resolveViewState({ status: 'pending', paymentStatus: 'unpaid', checkoutExpiresAt: future }, now).key,
  'pending'
);
assert.equal(
  page.resolveViewState({ status: 'cancelled', paymentStatus: 'unpaid', checkoutExpiresAt: future }, now).key,
  'cancelled'
);
assert.equal(
  page.resolveViewState({ status: 'cancelled', paymentStatus: 'unpaid', checkoutExpiresAt: past }, now).key,
  'expired'
);
assert.equal(
  page.resolveViewState({ status: 'pending', paymentStatus: 'paid', checkoutExpiresAt: future }, now).key,
  'paid'
);

window.location.search = '?orderId=order-query';
assert.equal(page.readOrderId(), 'order-query');
window.location.search = '';
storage.set('checkoutCompletedOrderId', 'order-stored');
assert.equal(page.readOrderId(), 'order-stored');
storage.delete('checkoutCompletedOrderId');
storage.set('lastCheckoutSession', JSON.stringify({ orderId: 'order-session' }));
assert.equal(page.readOrderId(), 'order-session');

console.log('checkout success state tests passed');
