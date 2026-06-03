// ========================================
// Yuruicamp 應用入口
// ========================================
// 此文件初始化應用並設置全局事件監聽器

// 用來記錄「全局組件是否已被初始化」的旗標
// Guard flag: prevent double-initialization when page JS already called init functions
window._appComponentsInitialized = false;

/**
 * 應用初始化函數（被各頁面 JS 呼叫，或由 main.js 自行呼叫）
 * App init function - called by page JS or by main.js itself
 *
 * 若頁面 JS（如 home.js、product-list.js）已自行初始化過，
 * 這裡只補跑「全局事件監聽」，不重複跑 navbar/modal/cart。
 */
window.initApp = () => {
  console.log('========================================');
  console.log('🎪 Yuruicamp 應用初始化');
  console.log('========================================');

  // 全局事件監聽（online/offline/beforeunload）始終需要設定
  window.initGlobalListeners();

  // 若頁面 JS 尚未初始化全局組件，在此補上
  // If page JS hasn't initialized global components yet, do it now
  if (!window._appComponentsInitialized) {
    window.initNavbar();
    window.initModalListeners();
    window.initCartListeners();
    window.initPersonalizationModal();
    window._appComponentsInitialized = true;
  }

  // 第 14 階段：初始化 Lazy Loading Fallback
  // Stage 14: Initialize lazy loading fallback for older browsers
  window.initLazyLoadingFallback();

  // 第 13 階段：offcanvas 開啟時鎖住 body 捲動（iOS Safari 需要）
  // Stage 13: Lock body scroll when offcanvas is open (required for iOS Safari)
  window.initBodyScrollLock();

  console.log('✓ 應用初始化完成');
  console.log('AppState:', window.AppState);
};

/**
 * 初始化全局事件監聽器
 */
window.initGlobalListeners = () => {
  // 在線/離線狀態監測
  window.addEventListener('online', () => {
    console.log('應用已連接到網絡');
    window.showToast('已連接到網絡', 'success');
  });
  
  window.addEventListener('offline', () => {
    console.log('應用已斷開網絡連接');
    window.showToast('網絡已斷開', 'warning');
  });
  
  // 記錄頁面卸載
  window.addEventListener('beforeunload', () => {
    window.saveAppState();
  });
  
  // 性能監測（使用 PerformanceObserver 更精確）
  // Performance monitoring using PerformanceObserver
  window.addEventListener('load', () => {
    // 基本計算方式（舊版）
    const perfData = window.performance.timing;
    const pageLoadTime = perfData.loadEventEnd - perfData.navigationStart;
    console.log(`⏱️ 頁面加載時間: ${pageLoadTime}ms`);

    // 現代 API：LCP（最大內容繪製）監測
    // Largest Contentful Paint monitoring (modern browsers only)
    if ('PerformanceObserver' in window) {
      try {
        const lcpObserver = new PerformanceObserver((entryList) => {
          const entries = entryList.getEntries();
          const lastEntry = entries[entries.length - 1];
          console.log(`🎨 LCP（最大內容繪製）: ${lastEntry.startTime.toFixed(0)}ms`);
        });
        lcpObserver.observe({ type: 'largest-contentful-paint', buffered: true });
      } catch (e) {
        // LCP 不支援時靜默跳過 / Silently ignore if LCP not supported
      }
    }

    // 頁面加載時間警告（超過 3 秒提醒）
    // Warn if page takes over 3 seconds to load
    if (pageLoadTime > 3000) {
      console.warn(`⚠️ 頁面加載超過 3 秒（${pageLoadTime}ms），建議優化資源`);
    }
  });
};

/**
 * 第 14 階段：Lazy Loading Fallback
 * 為不支援原生 loading="lazy" 的舊版瀏覽器提供後備方案
 * Lazy loading fallback for browsers that don't support native lazy loading
 *
 * 運作原理：
 * 1. 偵測瀏覽器是否支援原生 lazy loading
 * 2. 若不支援，使用 IntersectionObserver 模擬相同效果
 * 3. 圖片進入視窗時，才從 data-src 載入真實圖片
 */
window.initLazyLoadingFallback = () => {
  // 若瀏覽器原生支援 lazy loading，直接返回
  // If native lazy loading is supported, no fallback needed
  if ('loading' in HTMLImageElement.prototype) {
    console.log('✓ 瀏覽器支援原生圖片 Lazy Loading');
    return;
  }

  // 舊版瀏覽器：使用 IntersectionObserver 模擬 lazy loading
  // Fallback: Use IntersectionObserver to simulate lazy loading
  console.log('⚠️ 使用 IntersectionObserver Lazy Loading Fallback');

  if (!('IntersectionObserver' in window)) {
    // 更舊的瀏覽器：直接載入所有圖片
    // Very old browsers: just load all images immediately
    document.querySelectorAll('img[data-src]').forEach(img => {
      img.src = img.dataset.src;
    });
    return;
  }

  const lazyObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const img = entry.target;
        if (img.dataset.src) {
          img.src = img.dataset.src;
          img.removeAttribute('data-src');
          lazyObserver.unobserve(img); // 載入後停止觀察
        }
      }
    });
  }, {
    // 提前 200px 開始載入，使用者滾動前圖片已就緒
    // Start loading 200px before image enters viewport
    rootMargin: '200px 0px',
    threshold: 0,
  });

  // 觀察所有有 data-src 屬性的圖片
  document.querySelectorAll('img[data-src]').forEach(img => {
    lazyObserver.observe(img);
  });
};

/**
 * 第 13 階段：Body Scroll Lock（鎖定 body 捲動）
 * 當 Offcanvas 或 Modal 開啟時，防止背景頁面繼續捲動
 * 特別是 iOS Safari 需要 position: fixed 才有效
 *
 * Body scroll lock for offcanvas/modal open state
 * iOS Safari requires position:fixed to truly prevent background scroll
 */
window.initBodyScrollLock = () => {
  let scrollY = 0; // 記錄捲動位置，關閉時還原

  // 觀察 body 是否有 offcanvas-open class
  // Watch for offcanvas-open class on body
  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      if (mutation.type === 'attributes' && mutation.attributeName === 'class') {
        const isOpen = document.body.classList.contains('offcanvas-open');
        if (isOpen) {
          // 記住目前捲動位置，套用固定
          // Remember scroll position and fix body
          scrollY = window.scrollY;
          document.body.style.top = `-${scrollY}px`;
        } else {
          // 還原捲動位置
          // Restore scroll position
          document.body.style.top = '';
          window.scrollTo(0, scrollY);
        }
      }
    });
  });

  observer.observe(document.body, { attributes: true, attributeFilter: ['class'] });
};

/**
 * 應用啟動入口
 * 等待 DOM 完全加載後執行
 */
if (document.readyState === 'loading') {
  // DOM 仍在加載中
  document.addEventListener('DOMContentLoaded', window.initApp);
} else {
  // DOM 已加載完成
  window.initApp();
}

console.log('✓ Main.js 已加載');
