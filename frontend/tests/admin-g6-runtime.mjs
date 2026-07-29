import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const rootDir = dirname(dirname(fileURLToPath(import.meta.url)));
const apiSource = readFileSync(join(rootDir, 'admin/js/admin-api.js'), 'utf8');
const runtimeSource = readFileSync(join(rootDir, 'admin/js/admin-runtime.js'), 'utf8');
const authSource = readFileSync(join(rootDir, 'admin/js/admin-auth.js'), 'utf8');
const loginHtml = readFileSync(join(rootDir, 'admin/login.html'), 'utf8');
const calls = [];
const storage = new Map();
const sessionStorage = {
  getItem: key => storage.get(key) ?? null,
  setItem: (key, value) => storage.set(key, String(value)),
  removeItem: key => storage.delete(key),
};
const window = {
  AppConfig: {
    USE_MOCK_API: false,
    API_BASE_URL: 'http://localhost:8080/api',
    ENVIRONMENT: 'development',
    AUTH: { DEV_TOKEN: '' },
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
      if (path === '/admin/auth/firebase/session') {
        return {
          adminUserId: 'ADMIN-1',
          email: 'admin@example.test',
          name: '後台管理員',
          role: 'admin',
          effectivePermissions: ['orders.view', 'orders.edit', 'booking-calendar.view'],
        };
      }
      if (path.startsWith('/orders')) {
        return { data: [{ id: 1 }], meta: { page: 0, totalElements: 1 } };
      }
      return {};
    },
  },
  sessionStorage,
  location: { pathname: '/admin/login.html', href: '' },
  console,
};
const context = { window, sessionStorage, console, URLSearchParams };

vm.runInNewContext(apiSource, context, { filename: 'admin-api.js' });
vm.runInNewContext(runtimeSource, context, { filename: 'admin-runtime.js' });

assert.equal(window.AdminAPI.isBackendEnabled(), true);
assert.equal(window.AdminRuntime.isSectionReady('orders'), true);
assert.equal(window.AdminRuntime.isSectionReady('reviews'), true);
assert.equal(window.AdminRuntime.isFeatureReady('reviews.manage'), true);
assert.equal(window.AdminRuntime.isFeatureReady('customers.tagPool'), true);
assert.equal(window.AdminRuntime.isFeatureReady('customers.tagAssign'), true);
assert.equal(window.AdminRuntime.isFeatureReady('customers.preferences'), true);
assert.equal(window.AdminRuntime.isFeatureReady('products.minStock'), true);
assert.equal(window.AdminRuntime.isFeatureReady('customers.defaultAddress'), true);

const matrix = window.AdminRuntime.buildPermissionMatrix([
  'orders.view',
  'orders.edit',
  'booking-calendar.view',
]);
assert.equal(matrix.orders.view, true);
assert.equal(matrix.orders.edit, true);
assert.equal(matrix['booking-calendar'].view, true);

await window.AdminRuntime.refreshBackendSession({ idToken: 'dev:g6' });
assert.equal(sessionStorage.getItem('adminId'), 'ADMIN-1');
assert.equal(sessionStorage.getItem('isSuperAdmin'), 'false');
assert.equal(JSON.parse(sessionStorage.getItem('adminPermissions')).orders.edit, true);

const orderResult = await window.AdminAPI.orders.list({ page: 0, size: 20 });
assert.equal(orderResult.data[0].id, 1);
assert.equal(orderResult.meta.totalElements, 1);

// Reviews 已就緒：應發出正式 GET（W1-06）
await window.AdminAPI.reviews.list({ page: 0, size: 20, sort: 'createdAt,desc' });
assert.equal(calls[calls.length - 1].path, '/reviews?page=0&size=20&sort=createdAt%2Cdesc');
assert.equal(calls[calls.length - 1].options.method, 'GET');

const callCountBeforeUnsupported = calls.length;
// 舊整包 savePool 在正式模式仍拒絕；請改用 tags.create／update／remove
await assert.rejects(
  window.AdminAPI.tags.savePool({ VIP: 'bg-success' }),
  error => error.code === 'ADMIN_FEATURE_NOT_READY',
);
await assert.rejects(
  window.AdminAPI.customers.create({ name: '不應送出' }),
  error => error.code === 'ADMIN_FEATURE_NOT_READY',
);
assert.equal(calls.length, callCountBeforeUnsupported);

// 標籤池 CRUD 應可發出正式請求
await window.AdminAPI.tags.list();
assert.equal(calls[calls.length - 1].path, '/customer-tags');
assert.equal(calls[calls.length - 1].options.method, 'GET');

// 最低庫存閾值應可發出正式請求
await window.AdminAPI.minStocks.list({ inventoryDomain: 'store' });
assert.equal(calls[calls.length - 1].path, '/min-stocks?inventoryDomain=store');
assert.equal(calls[calls.length - 1].options.method, 'GET');


assert.match(loginHtml, /googleLoginBtn/);
assert.match(loginHtml, /firebaseLoginStatus/);
assert.match(loginHtml, /admin-runtime\.js/);
assert.match(authSource, /\$\('#googleLoginBtn'\)/);
assert.doesNotMatch(authSource, /googleAdminLoginBtn|backendLoginPanel/);
assert.doesNotMatch(loginHtml, /permissions\.js/);
assert.doesNotMatch(loginHtml, /findEmployeeById|localStorage\.adminEmployees/);

console.log('Admin G-6 runtime, session and readiness tests passed.');
