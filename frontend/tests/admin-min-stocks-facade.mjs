import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

/**
 * ADM-W1-07：驗證 min-stocks facade 路徑與 readiness。
 * Facade tests for min-stock list／upsert + products.minStock readiness.
 */
const rootDir = dirname(dirname(fileURLToPath(import.meta.url)));
const apiSource = readFileSync(join(rootDir, 'admin/js/admin-api.js'), 'utf8');
const runtimeSource = readFileSync(join(rootDir, 'admin/js/admin-runtime.js'), 'utf8');
const calls = [];
const window = {
  AppConfig: {
    USE_MOCK_API: false,
    API_BASE_URL: 'http://localhost:8080/api',
    ADMIN: { USE_BACKEND: true },
  },
  ApiRequestError: class ApiRequestError extends Error {
    constructor(code, message, details, status) {
      super(message);
      this.code = code;
      this.details = details;
      this.status = status;
    }
  },
  ApiClient: {
    _restRequest: async (path, options) => {
      calls.push({ path, options });
      if (path.startsWith('/min-stocks')) {
        return [
          {
            inventoryDomain: 'store',
            variantId: 'V001',
            productId: 'P001',
            locationId: 'main',
            minimumQuantity: 5,
          },
        ];
      }
      return {};
    },
  },
  console,
};
const context = { window, console, URLSearchParams };

vm.runInNewContext(apiSource, context, { filename: 'admin-api.js' });
vm.runInNewContext(runtimeSource, context, { filename: 'admin-runtime.js' });
window.AdminAPI.configure({ useBackend: true });

assert.equal(window.AdminRuntime.isFeatureReady('products.minStock'), true);
// W2-04：租借 listing／定價後端契約已就緒，readiness 改為 true（見 admin-runtime.js 備註）。
assert.equal(window.AdminRuntime.isFeatureReady('products.rentalWrite'), true);
assert.match(window.AdminRuntime.getReadiness('products').note, /最低庫存/);

await window.AdminAPI.minStocks.list({ inventoryDomain: 'store', productId: 'P001' });
await window.AdminAPI.minStocks.upsert({
  inventoryDomain: 'store',
  items: [{ variantId: 'V001', locationId: 'main', minimumQuantity: 3 }],
});

assert.deepEqual(
  calls.map((call) => [call.options.method, call.path]),
  [
    ['GET', '/min-stocks?inventoryDomain=store&productId=P001'],
    ['PUT', '/min-stocks'],
  ],
);
assert.equal(calls.every((call) => call.options.auth === 'required'), true);
assert.deepEqual(calls[1].options.body, {
  inventoryDomain: 'store',
  items: [{ variantId: 'V001', locationId: 'main', minimumQuantity: 3 }],
});

console.log('Admin min-stocks facade tests passed.');
