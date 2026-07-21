/**
 * 主站與 booking 共用的前端登入狀態模組。
 * 同步 currentUser、yuruiUser、isLoggedIn 與可用時的 AppState。
 */
(function () {
  'use strict';

  var STORAGE_KEYS = {
    isLoggedIn: 'isLoggedIn',
    currentUser: 'currentUser',
    bookingUser: 'yuruiUser'
  };

  function readJsonStorage(key, fallback) {
    try {
      return JSON.parse(localStorage.getItem(key) || JSON.stringify(fallback));
    } catch (error) {
      console.warn('Auth storage parse failed:', key, error);
      return fallback;
    }
  }

  function getProviderLabel(provider) {
    var value = String(provider || 'Google').toLowerCase();
    if (value === 'line') return 'LINE';
    if (value === 'facebook') return 'Facebook';
    return 'Google';
  }

  /** Fallback 測試會員（API 不可用時） */
  function createMockUser(provider) {
    return {
      id: 'U001',
      name: 'Amy Chen',
      email: 'amy@example.com',
      avatarUrl: getProviderLabel(provider).charAt(0),
      provider: String(provider || 'google').toLowerCase()
    };
  }

  function syncAppState(user) {
    if (!window.AppState) return;
    window.AppState.isLoggedIn = Boolean(user);
    window.AppState.currentUser = user || null;
    if (typeof window.saveAppState === 'function') window.saveAppState();
  }

  function persistUser(user) {
    localStorage.setItem(STORAGE_KEYS.isLoggedIn, JSON.stringify(Boolean(user)));
    if (user) {
      localStorage.setItem(STORAGE_KEYS.currentUser, JSON.stringify(user));
      localStorage.setItem(STORAGE_KEYS.bookingUser, JSON.stringify(user));
    } else {
      localStorage.removeItem(STORAGE_KEYS.currentUser);
      localStorage.removeItem(STORAGE_KEYS.bookingUser);
    }
    syncAppState(user);
  }

  function emitAuthChanged(type, user) {
    window.dispatchEvent(new CustomEvent('yurui:auth-changed', {
      detail: { type: type, user: user || null }
    }));
  }

  function readStoredUser() {
    return readJsonStorage(STORAGE_KEYS.currentUser, null)
      || readJsonStorage(STORAGE_KEYS.bookingUser, null);
  }

  function getUser() {
    if (window.AppState && window.AppState.isLoggedIn && window.AppState.currentUser) {
      return window.AppState.currentUser;
    }
    var user = readStoredUser();
    if (user && user.name) persistUser(user);
    return user && user.name ? user : null;
  }

  function isLoggedIn() {
    return Boolean(getUser());
  }

  /** 固定登入 Amy U001，從 API.customers 讀取 */
  function loginWithProvider(provider, options) {
    options = options || {};
    var label = getProviderLabel(provider);

    function finishLogin(user) {
      persistUser(user);
      emitAuthChanged('login', user);
      if (typeof options.close === 'function') options.close();
      if (options.showToast !== false && typeof window.showToast === 'function') {
        window.showToast('已使用 ' + label + ' 登入（' + user.name + '）', 'success');
      }
      if (options.openSurvey !== false && typeof window.openPersonalizationModal === 'function') {
        setTimeout(window.openPersonalizationModal, 300);
      }
      return user;
    }

    if (window.API && window.API.customers && window.API.customers.getById) {
      return window.API.customers.getById('U001').then(function (customer) {
        return finishLogin(Object.assign({}, customer, {
          provider: String(provider || 'google').toLowerCase()
        }));
      }).catch(function () {
        throw new Error('Active customer not found');
      });
    }

    return Promise.resolve(finishLogin(createMockUser(provider)));
  }

  function logout(options) {
    options = options || {};
    persistUser(null);
    emitAuthChanged('logout', null);
    if (typeof options.close === 'function') options.close();
    if (options.showToast !== false && typeof window.showToast === 'function') {
      window.showToast('已成功登出', 'success');
    }
  }

  window.YuruiAuth = {
    getProviderLabel: getProviderLabel,
    createMockUser: createMockUser,
    getUser: getUser,
    isLoggedIn: isLoggedIn,
    loginWithProvider: loginWithProvider,
    logout: logout,
    sync: function () {
      emitAuthChanged('sync', getUser());
    }
  };
}());
