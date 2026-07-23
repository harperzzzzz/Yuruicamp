// ========================================
// Coupon utilities — 讀 promotions/coupons + 資格驗證
// ========================================

(function () {
  const CHECKOUT_COUPON_STORAGE_KEY = 'checkoutCouponCode';

  let couponCache = null;

  function _escapeAttr(value) {
    return String(value || '')
      .replace(/&/g, '&amp;')
      .replace(/"/g, '&quot;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');
  }

  function _formatMoney(amount) {
    return Number(amount || 0).toLocaleString('zh-TW');
  }

  /** 讀取 promotions/coupons.json（含活動碼） */
  async function loadCoupons() {
    if (couponCache) return couponCache;
    if (window.API?.coupons?.getAll) {
      couponCache = await window.API.coupons.getAll();
      return couponCache;
    }
    const path =
      (window.MockDataPaths && window.MockDataPaths.coupons) ||
      '/data/promotions/coupons.json';
    const response = await fetch(path);
    couponCache = await response.json();
    return couponCache;
  }

  /** 會員可用券（生日/首購/活動） */
  async function loadAvailableCoupons(customerId) {
    if (window.API?.coupons?.getAvailable && customerId) {
      return window.API.coupons.getAvailable(customerId);
    }
    return loadCoupons();
  }

  function describeCoupon(coupon) {
    const type = coupon.discountType || coupon.type || 'fixed';
    const discount = Number(coupon.discountValue ?? coupon.discount ?? 0);
    const minimumAmount = Number(coupon.minimumAmount ?? coupon.minOrder ?? 0);
    const discountText = type === 'percent'
      ? `${discount}% OFF`
      : `折 NT$ ${_formatMoney(discount)}`;
    const minOrderText = minimumAmount ? ` / 滿 NT$ ${_formatMoney(minimumAmount)}` : '';
    return `${coupon.code} - ${discountText}${minOrderText}`;
  }

  function renderCouponOptions(datalistId, coupons) {
    const datalist = document.getElementById(datalistId);
    if (!datalist) return;

    datalist.innerHTML = (coupons || []).map((coupon) => (
      `<option value="${_escapeAttr(coupon.code)}" label="${_escapeAttr(describeCoupon(coupon))}"></option>`
    )).join('');
  }

  function findCouponByCode(coupons, rawCode) {
    const code = String(rawCode || '').trim().toUpperCase();
    return (coupons || []).find((coupon) => String(coupon.code || '').toUpperCase() === code) || null;
  }

  function calculateDiscount(coupon, subtotal) {
    if (!coupon) return 0;
    const type = coupon.discountType || coupon.type || 'fixed';
    const discountValue = Number(coupon.discountValue ?? coupon.discount ?? 0);
    const discount = type === 'percent'
      ? Math.round(Number(subtotal || 0) * discountValue / 100)
      : discountValue;
    return Math.min(discount, Number(subtotal || 0));
  }

  function normalizeCouponCodes(codes) {
    const list = Array.isArray(codes) ? codes : [codes];
    return [...new Set(list
      .map((code) => String(code || '').trim().toUpperCase())
      .filter(Boolean))];
  }

  function calculateAppliedCoupons(coupons, codes, subtotal) {
    let remainingSubtotal = Number(subtotal || 0);
    const items = normalizeCouponCodes(codes)
      .map((code) => findCouponByCode(coupons, code))
      .filter(Boolean)
      .map((coupon) => {
        const discount = Math.min(calculateDiscount(coupon, subtotal), remainingSubtotal);
        remainingSubtotal = Math.max(remainingSubtotal - discount, 0);
        return { code: coupon.code, label: describeCoupon(coupon), discount, coupon };
      });

    return { items, totalDiscount: items.reduce((sum, item) => sum + item.discount, 0) };
  }

  /** 驗證折扣碼（含 YURUIHBD / YRUIFIRST 資格） */
  async function validateCoupon(coupons, rawCode, subtotal, customerId) {
    const code = String(rawCode || '').trim().toUpperCase();
    if (!code) return { valid: false, message: '請輸入折扣碼' };

    const coupon = findCouponByCode(coupons, code);
    if (!coupon) return { valid: false, message: '折扣碼無效，請確認後再試' };

    if (coupon.status && coupon.status !== 'active') {
      return { valid: false, message: '此折扣碼目前無法使用' };
    }

    if (customerId && window.API?.customers?.getById) {
      try {
        const customer = await window.API.customers.getById(customerId);
        const now = new Date();
        if (coupon.category === 'birthday') {
          const bMonth = parseInt(String(customer.birthday).slice(5, 7), 10);
          if (bMonth !== now.getMonth() + 1) {
            return { valid: false, message: '生日折扣碼僅限生日當月使用' };
          }
        }
        if (coupon.category === 'firstPurchase' && customer.firstPurchaseUsed) {
          return { valid: false, message: '首購優惠已使用過' };
        }
      } catch (error) {
        console.warn('Coupon eligibility check failed', error);
      }
    }

    const minimumAmount = Number(coupon.minimumAmount ?? coupon.minOrder ?? 0);
    if (minimumAmount && Number(subtotal) < minimumAmount) {
      return { valid: false, message: `需滿 NT$ ${_formatMoney(minimumAmount)} 才可使用` };
    }

    return {
      valid: true,
      code: coupon.code,
      coupon,
      discount: calculateDiscount(coupon, subtotal),
      label: describeCoupon(coupon),
      message: `折扣碼「${coupon.code}」已套用`,
    };
  }

  function saveAppliedCouponCodes(codes) {
    localStorage.setItem(CHECKOUT_COUPON_STORAGE_KEY, JSON.stringify(normalizeCouponCodes(codes)));
  }

  function saveAppliedCouponCode(code) {
    saveAppliedCouponCodes([code]);
  }

  function getAppliedCouponCode() {
    return getAppliedCouponCodes()[0] || '';
  }

  function getAppliedCouponCodes() {
    const raw = localStorage.getItem(CHECKOUT_COUPON_STORAGE_KEY) || '';
    if (!raw) return [];
    try {
      return normalizeCouponCodes(JSON.parse(raw));
    } catch {
      return normalizeCouponCodes(raw);
    }
  }

  function clearAppliedCouponCode() {
    localStorage.removeItem(CHECKOUT_COUPON_STORAGE_KEY);
  }

  function renderAppliedCouponTexts(containerId, appliedItems) {
    const container = document.getElementById(containerId);
    if (!container) return;

    if (!appliedItems || appliedItems.length === 0) {
      container.style.display = 'none';
      container.innerHTML = '';
      return;
    }

    container.style.display = 'block';
    container.innerHTML = appliedItems.map((item) => (
      `<div>已套用：${_escapeAttr(item.code)}（折抵 NT$ ${_formatMoney(item.discount)}）</div>`
    )).join('');
  }

  window.YuruiCoupons = {
    loadCoupons,
    loadAvailableCoupons,
    renderCouponOptions,
    findCouponByCode,
    calculateDiscount,
    calculateAppliedCoupons,
    validateCoupon,
    normalizeCouponCodes,
    saveAppliedCouponCode,
    saveAppliedCouponCodes,
    getAppliedCouponCode,
    getAppliedCouponCodes,
    clearAppliedCouponCode,
    renderAppliedCouponTexts,
  };
})();
