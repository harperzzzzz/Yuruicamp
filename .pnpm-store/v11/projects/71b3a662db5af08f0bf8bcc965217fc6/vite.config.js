import { defineConfig } from 'vite';

/**
 * Defines every static HTML page plus the SCSS entry that Vite should process.
 * Main store pages live under storefront/pages/ after B1 layout.
 */
export default defineConfig({
  appType: 'mpa',
  css: {
    devSourcemap: true,
  },
  build: {
    assetsInlineLimit: 4096,
    rollupOptions: {
      input: {
        index: 'index.html',
        home: 'storefront/pages/home.html',
        products: 'storefront/pages/products.html',
        productDetail: 'storefront/pages/product-detail.html',
        checkout: 'storefront/pages/checkout.html',
        checkoutSuccess: 'storefront/pages/checkout-success.html',
        bookingSuccess: 'booking/pages/booking-success.html',
        memberCenter: 'storefront/pages/member-center.html',
        blog: 'storefront/pages/blog.html',
        blogDetail: 'storefront/pages/blog-detail.html',
        branches: 'storefront/pages/branches.html',
        faq: 'storefront/pages/faq.html',
        privacy: 'storefront/pages/privacy.html',
        terms: 'storefront/pages/terms.html',
        styles: 'src/styles.js',
      },
    },
  },
});
