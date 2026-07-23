import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

/**
 * ADM-W2-06：inventory-locations facade 與 readiness。
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
      return { id: 'W206-REPAIR', name: '維修區', active: true };
    },
  },
  console,
};
const context = { window, console, URLSearchParams };

vm.runInNewContext(apiSource, context, { filename: 'admin-api.js' });
vm.runInNewContext(runtimeSource, context, { filename: 'admin-runtime.js' });
window.AdminAPI.configure({ useBackend: true });

assert.equal(window.AdminRuntime.isFeatureReady('movement.locations'), true);

await window.AdminAPI.inventoryLocations.create({
  id: 'W206-REPAIR',
  code: 'w206-repair',
  inventoryDomain: 'store',
  type: 'repair',
  name: '維修區',
});
await window.AdminAPI.inventoryLocations.list({ includeInactive: true });
await window.AdminAPI.inventoryLocations.update('W206-REPAIR', { active: false });
await window.AdminAPI.inventoryLocations.remove('W206-REPAIR');

assert.deepEqual(
  calls.map((call) => [call.options.method, call.path]),
  [
    ['POST', '/inventory-locations'],
    ['GET', '/inventory-locations?includeInactive=true'],
    ['PATCH', '/inventory-locations/W206-REPAIR'],
    ['DELETE', '/inventory-locations/W206-REPAIR'],
  ],
);

console.log('Admin inventory locations facade tests passed.');
