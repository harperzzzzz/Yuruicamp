/**
 * admin/js/admin-api.js
 * 後台 REST API 抽象層（Mock → 未來串接後端 / 資料庫）
 *
 * 使用方式：
 *   1. 預設 useBackend = false：只更新前端 cache，API 回傳 resolved Promise（不發 request）
 *   2. 後端就緒後：AdminAPI.configure({ useBackend: true, baseUrl: '/api/admin' })
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
      return { ok: true, data: data };
    });
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
        return request('POST', '/customers', customer);
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
        return request('PUT', '/tag-pool', { tagColorMap: tagColorMap });
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
        return request('PATCH', '/orders/' + encodeURIComponent(orderId), payload);
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
        return request('PATCH', '/bookings/' + encodeURIComponent(bookingId), payload);
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
        return request('PUT', '/rentals/' + encodeURIComponent(rentalId), rental);
      }
    },

    // ── 評論 / Reviews ──
    reviews: {
      /** GET /api/admin/reviews */
      list: function () {
        return request('GET', '/reviews');
      },
      /** DELETE /api/admin/reviews/:id — 刪除整則評論 */
      remove: function (reviewId) {
        return request('DELETE', '/reviews/' + encodeURIComponent(reviewId));
      }
    },

    // ── 優惠券 / Coupons ──
    coupons: {
      list: function () {
        return request('GET', '/coupons');
      },
      create: function (coupon) {
        return request('POST', '/coupons', coupon);
      },
      updateStatus: function (code, status) {
        return request('PATCH', '/coupons/' + encodeURIComponent(code), { status: status });
      },
      remove: function (code) {
        return request('DELETE', '/coupons/' + encodeURIComponent(code));
      }
    },

    // ── 庫存異動 / Movement ──
    movement: {
      list: function () {
        return request('GET', '/inventory-movements');
      },
      create: function (record) {
        return request('POST', '/inventory-movements', record);
      }
    },

    // ── 營區公休 / Campground closures ──
    closures: {
      list: function () {
        return request('GET', '/campground-closures');
      },
      create: function (closure) {
        return request('POST', '/campground-closures', closure);
      },
      update: function (id, closure) {
        return request('PUT', '/campground-closures/' + encodeURIComponent(id), closure);
      },
      remove: function (id) {
        return request('DELETE', '/campground-closures/' + encodeURIComponent(id));
      }
    }
  };

  global.AdminAPI = AdminAPI;
})(typeof window !== 'undefined' ? window : this);
