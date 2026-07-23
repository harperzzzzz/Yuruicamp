import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

/**
 * ADM-W2-01／02：categories／brands facade 與 readiness。
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
      if (path === '/categories') {
        return [{ id: 99, code: 'camp-chair', name: '露營椅', sortOrder: 10 }];
      }
      if (path === '/brands') {
        return [{ id: 'naturehike', name: 'Naturehike', sortOrder: 20 }];
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

assert.equal(window.AdminRuntime.isFeatureReady('products.categoryMaster'), true);
assert.equal(window.AdminRuntime.isFeatureReady('products.brandMaster'), true);

await window.AdminAPI.categories.create({ code: 'camp-chair', name: '露營椅', sortOrder: 10 });
await window.AdminAPI.categories.list();
await window.AdminAPI.categories.update(99, { name: '露營椅改' });
await window.AdminAPI.categories.remove(99);

await window.AdminAPI.brands.create({ id: 'naturehike', name: 'Naturehike', sortOrder: 20 });
await window.AdminAPI.brands.list();
await window.AdminAPI.brands.update('naturehike', { name: 'Naturehike+' });
await window.AdminAPI.brands.remove('naturehike');

assert.deepEqual(
  calls.map((call) => [call.options.method, call.path]),
  [
    ['POST', '/categories'],
    ['GET', '/categories'],
    ['PATCH', '/categories/99'],
    ['DELETE', '/categories/99'],
    ['POST', '/brands'],
    ['GET', '/brands'],
    ['PATCH', '/brands/naturehike'],
    ['DELETE', '/brands/naturehike'],
  ],
);

console.log('Admin catalog master facade tests passed.');
