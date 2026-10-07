// Draws the My Body pictures: six body parts (palette colors only, no text). Run: node tools/art/make-body.mjs
import { mkdirSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'content', 'art', 'little-learners');
const lessons = { 'my-body-1': ['eye', 'ear', 'nose'], 'my-body-2': ['mouth', 'hand', 'foot'] };
const skin = '#F3D9AE', skinDark = '#F0953A';
const shine = (x, y, rx, ry, rot = 0) => `<ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" transform="rotate(${rot} ${x} ${y})" fill="#FFFFFF" stroke="none" opacity="0.55"/>`;

const parts = {
  eye: `<path d="M44 262 Q256 78 468 262 Q256 446 44 262 Z" fill="#FFFFFF"/>
<circle cx="256" cy="262" r="108" fill="#4A90D9"/><circle cx="256" cy="262" r="70" fill="#2E1F47" stroke="none"/>
<circle cx="218" cy="224" r="26" fill="#FFFFFF" stroke="none"/><circle cx="288" cy="296" r="12" fill="#FFFFFF" stroke="none"/>
<path d="M92 214 L66 170 M160 168 L146 112 M256 148 L256 90 M352 168 L366 112 M420 214 L446 170" fill="none" stroke-width="12"/>`,
  ear: `<path d="M300 70 C180 52 110 140 128 250 C140 330 188 372 214 412 C236 450 300 452 330 410 C372 352 420 308 410 214 C400 124 360 78 300 70 Z" fill="${skin}"/>
<path d="M290 130 C226 118 190 178 204 250 C214 304 252 322 262 352" fill="none" stroke-width="12"/>
<path d="M300 190 C268 182 254 216 266 246 C274 270 290 280 292 300" fill="none" stroke-width="10"/>
${shine(190, 170, 16, 46, 20)}`,
  nose: `<path d="M256 70 C300 70 318 200 346 290 C382 306 410 340 396 392 C380 444 300 452 256 424 C212 452 132 444 116 392 C102 340 130 306 166 290 C194 200 212 70 256 70 Z" fill="${skin}"/>
<ellipse cx="204" cy="388" rx="26" ry="34" fill="${skinDark}" transform="rotate(14 204 388)"/><ellipse cx="308" cy="388" rx="26" ry="34" fill="${skinDark}" transform="rotate(-14 308 388)"/>
${shine(228, 170, 14, 60, 8)}`,
  mouth: `<path d="M56 236 C110 184 196 196 256 226 C316 196 402 184 456 236 C420 372 320 440 256 440 C192 440 92 372 56 236 Z" fill="#E5524A"/>
<path d="M92 252 C150 238 210 250 256 268 C302 250 362 238 420 252 C396 330 330 372 256 372 C182 372 116 330 92 252 Z" fill="#FFFFFF" stroke-width="6"/>
<path d="M256 268 L256 372 M174 256 L186 366 M338 256 L326 366" fill="none" stroke-width="5"/>
<path d="M170 420 C200 372 312 372 342 420 C310 446 202 446 170 420 Z" fill="#F08FA5" stroke="none"/>`,
  hand: `<rect x="168" y="150" width="46" height="130" rx="23" fill="${skin}"/><rect x="218" y="104" width="48" height="176" rx="24" fill="${skin}"/><rect x="270" y="82" width="50" height="198" rx="25" fill="${skin}"/><rect x="324" y="108" width="48" height="172" rx="24" fill="${skin}"/>
<rect x="392" y="236" width="48" height="132" rx="24" fill="${skin}" transform="rotate(38 416 302)"/>
<rect x="150" y="230" width="244" height="232" rx="84" fill="${skin}"/>
<rect x="176" y="236" width="190" height="60" fill="${skin}" stroke="none"/>
<path d="M226 300 Q256 330 286 300" fill="none" stroke-width="7" opacity="0.4"/>
${shine(196, 350, 12, 52, 8)}`,
  foot: `<circle cx="338" cy="196" r="44" fill="${skin}"/><circle cx="270" cy="168" r="35" fill="${skin}"/><circle cx="206" cy="184" r="30" fill="${skin}"/><circle cx="160" cy="218" r="26" fill="${skin}"/><circle cx="132" cy="262" r="22" fill="${skin}"/>
<path d="M256 478 C168 478 146 404 166 330 C180 290 190 262 178 236 L340 226 C350 270 376 306 376 362 C376 432 334 478 256 478 Z" fill="${skin}"/>
<path d="M186 214 L352 206 L352 244 L172 252 Z" fill="${skin}" stroke="none"/>
${shine(206, 340, 14, 56, 10)}`,
};

for (const [lesson, names] of Object.entries(lessons)) {
  mkdirSync(join(root, lesson), { recursive: true });
  for (const n of names) {
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><g stroke="#5A3A28" stroke-width="9" stroke-linejoin="round" stroke-linecap="round">${parts[n]}</g></svg>\n`;
    writeFileSync(join(root, lesson, `${n}.svg`), svg);
  }
}
console.log('Wrote', Object.values(lessons).flat().length, 'body parts');
