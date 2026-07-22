import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const rootDir = dirname(dirname(fileURLToPath(import.meta.url)));
const source = readFileSync(join(rootDir, 'admin/js/admin-api.js'), 'utf8');
const calls = [];
const window = {
  AppConfig: { API_BASE_URL: 'http://localhost:8080/api' },
  ApiClient: {
    _restRequest: async (path, options) => {
      calls.push({ path, options });
      return {};
    },
  },
  console,
};

vm.runInNewContext(source, { window, console, URLSearchParams }, { filename: 'admin-api.js' });
window.AdminAPI.configure({ useBackend: true });

await window.AdminAPI.customers.list({ page: 2, size: 20, status: 'active', sort: 'totalSpent,desc' });
await window.AdminAPI.customers.getById('C / 1');
await window.AdminAPI.customers.update('C-1', { phone: '0912345678' });
await window.AdminAPI.customers.suspend('C-1');
await window.AdminAPI.customers.reactivate('C-1');

assert.deepEqual(
  calls.map((call) => [call.options.method, call.path]),
  [
    ['GET', '/customers?page=2&size=20&status=active&sort=totalSpent%2Cdesc'],
    ['GET', '/customers/C%20%2F%201'],
    ['PATCH', '/customers/C-1'],
    ['POST', '/customers/C-1/suspend'],
    ['POST', '/customers/C-1/reactivate'],
  ],
);
assert.equal(calls.every((call) => call.options.auth === 'required'), true);
assert.equal(calls.some((call) => call.path.startsWith('/api/')), false);

console.log('Admin Customers facade tests passed.');
