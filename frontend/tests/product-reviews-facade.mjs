import assert from 'node:assert/strict';
import fs from 'node:fs';

const facade = fs.readFileSync(new URL('../storefront/js/api-mock.js', import.meta.url), 'utf8');
const page = fs.readFileSync(new URL('../storefront/js/pages/product-detail.js', import.meta.url), 'utf8');

assert.match(facade, /\/products\/\$\{encodeURIComponent\(productId\)\}\/reviews/);
assert.match(facade, /auth: 'none', includeMeta: true/);
assert.match(facade, /sort === 'highest'/);
assert.match(facade, /sort === 'lowest'/);
assert.match(facade, /query\.set\('rating', rating\)/);
assert.match(facade, /hasPhotos/);
assert.match(facade, /ratingCounts/);
assert.match(page, /_renderReviewSummary\(result\.summary/);
assert.match(page, /summary\.averageRating/);
assert.match(page, /summary\.totalCount/);
assert.match(page, /reviewRatingFilter/);
assert.match(page, /reviewPhotoFilter/);
assert.match(page, /reviewLoadMoreBtn/);
assert.match(page, /_renderReviewDistribution|_renderReviewSummary/);
assert.match(page, /reviewVerifiedBadge/);
assert.match(page, /展開全文/);
assert.match(page, /重新載入/);

console.log('Product reviews facade checks passed');
