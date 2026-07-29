/**
 * camp-search.js
 * 功能：搜尋頁邏輯
 * ① 讀取 campgrounds.json（jQuery AJAX）
 * ② 動態渲染營區卡片
 * ③ Checkbox + 下拉選單即時篩選（AND 邏輯）
 *
 * Handles: data loading, card rendering, real-time filtering
 */

// ============================================================
// 全域狀態 / Global State
// ============================================================

/** 原始營區資料快取，保留一份完整陣列供篩選時使用 */
let allCampgrounds = [];

/** 由 initPriceRangeSlider 填入，供重設按鈕呼叫 */
let updatePriceSlider = function () {};

/** 可預約窗口與可用性上下文 / Booking window and availability context */
let searchBookingWindow = { minDate: null, maxDate: null };
let searchAvailabilityCtx = null;
let searchDateRange = { checkIn: null, checkOut: null };
let backendCampAvailability = new Map();
let availabilityRefreshId = 0;

// ============================================================
// 頁面初始化 / Page Initialization
// ============================================================
$(document).ready(function () {
  // 步驟 1：載入營區資料 / Step 1: Load campground data
  loadCampgrounds();

  // 步驟 2：綁定篩選器事件 / Step 2: Bind filter events
  bindFilterEvents();

  // Flatpickr 在 loadCampgrounds 取得 bookingWindow 後初始化

  // 步驟 4：行動版篩選器展開/收合 / Step 4: Mobile filter toggle
  $('#filterToggle').on('click', function () {
    const $body = $('#filterBody');
    const isOpen = $body.hasClass('isOpen');
    $body.toggleClass('isOpen', !isOpen);
    $(this).attr('aria-expanded', !isOpen);
  });
});

// ============================================================
// 步驟 1：載入資料
// ============================================================

/**
 * 從 JSON 檔案載入所有營區資料
 * Load all campground data from JSON file
 */
function loadCampgrounds() {
  // 透過 BookingAPI 讀取營區 catalog（MockDataPaths 在 api-mock.js）
  // Load campground catalog via BookingAPI (paths from api-mock MockDataPaths)
  if (!window.BookingAPI) {
    console.error('[camp-search] BookingAPI 未載入 / BookingAPI not loaded');
    return;
  }

  window.BookingAPI.getCampgrounds()
    .then(function (data) {
      allCampgrounds = data;
      return Promise.all([window.BookingAPI.getBookingWindow(), window.BookingAPI.loadAvailabilityContext()]);
    })
    .then(function (results) {
      searchBookingWindow = results[0] || searchBookingWindow;
      searchAvailabilityCtx = results[1];
      initFlatpickrDateRange();
      renderCampCards(allCampgrounds);
    })
    .catch(function (err) {
      console.error('[camp-search] 資料載入失敗 / Failed:', err);
      $('#loadingSkeleton').hide();
      $('#campCardGrid').html(`
      <div class="errorMsg">
        <i class="bi bi-exclamation-triangle"></i>
        資料載入失敗，請重新整理頁面。
      </div>
    `);
    });
}

// ============================================================
// 步驟 2：渲染卡片
// ============================================================

/**
 * 將營區資料陣列渲染成 HTML 卡片並插入 DOM
 * Render campground data array as HTML cards
 *
 * @param {Array} camps - 要顯示的營區資料陣列
 */
function renderCampCards(camps) {
  const $grid = $('#campCardGrid');

  // 隱藏 loading 骨架屏 / Hide loading skeleton
  $('#loadingSkeleton').hide();
  $grid.empty();

  // 沒有結果時顯示提示 / Show empty state if no results
  if (camps.length === 0) {
    $grid.html(`
      <div class="noResult">
        <i class="bi bi-search"></i>
        沒有符合條件的營區，請嘗試調整篩選條件。
      </div>
    `);
    $('#resultCount').text('共 0 個營區');
    return;
  }

  // 渲染每一個營區卡片 / Render each camp card
  camps.forEach(function (camp) {
    // 計算最低平日價（所有 zone 中取最小值）/ Min weekday price across all zones
    const minWeekdayPrice = Math.min(...camp.zones.map((z) => z.priceWeekday));
    // 計算最高假日價（所有 zone 中取最大值）/ Max holiday price
    const maxHolidayPrice = Math.max(...camp.zones.map((z) => z.priceHoliday));

    // 環境標籤 HTML / Environment tags HTML
    const envTagsHTML = camp.environmentTags
      .map((t) => `<span class="bookingTag bookingTagEnv">${t}</span>`)
      .join('');

    // 設施標籤 HTML（最多顯示 3 個）/ Facility tags HTML (max 3)
    const facTagsHTML = camp.facilityTags
      .slice(0, 3)
      .map((t) => `<span class="bookingTag bookingTagFacility">${t}</span>`)
      .join('');

    // 建立營區卡片 HTML：輸出 campCard 共通語意與 campCardBooking 預約流程變體。
    const statusBadge = (function () {
      if (!searchDateRange.checkIn || !searchDateRange.checkOut) return '';
      const status = getCampRangeStatus(camp);
      if (status.closed) {
        return '<span class="campCardBadge campCardBadgeBooking campCardBadgeClosed">公休</span>';
      }
      if (!status.available) {
        return '<span class="campCardBadge campCardBadgeBooking campCardBadgeFull">該日期已滿</span>';
      }
      return '';
    })();

    // Camp images: use data.images if present, else 3 picsum placeholders / 有資料用資料，否則用 3 張佔位圖
    const campImages =
      Array.isArray(camp.images) && camp.images.length > 0
        ? camp.images
        : [0, 1, 2].map((i) => `https://picsum.photos/seed/${camp.campgroundId}_${i}/400/250`);

    const badgeHtml = `
      <span class="campCardBadge campCardBadgeBooking">${camp.region}</span>
      ${statusBadge}
    `;

    const imageHtml = window.buildCardGalleryHtml
      ? window.buildCardGalleryHtml({
          images: campImages,
          alt: camp.name,
          galleryId: `camp-${camp.campgroundId}`,
          wrapClass: 'campCardImage campCardImageBooking',
          badgeHtml,
        })
      : `<div class="campCardImage campCardImageBooking">
          <img src="${campImages[0]}" alt="${camp.name}" loading="lazy">
          ${badgeHtml}
        </div>`;

    const cardHTML = `
      <div class="campCard campCardBooking${camp._dateClosed ? ' isDateClosed' : ''}${camp._dateFull ? ' isDateFull' : ''}"
           data-id="${camp.campgroundId}"
           data-region="${camp.region}"
           data-env="${camp.environmentTags.join(',')}"
           data-facility="${camp.facilityTags.join(',')}">

        ${imageHtml}

        <div class="campCardBody campCardBodyBooking">
          <h3 class="campCardName campCardNameBooking">${camp.name}</h3>
          <p class="campCardPrice campCardPriceBooking">
            平日 <strong>NT$${minWeekdayPrice.toLocaleString()}</strong>
            ／ 假日 <strong>NT$${maxHolidayPrice.toLocaleString()}</strong> 起
          </p>
          <div class="campCardTags campCardTagsBooking">${envTagsHTML}${facTagsHTML}</div>
        </div>

        <div class="campCardFooter campCardFooterBooking">
          <a href="${buildCampDetailHref(camp.campgroundId)}" class="btn btnPrimary"
             data-camp-detail-link data-camp-id="${camp.campgroundId}">
            查看詳情 <i class="bi bi-arrow-right"></i>
          </a>
        </div>

      </div>
    `;

    $grid.append(cardHTML);
  });

  // Init Swiper + GLightbox after all cards are in the DOM / 全部卡片插入後再初始化
  window.initCardGalleries?.($grid[0] || document);

  // 更新結果數量 / Update result count
  $('#resultCount').text(`共 ${camps.length} 個營區`);
}

// ============================================================
// 步驟 3：篩選邏輯
// ============================================================

/**
 * 綁定所有篩選器的 change 事件
 * Bind change events for all filter controls
 */
function bindFilterEvents() {
  // 點擊詳情時再讀取搜尋列最新值，避免人數變更後沿用舊連結。
  $(document).on('click', '[data-camp-detail-link]', function () {
    this.href = buildCampDetailHref($(this).data('camp-id'));
  });

  // Checkbox 變更時觸發篩選 / Trigger filter on checkbox change
  $(document).on('change', 'input[name="env"], input[name="facility"]', filterCampgrounds);

  // 地區下拉選單變更時觸發 / Trigger on region dropdown change
  $('#regionFilter').on('change', filterCampgrounds);

  // 雙滑塊價格篩選器 / Dual-thumb price slider
  initPriceRangeSlider();

  // 重設按鈕 / Reset button
  $('#resetFilterBtn').on('click', function () {
    $('input[name="env"]').prop('checked', false);
    $('input[name="facility"]').prop('checked', false);
    $('#regionFilter').val('');
    $('#priceMin').val(500);
    $('#priceMax').val(5000);

    // 如果有選取日期，也可以一併清空
    const datePicker = document.querySelector('#dateRange')._flatpickr;
    if (datePicker) datePicker.clear();
    searchDateRange = { checkIn: null, checkOut: null };
    backendCampAvailability.clear();

    updatePriceSlider();
    filterCampgrounds();
  });
}

/**
 * 建立營區詳情頁連結；只有使用者已填寫的搜尋條件才會被帶入。
 *
 * @param {string} campgroundId - 營區 ID
 * @returns {string} 詳情頁 URL
 */
function buildCampDetailHref(campgroundId) {
  const params = new URLSearchParams({ id: campgroundId });

  if (searchDateRange.checkIn && searchDateRange.checkOut) {
    params.set('checkIn', searchDateRange.checkIn);
    params.set('checkOut', searchDateRange.checkOut);
  }

  const guestCount = Number.parseInt($('#guestCount').val(), 10);
  if (Number.isInteger(guestCount) && guestCount > 0) {
    params.set('guests', String(guestCount));
  }

  return `./camp-detail.html?${params.toString()}`;
}

/**
 * 初始化 Flatpickr 日期區間選擇器
 * Initialize Flatpickr range datepicker
 */
function initFlatpickrDateRange() {
  const el = document.querySelector('#dateRange');
  if (!el) return;
  if (el._flatpickr) {
    el._flatpickr.destroy();
  }

  flatpickr('#dateRange', {
    mode: 'range',
    minDate: searchBookingWindow.minDate || 'today',
    maxDate: searchBookingWindow.maxDate || undefined,
    locale: 'zh_tw',
    dateFormat: 'Y-m-d',
    onChange: function (selectedDates) {
      if (selectedDates.length === 2) {
        const AV = window.BookingAvailability;
        searchDateRange = {
          checkIn: AV ? AV.formatISODate(selectedDates[0]) : null,
          checkOut: AV ? AV.formatISODate(selectedDates[1]) : null,
        };
      } else if (selectedDates.length === 0) {
        searchDateRange = { checkIn: null, checkOut: null };
      }
      refreshBackendAvailability();
    },
  });
}

// Backend 模式逐營區呼叫正式可用性 API，避免下載所有 Booking 在前端計算。
function refreshBackendAvailability() {
  const refreshId = ++availabilityRefreshId;
  if (searchAvailabilityCtx || !searchDateRange.checkIn || !searchDateRange.checkOut) {
    filterCampgrounds();
    return;
  }

  Promise.all(
    allCampgrounds.map(function (campground) {
      return window.BookingAPI.getAvailability({
        campgroundId: campground.campgroundId,
        checkIn: searchDateRange.checkIn,
        checkOut: searchDateRange.checkOut,
        zones: (campground.zones || []).map(function (zone) {
          return { zoneId: zone.zoneId, quantity: 1 };
        }),
      })
        .then(function (result) {
          return [campground.campgroundId, result];
        })
        .catch(function (error) {
          console.error('[camp-search] 營區可用性查詢失敗:', error);
          return [campground.campgroundId, null];
        });
    })
  ).then(function (entries) {
    if (refreshId !== availabilityRefreshId) return;

    backendCampAvailability = new Map(entries);
    filterCampgrounds();
  });
}

/**
 * 檢查營區在所選日期區間的狀態（可訂 / 公休 / 已滿）
 * Check campground availability status for selected date range
 */
function getCampRangeStatus(camp) {
  const AV = window.BookingAvailability;
  if (!searchDateRange.checkIn || !searchDateRange.checkOut) return { available: true };

  if (!searchAvailabilityCtx) {
    const result = backendCampAvailability.get(camp.campgroundId);
    if (!result) return { available: true };

    const closed = (result.reasons || []).includes('CAMPGROUND_CLOSED');
    return {
      available: result.available,
      closed: closed,
      reason: closed ? '公休' : '',
    };
  }

  if (!AV) return { available: true };

  if (
    AV.hasClosedNightInRange(
      camp.campgroundId,
      searchDateRange.checkIn,
      searchDateRange.checkOut,
      searchAvailabilityCtx
    )
  ) {
    const reason = AV.getClosureReason(
      camp.campgroundId,
      searchDateRange.checkIn,
      searchAvailabilityCtx.closures
    );
    return { available: false, closed: true, reason: reason || '公休' };
  }

  const hasSlot = (camp.zones || []).some(function (zone) {
    return (
      AV.getMinRemainingInRange(
        zone.zoneId,
        searchDateRange.checkIn,
        searchDateRange.checkOut,
        searchAvailabilityCtx
      ) > 0
    );
  });

  return { available: hasSlot, closed: false };
}

/**
 * 核心篩選函式：讀取所有勾選條件，過濾 allCampgrounds
 * Core filter function: read all checked conditions, filter allCampgrounds
 *
 * 篩選規則（AND 邏輯）：
 * - 勾選的「環境標籤」：每一項都必須存在於 camp.environment_tags
 * - 勾選的「設施標籤」：每一項都必須存在於 camp.facility_tags
 * - 選擇的「地區」：必須完全匹配 camp.region
 *
 * Filter rule (AND logic):
 * All selected env tags + facility tags + region must ALL match.
 */
function filterCampgrounds() {
  // 取得所有勾選的環境標籤 / Get all checked environment tags
  const checkedEnv = $('input[name="env"]:checked')
    .map(function () {
      return $(this).val();
    })
    .get();

  // 取得所有勾選的設施標籤 / Get all checked facility tags
  const checkedFacility = $('input[name="facility"]:checked')
    .map(function () {
      return $(this).val();
    })
    .get();

  // 取得選擇的地區 / Get selected region
  const selectedRegion = $('#regionFilter').val();

  // 過濾陣列 / Filter array
  const filtered = allCampgrounds
    .filter(function (camp) {
      // 地區篩選：有選才過濾，未選則略過 / Region: filter only if selected
      if (selectedRegion && camp.region !== selectedRegion) return false;

      // 環境標籤：每個勾選的標籤都必須存在於 camp.environment_tags
      // Every checked env tag must be in camp.environment_tags
      const envMatch = checkedEnv.every((tag) => camp.environmentTags.includes(tag));
      if (!envMatch) return false;

      // 設施標籤：每個勾選的標籤都必須存在於 camp.facilityTags
      // Every checked facility tag must be in camp.facilityTags
      const facilityMatch = checkedFacility.every((tag) => camp.facilityTags.includes(tag));
      if (!facilityMatch) return false;

      // 價格篩選：各 zone 最低平日價須落在 [minBudget, maxBudget] 區間內
      const minBudget = parseInt($('#priceMin').val());
      const maxBudget = parseInt($('#priceMax').val());
      if (minBudget > 500 || maxBudget < 5000) {
        const minWeekdayPrice = Math.min(...camp.zones.map((z) => z.priceWeekday));
        if (minWeekdayPrice < minBudget || minWeekdayPrice > maxBudget) return false;
      }

      return true;
    })
    .map(function (camp) {
      const status = getCampRangeStatus(camp);
      return Object.assign({}, camp, {
        _dateFull: !status.available && !status.closed,
        _dateClosed: Boolean(status.closed),
        _closureReason: status.reason || '',
      });
    })
    .sort(function (a, b) {
      if (a._dateClosed !== b._dateClosed) return a._dateClosed ? 1 : -1;
      if (a._dateFull !== b._dateFull) return a._dateFull ? 1 : -1;
      return 0;
    });

  renderCampCards(filtered);
}

// ============================================================
// 雙滑塊價格篩選器初始化
// ============================================================

/**
 * 建立 dual-thumb range slider：
 * - #priceMin / #priceMax 兩個 <input type="range"> 疊加
 * - #priceRangeFill 依百分比定位，顯示選取區段
 * - #priceRangeDisplay 即時更新文字
 */
function initPriceRangeSlider() {
  const $minEl = $('#priceMin');
  const $maxEl = $('#priceMax');
  const $label = $('#priceRangeDisplay');
  const TOTAL_MIN = 500;
  const TOTAL_MAX = 5000;

  function update() {
    const minVal = parseInt($minEl.val());
    const maxVal = parseInt($maxEl.val());

    // min thumb 靠近右側時提高層級，避免被 max thumb 擋住。
    $minEl.toggleClass('isRaised', minVal >= TOTAL_MAX - 500);

    // 文字顯示
    const maxLabel = maxVal >= TOTAL_MAX ? 'NT$5,000+' : 'NT$' + maxVal.toLocaleString();
    $label.text('NT$' + minVal.toLocaleString() + ' - ' + maxLabel);
  }

  // 暴露給重設按鈕使用
  updatePriceSlider = update;

  $minEl.on('input', function () {
    if (parseInt($minEl.val()) >= parseInt($maxEl.val())) {
      $minEl.val(parseInt($maxEl.val()) - TOTAL_MIN); // 至少保留一格距離
    }
    update();
    filterCampgrounds();
  });

  $maxEl.on('input', function () {
    if (parseInt($maxEl.val()) <= parseInt($minEl.val())) {
      $maxEl.val(parseInt($minEl.val()) + TOTAL_MIN);
    }
    update();
    filterCampgrounds();
  });

  update(); // 初始渲染
}
