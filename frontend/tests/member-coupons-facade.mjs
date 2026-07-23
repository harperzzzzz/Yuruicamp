import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const facadeSource = readFileSync(
  new URL('../storefront/js/api-mock.js', import.meta.url),
  'utf8',
);
const memberCenterSource = readFileSync(
  new URL('../storefront/js/components/member-center.js', import.meta.url),
  'utf8',
);
const calls = [];

class TestApiRequestError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const window = {
  AppConfig: {
    USE_MOCK_API: false,
    API_BASE_URL: 'http://localhost:8080/api',
  },
  ApiRequestError: TestApiRequestError,
  ApiClient: {
    _restRequest: async (path, options) => {
      calls.push({ path, options });

      return [
        {
          id: 101,
          couponId: 1,
          status: 'claimed',
          claimedAt: '2026-07-23T01:00:00Z',
          consumedAt: null,
          coupon: {
            id: 1,
            code: 'YURUIKAMP20',
            name: '悠露營活動折抵 200',
            discountType: 'fixed',
            discountValue: '200.00',
            minimumAmount: '0.00',
            category: 'promotion',
            status: 'active',
            validFrom: '2026-06-01T00:00:00+08:00',
            validUntil: '2026-08-31T23:59:00+08:00',
          },
        },
        {
          id: 102,
          couponId: 3,
          status: 'consumed',
          claimedAt: '2026-07-20T01:00:00Z',
          consumedAt: '2026-07-22T01:00:00Z',
          coupon: {
            id: 3,
            code: 'SUMMER100',
            name: '夏日露營折抵 100',
            discountType: 'fixed',
            discountValue: '100.00',
            minimumAmount: '0.00',
            category: 'promotion',
            status: 'active',
            validFrom: '2026-07-01T00:00:00+08:00',
            validUntil: '2026-09-30T23:59:00+08:00',
          },
        },
      ];
    },
  },
};
const localStorage = {
  getItem: () => null,
  setItem() {},
  removeItem() {},
};

vm.runInNewContext(
  facadeSource,
  {
    window,
    localStorage,
    fetch: async () => {
      throw new Error('Backend member coupons must not read static JSON');
    },
    URLSearchParams,
    CustomEvent: class CustomEvent {},
    console,
  },
  { filename: 'api-mock.js' },
);

const cards = await window.API.coupons.getMemberCenter('U-IGNORED');

assert.deepEqual(
  calls.map((call) => ({
    path: call.path,
    auth: call.options.auth,
  })),
  [{ path: '/me/coupons', auth: 'required' }],
);
assert.deepEqual(
  JSON.parse(JSON.stringify(cards)),
  [
    {
      id: 101,
      couponId: 1,
      claimStatus: 'claimed',
      code: 'YURUIKAMP20',
      name: '悠露營活動折抵 200',
      type: 'fixed',
      discount: 200,
      minOrder: 0,
      category: 'promotion',
      startDate: '2026-06-01T00:00:00+08:00',
      endDate: '2026-08-31T23:59:00+08:00',
      expiry: '2026-08-31',
      claimedAt: '2026-07-23T01:00:00Z',
      consumedAt: null,
      used: false,
    },
    {
      id: 102,
      couponId: 3,
      claimStatus: 'consumed',
      code: 'SUMMER100',
      name: '夏日露營折抵 100',
      type: 'fixed',
      discount: 100,
      minOrder: 0,
      category: 'promotion',
      startDate: '2026-07-01T00:00:00+08:00',
      endDate: '2026-09-30T23:59:00+08:00',
      expiry: '2026-09-30',
      claimedAt: '2026-07-20T01:00:00Z',
      consumedAt: '2026-07-22T01:00:00Z',
      used: true,
    },
  ],
);
assert.match(memberCenterSource, /window\.API\.coupons\.getMemberCenter\(uid\)/);
assert.doesNotMatch(memberCenterSource, /window\.API\.coupons\.getAvailable\(uid\)/);

console.log('Member coupon facade checks passed');
