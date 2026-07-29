import assert from 'node:assert/strict';
import fs from 'node:fs';

const source = fs.readFileSync(new URL('../storefront/js/pages/product-detail.js', import.meta.url), 'utf8');
const start = source.indexOf('function _renderReviews(');
const end = source.indexOf('/**', start);
const renderReviews = source.slice(start, end);

assert.ok(start >= 0 && end > start, 'review renderer must exist');
assert.doesNotMatch(renderReviews, /\.innerHTML\s*=/, 'review API data must not enter innerHTML');
assert.match(renderReviews, /container\.replaceChildren\(\)/);
assert.match(renderReviews, /author\.textContent = buyerName/);
assert.match(renderReviews, /comment\.textContent = String\(review\.comment/);
assert.match(renderReviews, /date\.textContent = String\(review\.createdAt/);
assert.match(renderReviews, /stars\.textContent = _renderStars/);

console.log('Product review XSS checks passed');
