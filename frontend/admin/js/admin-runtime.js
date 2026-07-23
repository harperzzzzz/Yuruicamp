/**
 * Admin 正式執行環境：統一 Backend 開關、Firebase Session、有效權限與功能就緒清單。
 */
(function (global) {
  'use strict';

  var SESSION_KEYS = [
    'adminLoggedIn',
    'adminId',
    'adminName',
    'adminRole',
    'adminEmail',
    'isSuperAdmin',
    'adminPermissions',
    'adminDevToken',
  ];

  /** 每個模組是否可以在 Backend 模式安全使用；未就緒功能不得發出不存在的 API。 */
  var READINESS = {
    analytics: { ready: true, level: 'read', note: '由正式訂單、商品與預約列表聚合' },
    orders: { ready: true, level: 'partial', note: '查詢、履約與內部備註可用；取消／退款待 W3' },
    movement: { ready: true, level: 'full', note: '正式庫存異動完整可用' },
    products: { ready: true, level: 'partial', note: '商城商品與最低庫存閾值可用；租借商品寫入尚未提供端點' },
    customers: { ready: true, level: 'partial', note: '查詢、基本更新、停權、標籤池／指派與預設地址可用；新增會員尚未提供端點' },
    discounts: { ready: true, level: 'full', note: '優惠券正式 CRUD 可用' },
    reviews: { ready: true, level: 'partial', note: '列表／詳情／硬刪可用；不做回覆與軟隱藏' },
    'booking-calendar': { ready: true, level: 'partial', note: '公休規則可用；月份容量仍由既有 Booking API 呈現' },
    bookings: { ready: true, level: 'partial', note: '查詢、履約與內部備註可用；已付款取消待 W3' },
    permissions: { ready: true, level: 'full', note: '管理員與有效權限正式可用' },
  };

  var FEATURE_READINESS = {
    'customers.create': false,
    /** 標籤字典 CRUD（W1-02）已就緒 / Tag pool CRUD ready */
    'customers.tagPool': true,
    /** 會員身上指派（W1-03）已就緒 / Assign tags to customer ready */
    'customers.tagAssign': true,
    /** 預設收件地址可編（W1-04）/ Default shipping address editable */
    'customers.defaultAddress': true,
    /** 會員偏好可編（W1-05）/ Customer preferences editable */
    'customers.preferences': true,
    'orders.sellerNote': true,
    'bookings.sellerNote': true,
    /** 最低庫存閾值讀寫（W1-07）；on-hand 仍唯讀 / Min-stock ready; on-hand still read-only */
    'products.minStock': true,
    'products.rentalWrite': false,
    /** 評論列表／硬刪（W1-06）；不做回覆／軟隱藏 */
    'reviews.manage': true,
  };

  function isBackendMode() {
    return !!(global.AdminAPI
      && global.AdminAPI.isBackendEnabled
      && global.AdminAPI.isBackendEnabled());
  }

  /** 將後端 permission code 集合轉成既有 Sidebar 使用的 section view/edit 矩陣。 */
  function buildPermissionMatrix(codes) {
    var matrix = {};
    (codes || []).forEach(function (code) {
      var separator = String(code).lastIndexOf('.');
      if (separator < 1) return;
      var section = String(code).slice(0, separator);
      var action = String(code).slice(separator + 1);
      if (action !== 'view' && action !== 'edit') return;
      if (!matrix[section]) matrix[section] = { view: false, edit: false };
      matrix[section][action] = true;
    });
    return matrix;
  }

  /** SessionStorage 只保存 UI 快取；Firebase ID Token 不寫入 Web Storage。 */
  function saveSession(profile) {
    sessionStorage.setItem('adminLoggedIn', 'true');
    sessionStorage.setItem('adminId', profile.adminUserId);
    sessionStorage.setItem('adminName', profile.name || profile.email || '管理員');
    sessionStorage.setItem('adminRole', profile.role || 'operator');
    sessionStorage.setItem('adminEmail', profile.email || '');
    sessionStorage.setItem('isSuperAdmin', 'false');
    sessionStorage.setItem(
      'adminPermissions',
      JSON.stringify(buildPermissionMatrix(profile.effectivePermissions))
    );
  }

  function clearSession() {
    SESSION_KEYS.forEach(function (key) {
      sessionStorage.removeItem(key);
    });
  }

  /** 載入共用 Firebase 模組並把 Auth instance 注入 AppAuth。 */
  async function initializeFirebase() {
    await import('/storefront/js/firebase-app.js');
    if (!global.YuruiFirebase || !global.YuruiFirebase.isReady()) {
      return null;
    }
    var auth = global.YuruiFirebase.getAuth();
    if (global.YuruiFirebase.waitForAuthState) {
      await global.YuruiFirebase.waitForAuthState();
    }
    global.AppAuth.configure({ auth: auth });
    return auth;
  }

  /** 以目前 Firebase 或 development dev Token 重新向後端取得最新有效權限。 */
  async function refreshBackendSession(options) {
    var settings = options || {};
    var token = settings.idToken || await global.AppAuth.getIdToken({
      required: true,
      forceRefresh: settings.forceRefresh === true,
    });
    var result = await global.AdminAPI.auth.establishSession(token);
    saveSession(result.data);
    return result.data;
  }

  /** Dashboard 每次重整都重新驗證白名單、啟用狀態與有效權限。 */
  async function initializeDashboard() {
    if (!isBackendMode()) {
      return sessionStorage.getItem('adminLoggedIn') === 'true';
    }

    var auth = await initializeFirebase();
    var devToken = global.AppConfig
      && global.AppConfig.AUTH
      && String(global.AppConfig.AUTH.DEV_TOKEN || '').trim();
    devToken = devToken || sessionStorage.getItem('adminDevToken') || '';
    if (devToken) global.AppAuth.configure({ devToken: devToken });
    if ((!auth || !auth.currentUser) && !devToken) {
      clearSession();
      return false;
    }

    await refreshBackendSession({ forceRefresh: false });
    return true;
  }

  async function signOut() {
    clearSession();
    if (isBackendMode() && global.YuruiFirebase && global.YuruiFirebase.signOut) {
      await global.YuruiFirebase.signOut();
    }
  }

  var adminMode = global.AppConfig && global.AppConfig.ADMIN;
  var useBackend = adminMode && typeof adminMode.USE_BACKEND === 'boolean'
    ? adminMode.USE_BACKEND
    : !!(global.AppConfig && global.AppConfig.USE_MOCK_API === false);
  global.AdminAPI.configure({
    useBackend: useBackend,
    baseUrl: global.AppConfig && global.AppConfig.API_BASE_URL
      ? global.AppConfig.API_BASE_URL.replace(/\/$/, '') + '/admin'
      : '/api/admin',
  });

  global.AdminRuntime = {
    readiness: READINESS,
    featureReadiness: FEATURE_READINESS,
    isBackendMode: isBackendMode,
    isSectionReady: function (section) {
      return !isBackendMode() || !!(READINESS[section] && READINESS[section].ready);
    },
    isFeatureReady: function (feature) {
      return !isBackendMode() || FEATURE_READINESS[feature] !== false;
    },
    getReadiness: function (section) {
      return READINESS[section] || { ready: false, level: 'none', note: '尚未完成 readiness 盤點' };
    },
    buildPermissionMatrix: buildPermissionMatrix,
    saveSession: saveSession,
    clearSession: clearSession,
    initializeFirebase: initializeFirebase,
    refreshBackendSession: refreshBackendSession,
    initializeDashboard: initializeDashboard,
    signOut: signOut,
  };

  /** Token 強制刷新仍失敗時清除 UI Session，要求管理員重新登入。 */
  if (typeof global.addEventListener === 'function') {
    global.addEventListener('app-auth-expired', function () {
      if (!isBackendMode()) return;
      clearSession();
      sessionStorage.setItem('adminLoginMessage', '登入已逾期，請重新使用管理員帳號登入。');
      if (!/\/admin\/login\.html$/.test(global.location.pathname)) {
        global.location.href = '/admin/login.html';
      }
    });
  }
})(typeof window !== 'undefined' ? window : this);
