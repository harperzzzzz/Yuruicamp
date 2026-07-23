import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('../storefront/js/pages/product-detail.js', import.meta.url), 'utf8');

let addCalls = 0;
let lastQuantity = 0;
const window = {
  AppState: {
    cart: [{ id: 'P001', variantId: 'V001', quantity: 2 }],
  },
  buildCartLineFromProduct: (product, variant) => ({
    id: product.id,
    variantId: variant.id,
    name: product.name,
  }),
  findProductVariant: () => ({ id: 'V001' }),
  addToCart: (_cartLine, quantity) => {
    addCalls += 1;
    lastQuantity = quantity;
  },
};

const document = {
  readyState: 'loading',
  addEventListener() {},
  getElementById: (id) => (id === 'qtyInput' ? { value: '3' } : null),
  querySelector: () => null,
};

const context = vm.createContext({
  console,
  document,
  Number,
  parseInt,
  String,
  URLSearchParams,
  window,
});

vm.runInContext(source, context, { filename: 'product-detail.js' });

const product = { id: 'P001', name: '測試帳篷' };

assert.equal(context._addSelectedProductToCart(product, true), false);
assert.equal(addCalls, 0);
assert.equal(window.AppState.cart[0].quantity, 2);

window.AppState.cart = [];
assert.equal(context._addSelectedProductToCart(product, true), true);
assert.equal(addCalls, 1);
assert.equal(lastQuantity, 3);

window.AppState.cart = [{ id: 'P001', variantId: 'V001', quantity: 2 }];
assert.equal(context._addSelectedProductToCart(product), true);
assert.equal(addCalls, 2);

assert(source.includes('_addSelectedProductToCart(product, true)'));

console.log('Product detail buy-now cart checks passed');
