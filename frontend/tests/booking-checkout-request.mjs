import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const rootDir = dirname(dirname(fileURLToPath(import.meta.url)));
const cartSource = readFileSync(join(rootDir, 'booking/js/booking-cart.js'), 'utf8');
const checkoutSource = readFileSync(join(rootDir, 'booking/js/booking-checkout.js'), 'utf8');
const cartPageSource = readFileSync(join(rootDir, 'booking/pages/booking-cart.html'), 'utf8');
const checkoutPageSource = readFileSync(join(rootDir, 'booking/pages/booking-checkout.html'), 'utf8');
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
  removeItem: (key) => sessionValues.delete(key),
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
    cancelBooking: async () => ({}),
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

vm.runInContext(cartSource, context, { filename: 'booking-cart.js' });

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

context.bookingCart = cart;
await context.prepareBookingCheckoutSession(false);
assert.equal(createCalls, 1);
assert.equal(JSON.parse(sessionStorage.getItem('lastCheckoutBooking')).bookingId, 'B001');
assert.equal(
  sessionStorage.getItem('lastCheckoutBookingFingerprint'),
  context.getBookingCartFingerprint(cart)
);
assert.equal(
  context.getBookingSessionErrorMessage({ code: 'RENTAL_STOCK_INSUFFICIENT' }),
  '商品剩餘數量不足請重新調整數量'
);
assert.equal(context.isBookingSessionExpired({ checkoutExpiresAt: '2000-01-01T00:00:00Z' }), true);

assert(cartPageSource.includes('id="bookingCheckoutSessionStatus"'));
assert(cartPageSource.includes('aria-live="polite"'));
assert(cartPageSource.includes('沒有預約營地、租賃裝備請前往預約首頁預約。'));
assert(cartSource.includes('BookingAPI.createBooking'));
assert(cartSource.includes('prepareBookingCheckoutSession(false)'));
assert(cartSource.includes('class="quantityValue quantityValueBooking quantityInputBooking"'));
assert(cartSource.includes("on('change', '.quantityInputBooking'"));
assert.match(cartSource, /localStorage\.removeItem\('bookingCart'\)[\s\S]*clearBookingIdempotencyKey\(\)/);
assert(!checkoutSource.includes('BookingAPI.createBooking'));

assert(!checkoutPageSource.includes('id="creditCardSection"'));
assert(!checkoutPageSource.includes('id="cardNumber"'));
assert(!checkoutPageSource.includes('id="cardExpiry"'));
assert(!checkoutPageSource.includes('id="cardCvv"'));
assert(checkoutPageSource.includes('id="confirmPayBtn"'));
assert(checkoutPageSource.includes('前往 ECPay'));
assert.match(checkoutPageSource, /class="checkoutPanel checkoutPanelBooking isOpen" id="panelDetails"/);
assert.match(checkoutPageSource, /class="checkoutPanel checkoutPanelBooking isOpen" id="panelContact"/);
assert.match(checkoutPageSource, /class="checkoutPanel checkoutPanelBooking isOpen" id="panelPayment"/);
assert(!checkoutSource.includes('tryAutoFillContactFields'));
assert(checkoutSource.includes('BookingAPI.createEcpayForm'));
assert(checkoutSource.includes('submitEcpayForm'));
assert(checkoutSource.includes('readPreparedBookingSession'));

console.log('Booking Checkout Request checks passed');
