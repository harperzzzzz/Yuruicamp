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
await window.AdminAPI.customers.replaceTags('C-1', [1, 3]);
await window.AdminAPI.customers.updateDefaultShippingAddress('C-1', {
  recipientName: '王小華',
  postalCode: '100',
  city: '臺北市',
  district: '中正區',
  addressLine: '忠孝西路一段 1 號',
  phone: '0912345678',
});
await window.AdminAPI.customers.replacePreferences('C-1', [2, 5, 9]);
await window.AdminAPI.preferenceOptions.list();

assert.deepEqual(
  calls.map((call) => [call.options.method, call.path]),
  [
    ['GET', '/customers?page=2&size=20&status=active&sort=totalSpent%2Cdesc'],
    ['GET', '/customers/C%20%2F%201'],
    ['PATCH', '/customers/C-1'],
    ['POST', '/customers/C-1/suspend'],
    ['POST', '/customers/C-1/reactivate'],
    ['PUT', '/customers/C-1/tags'],
    ['PUT', '/customers/C-1/default-shipping-address'],
    ['PUT', '/customers/C-1/preferences'],
    ['GET', '/preference-options'],
  ],
);
assert.equal(calls.every((call) => call.options.auth === 'required'), true);
assert.equal(calls.some((call) => call.path.startsWith('/api/')), false);
assert.deepEqual(calls[5].options.body.tagIds, [1, 3]);
assert.equal(calls[6].options.body.recipientName, '王小華');
assert.equal(calls[6].options.body.phone, '0912345678');
assert.deepEqual(calls[7].options.body.optionIds, [2, 5, 9]);

console.log('Admin Customers facade tests passed.');
