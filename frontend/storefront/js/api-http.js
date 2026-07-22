/**
 * 後端 REST 共用 HTTP（步驟 2-5）
 * Shared backend fetch with Firebase Bearer (Step 2-5)
 *
 * - 自動帶 Authorization: Bearer <Firebase ID Token>
 * - 優先用 Firebase currentUser.getIdToken() 刷新，否則用 localStorage
 * - Public GET 有 token 也無妨（後端可忽略）
 *
 * 步驟 2-6／3-x 手動驗收：
 * 1. Google／Facebook／LINE 登入 → session 200 → Console「✓ GET /api/me OK」
 * 2. Network：GET /api/me 有 Authorization: Bearer ...
 * 3. 登出後 fetchMe 應失敗
 * 4. 已無 mock U001 登入管道
 */
(function (global) {
  'use strict';

  var ID_TOKEN_KEY = 'yuruiFirebaseIdToken';

  /**
   * 取得可用的 ID Token（必要時向 Firebase 刷新並寫回 localStorage）。
   * @param {boolean} [forceRefresh=false]
   * @returns {Promise<string|null>}
   */
  function getValidIdToken(forceRefresh) {
    forceRefresh = Boolean(forceRefresh);
    var firebase = global.YuruiFirebase;
    var currentUser = firebase && firebase.auth && firebase.auth.currentUser;

    if (currentUser && typeof currentUser.getIdToken === 'function') {
      return currentUser
        .getIdToken(forceRefresh)
        .then(function (token) {
          if (token) {
            try {
              localStorage.setItem(ID_TOKEN_KEY, token);
            } catch (error) {
              console.warn('[YuruiApiHttp] persist token failed:', error);
            }
          }
          return token || null;
        })
        .catch(function (error) {
          console.warn('[YuruiApiHttp] getIdToken failed, fallback to storage:', error);
          return localStorage.getItem(ID_TOKEN_KEY) || null;
        });
    }

    return Promise.resolve(localStorage.getItem(ID_TOKEN_KEY) || null);
  }

  /**
   * 合併 Authorization（不覆寫呼叫端已設的 Authorization）。
   * @param {HeadersInit|undefined} headers
   * @param {string|null} idToken
   * @returns {Record<string, string>}
   */
  function mergeAuthHeaders(headers, idToken) {
    var merged = {};
    if (headers) {
      if (typeof Headers !== 'undefined' && headers instanceof Headers) {
        headers.forEach(function (value, key) {
          merged[key] = value;
        });
      } else if (Array.isArray(headers)) {
        headers.forEach(function (pair) {
          if (pair && pair.length >= 2) merged[pair[0]] = pair[1];
        });
      } else {
        Object.keys(headers).forEach(function (key) {
          merged[key] = headers[key];
        });
      }
    }

    var hasAuth = Object.keys(merged).some(function (key) {
      return String(key).toLowerCase() === 'authorization';
    });
    if (!hasAuth && idToken) {
      merged.Authorization = 'Bearer ' + idToken;
    }
    return merged;
  }

  /**
   * 帶 Bearer 的 fetch（步驟 2-5）。
   * @param {string} url
   * @param {RequestInit} [options]
   * @returns {Promise<Response>}
   */
  function apiFetch(url, options) {
    options = options || {};
    return getValidIdToken(false).then(function (idToken) {
      var next = Object.assign({}, options);
      next.headers = mergeAuthHeaders(options.headers, idToken);
      if (next.cache === undefined) next.cache = 'no-store';
      return fetch(url, next);
    });
  }

  /**
   * fetch + JSON parse；非 2xx 拋錯。
   * @param {string} url
   * @param {RequestInit} [options]
   * @returns {Promise<any>}
   */
  function fetchJson(url, options) {
    return apiFetch(url, options).then(function (res) {
      if (!res.ok) {
        var err = new Error('Fetch failed: ' + url + ' (HTTP ' + res.status + ')');
        err.status = res.status;
        throw err;
      }
      return res.json();
    });
  }

  /**
   * 步驟 2-6：打 GET /api/me 確認 Bearer 可用。
   * @returns {Promise<object>} data（CustomerPrincipal／session 形狀）
   */
  function fetchMe() {
    var base = String((global.AppConfig && global.AppConfig.API_BASE_URL) || '').replace(/\/$/, '');
    return apiFetch(base + '/me', { method: 'GET' }).then(function (res) {
      return res.json().then(function (body) {
        if (!res.ok || !body || body.success !== true) {
          var message =
            (body && body.error && body.error.message) ||
            'GET /api/me failed (HTTP ' + res.status + ')';
          throw new Error(message);
        }
        return body.data;
      });
    });
  }

  global.YuruiApiHttp = {
    getValidIdToken: getValidIdToken,
    apiFetch: apiFetch,
    fetchJson: fetchJson,
    fetchMe: fetchMe,
    mergeAuthHeaders: mergeAuthHeaders
  };
})(window);
