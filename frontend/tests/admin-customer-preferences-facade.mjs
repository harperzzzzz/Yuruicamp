import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

/**
 * ADM-W1-05：驗證偏好 replace／lookup facade 與 readiness。
 * Facade tests for customer preferences + preference-options lookup.
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
      if (path.startsWith('/preference-options')) {
        return { data: [{ id: 2, type: 'style', code: 'backpacking', label: '背包旅行', sortOrder: 2, active: true }] };
      }
      return { data: { id: 'C-1', preferences: { styles: ['backpacking'], equipment: [] } } };
    },
  },
  console,
};
const context = { window, console, URLSearchParams };

vm.runInNewContext(apiSource, context, { filename: 'admin-api.js' });
vm.runInNewContext(runtimeSource, context, { filename: 'admin-runtime.js' });
window.AdminAPI.configure({ useBackend: true });

assert.equal(window.AdminRuntime.isFeatureReady('customers.preferences'), true);

await window.AdminAPI.preferenceOptions.list({ includeInactive: false });
await window.AdminAPI.customers.replacePreferences('C-1', [2, 9]);

assert.deepEqual(
  calls.map((call) => [call.options.method, call.path]),
  [
    ['GET', '/preference-options'],
    ['PUT', '/customers/C-1/preferences'],
  ],
);
assert.deepEqual(calls[1].options.body.optionIds, [2, 9]);
assert.equal(calls.every((call) => call.options.auth === 'required'), true);

console.log('Admin customer preferences facade tests passed.');
