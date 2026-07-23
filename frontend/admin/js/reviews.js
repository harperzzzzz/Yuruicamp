/**
 * Admin 評論管理：後端分頁、搜尋、評分篩選、排序、詳情與刪除。
 */

var REVIEWS_STORAGE_KEY = 'mockReviews';
var LEGACY_REVIEWS_STORAGE_KEY = 'adminReviews';
var REVIEW_SEARCH_DELAY_MS = 300;
var pendingDeleteReviewId = null;
var reviewSearchTimer = null;

var reviewsState = {
  allReviews: [],
  pageReviews: [],
  searchQuery: '',
  ratingFilter: '',
  sortBy: 'date-desc',
  page: 0,
  size: 20,
  totalElements: 0,
  totalPages: 0,
  loading: false,
};

window.initReviews = function () {
  $(document).off('.reviews');
  bindReviewEvents();
  loadReviews();
};

function isBackendMode() {
  return typeof AdminAPI !== 'undefined' &&
    AdminAPI.isBackendEnabled &&
    AdminAPI.isBackendEnabled();
}

function loadReviews() {
  if (reviewsState.loading) return;
  reviewsState.loading = true;
  renderLoading();

  if (isBackendMode()) {
    AdminAPI.reviews.list(buildBackendQuery())
      .then(function (res) {
        var meta = (res && res.meta) || {};
        reviewsState.pageReviews = (res && res.data) || [];
        reviewsState.totalElements = Number(meta.totalElements) || 0;
        reviewsState.totalPages = Number(meta.totalPages) || 0;
        reviewsState.page = Number(meta.page) || 0;
        renderCurrentPage();
      })
      .catch(function (err) {
        AdminAPI.handleError(err, '載入評論失敗');
        renderLoadError();
      })
      .finally(function () {
        reviewsState.loading = false;
      });
    return;
  }

  loadMockReviews(function (reviews) {
    reviewsState.allReviews = reviews;
    applyMockQuery();
    reviewsState.loading = false;
  });
}

function buildBackendQuery() {
  var query = {
    page: reviewsState.page,
    size: reviewsState.size,
    sort: backendSortValue(),
  };
  if (reviewsState.searchQuery) query.q = reviewsState.searchQuery;
  if (reviewsState.ratingFilter) query.rating = reviewsState.ratingFilter;
  return query;
}

function backendSortValue() {
  if (reviewsState.sortBy === 'rating-asc') return 'rating,asc';
  if (reviewsState.sortBy === 'rating-desc') return 'rating,desc';
  return 'createdAt,desc';
}

function loadMockReviews(callback) {
  function normalizeLegacyReviewIds(reviews) {
    return (reviews || []).map(function (review) {
      var normalized = review && review.payload ? review.payload : review;
      if (normalized && /^R\d+$/.test(normalized.id)) {
        normalized = Object.assign({}, normalized, { id: 'REV' + normalized.id.slice(1) });
      }
      if (normalized && typeof normalized.verifiedPurchase !== 'boolean') {
        normalized = Object.assign({}, normalized, { verifiedPurchase: true });
      }
      return normalized;
    });
  }

  function finishLoad(seed) {
    var base = seed || [];
    if (typeof MockStorageMerge !== 'undefined') {
      var legacy = MockStorageMerge.readJsonStorage(LEGACY_REVIEWS_STORAGE_KEY, []);
      var overlay = MockStorageMerge.readJsonStorage(REVIEWS_STORAGE_KEY, []);
      base = MockStorageMerge.mergeById(base, legacy, 'id');
      base = MockStorageMerge.mergeById(base, overlay, 'id');
      if (legacy.length) localStorage.removeItem(LEGACY_REVIEWS_STORAGE_KEY);
    }
    callback(normalizeLegacyReviewIds(base));
  }

  $.getJSON(MockDataPaths.reviews, finishLoad).fail(function () {
    renderLoadError();
    reviewsState.loading = false;
  });
}

function applyMockQuery() {
  var filtered = reviewsState.allReviews.filter(function (review) {
    if (reviewsState.ratingFilter &&
        Number(review.rating) !== Number(reviewsState.ratingFilter)) {
      return false;
    }
    if (!reviewsState.searchQuery) return true;
    var query = reviewsState.searchQuery.toLowerCase();
    return [
      review.id,
      review.buyerName,
      review.productName,
      review.comment,
    ].join(' ').toLowerCase().indexOf(query) !== -1;
  });

  filtered.sort(function (a, b) {
    if (reviewsState.sortBy === 'rating-asc') {
      return (Number(a.rating) || 0) - (Number(b.rating) || 0);
    }
    if (reviewsState.sortBy === 'rating-desc') {
      return (Number(b.rating) || 0) - (Number(a.rating) || 0);
    }
    return String(b.createdAt).localeCompare(String(a.createdAt));
  });

  reviewsState.totalElements = filtered.length;
  reviewsState.totalPages = Math.ceil(filtered.length / reviewsState.size);
  if (reviewsState.totalPages > 0 && reviewsState.page >= reviewsState.totalPages) {
    reviewsState.page = reviewsState.totalPages - 1;
  }
  var start = reviewsState.page * reviewsState.size;
  reviewsState.pageReviews = filtered.slice(start, start + reviewsState.size);
  renderCurrentPage();
}

function bindReviewEvents() {
  $(document).on('input.reviews', '#reviewSearchInput', function () {
    var value = $(this).val().trim();
    window.clearTimeout(reviewSearchTimer);
    reviewSearchTimer = window.setTimeout(function () {
      reviewsState.searchQuery = value;
      resetPageAndLoad();
    }, REVIEW_SEARCH_DELAY_MS);
  });

  $(document).on('change.reviews', '#reviewRatingFilter', function () {
    reviewsState.ratingFilter = $(this).val();
    resetPageAndLoad();
  });

  $(document).on('change.reviews', '#reviewSortSelect', function () {
    reviewsState.sortBy = $(this).val();
    resetPageAndLoad();
  });

  $(document).on('change.reviews', '#reviewPageSize', function () {
    reviewsState.size = Number($(this).val()) || 20;
    resetPageAndLoad();
  });

  $(document).on('click.reviews', '#btnClearReviewFilters', function () {
    reviewsState.searchQuery = '';
    reviewsState.ratingFilter = '';
    reviewsState.sortBy = 'date-desc';
    $('#reviewSearchInput').val('');
    $('#reviewRatingFilter').val('');
    $('#reviewSortSelect').val('date-desc');
    resetPageAndLoad();
  });

  $(document).on('click.reviews', '#reviewsPrevPage', function () {
    if (reviewsState.page <= 0) return;
    reviewsState.page -= 1;
    loadOrApplyMock();
  });

  $(document).on('click.reviews', '#reviewsNextPage', function () {
    if (reviewsState.page + 1 >= reviewsState.totalPages) return;
    reviewsState.page += 1;
    loadOrApplyMock();
  });

  $(document).on('click.reviews', '.btn-review-detail', function () {
    openReviewDetail($(this).data('review-id'));
  });

  $(document).on('click.reviews', '.btn-delete-review', function () {
    openReviewDeleteModal($(this).data('review-id'));
  });

  $(document).on('click.reviews', '#confirmDeleteReviewBtn', function () {
    if (pendingDeleteReviewId) deleteReview(pendingDeleteReviewId);
  });

  $(document).on('hidden.bs.modal.reviews', '#reviewDeleteModal', function () {
    pendingDeleteReviewId = null;
  });
}

function resetPageAndLoad() {
  reviewsState.page = 0;
  loadOrApplyMock();
}

function loadOrApplyMock() {
  if (isBackendMode()) loadReviews();
  else applyMockQuery();
}

function renderCurrentPage() {
  renderReviewCards(reviewsState.pageReviews);
  updateReviewCount();
  updatePagination();
  updateClearButtonVisibility();
}

function updateReviewCount() {
  $('#tabCountAll').text(reviewsState.totalElements);
}

function updatePagination() {
  var hasResults = reviewsState.totalElements > 0;
  $('#reviewsPagination').toggleClass('d-none', !hasResults);
  if (!hasResults) return;

  var from = reviewsState.page * reviewsState.size + 1;
  var to = Math.min(from + reviewsState.pageReviews.length - 1, reviewsState.totalElements);
  var pageNumber = reviewsState.page + 1;
  var totalPages = Math.max(reviewsState.totalPages, 1);
  $('#reviewsPageSummary').text(
    '第 ' + from + '–' + to + ' 筆，共 ' + reviewsState.totalElements +
    ' 筆（第 ' + pageNumber + '／' + totalPages + ' 頁）'
  );
  $('#reviewsPrevPage').prop('disabled', reviewsState.page <= 0);
  $('#reviewsNextPage').prop('disabled', pageNumber >= totalPages);
}

function updateClearButtonVisibility() {
  var hasFilters = reviewsState.searchQuery !== '' ||
    reviewsState.ratingFilter !== '' ||
    reviewsState.sortBy !== 'date-desc';
  $('#btnClearReviewFilters').toggleClass('d-none', !hasFilters);
}

function renderLoading() {
  $('#reviewsContainer').html(
    '<div class="text-center py-5" role="status">' +
    '<div class="spinner-border spinner-border-sm me-2"></div>' +
    '<span class="text-muted">載入評論中...</span></div>'
  );
  $('#reviewsPagination').addClass('d-none');
}

function renderLoadError() {
  $('#reviewsContainer').html(
    '<div class="alert alert-danger mb-0">' +
    '<i class="fas fa-exclamation-triangle me-2"></i>載入評論失敗</div>'
  );
  $('#reviewsPagination').addClass('d-none');
}

function escapeHtml(value) {
  return $('<div>').text(value == null ? '' : String(value)).html();
}

function renderStars(rating) {
  var html = '';
  var value = Number(rating) || 0;
  for (var i = 1; i <= 5; i++) {
    html += i <= value
      ? '<i class="fas fa-star text-warning"></i>'
      : '<i class="far fa-star text-muted"></i>';
  }
  return html;
}

function renderReviewPhotos(photos) {
  if (!photos || !photos.length) return '';
  return '<div class="review-photos d-flex flex-wrap gap-2 mt-2">' +
    photos.map(function (url) {
      return '<a href="' + escapeHtml(url) + '" target="_blank" rel="noopener" class="review-photo-thumb">' +
        '<img src="' + escapeHtml(url) + '" alt="評論照片"' +
        ' onerror="this.parentElement.classList.add(\'d-none\')"></a>';
    }).join('') +
    '</div>';
}

function renderReviewCards(reviews) {
  if (!reviews || reviews.length === 0) {
    var message = reviewsState.searchQuery || reviewsState.ratingFilter
      ? '找不到符合條件的評論'
      : '目前沒有評論';
    $('#reviewsContainer').html(
      '<div class="text-center text-muted py-5">' +
      '<i class="far fa-comment-dots fa-2x mb-2 d-block opacity-50"></i>' +
      escapeHtml(message) + '</div>'
    );
    return;
  }

  var html = '<div class="row g-3">' + reviews.map(function (review) {
    var rating = Number(review.rating) || 0;
    var urgentClass = rating <= 2 ? ' review-card-urgent' : '';
    var urgentBadge = rating <= 2
      ? '<span class="badge bg-danger ms-1">需關注</span>'
      : '';
    var avatar = review.buyerAvatar || 'https://placehold.co/44x44/cccccc/555555?text=U';

    return '<div class="col-12"><div class="card shadow-sm review-card' + urgentClass + '">' +
      '<div class="card-body"><div class="d-flex align-items-start gap-3">' +
      '<img src="' + escapeHtml(avatar) + '" width="44" height="44"' +
      ' class="rounded-circle border object-fit-cover flex-shrink-0"' +
      ' alt="' + escapeHtml(review.buyerName) + ' 頭像"' +
      ' onerror="this.src=\'https://placehold.co/44x44/cccccc/555555?text=U\'">' +
      '<div class="flex-grow-1 min-w-0">' +
      '<div class="d-flex flex-wrap justify-content-between align-items-start gap-2 mb-1">' +
      '<div class="d-flex flex-wrap align-items-center gap-2">' +
      '<span class="fw-semibold">' + escapeHtml(review.buyerName) + '</span>' +
      '<span class="badge bg-secondary">' + escapeHtml(review.id) + '</span>' +
      urgentBadge + '</div>' +
      '<div class="review-card-stars">' + renderStars(rating) + '</div></div>' +
      '<div class="small text-muted mb-2">' +
      escapeHtml(review.createdAt) + ' · ' + escapeHtml(review.productName) + '</div>' +
      '<div class="review-buyer-comment"><p class="mb-0">' +
      escapeHtml(review.comment) + '</p>' + renderReviewPhotos(review.photos) + '</div>' +
      '<div class="d-flex flex-wrap justify-content-end gap-2 mt-3">' +
      '<button type="button" class="btn btn-sm btn-outline-secondary btn-review-detail"' +
      ' data-review-id="' + escapeHtml(review.id) + '">' +
      '<i class="fas fa-eye me-1"></i>查看詳情</button>' +
      '<button type="button" class="btn btn-sm btn-outline-danger btn-delete-review"' +
      ' data-review-id="' + escapeHtml(review.id) + '">' +
      '<i class="fas fa-trash-alt me-1"></i>刪除評論</button>' +
      '</div></div></div></div></div></div>';
  }).join('') + '</div>';

  $('#reviewsContainer').html(html);
  if (typeof window.applyEditPermission === 'function') {
    window.applyEditPermission('reviews', $('#contentArea'));
  }
}

function openReviewDetail(reviewId) {
  if (!reviewId) return;
  var modalElement = document.getElementById('reviewDetailModal');
  if (!modalElement) return;

  $('#reviewDetailContent').html(
    '<div class="text-center py-5" role="status">' +
    '<div class="spinner-border spinner-border-sm me-2"></div>載入詳情中...</div>'
  );
  bootstrap.Modal.getOrCreateInstance(modalElement).show();

  if (isBackendMode()) {
    AdminAPI.reviews.getById(reviewId)
      .then(function (res) {
        renderReviewDetail((res && res.data) || res);
      })
      .catch(function (err) {
        AdminAPI.handleError(err, '載入評論詳情失敗');
        $('#reviewDetailContent').html(
          '<div class="alert alert-danger mb-0">載入評論詳情失敗</div>'
        );
      });
    return;
  }

  var review = reviewsState.allReviews.find(function (item) {
    return item.id === reviewId;
  });
  if (review) renderReviewDetail(review);
  else $('#reviewDetailContent').html('<div class="alert alert-warning mb-0">找不到評論</div>');
}

function detailField(label, value, wide) {
  return '<div class="review-detail-field' + (wide ? ' review-detail-field-wide' : '') + '">' +
    '<div class="small text-muted mb-1">' + escapeHtml(label) + '</div>' +
    '<div class="text-break">' + escapeHtml(value || '—') + '</div></div>';
}

function renderReviewDetail(review) {
  if (!review) return;
  $('#reviewDetailContent').html(
    '<div class="review-detail-grid">' +
    detailField('評論編號', review.id) +
    detailField('建立時間', review.createdAt) +
    detailField('會員', review.buyerName) +
    detailField('會員編號', review.customerId) +
    detailField('商品', review.productName) +
    detailField('商品編號', review.productId) +
    detailField('訂單編號', review.orderId) +
    detailField('訂單項目編號', review.orderItemId) +
    detailField('SKU', review.sku) +
    detailField('評分', String(review.rating) + ' 星') +
    detailField('評論內容', review.comment, true) +
    '<div class="review-detail-field review-detail-field-wide">' +
    '<div class="small text-muted mb-1">評論照片</div>' +
    (renderReviewPhotos(review.photos) || '<span class="text-muted">無照片</span>') +
    '</div></div>'
  );
}

function openReviewDeleteModal(reviewId) {
  if (!reviewId) return;
  pendingDeleteReviewId = reviewId;
  $('#reviewDeleteTargetId').text(reviewId);
  var modalElement = document.getElementById('reviewDeleteModal');
  if (!modalElement) {
    window.showAdminToast('找不到刪除確認視窗', 'error');
    pendingDeleteReviewId = null;
    return;
  }
  bootstrap.Modal.getOrCreateInstance(modalElement).show();
}

function closeReviewDeleteModal() {
  var modalElement = document.getElementById('reviewDeleteModal');
  if (modalElement) {
    var modal = bootstrap.Modal.getInstance(modalElement);
    if (modal) modal.hide();
  }
  pendingDeleteReviewId = null;
}

function deleteReview(reviewId) {
  if (isBackendMode()) {
    AdminAPI.reviews.remove(reviewId)
      .then(function () {
        closeReviewDeleteModal();
        if (reviewsState.pageReviews.length === 1 && reviewsState.page > 0) {
          reviewsState.page -= 1;
        }
        loadReviews();
        window.showAdminToast('評論 ' + reviewId + ' 已刪除', 'warning');
      })
      .catch(function (err) {
        AdminAPI.handleError(err, '刪除評論失敗');
      });
    return;
  }

  reviewsState.allReviews = reviewsState.allReviews.filter(function (review) {
    return review.id !== reviewId;
  });
  localStorage.setItem(REVIEWS_STORAGE_KEY, JSON.stringify(reviewsState.allReviews));
  closeReviewDeleteModal();
  applyMockQuery();
  window.showAdminToast('評論 ' + reviewId + ' 已刪除', 'warning');
}
