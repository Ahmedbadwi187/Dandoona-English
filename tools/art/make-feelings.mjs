// Draws the Feelings pictures: six round faces, one per feeling (palette colors only, no text). Run: node tools/art/make-feelings.mjs
import { mkdirSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'content', 'art', 'little-learners');
const lessons = { 'feelings-1': ['happy', 'sad', 'angry'], 'feelings-2': ['sleepy', 'scared', 'surprised'] };
const ink = '#5A3A28';
const eye = (x, y, rx = 17, ry = 24) => `<ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" fill="#2B2B2B" stroke="none"/><circle cx="${x - 5}" cy="${y - 9}" r="6" fill="#FFFFFF" stroke="none"/>`;
const cheeks = '<circle cx="118" cy="318" r="30" fill="#F08FA5" stroke="none" opacity="0.6"/><circle cx="394" cy="318" r="30" fill="#F08FA5" stroke="none" opacity="0.6"/>';
const shine = '<ellipse cx="150" cy="140" rx="30" ry="50" transform="rotate(35 150 140)" fill="#FFFFFF" stroke="none" opacity="0.35"/>';

const faces = {
  happy: ['#F7CF3E', eye(190, 230) + eye(322, 230) + '<path d="M170 316 Q256 420 342 316 Z" fill="#E5524A" stroke-width="8"/><path d="M206 350 Q256 384 306 350 Q256 362 206 350 Z" fill="#F08FA5" stroke="none"/>' + cheeks],
  sad: ['#4A90D9', eye(190, 236) + eye(322, 236) + '<path d="M150 188 Q186 164 222 190 M290 190 Q326 164 362 188" fill="none" stroke-width="9"/><path d="M190 372 Q256 318 322 372" fill="none" stroke-width="10"/><path d="M158 292 Q140 328 158 344 Q176 328 158 292 Z" fill="#FFFFFF" stroke-width="5"/>'],
  angry: ['#E5524A', '<path d="M142 178 L228 214 M370 178 L284 214" fill="none" stroke-width="14"/>' + eye(194, 252, 15, 20) + eye(318, 252, 15, 20) + '<path d="M180 384 Q256 328 332 384" fill="none" stroke-width="10"/><path d="M256 96 L246 132 L266 132 Z" fill="#FFC93C" stroke="none"/>'],
  sleepy: ['#8E6BBF', '<path d="M154 240 Q190 270 226 240 M286 240 Q322 270 358 240" fill="none" stroke-width="10"/><ellipse cx="256" cy="360" rx="26" ry="34" fill="#2B2B2B" stroke-width="6"/><circle cx="368" cy="372" r="22" fill="#FFFFFF" stroke-width="5"/><circle cx="398" cy="338" r="14" fill="#FFFFFF" stroke-width="4"/><circle cx="420" cy="314" r="8" fill="#FFFFFF" stroke-width="3"/>' + cheeks],
  scared: ['#43B3B0', '<circle cx="190" cy="232" r="42" fill="#FFFFFF" stroke-width="7"/><circle cx="322" cy="232" r="42" fill="#FFFFFF" stroke-width="7"/><circle cx="196" cy="240" r="12" fill="#2B2B2B" stroke="none"/><circle cx="316" cy="240" r="12" fill="#2B2B2B" stroke="none"/><path d="M150 168 Q190 140 228 164 M284 164 Q322 140 362 168" fill="none" stroke-width="9"/><path d="M186 376 Q206 350 226 376 Q246 402 266 376 Q286 350 306 376 Q326 402 332 372" fill="none" stroke-width="9"/><path d="M420 190 Q400 226 420 244 Q440 226 420 190 Z" fill="#FFFFFF" stroke-width="5"/>'],
  surprised: ['#F0953A', '<path d="M146 176 Q190 140 232 172 M280 172 Q322 140 366 176" fill="none" stroke-width="9"/>' + eye(190, 244, 19, 28) + eye(322, 244, 19, 28) + '<ellipse cx="256" cy="372" rx="38" ry="48" fill="#2B2B2B" stroke-width="8"/><ellipse cx="256" cy="392" rx="22" ry="18" fill="#E5524A" stroke="none"/>' + cheeks],
};

for (const [lesson, names] of Object.entries(lessons)) {
  mkdirSync(join(root, lesson), { recursive: true });
  for (const n of names) {
    const [fill, inner] = faces[n];
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><g stroke="${ink}" stroke-width="8" stroke-linejoin="round" stroke-linecap="round"><circle cx="256" cy="262" r="206" fill="${fill}"/>${shine}${inner}</g></svg>\n`;
    writeFileSync(join(root, lesson, `${n}.svg`), svg);
  }
}
console.log('Wrote', Object.values(lessons).flat().length, 'faces');
