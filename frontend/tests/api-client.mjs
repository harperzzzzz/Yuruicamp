import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const rootDir = dirname(dirname(fileURLToPath(import.meta.url)));
const clientSource = readFileSync(join(rootDir, 'storefront/js/api-client.js'), 'utf8');

/**
 * 建立最小瀏覽器環境，讓共用 API 層可以在 Node 中驗證。
 */
function createRuntime(fetchImpl, configOverrides = {}) {
  const appConfig = {
    API_BASE_URL: 'http://localhost:8080/api',
    ENVIRONMENT: 'development',
    AUTH: { DEV_TOKEN: '' },
    ...configOverrides,
  };
  const window = { AppConfig: appConfig };
  const context = {
    window,
    fetch: fetchImpl,
    Headers,
    console,
  };

  vm.runInNewContext(clientSource, context, { filename: 'api-client.js' });

  return window;
}

/**
 * 建立後端 Envelope Response。
 */
function jsonResponse(status, payload) {
  return {
    ok: status >= 200 && status < 300,
    status,
    json: async () => payload,
  };
}

{
  const runtime = createRuntime(async () => jsonResponse(200, { success: true, data: null }));
  runtime.AppAuth.configure({
    auth: {
      currentUser: {
        getIdToken: async (forceRefresh) => forceRefresh ? 'firebase-refresh' : 'firebase-token',
      },
    },
  });

  assert.equal(await runtime.AppAuth.getIdToken(), 'firebase-token');
  assert.equal(await runtime.AppAuth.getIdToken({ forceRefresh: true }), 'firebase-refresh');
}

{
  const runtime = createRuntime(async () => jsonResponse(200, { success: true, data: null }));
  const auth = {
    currentUser: null,
    authStateReady: async () => {
      auth.currentUser = {
        getIdToken: async () => 'restored-firebase-token',
      };
    },
  };
  runtime.AppAuth.configure({ auth });

  // 新分頁必須等 Firebase 從 IndexedDB 還原使用者後才讀取 Token。
  assert.equal(await runtime.AppAuth.getIdToken(), 'restored-firebase-token');
}

{
  const runtime = createRuntime(async () => jsonResponse(200, { success: true, data: null }));
  const auth = { currentUser: null };
  runtime.YuruiFirebase = {
    waitForAuthState: async () => {
      auth.currentUser = {
        getIdToken: async () => 'restored-fallback-token',
      };
    },
  };
  runtime.AppAuth.configure({ auth });

  // 舊版 Auth 沒有 authStateReady 時，仍使用共用 Firebase readiness 等待流程。
  assert.equal(await runtime.AppAuth.getIdToken(), 'restored-fallback-token');
}

{
  let requestStarted = false;
  let capturedAuthorization = '';
  const runtime = createRuntime(async (_url, options) => {
    requestStarted = true;
    capturedAuthorization = options.headers.get('Authorization');

    return jsonResponse(200, { success: true, data: { id: 'U001' } });
  });
  const pendingRequest = runtime.ApiClient._restRequest('/me', { auth: 'required' });

  await Promise.resolve();
  assert.equal(requestStarted, false);

  // 頁面 API 先啟動時，必須等 main.js 或 Booking layout 注入 Firebase Auth。
  runtime.AppAuth.configure({
    auth: {
      currentUser: {
        getIdToken: async () => 'late-configured-token',
      },
    },
  });

  const result = await pendingRequest;
  assert.equal(requestStarted, true);
  assert.equal(capturedAuthorization, 'Bearer late-configured-token');
  assert.equal(result.id, 'U001');
}

{
  const runtime = createRuntime(async () => jsonResponse(200, { success: true, data: null }));
  const pendingToken = runtime.AppAuth.getIdToken({ required: false });

  // Firebase 未設定時也必須明確完成 readiness，optional API 才能不帶 Token 繼續。
  runtime.AppAuth.configure({ auth: null });
  assert.equal(await pendingToken, null);
}

{
  const runtime = createRuntime(
    async () => jsonResponse(200, { success: true, data: null }),
    { AUTH: { DEV_TOKEN: 'dev:uid-local:local@example.com:google:Local' } },
  );

  assert.equal(
    await runtime.AppAuth.getIdToken(),
    'dev:uid-local:local@example.com:google:Local',
  );
}

{
  let capturedUrl = '';
  let capturedOptions = null;
  const runtime = createRuntime(async (url, options) => {
    capturedUrl = url;
    capturedOptions = options;

    return jsonResponse(200, {
      success: true,
      data: [{ id: 'P001' }],
      meta: { page: 0 },
    });
  });
  runtime.AppAuth.configure({ devToken: 'dev:uid-api:api@example.com:google:Api' });

  const result = await runtime.ApiClient._restRequest('/products', {
    method: 'POST',
    auth: 'required',
    includeMeta: true,
    body: { page: 0 },
  });

  assert.equal(capturedUrl, 'http://localhost:8080/api/products');
  assert.equal(capturedOptions.method, 'POST');
  assert.equal(capturedOptions.headers.get('Content-Type'), 'application/json');
  assert.equal(
    capturedOptions.headers.get('Authorization'),
    'Bearer dev:uid-api:api@example.com:google:Api',
  );
  assert.equal(capturedOptions.body, JSON.stringify({ page: 0 }));
  assert.equal(result.data[0].id, 'P001');
  assert.equal(result.meta.page, 0);
}

{
  const runtime = createRuntime(async () => jsonResponse(409, {
    success: false,
    error: {
      code: 'STOCK_INSUFFICIENT',
      message: '庫存不足',
      details: [{ field: 'items[0].quantity', reason: 'available=0' }],
    },
  }));

  await assert.rejects(
    runtime.ApiClient._restRequest('/checkout/sessions', { auth: 'none' }),
    (error) => {
      assert.equal(error.name, 'ApiRequestError');
      assert.equal(error.code, 'STOCK_INSUFFICIENT');
      assert.equal(error.message, '庫存不足');
      assert.equal(error.status, 409);
      assert.equal(error.details[0].field, 'items[0].quantity');

      return true;
    },
  );
}

{
  const tokens = [];
  let requestCount = 0;
  const runtime = createRuntime(async (_url, options) => {
    requestCount += 1;
    tokens.push(options.headers.get('Authorization'));
    if (requestCount === 1) {
      return jsonResponse(401, { success: false, error: { code: 'UNAUTHORIZED' } });
    }
    return jsonResponse(200, { success: true, data: { refreshed: true } });
  });
  runtime.AppAuth.configure({
    auth: {
      currentUser: {
        getIdToken: async forceRefresh => forceRefresh ? 'fresh-token' : 'expired-token',
      },
    },
  });

  const result = await runtime.ApiClient._restRequest('/admin/users', { auth: 'required' });
  assert.equal(requestCount, 2);
  assert.deepEqual(tokens, ['Bearer expired-token', 'Bearer fresh-token']);
  assert.equal(result.refreshed, true);
}

console.log('API client checks passed');
