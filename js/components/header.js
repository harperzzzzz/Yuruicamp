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
<<<<<<< Updated upstream
  window.closeMainNavOffcanvas = _closeOffcanvas;
}

/**
 * 私有函數：初始化搜尋框（含下拉建議）
 * Private: Initialize search bar with dropdown suggestions
 */
function _initSearchBar() {
  const searchInput = document.querySelector('.navbar-search-input');
  const searchDropdown = document.querySelector('.navbar-search-dropdown');
  const searchForm = document.querySelector('.navbar-search-form');
  const searchWrapper = document.querySelector('.navbar-search-wrapper');
  const searchToggle = document.querySelector('.navbar-search-toggle');

  if (!searchInput || !searchDropdown || !searchWrapper) return;

  /**
   * 關閉搜尋表單與搜尋建議，讓搜尋層回到不佔畫面的收合狀態。
   */
  const closeSearchLayer = () => {
    searchWrapper.classList.remove('is-open');
    searchForm?.setAttribute('aria-hidden', 'true');
    searchToggle?.setAttribute('aria-expanded', 'false');
    searchDropdown.classList.remove('active');
  };

  /**
   * 對外提供搜尋層關閉入口，供購物車、選單與其他 dialog 開啟前共用。
   */
  window.closeMainSearchLayer = closeSearchLayer;

  // Search form starts collapsed; clicking the icon reveals it under the header.
  if (searchToggle && searchToggle.dataset.searchBound !== 'true') {
    searchToggle.dataset.searchBound = 'true';
    searchToggle.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
      const willOpen = !searchWrapper.classList.contains('is-open');
      searchWrapper.classList.toggle('is-open', willOpen);
      searchForm?.setAttribute('aria-hidden', String(!willOpen));
      searchToggle.setAttribute('aria-expanded', String(willOpen));
      if (willOpen) {
        _renderDropdown(SEARCH_SUGGESTIONS.slice(0, 6), searchDropdown, '熱門搜尋');
        searchInput.focus();
      } else {
        searchDropdown.classList.remove('active');
      }
    });
=======
  function hideSearchDropdown() {
    var dropdown = document.querySelector('.siteSearchDropdown');
    if (!dropdown) return;
    dropdown.innerHTML = '';
    dropdown.classList.remove('isVisible');
    dropdown.hidden = true;
>>>>>>> Stashed changes
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
<<<<<<< Updated upstream
    }
  }, 200));

  // 搜尋框獲得焦點 → 顯示熱門搜尋下拉
  searchInput.addEventListener('focus', () => {
    _renderDropdown(SEARCH_SUGGESTIONS.slice(0, 6), searchDropdown, '熱門搜尋');
    searchDropdown.classList.add('active');
  });

  // 點擊頁面其他地方 → 關閉搜尋按鈕展開狀態與下拉視窗
  document.addEventListener('click', (e) => {
    if (!e.target.closest('.navbar-search-wrapper')) {
      closeSearchLayer();
    }
  });

  // 送出搜尋表單（模擬）
  if (searchForm) {
    searchForm.addEventListener('submit', (e) => {
      e.preventDefault();
      const query = searchInput.value.trim();
      if (query) {
        window.showToast(`搜尋：${query}`, 'info');
        // 實際頁面跳轉：window.location.href = `/pages/products.html?q=${encodeURIComponent(query)}`;
=======
      if (logout) {
        logout.addEventListener('click', function (event) {
          event.preventDefault();
          window.handleLogout();
        });
>>>>>>> Stashed changes
      }
      closeSearchLayer();
    });
  }

<<<<<<< Updated upstream
/**
 * Closes visible main-site dialogs before opening another layer.
 */
window.closeMainHeaderDialogs = () => {
  window.closeMainSearchLayer?.();
  document.querySelector('.navbar-user-dropdown')?.setAttribute('hidden', '');
  window.closeMainNavOffcanvas?.();
  document.querySelectorAll('#loginModal.active, #personalizationModal.active').forEach((modal) => {
    modal.classList.remove('active');
  });
};

/**
 * 私有函數：渲染搜尋下拉選單
 * Private: Render search dropdown list
 * @param {string[]} items - 建議關鍵字列表
 * @param {HTMLElement} dropdown - 下拉容器
 * @param {string} title - 標題文字
 */
function _renderDropdown(items, dropdown, title) {
  if (items.length === 0) {
    dropdown.innerHTML = '<div class="search-dropdown-empty">找不到相關搜尋</div>';
    dropdown.classList.add('active');
    return;
  }

  const html = `
    ${title ? `<div class="search-dropdown-title">${title}</div>` : ''}
    <ul class="search-dropdown-list">
      ${items.map(item => `
        <li class="search-dropdown-item" data-keyword="${item}">
          🔍 ${item}
        </li>
      `).join('')}
    </ul>
  `;

  dropdown.innerHTML = html;
  dropdown.classList.add('active');

  // 點擊建議項目 → 填入搜尋框並送出
  dropdown.querySelectorAll('.search-dropdown-item').forEach(el => {
    el.addEventListener('click', () => {
      const keyword = el.dataset.keyword;
      const searchInput = document.querySelector('.navbar-search-input');
      if (searchInput) searchInput.value = keyword;
      window.closeMainSearchLayer?.();
      window.showToast(`搜尋：${keyword}`, 'info');
    });
  });
}

/**
 * 更新購物車 Badge 計數
 * Update cart badge number
 */
window.updateCartBadge = () => {
  const cartBadge = document.querySelector('.cart-badge');
  if (!cartBadge) return;

  // 計算購物車中商品的總數量
  const count = window.AppState.cart.reduce((sum, item) => sum + item.quantity, 0);
  cartBadge.textContent = count;

  // 有商品才顯示 Badge，沒有則隱藏
  cartBadge.hidden = count <= 0;
};

/**
 * 根據登入狀態更新導航欄顯示
 * Update navbar UI based on login state
 */
window.updateNavbarLoginState = () => {
  const loginButtons = document.querySelectorAll('.navbar-login-btn');
  const userMenus = document.querySelectorAll('.navbar-user-menu');
  const user = window.YuruiAuth && typeof window.YuruiAuth.getUser === 'function'
    ? window.YuruiAuth.getUser()
    : (window.AppState.isLoggedIn && window.AppState.currentUser ? window.AppState.currentUser : null);

  if (user) {
    // 已登入：隱藏「登入」按鈕，顯示用戶選單
    loginButtons.forEach(loginBtn => { loginBtn.hidden = true; });
    userMenus.forEach(userMenu => {
      userMenu.hidden = false;
      const userName = userMenu.querySelector('.user-name');
      const userAvatar = userMenu.querySelector('.user-avatar');
      if (userName) userName.textContent = user.name;
      if (userAvatar) userAvatar.textContent = (user.avatar || user.name.charAt(0)).toUpperCase();

      // 初始化用戶選單下拉功能
      _initUserMenuDropdown(userMenu);
    });
  } else {
    // 未登入：顯示「登入」按鈕，隱藏用戶選單
    loginButtons.forEach(loginBtn => { loginBtn.hidden = false; });
    userMenus.forEach(userMenu => { userMenu.hidden = true; });
  }
};

/**
 * 綁定共用 auth 事件，讓主站與 booking 的登入狀態即時同步。
 */
function _bindAuthStateEvents() {
  if (document.body.dataset.mainAuthStateBound === 'true') return;
  document.body.dataset.mainAuthStateBound = 'true';

  window.addEventListener('yurui:auth-changed', window.updateNavbarLoginState);
  window.addEventListener('storage', (event) => {
    if (['isLoggedIn', 'currentUser', 'yuruiUser'].includes(event.key)) {
      window.updateNavbarLoginState();
=======
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
>>>>>>> Stashed changes
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
