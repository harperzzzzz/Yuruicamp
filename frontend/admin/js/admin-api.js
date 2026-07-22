/**
 * admin/js/admin-api.js
 * 後台 REST API 抽象層；正式開關由 admin-runtime.js 依 AppConfig 統一設定。
 *
 * 使用方式：
 *   1. AppConfig.USE_MOCK_API=true：保留 Mock adapter。
 *   2. AppConfig.USE_MOCK_API=false：由 AdminRuntime 啟用正式後端與 readiness gate。
 *
 * 各模組在修改 cache 後呼叫對應方法，例如：
 *   AdminAPI.orders.updateStatus(orderId, payload).catch(handleApiError);
 */

(function (global) {
  'use strict';

  var config = {
    /** true 時才真的 fetch；false 僅保留接口、方便之後替換 */
    useBackend: false,
    baseUrl: '/api/admin',
    /** Mock 模式下是否在 console 記錄（開發除錯用） */
    logMockCalls: false
  };

  /**
   * 通用 HTTP 請求
   * @param {string} method
   * @param {string} path - 例如 '/orders/1'
   * @param {Object|null} body
   * @returns {Promise<Object>}
   */
  function request(method, path, body, includeMeta) {
    if (!config.useBackend) {
      if (config.logMockCalls && global.console && global.console.debug) {
        global.console.debug('[AdminAPI mock]', method, path, body || '');
      }
      return Promise.resolve({
        ok: true,
        mock: true,
        data: body || null
      });
    }

    var backendBase = config.baseUrl;
    if (backendBase === '/api/admin' && global.AppConfig && global.AppConfig.API_BASE_URL) {
      backendBase = global.AppConfig.API_BASE_URL.replace(/\/$/, '') + '/admin';
    }

    // 走 main 的 ApiClient（Bearer 由 AppAuth / Firebase 注入提供）
    return global.ApiClient._restRequest(path, {
      method: method,
      auth: 'required',
      baseUrl: backendBase,
      credentials: 'same-origin',
      body: body !== undefined && body !== null && method !== 'GET' && method !== 'HEAD'
        ? body
        : undefined,
      includeMeta: includeMeta === true
    }).then(function (data) {
      if (includeMeta === true) {
        return { ok: true, data: data.data, meta: data.meta };
      }
      return { ok: true, data: data };
    });
  }

  /** 正式模式遇到未實作功能時直接拒絕，不發出必然 404 的請求。 */
  function unsupported(feature, message, mockCall) {
    if (!config.useBackend && typeof mockCall === 'function') {
      return mockCall();
    }
    var error = global.ApiRequestError
      ? new global.ApiRequestError('ADMIN_FEATURE_NOT_READY', message, [{ field: 'feature', reason: feature }], 501)
      : new Error(message);
    return Promise.reject(error);
  }

  /** 統一錯誤提示（各模組可選用） */
  function handleError(err, fallbackMessage) {
    var msg = (err && err.message) || fallbackMessage || '操作失敗，請稍後再試';
    if (typeof global.showAdminToast === 'function') {
      global.showAdminToast(msg, 'danger');
    }
    if (global.console && global.console.error) {
      global.console.error('[AdminAPI]', err);
    }
  }

  var AdminAPI = {
    configure: function (opts) {
      if (!opts || typeof opts !== 'object') {
        return;
      }
      if (typeof opts.useBackend === 'boolean') {
        config.useBackend = opts.useBackend;
      }
      if (typeof opts.baseUrl === 'string' && opts.baseUrl) {
        config.baseUrl = opts.baseUrl;
      }
      if (typeof opts.logMockCalls === 'boolean') {
        config.logMockCalls = opts.logMockCalls;
      }
    },

    isBackendEnabled: function () {
      return config.useBackend === true;
    },

    handleError: handleError,

    auth: {
      /** 使用 Firebase ID Token 建立或刷新後台 Session 與有效權限。 */
      establishSession: function (idToken) {
        return global.ApiClient._restRequest('/admin/auth/firebase/session', {
          method: 'POST',
          auth: 'none',
          body: { idToken: idToken },
        }).then(function (data) {
          return { ok: true, data: data };
        });
      }
    },

    // ── 管理員與細權限 / Admin users and RBAC ──
    users: {
      list: function (page, size) {
        return request('GET', '/users?page=' + (page || 0) + '&size=' + (size || 100));
      },
      getById: function (adminUserId) {
        return request('GET', '/users/' + encodeURIComponent(adminUserId));
      },
      create: function (payload) {
        return request('POST', '/users', payload);
      },
      update: function (adminUserId, payload) {
        return request('PATCH', '/users/' + encodeURIComponent(adminUserId), payload);
      },
      updatePermissions: function (adminUserId, permissions) {
        return request('PUT', '/users/' + encodeURIComponent(adminUserId) + '/permissions', {
          permissions: permissions
        });
      }
    },

    permissions: {
      list: function () {
        return request('GET', '/permissions');
      }
    },

    // ── 客戶 / Customers ──
    customers: {
      /** GET /api/admin/customers */
      list: function (query) {
        var params = new URLSearchParams(query || {});
        var suffix = params.toString() ? '?' + params.toString() : '';
        return request('GET', '/customers' + suffix);
      },
      /** GET /api/admin/customers/:id */
      getById: function (customerId) {
        return request('GET', '/customers/' + encodeURIComponent(customerId));
      },
      /** POST /api/admin/customers */
      create: function (customer) {
        return unsupported('customers.create', '正式後端尚未開放由管理員建立會員', function () {
          return request('POST', '/customers', customer);
        });
      },
      /** PATCH /api/admin/customers/:id */
      update: function (customerId, changes) {
        return request('PATCH', '/customers/' + encodeURIComponent(customerId), changes);
      },
      /** POST /api/admin/customers/:id/suspend */
      suspend: function (customerId) {
        return request('POST', '/customers/' + encodeURIComponent(customerId) + '/suspend');
      },
      /** POST /api/admin/customers/:id/reactivate */
      reactivate: function (customerId) {
        return request('POST', '/customers/' + encodeURIComponent(customerId) + '/reactivate');
      }
    },

    // ── 標籤池 / Tag pool ──
    tags: {
      /** PUT /api/admin/tag-pool */
      savePool: function (tagColorMap) {
        return unsupported('customers.tagPool', '正式後端尚未提供會員標籤池維護', function () {
          return request('PUT', '/tag-pool', { tagColorMap: tagColorMap });
        });
      }
    },

    // ── 訂單 / Orders ──
    orders: {
      /** GET /api/admin/orders */
      list: function (query) {
        var search = new URLSearchParams();
        Object.keys(query || {}).forEach(function (key) {
          var value = query[key];
          (Array.isArray(value) ? value : [value]).forEach(function (item) {
            if (item !== undefined && item !== null && item !== '') search.append(key, item);
          });
        });
        var suffix = search.toString() ? '?' + search.toString() : '';
        return request('GET', '/orders' + suffix, null, true);
      },
      /** GET /api/admin/orders/:id */
      getById: function (orderId) {
        return request('GET', '/orders/' + encodeURIComponent(orderId));
      },
      /** PATCH /api/admin/orders/:id — 狀態、history 等 */
      update: function (orderId, payload) {
        return unsupported('orders.sellerNote', '正式後端尚未提供訂單備註修改', function () {
          return request('PATCH', '/orders/' + encodeURIComponent(orderId), payload);
        });
      },
      /** 語意化捷徑：出貨 */
      ship: function (orderId, payload) {
        return request('POST', '/orders/' + encodeURIComponent(orderId) + '/ship', payload || {});
      },
      /** 語意化捷徑：完成 */
      complete: function (orderId, payload) {
        return request('POST', '/orders/' + encodeURIComponent(orderId) + '/complete', payload || {});
      }
    },

    // ── 預約 / Bookings ──
    bookings: {
      /** GET /api/admin/bookings */
      list: function (query) {
        var search = new URLSearchParams();
        Object.keys(query || {}).forEach(function (key) {
          var value = query[key];
          (Array.isArray(value) ? value : [value]).forEach(function (item) {
            if (item !== undefined && item !== null && item !== '') search.append(key, item);
          });
        });
        var suffix = search.toString() ? '?' + search.toString() : '';
        return request('GET', '/bookings' + suffix, null, true);
      },
      /** GET /api/admin/bookings/:id */
      getById: function (bookingId) {
        return request('GET', '/bookings/' + encodeURIComponent(bookingId));
      },
      /** PATCH /api/admin/bookings/:id — 狀態、備註等 */
      update: function (bookingId, payload) {
        return unsupported('bookings.sellerNote', '正式後端尚未提供預約備註修改', function () {
          return request('PATCH', '/bookings/' + encodeURIComponent(bookingId), payload);
        });
      },
      /** POST /api/admin/bookings/:id/confirm */
      confirm: function (bookingId, payload) {
        return request('POST', '/bookings/' + encodeURIComponent(bookingId) + '/confirm', payload || {});
      },
      /** POST /api/admin/bookings/:id/complete */
      complete: function (bookingId, payload) {
        return request('POST', '/bookings/' + encodeURIComponent(bookingId) + '/complete', payload || {});
      }
    },

    // ── 商品 / Products ──
    products: {
      /** GET /api/admin/products */
      list: function (query) {
        var params = new URLSearchParams(query || { page: 0, size: 100, sort: 'id,asc' });
        var suffix = params.toString() ? '?' + params.toString() : '';
        return request('GET', '/products' + suffix);
      },
      /** GET /api/admin/products/:id */
      getById: function (productId) {
        return request('GET', '/products/' + encodeURIComponent(productId));
      },
      /** GET /api/admin/products/lookups */
      getLookups: function () {
        return request('GET', '/products/lookups');
      },
      /** POST /api/admin/products */
      create: function (product) {
        return request('POST', '/products', product);
      },
      /** PUT /api/admin/products/:id */
      update: function (productId, product) {
        return request('PUT', '/products/' + encodeURIComponent(productId), product);
      },
      /** POST /api/admin/products/:id/activate */
      activate: function (productId) {
        return request('POST', '/products/' + encodeURIComponent(productId) + '/activate', {});
      },
      /** POST /api/admin/products/:id/deactivate */
      deactivate: function (productId) {
        return request('POST', '/products/' + encodeURIComponent(productId) + '/deactivate', {});
      },
      /** PUT /api/admin/rentals/:id — 租借庫存 */
      updateRental: function (rentalId, rental) {
        return unsupported('products.rentalWrite', '正式後端尚未提供租借商品寫入', function () {
          return request('PUT', '/rentals/' + encodeURIComponent(rentalId), rental);
        });
      }
    },

    // ── 評論 / Reviews ──
    reviews: {
      /** GET /api/admin/reviews */
      list: function () {
        return unsupported('reviews.manage', '評論管理尚未提供正式後端端點', function () {
          return request('GET', '/reviews');
        });
      },
      /** DELETE /api/admin/reviews/:id — 刪除整則評論 */
      remove: function (reviewId) {
        return unsupported('reviews.manage', '評論管理尚未提供正式後端端點', function () {
          return request('DELETE', '/reviews/' + encodeURIComponent(reviewId));
        });
      }
    },

    // ── 優惠券 / Coupons ──
    coupons: {
      list: function (query) {
        var params = new URLSearchParams(query || { page: 0, size: 100, sort: 'createdAt,desc' });
        var suffix = params.toString() ? '?' + params.toString() : '';
        return request('GET', '/coupons' + suffix);
      },
      getById: function (couponId) {
        return request('GET', '/coupons/' + encodeURIComponent(couponId));
      },
      create: function (coupon) {
        return request('POST', '/coupons', coupon);
      },
      update: function (couponId, coupon) {
        return request('PATCH', '/coupons/' + encodeURIComponent(couponId), coupon);
      },
      updateStatus: function (couponId, status) {
        return request('PATCH', '/coupons/' + encodeURIComponent(couponId), { status: status });
      },
      remove: function (couponId) {
        return request('DELETE', '/coupons/' + encodeURIComponent(couponId));
      }
    },

    // ── 庫存異動 / Movement ──
    movement: {
      list: function (query) {
        var params = new URLSearchParams(query || { page: 0, size: 100, sort: 'occurredAt,desc' });
        var suffix = params.toString() ? '?' + params.toString() : '';
        return request('GET', '/inventory-movements' + suffix);
      },
      getById: function (movementId) {
        return request('GET', '/inventory-movements/' + encodeURIComponent(movementId));
      },
      getLookups: function () {
        return request('GET', '/inventory-movements/lookups');
      },
      createDraft: function (record) {
        return request('POST', '/inventory-movements', record);
      },
      addItem: function (movementId, item) {
        return request('POST', '/inventory-movements/' + encodeURIComponent(movementId) + '/items', item);
      },
      post: function (movementId) {
        return request('POST', '/inventory-movements/' + encodeURIComponent(movementId) + '/post', {});
      },
      cancel: function (movementId) {
        return request('POST', '/inventory-movements/' + encodeURIComponent(movementId) + '/cancel', {});
      },
      // Mock 模式保留舊 create 名稱；Backend 模式一律使用 createDraft。
      create: function (record) {
        return request('POST', '/inventory-movements', record);
      }
    },

    // ── 營區公休 / Campground closures ──
    closures: {
      list: function (query) {
        var params = new URLSearchParams(query || { page: 0, size: 100, sort: 'createdAt,desc' });
        var suffix = params.toString() ? '?' + params.toString() : '';
        return request('GET', '/campground-closures' + suffix);
      },
      getById: function (closureId) {
        return request('GET', '/campground-closures/' + encodeURIComponent(closureId));
      },
      create: function (closure) {
        return request('POST', '/campground-closures', closure);
      },
      update: function (id, closure) {
        return request('PATCH', '/campground-closures/' + encodeURIComponent(id), closure);
      },
      remove: function (id) {
        return request('DELETE', '/campground-closures/' + encodeURIComponent(id));
      }
    }
  };

  global.AdminAPI = AdminAPI;
})(typeof window !== 'undefined' ? window : this);
