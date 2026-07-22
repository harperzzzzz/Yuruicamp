import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const rootDir = dirname(dirname(fileURLToPath(import.meta.url)));
const source = readFileSync(join(rootDir, 'booking/js/booking-checkout.js'), 'utf8');
const sessionValues = new Map();
let createCalls = 0;

const chain = new Proxy(
  {},
  {
    get: () => () => chain,
  }
);
const jquery = () => chain;
jquery.fn = {};

const sessionStorage = {
  getItem: (key) => sessionValues.get(key) || null,
  setItem: (key, value) => sessionValues.set(key, value),
};

const window = {
  crypto: {
    randomUUID: () => 'c8475d58-52fa-4df5-9c99-125468651ccc',
  },
  BookingAPI: {
    createBooking: async (request) => {
      createCalls += 1;
      return { bookingId: 'B001', request };
    },
  },
  addEventListener: () => {},
};

const context = vm.createContext({
  window,
  document: {},
  localStorage: { removeItem: () => {} },
  sessionStorage,
  $: jquery,
  console,
  Date,
  Math,
  JSON,
  Number,
  String,
  Promise,
});

vm.runInContext(source, context, { filename: 'booking-checkout.js' });

const cart = {
  bookingInfo: {
    campgroundId: 'C002',
    campgroundName: '不可送出的顯示快照',
    region: '北部',
    checkIn: '2026-08-01',
    checkOut: '2026-08-03',
    guestCount: 2,
  },
  selectedZones: [{ zoneId: 'Z001', zoneType: '草地區', quantity: 1, subtotal: 2000 }],
  selectedRentals: [
    {
      equipmentId: 'RL001',
      rentalListingId: 'RL001',
      rentalSkuVariantId: 'RSV001',
      name: '不可送出的裝備快照',
      quantity: 2,
      subtotal: 400,
    },
  ],
  summary: { zoneTotal: 2000, rentalTotal: 400, finalAmount: 2400 },
};

const request = context.buildBookingPayload(cart, 'ecpay-credit');
assert.deepEqual(
  Object.keys(request).sort(),
  [
    'campgroundId',
    'checkIn',
    'checkOut',
    'guestCount',
    'zones',
    'rentals',
    'couponClaimId',
    'paymentMethod',
    'idempotencyKey',
  ].sort()
);
assert.deepEqual(JSON.parse(JSON.stringify(request.zones)), [{ zoneId: 'Z001', quantity: 1 }]);
assert.deepEqual(JSON.parse(JSON.stringify(request.rentals)), [
  {
    rentalListingId: 'RL001',
    rentalSkuVariantId: 'RSV001',
    quantity: 2,
  },
]);
assert.equal(request.paymentMethod, 'ecpay-credit');
assert.equal(request.idempotencyKey, 'c8475d58-52fa-4df5-9c99-125468651ccc');

const forbiddenFields = [
  'customerId',
  'campgroundName',
  'region',
  'zoneType',
  'name',
  'subtotal',
  'summary',
  'finalAmount',
  'status',
  'paymentStatus',
  'paid',
];
const requestText = JSON.stringify(request);
for (const field of forbiddenFields) {
  assert(!requestText.includes(`"${field}"`), `Booking Request must not contain ${field}`);
}

const [first, second] = await Promise.all([
  context.createBookingOnce(request, cart),
  context.createBookingOnce(request, cart),
]);
assert.equal(createCalls, 1);
assert.equal(first.bookingId, second.bookingId);

console.log('Booking Checkout Request checks passed');
