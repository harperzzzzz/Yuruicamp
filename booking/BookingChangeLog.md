# Booking Change Log

## Changed

### Booking CSS semantic convergence

- Consolidated booking page and component selectors around camelCase semantic names.
- Replaced generic flow selectors such as `.step`, `.breadcrumb`, `.tag`, and `.priceSummary` with booking-specific selectors.
- Standardized UI state classes toward `.isOpen`, `.isVisible`, `.isSelected`, `.isDisabled`, `.isCompleted`, `.isInvalid`, and `.isSuccess`.
- Moved reusable layout rules into the ITCSS objects layer and kept page SCSS focused on page-specific composition.

### Booking token convergence

- Set `--yc-*` as the source token family for booking SCSS.
- Replaced page and component `--bk-*` usage with equivalent `--yc-*` tokens.
- Moved external brand and floating contact colors into `--yc-brand-*` and `--yc-floating-line-*` tokens.
- Removed unused `--color-*` compatibility aliases from booking settings.
- Kept `--yui-*` as the shared-widget bridge and `--bk-*` as deprecated compatibility aliases only.

### Booking runtime selector cleanup

- Added booking semantic classes to shared auth modal markup after partial injection without changing modal IDs.
- Replaced booking auth modal CSS selectors with `.bookingAuth*` selectors.
- Added `.bookingToastContainer` to the dynamically created toast container and moved toast CSS off the ID selector.
- Replaced the booking header mount style with `.bookingHeaderMount` while preserving `#bookingHeader` as the layout injection hook.
- Removed the booking modal bridge that imported main-site `.modalContent` styles into booking CSS.
- Replaced generic checkout summary selectors with `.bookingSummaryRow`, `.bookingCostRow`, and `.bookingNoRental`.
- Replaced generic checkout payment selectors with `.bookingPaymentOption*`.
- Preserved existing IDs as JavaScript hooks and accessibility references.

### Shared widget token cleanup

- Replaced shared header and footer hardcoded white foreground styles with `--yui-surface`.
- Replaced booking transparent white page styles with `color-mix()` based on `--yc-on-dark`.

## Validation

- Run `npx.cmd sass booking/css/booking-main.scss booking/css/booking-main.css --no-source-map` after SCSS changes.
- Run `npm.cmd run stylelint`, `npm.cmd run build`, and `git diff --check -- booking`.
- Run `node --check` for touched booking JavaScript files.
