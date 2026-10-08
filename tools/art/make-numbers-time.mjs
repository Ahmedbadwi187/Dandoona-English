// Draws the pictures of the Numbers & Time unit (Explorers) in the shared palette, no text, all by arithmetic:
// teens and tens as counted dots and tens-rods, the days of the week and the months as a calendar with the right cell lit,
// and a clock for every o'clock. Run: node tools/art/make-numbers-time.mjs  (writes content/art/explorers/numbers-time-*/<word>.svg)
import { mkdirSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const out = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'content', 'art', 'explorers');
const C = { cream: '#FDF8E6', white: '#FFFFFF', ink: '#5A3A28', tan: '#F3D9AE', orange: '#F0953A', yellow: '#F7CF3E', green: '#7DBE45', teal: '#43B3B0', blue: '#4A90D9', purple: '#8E6BBF', pink: '#F08FA5', red: '#E5524A', gray: '#B8B8B8' };
const svg = (body) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><rect width="512" height="512" fill="${C.cream}" stroke="none"/><g stroke="${C.ink}" stroke-width="7" stroke-linejoin="round" stroke-linecap="round">\n${body}\n</g></svg>\n`;

/** n dots, five to a row (rows alternate two colors), centered. */
function dots(n) {
  const rows = Math.ceil(n / 5), gap = 78, r = 29;
  const top = 256 - ((rows - 1) * gap) / 2;
  let s = '';
  for (let i = 0; i < n; i++) {
    const row = Math.floor(i / 5), inRow = Math.min(5, n - row * 5), col = i % 5;
    const x = 256 - ((inRow - 1) * gap) / 2 + col * gap, y = top + row * gap;
    s += `<circle cx="${x}" cy="${y}" r="${r}" fill="${row % 2 ? C.orange : C.blue}"/>\n`;
  }
  return svg(s);
}

/** k tens-rods (a bar with ten little squares each), side by side. */
function rods(k) {
  const w = Math.min(44, 440 / k - 6), gap = 6, total = k * w + (k - 1) * gap, x0 = 256 - total / 2, cell = 28, top = 256 - 5 * cell;
  let s = '';
  for (let i = 0; i < k; i++) {
    const x = x0 + i * (w + gap);
    let lines = '';
    for (let j = 1; j < 10; j++) lines += `M${x} ${top + j * cell}h${w}`;
    s += `<rect x="${x}" y="${top}" width="${w}" height="${cell * 10}" fill="${i % 2 ? C.teal : C.green}" stroke-width="5"/>
<path d="${lines}" fill="none" stroke-width="3"/>
`;
  }
  return svg(s);
}

/** A calendar page: red top with two rings, and cells in cols x rows; cell `lit` is red, the others cream. */
function calendar(cols, rows, lit) {
  const x0 = 56, y0 = rows === 1 ? 230 : 150, w = 400, h = rows === 1 ? 150 : 300, cw = w / cols, ch = (h - 24) / rows;
  let s = `<rect x="${x0}" y="${y0 - 70}" width="${w}" height="${h + 70}" rx="22" fill="${C.white}"/>\n<path d="M${x0} ${y0 - 70}H${x0 + w}V${y0}H${x0}Z" fill="${C.red}"/>\n`;
  s += `<path d="M${x0 + 110} ${y0 - 96}V${y0 - 52}M${x0 + w - 110} ${y0 - 96}V${y0 - 52}" fill="none" stroke-width="14"/>\n`;
  for (let i = 0; i < cols * rows; i++) {
    const cx = x0 + 12 + (i % cols) * ((w - 24) / cols), cy = y0 + 14 + Math.floor(i / cols) * ch;
    s += `<rect x="${cx + 3}" y="${cy + 3}" width="${(w - 24) / cols - 6}" height="${ch - 6}" rx="10" fill="${i === lit ? C.red : C.tan}" stroke-width="${i === lit ? 7 : 4}"/>\n`;
  }
  return svg(s);
}

/** An analog clock at `hour` o'clock: twelve ticks, the short red hand on the hour, the long hand on 12. */
function clock(hour) {
  let s = `<circle cx="256" cy="256" r="196" fill="${C.white}" stroke-width="14"/>\n<circle cx="256" cy="256" r="196" fill="none" stroke="${C.blue}" stroke-width="8"/>\n`;
  for (let i = 0; i < 12; i++) {
    const a = (i * Math.PI) / 6, big = i % 3 === 0, r1 = big ? 140 : 156, r2 = 172;
    s += `<path d="M${(256 + Math.sin(a) * r1).toFixed(1)} ${(256 - Math.cos(a) * r1).toFixed(1)}L${(256 + Math.sin(a) * r2).toFixed(1)} ${(256 - Math.cos(a) * r2).toFixed(1)}" fill="none" stroke-width="${big ? 12 : 7}"/>\n`;
  }
  const ha = ((hour % 12) * Math.PI) / 6;
  s += `<path d="M256 256L256 98" fill="none" stroke-width="12"/>\n`; // the minute hand on 12
  s += `<path d="M256 256L${(256 + Math.sin(ha) * 100).toFixed(1)} ${(256 - Math.cos(ha) * 100).toFixed(1)}" fill="none" stroke="${C.red}" stroke-width="18"/>\n`;
  s += `<circle cx="256" cy="256" r="16" fill="${C.yellow}"/>`;
  return svg(s);
}

const lessons = {
  'numbers-time-teens-1': { eleven: dots(11), twelve: dots(12), thirteen: dots(13) },
  'numbers-time-teens-2': { fourteen: dots(14), fifteen: dots(15), sixteen: dots(16) },
  'numbers-time-teens-3': { seventeen: dots(17), eighteen: dots(18), nineteen: dots(19) },
  'numbers-time-tens-1': { twenty: rods(2), thirty: rods(3), forty: rods(4) },
  'numbers-time-tens-2': { fifty: rods(5), sixty: rods(6), seventy: rods(7) },
  'numbers-time-tens-3': { eighty: rods(8), ninety: rods(9), hundred: rods(10) },
  'numbers-time-days-1': Object.fromEntries(['monday', 'tuesday', 'wednesday', 'thursday'].map((d, i) => [d, calendar(7, 1, i)])),
  'numbers-time-days-2': Object.fromEntries(['friday', 'saturday', 'sunday'].map((d, i) => [d, calendar(7, 1, i + 4)])),
  'numbers-time-months-1': Object.fromEntries(['january', 'february', 'march', 'april'].map((m, i) => [m, calendar(4, 3, i)])),
  'numbers-time-months-2': Object.fromEntries(['may', 'june', 'july', 'august'].map((m, i) => [m, calendar(4, 3, i + 4)])),
  'numbers-time-months-3': Object.fromEntries(['september', 'october', 'november', 'december'].map((m, i) => [m, calendar(4, 3, i + 8)])),
  'numbers-time-clock-1': { 'one-o-clock': clock(1), 'two-o-clock': clock(2), 'three-o-clock': clock(3) },
  'numbers-time-clock-2': { 'four-o-clock': clock(4), 'five-o-clock': clock(5), 'six-o-clock': clock(6) },
  'numbers-time-clock-3': { 'seven-o-clock': clock(7), 'eight-o-clock': clock(8), 'nine-o-clock': clock(9) },
  'numbers-time-clock-4': { 'ten-o-clock': clock(10), 'eleven-o-clock': clock(11), 'twelve-o-clock': clock(12) },
};

let n = 0;
for (const [lesson, words] of Object.entries(lessons)) {
  mkdirSync(join(out, lesson), { recursive: true });
  for (const [word, body] of Object.entries(words)) {
    writeFileSync(join(out, lesson, `${word}.svg`), body);
    n++;
  }
}
console.log('Drew', n, 'pictures for the Numbers & Time unit.');
