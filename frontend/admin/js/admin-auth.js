/**
 * 後台 Firebase 登入／session 工具（階段 3）
 * Admin Firebase auth helpers — Google popup → POST /admin/auth/firebase/session
 *
 * 正式 REST 走 AppAuth + ApiClient；sessionStorage 仍給 dashboard UI／Sidebar 權限用。
 */
(function (global) {
  'use strict';

  var SESSION_KEYS = {
    loggedIn: 'adminLoggedIn',
    adminId: 'adminId',
    adminName: 'adminName',
    isSuperAdmin: 'isSuperAdmin',
    adminPermissions: 'adminPermissions',
    authSource: 'adminAuthSource',
    adminEmail: 'adminEmail',
    adminRole: 'adminRole'
  };

  /** Seed / Swagger 用的本機 Dev Token（僅 FIREBASE_ENABLED=false 時後端才接受） */
  var DEV_SEED_TOKEN =
    'dev:booking-seed-admin:booking-seed@example.test:google:Booking Seed Admin';

  /**
   * 後端 effectivePermissions（如 orders.view）→ 前端 Sidebar 用的巢狀物件
   * Map backend permission codes to UI { section: { view, edit } }
   * @param {string[]|Set<string>|null} codes
   * @param {string} role
   * @returns {Record<string, { view: boolean, edit: boolean }>}
   */
  function mapEffectivePermissionsToUi(codes, role) {
    var sections = (global.ADMIN_SECTIONS || []).map(function (s) {
      return s.key;
    });
    var perms = {};
    sections.forEach(function (key) {
      perms[key] = { view: false, edit: false };
    });

    // role=admin → 前端視為超級管理員（canView／canEdit 全開）
    if (String(role || '').toLowerCase() === 'admin') {
      sections.forEach(function (key) {
        perms[key] = { view: true, edit: true };
      });
      return perms;
    }

    var list = [];
    if (codes && typeof codes.forEach === 'function') {
      codes.forEach(function (code) {
        list.push(code);
      });
    } else if (Array.isArray(codes)) {
      list = codes;
    }

    list.forEach(function (code) {
      var parts = String(code || '').split('.');
      if (parts.length < 2) return;
      var action = parts[parts.length - 1];
      var section = parts.slice(0, -1).join('.');
      if (!perms[section]) {
        perms[section] = { view: false, edit: false };
      }
      if (action === 'view' || action === 'edit') {
        perms[section][action] = true;
      }
    });

    return perms;
  }

  /**
   * 寫入 dashboard 既有 sessionStorage 契約（5 個主 key + 輔助欄位）
   * @param {object} session - AdminSession data from backend
   * @param {string} authSource - 'firebase' | 'dev-token'
   */
  function persistAdminSession(session, authSource) {
    var role = session.role || '';
    var isSuperAdmin = String(role).toLowerCase() === 'admin';
    var permissions = mapEffectivePermissionsToUi(
      session.effectivePermissions,
      role
    );

    sessionStorage.setItem(SESSION_KEYS.loggedIn, 'true');
    sessionStorage.setItem(SESSION_KEYS.adminId, session.adminUserId || '');
    sessionStorage.setItem(SESSION_KEYS.adminName, session.name || session.email || '管理員');
    sessionStorage.setItem(SESSION_KEYS.isSuperAdmin, String(isSuperAdmin));
    sessionStorage.setItem(SESSION_KEYS.adminPermissions, JSON.stringify(permissions));
    sessionStorage.setItem(SESSION_KEYS.authSource, authSource || 'firebase');
    sessionStorage.setItem(SESSION_KEYS.adminEmail, session.email || '');
    sessionStorage.setItem(SESSION_KEYS.adminRole, role);
  }

  function clearAdminSessionStorage() {
    Object.keys(SESSION_KEYS).forEach(function (key) {
      sessionStorage.removeItem(SESSION_KEYS[key]);
    });
  }

  function requireApiClient() {
    if (!global.ApiClient || typeof global.ApiClient._restRequest !== 'function') {
      throw new Error('ApiClient 尚未載入。請確認已引入 /storefront/js/api-client.js');
    }
  }

  function ensureAppAuthWired() {
    if (!global.AppAuth || typeof global.AppAuth.configure !== 'function') {
      return;
    }
    if (!global.YuruiFirebase || typeof global.YuruiFirebase.isReady !== 'function') {
      return;
    }
    if (!global.YuruiFirebase.isReady()) {
      return;
    }
    try {
      global.AppAuth.configure({ auth: global.YuruiFirebase.getAuth() });
      console.log('✓ AppAuth 已注入 Firebase Auth（admin）');
    } catch (error) {
      console.warn('[AdminAuth] AppAuth.configure 略過:', error);
    }
  }

  function friendlySessionError(error) {
    var code = error && error.code ? String(error.code) : '';
    var message = (error && error.message) || '後台登入失敗';
    if (code === 'ADMIN_NOT_WHITELISTED' || /not whitelisted/i.test(message)) {
      return '此 Google 帳號尚未加入後台白名單。請請管理員把你的 email 寫入 admin_users。';
    }
    if (code === 'ADMIN_INACTIVE' || /disabled/i.test(message)) {
      return '此後台帳號已停用。';
    }
    if (code === 'FORBIDDEN' || /different Firebase/i.test(message)) {
      return '此 email 已綁定其他 Firebase 帳號，無法以此身分登入。';
    }
    if (code === 'API_NETWORK_ERROR') {
      return '無法連線伺服器，請確認後端已啟動（localhost:8080）。';
    }
    if (/Invalid Firebase ID token|INVALID_TOKEN|401/i.test(message + code)) {
      return 'Firebase Token 無效。請確認後端 FIREBASE_ENABLED 與憑證設定。';
    }
    return message;
  }

  /**
   * POST /api/admin/auth/firebase/session
   * @param {string} idToken
   * @returns {Promise<object>}
   */
  function establishAdminSession(idToken) {
    requireApiClient();
    return global.ApiClient._restRequest('/admin/auth/firebase/session', {
      method: 'POST',
      auth: 'none',
      body: { idToken: idToken }
    });
  }

  /**
   * Google → Admin session → 寫入 sessionStorage
   * @returns {Promise<object>}
   */
  function loginWithGoogle() {
    requireApiClient();

    return Promise.resolve()
      .then(function () {
        if (global.YuruiFirebase && global.YuruiFirebase.isReady && global.YuruiFirebase.isReady()) {
          return null;
        }
        return import('/storefront/js/firebase-app.js');
      })
      .then(function () {
        if (!global.YuruiFirebase || !global.YuruiFirebase.isReady || !global.YuruiFirebase.isReady()) {
          throw new Error(
            'Firebase 尚未就緒。請確認 frontend/.env.local 的 VITE_FIREBASE_* 並重啟 npm run dev。'
          );
        }
        ensureAppAuthWired();
        return global.YuruiFirebase.signInWithGoogle();
      })
      .then(function (firebaseResult) {
        return establishAdminSession(firebaseResult.idToken).then(function (session) {
          ensureAppAuthWired();
          persistAdminSession(session, 'firebase');
          console.log('✓ Admin Firebase session OK', {
            adminUserId: session.adminUserId,
            email: session.email,
            role: session.role
          });
          return session;
        });
      })
      .catch(function (error) {
        throw new Error(friendlySessionError(error));
      });
  }

  /**
   * 本機開發：用 seed 管理員 Dev Token（後端必須 FIREBASE_ENABLED=false）
   * @returns {Promise<object>}
   */
  function loginWithDevSeedToken() {
    var env = global.AppConfig && global.AppConfig.ENVIRONMENT;
    if (env !== 'development') {
      return Promise.reject(new Error('Dev Token 登入只允許 development 環境。'));
    }

    requireApiClient();

    if (global.AppAuth && typeof global.AppAuth.configure === 'function') {
      global.AppAuth.configure({ devToken: DEV_SEED_TOKEN });
    }

    return establishAdminSession(DEV_SEED_TOKEN)
      .then(function (session) {
        persistAdminSession(session, 'dev-token');
        console.log('✓ Admin Dev Token session OK', {
          adminUserId: session.adminUserId,
          email: session.email,
          role: session.role
        });
        return session;
      })
      .catch(function (error) {
        throw new Error(friendlySessionError(error));
      });
  }

  /**
   * 登出：清 sessionStorage；若有 Firebase 一併 signOut
   * @returns {Promise<void>}
   */
  function logout() {
    var signOutPromise = Promise.resolve();
    if (global.YuruiFirebase && typeof global.YuruiFirebase.signOut === 'function') {
      signOutPromise = global.YuruiFirebase.signOut();
    }
    return signOutPromise
      .catch(function (error) {
        console.warn('[AdminAuth] Firebase signOut 失敗（繼續清 session）:', error);
      })
      .then(function () {
        clearAdminSessionStorage();
        if (global.AppAuth && typeof global.AppAuth.configure === 'function') {
          try {
            global.AppAuth.configure({ auth: null, devToken: '' });
          } catch (error) {
            // ignore
          }
        }
      });
  }

  /**
   * Dashboard 載入時：若已用 Firebase 登入，把 Auth 注回 AppAuth
   * @returns {Promise<void>}
   */
  function restoreAppAuthIfNeeded() {
    var source = sessionStorage.getItem(SESSION_KEYS.authSource);
    if (source !== 'firebase') {
      return Promise.resolve();
    }
    return import('/storefront/js/firebase-app.js')
      .then(function () {
        ensureAppAuthWired();
      })
      .catch(function (error) {
        console.warn('[AdminAuth] 還原 AppAuth 失敗:', error);
      });
  }

  global.AdminAuth = {
    SESSION_KEYS: SESSION_KEYS,
    DEV_SEED_TOKEN: DEV_SEED_TOKEN,
    mapEffectivePermissionsToUi: mapEffectivePermissionsToUi,
    persistAdminSession: persistAdminSession,
    clearAdminSessionStorage: clearAdminSessionStorage,
    loginWithGoogle: loginWithGoogle,
    loginWithDevSeedToken: loginWithDevSeedToken,
    logout: logout,
    restoreAppAuthIfNeeded: restoreAppAuthIfNeeded,
    friendlySessionError: friendlySessionError
  };
})(typeof window !== 'undefined' ? window : this);
