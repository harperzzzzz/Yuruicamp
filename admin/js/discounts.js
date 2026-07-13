/**
 * admin/js/discounts.js
 * 折扣優惠管理模組
 * 使用 jQuery Event Namespace (.discounts) 防止重複導覽時事件堆疊
 *
 * 資料：data/promotions/coupons.json 種子 + window.couponsCache（記憶體）
 * 持久化：AdminAPI.coupons（後端就緒後啟用 useBackend）
 *
 * 物件欄位對齊 JSON 假資料與 DB coupons（前端 camelCase ↔ DB snake_case）：
 *   code, discount, type(fixed|percent), minOrder(min_order),
 *   quantity, used, startDate(start_date), endDate(end_date),
 *   status(active|disabled), category(promotion|birthday|firstPurchase)
 *
 * 表單欄位 ID：
 *   #newCouponCode, #newCouponDiscount, #newCouponQty, #newCouponMinOrder
 *   #newCouponStart, #newCouponEnd, #discountTypeSwitch
 *   #generateCouponCode, #submitAddCoupon, #setCouponStartNow
 */

window.couponsCache = window.couponsCache || [];

/** 依 code 更新快取中的優惠券 / Upsert coupon in cache by code */
function upsertCouponInCache(coupon) {
  var idx = window.couponsCache.findIndex(function (c) {
    return c.code === coupon.code;
  });
  if (idx >= 0) {
    window.couponsCache[idx] = coupon;
  } else {
    window.couponsCache.unshift(coupon);
  }
}

/** 從快取移除優惠券 / Remove coupon from cache */
function removeCouponFromCache(code) {
  window.couponsCache = window.couponsCache.filter(function (c) {
    return c.code !== code;
  });
}

/**
 * 將 "YYYY-MM-DDTHH:MM" 格式的時間字串轉為 "YYYY/MM/DD HH:MM" 顯示格式
 * Convert datetime-local string to a readable display format
 * 若傳入空值或 undefined，回傳 "—"
 *
 * @param {string} val - datetime-local 格式，例如 "2026-08-31T23:59"
 * @returns {string} 例如 "2026/08/31 23:59"，或 "—"
 */
function formatDateDisplay(val) {
  if (!val) return '—';
  var parts    = val.split('T');                  // ["2026-08-31", "23:59"]
  var datePart = parts[0].replace(/-/g, '/');     // "2026/08/31"
  return datePart + ' ' + (parts[1] || '');       // "2026/08/31 23:59"
}

/**
 * 依 coupon.type 顯示折扣（對齊 schema coupon_type 與 js/components/coupons.js）
 * Format discount cell by type: fixed → NT$; percent → n%
 *
 * @param {object} coupon - 須含 discount；type 缺省視為 fixed
 * @returns {{ html: string, isAmount: boolean }}
 */
function formatDiscountDisplay(coupon) {
  var type = coupon.type || 'fixed';
  var value = Number(coupon.discount) || 0;

  if (type === 'percent') {
    return { html: value + '%', isAmount: false };
  }
  return {
    html: 'NT$ ' + value.toLocaleString(),
    isAmount: true
  };
}

/**
 * 最低消費顯示：0 →「無門檻」；其餘 → NT$ xxx
 * Format minOrder (JSON) / min_order (DB)
 *
 * @param {number|string|undefined} minOrder
 * @returns {string} HTML 字串
 */
function formatMinOrderDisplay(minOrder) {
  var amount = Number(minOrder) || 0;
  if (amount > 0) {
    return 'NT$ ' + amount.toLocaleString();
  }
  return '<span class="text-muted">無門檻</span>';
}

window.initDiscounts = function () {
  $(document).off('.discounts');

  loadAdminJsonResource({
    adminList: AdminAPI && AdminAPI.coupons && AdminAPI.coupons.list,
    jsonPath: DataPaths.coupons,
    emptyValue: [],
    errorMessage: '載入優惠券失敗',
    onSuccess: function (coupons) {
      window.couponsCache = coupons || [];
      renderCouponsTable(window.couponsCache);
    },
    onError: function () {
      $('#couponsTableBody').html(
        '<tr><td colspan="10" class="text-center text-danger py-4">' +
        '<i class="fas fa-exclamation-triangle me-2"></i>載入優惠券數據失敗' +
        '</td></tr>'
      );
    }
  });

  // 折扣類型 Switch：對齊 schema coupon_type
  // 未勾選 = fixed（固定金額）；勾選 = percent（百分比）
  $(document).on('change.discounts', '#discountTypeSwitch', function () {
    var isPercent = $(this).is(':checked');

    if (isPercent) {
      // percent：discount 為百分比數字，例如 10 = 10% OFF
      $('#discountLabel').html('折扣百分比 (%) <span class="text-danger">*</span>');
      $('#newCouponDiscount')
        .attr('placeholder', '例：10')
        .attr('min', '1')
        .attr('max', '99')
        .attr('step', '1')
        .val('');
    } else {
      // fixed：discount 為新台幣金額
      $('#discountLabel').html('折扣金額 (NT$) <span class="text-danger">*</span>');
      $('#newCouponDiscount')
        .attr('placeholder', '例：200')
        .attr('min', '1')
        .removeAttr('max')
        .attr('step', '1')
        .val('');
    }
  });

  // 「現在」按鈕：將起始時間填入當下時間（精度到分鐘）
  $(document).on('click.discounts', '#setCouponStartNow', function () {
    var now    = new Date();
    var year   = now.getFullYear();
    var month  = String(now.getMonth() + 1).padStart(2, '0');
    var day    = String(now.getDate()).padStart(2, '0');
    var hour   = String(now.getHours()).padStart(2, '0');
    var minute = String(now.getMinutes()).padStart(2, '0');
    // datetime-local 格式必須是 "YYYY-MM-DDTHH:MM"
    $('#newCouponStart').val(year + '-' + month + '-' + day + 'T' + hour + ':' + minute);
  });

  // 產生隨機優惠碼（8碼英數）
  $(document).on('click.discounts', '#generateCouponCode', function () {
    var chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    var code  = '';
    for (var i = 0; i < 8; i++) {
      code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    $('#newCouponCode').val(code);
  });

  // 啟用 / 停用優惠券（status: active | disabled）
  $(document).on('click.discounts', '.btn-toggle-coupon', function () {
    var $btn     = $(this);
    var $row     = $btn.closest('tr');
    var code     = $row.data('coupon-code');
    var isActive = $row.data('coupon-status') === 'active';
    var newStatus = isActive ? 'disabled' : 'active';

    if (isActive) {
      $row.data('coupon-status', 'disabled');
      $row.find('.status-badge').text('已停用').removeClass('bg-success').addClass('bg-secondary');
      $btn.text('啟用').removeClass('btn-outline-warning').addClass('btn-outline-success');
      window.showAdminToast('優惠券 ' + code + ' 已停用');
    } else {
      $row.data('coupon-status', 'active');
      $row.find('.status-badge').text('啟用中').removeClass('bg-secondary').addClass('bg-success');
      $btn.text('停用').removeClass('btn-outline-success').addClass('btn-outline-warning');
      window.showAdminToast('優惠券 ' + code + ' 已啟用');
    }

    var cached = window.couponsCache.find(function (c) { return c.code === code; });
    if (cached) {
      cached.status = newStatus;
    }

    if (typeof AdminAPI !== 'undefined' && AdminAPI.coupons) {
      AdminAPI.coupons.updateStatus(code, newStatus).catch(function (err) {
        AdminAPI.handleError(err, '同步優惠券狀態失敗');
      });
    }
  });

  // 刪除優惠券
  $(document).on('click.discounts', '.btn-delete-coupon', function () {
    var $row = $(this).closest('tr');
    var code = $row.data('coupon-code');
    if (!window.confirm('確定要刪除優惠券「' + code + '」嗎？')) return;
    removeCouponFromCache(code);
    $row.fadeOut(300, function () { $(this).remove(); });
    window.showAdminToast('優惠券 ' + code + ' 已刪除', 'danger');

    if (typeof AdminAPI !== 'undefined' && AdminAPI.coupons) {
      AdminAPI.coupons.remove(code).catch(function (err) {
        AdminAPI.handleError(err, '刪除優惠券同步失敗');
      });
    }
  });

  // 新增優惠券（inline form，無 Modal）
  $(document).on('click.discounts', '#submitAddCoupon', function () {
    var code        = $('#newCouponCode').val().trim().toUpperCase();
    var discountRaw = parseFloat($('#newCouponDiscount').val()) || 0;
    var quantity    = parseInt($('#newCouponQty').val(), 10) || 50;
    // 最低消費：對應假資料 minOrder / DB min_order；空值或非法 → 0（無門檻）
    var minOrder    = parseInt($('#newCouponMinOrder').val(), 10);
    if (isNaN(minOrder) || minOrder < 0) {
      minOrder = 0;
    }
    var startVal  = $('#newCouponStart').val(); // "YYYY-MM-DDTHH:MM" 或空字串
    var endVal    = $('#newCouponEnd').val();
    var isPercent = $('#discountTypeSwitch').is(':checked'); // true → type: percent

    // --- 驗證 ---
    if (!code) {
      window.showAdminToast('請填寫優惠碼', 'danger');
      return;
    }
    if (isPercent) {
      // percent：1 ~ 99 的整數百分比
      if (discountRaw < 1 || discountRaw > 99 || discountRaw !== Math.floor(discountRaw)) {
        window.showAdminToast('百分比須為 1～99 的整數', 'danger');
        return;
      }
    } else {
      if (discountRaw <= 0) {
        window.showAdminToast('請填寫有效的折扣金額', 'danger');
        return;
      }
      // fixed：最低消費不宜低於折扣金額
      if (minOrder > 0 && minOrder < Math.floor(discountRaw)) {
        window.showAdminToast('最低消費不宜低於折扣金額', 'danger');
        return;
      }
    }

    // 對齊 schema / JSON：只用 type（fixed | percent），不寫舊欄位 discountType
    var couponType = isPercent ? 'percent' : 'fixed';
    var discountValue = isPercent ? discountRaw : Math.floor(discountRaw);

    var discountInfo = formatDiscountDisplay({ type: couponType, discount: discountValue });
    var discountCellClass = discountInfo.isAmount ? ' class="admin-cell-amount"' : '';

    // --- 組合新表格列 ---
    var newRow =
      '<tr data-coupon-code="' + code + '" data-coupon-status="active">' +
      '<td><code class="fw-bold">' + code + '</code></td>' +
      '<td' + discountCellClass + '>' + discountInfo.html + '</td>' +
      '<td class="admin-cell-amount">' + formatMinOrderDisplay(minOrder) + '</td>' +
      '<td class="text-center">' + quantity + '</td>' +
      '<td class="text-center">0</td>' +
      '<td class="text-center">' + quantity + '</td>' +
      '<td>' + formatDateDisplay(startVal) + '</td>' +
      '<td>' + formatDateDisplay(endVal)   + '</td>' +
      '<td><span class="badge bg-success status-badge">啟用中</span></td>' +
      '<td>' +
      '<button class="btn btn-sm btn-outline-warning btn-toggle-coupon me-1">停用</button>' +
      '<button class="btn btn-sm btn-outline-danger btn-delete-coupon">刪除</button>' +
      '</td></tr>';

    $('#couponsTableBody').prepend($(newRow).hide().fadeIn(400));

    // 寫入快取／API：欄位與 coupons.json 一致（camelCase）
    var newCoupon = {
      code: code,
      discount: discountValue,
      type: couponType,
      minOrder: minOrder,
      quantity: quantity,
      used: 0,
      startDate: startVal || '',
      endDate: endVal || '',
      status: 'active',
      category: 'promotion'
    };
    upsertCouponInCache(newCoupon);

    if (typeof AdminAPI !== 'undefined' && AdminAPI.coupons) {
      AdminAPI.coupons.create(newCoupon).catch(function (err) {
        AdminAPI.handleError(err, '新增優惠券同步失敗');
      });
    }

    // --- 重設表單欄位 ---
    $('#newCouponCode').val('');
    $('#newCouponDiscount').val('');
    $('#newCouponQty').val('50');
    $('#newCouponMinOrder').val('0');
    $('#newCouponStart').val('');
    $('#newCouponEnd').val('');
    // Switch 重設回 fixed（固定金額）
    $('#discountTypeSwitch').prop('checked', false).trigger('change');

    window.showAdminToast('優惠券「' + code + '」已新增');
  });
};

/**
 * 將 coupons 陣列渲染成 HTML 表格列，填入 #couponsTableBody
 * 讀取欄位與 coupons.json 一致：type / minOrder / startDate / endDate …
 *
 * @param {Array} coupons - coupons.json 的資料陣列
 */
function renderCouponsTable(coupons) {
  if (!coupons || coupons.length === 0) {
    $('#couponsTableBody').html(
      '<tr><td colspan="10" class="text-center text-muted py-4">目前沒有優惠券</td></tr>'
    );
    return;
  }

  var html = coupons.map(function (coupon) {
    var isActive  = coupon.status === 'active';
    var remaining = coupon.quantity - coupon.used;

    var remainDisplay = remaining <= 5
      ? '<span class="text-danger fw-bold">' + remaining + '</span>'
      : remaining;

    var statusBadge = isActive
      ? '<span class="badge bg-success status-badge">啟用中</span>'
      : '<span class="badge bg-secondary status-badge">已停用</span>';

    var toggleBtn = isActive
      ? '<button class="btn btn-sm btn-outline-warning btn-toggle-coupon me-1">停用</button>'
      : '<button class="btn btn-sm btn-outline-success btn-toggle-coupon me-1">啟用</button>';

    var discountInfo = formatDiscountDisplay(coupon);
    var discountCellClass = discountInfo.isAmount ? ' class="admin-cell-amount"' : '';
    // minOrder 缺欄時當 0（與 schema 預設、文件說明一致）
    var minOrderCell = formatMinOrderDisplay(coupon.minOrder);

    return '<tr data-coupon-code="' + coupon.code + '" data-coupon-status="' + coupon.status + '">' +
      '<td><code class="fw-bold">' + coupon.code + '</code></td>' +
      '<td' + discountCellClass + '>' + discountInfo.html + '</td>' +
      '<td class="admin-cell-amount">' + minOrderCell + '</td>' +
      '<td class="text-center">' + coupon.quantity + '</td>' +
      '<td class="text-center">' + coupon.used + '</td>' +
      '<td class="text-center">' + remainDisplay + '</td>' +
      '<td>' + formatDateDisplay(coupon.startDate) + '</td>' +
      '<td>' + formatDateDisplay(coupon.endDate)   + '</td>' +
      '<td>' + statusBadge + '</td>' +
      '<td>' + toggleBtn +
      '<button class="btn btn-sm btn-outline-danger btn-delete-coupon">刪除</button>' +
      '</td></tr>';
  }).join('');

  $('#couponsTableBody').html(html);

  if (typeof window.applyEditPermission === 'function') {
    window.applyEditPermission('discounts', $('#contentArea'));
  }
}
