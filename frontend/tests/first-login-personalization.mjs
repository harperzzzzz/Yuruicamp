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

assert(authSource.includes('isNewCustomer: data.created === true'));
assert.match(authSource, /user\.isNewCustomer\s*&&\s*options\.openSurvey !== false/);
assert(authSource.includes("localStorage.setItem('preferences', 'null')"));
assert(modalSource.includes('member-center.html?onboarding=profile'));
assert(stateSource.includes("readJson('preferences', null)"));
assert(memberSource.includes("onboarding === 'profile'"));
assert(memberSource.includes("switchPanel('profile')"));
assert(!/id="profileEmail"[^>]*readonly/.test(memberPartial));
assert(!/id="profileBirthday"[^>]*readonly/.test(memberPartial));
assert(memberSource.includes('birthdayInput.max = minimumAdultBirthday()'));
assert(memberSource.includes("showMemberFieldError('profileBirthday', '會員年齡必須滿 18 歲')"));
assert(memberSource.includes("'加入日期：' + registeredDate(state.user.registeredAt)"));
assert(authSource.includes('registeredAt: data.registeredAt || null'));

console.log('First-login personalization checks passed');
