import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const rootDir = dirname(dirname(fileURLToPath(import.meta.url)));
const facadeSource = readFileSync(join(rootDir, 'storefront/js/api-mock.js'), 'utf8');
const calls = [];

class TestApiRequestError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ApiRequestError';
    this.code = code;
  }
}

const window = {
  AppConfig: {
    USE_MOCK_API: false,
    API_BASE_URL: 'http://localhost:8080/api',
  },
  ApiRequestError: TestApiRequestError,
  ApiClient: {
    _restRequest: async (path, options) => {
      calls.push({ path, options });

      return { ok: true };
    },
  },
};

const storage = new Map();
const localStorage = {
  getItem: (key) => storage.get(key) || null,
  setItem: (key, value) => storage.set(key, value),
  removeItem: (key) => storage.delete(key),
};

vm.runInNewContext(facadeSource, {
  window,
  localStorage,
  fetch: async () => {
    throw new Error('Checkout facade route test must not call fetch directly');
  },
  URLSearchParams,
  CustomEvent: class CustomEvent {},
  console,
}, { filename: 'api-mock.js' });

const checkout = window.API.checkout;
const createRequest = { items: [{ variantId: 'V001', quantity: 1 }] };
const updateRequest = { paymentMethod: 'cod' };

await checkout.createSession(createRequest);
await checkout.getSession('ORD / 001');
await checkout.updateSession('ORD-001', updateRequest);
await checkout.cancelSession('ORD-001');
await checkout.confirmCod('ORD-001');
await checkout.createEcpayForm('ORD-001');

assert.deepEqual(
  calls.map((call) => ({
    path: call.path,
    method: call.options.method,
    auth: call.options.auth,
    body: call.options.body,
  })),
  [
    {
      path: '/checkout/sessions',
      method: 'POST',
      auth: 'required',
      body: createRequest,
    },
    {
      path: '/checkout/sessions/ORD%20%2F%20001',
      method: 'GET',
      auth: 'required',
      body: undefined,
    },
    {
      path: '/checkout/sessions/ORD-001',
      method: 'PATCH',
      auth: 'required',
      body: updateRequest,
    },
    {
      path: '/checkout/sessions/ORD-001/cancel',
      method: 'POST',
      auth: 'required',
      body: undefined,
    },
    {
      path: '/checkout/sessions/ORD-001/confirm-cod',
      method: 'POST',
      auth: 'required',
      body: undefined,
    },
    {
      path: '/checkout/sessions/ORD-001/ecpay',
      method: 'POST',
      auth: 'required',
      body: undefined,
    },
  ],
);

await assert.rejects(
  checkout.getSession(''),
  (error) => error.code === 'VALIDATION_ERROR',
);

assert.equal(
  calls.some((call) => call.path.startsWith('/api/')),
  false,
  'Facade paths must not repeat the /api prefix',
);

console.log('Checkout API facade checks passed');
