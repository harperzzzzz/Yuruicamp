// ========================================
// Mock API 層 — 統一讀取 /data（DataPaths）
// ========================================

const MOCK_ORDERS_KEY = 'mockOrders';
const MOCK_REVIEWS_KEY = 'mockReviews';
const MOCK_CUSTOMER_OVERLAY_KEY = 'mockCustomerOverlay';
const MOCK_CUSTOMER_RELATIONS_KEY = 'mockCustomerRelations';

let productsCache = null;
let productsCacheExpiresAt = 0;
let reviewsCache = null;
let ordersCache = null;

const _path = (key) => (window.DataPaths && window.DataPaths[key]) || '';

const _readJsonStorage = (key, fallback) => {
  try {
    return JSON.parse(localStorage.getItem(key) || JSON.stringify(fallback));
  } catch (error) {
    console.warn('localStorage parse failed:', key, error);
    return fallback;
  }
};

const _writeJsonStorage = (key, value) => {
  localStorage.setItem(key, JSON.stringify(value));
};

const _fetchJson = async (url) => {
  const res = await fetch(url, { cache: 'no-store' });
  if (!res.ok) throw new Error('Fetch failed: ' + url);
  return res.json();
};

const _formatLocalDateTime = (date = new Date()) => {
  const yyyy = date.getFullYear();
  const mm = String(date.getMonth() + 1).padStart(2, '0');
  const dd = String(date.getDate()).padStart(2, '0');
  const hh = String(date.getHours()).padStart(2, '0');
  const mi = String(date.getMinutes()).padStart(2, '0');
  const ss = String(date.getSeconds()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd} ${hh}:${mi}:${ss}`;
};

const _getStoredOrders = () => _readJsonStorage(MOCK_ORDERS_KEY, []);

const _mergeOrders = (base = [], persisted = []) => {
  const map = new Map();
  [...base, ...persisted].forEach((o) => {
    if (o && o.id != null) map.set(o.id, o);
  });
  return [...map.values()];
};

const _getNextOrderId = (orders = []) => {
  const ids = orders.map((o) => Number(o.id)).filter((n) => Number.isFinite(n) && n > 0);
  return Math.max(100, ...ids, 0) + 1;
};

const _normalizeOrder = (order) => {
  if (!order) return order;
  return {
    ...order,
    displayId: window.formatOrderDisplayId(order.id),
  };
};

/**
 * API 衍生欄位（不寫回 products.json）
 * Derived fields only — do NOT persist rating / salesCount / reviewCount to JSON.
 * totalStock / branch 亦為衍生（由 variants[].branch 加總，見 normalize-phase1-data.cjs）
 */
const _enrichProduct = async (product, reviews, orders) => {
  const enriched = window.enrichProductForDisplay(product);
  const ratingInfo = window.aggregateProductRating(enriched.id, reviews);
  enriched.rating = ratingInfo.rating;
  enriched.reviewCount = ratingInfo.reviewCount;
  enriched.ratingDisplay = ratingInfo.ratingDisplay;
  enriched.salesCount = window.computeProductSales(enriched.id, orders);
  return enriched;
};

const _getCustomerOverlay = () => _readJsonStorage(MOCK_CUSTOMER_OVERLAY_KEY, {});

const _setCustomerOverlay = (customerId, patch) => {
  const all = _getCustomerOverlay();
  all[customerId] = { ...(all[customerId] || {}), ...patch };
  _writeJsonStorage(MOCK_CUSTOMER_OVERLAY_KEY, all);
};

const _applyCustomerOverlay = (customer) => {
  const overlay = _getCustomerOverlay()[customer.id] || {};
  return { ...customer, ...overlay };
};

const _getCustomerRelationOverlay = () => _readJsonStorage(MOCK_CUSTOMER_RELATIONS_KEY, {});

const _setCustomerRelationOverlay = (customerId, patch) => {
  const all = _getCustomerRelationOverlay();
  all[customerId] = { ...(all[customerId] || {}), ...patch };
  _writeJsonStorage(MOCK_CUSTOMER_RELATIONS_KEY, all);
};

const _loadNormalizedCustomers = async () => {
  const [customers, options, preferences, addresses, tags, assignments] = await Promise.all([
    _fetchJson(_path('customers')),
    _fetchJson(_path('preferenceOptions')),
    _fetchJson(_path('customerPreferences')),
    _fetchJson(_path('customerShippingAddresses')),
    _fetchJson(_path('customerTags')),
    _fetchJson(_path('customerTagAssignments')),
  ]);
  const optionById = new Map(options.map((option) => [option.id, option]));
  const tagById = new Map(tags.map((tag) => [tag.id, tag]));
  return customers.map((customer) => {
    const preferenceObject = { styles: [], equipment: [] };
    preferences
      .filter((item) => item.customerId === customer.id)
      .map((item) => optionById.get(item.preferenceId))
      .filter(Boolean)
      .forEach((option) => {
        const key = option.type === 'style' ? 'styles' : 'equipment';
        preferenceObject[key].push(option.code);
      });
    const defaultAddress = addresses.find((address) => address.customerId === customer.id && address.isDefault);
    const shippingAddress = defaultAddress ? {
      lastName: '',
      firstName: defaultAddress.recipientName,
      postalCode: defaultAddress.postalCode,
      city: defaultAddress.city,
      district: defaultAddress.district,
      township: '',
      addressLine1: defaultAddress.addressLine,
      addressLine2: '',
      email: defaultAddress.email || customer.email,
      phone: defaultAddress.phone,
    } : null;
    const customerTagNames = assignments
      .filter((item) => item.customerId === customer.id)
      .map((item) => tagById.get(item.tagId)?.name)
      .filter(Boolean);
    return {
      ...customer,
      status: customer.status || 'active',
      deletedAt: customer.deletedAt || null,
      preferences: preferenceObject,
      shippingAddress,
      tags: customerTagNames,
      ...(_getCustomerRelationOverlay()[customer.id] || {}),
    };
  });
};

const _loadProductsRaw = async () => {
  const now = Date.now();
  if (productsCache && now < productsCacheExpiresAt) return productsCache;
  productsCache = await _fetchJson(_path('products'));
  productsCacheExpiresAt = now + (window.AppConfig?.CACHE_DURATION || 3600000);
  return productsCache;
};

const _loadReviews = async () => {
  if (reviewsCache) return reviewsCache;
  const seed = await _fetchJson(_path('reviews'));
  const mock = _readJsonStorage(MOCK_REVIEWS_KEY, []);
  reviewsCache = [...seed, ...mock].map((review) => ({
    ...review,
    verifiedPurchase: review.verifiedPurchase === true || review.id === 'REV031',
    ...(review.id === 'REV031' && review.orderItemId == null ? { orderItemId: 418 } : {}),
  }));
  return reviewsCache;
};

const _loadOrdersSeed = async () => {
  if (ordersCache) return ordersCache;
  let orderItemId = 0;
  const source = await _fetchJson(_path('orders'));
  ordersCache = source.map((order) => ({
    ...order,
    items: (order.items || []).map((item) => ({
      ...item,
      // Mirrors P4 source-order identity assignment. The review write
      // contract sends only this authoritative relationship.
      orderItemId: ++orderItemId,
    })),
  }));
  return ordersCache;
};

const _buildCustomerNotifications = (customer, orders) => {
  const list = [];
  const cid = customer.id;
  (orders || []).filter((o) => o.customerId === cid).forEach((o) => {
    const disp = window.formatOrderDisplayId(o.id);
    if (o.status === 'shipped') {
      // orderId：點通知可開訂單明細；trackingNumber 對應 schema orders.tracking_number
      const trackHint = o.trackingNumber
        ? '運單編號：' + o.trackingNumber + '。'
        : '';
      list.push({
        id: 'n-ship-' + o.id,
        type: 'order',
        orderId: o.id,
        title: '訂單 ' + disp + ' 已出貨',
        message: trackHint + '您的訂單已由宅配公司取件，請留意配送進度。',
        time: o.createdAt,
        read: false,
      });
    }
    if (o.status === 'completed') {
      const trackHint = o.trackingNumber
        ? '運單編號：' + o.trackingNumber + '。'
        : '';
      list.push({
        id: 'n-done-' + o.id,
        type: 'order',
        orderId: o.id,
        title: '訂單 ' + disp + ' 已送達',
        message: trackHint + '已送達，歡迎評價。',
        time: o.deliveredAt || o.createdAt,
        read: false,
      });
    }
  });
  const now = new Date();
  if (customer.birthday) {
    const bMonth = parseInt(String(customer.birthday).slice(5, 7), 10);
    if (bMonth === now.getMonth() + 1) {
      list.push({
        id: 'n-bday',
        type: 'promo',
        title: '生日折扣碼 YURUIHBD 當月可用',
        message: '祝您生日快樂！本月結帳可使用生日優惠。',
        time: _formatLocalDateTime(now).slice(0, 10),
        read: false,
      });
    }
  }
  if (!customer.firstPurchaseUsed) {
    list.push({
      id: 'n-first',
      type: 'promo',
      title: '首購優惠 YRUIFIRST 尚未使用',
      message: '首次購物可套用首購折扣碼。',
      time: _formatLocalDateTime(now).slice(0, 10),
      read: false,
    });
  }
  return list;
};

const customersApi = {
  getAll: async () => {
    const customers = await _loadNormalizedCustomers();
    return customers
      .map(_applyCustomerOverlay)
      .filter((customer) => customer.status === 'active' && customer.deletedAt === null);
  },

  getById: async (customerId) => {
    const customers = await customersApi.getAll();
    const user = customers.find((c) => c.id === customerId);
    if (!user) throw new Error('Customer not found');
    return user;
  },

  softDelete: async (customerId) => {
    const customer = await customersApi.getById(customerId);
    const timestamp = new Date().toISOString();
    _setCustomerOverlay(customerId, {
      status: 'deleted',
      deletedAt: timestamp,
      updatedAt: timestamp,
    });
    if (window.AppState?.currentUser?.id === customer.id) await customersApi.logout();
    return { ...customer, status: 'deleted', deletedAt: timestamp, updatedAt: timestamp };
  },

  suspend: async (customerId) => {
    const customer = await customersApi.getById(customerId);
    const timestamp = new Date().toISOString();
    _setCustomerOverlay(customerId, {
      status: 'suspended',
      deletedAt: null,
      updatedAt: timestamp,
    });
    if (window.AppState?.currentUser?.id === customer.id) await customersApi.logout();
    return { ...customer, status: 'suspended', deletedAt: null, updatedAt: timestamp };
  },

  getNotifications: async (customerId) => {
    const customer = await customersApi.getById(customerId);
    const orders = await window.API.orders.getAll();
    return _buildCustomerNotifications(customer, orders);
  },

  addPoints: async (customerId, points) => {
    const earned = Number(points) || 0;
    const customer = await customersApi.getById(customerId);
    const nextPoints = (Number(customer.points) || 0) + earned;
    _setCustomerOverlay(customerId, { points: nextPoints });
    const updated = await customersApi.getById(customerId);
    if (window.AppState?.currentUser?.id === customerId) {
      window.AppState.currentUser.points = updated.points;
      window.saveAppState && window.saveAppState();
    }
    window.dispatchEvent(new CustomEvent('yurui:user-points-updated', {
      detail: { userId: customerId, points: updated.points, earnedPoints: earned },
    }));
    return updated;
  },

  markFirstPurchaseUsed: async (customerId) => {
    _setCustomerOverlay(customerId, { firstPurchaseUsed: true });
  },

  update: async (customerId, updates) => {
    const current = window.AppState?.currentUser;
    if (!current || current.id !== customerId) throw new Error('Unauthorized');
    const updated = { ...current, ...updates };
    window.AppState.currentUser = updated;
    window.saveAppState && window.saveAppState();
    const relationUpdates = {};
    const customerUpdates = { ...updates };
    ['preferences', 'shippingAddress', 'tags'].forEach((key) => {
      if (Object.prototype.hasOwnProperty.call(customerUpdates, key)) {
        relationUpdates[key] = customerUpdates[key];
        delete customerUpdates[key];
      }
    });
    if (Object.keys(relationUpdates).length) _setCustomerRelationOverlay(customerId, relationUpdates);
    if (Object.keys(customerUpdates).length) _setCustomerOverlay(customerId, customerUpdates);
    return customersApi.getById(customerId);
  },

  logout: async () => {
    if (window.YuruiAuth?.logout) {
      window.YuruiAuth.logout({ showToast: false });
      return;
    }
    window.AppState.isLoggedIn = false;
    window.AppState.currentUser = null;
    window.saveAppState && window.saveAppState();
    localStorage.removeItem('currentUser');
    localStorage.removeItem('yuruiUser');
    localStorage.setItem('isLoggedIn', 'false');
    window.dispatchEvent(new CustomEvent('yurui:auth-changed', { detail: { type: 'logout', user: null } }));
  },
};

window.API = {
  /** @deprecated 請用 DataPaths */
  _getDataPath() {
    return '/data';
  },

  products: {
    getAll: async (filters = {}) => {
      const [raw, reviews, orders] = await Promise.all([
        _loadProductsRaw(),
        _loadReviews(),
        _loadOrdersSeed(),
      ]);
      let products = raw.filter((p) => p.status === 'active');
      products = await Promise.all(products.map((p) => _enrichProduct(p, reviews, orders)));

      if (filters.category) products = products.filter((p) => p.category === filters.category);
      if (filters.minPrice != null) products = products.filter((p) => p.price >= filters.minPrice);
      if (filters.maxPrice != null) products = products.filter((p) => p.price <= filters.maxPrice);
      if (filters.brand) products = products.filter((p) => p.brand === filters.brand);
      return products;
    },

    getById: async (productId) => {
      const raw = await _loadProductsRaw();
      const product = raw.find((p) => p.id === productId);
      if (!product) throw new Error('Product not found');
      const [reviews, orders] = await Promise.all([_loadReviews(), _loadOrdersSeed()]);
      return _enrichProduct(product, reviews, orders);
    },

    getReviews: async (productId) => {
      const reviews = await _loadReviews();
      return reviews.filter((r) => r.productId === productId);
    },

    getNewest: async (limit = 12) => {
      const all = await window.API.products.getAll();
      return all
        .slice()
        .sort((a, b) => {
          const na = parseInt(String(a.id).replace(/\D/g, ''), 10) || 0;
          const nb = parseInt(String(b.id).replace(/\D/g, ''), 10) || 0;
          return nb - na;
        })
        .slice(0, limit);
    },

    getBestsellers: async (limit = 20) => {
      const all = await window.API.products.getAll();
      return all
        .slice()
        .sort((a, b) => {
          if (b.salesCount !== a.salesCount) return b.salesCount - a.salesCount;
          return (b.reviewCount || 0) - (a.reviewCount || 0);
        })
        .slice(0, limit);
    },

    getCategories: async () => {
      const products = await _loadProductsRaw();
      return [...new Set(products.map((p) => p.category))];
    },
  },

  orders: {
    getAll: async () => {
      const seed = await _loadOrdersSeed();
      return _mergeOrders(seed, _getStoredOrders()).map(_normalizeOrder);
    },

    getByCustomerId: async (customerId, status = null) => {
      let orders = await window.API.orders.getAll();
      orders = orders.filter((o) => o.customerId === customerId);
      if (status) orders = orders.filter((o) => o.status === status);
      return orders;
    },

    create: async (orderData) => {
      const seed = await _loadOrdersSeed();
      const stored = _getStoredOrders();
      const merged = _mergeOrders(seed, stored);
      const nextId = orderData.id != null ? Number(orderData.id) : _getNextOrderId(merged);
      const subtotal = Number(orderData.subtotal) || 0;
      const points = window.calculateOrderRewardPoints(subtotal);

      const newOrder = _normalizeOrder({
        id: nextId,
        customerId: orderData.customerId || 'U001',
        buyerName: orderData.buyerName || '',
        buyerPhone: orderData.buyerPhone || '',
        buyerEmail: orderData.buyerEmail || '',
        userNote: orderData.userNote || orderData.buyerNote || '',
        items: orderData.items || [],
        subtotal,
        points,
        pointsAwarded: false,
        shippingFee: Number(orderData.shippingFee) || 0,
        coupons: orderData.coupons,
        discount: Number(orderData.discount) || 0,
        total: Number(orderData.total) || 0,
        status: orderData.status || 'unshipped',
        shippingMethod: orderData.shippingMethod || 'delivery',
        address: orderData.address || '',
        // payment = 付款方式；paymentStatus = unpaid|paid|refunded（COD → unpaid）
        payment: orderData.payment || 'credit-card',
        paymentStatus:
          orderData.paymentStatus ||
          (orderData.payment === 'cod' ? 'unpaid' : 'paid'),
        createdAt: orderData.createdAt || _formatLocalDateTime(),
        deliveredAt: '',
        trackingNumber: '',
        reviewed: false,
        history: [{ time: _formatLocalDateTime(), action: '訂單產生' }],
      });

      const orders = [...stored.filter((o) => o.id !== newOrder.id), newOrder];
      _writeJsonStorage(MOCK_ORDERS_KEY, orders);
      return newOrder;
    },

    markReviewed: async (orderId) => {
      const stored = _getStoredOrders();
      const idx = stored.findIndex((o) => o.id === orderId);
      if (idx >= 0) {
        stored[idx].reviewed = true;
        _writeJsonStorage(MOCK_ORDERS_KEY, stored);
      }
    },

    awardPointsIfCompleted: async (order) => {
      if (!order || order.status !== 'completed' || order.pointsAwarded) return;
      if (order.points > 0 && order.customerId) {
        await customersApi.addPoints(order.customerId, order.points);
      }
      const stored = _getStoredOrders();
      const idx = stored.findIndex((o) => o.id === order.id);
      if (idx >= 0) {
        stored[idx].pointsAwarded = true;
        _writeJsonStorage(MOCK_ORDERS_KEY, stored);
      }
    },
  },

  customers: customersApi,
  users: customersApi,

  coupons: {
    getAll: async () => _fetchJson(_path('coupons')),

    // 會員中心列表：僅 birthday + firstPurchase（promotion 活動碼只在結帳輸入）
    // Member center list: birthday + firstPurchase only (promotion codes are checkout-entry)
    getAvailable: async (customerId) => {
      const [coupons, customer] = await Promise.all([
        window.API.coupons.getAll(),
        customersApi.getById(customerId),
      ]);
      const now = new Date();
      return coupons.filter((c) => {
        if (c.status !== 'active') return false;
        if (c.category === 'birthday') {
          const bMonth = parseInt(String(customer.birthday).slice(5, 7), 10);
          return bMonth === now.getMonth() + 1;
        }
        if (c.category === 'firstPurchase') return !customer.firstPurchaseUsed;
        // 排除 promotion 等其他類別 / Exclude promotion and other categories
        return false;
      });
    },
  },

  reviews: {
    getAll: async () => _loadReviews(),

    create: async (payload) => {
      const orderItemId = Number(payload.orderItemId);
      if (!Number.isInteger(orderItemId) || orderItemId <= 0) {
        throw new Error('orderItemId is required');
      }
      const orders = await _loadOrdersSeed();
      let purchase = null;
      for (const order of orders) {
        const item = (order.items || []).find((candidate) => candidate.orderItemId === orderItemId);
        if (item) {
          if (purchase) throw new Error('orderItemId is ambiguous');
          purchase = { order, item };
        }
      }
      if (!purchase) throw new Error('orderItemId does not identify a purchased item');
      const existing = await _loadReviews();
      if (existing.some((review) => Number(review.orderItemId) === orderItemId)) {
        throw new Error('This order item was already reviewed');
      }
      const review = {
        id: 'REV-M-' + Date.now(),
        orderItemId,
        customerId: purchase.order.customerId,
        productId: purchase.item.productId,
        variantId: purchase.item.variantId,
        sku: purchase.item.sku,
        orderId: purchase.order.id,
        buyerName: purchase.order.buyerName,
        productName: purchase.item.name,
        rating: payload.rating,
        comment: payload.comment || '',
        photos: [],
        createdAt: _formatLocalDateTime(),
        verifiedPurchase: true,
      };
      const mock = _readJsonStorage(MOCK_REVIEWS_KEY, []);
      mock.push(review);
      _writeJsonStorage(MOCK_REVIEWS_KEY, mock);
      reviewsCache = null;
      await window.API.orders.markReviewed(purchase.order.id);
      return review;
    },
  },

  articles: {
    getAll: async () => _fetchJson(_path('articles')),
    getById: async (id) => {
      const articles = await window.API.articles.getAll();
      const article = articles.find((a) => a.id === id);
      if (!article) throw new Error('Article not found');
      return article;
    },
  },

  branches: {
    getAll: async () => _fetchJson(_path('branches')),
  },

  marketing: {
    getBrands: async () => _fetchJson(_path('brands')),
  },

  handleError: (error) => ({
    success: false,
    message: error.message || 'An error occurred',
    status: error.status || 500,
  }),
};

console.log('✓ Mock API 層已初始化（整合版）');
