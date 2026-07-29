import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const rootDir = dirname(dirname(fileURLToPath(import.meta.url)));
const facadeSource = readFileSync(join(rootDir, 'storefront/js/api-mock.js'), 'utf8');

function createRuntime(useMockApi, backendOrders = []) {
  const calls = [];
  const storage = new Map();
  const localStorage = {
    getItem: (key) => storage.get(key) || null,
    setItem: (key, value) => storage.set(key, value),
    removeItem: (key) => storage.delete(key),
  };
  const window = {
    AppConfig: {
      USE_MOCK_API: useMockApi,
      API_BASE_URL: 'http://localhost:8080/api',
      CACHE_DURATION: 3600000,
    },
    ApiClient: {
      _restRequest: async (path, options) => {
        calls.push({ path, options });
        return backendOrders;
      },
    },
    formatOrderDisplayId: (id) => `ORD-${id}`,
  };
  const mockOrders = [
    { id: 1, customerId: 'U001', status: 'completed', items: [] },
    { id: 2, customerId: 'U002', status: 'unshipped', items: [] },
  ];

  vm.runInNewContext(
    facadeSource,
    {
      window,
      localStorage,
      fetch: async (url) => {
        assert.equal(url, '/data/commerce/orders.json');
        return { ok: true, json: async () => mockOrders };
      },
      URLSearchParams,
      CustomEvent: class CustomEvent {},
      console,
    },
    { filename: 'api-mock.js' }
  );

  return { window, calls, localStorage };
}

const backendOrder = {
  id: 'O1001',
  customerId: 'C-AUTHENTICATED',
  placedAt: '2026-07-22T10:00:00Z',
  shippingAddress: '台北市測試路 1 號',
  shippingPhone: '0912345678',
  paymentMethod: 'ecpay-credit',
  paymentStatus: 'unpaid',
  status: 'unshipped',
  total: '2400.00',
  items: [
    {
      id: 91,
      productId: 'P001',
      productName: '測試帳篷',
      specification: '雙人帳',
      imageUrl: '/assets/test.jpg',
      unitPrice: '1200.00',
      quantity: 2,
    },
  ],
};
const backend = createRuntime(false, [backendOrder]);
const backendResult = await backend.window.API.orders.getByCustomerId('FORGED-CUSTOMER');

assert.equal(backend.calls.length, 1);
assert.equal(backend.calls[0].path, '/me/orders');
assert.equal(backend.calls[0].options.auth, 'required');
assert.equal(backendResult.length, 1, 'Backend identity must come from principal, not the caller argument');
assert.equal(backendResult[0].createdAt, backendOrder.placedAt);
assert.equal(backendResult[0].payment, 'ecpay-credit');
assert.equal(backendResult[0].address, backendOrder.shippingAddress);
assert.equal(backendResult[0].items[0].orderItemId, 91);
assert.equal(backendResult[0].items[0].name, '測試帳篷');
assert.equal(backendResult[0].items[0].image, '/assets/test.jpg');
assert.equal(backendResult[0].items[0].price, 1200);
assert.equal(backendResult[0].items[0].specLabel, '雙人帳');
assert.equal(backend.localStorage.getItem('mockOrders'), null);

const mock = createRuntime(true);
const mockResult = await mock.window.API.orders.getByCustomerId('U001', 'completed');

assert.equal(mock.calls.length, 0, 'Mock mode must not call Spring REST');
assert.equal(mockResult.length, 1);
assert.equal(mockResult[0].id, 1);

console.log('Member Orders facade checks passed');
