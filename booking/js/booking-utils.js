/**
 * booking-utils.js
 * 預約系統共用工具函式
 * showToast(message, type) — 取代原生 alert，顯示右上角訊息提示框
 *   type: 'info' | 'warning' | 'error' | 'success'（預設 'info'）
 */
(function () {
  'use strict';

  var ICONS = {
    info: 'bi bi-info-circle-fill',
    warning: 'bi bi-exclamation-triangle-fill',
    error: 'bi bi-x-octagon-fill',
    success: 'bi bi-check-circle-fill',
  };

  function getContainer() {
    var el = document.getElementById('bkToastContainer');
    if (!el) {
      el = document.createElement('div');
      el.id = 'bkToastContainer';
      document.body.appendChild(el);
    }
    return el;
  }

  function dismiss(toast) {
    toast.classList.add('bkToastHiding');
    setTimeout(function () {
      if (toast.parentNode) toast.parentNode.removeChild(toast);
    }, 300);
  }

  function showToast(message, type) {
    type = type && ICONS[type] ? type : 'info';
    var container = getContainer();

    var toast = document.createElement('div');
    toast.className = 'bkToast bkToast--' + type;

    var icon = document.createElement('i');
    icon.className = ICONS[type];
    icon.setAttribute('aria-hidden', 'true');

    var text = document.createElement('span');
    text.className = 'bkToastText';
    text.textContent = message;

    var closeBtn = document.createElement('button');
    closeBtn.className = 'bkToastClose';
    closeBtn.setAttribute('aria-label', '關閉');
    closeBtn.innerHTML = '&times;';
    closeBtn.addEventListener('click', function () {
      dismiss(toast);
    });

    toast.appendChild(icon);
    toast.appendChild(text);
    toast.appendChild(closeBtn);
    container.appendChild(toast);

    var timer = setTimeout(function () {
      dismiss(toast);
    }, 3500);
    toast.addEventListener('mouseenter', function () {
      clearTimeout(timer);
    });
    toast.addEventListener('mouseleave', function () {
      timer = setTimeout(function () {
        dismiss(toast);
      }, 2000);
    });
  }

  window.showToast = showToast;
})();
