/**
 * 後台登入頁：正式模式使用 Firebase Google 與 Admin Session；Mock 模式保留舊員工登入。
 */
(function (global) {
  'use strict';

  function showError(message) {
    $('#loginError').removeClass('d-none').text(message);
  }

  function clearError() {
    $('#loginError').addClass('d-none').text('');
  }

  function setBusy($button, busy, label) {
    $button.prop('disabled', busy);
    if (busy) {
      $button.data('original-html', $button.html());
      $button.html('<span class="spinner-border spinner-border-sm me-2"></span>' + label);
      return;
    }
    if ($button.data('original-html')) $button.html($button.data('original-html'));
  }

  function friendlyMessage(error) {
    var code = error && error.code;
    if (code === 'ADMIN_NOT_WHITELISTED') return '此 Google 帳號不在後台白名單中。';
    if (code === 'ADMIN_INACTIVE') return '此管理員帳號已停用。';
    if (code === 'FORBIDDEN') return '此 Email 已綁定其他 Firebase 帳號。';
    if (code === 'API_NETWORK_ERROR') return '無法連線後端，請確認 Spring Boot 已啟動。';
    return (error && error.message) || '登入失敗，請稍後再試。';
  }

  async function completeLogin(idToken) {
    await global.AdminRuntime.refreshBackendSession({ idToken: idToken });
    global.location.href = '/admin/dashboard.html';
  }

  async function initializeBackendLogin() {
    $('#loginForm, #mockLoginHint').addClass('d-none');
    $('#backendLoginPanel').removeClass('d-none');
    var storedMessage = sessionStorage.getItem('adminLoginMessage');
    sessionStorage.removeItem('adminLoginMessage');
    if (storedMessage) showError(storedMessage);

    try {
      var auth = await global.AdminRuntime.initializeFirebase();
      $('#firebaseLoginStatus').toggleClass('d-none', !!auth);
      $('#googleAdminLoginBtn').prop('disabled', !auth);
      if (auth && auth.currentUser) {
        $('#googleAdminLoginBtn').html('<i class="fab fa-google me-2"></i>繼續使用 ' +
          $('<div>').text(auth.currentUser.email || '目前帳號').html());
      }
    } catch (error) {
      $('#firebaseLoginStatus').removeClass('d-none').text(friendlyMessage(error));
      $('#googleAdminLoginBtn').prop('disabled', true);
    }

    if (global.AppConfig && global.AppConfig.ENVIRONMENT === 'development') {
      $('#adminDevLoginPanel').removeClass('d-none');
      $('#adminDevToken').val((global.AppConfig.AUTH && global.AppConfig.AUTH.DEV_TOKEN) || '');
    }
  }

  function loadMockEmployeeStore() {
    var script = document.createElement('script');
    script.src = '/admin/js/permissions.js';
    script.onload = function () {
      $('#loginBtn').prop('disabled', false);
      bindMockLogin();
    };
    script.onerror = function () {
      showError('Mock 員工資料載入失敗。');
    };
    $('#loginBtn').prop('disabled', true);
    document.head.appendChild(script);
  }

  /** Mock 模式才允許舊員工 ID 登入，避免正式流程讀取 localStorage 員工。 */
  function bindMockLogin() {
    $('#loginForm').off('submit.adminMock').on('submit.adminMock', function (event) {
      event.preventDefault();
      var employeeId = $('#username').val().trim();
      var password = $('#password').val().trim();
      clearError();
      $('#username, #password').removeClass('is-invalid');
      if (!employeeId || !password) {
        $('#username').toggleClass('is-invalid', !employeeId);
        $('#password').toggleClass('is-invalid', !password);
        showError('請輸入員工 ID 與密碼。');
        return;
      }
      var employee = global.findEmployeeById(employeeId);
      if (!employee || !employee.isActive) {
        showError('帳號不存在或已停用。');
        return;
      }
      sessionStorage.setItem('adminLoggedIn', 'true');
      sessionStorage.setItem('adminId', employee.id);
      sessionStorage.setItem('adminName', employee.displayName);
      sessionStorage.setItem('isSuperAdmin', String(!!employee.isSuperAdmin));
      sessionStorage.setItem('adminPermissions', JSON.stringify(employee.permissions || {}));
      global.location.href = '/admin/dashboard.html';
    });
  }

  $(document).ready(function () {
    $('#togglePassword').on('click', function () {
      var $password = $('#password');
      var reveal = $password.attr('type') === 'password';
      $password.attr('type', reveal ? 'text' : 'password');
      $('#toggleIcon').toggleClass('fa-eye', !reveal).toggleClass('fa-eye-slash', reveal);
    });

    if (!global.AdminRuntime.isBackendMode()) {
      loadMockEmployeeStore();
      return;
    }

    // 移除舊 Mock 表單事件，正式模式只允許 Firebase 或 development dev Token。
    $('#loginForm').off('submit');
    initializeBackendLogin();

    $('#googleAdminLoginBtn').on('click', async function () {
      var $button = $(this);
      clearError();
      setBusy($button, true, '驗證管理員資格...');
      try {
        var firebaseResult = await global.YuruiFirebase.signInWithGoogle();
        sessionStorage.removeItem('adminDevToken');
        global.AppAuth.configure({ auth: global.YuruiFirebase.getAuth(), devToken: '' });
        await completeLogin(firebaseResult.idToken);
      } catch (error) {
        showError(friendlyMessage(error));
        setBusy($button, false);
      }
    });

    $('#adminDevLoginBtn').on('click', async function () {
      var $button = $(this);
      var token = $('#adminDevToken').val().trim();
      clearError();
      if (!token || token.indexOf('dev:') !== 0) {
        showError('請輸入後端支援的完整 dev: Token。');
        return;
      }
      setBusy($button, true, '驗證開發帳號...');
      try {
        sessionStorage.setItem('adminDevToken', token);
        global.AppAuth.configure({ auth: null, devToken: token });
        await completeLogin(token);
      } catch (error) {
        showError(friendlyMessage(error));
        setBusy($button, false);
      }
    });
  });
})(typeof window !== 'undefined' ? window : this);
