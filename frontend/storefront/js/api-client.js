// ========================================
// 前端認證與 REST 請求共用層
// ========================================

(function (global) {
  'use strict';

  var configuredAuth = null;
  var configuredDevToken = '';

  /**
   * 保存後端錯誤碼、欄位細節與 HTTP 狀態，讓頁面只處理一致的錯誤物件。
   */
  function ApiRequestError(code, message, details, status, cause) {
    this.name = 'ApiRequestError';
    this.code = code || 'API_REQUEST_FAILED';
    this.message = message || 'API request failed';
    this.details = Array.isArray(details) ? details : [];
    this.status = Number.isInteger(status) ? status : 0;
    this.cause = cause || null;

    if (Error.captureStackTrace) {
      Error.captureStackTrace(this, ApiRequestError);
    }
  }

  ApiRequestError.prototype = Object.create(Error.prototype);
  ApiRequestError.prototype.constructor = ApiRequestError;

  /**
   * 取得已注入的 Firebase Auth；相容 compat SDK 與應用自行保存的 auth instance。
   */
  function resolveFirebaseAuth() {
    if (configuredAuth) {
      return configuredAuth;
    }

    if (global.FirebaseAuth && global.FirebaseAuth.currentUser) {
      return global.FirebaseAuth;
    }

    if (global.firebase && typeof global.firebase.auth === 'function') {
      return global.firebase.auth();
    }

    return null;
  }

  /**
   * 本機 dev Token 只允許 development，並且必須使用後端支援的 dev: 格式。
   */
  function resolveDevToken() {
    var configToken = global.AppConfig
      && global.AppConfig.AUTH
      && global.AppConfig.AUTH.DEV_TOKEN;
    var token = String(configuredDevToken || configToken || '').trim();

    if (!token) {
      return '';
    }

    if (global.AppConfig && global.AppConfig.ENVIRONMENT !== 'development') {
      throw new ApiRequestError(
        'DEV_AUTH_NOT_ALLOWED',
        '開發 Token 只能在 development 環境使用。'
      );
    }

    if (token.indexOf('dev:') !== 0) {
      throw new ApiRequestError(
        'DEV_AUTH_TOKEN_INVALID',
        '開發 Token 必須使用後端支援的 dev: 格式。'
      );
    }

    return token;
  }

  var AppAuth = {
    /**
     * 應用啟動時可注入 Firebase Auth；本機也可暫時注入 dev Token。
     */
    configure: function (options) {
      var next = options || {};

      if (Object.prototype.hasOwnProperty.call(next, 'auth')) {
        configuredAuth = next.auth || null;
      }

      if (Object.prototype.hasOwnProperty.call(next, 'devToken')) {
        configuredDevToken = String(next.devToken || '').trim();
      }
    },

    /**
     * 正式模式優先向 Firebase currentUser 取得最新 ID Token。
     */
    getIdToken: async function (options) {
      var settings = options || {};
      var required = settings.required !== false;
      var auth = resolveFirebaseAuth();
      var user = auth && auth.currentUser;

      if (user && typeof user.getIdToken === 'function') {
        return user.getIdToken(settings.forceRefresh === true);
      }

      var devToken = resolveDevToken();
      if (devToken) {
        return devToken;
      }

      if (required) {
        throw new ApiRequestError(
          'AUTH_TOKEN_UNAVAILABLE',
          '目前沒有可用的 Firebase 登入或開發認證設定。',
          [],
          401
        );
      }

      return null;
    },
  };

  /**
   * 將 API_BASE_URL 與資源路徑安全合併，避免多一個或少一個斜線。
   */
  function buildRestUrl(path, baseUrl) {
    var base = String(baseUrl || (global.AppConfig && global.AppConfig.API_BASE_URL) || '')
      .replace(/\/+$/, '');
    var resource = String(path || '');

    if (/^https?:\/\//i.test(resource)) {
      return resource;
    }

    if (!base) {
      throw new ApiRequestError('API_BASE_URL_MISSING', '尚未設定 API_BASE_URL。');
    }

    return base + '/' + resource.replace(/^\/+/, '');
  }

  /**
   * 將後端 Envelope 的 error 轉為統一前端錯誤。
   */
  function toApiError(response, json, fallbackCode, fallbackMessage, cause) {
    var error = json && json.error ? json.error : {};

    return new ApiRequestError(
      error.code || fallbackCode,
      error.message || fallbackMessage,
      error.details,
      response ? response.status : 0,
      cause
    );
  }

  /**
   * 所有真後端請求的唯一入口；頁面與各 facade 不直接處理 fetch、Token 或 Envelope。
   */
  async function _restRequest(path, options) {
    var settings = options || {};
    var authMode = settings.auth || 'optional';
    var headers = new Headers(settings.headers || {});
    var body = settings.body;
    var requestOptions = {
      method: settings.method || 'GET',
      headers: headers,
      cache: settings.cache || 'no-store',
    };

    headers.set('Accept', 'application/json');
    if (!headers.has('Content-Type')) {
      headers.set('Content-Type', 'application/json');
    }

    if (authMode !== 'none') {
      var token = await AppAuth.getIdToken({
        required: authMode === 'required',
        forceRefresh: settings.forceRefresh === true,
      });

      if (token) {
        headers.set('Authorization', 'Bearer ' + token);
      }
    }

    if (body !== undefined && body !== null) {
      requestOptions.body = typeof body === 'string' ? body : JSON.stringify(body);
    }

    ['credentials', 'signal', 'redirect', 'referrerPolicy'].forEach(function (key) {
      if (settings[key] !== undefined) {
        requestOptions[key] = settings[key];
      }
    });

    var response;
    try {
      response = await fetch(buildRestUrl(path, settings.baseUrl), requestOptions);
    } catch (cause) {
      if (cause && cause.name === 'AbortError') {
        throw cause;
      }

      throw new ApiRequestError(
        'API_NETWORK_ERROR',
        '無法連線到後端服務。',
        [],
        0,
        cause
      );
    }

    if (response.status === 204) {
      if (!response.ok) {
        throw toApiError(response, null, 'API_REQUEST_FAILED', 'API request failed');
      }

      return settings.includeMeta ? { data: null, meta: null } : null;
    }

    var json;
    try {
      json = await response.json();
    } catch (cause) {
      throw new ApiRequestError(
        'API_RESPONSE_INVALID',
        '後端回應不是有效的 JSON。',
        [],
        response.status,
        cause
      );
    }

    if (!response.ok || !json || json.success !== true) {
      throw toApiError(
        response,
        json,
        'API_REQUEST_FAILED',
        'API request failed'
      );
    }

    if (settings.includeMeta) {
      return {
        data: json.data,
        meta: json.meta || null,
      };
    }

    return json.data;
  }

  global.ApiRequestError = ApiRequestError;
  global.AppAuth = AppAuth;
  global.ApiClient = {
    _restRequest: _restRequest,
  };
})(typeof window !== 'undefined' ? window : this);

console.log('✓ AppAuth 與 ApiClient 已初始化');
