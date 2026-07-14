// ========================================
// DataPaths — 統一 mock JSON 路徑（根目錄絕對路徑）
// ========================================
// 全站請透過 window.DataPaths 或 API 層讀取，勿在各頁硬編碼 ../data

(function (global) {
  'use strict';

  var BASE = '/data';

  global.DataPaths = {
    products: BASE + '/catalog/products.json',
    campgrounds: BASE + '/catalog/campgrounds.json',
    campEquipment: BASE + '/catalog/camp-equipment.json',

    orders: BASE + '/commerce/orders.json',
    campBookings: BASE + '/commerce/camp-bookings.json',

    customers: BASE + '/customers/customers.json',
    preferenceOptions: BASE + '/customers/preference-options.json',
    customerPreferences: BASE + '/customers/customer-preferences.json',
    customerShippingAddresses: BASE + '/customers/customer-shipping-addresses.json',
    customerTags: BASE + '/customers/customer-tags.json',
    customerTagAssignments: BASE + '/customers/customer-tag-assignments.json',

    articles: BASE + '/marketing/articles.json',
    branches: BASE + '/marketing/branches.json',
    brands: BASE + '/marketing/brands.json',

    coupons: BASE + '/promotions/coupons.json',

    reviews: BASE + '/admin/reviews.json',
    movement: BASE + '/admin/movement.json',
    minStock: BASE + '/admin/min-stock.json',
    rentalSkus: BASE + '/admin/rental-skus.json',
    bookingPolicy: BASE + '/admin/booking-policy.json',
    zoneBlocks: BASE + '/admin/zone-blocks.json',
    campgroundClosures: BASE + '/admin/campground-closures.json',
  };
})(typeof window !== 'undefined' ? window : this);
