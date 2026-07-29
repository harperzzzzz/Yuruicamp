import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const source = readFileSync(new URL('../storefront/js/api-mock.js', import.meta.url), 'utf8');

const reviewsSection = source.slice(source.indexOf('  reviews: {'), source.indexOf('  articles: {'));

assert(reviewsSection.includes("window.ApiClient._restRequest('/me/reviews', { auth: 'required' })"));
assert(reviewsSection.includes("method: 'POST'"));
assert(reviewsSection.includes("auth: 'required'"));
assert(reviewsSection.includes('orderItemId: payload.orderItemId'));
assert(reviewsSection.includes('rating: payload.rating'));
assert(!reviewsSection.includes('customerId: payload.customerId'));

console.log('Member reviews facade checks passed');
