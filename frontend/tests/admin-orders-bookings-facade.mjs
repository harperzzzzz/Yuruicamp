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

await window.AdminAPI.orders.list({ page: 1, status: ['unshipped', 'shipped'], sort: 'placedAt,desc' });
await window.AdminAPI.orders.getById('O / 1');
await window.AdminAPI.orders.ship('O-1', {});
await window.AdminAPI.orders.complete('O-1', {});
await window.AdminAPI.bookings.list({ page: 0, hasRental: true, sort: 'createdAt,desc' });
await window.AdminAPI.bookings.getById('B / 1');
await window.AdminAPI.bookings.confirm('B-1', {});
await window.AdminAPI.bookings.complete('B-1', {});

assert.deepEqual(
  calls.map((call) => [call.options.method, call.path]),
  [
    ['GET', '/orders?page=1&status=unshipped&status=shipped&sort=placedAt%2Cdesc'],
    ['GET', '/orders/O%20%2F%201'],
    ['POST', '/orders/O-1/ship'],
    ['POST', '/orders/O-1/complete'],
    ['GET', '/bookings?page=0&hasRental=true&sort=createdAt%2Cdesc'],
    ['GET', '/bookings/B%20%2F%201'],
    ['POST', '/bookings/B-1/confirm'],
    ['POST', '/bookings/B-1/complete'],
  ],
);
assert.equal(calls.every((call) => call.options.auth === 'required'), true);
assert.equal(calls[0].options.includeMeta, true);
assert.equal(calls[4].options.includeMeta, true);

console.log('Admin Orders and Bookings facade tests passed.');
