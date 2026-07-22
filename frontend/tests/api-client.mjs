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
