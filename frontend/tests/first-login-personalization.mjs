import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const rootDir = dirname(dirname(fileURLToPath(import.meta.url)));
const authSource = readFileSync(join(rootDir, 'storefront/js/components/auth.js'), 'utf8');
const modalSource = readFileSync(join(rootDir, 'storefront/js/components/modal.js'), 'utf8');
const stateSource = readFileSync(join(rootDir, 'storefront/js/state.js'), 'utf8');
const memberSource = readFileSync(join(rootDir, 'storefront/js/components/member-center.js'), 'utf8');
const memberPartial = readFileSync(join(rootDir, 'components/member-center.partial'), 'utf8');
const headerPartial = readFileSync(join(rootDir, 'components/header.partial'), 'utf8');
const headerSource = readFileSync(join(rootDir, 'storefront/js/components/header.js'), 'utf8');
const bookingHeaderSource = readFileSync(join(rootDir, 'booking/js/booking-header.js'), 'utf8');
const bookingMemberPage = readFileSync(join(rootDir, 'booking/pages/member-center.html'), 'utf8');
const storefrontMemberPage = readFileSync(join(rootDir, 'storefront/pages/member-center.html'), 'utf8');

function preferenceValues(source, selectorClass) {
  return Array.from(
    source.matchAll(new RegExp(`class="${selectorClass}"[^>]*data-value="([^"]+)"`, 'g')),
    (match) => match[1]
  ).sort();
}

assert(authSource.includes('isNewCustomer: data.created === true'));
assert.match(authSource, /user\.isNewCustomer\s*&&\s*options\.openSurvey !== false/);
assert(authSource.includes("localStorage.setItem('preferences', 'null')"));
assert(modalSource.includes('member-center.html?onboarding=profile'));
assert.match(modalSource, /\[data-survey-close-confirm\][\s\S]*?redirectToMemberProfile\(\)/);
assert(stateSource.includes("readJson('preferences', null)"));
assert(memberSource.includes("onboarding === 'profile'"));
assert(memberSource.includes("switchPanel('profile')"));
assert(memberSource.includes("openModal('profileOnboardingOverlay')"));
assert.deepEqual(
  preferenceValues(headerPartial, 'surveyTag'),
  preferenceValues(memberPartial, 'memberPreferenceTag')
);
assert(modalSource.includes('window.syncPersonalizationPreferenceTags = function'));
assert(modalSource.includes('window.syncPersonalizationPreferenceTags(readStoredPreferences())'));
assert(memberSource.includes('window.syncPersonalizationPreferenceTags?.(obj)'));
assert(memberSource.includes("new CustomEvent('yurui:preferences-updated', { detail: obj })"));
assert(memberPartial.includes('id="profileOnboardingOverlay"'));
assert(memberPartial.includes('id="profileOnboardingClose"'));
assert(memberPartial.includes('id="profileOnboardingAcknowledge"'));
assert(memberPartial.includes('請填寫會員姓名、電話、地址完成後可以讓您的購物體驗更加愉快!!'));
assert(!/id="profileEmail"[^>]*readonly/.test(memberPartial));
assert(!/id="profileBirthday"[^>]*readonly/.test(memberPartial));
assert(bookingMemberPage.includes('lockGoogleEmail: true'));
assert(storefrontMemberPage.includes('lockGoogleEmail: true'));
assert(memberSource.includes('function isGoogleProfileEmailLocked()'));
assert(memberSource.includes('emailInput.readOnly = locked'));
assert(memberSource.includes("provider === 'google' || provider === 'google.com'"));
assert(memberSource.includes('if (!isGoogleProfileEmailLocked()) profileUpdates.email = s.email'));
assert(memberSource.includes('birthdayInput.max = minimumAdultBirthday()'));
assert(memberSource.includes("showMemberFieldError('profileBirthday', '會員年齡必須滿 18 歲')"));
assert(memberSource.includes("'加入日期：' + registeredDate(state.user.registeredAt)"));
assert(authSource.includes('registeredAt: data.registeredAt || null'));
assert(memberSource.includes('function syncProfileDisplayName(name)'));
assert(memberSource.includes("var name = state.user.name || s.name || 'Yurui Camper'"));
assert(memberSource.includes("new CustomEvent('yurui:profile-updated'"));
assert(memberSource.includes('syncProfileDisplayName(s.name)'));
assert(memberSource.includes("showMemberFieldError('profileName', '請填寫姓名')"));
assert(
  headerSource.includes("window.addEventListener('yurui:profile-updated', window.updateNavbarLoginState)")
);
assert(bookingHeaderSource.includes("window.addEventListener('yurui:profile-updated', checkLoginState)"));

console.log('First-login personalization checks passed');
