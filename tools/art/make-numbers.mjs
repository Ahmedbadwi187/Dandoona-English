// Draws the Numbers pictures: n balloons for the number n (1-10). Palette colors only, no text (the generator's SVG test
// enforces both). Run: node tools/art/make-numbers.mjs   -> content/art/little-learners/<lesson>/<word>.svg
import { mkdirSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'content', 'art', 'little-learners');
const colors = ['#E5524A', '#F0953A', '#F7CF3E', '#7DBE45', '#43B3B0', '#4A90D9', '#8E6BBF', '#F08FA5'];
const lessons = { 'number-1-3': ['one', 'two', 'three'], 'number-4-6': ['four', 'five', 'six'], 'number-7-10': ['seven', 'eight', 'nine', 'ten'] };
const words = ['one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten'];

function balloon(cx, cy, s, color) {
  const rx = 38 * s, ry = 46 * s;
  return [
    `<path d="M${cx} ${cy + ry} C${cx - 10 * s} ${cy + ry + 30 * s} ${cx + 12 * s} ${cy + ry + 46 * s} ${cx} ${cy + ry + 76 * s}" fill="none" stroke-width="${4 * s}"/>`,
    `<path d="M${cx - 8 * s} ${cy + ry + 10 * s} L${cx + 8 * s} ${cy + ry + 10 * s} L${cx} ${cy + ry - 2 * s}Z" fill="${color}"/>`,
    `<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" fill="${color}"/>`,
    `<ellipse cx="${cx - 14 * s}" cy="${cy - 16 * s}" rx="${7 * s}" ry="${12 * s}" fill="#FFFFFF" stroke="none" opacity="0.75"/>`,
  ].join('');
}

function picture(n) {
  // up to five in a row; six or more go in two rows
  const rows = n <= 5 ? [n] : [Math.ceil(n / 2), Math.floor(n / 2)];
  const s = n <= 3 ? 1.5 : n <= 5 ? 1.15 : 0.9;
  const gap = 96 * s;
  const rowH = 190 * s;
  const top = 256 - (rows.length * rowH) / 2 + 50 * s;
  let i = 0;
  const parts = [];
  rows.forEach((count, r) => {
    const startX = 256 - ((count - 1) * gap) / 2;
    for (let k = 0; k < count; k++) parts.push(balloon(startX + k * gap + (r % 2) * 14 * s, top + r * rowH, s, colors[i++ % colors.length]));
  });
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><g stroke="#5A3A28" stroke-width="${Math.max(4, 6 * s)}" stroke-linejoin="round" stroke-linecap="round">${parts.join('')}</g></svg>\n`;
}

for (const [lesson, ws] of Object.entries(lessons)) {
  mkdirSync(join(root, lesson), { recursive: true });
  for (const w of ws) writeFileSync(join(root, lesson, `${w}.svg`), picture(words.indexOf(w) + 1));
}
console.log('Wrote', words.length, 'balloon pictures');
