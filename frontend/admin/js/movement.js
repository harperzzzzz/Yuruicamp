/**
 * admin/js/movement.js
 * 庫存異動紀錄模組
 * 後端讀取 P5 inventory_movement_items_view 組成的 DTO；JSON 僅為唯讀 fallback。
 *
 * 功能：
 *   - 期間篩選：近 7/30 天、本月、近 3 個月、自定義（flatpickr）
 *   - 欄位排序（可疊加）：異動日期
 *   - 多選篩選（可疊加）：負責員工 ID、異動性質
 *
 * 使用 jQuery Event Namespace (.movement) 防止重複導覽時事件堆疊
 */

window.generatedMovementRecords = window.generatedMovementRecords || [];
window.movementBaseLoaded = false;
window.movementLoadedMode = window.movementLoadedMode || null;

// Backend 模式的庫位與規格選項，送出時只使用正式 ID。
var adminMovementLookups = { locations: [], variants: [] };

var MOVEMENT_TYPE_LABELS = {
  receipt: '進貨',
  write_off: '損耗',
  transfer: '調撥'
};

var MOVEMENT_STATUS_LABELS = {
  draft: '草稿',
  posted: '已過帳',
  cancelled: '已作廢'
};

/** 判斷庫存異動頁是否使用正式後端。 */
function isAdminMovementBackendEnabled() {
  return typeof AdminAPI !== 'undefined' &&
    AdminAPI.isBackendEnabled &&
    AdminAPI.isBackendEnabled();
}

/** Backend 模式才顯示正式庫存寫入控制。 */
function syncBackendMovementUi() {
  $('.backend-movement-action').toggleClass('d-none', !isAdminMovementBackendEnabled());
}

/**
 * 排序堆疊：依點擊時間順序排列
 * 初始值設為日期降冪（最新異動在最上面）
 */
var movementSortStack = [{ key: 'createdAt', dir: 'desc' }];

/**
 * 日期篩選 UI 狀態（對齊 orders.js orderDateState）
 */
var movementDateState = { days: 30, startDate: null, endDate: null };

/**
 * 篩選條件：各欄位目前勾選的值
 * 空陣列 = 不篩選（顯示全部）
 * dateStart / dateEnd 為 YYYY-MM-DD 字串，null = 不限制
 */
var movementFilterState = {
  employeeId:   [],   // e.g. ['01', '02']
  movementType: [],   // e.g. ['進貨', '損耗']
  dateStart:    null,
  dateEnd:      null
};

/** 取得異動時間（支援舊欄位 date）/ Get movement timestamp string */
function getMovementCreatedAt(record) {
  // 優先 camelCase；相容舊 created_at / date
  return (record && (record.createdAt || record.created_at || record.date)) || '';
}

window.initMovement = function () {
  // 清除 orders / movement 舊事件（共用 .sortable-th / .filter-icon 選擇器）
  $(document).off('.orders');
  $(document).off('.movement');

  // 每次進入頁面重置排序與篩選（預設：日期降冪 + 近 30 天）
  movementSortStack = [{ key: 'createdAt', dir: 'desc' }];
  movementFilterState = { employeeId: [], movementType: [], dateStart: null, dateEnd: null };
  movementDateState = { days: 30, startDate: null, endDate: null };

  var currentMode = isAdminMovementBackendEnabled() ? 'backend' : 'mock';
  if (window.movementLoadedMode && window.movementLoadedMode !== currentMode) {
    window.movementBaseLoaded = false;
    window.movementCache = [];
  }
  syncBackendMovementUi();
  if (currentMode === 'backend') {
    loadBackendMovementLookups();
  }

  setupMovementPeriodFilter();
  initMovementFlatpickr();
  applyMovementDayRange(30);

  if (window.movementBaseLoaded) {
    populateEmployeeFilterOptions(window.movementCache || []);
    applyMovementFiltersAndSort();
  } else {
    loadAdminJsonResource({
      adminList: AdminAPI && AdminAPI.movement && AdminAPI.movement.list,
      jsonPath: MockDataPaths.movement,
      emptyValue: [],
      errorMessage: '載入庫存異動失敗',
      onSuccess: function (records) {
        window.movementCache = mergeMovementRecords(
          window.generatedMovementRecords,
          (records || []).map(function (record) {
            return normalizeMovementRecord(adaptLegacyMovementRecord(record && (record.payload || record)));
          })
        );
        window.movementBaseLoaded = true;
        window.movementLoadedMode = currentMode;
        populateEmployeeFilterOptions(window.movementCache);
        applyMovementFiltersAndSort();
      },
      onError: function () {
        $('#movementTableBody').html(
          '<tr><td colspan="5" class="text-center text-danger py-4">' +
          '<i class="fas fa-exclamation-triangle me-2"></i>載入庫存異動紀錄失敗' +
          '</td></tr>'
        );
      }
    });
  }

  // ── 排序：點擊 .sortable-th 標頭（三段式：無 → asc → desc → 移除） ──
  $(document).on('click.movement', '#movementTable .sortable-th', function () {
    var key = $(this).data('sort-key');
    var idx = movementSortStack.findIndex(function (s) { return s.key === key; });

    if (idx === -1) {
      movementSortStack.push({ key: key, dir: 'asc' });
    } else if (movementSortStack[idx].dir === 'asc') {
      movementSortStack[idx].dir = 'desc';
    } else {
      movementSortStack.splice(idx, 1);
    }

    applyMovementFiltersAndSort();
  });

  // ── 篩選 Dropdown 開關：點擊漏斗 icon ──
  $(document).on('click.movement', '#movementTable .filter-icon', function (e) {
    e.stopPropagation();
    var $th = $(this).closest('.filter-th');
    var $dropdown = $th.find('.filter-dropdown');

    $('#movementTable .filter-dropdown').not($dropdown).addClass('d-none');
    $dropdown.toggleClass('d-none');
  });

  // 點擊 Dropdown 內部時阻止冒泡關閉
  $(document).on('click.movement', '#movementTable .filter-dropdown', function (e) {
    e.stopPropagation();
  });

  // 點擊頁面其他地方 → 關閉所有 Dropdown
  $(document).on('click.movement', function () {
    $('#movementTable .filter-dropdown').addClass('d-none');
  });

  // ── 篩選 checkbox 勾選/取消 ──
  $(document).on('change.movement', '#movementTable .filter-dropdown input[type="checkbox"]', function () {
    var $th = $(this).closest('.filter-th');
    var key = $th.data('filter-key');

    var selected = [];
    $th.find('input[type="checkbox"]:checked').each(function () {
      selected.push($(this).val());
    });

    movementFilterState[key] = selected;
    applyMovementFiltersAndSort();
  });

  // ── 清除條件按鈕：還原預設排序 + 清空欄位篩選 + 還原近 30 天 ──
  $(document).on('click.movement', '#btnClearMovementSort', function () {
    movementSortStack = [{ key: 'createdAt', dir: 'desc' }];
    movementFilterState.employeeId = [];
    movementFilterState.movementType = [];
    applyMovementDayRange(30);
  });

  // ── 點擊異動 ID → 開啟明細 Modal ──
  $(document).on('click.movement', '.movement-detail-link', function () {
    var movementId = $(this).data('movement-id');
    var record = (window.movementCache || []).find(function (item) {
      return window.sameId(item.id, movementId);
    });

    if (record) {
      showMovementDetailModal(record);
    }
  });

  // 開啟正式庫存異動草稿表單。
  $(document).on('click.movement', '#openMovementDraftModal', function () {
    resetMovementDraftForm();
    bootstrap.Modal.getOrCreateInstance(document.getElementById('movementDraftModal')).show();
  });

  $(document).on('change.movement', '#movementDomain, #movementType', function () {
    renderMovementLocationOptions();
    renderMovementDraftRows();
    syncMovementLocationFields();
  });

  $(document).on('click.movement', '#addMovementDraftRow', function () {
    appendMovementDraftRow();
  });

  $(document).on('click.movement', '.remove-movement-draft-row', function () {
    $(this).closest('.movement-draft-row').remove();
    if (!$('#movementDraftRows .movement-draft-row').length) {
      appendMovementDraftRow();
    }
  });

  $(document).on('submit.movement', '#movementDraftForm', function (event) {
    event.preventDefault();
    submitMovementDraftForm();
  });

  $(document).on('click.movement', '#addDraftMovementItem', function () {
    addItemToOpenMovementDraft();
  });

  $(document).on('click.movement', '#postMovementDraft', function () {
    changeOpenMovementStatus('post');
  });

  $(document).on('click.movement', '#cancelMovementDraft', function () {
    changeOpenMovementStatus('cancel');
  });
};

window.addMovementRecord = function (record) {
  if (isAdminMovementBackendEnabled()) {
    window.showAdminToast('正式庫存請到「庫存異動紀錄」建立草稿並過帳', 'info');
    return;
  }
  var normalizedRecord = normalizeMovementRecord(record);

  window.generatedMovementRecords = window.generatedMovementRecords || [];
  window.generatedMovementRecords.unshift(normalizedRecord);

  if (Array.isArray(window.movementCache)) {
    window.movementCache.unshift(normalizedRecord);
  }

  if (typeof AdminAPI !== 'undefined' && AdminAPI.movement) {
    AdminAPI.movement.create(normalizedRecord).catch(function (err) {
      AdminAPI.handleError(err, '同步庫存異動紀錄失敗');
    });
  }

  if ($('#movementTableBody').length > 0) {
    populateEmployeeFilterOptions(window.movementCache || window.generatedMovementRecords);
    applyMovementFiltersAndSort();
  }
};

function mergeMovementRecords(generatedRecords, baseRecords) {
  var merged = [];
  var idMap = {};

  (generatedRecords || []).concat(baseRecords || []).forEach(function (record) {
    var normalizedRecord = normalizeMovementRecord(record);

    if (!idMap[normalizedRecord.id]) {
      merged.push(normalizedRecord);
      idMap[normalizedRecord.id] = true;
    }
  });

  return merged;
}

/**
 * 產生下一筆庫存異動編號（純數字，顯示時用 formatMovementId）
 * Generate next movement record ID as numeric PK.
 */
function createMovementRecordId() {
  var existingRecords = [];

  if (Array.isArray(window.movementCache)) {
    existingRecords = existingRecords.concat(window.movementCache);
  }

  if (Array.isArray(window.generatedMovementRecords)) {
    existingRecords = existingRecords.concat(window.generatedMovementRecords);
  }

  return window.getNextMovementId(existingRecords);
}

/** 格式化為 YYYY-MM-DD HH:mm:ss / Format datetime for movement records */
function formatMovementDateTime(date) {
  var pad = function (num) {
    return String(num).padStart(2, '0');
  };
  return date.getFullYear() + '-' +
    pad(date.getMonth() + 1) + '-' +
    pad(date.getDate()) + ' ' +
    pad(date.getHours()) + ':' +
    pad(date.getMinutes()) + ':' +
    pad(date.getSeconds());
}

window.createMovementRecordId = createMovementRecordId;

function normalizeMovementRecord(record) {
  var items = Array.isArray(record && record.items)
    ? record.items
    : [{
      productName: record && record.productName,
      quantity: record && record.quantity,
      fromStore: record && record.fromStore,
      toStore: record && record.toStore,
      type: record && record.type
    }];

  return {
    id: (record && record.id) || createMovementRecordId(),
    movementNo: record && record.movementNo,
    inventoryDomain: (record && record.inventoryDomain) || 'legacy',
    movementType: record && record.movementType,
    status: (record && record.status) || 'posted',
    sourceLocationId: record && record.sourceLocationId,
    sourceLocationName: record && record.sourceLocationName,
    destinationLocationId: record && record.destinationLocationId,
    destinationLocationName: record && record.destinationLocationName,
    reason: (record && record.reason) || '',
    postedAt: record && record.postedAt,
    // 權威欄位 camelCase；保留 created_at 一版相容讀取（getMovementCreatedAt 已 fallback）
    createdAt: (record && record.occurredAt) || getMovementCreatedAt(record) || formatMovementDateTime(new Date()),
    employeeId: (record && (record.employeeId || record.adminId || record.staffId)) || '—',
    employeeName: record && record.employeeName,
    items: items.map(function (item) {
      return {
        inventoryDomain: (item && item.inventoryDomain) || (record && record.inventoryDomain) || 'legacy',
        variantId: (item && item.variantId) || null,
        sku: (item && item.sku) || null,
        productName: (item && item.productName) || '未命名商品',
        quantity: parseInt(item && item.quantity, 10) || 0,
        fromStore: (item && (item.fromStore || item.sourceLocationId)) ||
          (record && (record.sourceLocationName || record.sourceLocationId)) || '—',
        toStore: (item && (item.toStore || item.destinationLocationId)) ||
          (record && (record.destinationLocationName || record.destinationLocationId)) || '—',
        type: (item && item.type) || MOVEMENT_TYPE_LABELS[record && record.movementType] ||
          (record && record.movementType) || '—'
      };
    })
  };
}

/**
 * Isolate the pre-P5 JSON shape behind a read-only adapter. It deliberately
 * does not invent a variant identity from legacy productId.
 */
function adaptLegacyMovementRecord(record) {
  if (!record || record.inventoryDomain || record.movementNo) return record;
  return {
    id: record.id,
    legacyMovementId: String(record.id || ''),
    inventoryDomain: 'legacy',
    createdAt: getMovementCreatedAt(record),
    employeeId: record.employeeId || record.adminId || record.staffId,
    items: (record.items || []).map(function (item) {
      return {
        inventoryDomain: 'legacy',
        variantId: null,
        sku: null,
        productName: item.productName,
        quantity: item.quantity,
        fromStore: item.fromStore,
        toStore: item.toStore,
        type: item.type
      };
    })
  };
}

/**
 * 取得一筆紀錄所有不重複的異動性質（供篩選使用）
 * Get unique movement types from a record's items array.
 */
function getRecordMovementTypes(record) {
  var types = {};
  (record.items || []).forEach(function (item) {
    types[item.type || '—'] = true;
  });
  return Object.keys(types);
}

/**
 * 從 items 陣列摘要顯示「異動性質」（取各 item type 的唯一值集合）。
 * 若有多種 type，用頓號連接。
 */
function summarizeMovementTypes(items) {
  var types = {};
  (items || []).forEach(function (item) {
    var t = item.type || '—';
    types[t] = true;
  });
  var keys = Object.keys(types);
  return keys.length > 0 ? keys.join('、') : '—';
}

/**
 * 依資料動態產生「負責員工 ID」篩選選項
 * Dynamically build employee ID filter checkboxes from cache.
 */
function populateEmployeeFilterOptions(records) {
  var ids = {};
  (records || []).forEach(function (record) {
    var id = record.employeeId;
    if (id && id !== '—') {
      ids[id] = true;
    }
  });

  var html = Object.keys(ids).sort().map(function (id) {
    return '<label><input type="checkbox" value="' + escapeMovementHtml(id) + '"> ' +
      escapeMovementHtml(id) + '</label>';
  }).join('');

  var $dropdown = $('#movementTable .filter-th[data-filter-key="employeeId"] .filter-dropdown');
  if (!$dropdown.length) return;

  $dropdown.html(
    html || '<span class="text-muted small px-2">尚無員工資料</span>'
  );
}

// ─────────────────────────────────────────────
// 日期篩選器（邏輯對齊 orders.js）
// ─────────────────────────────────────────────

function fmtMovementDateISO(d) {
  if (!d) return null;
  return d.getFullYear() + '-' +
    String(d.getMonth() + 1).padStart(2, '0') + '-' +
    String(d.getDate()).padStart(2, '0');
}

function applyMovementDayRange(days) {
  if (days === 'all') {
    movementDateState.days      = 'all';
    movementDateState.startDate = null;
    movementDateState.endDate   = null;
    movementFilterState.dateStart = null;
    movementFilterState.dateEnd   = null;
  } else if (days === 'month') {
    var now   = new Date();
    var start = new Date(now.getFullYear(), now.getMonth(), 1);
    movementDateState.days      = 'month';
    movementDateState.startDate = start;
    movementDateState.endDate   = new Date(now);
    movementFilterState.dateStart = fmtMovementDateISO(start);
    movementFilterState.dateEnd   = fmtMovementDateISO(new Date(now));
  } else {
    var now   = new Date();
    var start = new Date(now);
    start.setDate(start.getDate() - (days - 1));
    movementDateState.days      = days;
    movementDateState.startDate = start;
    movementDateState.endDate   = new Date(now);
    movementFilterState.dateStart = fmtMovementDateISO(start);
    movementFilterState.dateEnd   = fmtMovementDateISO(new Date(now));
  }

  if (days !== 'custom') {
    $('#movementDateRangePicker').hide();
  }
  updateMovementPeriodLabel();
  applyMovementFiltersAndSort();
}

function applyMovementCustomRange(dateStart, dateEnd) {
  movementDateState.days      = 'custom';
  movementDateState.startDate = dateStart ? new Date(dateStart + 'T00:00:00') : null;
  movementDateState.endDate   = dateEnd   ? new Date(dateEnd   + 'T00:00:00') : null;
  movementFilterState.dateStart = dateStart || null;
  movementFilterState.dateEnd   = dateEnd   || null;
  updateMovementPeriodLabel();
  applyMovementFiltersAndSort();

  var pickerEl = document.querySelector('#movementDateRangePicker');
  if (pickerEl && pickerEl._flatpickr && movementDateState.startDate && movementDateState.endDate) {
    pickerEl._flatpickr.setDate(
      [movementDateState.startDate, movementDateState.endDate],
      false
    );
  }
  $('#movementDateRangePicker').show();
}

function updateMovementPeriodLabel() {
  var days = movementDateState.days;

  $('#movementPeriodBtns button').removeClass('active');
  if (days !== 'all') {
    $('#movementPeriodBtns button[data-days="' + days + '"]').addClass('active');
  }

  var $label = $('#movementPeriodLabel');

  if (days === 'custom') {
    $label.addClass('d-none').text('');
    return;
  }

  $label.removeClass('d-none');

  if (days === 'all') {
    $label.text('全部期間');
  } else if (movementDateState.startDate && movementDateState.endDate) {
    $label.text(
      fmtMovementDateISO(movementDateState.startDate) + ' 至 ' +
      fmtMovementDateISO(movementDateState.endDate)
    );
  } else {
    $label.text('');
  }
}

function enterMovementCustomMode() {
  movementDateState.days = 'custom';
  updateMovementPeriodLabel();

  var pickerEl = document.querySelector('#movementDateRangePicker');
  if (pickerEl && pickerEl._flatpickr && movementDateState.startDate && movementDateState.endDate) {
    pickerEl._flatpickr.setDate(
      [movementDateState.startDate, movementDateState.endDate],
      false
    );
  }

  $('#movementDateRangePicker').show().trigger('click');
}

function initMovementFlatpickr() {
  if (typeof flatpickr === 'undefined') return;

  var locale = (flatpickr.l10ns && flatpickr.l10ns.zh_tw)
    ? flatpickr.l10ns.zh_tw
    : 'default';

  flatpickr('#movementDateRangePicker', {
    mode: 'range',
    dateFormat: 'Y-m-d',
    locale: locale,
    onClose: function (selectedDates) {
      if (selectedDates.length === 2) {
        applyMovementCustomRange(
          fmtMovementDateISO(selectedDates[0]),
          fmtMovementDateISO(selectedDates[1])
        );
      }
    }
  });
}

function setupMovementPeriodFilter() {
  $(document).on('click.movement', '#movementPeriodBtns button[data-days]', function () {
    var days = $(this).data('days');

    if (days === 'custom') {
      enterMovementCustomMode();
    } else if (days === 'month') {
      if ($(this).hasClass('active')) {
        applyMovementDayRange('all');
      } else {
        applyMovementDayRange('month');
      }
    } else if ($(this).hasClass('active')) {
      applyMovementDayRange('all');
    } else {
      applyMovementDayRange(parseInt(days, 10));
    }
  });
}

/**
 * 依 movementFilterState 篩選、依 movementSortStack 排序，再重新渲染表格
 * Filter → sort → render pipeline (same pattern as orders.js)
 */
function applyMovementFiltersAndSort() {
  var data = (window.movementCache || []).slice();

  // ── Step 1：篩選（欄位之間 AND，同欄多選 OR） ──

  if (movementFilterState.employeeId.length > 0) {
    data = data.filter(function (record) {
      return movementFilterState.employeeId.indexOf(record.employeeId) !== -1;
    });
  }

  if (movementFilterState.movementType.length > 0) {
    data = data.filter(function (record) {
      var types = getRecordMovementTypes(record);
      return types.some(function (type) {
        return movementFilterState.movementType.indexOf(type) !== -1;
      });
    });
  }

  // 日期範圍篩選（比對 created_at 的日期部分）
  if (movementFilterState.dateStart) {
    data = data.filter(function (record) {
      return getMovementCreatedAt(record).slice(0, 10) >= movementFilterState.dateStart;
    });
  }
  if (movementFilterState.dateEnd) {
    data = data.filter(function (record) {
      return getMovementCreatedAt(record).slice(0, 10) <= movementFilterState.dateEnd;
    });
  }

  // ── Step 2：排序（多鍵穩定排序） ──
  if (movementSortStack.length > 0) {
    data.sort(function (a, b) {
      for (var i = 0; i < movementSortStack.length; i++) {
        var key = movementSortStack[i].key;
        var dir = movementSortStack[i].dir === 'asc' ? 1 : -1;
        var valA = key === 'createdAt' || key === 'created_at' ? getMovementCreatedAt(a) : (a[key] || '');
        var valB = key === 'createdAt' || key === 'created_at' ? getMovementCreatedAt(b) : (b[key] || '');
        if (valA < valB) return -1 * dir;
        if (valA > valB) return  1 * dir;
      }
      return (b.id - a.id);
    });
  }

  // ── Step 3：渲染 + 更新 UI ──
  renderMovementTable(data);
  updateMovementSortUI();
  updateMovementFilterUI();
}

/**
 * 依 movementSortStack 更新欄位標頭箭頭 icon 與「清除條件」按鈕
 */
function updateMovementSortUI() {
  $('#movementTable .sort-icon')
    .removeClass('fa-sort-up fa-sort-down sort-active')
    .addClass('fa-sort');

  movementSortStack.forEach(function (s) {
    var $icon = $('#movementTable .sortable-th[data-sort-key="' + s.key + '"] .sort-icon');
    $icon
      .removeClass('fa-sort')
      .addClass(s.dir === 'asc' ? 'fa-sort-up' : 'fa-sort-down')
      .addClass('sort-active');
  });

  var isDefaultSort = (
    movementSortStack.length === 1 &&
    movementSortStack[0].key === 'createdAt' &&
    movementSortStack[0].dir === 'desc'
  );

  var hasActiveFilter = (
    movementFilterState.employeeId.length > 0 ||
    movementFilterState.movementType.length > 0
  );

  var isDefaultDate = movementDateState.days === 30;

  if (!isDefaultSort || hasActiveFilter || !isDefaultDate) {
    $('#btnClearMovementSort').removeClass('d-none');
  } else {
    $('#btnClearMovementSort').addClass('d-none');
  }
}

/**
 * 依 movementFilterState 更新漏斗 icon 顏色、紅點與 checkbox 勾選狀態
 */
function updateMovementFilterUI() {
  ['employeeId', 'movementType'].forEach(function (key) {
    var $th   = $('#movementTable .filter-th[data-filter-key="' + key + '"]');
    var $icon = $th.find('.filter-icon');
    var $dot  = $th.find('.filter-dot');

    if (movementFilterState[key].length > 0) {
      $icon.addClass('active');
      $dot.removeClass('d-none');
      $th.find('input[type="checkbox"]').each(function () {
        $(this).prop('checked', movementFilterState[key].indexOf($(this).val()) !== -1);
      });
    } else {
      $icon.removeClass('active');
      $dot.addClass('d-none');
      $th.find('input[type="checkbox"]').prop('checked', false);
    }
  });
}

function renderMovementTable(records) {
  if (!records || records.length === 0) {
    $('#movementTableBody').html(
      '<tr><td colspan="6" class="text-center text-muted py-4">目前沒有符合條件的庫存異動紀錄</td></tr>'
    );
    return;
  }

  var html = records.map(function (record) {
    var itemCount = (record.items || []).length;
    var typesSummary = summarizeMovementTypes(record.items);

    return '<tr data-movement-id="' + escapeMovementHtml(record.id) + '">' +
      '<td>' +
      '<span class="admin-cell-link movement-detail-link" ' +
      'data-movement-id="' + escapeMovementHtml(record.id) + '">' +
      escapeMovementHtml(record.movementNo || window.formatMovementId(record.id)) +
      '</span>' +
      '</td>' +
      '<td>' + escapeMovementHtml(getMovementCreatedAt(record).slice(0, 10)) + '</td>' +
      '<td>' + escapeMovementHtml(record.employeeId || '—') + '</td>' +
      '<td>' + itemCount + ' 筆</td>' +
      '<td>' + buildMovementStatusBadge(record.status) + '</td>' +
      '<td>' + escapeMovementHtml(typesSummary) + '</td>' +
      '</tr>';
  }).join('');

  $('#movementTableBody').html(html);
}

function showMovementDetailModal(record) {
  $('#movementDetailModal').data('movement-id', record.id);
  $('#modalMovementId').text(record.movementNo || window.formatMovementId(record.id));
  $('#modalMovementDate').text(getMovementCreatedAt(record));
  $('#modalMovementEmployeeId').text(
    (record.employeeName ? record.employeeName + ' / ' : '') + (record.employeeId || '—')
  );
  $('#modalMovementStatus').html(buildMovementStatusBadge(record.status));
  $('#modalMovementDomain').text(record.inventoryDomain === 'rental' ? '租借庫存' : '商城庫存');
  $('#modalMovementReason').text(record.reason || '—');

  var itemsHtml = (record.items || []).map(function (item) {
    var typeBadge = item.type || '—';
    var typeCellContent = item.type === '損耗'
      ? '<span class="badge bg-warning text-dark">' + escapeMovementHtml(typeBadge) + '</span>'
      : escapeMovementHtml(typeBadge);

    return '<tr>' +
      '<td>' + escapeMovementHtml(item.productName) + '</td>' +
      '<td class="text-center fw-semibold">' + escapeMovementHtml(item.quantity) + '</td>' +
      '<td>' + escapeMovementHtml(item.fromStore) + '</td>' +
      '<td>' + escapeMovementHtml(item.toStore) + '</td>' +
      '<td>' + typeCellContent + '</td>' +
      '</tr>';
  }).join('');

  $('#modalMovementItems').html(
    itemsHtml || '<tr><td colspan="5" class="text-center text-muted">沒有異動明細</td></tr>'
  );

  var isDraft = isAdminMovementBackendEnabled() && record.status === 'draft';
  $('#draftMovementItemEditor').toggleClass('d-none', !isDraft);
  $('#postMovementDraft, #cancelMovementDraft').toggleClass('d-none', !isDraft);
  if (isDraft) {
    renderOpenDraftVariantOptions(record);
  }

  bootstrap.Modal.getOrCreateInstance(document.getElementById('movementDetailModal')).show();
}

/** 依異動狀態建立一致的 Bootstrap badge。 */
function buildMovementStatusBadge(status) {
  var style = status === 'posted'
    ? 'bg-success'
    : (status === 'cancelled' ? 'bg-secondary' : 'bg-warning text-dark');
  return '<span class="badge ' + style + '">' +
    escapeMovementHtml(MOVEMENT_STATUS_LABELS[status] || status || '—') +
    '</span>';
}

/** 載入正式庫位與規格 lookup，避免前端用名稱猜 ID。 */
function loadBackendMovementLookups() {
  AdminAPI.movement.getLookups().then(function (response) {
    adminMovementLookups = response.data || { locations: [], variants: [] };
    renderMovementLocationOptions();
    renderMovementDraftRows();
  }).catch(function (error) {
    AdminAPI.handleError(error, '載入庫存異動選項失敗');
  });
}

/** 重設建立草稿 Modal，預設使用商城入庫與一筆明細。 */
function resetMovementDraftForm() {
  document.getElementById('movementDraftForm').reset();
  $('#movementDomain').val('store');
  $('#movementType').val('receipt');
  $('#movementOccurredAt').val('');
  $('#movementDraftRows').empty();
  renderMovementLocationOptions();
  appendMovementDraftRow();
  syncMovementLocationFields();
}

function movementLocationsForDomain(domain) {
  return (adminMovementLookups.locations || []).filter(function (location) {
    return location.inventoryDomain === domain;
  });
}

function movementVariantsForDomain(domain) {
  return (adminMovementLookups.variants || []).filter(function (variant) {
    return variant.inventoryDomain === domain;
  });
}

/** 依庫存領域刷新來源與目的庫位選項。 */
function renderMovementLocationOptions() {
  var domain = $('#movementDomain').val() || 'store';
  var options = movementLocationsForDomain(domain).map(function (location) {
    return '<option value="' + escapeMovementHtml(location.id) + '">' +
      escapeMovementHtml(location.name + '（' + location.code + '）') +
      '</option>';
  }).join('');
  $('#movementSourceLocation, #movementDestinationLocation').html(options);
}

/** 類型決定來源／目的欄位，完全對齊後端與 DB CHECK。 */
function syncMovementLocationFields() {
  var type = $('#movementType').val();
  $('#movementSourceGroup').toggleClass('d-none', type === 'receipt');
  $('#movementDestinationGroup').toggleClass('d-none', type === 'write_off');
}

function buildMovementVariantOptions(domain) {
  return movementVariantsForDomain(domain).map(function (variant) {
    return '<option value="' + escapeMovementHtml(variant.id) + '">' +
      escapeMovementHtml(variant.productName + ' / ' + variant.sku + ' / ' + variant.specification) +
      '</option>';
  }).join('');
}

/** 在草稿建立表單加入一筆規格數量列。 */
function appendMovementDraftRow() {
  var domain = $('#movementDomain').val() || 'store';
  var html = '<div class="movement-draft-row row g-2 align-items-end border rounded p-2">' +
    '<div class="col-md-9"><label class="form-label small">商品規格</label>' +
    '<select class="form-select form-select-sm movement-draft-variant" required>' +
    buildMovementVariantOptions(domain) + '</select></div>' +
    '<div class="col-md-2"><label class="form-label small">數量</label>' +
    '<input type="number" class="form-control form-control-sm movement-draft-quantity" ' +
    'min="1" value="1" required></div>' +
    '<div class="col-md-1 d-grid"><button type="button" ' +
    'class="btn btn-sm btn-outline-danger remove-movement-draft-row" title="移除">' +
    '<i class="fas fa-trash"></i></button></div></div>';
  $('#movementDraftRows').append(html);
}

/** 領域變更時保留列數並重建每列可選規格。 */
function renderMovementDraftRows() {
  var $rows = $('#movementDraftRows .movement-draft-row');
  if (!$rows.length) return;
  var options = buildMovementVariantOptions($('#movementDomain').val() || 'store');
  $rows.find('.movement-draft-variant').html(options);
}

/** 建立表頭後逐筆新增明細；任何失敗都保留已建立的 draft 供修正。 */
function submitMovementDraftForm() {
  var type = $('#movementType').val();
  var occurredValue = $('#movementOccurredAt').val();
  var request = {
    inventoryDomain: $('#movementDomain').val(),
    movementType: type,
    sourceLocationId: type === 'receipt' ? null : $('#movementSourceLocation').val(),
    destinationLocationId: type === 'write_off' ? null : $('#movementDestinationLocation').val(),
    reason: String($('#movementReason').val() || '').trim(),
    occurredAt: occurredValue ? new Date(occurredValue).toISOString() : null
  };
  var items = [];
  var variantIds = {};
  $('#movementDraftRows .movement-draft-row').each(function () {
    var variantId = $(this).find('.movement-draft-variant').val();
    var quantity = parseInt($(this).find('.movement-draft-quantity').val(), 10);
    if (variantId && quantity > 0 && !variantIds[variantId]) {
      items.push({ variantId: variantId, quantity: quantity });
      variantIds[variantId] = true;
    }
  });
  if (!request.reason || !items.length) {
    window.showAdminToast('請填寫原因並至少加入一筆有效明細', 'danger');
    return;
  }
  var $button = $('#submitMovementDraft').prop('disabled', true).text('建立中…');
  var movementId;
  AdminAPI.movement.createDraft(request).then(function (response) {
    movementId = response.data.id;
    return items.reduce(function (chain, item) {
      return chain.then(function () {
        return AdminAPI.movement.addItem(movementId, item);
      });
    }, Promise.resolve(response));
  }).then(function (response) {
    upsertBackendMovement(response.data);
    bootstrap.Modal.getOrCreateInstance(document.getElementById('movementDraftModal')).hide();
    window.showAdminToast('已建立草稿 ' + response.data.movementNo);
  }).catch(function (error) {
    AdminAPI.handleError(error, movementId
      ? '草稿已建立，但部分明細新增失敗；請從草稿詳情繼續處理'
      : '建立庫存異動草稿失敗');
  }).finally(function () {
    $button.prop('disabled', false).text('建立草稿');
  });
}

function renderOpenDraftVariantOptions(record) {
  $('#draftMovementVariant').html(buildMovementVariantOptions(record.inventoryDomain));
  $('#draftMovementQuantity').val(1);
}

/** 對目前開啟的 draft 新增明細，後端成功後才更新 cache。 */
function addItemToOpenMovementDraft() {
  var movementId = $('#movementDetailModal').data('movement-id');
  var request = {
    variantId: $('#draftMovementVariant').val(),
    quantity: parseInt($('#draftMovementQuantity').val(), 10)
  };
  if (!request.variantId || !(request.quantity > 0)) {
    window.showAdminToast('請選擇規格並輸入正整數數量', 'danger');
    return;
  }
  AdminAPI.movement.addItem(movementId, request).then(function (response) {
    var record = upsertBackendMovement(response.data);
    showMovementDetailModal(record);
    window.showAdminToast('異動明細已新增');
  }).catch(function (error) {
    AdminAPI.handleError(error, '新增異動明細失敗');
  });
}

/** 過帳或作廢都以後端回應取代 cache，避免前端假成功。 */
function changeOpenMovementStatus(action) {
  var movementId = $('#movementDetailModal').data('movement-id');
  var operation = action === 'post'
    ? AdminAPI.movement.post(movementId)
    : AdminAPI.movement.cancel(movementId);
  operation.then(function (response) {
    var record = upsertBackendMovement(response.data);
    showMovementDetailModal(record);
    window.showAdminToast(action === 'post' ? '庫存異動已過帳' : '庫存異動已作廢');
  }).catch(function (error) {
    AdminAPI.handleError(error, action === 'post' ? '庫存異動過帳失敗' : '庫存異動作廢失敗');
  });
}

function upsertBackendMovement(movement) {
  var record = normalizeMovementRecord(movement);
  var index = (window.movementCache || []).findIndex(function (item) {
    return window.sameId(item.id, record.id);
  });
  window.movementCache = window.movementCache || [];
  if (index >= 0) {
    window.movementCache[index] = record;
  } else {
    window.movementCache.unshift(record);
  }
  populateEmployeeFilterOptions(window.movementCache);
  applyMovementFiltersAndSort();

  return record;
}

function escapeMovementHtml(value) {
  return String(value === null || value === undefined ? '' : value).replace(/[&<>"']/g, function (char) {
    return {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#39;'
    }[char];
  });
}
