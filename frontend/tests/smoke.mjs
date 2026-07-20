import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const rootDir = dirname(dirname(fileURLToPath(import.meta.url)));
const mainRuntimeOrder = ['config.js', 'storage.js', 'state.js', 'formatters.js', 'validators.js', 'cart-service.js'];

/**
 * Reads a project file as UTF-8 text.
 * @param {string} relativePath - Project-relative file path.
 * @returns {string} File contents.
 */
function readProjectFile(relativePath) {
  return readFileSync(join(rootDir, relativePath), 'utf8');
}

/**
 * Fails the smoke test with a readable message when a required condition is false.
 * @param {boolean} condition - Condition to validate.
 * @param {string} message - Failure message.
 */
function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

/**
 * Checks that a file exists before deeper content assertions run.
 * @param {string} relativePath - Project-relative file path.
 */
function assertFileExists(relativePath) {
  assert(existsSync(join(rootDir, relativePath)), `Missing required file: ${relativePath}`);
}

/**
 * Verifies split runtime scripts are loaded in the expected dependency order.
 * @param {string} relativePath - HTML file path.
 */
function assertRuntimeScriptOrder(relativePath) {
  const html = readProjectFile(relativePath);
  const positions = mainRuntimeOrder.map((fileName) => html.indexOf(fileName));
  assert(positions.every((index) => index !== -1), `${relativePath} is missing split runtime scripts`);
  positions.slice(1).forEach((position, index) => {
    assert(position > positions[index], `${relativePath} runtime scripts are out of order`);
  });
}

/**
 * Returns every main-site HTML page that loads the shared runtime.
 * @returns {string[]} Project-relative HTML paths.
 */
function getMainHtmlPages() {
  // 主站 HTML 在 storefront/pages/（B1）/ Main site HTML lives under storefront/pages/
  const pageFiles = readdirSync(join(rootDir, 'storefront/pages'))
    .filter((fileName) => fileName.endsWith('.html'))
    .map((fileName) => `storefront/pages/${fileName}`);
  return ['index.html', ...pageFiles].filter((relativePath) => readProjectFile(relativePath).includes('config.js'));
}

[
  'package.json',
  'vite.config.js',
  'eslint.config.js',
  'stylelint.config.cjs',
  '.prettierrc.json',
  'src/styles.js',
  'storefront/js/storage.js',
  'storefront/js/state.js',
  'storefront/js/formatters.js',
  'storefront/js/validators.js',
  'storefront/js/cart-service.js',
  'storefront/js/api-mock.js',
  'storefront/js/config.js',
  'components/member-center.partial',
  'components/shipping-address-modal.partial',
].forEach(assertFileExists);

assert(!existsSync(join(rootDir, 'storefront/js/data-paths.js')), 'data-paths.js must be removed (merged into api-mock)');

getMainHtmlPages().forEach(assertRuntimeScriptOrder);

const header = readProjectFile('components/header.partial');
assert(header.includes('id="siteCartDrawer"'), 'Header must include shared cart drawer');
assert(header.includes('class="siteCartButton"'), 'Header must include shared cart button');
assert(!header.includes('id="bkLoginBtn"'), 'Legacy booking login button should be removed');
assert(!header.includes('id="bkUserMenu"'), 'Legacy booking user menu should be removed');
assert(!/style=/.test(header), 'Header partial should not contain inline styles');
assert(header.includes('src="/assets/'), 'Header brand image must use root-absolute /assets');
assert(!header.includes('data-app-path'), 'Header must not use data-app-path');

assert(!existsSync(join(rootDir, 'storefront/pages/cart.html')), 'Legacy cart page should be removed');
assert(!existsSync(join(rootDir, 'storefront/js/pages/cart.js')), 'Legacy cart page script should be removed');
assert(!existsSync(join(rootDir, 'pages')), 'Legacy frontend/pages/ folder should be removed after B1');
assert(!existsSync(join(rootDir, 'js')), 'Legacy frontend/js/ folder should be removed after B1');

const homePage = readProjectFile('storefront/pages/home.html');
assert(!/style=/.test(homePage), 'Home page should not contain inline style attributes');
assert(!/<style/i.test(homePage), 'Home page should not contain inline style blocks');
assert(homePage.includes('src="/storefront/js/api-mock.js"'), 'Home must load api-mock via root-absolute path');
assert(homePage.includes('src="/assets/videos/hero_video.mp4"'), 'Home hero video must use /assets');
assert(!homePage.includes('data-paths.js'), 'Home must not load data-paths.js');

const mainJs = readProjectFile('storefront/js/main.js');
assert(!mainJs.includes('async function initLayout'), 'main.js should not keep the legacy initLayout flow');
assert(!mainJs.includes('DOMContentLoaded", initLayout'), 'main.js should not bind legacy initLayout');
assert(mainJs.includes('/components/header.partial'), 'main.js must load header via /components');
assert(mainJs.includes('/storefront/js/components/header.js'), 'main.js must load header.js via /storefront/js');
assert(!mainJs.includes('rewriteAppPathsIn'), 'main.js must not rewrite paths');

const apiMock = readProjectFile('storefront/js/api-mock.js');
assert(apiMock.includes('productsCache'), 'api-mock.js should cache products.json');
assert(
  apiMock.includes('const _loadProductsRaw'),
  'api-mock.js should expose the shared product loader',
);
assert(apiMock.includes('MOCK_DATA_PATHS'), 'api-mock.js must define MOCK_DATA_PATHS');
assert(apiMock.includes('/data/catalog/products.json'), 'Mock products path must be root-absolute');
assert(apiMock.includes('USE_MOCK_API'), 'api-mock.js must respect USE_MOCK_API');
assert(!apiMock.includes('rewriteAssetUrlsDeep'), 'api-mock.js must not rewrite asset URLs');

const config = readProjectFile('storefront/js/config.js');
assert(config.includes('USE_MOCK_API'), 'config.js must expose USE_MOCK_API');
assert(config.includes('API_BASE_URL'), 'config.js must expose API_BASE_URL');
assert(config.includes('ASSET_BASE_URL'), 'config.js must expose ASSET_BASE_URL');

const forbiddenPathHelpers = ['resolveAppUrl', 'rewriteAssetUrlsDeep', 'rewriteAppPathsIn', 'getAppBase'];
const scanRoots = ['storefront/js', 'booking/js', 'admin/js', 'storefront/pages', 'booking/pages', 'components'];
for (const scanRoot of scanRoots) {
  const abs = join(rootDir, scanRoot);
  if (!existsSync(abs)) continue;
  const walk = (dir) => {
    for (const name of readdirSync(dir, { withFileTypes: true })) {
      const full = join(dir, name.name);
      if (name.isDirectory()) {
        walk(full);
        continue;
      }
      if (!/\.(js|html|partial)$/.test(name.name)) continue;
      const text = readFileSync(full, 'utf8');
      for (const token of forbiddenPathHelpers) {
        // allow comments that say "不再 resolveAppUrl"
        if (token === 'resolveAppUrl' && text.includes('不再 resolveAppUrl')) {
          const stripped = text.replace(/不再 resolveAppUrl/g, '');
          assert(!stripped.includes(token), `${full} still references ${token}`);
          continue;
        }
        assert(!text.includes(token), `${full} still references ${token}`);
      }
      assert(!text.includes('data-paths.js'), `${full} still references data-paths.js`);
    }
  };
  walk(abs);
}

console.log('Smoke checks passed');
