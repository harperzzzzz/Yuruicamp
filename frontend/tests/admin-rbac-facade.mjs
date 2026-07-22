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
      return { id: 'ADMIN-1' };
    },
  },
  console,
};

vm.runInNewContext(source, { window, console }, { filename: 'admin-api.js' });
window.AdminAPI.configure({ useBackend: true });

await window.AdminAPI.users.list(0, 50);
await window.AdminAPI.users.getById('ADMIN / 1');
await window.AdminAPI.users.create({ name: '管理員', email: 'admin@example.com', role: 'operator' });
await window.AdminAPI.users.update('ADMIN-1', { active: false });
await window.AdminAPI.users.updatePermissions('ADMIN-1', { 'orders.view': true });
await window.AdminAPI.permissions.list();

assert.deepEqual(
  calls.map((call) => [call.options.method, call.path]),
  [
    ['GET', '/users?page=0&size=50'],
    ['GET', '/users/ADMIN%20%2F%201'],
    ['POST', '/users'],
    ['PATCH', '/users/ADMIN-1'],
    ['PUT', '/users/ADMIN-1/permissions'],
    ['GET', '/permissions'],
  ],
);
assert.equal(calls.every((call) => call.options.auth === 'required'), true);
assert.equal(calls.some((call) => call.path.startsWith('/api/')), false);

console.log('Admin RBAC facade tests passed.');
