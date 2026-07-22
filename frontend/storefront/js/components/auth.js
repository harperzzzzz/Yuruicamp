/**
 * 主站與 booking 共用的前端登入狀態模組（步驟 2-3／3-x）。
 * Shared auth — all providers via Firebase (no mock U001).
 *
 * Google／Facebook／LINE → Firebase popup → POST /auth/firebase/session → Bearer
 */
(function () {
  'use strict';

  var STORAGE_KEYS = {
    isLoggedIn: 'isLoggedIn',
    currentUser: 'currentUser',
    bookingUser: 'yuruiUser',
    idToken: 'yuruiFirebaseIdToken'
  };

  function readJsonStorage(key, fallback) {
    try {
      return JSON.parse(localStorage.getItem(key) || JSON.stringify(fallback));
    } catch (error) {
      console.warn('Auth storage parse failed:', key, error);
      return fallback;
    }
  }

  /**
   * @param {string} provider
   * @returns {'google'|'facebook'|'line'}
   */
  function normalizeProvider(provider) {
    var value = String(provider || 'google').toLowerCase();
    if (value === 'line') return 'line';
    if (value === 'facebook') return 'facebook';
    return 'google';
  }

  function getProviderLabel(provider) {
    var value = normalizeProvider(provider);
    if (value === 'line') return 'LINE';
    if (value === 'facebook') return 'Facebook';
    return 'Google';
  }

  function syncAppState(user) {
    if (!window.AppState) return;
    window.AppState.isLoggedIn = Boolean(user);
    window.AppState.currentUser = user || null;
    if (typeof window.saveAppState === 'function') window.saveAppState();
  }

  function persistIdToken(idToken) {
    if (idToken) {
      localStorage.setItem(STORAGE_KEYS.idToken, idToken);
    } else {
      localStorage.removeItem(STORAGE_KEYS.idToken);
    }
  }

  function getIdToken() {
    return localStorage.getItem(STORAGE_KEYS.idToken) || null;
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

  function finishLogin(user, options, label) {
    options = options || {};
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

  /**
   * @param {object} data
   * @returns {object}
   */
  function mapSessionToUser(data) {
    var name = data.name || data.email || '會員';
    return {
      id: data.customerId,
      name: name,
      email: data.email || '',
      provider: normalizeProvider(data.authProvider || 'google'),
      firebaseUid: data.firebaseUid || null,
      status: data.status || null,
      avatarUrl: String(name).charAt(0)
    };
  }

  function sessionUrl() {
    var base = String((window.AppConfig && window.AppConfig.API_BASE_URL) || '').replace(/\/$/, '');
    return base + '/auth/firebase/session';
  }

  function sessionErrorMessage(body, status) {
    if (body && body.error && body.error.message) return body.error.message;
    if (status === 401) {
      return 'Invalid Firebase ID token（請確認後端 FIREBASE_ENABLED=true）';
    }
    return '登入失敗（HTTP ' + status + '）';
  }

  function verifySessionWithMe() {
    if (!window.YuruiApiHttp || typeof window.YuruiApiHttp.fetchMe !== 'function') {
      console.warn('[YuruiAuth] YuruiApiHttp 尚未載入，跳過 /api/me 驗收');
      return Promise.resolve(null);
    }
    return window.YuruiApiHttp.fetchMe()
      .then(function (me) {
        console.log('✓ GET /api/me OK', me);
        return me;
      })
      .catch(function (error) {
        console.warn('✗ GET /api/me 失敗（登入 UI 仍可用）:', error && error.message ? error.message : error);
        return null;
      });
  }

  /**
   * 任一 OAuth provider：Firebase → session → /api/me（步驟 3-1～3-3，已無 mock U001）。
   * @param {string} provider
   * @param {object} [options]
   */
  function loginWithFirebaseProvider(provider, options) {
    options = options || {};
    var normalized = normalizeProvider(provider);
    var label = getProviderLabel(normalized);

    if (!window.YuruiFirebase || typeof window.YuruiFirebase.isReady !== 'function' || !window.YuruiFirebase.isReady()) {
      return Promise.reject(
        new Error('Firebase 尚未就緒。請確認 frontend/.env.local 並重啟 npm run dev。')
      );
    }
    if (typeof window.YuruiFirebase.signInWithProvider !== 'function') {
      return Promise.reject(new Error('YuruiFirebase.signInWithProvider 不可用，請硬刷頁面'));
    }

    return window.YuruiFirebase.signInWithProvider(normalized)
      .then(function (firebaseResult) {
        return fetch(sessionUrl(), {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ idToken: firebaseResult.idToken })
        }).then(function (response) {
          return response.json().then(function (body) {
            return { response: response, body: body, idToken: firebaseResult.idToken };
          }).catch(function () {
            throw new Error('伺服器回應格式錯誤');
          });
        });
      })
      .then(function (result) {
        if (!result.response.ok || !result.body || result.body.success !== true) {
          throw new Error(sessionErrorMessage(result.body, result.response.status));
        }
        persistIdToken(result.idToken);
        var user = finishLogin(mapSessionToUser(result.body.data), options, label);
        return verifySessionWithMe().then(function () {
          return user;
        });
      })
      .catch(function (error) {
        if (error && error.name === 'TypeError') {
          throw new Error('無法連線伺服器，請確認後端已啟動（localhost:8080）');
        }
        throw error;
      });
  }

  /** 對外入口：三顆按鈕都走真 Firebase（步驟 3-3） */
  function loginWithProvider(provider, options) {
    return loginWithFirebaseProvider(provider, options);
  }

  function logout(options) {
    options = options || {};

    var signOutPromise = Promise.resolve();
    if (window.YuruiFirebase && typeof window.YuruiFirebase.signOut === 'function') {
      signOutPromise = window.YuruiFirebase.signOut();
    }

    return signOutPromise
      .catch(function (error) {
        console.warn('Firebase signOut 失敗（繼續清本機狀態）:', error);
      })
      .then(function () {
        persistIdToken(null);
        persistUser(null);
        emitAuthChanged('logout', null);
        if (typeof options.close === 'function') options.close();
        if (options.showToast !== false && typeof window.showToast === 'function') {
          window.showToast('已成功登出', 'success');
        }
      });
  }

  window.YuruiAuth = {
    getProviderLabel: getProviderLabel,
    normalizeProvider: normalizeProvider,
    getUser: getUser,
    isLoggedIn: isLoggedIn,
    getIdToken: getIdToken,
    getValidIdToken: function (forceRefresh) {
      if (window.YuruiApiHttp && typeof window.YuruiApiHttp.getValidIdToken === 'function') {
        return window.YuruiApiHttp.getValidIdToken(forceRefresh);
      }
      return Promise.resolve(getIdToken());
    },
    apiFetch: function (url, options) {
      if (window.YuruiApiHttp && typeof window.YuruiApiHttp.apiFetch === 'function') {
        return window.YuruiApiHttp.apiFetch(url, options);
      }
      return fetch(url, options || {});
    },
    fetchMe: function () {
      if (window.YuruiApiHttp && typeof window.YuruiApiHttp.fetchMe === 'function') {
        return window.YuruiApiHttp.fetchMe();
      }
      return Promise.reject(new Error('YuruiApiHttp 尚未載入'));
    },
    verifySessionWithMe: verifySessionWithMe,
    loginWithProvider: loginWithProvider,
    logout: logout,
    sync: function () {
      emitAuthChanged('sync', getUser());
    }
  };
}());
