import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const rootDir = dirname(dirname(fileURLToPath(import.meta.url)));
const source = readFileSync(join(rootDir, 'storefront/js/booking-api.js'), 'utf8');
const calls = [];
const writes = [];

const responses = new Map([
  ['/booking/campgrounds', [{ id: 'C002', name: '測試營區', region: '北部' }]],
  [
    '/booking/campgrounds/C002',
    {
      id: 'C002',
      name: '測試營區',
      region: '北部',
      description: '測試',
      zones: [
        {
          id: 'Z001',
          type: '草地區',
          capacityPerSite: 4,
          priceWeekday: '1000.00',
          priceHoliday: '1500.00',
          totalSites: 3,
        },
      ],
    },
  ],
  [
    '/booking/equipment?campgroundId=C002',
    [
      {
        id: 'RL001',
        rentalSkuVariantId: 'RSV001',
        campgroundId: 'C002',
        name: '桌椅組',
        pricePerDayWeekday: '100.00',
        pricePerDayHoliday: '150.00',
      },
    ],
  ],
  ['/booking/policy', { bookingWindowDays: 90, advanceDays: 1 }],
  ['/booking/closures', []],
  [
    '/booking/check-availability',
    {
      available: true,
      reasons: [],
      zones: [{ zoneId: 'Z001', requested: 1, availableQuantity: 2 }],
    },
  ],
  [
    '/booking/bookings?page=0&size=20',
    {
      data: [
        {
          bookingId: 'B001',
          status: 'pending',
          paymentStatus: 'unpaid',
          campgroundName: '測試營區',
          checkIn: '2026-08-01',
          checkOut: '2026-08-02',
          finalAmount: '1000.00',
        },
      ],
      meta: { page: 0, size: 20, totalElements: 1, totalPages: 1 },
    },
  ],
  [
    '/booking/bookings/B001',
    {
      bookingId: 'B001',
      status: 'pending',
      paymentStatus: 'unpaid',
      campgroundName: '測試營區',
      pricing: { zoneTotal: '1000.00', rentalTotal: '0.00', discount: '0.00', finalAmount: '1000.00' },
      zones: [],
      rentals: [],
    },
  ],
  [
    '/booking/checkout/sessions',
    {
      bookingId: 'B001',
      status: 'pending',
      paymentStatus: 'unpaid',
      checkoutExpiresAt: '2026-08-01T00:15:00Z',
      pricing: { finalAmount: '1000.00' },
    },
  ],
  ['/booking/checkout/sessions/B001', { bookingId: 'B001', status: 'pending' }],
  ['/booking/checkout/sessions/B001/cancel', { bookingId: 'B001', status: 'cancelled' }],
]);

const window = {
  AppConfig: {
    USE_MOCK_API: false,
    API_BASE_URL: 'http://localhost:8080/api',
  },
  BookingAvailability: {
    normalizePolicy: (policy) => policy,
    getBookingWindow: () => ({ minDate: '2026-07-22', maxDate: '2026-10-19' }),
  },
  ApiClient: {
    _restRequest: async (path, options) => {
      calls.push({ path, options });
      const response = responses.get(path);
      if (options?.includeMeta) return response;
      return response;
    },
  },
};

const localStorage = {
  getItem: () => null,
  setItem: (key, value) => writes.push({ key, value }),
};

vm.runInNewContext(
  source,
  {
    window,
    localStorage,
    fetch: async () => {
      throw new Error('Backend facade must not fetch Mock JSON');
    },
    URLSearchParams,
    Date,
    Number,
    Math,
    JSON,
    Promise,
    console,
  },
  { filename: 'booking-api.js' }
);

const api = window.BookingAPI;
const campgrounds = await api.getCampgrounds();
const equipment = await api.getEquipment('C002');
await api.getPolicy();
await api.getClosures();
await api.getAvailability({
  campgroundId: 'C002',
  checkIn: '2026-08-01',
  checkOut: '2026-08-02',
  zones: [{ zoneId: 'Z001', quantity: 1 }],
});
const bookings = await api.getBookings('client-side-id-must-not-be-sent');
await api.getBookingById('B001');
await api.getCheckoutSession('B001');
await api.createBooking({
  campgroundId: 'C002',
  checkIn: '2026-08-01',
  checkOut: '2026-08-02',
  guestCount: 2,
  zones: [{ zoneId: 'Z001', quantity: 1 }],
  rentals: [],
  couponClaimId: null,
  paymentMethod: 'ecpay-credit',
  idempotencyKey: 'booking-test-key',
});
await api.cancelBooking('B001');

assert.equal(campgrounds[0].campgroundId, 'C002');
assert.equal(campgrounds[0].zones[0].zoneId, 'Z001');
assert.equal(campgrounds[0].zones[0].priceWeekday, 1000);
assert.equal(equipment[0].rentalListingId, 'RL001');
assert.equal(equipment[0].rentalSkuVariantId, 'RSV001');
assert.equal(equipment[0].stock, null);
assert.equal(bookings[0].id, 'B001');
assert.deepEqual(bookings.meta, { page: 0, size: 20, totalElements: 1, totalPages: 1 });
assert.equal(writes.length, 0, 'Backend mode must not write mockBookings');

const availabilityCall = calls.find((call) => call.path === '/booking/check-availability');
assert.equal(availabilityCall.options.method, 'POST');
assert.equal(availabilityCall.options.auth, 'none');
assert.deepEqual(availabilityCall.options.body.zones, [{ zoneId: 'Z001', quantity: 1 }]);

const memberCalls = calls.filter(
  (call) => call.path.startsWith('/booking/bookings') || call.path.startsWith('/booking/checkout/sessions')
);
assert(memberCalls.every((call) => call.options.auth === 'required'));
assert(calls.every((call) => !call.path.startsWith('/api/')));
assert(!calls.some((call) => call.path.includes('customerId=')));
assert(!calls.some((call) => call.path.includes('zone-blocks')));

console.log('Booking API facade checks passed');
