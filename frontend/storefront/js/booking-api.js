// ========================================
// BookingAPI — 預約前台 Mock API
// ========================================

(function (global) {
  'use strict';

  var MOCK_BOOKINGS_KEY = 'mockBookings';
  var MOCK_CLOSURES_KEY = 'mockCampgroundClosures';

  /** Mock 路徑：優先 MockDataPaths（api-mock.js）；勿再改寫 /assets */
  function path(key) {
    var table = global.MockDataPaths;
    return table && table[key] ? table[key] : '';
  }

  function useMockApi() {
    return !(global.AppConfig && global.AppConfig.USE_MOCK_API === false);
  }

  function restUrl(restPath) {
    var base = String((global.AppConfig && global.AppConfig.API_BASE_URL) || '').replace(/\/$/, '');
    return base + restPath;
  }

  function readStorage(key, fallback) {
    try {
      return JSON.parse(localStorage.getItem(key) || JSON.stringify(fallback));
    } catch (e) {
      return fallback;
    }
  }

  function writeStorage(key, value) {
    localStorage.setItem(key, JSON.stringify(value));
  }

  /** 直接 fetch；圖片欄位保持後端／JSON 原樣 / No path rewriting */
  function fetchJson(url) {
    return fetch(url, { cache: 'no-store' }).then(function (res) {
      if (!res.ok) throw new Error('Fetch failed: ' + url);
      return res.json();
    });
  }

  /** mock 檔或 REST / Mock file or REST endpoint */
  function loadMockOrRest(mockKey, restPath) {
    if (useMockApi()) {
      return fetchJson(path(mockKey));
    }
    return fetchJson(restUrl(restPath));
  }

  function formatDateTime(date) {
    date = date || new Date();
    var yyyy = date.getFullYear();
    var mm = String(date.getMonth() + 1).padStart(2, '0');
    var dd = String(date.getDate()).padStart(2, '0');
    var hh = String(date.getHours()).padStart(2, '0');
    var mi = String(date.getMinutes()).padStart(2, '0');
    var ss = String(date.getSeconds()).padStart(2, '0');
    return yyyy + '-' + mm + '-' + dd + ' ' + hh + ':' + mi + ':' + ss;
  }

  /** 從預約列表取最大數字 id / Get max numeric booking id from a list */
  function getMaxBookingId(list) {
    var maxId = 0;
    (list || []).forEach(function (b) {
      var n = Number(b && b.id) || 0;
      if (n > maxId) maxId = n;
    });
    return maxId;
  }

  /** 載入可用性計算所需完整上下文 / Load availability context */
  function loadAvailabilityContext() {
    var AV = global.BookingAvailability;
    if (!AV) {
      return Promise.reject(new Error('BookingAvailability not loaded'));
    }

    return Promise.all([
      loadMockOrRest('campgrounds', '/booking/campgrounds'),
      BookingAPI.getBookings(),
      loadMockOrRest('zoneBlocks', '/booking/zone-blocks').catch(function () { return []; }),
      BookingAPI.getPolicy(),
      BookingAPI.getClosures(),
    ]).then(function (results) {
      return AV.buildContext(results[0], results[1], results[2], results[3], null, results[4]);
    });
  }

  var BookingAPI = {
    getCampgrounds: function (filters) {
      return loadMockOrRest('campgrounds', '/booking/campgrounds').then(function (list) {
        if (!filters) return list;
        return list.filter(function (c) {
          if (filters.region && c.region !== filters.region) return false;
          return true;
        });
      });
    },

    getCampgroundById: function (campgroundId) {
      return BookingAPI.getCampgrounds().then(function (list) {
        var item = list.find(function (c) {
          return c.campgroundId === campgroundId;
        });
        if (!item) throw new Error('Campground not found');
        return item;
      });
    },

    getEquipment: function (campgroundId) {
      return loadMockOrRest('campEquipment', '/booking/equipment').then(function (list) {
        return list.filter(function (e) {
          return e.campgroundId === campgroundId;
        });
      });
    },

    getBookings: function (customerId) {
      return loadMockOrRest('campBookings', '/booking/bookings').then(function (seed) {
        var mock = useMockApi() ? readStorage(MOCK_BOOKINGS_KEY, []) : [];
        var all = seed.concat(mock);
        if (!customerId) return all;
        return all.filter(function (b) {
          return b.customerId === customerId;
        });
      });
    },

    createBooking: function (payload) {
      if (!useMockApi()) {
        return fetch(restUrl('/booking/bookings'), {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
        }).then(function (res) {
          if (!res.ok) throw new Error('Create booking failed');
          return res.json();
        });
      }
      return loadMockOrRest('campBookings', '/booking/bookings').then(function (seed) {
        var mock = readStorage(MOCK_BOOKINGS_KEY, []);
        var all = (Array.isArray(seed) ? seed : []).concat(mock);
        // 不可把整個陣列傳給 Math.max，多筆時會變成 NaN
        // Never pass a whole array to Math.max; multiple ids become NaN
        var maxId = getMaxBookingId(all);
        var booking = Object.assign({}, payload, {
          id: maxId + 1,
          submittedAt: payload.submittedAt || formatDateTime(),
          status: payload.status || 'pending',
          paymentStatus: payload.paymentStatus || 'paid',
        });
        mock.push(booking);
        writeStorage(MOCK_BOOKINGS_KEY, mock);
        return booking;
      });
    },

    /** 預約政策（窗口天數、佔用狀態）/ Booking policy */
    getPolicy: function () {
      var AV = global.BookingAvailability;
      return loadMockOrRest('bookingPolicy', '/booking/policy').then(function (policy) {
        return AV ? AV.normalizePolicy(policy) : policy;
      }).catch(function () {
        return AV ? AV.normalizePolicy(null) : { bookingWindowDays: 90 };
      });
    },

    /** 營位停售例外 / Zone block overrides */
    getZoneBlocks: function () {
      return loadMockOrRest('zoneBlocks', '/booking/zone-blocks').catch(function () { return []; });
    },

    /** 營區公休（seed + localStorage overlay）/ Campground closures */
    getClosures: function () {
      var merge = global.MockStorageMerge;
      return loadMockOrRest('campgroundClosures', '/booking/closures').then(function (seed) {
        if (!merge || !useMockApi()) return seed;
        var overlay = merge.readJsonStorage(MOCK_CLOSURES_KEY, []);
        return merge.mergeById(seed, overlay, 'id').filter(function (cl) {
          return !cl._deleted;
        });
      }).catch(function () {
        if (global.MockStorageMerge && useMockApi()) {
          return global.MockStorageMerge.readJsonStorage(MOCK_CLOSURES_KEY, []);
        }
        return [];
      });
    },

    /** 寫入公休 overlay（Admin 編輯用）/ Save closure overlay */
    saveClosuresOverlay: function (list) {
      writeStorage(MOCK_CLOSURES_KEY, list || []);
      return Promise.resolve(list);
    },

    /** 可預約日期窗口 { minDate, maxDate } / Bookable date window */
    getBookingWindow: function () {
      var AV = global.BookingAvailability;
      return BookingAPI.getPolicy().then(function (policy) {
        return AV ? AV.getBookingWindow(policy) : { minDate: null, maxDate: null };
      });
    },

    /**
     * Zone 可用性區間 DTO
     * @param {{ campgroundId?: string, zoneId: string, from: string, to: string }} params
     */
    getAvailability: function (params) {
      var AV = global.BookingAvailability;
      if (!AV) {
        return Promise.reject(new Error('BookingAvailability not loaded'));
      }
      return loadAvailabilityContext().then(function (ctx) {
        return AV.getAvailabilityRange(params, ctx);
      });
    },

    /**
     * 住宿區間最低剩餘（用於 range 驗證）
     * Min remaining across stay nights for one zone
     */
    getMinRemainingForStay: function (zoneId, checkIn, checkOut) {
      var AV = global.BookingAvailability;
      if (!AV) {
        return Promise.reject(new Error('BookingAvailability not loaded'));
      }
      return loadAvailabilityContext().then(function (ctx) {
        if (AV.hasClosedNightInRange(
          (ctx.zonesById[zoneId] || {}).campgroundId,
          checkIn,
          checkOut,
          ctx
        )) {
          return 0;
        }
        return AV.getMinRemainingInRange(zoneId, checkIn, checkOut, ctx);
      });
    },

    /** 載入完整可用性上下文（Admin 日曆用）/ Full context for admin calendar */
    loadAvailabilityContext: loadAvailabilityContext,
  };

  global.BookingAPI = BookingAPI;
})(typeof window !== 'undefined' ? window : this);

console.log('✓ BookingAPI 已初始化');
