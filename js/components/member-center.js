(function () {
  'use strict';
  var cfg = Object.assign({ dataBasePath: '../data', authStorageKey: 'currentUser', fallbackAuthStorageKey: 'yuruiUser', homeHref: 'home.html', requireLogin: true }, window.MemberCenterConfig || {});
  var REVIEW_KEY = 'member_center_reviews';
  var MOCK_ORDERS_KEY = 'mockOrders';
  var MOCK_POINTS_KEY = 'mockUserPointDeltas';
  var statusMeta = {
    purchase: [ ['all','全部',''], ['unshipped','待出貨','isPending'], ['shipped','已出貨','isUpcoming'], ['delivered','已完成','isDone'], ['returned','已退貨','isCancelled'] ],
    rental: [ ['all','全部',''], ['pending','待確認','isPending'], ['confirmed','已確認','isUpcoming'], ['completed','已完成','isDone'], ['refunded','已退款','isCancelled'] ]
  };
<<<<<<< Updated upstream

  var config = Object.assign({}, DEFAULT_CONFIG, window.MemberCenterConfig || {});
  var DATA_PATHS = {
    users: joinPath(config.dataBasePath, 'users.json'),
    orders: joinPath(config.dataBasePath, 'orders.json'),
    rentalOrders: joinPath(config.dataBasePath, 'rentalOrders.json')
  };

  var REWARD_POINT_RATE = 0.1;
  var REVIEW_STORAGE_KEY = 'member_center_reviews';
  var MOCK_ORDERS_STORAGE_KEY = 'mockOrders';
  var MOCK_USER_POINT_DELTAS_STORAGE_KEY = 'mockUserPointDeltas';

  var state = {
    root: null,
    initialized: false,
    user: null,
    users: [],
    orders: [],
    rentalOrders: [],
    activeFilters: {
      purchase: 'all',
      rental: 'all'
    },
    review: {
      orderId: null,
      itemName: '',
      rating: 0
    },
    pointsTimer: null,
    loginTimer: null
  };

  /** 重點：購買紀錄狀態沿用先前 data/orders.json 合約，cod 併入 paid，processing 併入 unshipped。 */
  var PURCHASE_ORDER_STATUS_META = [
    { value: 'paid', label: '待付款', cls: 'status--pending' },
    { value: 'unpaid', label: '已付款', cls: 'status--upcoming' },
    { value: 'unshipped', label: '待出貨', cls: 'status--pending' },
    { value: 'shipped', label: '已出貨', cls: 'status--upcoming' },
    { value: 'delivered', label: '已完成', cls: 'status--done' },
    { value: 'returned', label: '已退貨', cls: 'status--cancelled' },
    { value: 'cancelled', label: '已取消', cls: 'status--cancelled' }
  ];

  /** 重點：預約與租借紀錄狀態沿用 data/rentalOrders.json，舊狀態由 aliases 統一轉換。 */
  var RENTAL_ORDER_STATUS_META = [
    { value: 'refunded', label: '已退款', cls: 'status--cancelled' },
    { value: 'paid', label: '已付款', cls: 'status--upcoming' },
    { value: 'pending', label: '待確認', cls: 'status--pending' },
    { value: 'confirmed', label: '已確認', cls: 'status--upcoming' },
    { value: 'completed', label: '已完成', cls: 'status--done' },
    { value: 'cancelled', label: '已取消', cls: 'status--cancelled' }
  ];

  var PURCHASE_ORDER_ALIASES = {
    processing: 'unshipped',
    cod: 'paid'
  };

  var RENTAL_ORDER_ALIASES = {
    processing: 'pending',
    shipped: 'confirmed',
    delivered: 'completed'
  };

  var PURCHASE_META_MAP = toMetaMap(PURCHASE_ORDER_STATUS_META);
  var RENTAL_META_MAP = toMetaMap(RENTAL_ORDER_STATUS_META);
  var PREFERENCE_STYLE_VALUES = ['glamping', 'backpacking', 'family', 'solo', 'hiking', 'car-camping', 'ultralight', 'base-camp'];
  var PREFERENCE_EQUIPMENT_VALUES = ['tent', 'sleeping-bag', 'backpack', 'cooking', 'lighting', 'clothing', 'chair', 'navigation', 'safety', 'photography'];
  var PURCHASE_TAB_FILTERS = ['all', 'unshipped', 'shipped', 'returned'];
  var RENTAL_TAB_FILTERS = ['all', 'pending', 'confirmed', 'refunded'];

  function joinPath(base, fileName) {
    return String(base || '').replace(/\/+$/, '') + '/' + fileName;
  }

  function toMetaMap(items) {
    return items.reduce(function (map, item) {
      map[item.value] = item;
      return map;
    }, {});
  }

  function safeJsonParse(value, fallback) {
    try {
      return value ? JSON.parse(value) : fallback;
    } catch (error) {
      return fallback;
    }
  }

  /** 重點：安全讀取 localStorage 陣列，避免 checkout 暫存資料壞掉時影響會員中心。 */
  function readStorageArray(key) {
    var value = safeJsonParse(localStorage.getItem(key), []);
    return Array.isArray(value) ? value : [];
  }

  /** 重點：data/orders.json 與 mockOrders 以 id 合併，讓結帳後的新訂單可即時出現在會員中心。 */
  function mergeOrders(baseOrders, mockOrders) {
    var orderMap = new Map();
    (Array.isArray(baseOrders) ? baseOrders : [])
      .concat(Array.isArray(mockOrders) ? mockOrders : [])
      .forEach(function (order) {
        if (order && order.id) orderMap.set(order.id, order);
      });
    return Array.from(orderMap.values());
  }

  /** 重點：cardPoints 只加總 delivered 的 mockOrders，避免 checkout 新增 unshipped 訂單時先發點數。 */
  function getDeliveredMockOrderPointDeltas() {
    return readStorageArray(MOCK_ORDERS_STORAGE_KEY).reduce(function (deltas, order) {
      if (normalizeFilterValue('purchase', order && order.status) !== 'delivered') return deltas;

      var userId = order.userId || 'user-001';
      deltas[userId] = (Number(deltas[userId]) || 0) + getOrderRewardPoints(order);
      return deltas;
    }, {});
  }

  /** 重點：users.json points 搭配 delivered 訂單暫存點數，只有已完成訂單才更新會員卡點數。 */
  function applyUserPointDeltas(users) {
    var deltas = getDeliveredMockOrderPointDeltas();
    return (Array.isArray(users) ? users : []).map(function (user) {
      return Object.assign({}, user, {
        points: (Number(user.points) || 0) + (Number(deltas[user.id]) || 0)
      });
    });
  }

  function escapeHtml(value) {
    return String(value == null ? '' : value)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function showMcToast(message, type) {
    if (typeof window.showToast === 'function') {
      window.showToast(message, type || 'info');
      return;
    }
    console.log(message);
  }

  async function fetchJson(path, fallback) {
    try {
      var response = await fetch(path, { cache: 'no-store' });
      if (!response.ok) throw new Error('HTTP ' + response.status);
      return await response.json();
    } catch (error) {
      console.error('會員中心資料讀取失敗：' + path, error);
      return fallback;
    }
  }

  function formatMoney(value) {
    return 'NT$ ' + Number(value || 0).toLocaleString('zh-TW');
  }

  /** 重點：升等進度只採計 delivered 購買訂單 subtotal，讓已完成訂單才會推進會員等級。 */
  function getDeliveredPurchaseSubtotal() {
    return state.orders.reduce(function (total, order) {
      if (normalizeFilterValue('purchase', order && order.status) !== 'delivered') return total;
      return total + (Number(order.subtotal) || 0);
    }, 0);
  }

  /** 重點：依目前 delivered subtotal 更新會員卡進度條與距下一級文字。 */
  function renderTierProgress(user) {
    var nextTierSpend = Number(user && user.nextTierSpend) || 0;
    var totalSpend = getDeliveredPurchaseSubtotal();
    var remaining = Math.max(nextTierSpend - totalSpend, 0);
    var progress = nextTierSpend > 0 ? Math.min(Math.round((totalSpend / nextTierSpend) * 100), 100) : 0;
    var progressBar = document.getElementById('tierProgressBar');

    setText('nextTierSpend', formatMoney(remaining));
    if (progressBar) progressBar.style.width = progress + '%';
  }

  function formatDate(value) {
    return value || '--';
  }

  function getStoredUserFromKey(key) {
    return key ? safeJsonParse(localStorage.getItem(key), null) : null;
  }

  function getLoginUser() {
    if (window.AppState && window.AppState.isLoggedIn && window.AppState.currentUser) {
      return window.AppState.currentUser;
    }

    var keys = [
      config.authStorageKey,
      config.fallbackAuthStorageKey,
      'currentUser',
      'yuruiUser'
    ].filter(Boolean);

    for (var index = 0; index < keys.length; index += 1) {
      var user = getStoredUserFromKey(keys[index]);
      if (user) return user;
    }

    if (localStorage.getItem('isLoggedIn') === 'true') {
      return { id: 'user-001' };
    }

    return null;
  }

  function isLoggedIn() {
    return config.requireLogin === false || Boolean(getLoginUser());
  }

  function getSavedProfile() {
    return safeJsonParse(localStorage.getItem('yurui_profile'), {});
  }

  function getCurrentMemberId() {
    var loginUser = getLoginUser();
    return (loginUser && (loginUser.id || loginUser.userId)) || 'user-001';
  }

  function selectUser(users) {
    var safeUsers = Array.isArray(users) ? users : [];
    var loginUser = getLoginUser() || {};
    var loginId = loginUser.id || loginUser.userId;
    var loginEmail = loginUser.email;

    return safeUsers.find(function (user) {
      return user.id === loginId || (loginEmail && user.email === loginEmail);
    }) || safeUsers.find(function (user) {
      return user.id === 'user-001';
    }) || safeUsers[0] || null;
  }

  function normalizePreferenceValues(preferences) {
    if (Array.isArray(preferences)) return preferences.filter(Boolean);
    if (typeof preferences === 'string' && preferences) return [preferences];
    if (!preferences || typeof preferences !== 'object') return [];

    return []
      .concat(preferences.styles || [])
      .concat(preferences.equipment || [])
      .filter(Boolean);
  }

  function getPreferenceGroup(value) {
    if (PREFERENCE_STYLE_VALUES.includes(value)) return 'styles';
    if (PREFERENCE_EQUIPMENT_VALUES.includes(value)) return 'equipment';
    return null;
  }

  function uniqueValues(values) {
    return Array.from(new Set((Array.isArray(values) ? values : []).filter(Boolean)));
  }

  function normalizePreferenceObject(preferences) {
    var normalized = { styles: [], equipment: [] };

    // 重點：舊資料可能是攤平陣列，新資料則固定拆回 styles / equipment。
    normalizePreferenceValues(preferences).forEach(function (value) {
      var group = getPreferenceGroup(value);
      if (group) normalized[group].push(value);
    });

    normalized.styles = uniqueValues(normalized.styles);
    normalized.equipment = uniqueValues(normalized.equipment);
    return normalized;
  }

  function getStoredPreferenceObject() {
    return normalizePreferenceObject(getStoredPreferenceValues());
  }

  function getActivePreferenceObject() {
    var preferences = { styles: [], equipment: [] };

    document.querySelectorAll('#prefTags .survey-tag.active').forEach(function (tag) {
      var group = getPreferenceGroup(tag.dataset.value);
      if (group) preferences[group].push(tag.dataset.value);
    });

    preferences.styles = uniqueValues(preferences.styles);
    preferences.equipment = uniqueValues(preferences.equipment);
    return preferences;
  }

  function persistPreferenceObject(preferences) {
    var normalized = normalizePreferenceObject(preferences);
    var savedProfile = getSavedProfile();

    // 重點：同步保存分類結構，避免重新渲染時把剛切換的 active 狀態復原。
    savedProfile.preferences = normalized;
    localStorage.setItem('yurui_profile', JSON.stringify(savedProfile));
    localStorage.setItem('preferences', JSON.stringify(normalized));

    if (window.AppState) {
      window.AppState.preferences = normalized;
      if (typeof window.saveAppState === 'function') window.saveAppState();
    }

    return normalized;
  }

  function updatePreferenceObjectValue(preferences, value, isActive) {
    var normalized = normalizePreferenceObject(preferences);
    var group = getPreferenceGroup(value);
    if (!group) return normalized;

    // 重點：active 被取消就從對應陣列移除，新啟用則新增到對應陣列。
    normalized[group] = normalized[group].filter(function (item) { return item !== value; });
    if (isActive) normalized[group].push(value);
    normalized[group] = uniqueValues(normalized[group]);
    return normalized;
  }

  function getStoredPreferenceValues() {
    var appPrefs = normalizePreferenceValues(window.AppState && window.AppState.preferences);
    if (appPrefs.length) return appPrefs;

    var profilePrefs = normalizePreferenceValues(getSavedProfile().preferences);
    if (profilePrefs.length) return profilePrefs;

    var localPrefs = normalizePreferenceValues(safeJsonParse(localStorage.getItem('preferences'), {}));
    if (localPrefs.length) return localPrefs;

    return normalizePreferenceValues(state.user && state.user.preferences);
  }

  function normalizeFilterValue(orderType, value) {
    var aliases = orderType === 'rental' ? RENTAL_ORDER_ALIASES : PURCHASE_ORDER_ALIASES;
    return aliases[value] || value;
  }

  function getStatusInfo(status) {
    var normalized = normalizeFilterValue('purchase', status);
    return PURCHASE_META_MAP[normalized] || { value: normalized, label: normalized || '未設定', cls: 'status--pending' };
  }

  function getRentalStatusInfo(status) {
    var normalized = normalizeFilterValue('rental', status);
    return RENTAL_META_MAP[normalized] || { value: normalized, label: normalized || '未設定', cls: 'status--pending' };
  }

  function orderMatchesFilter(order, filter, orderType) {
    if (!filter || filter === 'all') return true;

    var normalizedStatus = normalizeFilterValue(orderType, order.status);
    var normalizedPayment = normalizeFilterValue(orderType, order.paymentStatus);

    // 重點：待付款篩選可吃 paymentStatus，但已退貨訂單不可被帶進待付款列表。
    if (orderType === 'purchase' && filter === 'paid' && normalizedStatus === 'returned') {
      return false;
    }

    return normalizedStatus === filter || normalizedPayment === filter;
  }

  function buildFilterDefinitions(orderType, orders) {
    var meta = orderType === 'rental' ? RENTAL_ORDER_STATUS_META : PURCHASE_ORDER_STATUS_META;
    var allowed = orderType === 'rental' ? RENTAL_TAB_FILTERS : PURCHASE_TAB_FILTERS;

    // 重點：訂單可保留更多 status，但 tab 只渲染需求指定的篩選選項。
    return allowed.map(function (value) {
      if (value === 'all') return { value: 'all', label: '全部', cls: '' };
      return meta.find(function (item) { return item.value === value; }) || { value: value, label: value, cls: 'status--pending' };
    });
  }

  function renderOrderStatusTabs(orderType, orders) {
    var container = document.getElementById(orderType === 'rental' ? 'rentalOrderStatusTabs' : 'purchaseOrderStatusTabs');
    if (!container) return;

    var filters = buildFilterDefinitions(orderType, orders);
    var active = filters.some(function (item) { return item.value === state.activeFilters[orderType]; })
      ? state.activeFilters[orderType]
      : 'all';

    state.activeFilters[orderType] = active;

    // 重點：篩選標籤完全由 JSON 狀態動態產生，保留兩個會員中心一致的預設全部選項。
    container.innerHTML = filters.map(function (item) {
      var isActive = item.value === active;
      return '<button class="order-status-tab' + (isActive ? ' active' : '') + '"'
        + ' type="button" data-filter="' + escapeHtml(item.value) + '" aria-pressed="' + isActive + '">'
        + escapeHtml(item.label)
        + '</button>';
    }).join('');
  }

  function buildItemSummary(items) {
    var safeItems = Array.isArray(items) ? items : [];
    if (safeItems.length === 0) return '未命名商品';
    if (safeItems.length === 1) return safeItems[0].name || '未命名商品';
    return (safeItems[0].name || '未命名商品') + ' 等 ' + safeItems.length + ' 件';
  }

  function buildThumbsHtml(items) {
    var safeItems = Array.isArray(items) ? items : [];
    if (safeItems.length === 0) return '';

    return '<div class="rec-item__thumbs">'
      + safeItems.slice(0, 3).map(function (item) {
        var image = item.image || 'https://picsum.photos/seed/fallback/80/80';
        return '<img src="' + escapeHtml(image) + '" alt="' + escapeHtml(item.name || '商品') + '" class="rec-item__thumb"'
          + ' onerror="this.src=\'https://picsum.photos/seed/fallback/80/80\'">';
      }).join('')
      + (safeItems.length > 3 ? '<span class="rec-item__more">+' + (safeItems.length - 3) + '</span>' : '')
      + '</div>';
  }

  function getStoredReviews() {
    return safeJsonParse(localStorage.getItem(REVIEW_STORAGE_KEY), []);
  }

  function isOrderReviewed(order) {
    if (order.reviewed || order.review) return true;
    return getStoredReviews().some(function (review) {
      return review.orderId === order.id;
    });
  }

  function canReviewOrder(order) {
    return Boolean(order && order.canReview && normalizeFilterValue('purchase', order.status) === 'delivered' && !isOrderReviewed(order));
  }

  function renderPurchaseOrders() {
    var container = document.getElementById('ordersList');
    if (!container) return;

    var filtered = state.orders.filter(function (order) {
      return orderMatchesFilter(order, state.activeFilters.purchase, 'purchase');
    });

    if (filtered.length === 0) {
      container.innerHTML = '<div class="rec-empty"><div class="rec-empty__icon"><i class="bi bi-bag-x"></i></div>目前沒有符合條件的購買紀錄</div>';
      return;
    }

    container.innerHTML = filtered.map(function (order) {
      var status = getStatusInfo(order.status);
      var itemName = buildItemSummary(order.items);
      var reviewButton = canReviewOrder(order)
        ? '<button class="rec-item__detail-btn" type="button" data-review-order="' + escapeHtml(order.id) + '" data-review-item="' + escapeHtml((order.items && order.items[0] && order.items[0].name) || itemName) + '">寫評價</button>'
        : '';

      return '<div class="rec-item" data-order-id="' + escapeHtml(order.id) + '">'
        + '<div class="rec-item__info">'
        + '<div class="rec-item__title">' + escapeHtml(itemName) + '</div>'
        + '<div class="rec-item__meta">' + escapeHtml(order.orderNumber || order.id) + ' ｜ ' + escapeHtml(formatDate(order.createdAt)) + ' ｜ ' + ((order.items || []).length || 0) + ' 件商品</div>'
        + buildThumbsHtml(order.items)
        + '</div>'
        + '<div class="rec-item__right">'
        + '<div class="rec-item__amount">' + formatMoney(order.total) + '</div>'
        + '<span class="rec-item__status ' + status.cls + '">' + escapeHtml(status.label) + '</span>'
        + '<button class="rec-item__detail-btn" type="button" data-order-detail="' + escapeHtml(order.id) + '">查看明細</button>'
        + reviewButton
        + '</div>'
        + '</div>';
    }).join('');
  }

  function renderRentalOrders() {
    var container = document.getElementById('rentalOrdersList');
    if (!container) return;

    var filtered = state.rentalOrders.filter(function (order) {
      return orderMatchesFilter(order, state.activeFilters.rental, 'rental');
    });

    if (filtered.length === 0) {
      container.innerHTML = '<div class="rec-empty"><div class="rec-empty__icon"><i class="bi bi-tent-x"></i></div>目前沒有符合條件的預約與租借紀錄</div>';
      return;
    }

    container.innerHTML = filtered.map(function (order) {
      var status = getRentalStatusInfo(order.status);
      return '<div class="rec-item" data-rental-order-id="' + escapeHtml(order.id) + '">'
        + '<div class="rec-item__info">'
        + '<div class="rec-item__title">' + escapeHtml(buildItemSummary(order.items)) + '</div>'
        + '<div class="rec-item__meta">' + escapeHtml(order.orderNumber || order.id) + ' ｜ ' + escapeHtml(order.rentalStart || '--') + ' - ' + escapeHtml(order.rentalEnd || '--') + ' ｜ ' + escapeHtml(order.pickupStore || '--') + ' / ' + escapeHtml(order.returnStore || '--') + '</div>'
        + buildThumbsHtml(order.items)
        + '</div>'
        + '<div class="rec-item__right">'
        + '<div class="rec-item__amount">' + formatMoney(order.total) + '</div>'
        + '<span class="rec-item__status ' + status.cls + '">' + escapeHtml(status.label) + '</span>'
        + '<button class="rec-item__detail-btn" type="button" data-rental-detail="' + escapeHtml(order.id) + '">查看明細</button>'
        + '</div>'
        + '</div>';
    }).join('');
  }

  function calculateOrderRewardPoints(subtotal) {
    return Math.ceil((Number(subtotal) || 0) * REWARD_POINT_RATE);
  }

  function getOrderRewardPoints(order) {
    var points = Number(order && order.points);
    return Number.isFinite(points) ? points : calculateOrderRewardPoints(order && order.subtotal);
  }

  function getOrderCoupons(order) {
    if (Array.isArray(order.coupons)) return order.coupons;
    return order && order.coupon ? [order.coupon] : [];
  }

  function formatOrderCoupon(coupon) {
    var code = coupon.code || '未命名折扣';
    if (coupon.type === 'percent') {
      var amountText = coupon.amount ? '，折抵 ' + formatMoney(coupon.amount) : '';
      return code + '（' + coupon.discount + '%' + amountText + '）';
    }
    return code + '（折抵 ' + formatMoney(coupon.amount || coupon.discount || 0) + '）';
  }

  function buildOrderCouponRow(order) {
    var coupons = getOrderCoupons(order);
    if (!coupons.length) return '';

    return '<div class="bk-detail-row bk-detail-row--success">'
      + '<span>使用折價券</span><span>' + coupons.map(function (coupon) {
        return escapeHtml(formatOrderCoupon(coupon));
      }).join('<br>') + '</span>'
      + '</div>';
  }

  function buildOrderPointsRow(order) {
    return '<div class="bk-detail-row bk-detail-row--success">'
      + '<span>回饋點數</span><span>' + getOrderRewardPoints(order).toLocaleString('zh-TW') + ' 點</span>'
      + '</div>';
  }

  function getPaymentLabel(payment) {
    var map = {
      'credit-card': '信用卡',
      'line-pay': 'LINE Pay',
      cod: '貨到付款'
    };
    return map[payment] || payment || '未設定';
  }

  function openDetailModal(title, bodyHtml) {
    var titleEl = document.getElementById('orderDetailTitle');
    var bodyEl = document.getElementById('orderDetailBody');
    var overlay = document.getElementById('orderDetailOverlay');
    if (!titleEl || !bodyEl || !overlay) return;

    titleEl.textContent = title;
    bodyEl.innerHTML = bodyHtml;
    overlay.classList.add('is-open');
    document.body.style.overflow = 'hidden';
  }

  function closeDetailModal() {
    var overlay = document.getElementById('orderDetailOverlay');
    if (overlay) overlay.classList.remove('is-open');
    document.body.style.overflow = '';
  }

  window.openOrderDetail = function (orderId) {
    var order = state.orders.find(function (item) { return item.id === orderId; });
    if (!order) return;

    var status = getStatusInfo(order.status);
    var itemsHtml = (order.items || []).map(function (item) {
      var quantity = Number(item.quantity || 0);
      var subtotal = Number(item.price || 0) * quantity;
      return '<div class="bk-order-item-row">'
        + '<img src="' + escapeHtml(item.image || 'https://picsum.photos/seed/fallback/80/80') + '" alt="' + escapeHtml(item.name || '商品') + '" class="bk-order-item-img"'
        + ' onerror="this.src=\'https://picsum.photos/seed/fallback/80/80\'">'
        + '<div>'
        + '<div class="bk-order-item-name">' + escapeHtml(item.name || '未命名商品') + '</div>'
        + '<div class="bk-order-item-qty">x ' + quantity + '，' + formatMoney(subtotal) + '</div>'
        + '</div>'
        + '</div>';
    }).join('');

    // 重點：購買明細同時顯示 coupons、discount、points，資料全從 data/orders.json 取得。
    openDetailModal('訂單詳情 ' + (order.orderNumber || order.id), ''
      + '<div class="bk-detail-head">'
      + '<div class="bk-detail-date">' + escapeHtml(formatDate(order.createdAt)) + '</div>'
      + '<span class="bk-status-badge ' + status.cls + '">' + escapeHtml(status.label) + '</span>'
      + '</div>'
      + '<div class="bk-detail-section-title"><i class="bi bi-receipt"></i> 商品明細</div>'
      + itemsHtml
      + '<hr class="bk-detail-sep">'
      + '<div class="bk-detail-rows">'
      + '<div class="bk-detail-row"><span>商品小計</span><span>' + formatMoney(order.subtotal) + '</span></div>'
      + '<div class="bk-detail-row"><span>運費</span><span>' + (Number(order.shippingFee) === 0 ? '免費' : formatMoney(order.shippingFee)) + '</span></div>'
      + (order.discount ? '<div class="bk-detail-row bk-detail-row--danger"><span>折扣</span><span>- ' + formatMoney(order.discount) + '</span></div>' : '')
      + buildOrderCouponRow(order)
      + '<div class="bk-detail-row bk-detail-row--total"><span>訂單總計</span><span>' + formatMoney(order.total) + '</span></div>'
      + buildOrderPointsRow(order)
      + '</div>'
      + '<div class="bk-detail-note"><i class="bi bi-credit-card"></i> 付款方式：' + escapeHtml(getPaymentLabel(order.payment)) + '</div>'
      + (order.shippingAddress ? '<div class="bk-detail-note"><i class="bi bi-geo-alt"></i> 配送地址：' + escapeHtml(order.shippingAddress) + '</div>' : '')
      + (order.trackingNumber ? '<div class="bk-detail-note"><i class="bi bi-truck"></i> 物流追蹤：' + escapeHtml(order.trackingNumber) + '</div>' : '')
      // 重點：checkout 寫入的 userNote 只在有內容時顯示，避免舊訂單產生空白備註列。
      + (order.userNote ? '<div class="bk-detail-note"><i class="bi bi-chat-left-text"></i> 使用者備註：' + escapeHtml(order.userNote) + '</div>' : '')
      + buildLineSupportLink('詢問訂單'));
  };

  window.openRentalOrderDetail = function (orderId) {
    var order = state.rentalOrders.find(function (item) { return item.id === orderId; });
    if (!order) return;

    var status = getRentalStatusInfo(order.status);
    var itemsHtml = (order.items || []).map(function (item) {
      var quantity = Number(item.quantity || 0);
      var subtotal = Number(item.price || 0) * quantity;
      return '<div class="bk-order-item-row">'
        + '<img src="' + escapeHtml(item.image || 'https://picsum.photos/seed/fallback/80/80') + '" alt="' + escapeHtml(item.name || '商品') + '" class="bk-order-item-img"'
        + ' onerror="this.src=\'https://picsum.photos/seed/fallback/80/80\'">'
        + '<div>'
        + '<div class="bk-order-item-name">' + escapeHtml(item.name || '未命名租借品') + '</div>'
        + '<div class="bk-order-item-qty">x ' + quantity + '，' + formatMoney(subtotal) + '</div>'
        + '</div>'
        + '</div>';
    }).join('');

    // 重點：租借明細補齊租期、押金、取還門市與付款方式，供兩個會員中心共用。
    openDetailModal('預約與租借詳情 ' + (order.orderNumber || order.id), ''
      + '<div class="bk-detail-head">'
      + '<div class="bk-detail-date">' + escapeHtml(formatDate(order.createdAt)) + '</div>'
      + '<span class="bk-status-badge ' + status.cls + '">' + escapeHtml(status.label) + '</span>'
      + '</div>'
      + '<div class="bk-detail-section-title"><i class="bi bi-tent"></i> 租借品項</div>'
      + itemsHtml
      + '<hr class="bk-detail-sep">'
      + '<div class="bk-detail-rows">'
      + '<div class="bk-detail-row"><span>租借費用</span><span>' + formatMoney(order.subtotal) + '</span></div>'
      + '<div class="bk-detail-row"><span>押金</span><span>' + formatMoney(order.deposit) + '</span></div>'
      + '<div class="bk-detail-row bk-detail-row--total"><span>訂單總計</span><span>' + formatMoney(order.total) + '</span></div>'
      + '</div>'
      + '<div class="bk-detail-note">租借期間：' + escapeHtml(order.rentalStart || '--') + ' - ' + escapeHtml(order.rentalEnd || '--') + '</div>'
      + '<div class="bk-detail-note">取貨 / 還貨：' + escapeHtml(order.pickupStore || '--') + ' / ' + escapeHtml(order.returnStore || '--') + '</div>'
      + '<div class="bk-detail-note"><i class="bi bi-credit-card"></i> 付款方式：' + escapeHtml(getPaymentLabel(order.payment)) + '</div>'
      + (order.cancelReason ? '<div class="bk-detail-note bk-detail-row--danger">取消原因：' + escapeHtml(order.cancelReason) + '</div>' : '')
      + buildLineSupportLink('詢問租借'));
  };

  window.openMcOrderDetail = window.openOrderDetail;
  window.openMcBookingDetail = window.openRentalOrderDetail;

  function buildLineSupportLink(label) {
    return '<div class="bk-detail-support">'
      + '<a href="https://line.me/R/ti/p/@yuruicamp" target="_blank" rel="noopener">'
      + '<i class="bi bi-chat-dots"></i> 使用 LINE ' + escapeHtml(label)
      + '</a>'
      + '</div>';
  }

  function renderMemberRewardPoints(points) {
    var pointsEl = document.getElementById('cardPoints');
    if (!pointsEl) return;

    var safePoints = Number.isFinite(Number(points)) ? Number(points) : 0;
    pointsEl.textContent = '回饋點數：' + safePoints.toLocaleString('zh-TW') + ' 點';
  }

  async function refreshMemberRewardPoints() {
    // 重點：點數以 users.json 為唯一顯示來源，讓結帳後更新 JSON 時會員卡可定時同步。
    var users = applyUserPointDeltas(await fetchJson(DATA_PATHS.users, []));
    var user = selectUser(users);
    state.users = users;
    state.user = user || state.user;
    renderMemberRewardPoints(state.user && state.user.points);
  }

  function initMemberRewardPoints() {
    renderMemberRewardPoints(state.user && state.user.points);
    window.clearInterval(state.pointsTimer);
    state.pointsTimer = window.setInterval(refreshMemberRewardPoints, Number(config.pointsRefreshMs) || 5000);
  }

  function applyProfileData() {
    var user = state.user || {};
    var saved = getSavedProfile();
    var loginUser = getLoginUser() || {};
    var displayName = saved.name || loginUser.name || user.name || '露友';
    var displayEmail = loginUser.email || user.email || saved.email || 'camper@example.com';

    setText('mcAvatar', displayName.charAt(0).toUpperCase());
    setText('mcName', displayName);
    setText('mcEmail', displayEmail);
    setText('cardName', displayName);
    setText('cardTier', user.tierName || '探險家');
    setText('cardSince', '加入日期：' + (user.joinDate || user.joinedAt || '2026-01-01'));
    renderTierProgress(user);

    setInputValue('profileName', saved.name || user.name || displayName);
    setInputValue('profilePhone', saved.phone || user.phone || '0912-345-678');
    setInputValue('profileEmail', displayEmail);
    setInputValue('profileBirthday', user.birthday || saved.birthday || '1990-06-15');
    setInputValue('profileAddress', saved.address || user.address || '台北市信義區信義路五段 100 號');

    renderMemberRewardPoints(user.points);
    syncPreferenceTags(getStoredPreferenceValues());
  }

  function setText(id, value) {
    var el = document.getElementById(id);
    if (el) el.textContent = value;
  }

  function setInputValue(id, value) {
    var el = document.getElementById(id);
    if (el) el.value = value || '';
  }

  function syncPreferenceTags(preferences) {
    var selected = new Set(normalizePreferenceValues(preferences));
    document.querySelectorAll('#prefTags .survey-tag').forEach(function (tag) {
      tag.classList.toggle('active', selected.has(tag.dataset.value));
    });
  }

  window.syncMemberPreferenceTags = function (preferences) {
    var selectedPrefs = normalizePreferenceObject(preferences);
    syncPreferenceTags(selectedPrefs);

    // 重點：外部問卷同步進來時，也保留 styles / equipment 分類結構。
    persistPreferenceObject(selectedPrefs);
  };

  function initPreferenceTags() {
    syncPreferenceTags(getStoredPreferenceValues());
    document.querySelectorAll('#prefTags .survey-tag').forEach(function (tag) {
      if (tag.dataset.prefToggleBound === 'true') return;
      tag.dataset.prefToggleBound = 'true';
      tag.addEventListener('click', function () {
        var willBeActive = !tag.classList.contains('active');
        var preferences = updatePreferenceObjectValue(getStoredPreferenceObject(), tag.dataset.value, willBeActive);

        // 重點：先寫入資料再更新畫面，避免下一次重繪把 active 狀態復原。
        persistPreferenceObject(preferences);
        syncPreferenceTags(preferences);
      });
    });
  }

  function getInputValue(id) {
    var el = document.getElementById(id);
    return el ? el.value.trim() : '';
  }

  function initProfileForm() {
    var form = document.getElementById('profileForm');
    if (!form || form.dataset.bound === 'true') return;
    form.dataset.bound = 'true';

    form.addEventListener('submit', function (event) {
      event.preventDefault();
      var selectedPreferences = getActivePreferenceObject();
      var profileData = {
        name: getInputValue('profileName'),
        phone: getInputValue('profilePhone'),
        email: (state.user && state.user.email) || (getLoginUser() && getLoginUser().email) || getInputValue('profileEmail'),
        birthday: (state.user && state.user.birthday) || getInputValue('profileBirthday'),
        address: getInputValue('profileAddress'),
        preferences: selectedPreferences
      };

      // 重點：Email 與生日為唯讀資料，儲存時保留原始值，避免前端表單覆寫會員識別資料。
      localStorage.setItem('yurui_profile', JSON.stringify(profileData));
      updateLoginStorage(profileData);
      persistPreferenceObject(selectedPreferences);

      if (window.AppState) {
        window.AppState.preferences = selectedPreferences;
        if (typeof window.saveAppState === 'function') window.saveAppState();
      }

      applyProfileData();
      showMcToast('個人資料已儲存', 'success');
    });
  }

  function updateLoginStorage(profileData) {
    var keys = [config.authStorageKey, config.fallbackAuthStorageKey, 'currentUser', 'yuruiUser'].filter(Boolean);
    keys.forEach(function (key) {
      var user = getStoredUserFromKey(key);
      if (!user) return;
      user.name = profileData.name || user.name;
      user.email = profileData.email || user.email;
      localStorage.setItem(key, JSON.stringify(user));
    });

    if (window.AppState && window.AppState.currentUser) {
      window.AppState.currentUser.name = profileData.name || window.AppState.currentUser.name;
      window.AppState.currentUser.email = profileData.email || window.AppState.currentUser.email;
      if (typeof window.updateNavbarLoginState === 'function') window.updateNavbarLoginState();
    }
  }

  function isCouponExpired(coupon) {
    if (coupon.used) return true;
    if (!coupon.expiry) return false;
    var expiry = new Date(coupon.expiry + 'T23:59:59');
    return Number.isFinite(expiry.getTime()) && expiry < new Date();
  }

  function formatCoupon(coupon) {
    var isPercent = coupon.type === 'percent';
    var discountVal = isPercent ? coupon.discount + '%' : Number(coupon.discount || 0).toLocaleString('zh-TW');
    var discountUnit = isPercent ? 'OFF' : '元';
    var title = isPercent ? '會員折扣券' : '現金折抵券';
    var condition = coupon.minOrder ? '滿 NT$ ' + Number(coupon.minOrder).toLocaleString('zh-TW') + ' 可使用' : '不限金額';
    return {
      code: coupon.code,
      expired: isCouponExpired(coupon),
      discountVal: discountVal,
      discountUnit: discountUnit,
      title: title,
      condition: condition,
      expiry: coupon.expiry ? coupon.expiry + ' 到期' : '無期限'
    };
  }

  function renderCoupons() {
    var activeContainer = document.getElementById('activeCoupons');
    var expiredContainer = document.getElementById('expiredCoupons');
    if (!activeContainer || !expiredContainer) return;

    var coupons = ((state.user && state.user.coupons) || []).map(formatCoupon);
    var active = coupons.filter(function (coupon) { return !coupon.expired; });
    var expired = coupons.filter(function (coupon) { return coupon.expired; });

    activeContainer.innerHTML = active.length
      ? active.map(buildCouponHtml).join('')
      : '<div class="rec-empty">目前沒有可使用的折價券</div>';

    expiredContainer.innerHTML = expired.length
      ? expired.map(buildCouponHtml).join('')
      : '<div class="rec-empty">目前沒有已失效的折價券</div>';
  }

  function buildCouponHtml(coupon) {
    return '<div class="coupon-ticket' + (coupon.expired ? ' expired' : '') + '">'
      + '<div class="coupon-left">'
      + '<div class="coupon-discount-val">' + escapeHtml(coupon.discountVal) + '</div>'
      + '<div class="coupon-discount-unit">' + escapeHtml(coupon.discountUnit) + '</div>'
      + '</div>'
      + '<div class="coupon-sep"></div>'
      + '<div class="coupon-right">'
      + '<div class="coupon-title">' + escapeHtml(coupon.title) + '</div>'
      + '<div class="coupon-condition">' + escapeHtml(coupon.condition) + '</div>'
      + '<div class="coupon-expiry"><i class="bi bi-clock"></i> ' + escapeHtml(coupon.expiry) + '</div>'
      + '<div class="coupon-code-row">'
      + '<span class="coupon-code">' + escapeHtml(coupon.code) + '</span>'
      + (!coupon.expired ? '<button class="copy-btn" type="button" data-copy-coupon="' + escapeHtml(coupon.code) + '">複製</button>' : '')
      + '</div>'
      + '</div>'
      + '</div>';
  }

  window.copyMcCouponCode = function (code) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(code)
        .then(function () { showMcToast('已複製折扣碼：' + code, 'success'); })
        .catch(function () { fallbackCopy(code); });
      return;
    }
    fallbackCopy(code);
  };

  function fallbackCopy(code) {
    var el = document.createElement('textarea');
    el.value = code;
    el.style.cssText = 'position:fixed;opacity:0;';
    document.body.appendChild(el);
    el.select();
    document.execCommand('copy');
    document.body.removeChild(el);
    showMcToast('已複製折扣碼：' + code, 'success');
  }

  /** 重點：建立通知可辨識的訂單編號清單，讓訊息中的編號可導向對應明細。 */
  function getNotificationOrderTokens() {
    var tokens = [];
    state.orders.forEach(function (order) {
      [order.id, order.orderNumber].filter(Boolean).forEach(function (token) {
        tokens.push({ token: String(token), type: 'purchase', id: order.id });
      });
    });
    state.rentalOrders.forEach(function (order) {
      [order.id, order.orderNumber].filter(Boolean).forEach(function (token) {
        tokens.push({ token: String(token), type: 'rental', id: order.id });
      });
    });
    return tokens.sort(function (a, b) { return b.token.length - a.token.length; });
  }

  /** 重點：通知文字會保留原文順序，只將確定存在的訂單 / 預約編號轉成可點擊明細連結。 */
  function linkNotificationText(value) {
    var text = String(value == null ? '' : value);
    var tokens = getNotificationOrderTokens();
    var matches = [];

    tokens.forEach(function (item) {
      var start = text.indexOf(item.token);
      while (start !== -1) {
        var end = start + item.token.length;
        var overlaps = matches.some(function (match) {
          return start < match.end && end > match.start;
        });
        if (!overlaps) matches.push({ start: start, end: end, item: item });
        start = text.indexOf(item.token, end);
      }
    });

    if (!matches.length) return escapeHtml(text);

    matches.sort(function (a, b) { return a.start - b.start; });
    var html = '';
    var cursor = 0;
    matches.forEach(function (match) {
      html += escapeHtml(text.slice(cursor, match.start));
      html += '<button class="notif-item__link" type="button" data-notification-'
        + (match.item.type === 'rental' ? 'rental' : 'order')
        + '-detail="' + escapeHtml(match.item.id) + '">'
        + escapeHtml(text.slice(match.start, match.end))
        + '</button>';
      cursor = match.end;
    });
    return html + escapeHtml(text.slice(cursor));
  }

  function renderNotifications() {
    var container = document.getElementById('notificationList');
    if (!container) return;

    var notifications = (state.user && state.user.notifications) || [];
    if (!notifications.length) {
      container.innerHTML = '<div class="rec-empty">目前沒有通知</div>';
      return;
    }

    // 重點：通知讀取後只更新畫面內狀態，不回寫 JSON，避免靜態資料檔被瀏覽器直接改寫。
    container.innerHTML = notifications.map(function (notification) {
      var read = Boolean(notification.read);
      return '<div class="notif-item" id="notif-' + escapeHtml(notification.id) + '" data-notif-id="' + escapeHtml(notification.id) + '">'
        + '<div class="notif-item__dot' + (read ? ' read' : '') + '"></div>'
        + '<div>'
        + '<div class="notif-item__title">' + linkNotificationText(notification.title) + '</div>'
        + '<div class="notif-item__body">' + linkNotificationText(notification.message) + '</div>'
        + '<div class="notif-item__date">' + escapeHtml(notification.time) + '</div>'
        + '</div>'
        + '</div>';
    }).join('');
  }

  function renderRecentActivity() {
    var container = document.getElementById('recentActivity');
    if (!container) return;

    var activities = [];
    state.orders.slice(0, 3).forEach(function (order) {
      activities.push({
        date: order.createdAt,
        title: '訂單 ' + (order.orderNumber || order.id) + ' ' + getStatusInfo(order.status).label,
        type: 'purchase',
        id: order.id
      });
    });
    state.rentalOrders.slice(0, 2).forEach(function (order) {
      activities.push({
        date: order.createdAt,
        title: '預約與租借 ' + (order.orderNumber || order.id) + ' ' + getRentalStatusInfo(order.status).label,
        type: 'rental',
        id: order.id
      });
    });
    ((state.user && state.user.notifications) || []).slice(0, 2).forEach(function (notification) {
      activities.push({
        date: notification.time,
        title: notification.title
      });
    });

    activities.sort(function (a, b) {
      return String(b.date || '').localeCompare(String(a.date || ''));
    });

    if (!activities.length) {
      container.innerHTML = '<div class="rec-empty">目前沒有最近活動</div>';
      return;
    }

    container.innerHTML = activities.slice(0, 4).map(function (activity) {
      var detailAttr = activity.type === 'rental'
        ? ' data-notification-rental-detail="' + escapeHtml(activity.id) + '"'
        : (activity.type === 'purchase' ? ' data-notification-order-detail="' + escapeHtml(activity.id) + '"' : '');
      var titleHtml = detailAttr
        ? '<button class="mc-activity-item__title mc-activity-item__title--button" type="button"' + detailAttr + '>' + escapeHtml(activity.title) + '</button>'
        : '<div class="mc-activity-item__title">' + escapeHtml(activity.title) + '</div>';
      return '<div class="mc-activity-item">'
        + '<div>'
        + titleHtml
        + '<div class="mc-activity-item__date">' + escapeHtml(formatDate(activity.date)) + '</div>'
        + '</div>'
        + '</div>';
    }).join('');
  }

  function updateStats() {
    var activeCoupons = ((state.user && state.user.coupons) || []).filter(function (coupon) {
      return !isCouponExpired(coupon);
    }).length;
    var unread = ((state.user && state.user.notifications) || []).filter(function (item) {
      return !item.read;
    }).length;
    var pendingOrders = state.orders.filter(function (order) {
      return ['paid', 'unshipped', 'shipped'].includes(normalizeFilterValue('purchase', order.status));
    }).length;
    var upcomingRentals = state.rentalOrders.filter(function (order) {
      return ['paid', 'pending', 'confirmed'].includes(normalizeFilterValue('rental', order.status));
    }).length;

    setText('statOrders', String(pendingOrders));
    setText('statBookings', String(upcomingRentals));
    setText('statCoupons', String(activeCoupons));
    setText('statUnread', String(unread));
  }

  function initCouponTabs() {
    document.querySelectorAll('.rec-tab[data-coupon-tab]').forEach(function (tab) {
      if (tab.dataset.bound === 'true') return;
      tab.dataset.bound = 'true';
      tab.addEventListener('click', function () {
        var selected = tab.dataset.couponTab;
        document.querySelectorAll('.rec-tab[data-coupon-tab]').forEach(function (item) {
          item.classList.toggle('active', item.dataset.couponTab === selected);
        });
        var active = document.getElementById('activeCoupons');
        var expired = document.getElementById('expiredCoupons');
        if (active) {
          active.hidden = selected !== 'active';
          active.style.display = selected === 'active' ? '' : 'none';
        }
        if (expired) {
          expired.hidden = selected !== 'expired';
          expired.style.display = selected === 'expired' ? '' : 'none';
        }
      });
    });
  }

  function initOrderStatusTabs() {
    document.querySelectorAll('.order-status-tabs[data-order-status-tabs]').forEach(function (container) {
      if (container.dataset.bound === 'true') return;
      container.dataset.bound = 'true';

      container.addEventListener('click', function (event) {
        var tab = event.target.closest('.order-status-tab[data-filter]');
        if (!tab || !container.contains(tab)) return;

        var orderType = container.dataset.orderStatusTabs === 'rental' ? 'rental' : 'purchase';
        state.activeFilters[orderType] = tab.dataset.filter || 'all';

        if (orderType === 'rental') {
          renderOrderStatusTabs('rental', state.rentalOrders);
          renderRentalOrders();
          return;
        }

        renderOrderStatusTabs('purchase', state.orders);
        renderPurchaseOrders();
      });
    });
  }

  function initDynamicActionButtons() {
    if (document.body.dataset.memberCenterActionsBound === 'true') return;
    document.body.dataset.memberCenterActionsBound = 'true';

    // 重點：所有動態按鈕改用 data-* 事件代理，partial 被兩個頁面載入時不需要 inline onclick。
    document.addEventListener('click', function (event) {
      var purchaseBtn = event.target.closest('[data-order-detail]');
      if (purchaseBtn) {
        window.openOrderDetail(purchaseBtn.dataset.orderDetail);
        return;
      }

      var rentalBtn = event.target.closest('[data-rental-detail]');
      if (rentalBtn) {
        window.openRentalOrderDetail(rentalBtn.dataset.rentalDetail);
        return;
      }

      var reviewBtn = event.target.closest('[data-review-order]');
      if (reviewBtn) {
        window.openReviewModal(reviewBtn.dataset.reviewOrder, reviewBtn.dataset.reviewItem);
        return;
      }

      var copyBtn = event.target.closest('[data-copy-coupon]');
      if (copyBtn) {
        window.copyMcCouponCode(copyBtn.dataset.copyCoupon);
        return;
      }

      var notificationOrderBtn = event.target.closest('[data-notification-order-detail]');
      if (notificationOrderBtn) {
        openRecordDetailFromNotification('purchase', notificationOrderBtn.dataset.notificationOrderDetail);
        return;
      }

      var notificationRentalBtn = event.target.closest('[data-notification-rental-detail]');
      if (notificationRentalBtn) {
        openRecordDetailFromNotification('rental', notificationRentalBtn.dataset.notificationRentalDetail);
      }
    });
  }

  /** 重點：通知與最近活動點擊編號時，先切到紀錄分頁再開啟對應明細。 */
  function openRecordDetailFromNotification(orderType, orderId) {
    switchMemberPanel('records');
    switchRecordTab(orderType === 'rental' ? 'rental' : 'purchase');
    if (orderType === 'rental') {
      window.openRentalOrderDetail(orderId);
      return;
    }
    window.openOrderDetail(orderId);
  }

  /** 重點：抽出紀錄內部 tab 切換，通知連結與使用者點擊 tab 共用同一流程。 */
  function switchRecordTab(rec) {
    document.querySelectorAll('.rec-tab[data-rec]').forEach(function (item) {
      item.classList.toggle('active', item.dataset.rec === rec);
    });
    document.querySelectorAll('.rec-panel[data-rec-panel]').forEach(function (panel) {
      panel.classList.toggle('active', panel.dataset.recPanel === rec);
    });
  }

  function initRecordTabs() {
    document.querySelectorAll('.rec-tab[data-rec]').forEach(function (tab) {
      if (tab.dataset.bound === 'true') return;
      tab.dataset.bound = 'true';

      tab.addEventListener('click', function () {
        switchRecordTab(tab.dataset.rec);
      });
    });
  }

  /** 重點：抽出會員中心主分頁切換，URL、導覽列與通知深連結共用同一流程。 */
  function switchMemberPanel(tab) {
    var normalizedTab = tab === 'orders' ? 'records' : tab;
    document.querySelectorAll('.mc-nav-item').forEach(function (item) {
      item.classList.toggle('active', item.dataset.tab === normalizedTab);
    });
    document.querySelectorAll('.mc-tab-mobile').forEach(function (button) {
      button.classList.toggle('active', button.dataset.tab === normalizedTab);
    });
    document.querySelectorAll('.mc-panel').forEach(function (panel) {
      panel.classList.toggle('active', panel.dataset.panel === normalizedTab);
    });
  }

  function initPanelTabs() {
    document.querySelectorAll('.mc-nav-item').forEach(function (item) {
      if (item.dataset.bound === 'true') return;
      item.dataset.bound = 'true';
      item.addEventListener('click', function () {
        switchMemberPanel(item.dataset.tab);
      });
    });

    document.querySelectorAll('.mc-tab-mobile').forEach(function (button) {
      if (button.dataset.bound === 'true') return;
      button.dataset.bound = 'true';
      button.addEventListener('click', function () {
        switchMemberPanel(button.dataset.tab);
      });
    });

    var urlTab = new URLSearchParams(window.location.search).get('tab');
    if (urlTab) switchMemberPanel(urlTab);
  }

  function applyLoginState() {
    var guard = document.getElementById('mcLoginGuard');
    var page = document.getElementById('mcPage');
    var loggedIn = isLoggedIn();

    if (guard) {
      guard.hidden = loggedIn;
      guard.style.display = loggedIn ? 'none' : 'flex';
    }
    if (page) {
      page.hidden = !loggedIn;
      page.style.display = loggedIn ? '' : 'none';
    }

    if (loggedIn) {
      applyProfileData();
    }
  }

  function initLoginGuard() {
    applyLoginState();

    var guardLoginBtn = document.getElementById('guardLoginBtn');
    if (guardLoginBtn && guardLoginBtn.dataset.bound !== 'true') {
      guardLoginBtn.dataset.bound = 'true';
      guardLoginBtn.addEventListener('click', function () {
        if (typeof window.openModal === 'function') {
          window.openModal('loginModal');
        }
      });
    }

    window.clearInterval(state.loginTimer);
    state.loginTimer = window.setInterval(function () {
      applyLoginState();
    }, 1500);
  }

  function initNotificationActions() {
    var list = document.getElementById('notificationList');
    if (list && list.dataset.bound !== 'true') {
      list.dataset.bound = 'true';
      list.addEventListener('click', function (event) {
        var item = event.target.closest('.notif-item[data-notif-id]');
        if (!item || !state.user) return;

        var notification = (state.user.notifications || []).find(function (entry) {
          return entry.id === item.dataset.notifId;
        });
        if (notification) notification.read = true;
        renderNotifications();
        updateStats();
      });
    }

    var markAllBtn = document.getElementById('markAllReadBtn');
    if (markAllBtn && markAllBtn.dataset.bound !== 'true') {
      markAllBtn.dataset.bound = 'true';
      markAllBtn.addEventListener('click', function () {
        if (state.user && Array.isArray(state.user.notifications)) {
          state.user.notifications.forEach(function (item) { item.read = true; });
        }
        renderNotifications();
        updateStats();
      });
    }
  }

  function initModalClose() {
    var overlay = document.getElementById('orderDetailOverlay');
    var closeBtn = document.getElementById('orderDetailClose');
    if (closeBtn && closeBtn.dataset.bound !== 'true') {
      closeBtn.dataset.bound = 'true';
      closeBtn.addEventListener('click', closeDetailModal);
    }
    if (overlay && overlay.dataset.bound !== 'true') {
      overlay.dataset.bound = 'true';
      overlay.addEventListener('click', function (event) {
        if (event.target === overlay) closeDetailModal();
      });
    }
  }

  function updateReviewStars(rating) {
    state.review.rating = Number(rating) || 0;
    document.querySelectorAll('.mc-review-star').forEach(function (button) {
      button.classList.toggle('is-active', Number(button.dataset.reviewRating) <= state.review.rating);
    });
  }

  window.openReviewModal = function (orderId, itemName) {
    var overlay = document.getElementById('reviewOverlay');
    if (!overlay) return;

    state.review.orderId = orderId;
    state.review.itemName = itemName || '';
    state.review.rating = 0;
    setText('reviewProductName', itemName || '商品評價');
    setInputValue('reviewContent', '');
    updateReviewStars(0);
    overlay.classList.add('is-open');
    document.body.style.overflow = 'hidden';
  };

  function closeReviewModal() {
    var overlay = document.getElementById('reviewOverlay');
    if (overlay) overlay.classList.remove('is-open');
    document.body.style.overflow = '';
  }

  function initReviewModal() {
    var overlay = document.getElementById('reviewOverlay');
    var closeBtn = document.getElementById('reviewClose');
    var form = document.getElementById('reviewForm');

    document.querySelectorAll('.mc-review-star').forEach(function (button) {
      if (button.dataset.bound === 'true') return;
      button.dataset.bound = 'true';
      button.addEventListener('click', function () {
        updateReviewStars(button.dataset.reviewRating);
      });
    });

    if (closeBtn && closeBtn.dataset.bound !== 'true') {
      closeBtn.dataset.bound = 'true';
      closeBtn.addEventListener('click', closeReviewModal);
    }
    if (overlay && overlay.dataset.bound !== 'true') {
      overlay.dataset.bound = 'true';
      overlay.addEventListener('click', function (event) {
        if (event.target === overlay) closeReviewModal();
      });
    }
    if (form && form.dataset.bound !== 'true') {
      form.dataset.bound = 'true';
      form.addEventListener('submit', function (event) {
        event.preventDefault();
        if (!state.review.orderId || !state.review.rating) {
          showMcToast('請選擇評分', 'warning');
          return;
        }

        // 重點：靜態 JSON 無法直接由瀏覽器寫回，評價結果以 localStorage 保存並即時更新訂單畫面。
        var reviews = getStoredReviews();
        reviews.push({
          orderId: state.review.orderId,
          itemName: state.review.itemName,
          rating: state.review.rating,
          content: getInputValue('reviewContent'),
          createdAt: new Date().toISOString()
        });
        localStorage.setItem(REVIEW_STORAGE_KEY, JSON.stringify(reviews));

        var order = state.orders.find(function (item) { return item.id === state.review.orderId; });
        if (order) order.reviewed = true;
        renderPurchaseOrders();
        closeReviewModal();
        showMcToast('評價已送出', 'success');
      });
    }
  }

  function initGlobalEvents() {
    if (window.__memberCenterGlobalEventsBound) return;
    window.__memberCenterGlobalEventsBound = true;

    window.addEventListener('storage', function (event) {
      if (['currentUser', 'yuruiUser', 'isLoggedIn', 'yurui_profile', 'preferences', MOCK_USER_POINT_DELTAS_STORAGE_KEY, MOCK_ORDERS_STORAGE_KEY].includes(event.key)) {
        applyLoginState();
        if (event.key === MOCK_USER_POINT_DELTAS_STORAGE_KEY) refreshMemberRewardPoints();
        if (event.key === MOCK_ORDERS_STORAGE_KEY) loadMemberData();
      }
    });

    window.addEventListener('yurui:preferences-updated', function (event) {
      window.syncMemberPreferenceTags(event.detail || []);
    });

    document.addEventListener('keydown', function (event) {
      if (event.key !== 'Escape') return;
      closeDetailModal();
      closeReviewModal();
    });
  }

  function setConfigLinks() {
    document.querySelectorAll('[data-member-center-home-link]').forEach(function (link) {
      link.setAttribute('href', config.homeHref || 'home.html');
    });
  }

  async function loadMemberData() {
    var results = await Promise.all([
      fetchJson(DATA_PATHS.users, []),
      fetchJson(DATA_PATHS.orders, []),
      fetchJson(DATA_PATHS.rentalOrders, [])
    ]);
    var memberId = getCurrentMemberId();

    state.users = applyUserPointDeltas(results[0]);
    state.user = selectUser(state.users);
    state.orders = mergeOrders(results[1], readStorageArray(MOCK_ORDERS_STORAGE_KEY)).filter(function (order) {
      return !order.userId || order.userId === memberId || (state.user && order.userId === state.user.id);
    });
    state.rentalOrders = (Array.isArray(results[2]) ? results[2] : []).filter(function (order) {
      return !order.userId || order.userId === memberId || (state.user && order.userId === state.user.id);
    });

    applyProfileData();
    renderOrderStatusTabs('purchase', state.orders);
    renderOrderStatusTabs('rental', state.rentalOrders);
    renderPurchaseOrders();
    renderRentalOrders();
    renderCoupons();
    renderNotifications();
    renderRecentActivity();
    updateStats();
    applyLoginState();
  }

  function initAll() {
    state.root = document.getElementById('memberCenterComponentRoot');
    if (!state.root) return;

    setConfigLinks();
    initPanelTabs();
    initRecordTabs();
    initCouponTabs();
    initOrderStatusTabs();
    initDynamicActionButtons();
    initPreferenceTags();
    initProfileForm();
    initNotificationActions();
    initModalClose();
    initReviewModal();
    initLoginGuard();
    initGlobalEvents();

    // 重點：初始化時一次載入 users、orders、rentalOrders，讓兩個頁面共用同一個資料渲染流程。
    loadMemberData();
    initMemberRewardPoints();
  }

  window.initMemberCenterComponent = function () {
    var currentRoot = document.getElementById('memberCenterComponentRoot');
    if (!currentRoot) return;

    if (state.initialized && state.root === currentRoot) {
      loadMemberData();
      applyLoginState();
      return;
    }

    state.initialized = true;
    initAll();
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () {
      if (document.getElementById('memberCenterComponentRoot')) {
        window.initMemberCenterComponent();
      }
    });
  } else if (document.getElementById('memberCenterComponentRoot')) {
    window.initMemberCenterComponent();
  }
=======
  var aliases = { purchase: { processing: 'unshipped', cod: 'paid' }, rental: { processing: 'pending', shipped: 'confirmed', delivered: 'completed', cancelled: 'refunded' } };
  var stylePrefs = ['glamping','backpacking','family','solo','hiking','car-camping','ultralight','base-camp'];
  var gearPrefs = ['tent','sleeping-bag','backpack','cooking','lighting','clothing','chair','navigation','safety','photography'];
  var state = { user: null, orders: [], rentalOrders: [], filters: { purchase: 'all', rental: 'all' }, review: { orderId: '', itemName: '', rating: 0 }, lastFocus: null, initialized: false };

  function path(file) { return String(cfg.dataBasePath || '').replace(/\/+$/, '') + '/' + file; }
  function parse(value, fallback) { try { return value ? JSON.parse(value) : fallback; } catch { return fallback; } }
  function arrays(key) { var value = parse(localStorage.getItem(key), []); return Array.isArray(value) ? value : []; }
  function html(value) { return String(value == null ? '' : value).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;'); }
  function text(id, value) { var el = document.getElementById(id); if (el) el.textContent = value == null ? '' : String(value); }
  function input(id, value) { var el = document.getElementById(id); if (el) el.value = value == null ? '' : String(value); }
  function money(value) { return 'NT$ ' + Number(value || 0).toLocaleString('zh-TW'); }
  function toast(message, type) { if (typeof window.showToast === 'function') window.showToast(message, type || 'info'); else console.log(message); }
  async function json(file, fallback) { try { var r = await fetch(path(file), { cache: 'no-store' }); if (!r.ok) throw new Error(r.status); return await r.json(); } catch { return fallback; } }

  function fallbackUsers() { return [{ id:'user-001', name:'Yurui Camper', email:'member@yuruicamp.test', phone:'0912-345-678', address:'台北市中山區露營路 100 號', birthday:'1995-01-01', tierName:'Explorer', joinDate:'2025-01-15', points:760, nextTierSpend:30000, preferences:{ styles:['backpacking','hiking'], equipment:['tent','backpack'] }, coupons:[{code:'WELCOME100',discount:100,type:'fixed',minOrder:500,expiry:'2026-12-31'},{code:'SUMMER10',discount:10,type:'percent',minOrder:1000,expiry:'2026-08-31'}], notifications:[{id:'n1',title:'訂單已成立',message:'你的訂單正在準備出貨。',time:'2026-05-13',read:false},{id:'n2',title:'折價券提醒',message:'記得在期限前使用會員折價券。',time:'2026-05-10',read:false}] }]; }
  function fallbackOrders() { return [{ id:'ord-001', userId:'user-001', orderNumber:'#ORD-20260101', createdAt:'2026-01-01', status:'delivered', paymentStatus:'paid', subtotal:3797, total:3797, points:380, canReview:true, items:[{name:'兩人帳篷',price:2999,quantity:1,image:'https://picsum.photos/seed/tent1/80/80'}] },{ id:'ord-002', userId:'user-001', orderNumber:'#ORD-20260310', createdAt:'2026-03-10', status:'unshipped', paymentStatus:'paid', subtotal:4997, discount:500, total:4497, points:500, items:[{name:'防風外套',price:3599,quantity:1,image:'https://picsum.photos/seed/jacket1/80/80'}] }]; }
  function fallbackRentals() { return [{ id:'rent-001', userId:'user-001', orderNumber:'#RENT-20260412', createdAt:'2026-04-12', rentalStart:'2026-04-18', rentalEnd:'2026-04-20', pickupStore:'台北門市', returnStore:'台北門市', status:'completed', paymentStatus:'paid', subtotal:1320, deposit:2000, total:3320, items:[{name:'露營帳篷',price:480,quantity:1,image:'https://picsum.photos/seed/rent-tent/80/80'}] }]; }
  function loginUser() { if (window.AppState && window.AppState.isLoggedIn && window.AppState.currentUser) return window.AppState.currentUser; var keys=[cfg.authStorageKey,cfg.fallbackAuthStorageKey,'currentUser','yuruiUser'].filter(Boolean); for (var i=0;i<keys.length;i++){ var u=parse(localStorage.getItem(keys[i]),null); if(u) return u; } return localStorage.getItem('isLoggedIn') === 'true' ? { id:'user-001' } : null; }
  function loggedIn() { return cfg.requireLogin === false || Boolean(loginUser()); }
  function norm(type, value) { return (aliases[type] && aliases[type][value]) || value || 'pending'; }
  function meta(type, value) { var normalized = norm(type,value); var row = statusMeta[type].find(function(item){ return item[0] === normalized; }); return row ? {value:row[0],label:row[1],cls:row[2]} : {value:normalized,label:normalized,cls:'isPending'}; }
  function currentMemberId() { var u=loginUser() || {}; return u.id || u.userId || 'user-001'; }
  function mergeOrders(base, mock) { var m=new Map(); (Array.isArray(base)?base:[]).concat(Array.isArray(mock)?mock:[]).forEach(function(o){ if(o && o.id) m.set(o.id,o); }); return Array.from(m.values()); }
  function pointOf(order) { var p=Number(order && order.points); return Number.isFinite(p) ? p : Math.ceil((Number(order && order.subtotal)||0)*0.1); }
  function applyPointDeltas(users) { var deltas = arrays(MOCK_ORDERS_KEY).reduce(function(acc,o){ if(norm('purchase',o && o.status)==='delivered'){ var uid=o.userId||'user-001'; acc[uid]=(Number(acc[uid])||0)+pointOf(o); } return acc; }, parse(localStorage.getItem(MOCK_POINTS_KEY),{}) || {}); return users.map(function(u){ return Object.assign({},u,{points:(Number(u.points)||0)+(Number(deltas[u.id])||0)}); }); }
  function prefValues(p){ if(Array.isArray(p)) return p.filter(Boolean); if(typeof p==='string'&&p) return [p]; if(!p||typeof p!=='object') return []; return [].concat(p.styles||[]).concat(p.equipment||[]).filter(Boolean); }
  function prefObject(values){ var out={styles:[],equipment:[]}; prefValues(values).forEach(function(v){ var g=stylePrefs.includes(v)?'styles':(gearPrefs.includes(v)?'equipment':null); if(g&&!out[g].includes(v)) out[g].push(v); }); return out; }
  function savedProfile(){ return parse(localStorage.getItem('yurui_profile'),{}) || {}; }
  function selectedPrefs(){ var app=prefValues(window.AppState&&window.AppState.preferences); if(app.length) return app; var profile=prefValues(savedProfile().preferences); if(profile.length) return profile; var local=prefValues(parse(localStorage.getItem('preferences'),{})); return local.length ? local : prefValues(state.user && state.user.preferences); }
  function syncPrefs(values){ var set=new Set(prefValues(values)); document.querySelectorAll('#prefTags .memberPreferenceTag').forEach(function(tag){ var on=set.has(tag.dataset.value); tag.classList.toggle('isSelected',on); tag.setAttribute('aria-pressed',String(on)); }); }
  function savePrefs(values){ var obj=prefObject(values), profile=savedProfile(); profile.preferences=obj; localStorage.setItem('yurui_profile',JSON.stringify(profile)); localStorage.setItem('preferences',JSON.stringify(obj)); if(window.AppState){ window.AppState.preferences=obj; if(typeof window.saveAppState==='function') window.saveAppState(); } }
  function applyProfile(){ if(!state.user) return; var s=savedProfile(); var name=s.name||state.user.name||'Yurui Camper'; var email=state.user.email||s.email||'member@yuruicamp.test'; text('mcAvatar',name.charAt(0).toUpperCase()); text('mcName',name); text('mcEmail',email); text('cardName',name); text('cardTier',state.user.tierName||'Explorer'); text('cardSince','加入日期：'+(state.user.joinDate||'--')); text('cardPoints','回饋點數：'+Number(state.user.points||0).toLocaleString('zh-TW')); input('profileName',name); input('profilePhone',s.phone||state.user.phone||''); input('profileEmail',email); input('profileBirthday',s.birthday||state.user.birthday||''); input('profileAddress',s.address||state.user.address||''); renderProgress(); syncPrefs(selectedPrefs()); }
  function renderProgress(){ var next=Number(state.user&&state.user.nextTierSpend)||0; var spent=state.orders.reduce(function(t,o){ return norm('purchase',o.status)==='delivered'?t+(Number(o.subtotal)||0):t; },0); var progress=next>0?Math.min(Math.round(spent/next*100),100):0; text('nextTierSpend',money(Math.max(next-spent,0))); var bar=document.getElementById('tierProgressBar'); if(bar) bar.style.setProperty('--member-tier-progress',progress+'%'); }
  function itemTitle(items){ var list=Array.isArray(items)?items:[]; if(!list.length) return '商品明細'; if(list.length===1) return list[0].name||'商品明細'; return (list[0].name||'商品明細')+' 等 '+list.length+' 件'; }
  function thumbs(items){ var list=Array.isArray(items)?items:[]; return '<div class="memberOrderThumbs">'+list.slice(0,3).map(function(i){ var src=i.image||'https://picsum.photos/seed/fallback/80/80'; return '<img class="memberOrderThumb" src="'+html(src)+'" alt="'+html(i.name||'商品')+'">'; }).join('')+(list.length>3?'<span class="memberOrderMore">+'+(list.length-3)+'</span>':'')+'</div>'; }
  function renderFilters(type, orders){ var c=document.getElementById(type==='rental'?'rentalOrderStatusTabs':'purchaseOrderStatusTabs'); if(!c) return; var selected=state.filters[type]||'all'; c.innerHTML=statusMeta[type].map(function(row){ var count=row[0]==='all'?orders.length:orders.filter(function(o){ return norm(type,o.status)===row[0]||norm(type,o.paymentStatus)===row[0]; }).length; var on=selected===row[0]; return '<button class="memberOrderFilter'+(on?' isSelected':'')+'" type="button" data-filter="'+html(row[0])+'" aria-pressed="'+String(on)+'">'+html(row[1])+' <span>'+count+'</span></button>'; }).join(''); }
  function filtered(type, orders){ var selected=state.filters[type]||'all'; if(selected==='all') return orders; return orders.filter(function(o){ return norm(type,o.status)===selected||norm(type,o.paymentStatus)===selected; }); }
  function canReview(o){ if(!o||!o.canReview||norm('purchase',o.status)!=='delivered') return false; var reviews=parse(localStorage.getItem(REVIEW_KEY),[]); return !o.reviewed && !reviews.some(function(r){ return r.orderId===o.id; }); }
  function renderOrders(){ var c=document.getElementById('ordersList'); if(!c) return; var orders=filtered('purchase',state.orders); if(!orders.length){ c.innerHTML='<div class="memberEmptyState"><div class="memberEmptyStateIcon"><i class="bi bi-bag-x"></i></div>目前沒有符合條件的購買紀錄</div>'; return; } c.innerHTML=orders.map(function(o){ var st=meta('purchase',o.status), title=itemTitle(o.items); var review=canReview(o)?'<button class="memberOrderDetailButton" type="button" data-review-order="'+html(o.id)+'" data-review-item="'+html(title)+'">寫評價</button>':''; return '<article class="memberOrderCard" data-order-id="'+html(o.id)+'"><div class="memberOrderInfo"><h3 class="memberOrderTitle">'+html(title)+'</h3><p class="memberOrderMeta">'+html(o.orderNumber||o.id)+' ｜ '+html(o.createdAt||'--')+' ｜ '+((o.items||[]).length||0)+' 件商品</p>'+thumbs(o.items)+'</div><div class="memberOrderSummary"><div class="memberOrderAmount">'+money(o.total)+'</div><span class="memberOrderStatus '+st.cls+'">'+html(st.label)+'</span><button class="memberOrderDetailButton" type="button" data-order-detail="'+html(o.id)+'">查看明細</button>'+review+'</div></article>'; }).join(''); }
  function renderRentals(){ var c=document.getElementById('rentalOrdersList'); if(!c) return; var orders=filtered('rental',state.rentalOrders); if(!orders.length){ c.innerHTML='<div class="memberEmptyState"><div class="memberEmptyStateIcon"><i class="bi bi-tent"></i></div>目前沒有符合條件的預約與租借紀錄</div>'; return; } c.innerHTML=orders.map(function(o){ var st=meta('rental',o.status); return '<article class="memberOrderCard" data-rental-order-id="'+html(o.id)+'"><div class="memberOrderInfo"><h3 class="memberOrderTitle">'+html(itemTitle(o.items))+'</h3><p class="memberOrderMeta">'+html(o.orderNumber||o.id)+' ｜ '+html(o.rentalStart||'--')+' - '+html(o.rentalEnd||'--')+' ｜ '+html(o.pickupStore||'--')+' / '+html(o.returnStore||'--')+'</p>'+thumbs(o.items)+'</div><div class="memberOrderSummary"><div class="memberOrderAmount">'+money(o.total)+'</div><span class="memberOrderStatus '+st.cls+'">'+html(st.label)+'</span><button class="memberOrderDetailButton" type="button" data-rental-detail="'+html(o.id)+'">查看明細</button></div></article>'; }).join(''); }
  function couponOff(c){ return c.used || (c.expiry && new Date(c.expiry+'T23:59:59')<new Date()); }
  function renderCoupons(){ var a=document.getElementById('activeCoupons'), e=document.getElementById('expiredCoupons'); if(!a||!e) return; var list=((state.user&&state.user.coupons)||[]).map(function(c){ return Object.assign({},c,{isDisabled:couponOff(c)}); }); function card(c){ var percent=c.type==='percent'; return '<article class="memberCouponCard'+(c.isDisabled?' isDisabled':'')+'"><div class="memberCouponValue"><div class="memberCouponDiscountValue">'+html(c.discount||0)+'</div><div class="memberCouponDiscountUnit">'+(percent?'% OFF':'NT$')+'</div></div><div class="memberCouponDivider" aria-hidden="true"></div><div class="memberCouponContent"><h3 class="memberCouponTitle">'+html(c.code||'會員折價券')+'</h3><p class="memberCouponMeta">滿 '+money(c.minOrder||0)+' 可用</p><p class="memberCouponStatus">期限 '+html(c.expiry||'無期限')+'</p><div class="memberCouponCodeRow"><span class="memberCouponCode">'+html(c.code||'')+'</span>'+(!c.isDisabled?'<button class="memberCopyButton" type="button" data-copy-coupon="'+html(c.code||'')+'">複製</button>':'')+'</div></div></article>'; } var on=list.filter(function(c){return !c.isDisabled;}), off=list.filter(function(c){return c.isDisabled;}); a.innerHTML=on.length?on.map(card).join(''):'<div class="memberEmptyState">目前沒有可使用的折價券</div>'; e.innerHTML=off.length?off.map(card).join(''):'<div class="memberEmptyState">目前沒有已失效的折價券</div>'; }
  function renderNotifications(){ var c=document.getElementById('notificationList'); if(!c) return; var list=(state.user&&state.user.notifications)||[]; if(!list.length){ c.innerHTML='<div class="memberEmptyState">目前沒有通知</div>'; return; } c.innerHTML=list.map(function(n){ var seen=Boolean(n.read); return '<article class="memberNotification'+(seen?' isRead':'')+'" data-notif-id="'+html(n.id)+'"><span class="memberNotificationIndicator" aria-hidden="true"></span><div class="memberNotificationContent"><h3 class="memberNotificationTitle">'+html(n.title||'會員通知')+'</h3><p class="memberNotificationBody">'+html(n.message||'')+'</p><p class="memberNotificationMeta">'+html(n.time||'')+'</p></div></article>'; }).join(''); }
  function renderActivity(){ var c=document.getElementById('recentActivity'); if(!c) return; var list=[]; state.orders.slice(0,3).forEach(function(o){ list.push({date:o.createdAt,title:'訂單 '+(o.orderNumber||o.id)+' '+meta('purchase',o.status).label,type:'purchase',id:o.id}); }); state.rentalOrders.slice(0,2).forEach(function(o){ list.push({date:o.createdAt,title:'租借 '+(o.orderNumber||o.id)+' '+meta('rental',o.status).label,type:'rental',id:o.id}); }); ((state.user&&state.user.notifications)||[]).slice(0,2).forEach(function(n){ list.push({date:n.time,title:n.title}); }); list.sort(function(a,b){ return String(b.date||'').localeCompare(String(a.date||'')); }); c.innerHTML=list.length?list.slice(0,5).map(function(i){ var attr=i.type==='purchase'?' data-notification-order-detail="'+html(i.id)+'"':(i.type==='rental'?' data-notification-rental-detail="'+html(i.id)+'"':''); var title=attr?'<button class="memberActivityTitle memberActivityTitleButton" type="button"'+attr+'>'+html(i.title)+'</button>':'<div class="memberActivityTitle">'+html(i.title)+'</div>'; return '<article class="memberActivityItem">'+title+'<div class="memberActivityDate">'+html(i.date||'--')+'</div></article>'; }).join(''):'<div class="memberEmptyState">目前沒有最近活動</div>'; }
  function updateStats(){ var coupons=((state.user&&state.user.coupons)||[]).filter(function(c){return !couponOff(c);}).length; var unread=((state.user&&state.user.notifications)||[]).filter(function(n){return !n.read;}).length; text('statOrders',state.orders.filter(function(o){return ['paid','unshipped','shipped'].includes(norm('purchase',o.status));}).length); text('statBookings',state.rentalOrders.filter(function(o){return ['paid','pending','confirmed'].includes(norm('rental',o.status));}).length); text('statCoupons',coupons); text('statUnread',unread); }
  function detailRows(order, st, type){ var items=Array.isArray(order.items)?order.items:[]; return '<div class="memberDetailRow"><span>狀態</span><span class="memberOrderStatus '+st.cls+'">'+html(st.label)+'</span></div><div class="memberDetailRow"><span>建立日期</span><span>'+html(order.createdAt||'--')+'</span></div>'+(type==='rental'?'<div class="memberDetailNote">租借期間：'+html(order.rentalStart||'--')+' - '+html(order.rentalEnd||'--')+'</div>':'')+items.map(function(i){return '<div class="memberDetailRow"><span>'+html(i.name||'商品')+' x '+(i.quantity||1)+'</span><span>'+money((i.price||0)*(i.quantity||1))+'</span></div>';}).join('')+(order.discount?'<div class="memberDetailRow memberDetailRowDanger"><span>折扣</span><span>- '+money(order.discount)+'</span></div>':'')+(order.deposit?'<div class="memberDetailRow"><span>押金</span><span>'+money(order.deposit)+'</span></div>':'')+'<div class="memberDetailRow memberDetailRowTotal"><span>總計</span><span>'+money(order.total)+'</span></div>'; }
  function openModal(id){ var o=document.getElementById(id); if(!o) return; state.lastFocus=document.activeElement; o.classList.add('isOpen'); o.setAttribute('aria-hidden','false'); document.body.classList.add('memberModalOpen'); var d=o.querySelector('.memberModalDialog'); if(d) d.focus(); }
  function closeModal(id){ var o=document.getElementById(id); if(!o) return; o.classList.remove('isOpen'); o.setAttribute('aria-hidden','true'); if(!document.querySelector('.memberModalOverlay.isOpen')) document.body.classList.remove('memberModalOpen'); if(state.lastFocus&&typeof state.lastFocus.focus==='function') state.lastFocus.focus(); }
  window.openOrderDetail=function(id){ var o=state.orders.find(function(x){return x.id===id;}); if(!o) return; text('orderDetailTitle','訂單 '+(o.orderNumber||o.id)); var b=document.getElementById('orderDetailBody'); if(b) b.innerHTML=detailRows(o,meta('purchase',o.status),'purchase'); openModal('orderDetailOverlay'); };
  window.openRentalOrderDetail=function(id){ var o=state.rentalOrders.find(function(x){return x.id===id;}); if(!o) return; text('orderDetailTitle','租借 '+(o.orderNumber||o.id)); var b=document.getElementById('orderDetailBody'); if(b) b.innerHTML=detailRows(o,meta('rental',o.status),'rental'); openModal('orderDetailOverlay'); };
  window.openReviewModal=function(id,name){ state.review={orderId:id,itemName:name||'',rating:0}; text('reviewProductName',name||'商品評價'); input('reviewContent',''); stars(0); openModal('reviewOverlay'); };
  function stars(rating){ state.review.rating=Number(rating)||0; document.querySelectorAll('.memberRatingStar').forEach(function(b){ var on=Number(b.dataset.reviewRating)<=state.review.rating; b.classList.toggle('isSelected',on); b.setAttribute('aria-checked',String(on)); }); }
  function switchPanel(tab){ var selected=tab==='orders'?'records':(tab||'overview'); document.querySelectorAll('.memberNavItem,.memberMobileNavItem').forEach(function(i){ var on=i.dataset.tab===selected; i.classList.toggle('isActive',on); i.setAttribute('aria-selected',String(on)); if(i.classList.contains('memberNavItem')){ if(on) i.setAttribute('aria-current','page'); else i.removeAttribute('aria-current'); } }); document.querySelectorAll('.memberPanel').forEach(function(p){ var on=p.dataset.panel===selected; p.classList.toggle('isActive',on); p.hidden=!on; }); }
  function switchRecord(type){ var selected=type==='rental'?'rental':'purchase'; document.querySelectorAll('.memberRecordTab[data-rec]').forEach(function(t){ var on=t.dataset.rec===selected; t.classList.toggle('isActive',on); t.setAttribute('aria-selected',String(on)); }); document.querySelectorAll('.memberRecordPanel').forEach(function(p){ var on=p.dataset.recPanel===selected; p.classList.toggle('isActive',on); p.hidden=!on; }); }
  function switchCoupon(value){ var show=value!=='unavailable'; document.querySelectorAll('.memberRecordTab[data-coupon-tab]').forEach(function(t){ var on=t.dataset.couponTab===(show?'available':'unavailable'); t.classList.toggle('isActive',on); t.setAttribute('aria-selected',String(on)); }); var a=document.getElementById('activeCoupons'), e=document.getElementById('expiredCoupons'); if(a) a.hidden=!show; if(e) e.hidden=show; }
  function applyLogin(){ var guard=document.getElementById('memberLoginGuard'), shell=document.getElementById('memberCenterShell'), ok=loggedIn(); if(guard){ guard.hidden=ok; guard.classList.toggle('isHidden',ok); } if(shell) shell.hidden=!ok; if(ok) applyProfile(); }
  async function loadData(){ var rs=await Promise.all([json('users.json',fallbackUsers()),json('orders.json',fallbackOrders()),json('rentalOrders.json',fallbackRentals())]); var uid=currentMemberId(); var users=Array.isArray(rs[0])?rs[0]:fallbackUsers(); state.user=(applyPointDeltas(users).find(function(u){var l=loginUser()||{}; return u.id===(l.id||l.userId)||u.email===l.email;})||applyPointDeltas(users)[0]); state.orders=mergeOrders(Array.isArray(rs[1])?rs[1]:fallbackOrders(),arrays(MOCK_ORDERS_KEY)).filter(function(o){return !o.userId||o.userId===uid||(state.user&&o.userId===state.user.id);}); state.rentalOrders=(Array.isArray(rs[2])?rs[2]:fallbackRentals()).filter(function(o){return !o.userId||o.userId===uid||(state.user&&o.userId===state.user.id);}); applyProfile(); renderFilters('purchase',state.orders); renderFilters('rental',state.rentalOrders); renderOrders(); renderRentals(); renderCoupons(); renderNotifications(); renderActivity(); updateStats(); applyLogin(); }
  function bind(){ document.querySelectorAll('.memberNavItem,.memberMobileNavItem').forEach(function(b){ if(b.dataset.bound) return; b.dataset.bound='true'; b.addEventListener('click',function(){switchPanel(b.dataset.tab);}); }); document.querySelectorAll('.memberRecordTab[data-rec]').forEach(function(b){ if(b.dataset.bound) return; b.dataset.bound='true'; b.addEventListener('click',function(){switchRecord(b.dataset.rec);}); }); document.querySelectorAll('.memberRecordTab[data-coupon-tab]').forEach(function(b){ if(b.dataset.bound) return; b.dataset.bound='true'; b.addEventListener('click',function(){switchCoupon(b.dataset.couponTab);}); }); document.querySelectorAll('.memberOrderFilters').forEach(function(c){ if(c.dataset.bound) return; c.dataset.bound='true'; c.addEventListener('click',function(e){ var b=e.target.closest('.memberOrderFilter[data-filter]'); if(!b) return; var type=c.dataset.orderStatusTabs==='rental'?'rental':'purchase'; state.filters[type]=b.dataset.filter||'all'; renderFilters(type,type==='rental'?state.rentalOrders:state.orders); if(type==='rental') renderRentals(); else renderOrders(); }); }); document.querySelectorAll('#prefTags .memberPreferenceTag').forEach(function(t){ if(t.dataset.bound) return; t.dataset.bound='true'; t.addEventListener('click',function(){ t.classList.toggle('isSelected'); var vals=Array.from(document.querySelectorAll('#prefTags .memberPreferenceTag.isSelected')).map(function(x){return x.dataset.value;}); savePrefs(vals); syncPrefs(vals); }); }); var form=document.getElementById('profileForm'); if(form&&!form.dataset.bound){ form.dataset.bound='true'; form.addEventListener('submit',function(e){ e.preventDefault(); var s=savedProfile(); s.name=document.getElementById('profileName').value.trim(); s.phone=document.getElementById('profilePhone').value.trim(); s.address=document.getElementById('profileAddress').value.trim(); s.birthday=document.getElementById('profileBirthday').value; s.preferences=prefObject(Array.from(document.querySelectorAll('#prefTags .memberPreferenceTag.isSelected')).map(function(t){return t.dataset.value;})); localStorage.setItem('yurui_profile',JSON.stringify(s)); toast('會員資料已更新','success'); applyProfile(); }); } }
  function bindGlobal(){ if(document.body.dataset.memberCenterActionsBound) return; document.body.dataset.memberCenterActionsBound='true'; document.addEventListener('click',function(e){ var o=e.target.closest('[data-order-detail]'); if(o) return window.openOrderDetail(o.dataset.orderDetail); var r=e.target.closest('[data-rental-detail]'); if(r) return window.openRentalOrderDetail(r.dataset.rentalDetail); var rv=e.target.closest('[data-review-order]'); if(rv) return window.openReviewModal(rv.dataset.reviewOrder,rv.dataset.reviewItem); var cp=e.target.closest('[data-copy-coupon]'); if(cp) return copy(cp.dataset.copyCoupon); var no=e.target.closest('[data-notification-order-detail]'); if(no){ switchPanel('records'); switchRecord('purchase'); return window.openOrderDetail(no.dataset.notificationOrderDetail); } var nr=e.target.closest('[data-notification-rental-detail]'); if(nr){ switchPanel('records'); switchRecord('rental'); return window.openRentalOrderDetail(nr.dataset.notificationRentalDetail); } }); document.addEventListener('keydown',function(e){ if(e.key==='Escape'){ closeModal('orderDetailOverlay'); closeModal('reviewOverlay'); } }); }
  function copy(code){ if(!code) return; if(navigator.clipboard&&navigator.clipboard.writeText){ navigator.clipboard.writeText(code).then(function(){toast('折價券代碼已複製','success');}); return; } var el=document.createElement('textarea'); el.className='memberClipboardProxy'; el.value=code; document.body.appendChild(el); el.select(); document.execCommand('copy'); el.remove(); toast('折價券代碼已複製','success'); }
  function bindModals(){ [['orderDetailOverlay','orderDetailClose'],['reviewOverlay','reviewClose']].forEach(function(p){ var o=document.getElementById(p[0]), c=document.getElementById(p[1]); if(c&&!c.dataset.bound){ c.dataset.bound='true'; c.addEventListener('click',function(){closeModal(p[0]);}); } if(o&&!o.dataset.bound){ o.dataset.bound='true'; o.addEventListener('click',function(e){if(e.target===o) closeModal(p[0]);}); o.addEventListener('keydown',function(e){ if(e.key!=='Tab') return; var f=Array.from(o.querySelectorAll('button,[href],input,textarea,[tabindex]:not([tabindex="-1"])')).filter(function(x){return !x.disabled&&!x.hidden;}); if(!f.length) return; if(e.shiftKey&&document.activeElement===f[0]){e.preventDefault();f[f.length-1].focus();} else if(!e.shiftKey&&document.activeElement===f[f.length-1]){e.preventDefault();f[0].focus();} }); } }); document.querySelectorAll('.memberRatingStar').forEach(function(b){ if(b.dataset.bound) return; b.dataset.bound='true'; b.addEventListener('click',function(){stars(b.dataset.reviewRating);}); }); var form=document.getElementById('reviewForm'); if(form&&!form.dataset.bound){ form.dataset.bound='true'; form.addEventListener('submit',function(e){ e.preventDefault(); if(!state.review.orderId||!state.review.rating){toast('請先選擇評分','warning');return;} var reviews=parse(localStorage.getItem(REVIEW_KEY),[]); reviews.push({orderId:state.review.orderId,itemName:state.review.itemName,rating:state.review.rating,content:document.getElementById('reviewContent').value.trim(),createdAt:new Date().toISOString()}); localStorage.setItem(REVIEW_KEY,JSON.stringify(reviews)); var o=state.orders.find(function(x){return x.id===state.review.orderId;}); if(o) o.reviewed=true; renderOrders(); closeModal('reviewOverlay'); toast('評價已送出','success'); }); } }
  function bindNotifications(){ var list=document.getElementById('notificationList'); if(list&&!list.dataset.bound){ list.dataset.bound='true'; list.addEventListener('click',function(e){ var item=e.target.closest('.memberNotification[data-notif-id]'); if(!item||!state.user) return; var n=(state.user.notifications||[]).find(function(x){return x.id===item.dataset.notifId;}); if(n) n.read=true; renderNotifications(); updateStats(); }); } var all=document.getElementById('markAllReadBtn'); if(all&&!all.dataset.bound){ all.dataset.bound='true'; all.addEventListener('click',function(){ if(state.user&&Array.isArray(state.user.notifications)) state.user.notifications.forEach(function(n){n.read=true;}); renderNotifications(); updateStats(); toast('通知已全部標示為已讀','success'); }); } }
  function init(){ var root=document.getElementById('memberCenterComponentRoot'); if(!root) return; state.root=root; document.querySelectorAll('[data-member-center-home-link]').forEach(function(a){a.setAttribute('href',cfg.homeHref||'home.html');}); bind(); bindGlobal(); bindModals(); bindNotifications(); var login=document.getElementById('guardLoginBtn'); if(login&&!login.dataset.bound){ login.dataset.bound='true'; login.addEventListener('click',function(){ if(typeof window.openModal==='function') window.openModal('loginModal'); }); } window.syncMemberPreferenceTags=syncPrefs; switchCoupon('available'); applyLogin(); loadData(); window.clearInterval(state.loginTimer); state.loginTimer=window.setInterval(applyLogin,1500); window.clearInterval(state.pointsTimer); state.pointsTimer=window.setInterval(function(){if(loggedIn()) loadData();},Number(cfg.pointsRefreshMs)||5000); }
  window.initMemberCenterComponent=function(){ if(state.initialized&&state.root===document.getElementById('memberCenterComponentRoot')){ loadData(); applyLogin(); return; } state.initialized=true; init(); };
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',window.initMemberCenterComponent); else window.initMemberCenterComponent();
>>>>>>> Stashed changes
})();
