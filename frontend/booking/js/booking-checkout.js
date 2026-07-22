/**
 * booking-checkout.js
 * 功能：預約結帳頁邏輯
 *   ① 讀取 LocalStorage 取得完整 bookingCart
 *   ② 渲染住宿明細、裝備明細、費用加總
 *   ③ 聯絡資訊表單驗證
 *   ④ 建立 pending、unpaid 的 Booking Checkout
 *   ⑤ 顯示後端價格與付款期限，付款確認留給線 D
 */

const BOOKING_IDEMPOTENCY_KEY = 'bookingCheckoutIdempotencyKey';
const BOOKING_FINGERPRINT_KEY = 'bookingCheckoutFingerprint';
let bookingCreationPromise = null;

$(document).ready(function () {
  // 讀取並正規化 bookingCart（camelCase；相容舊 snake_case）
  const bookingCart = typeof window.readBookingCart === 'function' ? window.readBookingCart() : null;

  if (!bookingCart || !bookingCart.bookingInfo) {
    showToast('購物車資料為空，請重新選擇。', 'warning');
    window.location.href = './booking-cart.html';
    return;
  }

  // 舊格式立刻寫回 camelCase
  if (typeof window.writeBookingCart === 'function') {
    window.writeBookingCart(bookingCart);
  }

  renderCheckoutPage(bookingCart);
  initAccordionPanels();
  initPaymentMethod();
  initFillProfileBtn();

  $('#confirmPayBtn').on('click', function () {
    handleCheckout(bookingCart);
  });
});

// ============================================================
// 渲染整頁預約明細
// ============================================================

function renderCheckoutPage(cart) {
  const info = cart.bookingInfo || {};
  const zones = cart.selectedZones || [];
  const rentals = cart.selectedRentals || [];
  const summary = cart.summary || {};

  // 住宿資訊
  const zoneRowsHTML = zones
    .map(
      (z) => `
    <div class="bookingSummaryRow">
      <span>
        <strong>${info.campgroundName}</strong>・${z.zoneType}・×${z.quantity} 個營位
      </span>
      <span><strong>NT$${z.subtotal.toLocaleString()}</strong></span>
    </div>
  `
    )
    .join('');

  $('#stayDetail').html(`
    <div class="bookingSummaryRow bookingSummaryRowMeta">
      <i class="bi bi-calendar3"></i>
      ${info.checkIn} ～ ${info.checkOut}
      （${info.totalDays} 晚｜平日 ${info.weekdayCount} 晚、假日 ${info.holidayCount} 晚）
    </div>
    <div class="bookingSummaryRow bookingSummaryRowMeta">
      <i class="bi bi-geo-alt"></i> ${info.region}
      &nbsp;&nbsp;
      <i class="bi bi-people"></i> ${info.guestCount} 人
    </div>
    ${zoneRowsHTML}
  `);

  // 租借裝備
  if (!rentals || rentals.length === 0) {
    $('#rentalDetail').html('<p class="bookingNoRental">本次未選擇租借裝備。</p>');
  } else {
    const rentalRowsHTML = rentals
      .map(
        (r) => `
      <div class="bookingSummaryRow">
        <span>${r.name}${r.specLabel ? ` <small class="bookingRentalSpec">(${r.specLabel})</small>` : ''} ×${r.quantity}</span>
        <span><strong>NT$${r.subtotal.toLocaleString()}</strong></span>
      </div>
    `
      )
      .join('');
    $('#rentalDetail').html(rentalRowsHTML);
  }

  // 費用明細
  let breakdownHTML = `
    <div class="bookingCostRow">
      <span>住宿費</span>
      <span>NT$${(summary.zoneTotal || 0).toLocaleString()}</span>
    </div>
    <div class="bookingCostRow">
      <span>裝備租借費</span>
      <span>NT$${(summary.rentalTotal || 0).toLocaleString()}</span>
    </div>
  `;

  if (summary.appliedDiscount > 0) {
    breakdownHTML += `
      <div class="bookingCostRow bookingCostRowDiscount">
        <span><i class="bi bi-tag"></i> 租借折扣優惠</span>
        <span>-NT$${summary.appliedDiscount.toLocaleString()}</span>
      </div>
    `;
  }

  $('#costBreakdown').html(breakdownHTML);
  $('#finalAmount').text(`NT$${(summary.finalAmount || 0).toLocaleString()}`);
}

// ============================================================
// 會員資料帶入 / Fill member profile
// ============================================================

/** 取得目前登入會員（優先 YuruiAuth，fallback localStorage） */
function getLoggedInUser() {
  if (window.YuruiAuth && typeof window.YuruiAuth.getUser === 'function') {
    return window.YuruiAuth.getUser();
  }
  try {
    var user = JSON.parse(localStorage.getItem('yuruiUser'));
    return user && user.name ? user : null;
  } catch {
    return null;
  }
}

/** 將會員姓名、電話、Email 填入訂購人欄位（備註不帶入） */
function fillContactFields(user) {
  if (!user) return;
  if (user.name) $('#contactName').val(user.name);
  if (user.phone) $('#contactPhone').val(user.phone);
  if (user.email) $('#contactEmail').val(user.email);
}

/** 已登入時自動帶入；未登入則略過 */
function tryAutoFillContactFields() {
  var user = getLoggedInUser();
  if (user) fillContactFields(user);
}

/** 綁定「帶入會員資料」按鈕與登入後自動填入 */
function initFillProfileBtn() {
  $('#fillProfileBtn').on('click', function () {
    var user = getLoggedInUser();
    if (!user) {
      showToast('請先登入後再帶入會員資料', 'info');
      if (typeof window.openModal === 'function') {
        window.openModal('loginModal');
      }
      return;
    }
    fillContactFields(user);
    showToast('已帶入會員資料', 'success');
  });

  window.addEventListener('yurui:auth-changed', function (e) {
    if (e.detail && e.detail.type === 'login' && e.detail.user) {
      fillContactFields(e.detail.user);
    }
  });
}

// ============================================================
// 登入守衛
// ============================================================

window.onBookingHeaderReady = function () {
  initLoginGuard();
  tryAutoFillContactFields();
};

function initLoginGuard() {
  function showNotice() {
    $('#loginNotice').addClass('isVisible');
  }
  function hideNotice() {
    $('#loginNotice').removeClass('isVisible');
  }

  if (!getLoggedInUser()) {
    setTimeout(function () {
      if (typeof window.openModal === 'function') {
        window.openModal('loginModal');
      }
      showNotice();
    }, 400);
  }

  $('#loginNoticeBtn').on('click', function () {
    if (typeof window.openModal === 'function') {
      window.openModal('loginModal');
    }
  });

  window.addEventListener('storage', function (e) {
    if (e.key === 'yuruiUser' || e.key === 'currentUser') {
      getLoggedInUser() ? hideNotice() : showNotice();
    }
  });

  window.addEventListener('yurui:auth-changed', function (e) {
    if (e.detail && e.detail.type === 'login') {
      hideNotice();
    } else if (e.detail && e.detail.type === 'logout') {
      showNotice();
    }
  });
}

// ============================================================
// 手風琴面板
// ============================================================

function initAccordionPanels() {
  // 手風琴互動：使用 checkoutPanel* 語意 class，讓 JS hook 與版型命名解耦。
  $('.checkoutPanelHeaderBooking').on('click', function () {
    const $panel = $(this).closest('.checkoutPanelBooking');
    const $body = $panel.find('> .checkoutPanelBodyBooking');
    const isOpen = $panel.hasClass('isOpen');

    if (isOpen) {
      $body.slideUp(200);
      $panel.removeClass('isOpen');
    } else {
      $body.slideDown(200);
      $panel.addClass('isOpen');
    }
  });
}

// ============================================================
// 付款方式互動
// ============================================================

function initPaymentMethod() {
  $('#payOptEcpay').addClass('isSelected');
}

// ============================================================
// 送出結帳
// ============================================================

function handleCheckout(cart) {
  var u = getLoggedInUser();
  if (!u) {
    if (typeof window.openModal === 'function') window.openModal('loginModal');
    return;
  }

  const name = $('#contactName').val().trim();
  const phone = $('#contactPhone').val().trim();
  const email = $('#contactEmail').val().trim();

  if (!name) {
    highlightError('#contactName', '請填寫訂購人姓名');
    return;
  }
  if (!phone || !/^[0-9]{8,12}$/.test(phone)) {
    highlightError('#contactPhone', '請填寫正確的手機號碼（8-12 位數字）');
    return;
  }
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    highlightError('#contactEmail', '請填寫有效的電子信箱格式');
    return;
  }

  const paymentMethod = $('input[name="paymentMethod"]:checked').val();

  const payload = buildBookingPayload(cart, paymentMethod);

  $('#confirmPayBtn').prop('disabled', true).html('<i class="bi bi-hourglass-split"></i> 送出中...');

  if (!window.BookingAPI) {
    showToast('BookingAPI 未載入，請重新整理頁面。', 'error');
    $('#confirmPayBtn').prop('disabled', false).html('<i class="bi bi-lock-fill"></i> 建立待付款預約');
    return;
  }

  // Backend 模式只送精簡契約；Mock 才會使用第二個參數產生顯示快照。
  createBookingOnce(payload, cart)
    .then(function (booking) {
      console.log('[booking-checkout] 預約成功 / Booking created:', booking);
      onCheckoutSuccess(booking);
    })
    .catch(function (err) {
      console.error('[booking-checkout] 預約失敗 / Failed:', err);
      showToast(err && err.message ? err.message : '預約送出失敗，請稍後再試。', 'error');
      $('#confirmPayBtn').prop('disabled', false).html('<i class="bi bi-lock-fill"></i> 建立待付款預約');
    });
}

// ============================================================
// 組裝 createBooking payload（bookingCart 已是 camelCase，幾乎直接沿用）
// ============================================================

/**
 * 將 bookingCart 組成 Booking API Contract 的精簡 Request。
 * 會員、價格、快照、付款狀態與聯絡資料都不交給前端決定。
 */
function buildBookingPayload(cart, paymentMethod) {
  var info = cart.bookingInfo || {};

  return {
    campgroundId: info.campgroundId,
    checkIn: info.checkIn,
    checkOut: info.checkOut,
    guestCount: Number(info.guestCount) || 1,
    zones: (cart.selectedZones || []).map(function (zone) {
      return {
        zoneId: zone.zoneId,
        quantity: Number(zone.quantity) || 1,
      };
    }),
    rentals: (cart.selectedRentals || []).map(function (rental) {
      return {
        rentalListingId: rental.rentalListingId || rental.equipmentId,
        rentalSkuVariantId: rental.rentalSkuVariantId || rental.variantId,
        quantity: Number(rental.quantity) || 1,
      };
    }),
    couponClaimId: null,
    paymentMethod: paymentMethod === 'ecpay-credit' ? paymentMethod : 'ecpay-credit',
    idempotencyKey: getBookingIdempotencyKey(cart),
  };
}

// 同一次送出與網路重試共用 Promise／冪等鍵，避免連點建立兩筆預約。
function createBookingOnce(request, cart) {
  if (!bookingCreationPromise) {
    bookingCreationPromise = window.BookingAPI.createBooking(request, cart).finally(function () {
      bookingCreationPromise = null;
    });
  }

  return bookingCreationPromise;
}

function getBookingIdempotencyKey(cart) {
  var fingerprint = JSON.stringify({
    bookingInfo: cart.bookingInfo,
    selectedZones: cart.selectedZones,
    selectedRentals: cart.selectedRentals,
  });
  var previousFingerprint = sessionStorage.getItem(BOOKING_FINGERPRINT_KEY);
  var key = sessionStorage.getItem(BOOKING_IDEMPOTENCY_KEY);

  if (!key || previousFingerprint !== fingerprint) {
    key =
      window.crypto && typeof window.crypto.randomUUID === 'function'
        ? window.crypto.randomUUID()
        : 'booking-' + Date.now() + '-' + Math.random().toString(36).slice(2);
    sessionStorage.setItem(BOOKING_IDEMPOTENCY_KEY, key);
    sessionStorage.setItem(BOOKING_FINGERPRINT_KEY, fingerprint);
  }

  return key;
}

// ============================================================
// 結帳成功後處理
// ============================================================

/**
 * 將 booking id 轉成顯示用編號，格式化失敗時回退原始 id
 * Format booking id for display; fall back to raw id when formatter returns empty
 */
function toBookingDisplayNum(id) {
  if (id == null || id === '') return '';
  var formatted = window.formatBookingDisplayId ? window.formatBookingDisplayId(id) : '';
  return formatted || String(id);
}

/**
 * 清除預約背包並跳轉成功頁（對應商城 checkout-success 流程）
 * Clear booking cart and redirect to booking success page
 */
function onCheckoutSuccess(booking) {
  var bookingId = booking && (booking.bookingId || booking.id);
  if (!bookingId) {
    console.error('[booking-checkout] 缺少 bookingId / Missing bookingId:', booking);
    showToast('預約已送出，但編號異常，請至會員中心查看', 'warning');
    localStorage.removeItem('bookingCart');
    window.location.href = './member-center.html';
    return;
  }

  localStorage.removeItem('bookingCart');
  sessionStorage.setItem('lastCheckoutBooking', JSON.stringify(booking));

  // 真後端模式不把 Booking 當成本機業務資料；Mock 才保留 localStorage 備援。
  if (window.BookingAPI && window.BookingAPI.isMockMode()) {
    localStorage.setItem('lastCheckoutBooking', JSON.stringify(booking));
  } else {
    localStorage.removeItem('lastCheckoutBooking');
  }

  var bookingNum = toBookingDisplayNum(bookingId) || String(bookingId);

  window.location.href = './booking-success.html?bookingNum=' + encodeURIComponent(bookingNum);
}

// ============================================================
// 工具函式
// ============================================================

function highlightError(selector, message) {
  const $input = $(selector);
  $input.addClass('isInvalid');
  $input.focus();
  setTimeout(() => $input.removeClass('isInvalid'), 2000);
  showToast(message, 'warning');
}
