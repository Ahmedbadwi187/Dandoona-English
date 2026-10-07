// Draws the Shapes pictures: one plain, bright shape each (palette colors only, no text). Run: node tools/art/make-shapes.mjs
import { mkdirSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'content', 'art', 'little-learners');
const lessons = { 'shapes-1': ['circle', 'square', 'triangle'], 'shapes-2': ['rectangle', 'oval', 'diamond'], 'shapes-3': ['star', 'heart'] };

const star = (() => {
  const pts = [];
  for (let i = 0; i < 10; i++) {
    const r = i % 2 === 0 ? 190 : 80;
    const a = -Math.PI / 2 + (i * Math.PI) / 5;
    pts.push(`${(256 + r * Math.cos(a)).toFixed(1)},${(268 + r * Math.sin(a)).toFixed(1)}`);
  }
  return pts.join(' ');
})();

// each shape: body, a small white shine
const shapes = {
  circle: ['#F0953A', '<circle cx="256" cy="256" r="180"/>', '<ellipse cx="190" cy="180" rx="30" ry="46" transform="rotate(35 190 180)"/>'],
  square: ['#4A90D9', '<rect x="84" y="84" width="344" height="344" rx="26"/>', '<rect x="122" y="122" width="26" height="90" rx="13"/>'],
  triangle: ['#7DBE45', '<path d="M256 78 L444 424 L68 424 Z" stroke-linejoin="round"/>', '<ellipse cx="222" cy="270" rx="16" ry="48" transform="rotate(28 222 270)"/>'],
  rectangle: ['#E5524A', '<rect x="48" y="132" width="416" height="248" rx="24"/>', '<rect x="82" y="166" width="26" height="86" rx="13"/>'],
  oval: ['#8E6BBF', '<ellipse cx="256" cy="256" rx="206" ry="140"/>', '<ellipse cx="160" cy="206" rx="22" ry="46" transform="rotate(50 160 206)"/>'],
  diamond: ['#43B3B0', '<path d="M256 56 L452 256 L256 456 L60 256 Z" stroke-linejoin="round"/>', '<ellipse cx="190" cy="226" rx="16" ry="50" transform="rotate(45 190 226)"/>'],
  star: ['#F7CF3E', `<polygon points="${star}" stroke-linejoin="round"/>`, '<ellipse cx="222" cy="214" rx="14" ry="42" transform="rotate(35 222 214)"/>'],
  heart: ['#F08FA5', '<path d="M256 436 C60 304 64 150 168 118 C224 102 256 150 256 168 C256 150 288 102 344 118 C448 150 452 304 256 436 Z" stroke-linejoin="round"/>', '<ellipse cx="170" cy="190" rx="18" ry="42" transform="rotate(40 170 190)"/>'],
};

for (const [lesson, names] of Object.entries(lessons)) {
  mkdirSync(join(root, lesson), { recursive: true });
  for (const n of names) {
    const [fill, body, shine] = shapes[n];
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><g stroke="#5A3A28" stroke-width="10" stroke-linecap="round" fill="${fill}">${body}</g><g fill="#FFFFFF" opacity="0.7">${shine}</g></svg>\n`;
    writeFileSync(join(root, lesson, `${n}.svg`), svg);
  }
}
console.log('Wrote', Object.values(lessons).flat().length, 'shape pictures');
