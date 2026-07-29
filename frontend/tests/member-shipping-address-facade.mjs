import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const rootDir = dirname(dirname(fileURLToPath(import.meta.url)));
const source = readFileSync(join(rootDir, 'storefront/js/api-mock.js'), 'utf8');
const calls = [];
const window = {
  AppConfig: { USE_MOCK_API: false, CACHE_DURATION: 3600000 },
  ApiClient: {
    _restRequest: async (path, options = {}) => {
      calls.push({ path, options });
      if (options.method === 'PUT') {
        return { id: 1, ...options.body };
      }
      return {
        id: 1,
        recipientName: '王小明',
        postalCode: '701',
        city: '臺南市',
        district: '東區',
        addressLine: '長榮路二段200號',
        phone: '0912345678',
        email: 'member@example.test',
      };
    },
  },
};
const context = vm.createContext({
  window,
  localStorage: { getItem: () => null, setItem() {}, removeItem() {} },
  sessionStorage: { getItem: () => null, setItem() {}, removeItem() {} },
  fetch: async () => ({ ok: true, json: async () => [] }),
  console,
  CustomEvent: class CustomEvent {},
  URLSearchParams,
  crypto: { randomUUID: () => 'test-id' },
  setTimeout,
  clearTimeout,
});

vm.runInContext(source, context);

const loaded = await window.API.shippingAddresses.getDefault();
assert.equal(loaded.lastName, '王');
assert.equal(loaded.firstName, '小明');
assert.equal(calls[0].path, '/me/shipping-address');
assert.equal(calls[0].options.auth, 'required');

await window.API.shippingAddresses.saveDefault({
  lastName: '王',
  firstName: '小明',
  postalCode: '701',
  city: '臺南市',
  district: '東區',
  township: '',
  addressLine1: '長榮路二段200號',
  addressLine2: '3樓',
  phone: '0912-345-678',
  email: 'member@example.test',
});

assert.equal(calls[1].path, '/me/shipping-address');
assert.equal(calls[1].options.method, 'PUT');
assert.equal(calls[1].options.auth, 'required');
assert.equal(calls[1].options.body.recipientName, '王小明');
assert.equal(calls[1].options.body.addressLine, '長榮路二段200號 3樓');
assert.equal(calls[1].options.body.phone, '0912345678');

// 新 Firebase 會員不在靜態 customers JSON 時，Mock 儲存仍只依目前登入會員運作。
window.AppConfig.USE_MOCK_API = true;
window.AppState = { currentUser: { id: 'NEW-FIREBASE-CUSTOMER' } };
window.saveAppState = () => {};
const mockSaved = await window.API.shippingAddresses.saveDefault({
  lastName: '林',
  firstName: '小露',
  postalCode: '100',
  city: '臺北市',
  district: '中正區',
  addressLine1: '忠孝西路一段1號',
  phone: '0987654321',
  email: 'new@example.test',
});
assert.equal(mockSaved.lastName, '林');
assert.equal(window.AppState.currentUser.shippingAddress.firstName, '小露');

console.log('Member shipping address facade checks passed');
