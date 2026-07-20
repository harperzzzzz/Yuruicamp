/**
 * booking-checkout.js
 * 功能：預約結帳頁邏輯
 *   ① 讀取 LocalStorage 取得完整 bookingCart
 *   ② 渲染住宿明細、裝備明細、費用加總
 *   ③ 聯絡資訊表單驗證
 *   ④ 模擬送出結帳（未來對接 Java 後端）
 *   ⑤ 結帳成功後清除 LocalStorage，跳轉預約成功頁
 */

$(document).ready(function () {
  // 讀取並正規化 bookingCart（camelCase；相容舊 snake_case）
  const bookingCart =
    typeof window.readBookingCart === 'function' ? window.readBookingCart() : null;

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
  $('input[name="paymentMethod"]').on('change', function () {
    const val = $(this).val();

    $('#payOptCredit').toggleClass('isSelected', val === 'credit');
    $('#payOptLine').toggleClass('isSelected', val === 'linepay');

    if (val === 'credit') {
      $('#creditCardSection').slideDown(200);
    } else {
      $('#creditCardSection').slideUp(200);
    }
  });

  $('#cardNumber').on('input', function () {
    let v = $(this).val().replace(/\D/g, '').substring(0, 16);
    v = v.replace(/(.{4})/g, '$1 ').trim();
    $(this).val(v);
  });

  $('#cardExpiry').on('input', function () {
    let v = $(this).val().replace(/\D/g, '').substring(0, 4);
    if (v.length >= 3) v = v.slice(0, 2) + ' / ' + v.slice(2);
    $(this).val(v);
  });

  $('#cardCvv').on('input', function () {
    $(this).val($(this).val().replace(/\D/g, '').substring(0, 4));
  });
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
  if (paymentMethod === 'credit') {
    const cardNum = $('#cardNumber').val().replace(/\s/g, '');
    const cardExpiry = $('#cardExpiry').val().trim();
    const cardCvv = $('#cardCvv').val().trim();
    if (cardNum.length < 16) {
      highlightError('#cardNumber', '請填寫完整的信用卡卡號（16 位）');
      return;
    }
    if (!/^\d{2} \/ \d{2}$/.test(cardExpiry)) {
      highlightError('#cardExpiry', '請填寫正確的到期日格式（MM / YY）');
      return;
    }
    if (cardCvv.length < 3) {
      highlightError('#cardCvv', '請填寫 CVV（3-4 位數字）');
      return;
    }
  }

  const payload = buildBookingPayload(cart, { name: name, phone: phone, email: email }, u, paymentMethod);

  $('#confirmPayBtn').prop('disabled', true).html('<i class="bi bi-hourglass-split"></i> 送出中...');

  if (!window.BookingAPI) {
    showToast('BookingAPI 未載入，請重新整理頁面。', 'error');
    $('#confirmPayBtn').prop('disabled', false).html('<i class="bi bi-lock-fill"></i> 確認預約並送出');
    return;
  }

  // 透過 BookingAPI 寫入 mockBookings（localStorage）並合併 seed 資料
  // Persist booking via BookingAPI → localStorage mockBookings
  window.BookingAPI.createBooking(payload)
    .then(function (booking) {
      console.log('[booking-checkout] 預約成功 / Booking created:', booking);
      onCheckoutSuccess(booking);
    })
    .catch(function (err) {
      console.error('[booking-checkout] 預約失敗 / Failed:', err);
      showToast('預約送出失敗，請稍後再試。', 'error');
      $('#confirmPayBtn')
        .prop('disabled', false)
        .html('<i class="bi bi-lock-fill"></i> 確認預約並送出');
    });
}

// ============================================================
// 組裝 createBooking payload（bookingCart 已是 camelCase，幾乎直接沿用）
// ============================================================

/**
 * 將 localStorage bookingCart（camelCase）組成 createBooking 需要的 payload
 * 只補結帳當下才有的欄位：contact / paymentMethod / history / customerNote
 * （3-13：不再做 snake_case → camelCase 轉換）
 */
function buildBookingPayload(cart, contact, user, paymentMethod) {
  var info = cart.bookingInfo || {};
  var summary = cart.summary || {};
  var now = new Date();
  var timeStr =
    now.getFullYear() +
    '-' +
    String(now.getMonth() + 1).padStart(2, '0') +
    '-' +
    String(now.getDate()).padStart(2, '0') +
    ' ' +
    String(now.getHours()).padStart(2, '0') +
    ':' +
    String(now.getMinutes()).padStart(2, '0') +
    ':' +
    String(now.getSeconds()).padStart(2, '0');

  var paidLabel = paymentMethod === 'cod' ? '現場付款（待確認）' : '已付款';

  return {
    customerId: user.id || user.customerId || 'U001',
    bookingInfo: {
      campgroundId: info.campgroundId,
      campgroundName: info.campgroundName,
      region: info.region,
      checkIn: info.checkIn,
      checkOut: info.checkOut,
      totalDays: info.totalDays,
      weekdayCount: info.weekdayCount,
      holidayCount: info.holidayCount,
      guestCount: info.guestCount,
    },
    selectedZones: (cart.selectedZones || []).map(function (z) {
      return {
        zoneId: z.zoneId,
        zoneType: z.zoneType,
        quantity: z.quantity,
        subtotal: z.subtotal,
      };
    }),
    selectedRentals: (cart.selectedRentals || []).map(function (r) {
      return {
        equipmentId: r.equipmentId,
        rentalSkuId: r.rentalSkuId,
        productId: r.productId,
        variantId: r.variantId,
        sku: r.sku,
        name: r.name,
        specLabel: r.specLabel || '',
        quantity: r.quantity,
        subtotal: r.subtotal,
      };
    }),
    summary: {
      zoneTotal: summary.zoneTotal || 0,
      rentalTotal: summary.rentalTotal || 0,
      appliedDiscount: summary.appliedDiscount || 0,
      finalAmount: summary.finalAmount || 0,
    },
    contact: contact,
    customerNote: $('#buyerNote').val().trim() || '',
    paymentMethod: paymentMethod,
    equipmentReturned: false,
    history: [
      { time: timeStr, action: '預約單已送出' },
      { time: timeStr, action: paidLabel },
    ],
  };
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
  // 防呆：確保 booking.id 是有效數字（NaN 也會被攔下）
  // Guard: ensure booking.id is a finite number (NaN is rejected too)
  if (!booking || booking.id == null || !Number.isFinite(Number(booking.id))) {
    console.error('[booking-checkout] 缺少有效 booking.id / Invalid booking.id:', booking);
    showToast('預約已送出，但編號異常，請至會員中心查看', 'warning');
    localStorage.removeItem('bookingCart');
    window.location.href = './member-center.html';
    return;
  }

  localStorage.removeItem('bookingCart');
  localStorage.setItem('lastCheckoutBooking', JSON.stringify(booking));
  // 同分頁跳轉備援，比 localStorage 更可靠
  // Same-tab handoff fallback; more reliable than localStorage alone
  sessionStorage.setItem('lastCheckoutBooking', JSON.stringify(booking));

  var bookingNum = toBookingDisplayNum(booking.id) || String(booking.id);

  window.location.href =
    './booking-success.html?bookingNum=' + encodeURIComponent(bookingNum);
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
