// Product detail page state and behavior.
const DEFAULT_PRODUCT_ID = 'prod-001';
const FREE_SHIPPING_THRESHOLD = 3000;

// Initialize product detail page after shared scripts are available.
window.initProductDetailPage = async () => {
  const productId = _getProductIdFromUrl();
  _setProductPageState('loading');

  try {
    const product = await window.API.products.getById(productId);
    _renderProductPage(product);
    _setProductPageState('ready');
  } catch (error) {
    console.error('Product detail failed to load', error);
    _setProductPageState('error');
  }
};

// Read product id from query string with a stable fallback.
function _getProductIdFromUrl() {
  return new URLSearchParams(window.location.search).get('id') || DEFAULT_PRODUCT_ID;
}

// Toggle loading, error, and content states without inline styles.
function _setProductPageState(state) {
  const loading = document.getElementById('productLoading');
  const error = document.getElementById('productError');
  const content = document.getElementById('productDetailContent');
  if (loading) loading.hidden = state !== 'loading';
  if (error) error.hidden = state !== 'error';
  if (content) content.hidden = state !== 'ready';
}

// Render all product detail sections and bind interactions.
function _renderProductPage(product) {
  _renderProductInfo(product);
  _renderGallery(product);
  _renderSpecOptions(product, 'color');
  _renderSpecOptions(product, 'size');
  _renderSpecTable(product);
  _renderShippingProgress();
  _initQtyStepper();
  _initActionButtons(product);
  _initTabSwitching();
  _updatePageMeta(product);
}

// Update title and breadcrumb for the loaded product.
function _updatePageMeta(product) {
  const breadcrumb = document.getElementById('breadcrumbProductName');
  if (breadcrumb) breadcrumb.textContent = product.name;
  document.title = `${product.name} - Yuruicamp`;
}

// Render brand, name, rating, price, description, and tags.
function _renderProductInfo(product) {
  _setText('productBrand', product.brand || '');
  _setText('productName', product.name || '');
  _setText('productDescription', product.description || '');
  _renderRating(product);
  _renderPrice(product);
  _renderTags(product.tags || []);
}

// Safely set textContent by id.
function _setText(id, value) {
  const element = document.getElementById(id);
  if (element) element.textContent = value;
}

// Render rating text from static review cards or product data.
function _renderRating(product) {
  const reviewRatings = _getReviewCardRatings();
  const average = reviewRatings.length ? _average(reviewRatings) : product.rating || 0;
  const reviewCount = reviewRatings.length || product.reviews || 0;
  _setText('productStars', _renderStars(average));
  _setText('productRatingNum', average.toFixed(1));
  _setText('productReviewCount', `\uff08${reviewCount} \u5247\u8a55\u50f9\uff09`);
}

// Render current, original, and discount prices.
function _renderPrice(product) {
  const hasDiscount = product.originalPrice && product.originalPrice > product.price;
  _setText('productPrice', window.formatCurrency(product.price));
  _setText('productOriginalPrice', hasDiscount ? window.formatCurrency(product.originalPrice) : '');
  _setText('productDiscount', hasDiscount ? `-${Math.round((1 - product.price / product.originalPrice) * 100)}%` : '');
  document.getElementById('productOriginalPrice')?.toggleAttribute('hidden', !hasDiscount);
  document.getElementById('productDiscount')?.toggleAttribute('hidden', !hasDiscount);
}

// Render product tags as badges.
function _renderTags(tags) {
  const tagsEl = document.getElementById('productTags');
  if (!tagsEl) return;
  tagsEl.innerHTML = tags.map(tag => `<span class="productTag">#${tag}</span>`).join('');
}

// Convert numeric rating to five star characters.
function _renderStars(rating) {
  const filled = Math.max(0, Math.min(5, Math.round(Number(rating) || 0)));
  return `${'\u2605'.repeat(filled)}${'\u2606'.repeat(5 - filled)}`;
}

// Calculate an average value from numbers.
function _average(values) {
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

// Read star values from static review cards.
function _getReviewCardRatings() {
  return Array.from(document.querySelectorAll('[data-review-rating]'))
    .map(element => Number(element.dataset.reviewRating))
    .filter(value => Number.isFinite(value));
}

// Render image gallery with semantic thumbnail buttons.
function _renderGallery(product) {
  const images = product.images && product.images.length > 0 ? product.images : [product.image].filter(Boolean);
  const mainImg = document.getElementById('galleryMainImg');
  const thumbs = document.getElementById('galleryThumbs');
  if (!mainImg || !thumbs || images.length === 0) return;

  _setMainImage(mainImg, images[0], product.name);
  thumbs.innerHTML = images.map((src, index) => _buildGalleryThumb(src, index, product.name)).join('');
  thumbs.addEventListener('click', event => _handleGalleryClick(event, mainImg, product.name));
}

// Set the main gallery image source and alt text.
function _setMainImage(image, src, name) {
  image.src = src;
  image.alt = name;
  image.classList.remove('isSwitching');
}

// Build one gallery thumbnail button.
function _buildGalleryThumb(src, index, name) {
  const active = index === 0 ? ' isSelected' : '';
  return `
    <button class="galleryThumb${active}" data-src="${src}" type="button" aria-label="${name} ${index + 1}">
      <img src="${src}" alt="" class="galleryThumbImage" loading="lazy">
    </button>
  `;
}

// Switch the main gallery image from a thumbnail click.
function _handleGalleryClick(event, mainImg, productName) {
  const thumb = event.target.closest('.galleryThumb');
  if (!thumb) return;
  document.querySelectorAll('.galleryThumb').forEach(item => item.classList.remove('isSelected'));
  thumb.classList.add('isSelected');
  mainImg.classList.add('isSwitching');
  window.setTimeout(() => _setMainImage(mainImg, thumb.dataset.src, productName), 150);
}

// Render color or size option groups.
function _renderSpecOptions(product, type) {
  const options = type === 'color' ? product.colors : product.sizes;
  const group = document.getElementById(`${type}SpecGroup`);
  const container = document.getElementById(`${type}Options`);
  const label = document.getElementById(`selected${_capitalize(type)}Label`);

  group?.toggleAttribute('hidden', !options || options.length === 0);
  if (!options || !container || options.length === 0) return;
  if (label) label.textContent = options[0];
  container.innerHTML = options.map((value, index) => _buildSpecButton(type, value, index)).join('');
  container.addEventListener('click', event => _handleSpecClick(event, type, container, label));
}

// Build one spec option button.
function _buildSpecButton(type, value, index) {
  const active = index === 0 ? ' isSelected' : '';
  return `<button class="specOptionBtn${active}" data-${type}="${value}" type="button">${value}</button>`;
}

// Update selected spec button and visible label.
function _handleSpecClick(event, type, container, label) {
  const button = event.target.closest('.specOptionBtn');
  if (!button) return;
  container.querySelectorAll('.specOptionBtn').forEach(item => item.classList.remove('isSelected'));
  button.classList.add('isSelected');
  if (label) label.textContent = button.dataset[type];
}

// Capitalize a simple ASCII word.
function _capitalize(value) {
  return value.charAt(0).toUpperCase() + value.slice(1);
}

// Render product specifications and feature tags.
function _renderSpecTable(product) {
  const specTable = document.getElementById('productSpecTable');
  if (!specTable) return;
  const specs = product.specifications || {};
  specTable.innerHTML = Object.keys(specs).length ? _buildSpecRows(specs) : '<div class="productSpecEmpty">\u66ab\u7121\u898f\u683c\u8cc7\u6599</div>';
  _renderFeatures(product.tags || []);
}

// Build specification rows from key-value data.
function _buildSpecRows(specs) {
  return Object.entries(specs).map(([key, value]) => `
    <div class="productSpecRow">
      <div class="productSpecLabel">${_getSpecLabel(key)}</div>
      <div class="productSpecValue">${value}</div>
    </div>
  `).join('');
}

// Map known specification keys to labels.
function _getSpecLabel(key) {
  const labels = {
    weight: '\u91cd\u91cf',
    capacity: '\u5bb9\u91cf',
    material: '\u6750\u8cea',
    waterproof: '\u9632\u6c34\u4fc2\u6578',
    frameType: '\u652f\u67b6\u985e\u578b',
    power: '\u529f\u7387',
    fuelType: '\u71c3\u6599\u985e\u578b',
    lumens: '\u4eae\u5ea6',
    batteryLife: '\u96fb\u6c60\u7e8c\u822a',
    windSpeed: '\u98a8\u901f',
    poles: '\u71df\u67f1\u6750\u8cea',
  };
  return labels[key] || key;
}

// Render feature tags in the description tab.
function _renderFeatures(tags) {
  const features = document.getElementById('productFeatures');
  if (!features || tags.length === 0) return;
  features.innerHTML = `
    <h4 class="productFeaturesTitle">\u5546\u54c1\u7279\u8272</h4>
    <ul class="productFeaturesList">${tags.map(tag => `<li>${tag}</li>`).join('')}</ul>
  `;
}

// Render native progress value for free shipping threshold.
function _renderShippingProgress() {
  const cartTotal = window.calculateCartTotal ? window.calculateCartTotal() : 0;
  const progress = Math.min(Math.round((cartTotal / FREE_SHIPPING_THRESHOLD) * 100), 100);
  const remaining = Math.max(FREE_SHIPPING_THRESHOLD - cartTotal, 0);
  const displayProgress = cartTotal === 0 ? 80 : progress;

  const progressBar = document.getElementById('shippingProgressBar');
  if (progressBar) progressBar.value = displayProgress;
  _setText('shippingProgressText', cartTotal >= FREE_SHIPPING_THRESHOLD ? '\u5df2\u9054\u514d\u904b' : `${progress}%`);
  _setShippingHint(cartTotal, remaining);
}

// Render shipping hint text and status class.
function _setShippingHint(cartTotal, remaining) {
  const hint = document.getElementById('shippingProgressHint');
  if (!hint) return;
  hint.classList.toggle('isSuccess', cartTotal >= FREE_SHIPPING_THRESHOLD);
  if (cartTotal >= FREE_SHIPPING_THRESHOLD) hint.textContent = '\u5df2\u9054\u514d\u904b\u9580\u6abb';
  else if (cartTotal === 0) hint.textContent = `\u8cfc\u7269\u6eff NT$${FREE_SHIPPING_THRESHOLD.toLocaleString()} \u514d\u904b\uff0c\u9084\u5dee NT$${remaining.toLocaleString()}`;
  else hint.textContent = `\u518d\u8cfc\u8cb7 NT$${remaining.toLocaleString()} \u5373\u53ef\u514d\u904b`;
}

// Initialize quantity stepper buttons.
function _initQtyStepper() {
  const qtyInput = document.getElementById('qtyInput');
  document.getElementById('qtyDecrease')?.addEventListener('click', () => _setQuantity(qtyInput, -1));
  document.getElementById('qtyIncrease')?.addEventListener('click', () => _setQuantity(qtyInput, 1));
  qtyInput?.addEventListener('change', () => _normalizeQuantity(qtyInput));
}

// Increment or decrement the current quantity.
function _setQuantity(input, step) {
  if (!input) return;
  input.value = Math.max(1, Math.min(99, parseInt(input.value, 10) + step));
}

// Keep quantity inside the supported range.
function _normalizeQuantity(input) {
  let value = parseInt(input.value, 10);
  if (Number.isNaN(value) || value < 1) value = 1;
  input.value = Math.min(value, 99);
}

// Initialize add-to-cart and buy-now actions.
function _initActionButtons(product) {
  document.getElementById('addToCartBtn')?.addEventListener('click', () => {
    _addSelectedProductToCart(product);
    _renderShippingProgress();
  });
  document.getElementById('buyNowBtn')?.addEventListener('click', () => {
    _addSelectedProductToCart(product);
    window.setTimeout(() => { window.location.href = 'checkout.html'; }, 500);
  });
}

// Add the current product and selected specs to cart.
function _addSelectedProductToCart(product) {
  const qty = parseInt(document.getElementById('qtyInput')?.value || '1', 10);
  const specs = _getSelectedSpecs();
  const specSuffix = [specs.color, specs.size].filter(Boolean).join(' / ');
  window.addToCart({
    id: product.id,
    name: specSuffix ? `${product.name}\uff08${specSuffix}\uff09` : product.name,
    price: product.price,
    image: product.image,
    brand: product.brand,
  }, qty);
}

// Get currently selected color and size.
function _getSelectedSpecs() {
  return {
    color: document.querySelector('#colorOptions .specOptionBtn.isSelected')?.dataset.color || null,
    size: document.querySelector('#sizeOptions .specOptionBtn.isSelected')?.dataset.size || null,
  };
}

// Initialize product description and review tabs.
function _initTabSwitching() {
  const tabBtns = document.querySelectorAll('.productTabBtn');
  const tabPanels = document.querySelectorAll('.productTabPanel');
  tabBtns.forEach(button => {
    button.addEventListener('click', () => _activateTab(button, tabBtns, tabPanels));
  });
}

// Activate one tab and its matching panel.
function _activateTab(activeButton, tabBtns, tabPanels) {
  const targetTab = activeButton.dataset.tab;
  tabBtns.forEach(button => button.classList.toggle('isSelected', button === activeButton));
  tabPanels.forEach(panel => panel.classList.toggle('isSelected', panel.dataset.panel === targetTab));
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', window.initProductDetailPage);
} else {
  window.initProductDetailPage();
}
