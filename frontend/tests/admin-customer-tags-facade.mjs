import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

/**
 * ADM-W1-02：驗證標籤池 facade 路徑與 readiness 拆分。
 * Facade tests for customer-tags CRUD + tagPool/tagAssign readiness.
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
      if (path.startsWith('/customer-tags')) {
        return { id: 99, name: 'VIP', color: 'bg-success', sortOrder: 0, active: true };
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

assert.equal(window.AdminRuntime.isFeatureReady('customers.tagPool'), true);
assert.equal(window.AdminRuntime.isFeatureReady('customers.tagAssign'), true);

await window.AdminAPI.tags.list({ includeInactive: true });
await window.AdminAPI.tags.getById(7);
await window.AdminAPI.tags.create({ name: 'VIP', color: 'bg-success' });
await window.AdminAPI.tags.update(7, { active: false });
await window.AdminAPI.tags.remove(7);

assert.deepEqual(
  calls.map((call) => [call.options.method, call.path]),
  [
    ['GET', '/customer-tags?includeInactive=true'],
    ['GET', '/customer-tags/7'],
    ['POST', '/customer-tags'],
    ['PATCH', '/customer-tags/7'],
    ['DELETE', '/customer-tags/7'],
  ],
);
assert.equal(calls.every((call) => call.options.auth === 'required'), true);

await window.AdminAPI.customers.replaceTags('C-1', [7, 8]);
assert.equal(calls[calls.length - 1].options.method, 'PUT');
assert.equal(calls[calls.length - 1].path, '/customers/C-1/tags');
assert.deepEqual(calls[calls.length - 1].options.body.tagIds, [7, 8]);

await assert.rejects(
  window.AdminAPI.tags.savePool({ VIP: 'bg-success' }),
  (error) => error.code === 'ADMIN_FEATURE_NOT_READY',
);

console.log('Admin customer-tags facade tests passed.');
