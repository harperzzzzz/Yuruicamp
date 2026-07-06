/**
 * Creates the floating scroll-to-top and LINE shortcut buttons on booking pages.
 */
function initFloatingActions() {
  if (document.querySelector('.floatingActions')) return;

  const floatingActions = document.createElement('div');
  floatingActions.className = 'floatingActions';
  floatingActions.innerHTML = `
    <button
      class="floatingTopBtn"
      type="button"
      aria-label="回到頁面頂端"
      title="回到頁面頂端"
    >
      <i class="bi bi-chevron-up"></i>
    </button>
    <a
      class="floatingLineBtn"
      href="https://line.me"
      target="_blank"
      rel="noopener noreferrer"
      aria-label="LINE 聯絡"
      title="LINE 聯絡"
    >
      <span class="floatingLineLabel">LINE 客服</span>
      <span class="floatingLineIcon" aria-hidden="true">
        <i class="bi bi-chat-dots-fill"></i>
      </span>
    </a>
  `;

  document.body.appendChild(floatingActions);

  const topButton = floatingActions.querySelector('.floatingTopBtn');

  /**
   * Shows the top button only after the user scrolls past the first viewport segment.
   */
  function toggleTopButton() {
    const scrollTop = window.scrollY || document.documentElement.scrollTop;
    const shouldShow = scrollTop > window.innerHeight / 5;
    topButton.classList.toggle('isVisible', shouldShow);
  }

  topButton.addEventListener('click', function () {
    window.scrollTo({ top: 0, behavior: 'smooth' });
  });
  window.addEventListener('scroll', toggleTopButton, { passive: true });
  window.addEventListener('resize', toggleTopButton);
  toggleTopButton();
}

/**
 * Loads a script once and uses a window flag to prevent duplicate event bindings.
 * @param {string} src - Script URL to load.
 * @param {string} flagName - Window flag used to mark a loaded script.
 * @returns {Promise<void>} Resolves after the script loads.
 */
function loadScriptOnce(src, flagName) {
  return new Promise(function (resolve, reject) {
    if (window[flagName]) {
      resolve();
      return;
    }

    window[flagName] = true;
    const script = document.createElement('script');
    script.src = src;
    script.onload = function () {
      resolve();
    };
    script.onerror = function () {
      window[flagName] = false;
      reject(new Error('script load failed: ' + src));
    };
    document.body.appendChild(script);
  });
}

/**
 * Adds booking-scoped semantic classes to the shared auth partial without
 * changing the shared main-site markup contract or modal IDs.
 * @param {Element} target - Header container that received the shared auth partial.
 */
function applyBookingAuthSemanticClasses(target) {
  const classMap = [
    ['#loginModal', 'bookingAuthModal bookingLoginModal'],
    ['#personalizationModal', 'bookingAuthModal bookingPersonalizationModal'],
    ['#surveyCloseConfirmModal', 'bookingAuthModal bookingSurveyCloseConfirmModal'],
    ['.modalContent', 'bookingAuthModalContent'],
    ['.modalHeader', 'bookingAuthModalHeader'],
    ['.modalTitle', 'bookingAuthModalTitle'],
    ['.modalClose', 'bookingAuthModalClose'],
    ['.modalBody', 'bookingAuthModalBody'],
    ['.btnGoogleLogin', 'bookingAuthProviderGoogle'],
    ['.btnFacebookLogin', 'bookingAuthProviderFacebook'],
    ['.btnLineLogin', 'bookingAuthProviderLine'],
    ['.oauthDesc', 'bookingAuthOauthDesc'],
    ['.oauthPrivacy', 'bookingAuthOauthPrivacy'],
    ['.stepperHeader', 'bookingAuthStepperHeader'],
    ['.stepperDot', 'bookingAuthStepperDot'],
    ['.stepperLine', 'bookingAuthStepperLine'],
    ['.stepperText', 'bookingAuthStepperText'],
    ['.surveyStep', 'bookingAuthSurveyStep'],
    ['.surveyQuestion', 'bookingAuthSurveyQuestion'],
    ['.surveyHint', 'bookingAuthSurveyHint'],
    ['.surveyTags', 'bookingAuthSurveyTags'],
    ['.surveyTag', 'bookingAuthSurveyTag'],
    ['#surveyNextBtn', 'bookingSurveyNextButton'],
    ['#surveyFinishBtn', 'bookingSurveyFinishButton'],
  ];

  classMap.forEach(function ([selector, classNames]) {
    target.querySelectorAll(selector).forEach(function (element) {
      element.classList.add(...classNames.split(' '));
    });
  });
}

/**
 * 載入 booking shared auth 與 header 互動腳本。
 * 套用元件：#loginModal、#personalizationModal、.bookingHeader。
 */
function loadBookingHeaderScript() {
  loadScriptOnce('../../js/components/modal.js', '__yuruiModalScriptLoaded')
    .then(function () {
      return loadScriptOnce('../../js/components/auth.js', '__yuruiAuthScriptLoaded');
    })
    .then(function () {
      window.initModalListeners?.();
      return loadScriptOnce('../js/booking-header.js', '__bookingHeaderScriptLoaded');
    })
    .catch(function (error) {
      console.error(error);
    });
}

/**
 * Loads one data-layout-part from a shared partial into a booking page target.
 * @param {string} targetSelector - Target element selector.
 * @param {string} url - Partial URL.
 * @param {string} partSelector - data-layout-part selector to extract.
 * @param {Function=} callback - Optional completion callback.
 * @returns {Promise<boolean>} Whether the partial was loaded.
 */
function loadBookingLayoutPartial(targetSelector, url, partSelector, callback) {
  const target = document.querySelector(targetSelector);
  if (!target) {
    if (callback) callback(false);
    return Promise.resolve(false);
  }

  return fetch(url)
    .then(function (response) {
      if (!response.ok) throw new Error('booking layout partial load failed: ' + url);
      return response.text();
    })
    .then(function (html) {
      const template = document.createElement('template');
      template.innerHTML = html;
      const part = template.content.querySelector(partSelector);
      const content = part ? part.innerHTML : html;

      // Shared auth is appended after the booking header so both systems use one modal.
      if (partSelector === '[data-layout-part="shared-auth"]') {
        target.insertAdjacentHTML('beforeend', content);
        applyBookingAuthSemanticClasses(target);
      } else {
        target.innerHTML = content;
      }

      if (callback) callback(true);
      return true;
    })
    .catch(function (error) {
      console.error(error);
      if (callback) callback(false);
      return false;
    });
}

/**
 * Loads the booking header, shared auth modal, and footer for booking pages.
 */
window.loadBookingSharedLayout = function () {
  loadBookingLayoutPartial(
    '#bookingHeader',
    '../../components/header.partial',
    '[data-layout-part="bookingHeader"]',
    function (ok) {
      if (!ok) return;
      loadBookingLayoutPartial(
        '#bookingHeader',
        '../../components/header.partial',
        '[data-layout-part="shared-auth"]',
        function () {
          loadBookingHeaderScript();
        }
      );
    }
  );
  loadBookingLayoutPartial(
    '#bookingFooter',
    '../../components/footer.partial',
    '[data-layout-part="bookingFooter"]'
  );
};

document.addEventListener('DOMContentLoaded', initFloatingActions);
