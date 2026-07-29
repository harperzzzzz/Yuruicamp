import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const rootDir = dirname(dirname(fileURLToPath(import.meta.url)));
const apiSource = readFileSync(join(rootDir, 'admin/js/admin-api.js'), 'utf8');
const discountsSource = readFileSync(join(rootDir, 'admin/js/discounts.js'), 'utf8');
const closuresSource = readFileSync(join(rootDir, 'admin/js/booking-calendar.js'), 'utf8');
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

vm.runInNewContext(apiSource, { window, console, URLSearchParams }, { filename: 'admin-api.js' });
window.AdminAPI.configure({ useBackend: true });

await window.AdminAPI.coupons.list({ page: 1, size: 20, status: 'active' });
await window.AdminAPI.coupons.getById(7);
await window.AdminAPI.coupons.create({ code: 'SUMMER26' });
await window.AdminAPI.coupons.update(7, { name: '夏日優惠' });
await window.AdminAPI.coupons.updateStatus(7, 'disabled');
await window.AdminAPI.coupons.remove(7);
await window.AdminAPI.closures.list({ page: 0, size: 100, closureType: 'weekly' });
await window.AdminAPI.closures.getById(9);
await window.AdminAPI.closures.create({ campgroundId: 1, closureType: 'weekly' });
await window.AdminAPI.closures.update(9, { reason: '設備維護' });
await window.AdminAPI.closures.remove(9);

assert.deepEqual(
  calls.map((call) => [call.options.method, call.path]),
  [
    ['GET', '/coupons?page=1&size=20&status=active'],
    ['GET', '/coupons/7'],
    ['POST', '/coupons'],
    ['PATCH', '/coupons/7'],
    ['PATCH', '/coupons/7'],
    ['DELETE', '/coupons/7'],
    ['GET', '/campground-closures?page=0&size=100&closureType=weekly'],
    ['GET', '/campground-closures/9'],
    ['POST', '/campground-closures'],
    ['PATCH', '/campground-closures/9'],
    ['DELETE', '/campground-closures/9'],
  ],
);
assert.equal(calls.every((call) => call.options.auth === 'required'), true);
assert.equal(JSON.stringify(calls[4].options.body), JSON.stringify({ status: 'disabled' }));

const discountContext = { window: {}, console, Date, Intl };
vm.runInNewContext(discountsSource, discountContext, { filename: 'discounts.js' });
const coupon = discountContext.mapAdminCouponResponse({
  id: 7,
  code: 'SUMMER26',
  name: '夏日優惠',
  discountType: 'percent',
  discountValue: '15.00',
  minimumAmount: '1000.00',
  issueQuantity: 100,
  claimedQuantity: 3,
  validFrom: '2026-08-01T00:00:00Z',
  validUntil: '2026-09-01T00:00:00Z',
  status: 'active',
  category: 'promotion',
});
assert.equal(coupon.type, 'percent');
assert.equal(coupon.used, 3);
assert.equal(coupon.quantity, 100);

const couponRequest = discountContext.buildAdminCouponRequest({
  code: 'summer26',
  name: '夏日優惠',
  category: 'promotion',
  type: 'percent',
  discount: 15,
  minAmount: 1000,
  quantity: 100,
  startDate: '2026-08-01',
  endDate: '2026-09-01',
  status: 'active',
  used: 99,
});
assert.equal(couponRequest.code, 'SUMMER26');
assert.equal(couponRequest.discountType, 'percent');
assert.equal('used' in couponRequest, false);
assert.equal('claimedQuantity' in couponRequest, false);
assert.match(discountsSource, /AdminAPI\.coupons\.create\(buildAdminCouponRequest\(newCoupon\)\)[\s\S]*?applyCreated\(mapAdminCouponResponse/);

const closureContext = { window: {}, console, Date };
vm.runInNewContext(closuresSource, closureContext, { filename: 'booking-calendar.js' });
const closure = closureContext.mapAdminClosureResponse({
  id: 9,
  campgroundId: 'C001',
  campgroundName: '星空營區',
  closureType: 'weekly',
  weekday: 2,
  effectiveFrom: '2026-08-01',
  effectiveTo: '2026-12-31',
  reason: '每週保養',
});
assert.equal(closure.type, 'weekly');
assert.equal(closure.dayOfWeek, 2);
assert.deepEqual(
  JSON.parse(JSON.stringify(closureContext.buildAdminClosureRequest(closure))),
  {
    campgroundId: 'C001',
    closureType: 'weekly',
    startDate: null,
    endDate: null,
    weekday: 2,
    effectiveFrom: '2026-08-01',
    effectiveTo: '2026-12-31',
    reason: '每週保養',
  },
);
assert.match(closuresSource, /AdminAPI\.closures\.create\(buildAdminClosureRequest\(item\)\)/);
assert.match(closuresSource, /AdminAPI\.closures\.remove\(closureId\)[\s\S]*?applyClosureList/);

console.log('Admin G-4 coupon and campground closure facade tests passed.');
