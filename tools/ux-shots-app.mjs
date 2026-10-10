// Dev only: after the setup summary (see ux-shots.sh) walks the app and screenshots the child map and the parent pages.
//   node tools/ux-shots-app.mjs <en|ar> <first-number>      (first-number: the next file number, 14 after ux-shots.sh)
import { execFileSync } from 'node:child_process';
const adb = 'C:/src/android-sdk/platform-tools/adb.exe';
const [lang = 'en', start = '14'] = process.argv.slice(2);
const out = `dist/review/ux/${lang}`;
const env = { ...process.env, MSYS_NO_PATHCONV: '1' };
const A = (...a) => execFileSync(adb, a, { encoding: 'utf8', env });
const U = (...a) => execFileSync('node', ['tools/adb-ui.mjs', ...a], { encoding: 'utf8', env });
const sleep = (s) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, s * 1000);
let n = Number(start);
const shot = (name) => U('shot', `${out}/${String(n++).padStart(2, '0')}-${name}.png`);
const labels = () => U('labels').split('\n').map((l) => /^(\d+) (\d+) (.*)$/.exec(l)).filter(Boolean).map((m) => ({ x: +m[1], y: +m[2], label: m[3] }));
const tap = (text, i = 1) => U('tap', text, String(i));
const digits = (s) => s.replace(/[٠-٩]/g, (d) => '٠١٢٣٤٥٦٧٨٩'.indexOf(d));
const has = (text) => labels().some((l) => l.label.includes(text));

U('tapat', '540', '2222'); sleep(4); shot('dandoona-hello');
tap("Let's go"); sleep(4); shot('child-map');
tap('Parent area'); sleep(1.5); shot('parent-gate-hold');
const hold = labels().find((l) => l.label === 'Hold' || l.label === 'اضغط باستمرار') ?? { x: 540, y: 1369 };
A('shell', 'input', 'swipe', '540', String(hold.y - 174), '540', String(hold.y - 174), '2800'); sleep(1);
const q = labels().map((l) => /(\d+)\s*[×x]\s*(\d+)/.exec(digits(l.label))).find(Boolean);
shot('parent-gate-solve');
const answer = Number(q[1]) * Number(q[2]);
const target = labels().find((l) => digits(l.label) === String(answer));
U('tapat', String(target.x), String(target.y)); sleep(2.5); shot('parent-home');
const L = labels();
const open = (names) => { const t = L.find((l) => names.some((s) => l.label.includes(s))); return t; };
// child detail: tap the child's card
const card = L.find((l) => l.label.includes('Yar'));
if (card) { U('tapat', String(card.x), String(card.y)); sleep(2); shot('child-detail'); U('swipe', 'up'); sleep(0.6); shot('child-detail-bottom'); A('shell', 'input', 'keyevent', '4'); sleep(1.2); }
const manage = labels().find((l) => l.y > 2000 && l.label !== 'Child mode' && !l.label.includes('Child mode') && l.label !== 'وضع الطفل');
if (manage) { U('tapat', String(manage.x), String(manage.y)); sleep(1.8); shot('manage-children'); }
const childRow = labels().find((l) => l.label.includes('Yar'));
if (childRow) { U('tapat', String(childRow.x), String(childRow.y)); sleep(2); shot('edit-child-top'); for (let i = 0; i < 4; i++) { U('swipe', 'up'); sleep(0.6); shot(`edit-child-${i + 2}`); } A('shell', 'input', 'keyevent', '4'); sleep(1); }
A('shell', 'input', 'keyevent', '4'); sleep(1.2);
const settings = labels().find((l) => l.x > 900 && l.y < 300);
if (settings) { U('tapat', String(settings.x), String(settings.y)); sleep(1.8); shot('settings-top'); U('swipe', 'up'); sleep(0.6); shot('settings-bottom'); }
const auth = labels().find((l) => l.label.includes('Create account') || l.label.includes('إنشاء حساب'));
if (auth) { U('tapat', String(auth.x), String(auth.y)); sleep(2); shot('sign-in'); }
console.log('last file number', n - 1);
