// 用途：FAQ 頁互動入口，套用於 pages/faq.html。

const FAQ_SEARCH_DELAY = 300;
const FAQ_NPS_MIN = 0;
const FAQ_NPS_MAX = 10;

let selectedNpsScore = null;

/**
 * 用途：延遲執行頻繁觸發的事件處理，套用於 FAQ 搜尋輸入。
 * @param {Function} callback - 延遲執行的函式。
 * @param {number} delay - 延遲毫秒數。
 * @returns {Function} debounced event handler。
 */
function debounceFaqSearch(callback, delay) {
  let timer = null;

  return function debouncedHandler(...args) {
    clearTimeout(timer);
    timer = setTimeout(() => callback.apply(this, args), delay);
  };
}

/**
 * 用途：取得 FAQ 頁面需要操作的 DOM 節點，套用於搜尋、手風琴與回饋問卷。
 * @returns {object} FAQ DOM references。
 */
function getFaqElements() {
  return {
    searchInput: document.getElementById('faqSearchInput'),
    searchStatus: document.getElementById('faqSearchStatus'),
    searchEmptyState: document.querySelector('.faqSearchEmptyState'),
    categories: Array.from(document.querySelectorAll('.faqCategory')),
    accordionItems: Array.from(document.querySelectorAll('.faqAccordionItem')),
    npsGroup: document.getElementById('npsGroup'),
    feedbackTextarea: document.getElementById('feedbackTextarea'),
    submitFeedbackBtn: document.getElementById('submitFeedbackBtn'),
  };
}

/**
 * 用途：判斷 FAQ 問答是否符合搜尋關鍵字，套用於 FAQ 搜尋結果篩選。
 * @param {Element} item - FAQ accordion item。
 * @param {string} query - 已整理的小寫搜尋字串。
 * @returns {boolean} 是否符合搜尋。
 */
function faqItemMatchesQuery(item, query) {
  const questionText = item.querySelector('.faqAccordionQuestion')?.textContent || '';
  const answerText = item.querySelector('.faqAccordionAnswer')?.textContent || '';
  const searchableText = `${questionText} ${answerText}`.trim().toLowerCase();

  return searchableText.includes(query);
}

/**
 * 用途：更新搜尋狀態提示，套用於 FAQ 搜尋結果區。
 * @param {string} query - 使用者搜尋關鍵字。
 * @param {number} visibleCount - 符合結果數量。
 */
function updateFaqSearchStatus(query, visibleCount) {
  const { searchStatus, searchEmptyState } = getFaqElements();
  const hasQuery = query.length > 0;

  if (searchStatus) {
    searchStatus.textContent = hasQuery ? `找到 ${visibleCount} 個相關問題。` : '輸入關鍵字可篩選下方常見問題。';
  }

  if (searchEmptyState) {
    const shouldShowEmptyState = hasQuery && visibleCount === 0;
    searchEmptyState.hidden = !shouldShowEmptyState;
    searchEmptyState.classList.toggle('isEmpty', shouldShowEmptyState);
  }
}

/**
 * 用途：依關鍵字篩選 FAQ 項目並隱藏空分類，套用於 FAQ 搜尋表單。
 * @param {string} keyword - 搜尋關鍵字。
 */
function searchFaq(keyword) {
  const query = keyword.trim().toLowerCase();
  const { categories, accordionItems } = getFaqElements();
  let visibleItemCount = 0;

  accordionItems.forEach(item => {
    const matches = query === '' || faqItemMatchesQuery(item, query);

    item.hidden = !matches;
    item.classList.toggle('isHidden', !matches);

    if (matches) {
      visibleItemCount += 1;
    }
  });

  categories.forEach(category => {
    const visibleItems = Array.from(category.querySelectorAll('.faqAccordionItem')).filter(item => !item.hidden);
    const shouldHideCategory = visibleItems.length === 0;

    category.hidden = shouldHideCategory;
    category.classList.toggle('isHidden', shouldHideCategory);
  });

  updateFaqSearchStatus(query, visibleItemCount);
}

/**
 * 用途：切換單一 FAQ 手風琴項目的展開狀態，套用於 .faqAccordionTrigger。
 * @param {HTMLButtonElement} trigger - 被操作的手風琴按鈕。
 */
function toggleFaqAccordion(trigger) {
  const item = trigger.closest('.faqAccordionItem');
  const panelId = trigger.getAttribute('aria-controls');
  const panel = panelId ? document.getElementById(panelId) : null;
  const shouldOpen = trigger.getAttribute('aria-expanded') !== 'true';

  if (!item || !panel) return;

  item.classList.toggle('isOpen', shouldOpen);
  trigger.classList.toggle('isOpen', shouldOpen);
  trigger.setAttribute('aria-expanded', String(shouldOpen));
  panel.hidden = !shouldOpen;
}

/**
 * 用途：初始化 FAQ 手風琴事件，套用於所有 .faqAccordionTrigger。
 */
function initFaqAccordion() {
  const triggers = document.querySelectorAll('.faqAccordionTrigger');

  triggers.forEach(trigger => {
    trigger.addEventListener('click', () => {
      toggleFaqAccordion(trigger);
    });
  });
}

/**
 * 用途：依 NPS 分數取得狀態 class，套用於 NPS 按鈕選取狀態。
 * @param {number} score - NPS 分數。
 * @returns {string} score state class。
 */
function getNpsScoreClass(score) {
  if (score <= 6) return 'isLowScore';
  if (score <= 8) return 'isMidScore';
  return 'isHighScore';
}

/**
 * 用途：建立單一 NPS 按鈕 HTML，套用於 .faqNpsGroup。
 * @param {number} score - NPS 分數。
 * @returns {string} NPS button markup。
 */
function buildNpsButton(score) {
  return `
    <button
      class="faqNpsButton"
      type="button"
      role="radio"
      aria-checked="false"
      aria-label="評分 ${score} 分，尚未選取"
      data-score="${score}"
    >
      ${score}
    </button>
  `;
}

/**
 * 用途：清除 NPS 選取狀態，套用於送出成功後的問卷 reset。
 * @param {Element} npsGroup - NPS button group。
 */
function resetNpsSelection(npsGroup) {
  const buttons = npsGroup.querySelectorAll('.faqNpsButton');

  buttons.forEach(button => {
    const score = button.dataset.score;

    button.classList.remove('isSelected', 'isLowScore', 'isMidScore', 'isHighScore');
    button.setAttribute('aria-checked', 'false');
    button.setAttribute('aria-label', `評分 ${score} 分，尚未選取`);
  });

  selectedNpsScore = null;
}

/**
 * 用途：套用 NPS 選取狀態，套用於使用者點擊或鍵盤選取分數。
 * @param {HTMLButtonElement} selectedButton - 被選取的 NPS button。
 * @param {Element} npsGroup - NPS button group。
 */
function selectNpsScore(selectedButton, npsGroup) {
  const score = Number.parseInt(selectedButton.dataset.score, 10);

  if (Number.isNaN(score)) return;

  resetNpsSelection(npsGroup);
  selectedButton.classList.add('isSelected', getNpsScoreClass(score));
  selectedButton.setAttribute('aria-checked', 'true');
  selectedButton.setAttribute('aria-label', `已選取 ${score} 分`);
  selectedNpsScore = score;
}

/**
 * 用途：用方向鍵移動 NPS button 焦點，套用於 .faqNpsGroup 鍵盤操作。
 * @param {KeyboardEvent} event - keyboard event。
 * @param {Element} npsGroup - NPS button group。
 */
function moveNpsFocus(event, npsGroup) {
  const keys = ['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Home', 'End'];

  if (!keys.includes(event.key)) return;

  const buttons = Array.from(npsGroup.querySelectorAll('.faqNpsButton'));
  const currentIndex = buttons.indexOf(document.activeElement);
  let nextIndex = currentIndex;

  if (event.key === 'Home') nextIndex = 0;
  if (event.key === 'End') nextIndex = buttons.length - 1;
  if (event.key === 'ArrowLeft' || event.key === 'ArrowUp') nextIndex = Math.max(currentIndex - 1, 0);
  if (event.key === 'ArrowRight' || event.key === 'ArrowDown') nextIndex = Math.min(currentIndex + 1, buttons.length - 1);

  event.preventDefault();
  buttons[nextIndex]?.focus();
}

/**
 * 用途：初始化 NPS 評分按鈕與互動，套用於滿意度問卷。
 */
function initNpsButtons() {
  const { npsGroup } = getFaqElements();

  if (!npsGroup) return;

  npsGroup.innerHTML = Array.from({ length: FAQ_NPS_MAX - FAQ_NPS_MIN + 1 }, (_, index) =>
    buildNpsButton(index + FAQ_NPS_MIN)
  ).join('');

  npsGroup.addEventListener('click', event => {
    const button = event.target.closest('.faqNpsButton');

    if (!button) return;
    selectNpsScore(button, npsGroup);
  });

  npsGroup.addEventListener('keydown', event => {
    moveNpsFocus(event, npsGroup);
  });
}

/**
 * 用途：送出回饋表單並重置 UI 狀態，套用於 #submitFeedbackBtn。
 */
function initSubmitFeedback() {
  const { npsGroup, feedbackTextarea, submitFeedbackBtn } = getFaqElements();

  if (!npsGroup || !submitFeedbackBtn) return;

  submitFeedbackBtn.addEventListener('click', () => {
    if (selectedNpsScore === null) {
      if (typeof window.showToast === 'function') {
        window.showToast('請先給個評分再送出。', 'warning');
      }
      return;
    }

    if (typeof window.showToast === 'function') {
      window.showToast('感謝您的回饋，我們會持續改善服務。', 'success');
    }

    if (feedbackTextarea) {
      feedbackTextarea.value = '';
    }

    resetNpsSelection(npsGroup);
  });
}

/**
 * 用途：初始化 FAQ 搜尋表單，套用於 #faqSearchInput。
 */
function initFaqSearch() {
  const { searchInput } = getFaqElements();

  if (!searchInput) return;

  const debouncedSearch = debounceFaqSearch(searchFaq, FAQ_SEARCH_DELAY);

  searchInput.addEventListener('input', event => {
    debouncedSearch(event.target.value);
  });

  searchInput.closest('form')?.addEventListener('submit', event => {
    event.preventDefault();
    searchFaq(searchInput.value);
  });
}

/**
 * 用途：初始化 FAQ 頁面共用元件與頁面互動，套用於 pages/faq.html。
 */
window.initFaqPage = function initFaqPage() {
  window._appComponentsInitialized = true;

  if (typeof window.initNavbar === 'function') window.initNavbar();
  if (typeof window.initModalListeners === 'function') window.initModalListeners();
  if (typeof window.initCartListeners === 'function') window.initCartListeners();
  if (typeof window.initPersonalizationModal === 'function') window.initPersonalizationModal();

  initFaqSearch();
  initFaqAccordion();
  initNpsButtons();
  initSubmitFeedback();
};

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', window.initFaqPage);
} else {
  window.initFaqPage();
}
