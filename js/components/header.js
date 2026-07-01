// Shared header runtime for main-site partials.
(function () {
  'use strict';

  var lastMainFocus = null;

  function getCurrentUser() {
    if (window.YuruiAuth && typeof window.YuruiAuth.getUser === 'function') {
      return window.YuruiAuth.getUser();
    }
    if (!window.AppState || !window.AppState.isLoggedIn) return null;
    return window.AppState.currentUser || null;
  }

  function lockHeaderLayer(shouldLock) {
    document.body.classList.toggle('isHeaderLayerOpen', shouldLock);
  }

  function getFocusable(container) {
    if (!container) return [];
    return Array.from(container.querySelectorAll([
      'a[href]',
      'button:not([disabled])',
      'input:not([disabled])',
      'select:not([disabled])',
      'textarea:not([disabled])',
      '[tabindex]:not([tabindex="-1"])',
    ].join(',')));
  }

  function focusFirst(container) {
    var first = getFocusable(container)[0];
    if (first) first.focus();
  }

  function closeUserMenu() {
    document.querySelectorAll('.siteUserMenu').forEach(function (menu) {
      var trigger = menu.querySelector('.siteUserTrigger');
      var dropdown = menu.querySelector('.siteUserDropdown');
      if (trigger) trigger.setAttribute('aria-expanded', 'false');
      if (dropdown) {
        dropdown.classList.remove('isOpen');
        dropdown.hidden = true;
      }
    });
  }

  function toggleUserMenu(menu, shouldOpen) {
    var trigger = menu.querySelector('.siteUserTrigger');
    var dropdown = menu.querySelector('.siteUserDropdown');
    if (!trigger || !dropdown) return;
    dropdown.hidden = !shouldOpen;
    dropdown.classList.toggle('isOpen', shouldOpen);
    trigger.setAttribute('aria-expanded', String(shouldOpen));
    if (shouldOpen) focusFirst(dropdown);
  }

  function closeSearchLayer() {
    var search = document.querySelector('.siteSearch');
    if (!search) return;
    var toggle = search.querySelector('.siteSearchToggle');
    var form = search.querySelector('.siteSearchForm');
    var dropdown = search.querySelector('.siteSearchDropdown');
    search.classList.remove('isOpen');
    if (toggle) toggle.setAttribute('aria-expanded', 'false');
    if (form) form.hidden = true;
    if (dropdown) {
      dropdown.classList.remove('isVisible');
      dropdown.hidden = true;
    }
  }

  /**
   * 關閉搜尋建議區；目前商品 API 沒有即時搜尋端點，避免在 Header 杜撰資料。
   * 套用元件：.siteSearchDropdown。
   */
  function hideSearchDropdown() {
    var dropdown = document.querySelector('.siteSearchDropdown');
    if (!dropdown) return;
    dropdown.innerHTML = '';
    dropdown.classList.remove('isVisible');
    dropdown.hidden = true;
  }

  /**
   * 開啟 Header 搜尋表單並聚焦輸入框。
   * 套用元件：.siteSearchToggle、#siteSearchForm。
   */
  function openSearchLayer() {
    var search = document.querySelector('.siteSearch');
    if (!search) return;
    var toggle = search.querySelector('.siteSearchToggle');
    var form = search.querySelector('.siteSearchForm');
    var input = search.querySelector('.siteSearchInput');
    window.closeMainNavOffcanvas?.();
    closeUserMenu();
    search.classList.add('isOpen');
    if (toggle) toggle.setAttribute('aria-expanded', 'true');
    if (form) form.hidden = false;
    hideSearchDropdown();
    if (input) input.focus();
  }

  /**
   * 依目前頁面位置導向商品列表搜尋結果。
   * 套用元件：#siteSearchForm。
   */
  function getProductsSearchUrl(query) {
    var pagePath = window.location.pathname.includes('/pages/') ? 'products.html' : 'pages/products.html';
    return pagePath + '?keyword=' + encodeURIComponent(query);
  }

  /**
   * 送出 Header 搜尋表單。
   * 套用元件：#siteSearchForm。
   */
  function submitSearch(keyword) {
    var query = keyword.trim();
    if (!query) {
      window.showToast && window.showToast('請輸入搜尋關鍵字', 'warning');
      return;
    }
    window.location.href = getProductsSearchUrl(query);
  }

  window.closeMainSearchLayer = closeSearchLayer;

  window.closeMainNavOffcanvas = function () {
    var panel = document.getElementById('siteNavigationPanel');
    var backdrop = document.querySelector('.siteOffcanvasBackdrop');
    var button = document.querySelector('.siteMenuButton');
    if (panel) {
      panel.classList.remove('isOpen');
      panel.setAttribute('aria-hidden', 'true');
    }
    if (backdrop) {
      backdrop.classList.remove('isVisible');
      backdrop.hidden = true;
    }
    if (button) button.setAttribute('aria-expanded', 'false');
    lockHeaderLayer(Boolean(document.querySelector('.siteCartDrawer.isOpen')));
    if (lastMainFocus) lastMainFocus.focus();
  };

  function openMainNavOffcanvas(trigger) {
    var panel = document.getElementById('siteNavigationPanel');
    var backdrop = document.querySelector('.siteOffcanvasBackdrop');
    if (!panel) return;
    lastMainFocus = trigger || document.activeElement;
    window.closeMainHeaderDialogs?.();
    panel.classList.add('isOpen');
    panel.setAttribute('aria-hidden', 'false');
    if (backdrop) {
      backdrop.hidden = false;
      backdrop.classList.add('isVisible');
    }
    if (trigger) trigger.setAttribute('aria-expanded', 'true');
    lockHeaderLayer(true);
    focusFirst(panel);
  }

  window.closeMainHeaderDialogs = function () {
    window.closeMainNavOffcanvas?.();
    closeSearchLayer();
    closeUserMenu();
  };

  window.updateCartBadge = function () {
    if (!window.AppState || !Array.isArray(window.AppState.cart)) return;
    var count = window.AppState.cart.reduce(function (sum, item) {
      return sum + Number(item.quantity || 0);
    }, 0);
    document.querySelectorAll('.cartBadge, .siteCartBadge').forEach(function (badge) {
      badge.textContent = count > 9 ? '9+' : String(count);
      badge.hidden = count <= 0;
    });
  };

  window.updateNavbarLoginState = function () {
    var user = getCurrentUser();
    document.querySelectorAll('.siteLoginButton').forEach(function (button) {
      button.hidden = Boolean(user && user.name);
    });
    document.querySelectorAll('.siteUserMenu').forEach(function (menu) {
      var userName = menu.querySelector('.siteUserName');
      var userAvatar = menu.querySelector('.siteUserAvatar');
      menu.hidden = !(user && user.name);
      if (userName && user) userName.textContent = user.name;
      if (userAvatar && user) userAvatar.textContent = String(user.avatar || user.name.charAt(0)).toUpperCase();
      if (!user) toggleUserMenu(menu, false);
    });
  };

  window.handleLogout = function () {
    if (window.YuruiAuth && typeof window.YuruiAuth.logout === 'function') {
      window.YuruiAuth.logout({ close: closeUserMenu });
      return;
    }
    if (window.AppState) {
      window.AppState.isLoggedIn = false;
      window.AppState.currentUser = null;
      window.saveAppState?.();
    }
    localStorage.setItem('isLoggedIn', 'false');
    localStorage.removeItem('currentUser');
    localStorage.removeItem('yuruiUser');
    window.dispatchEvent(new CustomEvent('yurui:auth-changed', { detail: { type: 'logout', user: null } }));
    closeUserMenu();
    window.updateNavbarLoginState();
    window.showToast && window.showToast('已登出', 'success');
  };

  function bindSearch() {
    var search = document.querySelector('.siteSearch');
    if (!search || search.dataset.bound === 'true') return;
    search.dataset.bound = 'true';
    var toggle = search.querySelector('.siteSearchToggle');
    var form = search.querySelector('.siteSearchForm');
    var input = search.querySelector('.siteSearchInput');

    if (toggle) {
      toggle.addEventListener('click', function () {
        if (search.classList.contains('isOpen')) closeSearchLayer();
        else openSearchLayer();
      });
    }
    if (input) {
      input.addEventListener('input', function () {
        hideSearchDropdown();
      });
    }
    if (form) {
      form.addEventListener('submit', function (event) {
        event.preventDefault();
        submitSearch(input ? input.value : '');
      });
    }
  }

  function bindAuthButtons() {
    document.querySelectorAll('[data-modal-target]').forEach(function (button) {
      if (button.dataset.modalTriggerBound === 'true') return;
      button.dataset.modalTriggerBound = 'true';
      button.addEventListener('click', function () {
        var target = button.dataset.modalTarget;
        if (target) window.openModal?.(target);
      });
    });

    document.querySelectorAll('.siteUserMenu').forEach(function (menu) {
      if (menu.dataset.userMenuBound === 'true') return;
      menu.dataset.userMenuBound = 'true';
      var trigger = menu.querySelector('.siteUserTrigger');
      var logout = menu.querySelector('.siteLogoutButton');
      if (trigger) {
        trigger.addEventListener('click', function (event) {
          event.stopPropagation();
          var shouldOpen = trigger.getAttribute('aria-expanded') !== 'true';
          if (shouldOpen) closeSearchLayer();
          toggleUserMenu(menu, shouldOpen);
        });
      }
      if (logout) {
        logout.addEventListener('click', function (event) {
          event.preventDefault();
          window.handleLogout();
        });
      }
      closeSearchLayer();
    });
  }

  window.initNavbar = function () {
    var menuButton = document.querySelector('.siteMenuButton');
    var closeButton = document.querySelector('.siteOffcanvasClose');
    var backdrop = document.querySelector('.siteOffcanvasBackdrop');

    if (menuButton && menuButton.dataset.navBound !== 'true') {
      menuButton.dataset.navBound = 'true';
      menuButton.addEventListener('click', function () {
        openMainNavOffcanvas(menuButton);
      });
    }
    if (closeButton && closeButton.dataset.navBound !== 'true') {
      closeButton.dataset.navBound = 'true';
      closeButton.addEventListener('click', window.closeMainNavOffcanvas);
    }
    if (backdrop && backdrop.dataset.navBound !== 'true') {
      backdrop.dataset.navBound = 'true';
      backdrop.addEventListener('click', window.closeMainNavOffcanvas);
    }

    bindSearch();
    bindAuthButtons();
    window.updateCartBadge();
    window.updateNavbarLoginState();
  };

  if (!window.__siteHeaderGlobalBound) {
    window.__siteHeaderGlobalBound = true;
    document.addEventListener('click', function (event) {
      if (!event.target.closest('.siteSearch')) closeSearchLayer();
      if (!event.target.closest('.siteUserMenu')) closeUserMenu();
    });
    document.addEventListener('keydown', function (event) {
      if (event.key !== 'Escape') return;
      closeSearchLayer();
      closeUserMenu();
      window.closeMainNavOffcanvas?.();
      window.closeCartDrawer?.();
    });
    window.addEventListener('storage', function (event) {
      if (['isLoggedIn', 'currentUser', 'yuruiUser'].includes(event.key)) window.updateNavbarLoginState();
    });
    window.addEventListener('yurui:auth-changed', window.updateNavbarLoginState);
  }

  window.initNavbar();
}());
