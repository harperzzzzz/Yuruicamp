import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const rootDir = dirname(dirname(fileURLToPath(import.meta.url)));
const mainRuntimeOrder = ['config.js', 'storage.js', 'state.js', 'formatters.js', 'validators.js', 'cart-service.js'];

function readProjectFile(relativePath) {
  return readFileSync(join(rootDir, relativePath), 'utf8');
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function assertFileExists(relativePath) {
  assert(existsSync(join(rootDir, relativePath)), `Missing required file: ${relativePath}`);
}

function assertRuntimeScriptOrder(relativePath) {
  const html = readProjectFile(relativePath);
  const positions = mainRuntimeOrder.map((fileName) => html.indexOf(fileName));
  assert(positions.every((index) => index !== -1), `${relativePath} is missing split runtime scripts`);
  positions.slice(1).forEach((position, index) => {
    assert(position > positions[index], `${relativePath} runtime scripts are out of order`);
  });
}

function getHtmlPages(relativeDir) {
  return readdirSync(join(rootDir, relativeDir))
    .filter((fileName) => fileName.endsWith('.html'))
    .map((fileName) => `${relativeDir}/${fileName}`);
}

function assertHeaderRoot(pagePath, expectedContext) {
  const html = readProjectFile(pagePath);
  const headerRootCount = (html.match(/id="header"/g) || []).length;
  const bookingHeaderCount = (html.match(/id="booking-header"/g) || []).length;
  const contextMatch = html.match(/<div id="header"[^>]*data-header-context="([^"]+)"/);
  const themeHeaderLoaded = html.includes('theme-header.css');

  assert(headerRootCount === 1, `${pagePath} should have exactly one #header root`);
  assert(bookingHeaderCount === 0, `${pagePath} should not contain #booking-header`);
  assert(contextMatch, `${pagePath} should declare data-header-context`);
  assert(['shop', 'camp'].includes(contextMatch[1]), `${pagePath} context must be shop/camp`);
  assert(contextMatch[1] === expectedContext, `${pagePath} should use ${expectedContext} context`);
  assert(themeHeaderLoaded, `${pagePath} should load theme-header.css`);
}

[
  'package.json',
  'vite.config.js',
  'eslint.config.js',
  'stylelint.config.cjs',
  '.prettierrc.json',
  'src/styles.js',
  'js/storage.js',
  'js/state.js',
  'js/formatters.js',
  'js/validators.js',
  'js/cart-service.js',
  'css/theme/theme-header.css',
].forEach(assertFileExists);

const shopPages = getHtmlPages('pages');
const campPages = getHtmlPages('booking/pages');

shopPages.forEach((pagePath) => {
  assertRuntimeScriptOrder(pagePath);
  assertHeaderRoot(pagePath, 'shop');
});

campPages.forEach((pagePath) => {
  assertHeaderRoot(pagePath, 'camp');
});

const headerPartial = readProjectFile('components/header.partial');
assert((headerPartial.match(/data-layout-part="shared-site-header"/g) || []).length === 1, 'header.partial must define shared-site-header once');
assert((headerPartial.match(/data-layout-part="shared-auth"/g) || []).length === 1, 'header.partial must define shared-auth once');
assert((headerPartial.match(/data-layout-part="shared-site-cart-panel"/g) || []).length === 1, 'header.partial must define shared-site-cart-panel once');
assert((headerPartial.match(/data-layout-part="shared-booking-cart-panel"/g) || []).length === 1, 'header.partial must define shared-booking-cart-panel once');
assert(!headerPartial.includes('data-layout-part="main-header"'), 'header.partial should remove main-header');
assert(!headerPartial.includes('data-layout-part="booking-header"'), 'header.partial should remove booking-header');
assert(!headerPartial.includes('data-layout-part="shared-header"'), 'header.partial should remove legacy shared-header');

const sharedHeaderFragment = headerPartial
  .split('<div data-layout-part="shared-site-header">')[1]
  ?.split('<div data-layout-part="shared-site-cart-panel">')[0] || '';
assert(!sharedHeaderFragment.includes('id="siteCartDrawer"'), 'shared-site-header should not inline shop cart panel');
assert(!sharedHeaderFragment.includes('id="cartPanel"'), 'shared-site-header should not inline booking panel');

const mainJs = readProjectFile('js/main.js');
assert(mainJs.includes('[data-layout-part="shared-site-header"]'), 'main.js should always load shared-site-header');
assert(!mainJs.includes('[data-layout-part="main-header"]'), 'main.js should not fallback to main-header');
assert(mainJs.includes('Missing or invalid data-header-context on #header'), 'main.js should fail loudly on missing context');
assert(mainJs.includes("!document.getElementById('siteCartDrawer')"), 'main.js should guard against duplicate shop cart panel');

const bookingLayoutJs = readProjectFile('booking/js/layout.js');
assert(bookingLayoutJs.includes('[data-layout-part="shared-site-header"]'), 'booking layout should load shared-site-header');
assert(!bookingLayoutJs.includes('[data-layout-part="booking-header"]'), 'booking layout should remove booking-header fallback');
assert(!bookingLayoutJs.includes('#booking-header'), 'booking layout should not query #booking-header');
assert(bookingLayoutJs.includes("if (document.getElementById('cartPanel')) return true;"), 'booking layout should guard booking cart panel singleton');

const sharedHeaderController = readProjectFile('js/components/header.js');
assert(sharedHeaderController.includes('data-auth-login-trigger'), 'shared header should render auth login trigger hook');
assert(sharedHeaderController.includes('root.dataset.headerInitializedContext = context;'), 'shared header should persist initialized context');
assert(sharedHeaderController.includes('_sharedHeaderStructureReady(root)'), 'shared header should validate structure before complete');
assert(sharedHeaderController.includes('_sharedHeaderContentReady(root)'), 'shared header should validate content before complete');
assert(!sharedHeaderController.includes('#booking-header'), 'header controller should not support #booking-header fallback');
assert(!sharedHeaderController.includes('.navbar-offcanvas'), 'header controller should not contain legacy offcanvas logic');
assert(!sharedHeaderController.includes('.navbar-hamburger'), 'header controller should not contain legacy hamburger logic');

const bookingHeaderJs = readProjectFile('booking/js/booking-header.js');
assert(!bookingHeaderJs.includes('bkOffcanvas'), 'booking-header.js should remove legacy offcanvas elements');
assert(!bookingHeaderJs.includes('bkHamburger'), 'booking-header.js should remove legacy hamburger handling');
assert(!bookingHeaderJs.includes('bkBackdrop'), 'booking-header.js should remove legacy offcanvas backdrop handling');
assert(bookingHeaderJs.includes("document.getElementById('cartPanel')"), 'booking-header.js should keep booking cart panel handling');
assert(bookingHeaderJs.includes("document.getElementById('bkPanelBackdrop')"), 'booking-header.js should keep booking panel backdrop handling');

const authJs = readProjectFile('js/components/auth.js');
assert(authJs.includes('window.initAuth = function initAuth()'), 'auth.js should expose initAuth');

const checkoutSuccessHtml = readProjectFile('pages/checkout-success.html');
assert(!/initNavbar\(|window\.initNavbar/.test(checkoutSuccessHtml), 'checkout-success should not re-run header initialization');

const pageScripts = [
  'js/pages/product-list.js',
  'js/pages/blog.js',
  'js/pages/blog-detail.js',
  'js/pages/faq.js',
  'js/pages/branches.js',
  'js/pages/checkout.js',
];
pageScripts.forEach((pageScript) => {
  const source = readProjectFile(pageScript);
  assert(!/initNavbar\(|window\.initNavbar/.test(source), `${pageScript} should not directly call initNavbar`);
});

const cssLegacyCandidates = [
  'css/main.css',
  'css/theme/theme-base.css',
  'css/theme/theme-layout.css',
  'css/theme/theme-components.css',
  'booking/css/booking.css',
  'booking/css/theme/booking-shell.css',
];
cssLegacyCandidates.forEach((path) => {
  const css = readProjectFile(path);
  assert(!css.includes('.navbar-offcanvas'), `${path} should not contain legacy .navbar-offcanvas selectors`);
  assert(!css.includes('.navbar-hamburger'), `${path} should not contain legacy .navbar-hamburger selectors`);
  assert(!css.includes('.offcanvas-close'), `${path} should not contain legacy .offcanvas-close selectors`);
  assert(!css.includes('.bk-offcanvas'), `${path} should not contain legacy .bk-offcanvas selectors`);
  assert(!css.includes('.bk-hamburger'), `${path} should not contain legacy .bk-hamburger selectors`);
});

const mainCss = readProjectFile('css/main.css');
assert(mainCss.includes('.cart-drawer'), 'main.css should keep shop cart drawer styles');
const bookingCss = readProjectFile('booking/css/booking.css');
assert(bookingCss.includes('.bk-slide-panel'), 'booking.css should keep booking panel styles');

console.log('Smoke checks passed');
