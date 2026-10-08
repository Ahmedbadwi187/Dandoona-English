// Draws the pictures of the Word Families unit (Explorers) in the shared palette, no text. Run: node tools/art/make-families.mjs
// Each picture is written to content/art/explorers/<lesson>/<word>.svg (a lesson file says `source: svg`).
import { mkdirSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const out = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'content', 'art', 'explorers');
const C = { cream: '#FDF8E6', white: '#FFFFFF', ink: '#5A3A28', brown: '#B8733F', tan: '#F3D9AE', orange: '#F0953A', yellow: '#F7CF3E', green: '#7DBE45', blue: '#4A90D9', purple: '#8E6BBF', pink: '#F08FA5', red: '#E5524A', gray: '#B8B8B8', black: '#2B2B2B', sunflower: '#FFC93C', teal: '#43B3B0' };

const svg = (body) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><rect width="512" height="512" fill="${C.cream}" stroke="none"/><g stroke="${C.ink}" stroke-width="8" stroke-linejoin="round" stroke-linecap="round">\n${body}\n</g></svg>\n`;

const pictures = {
  'word-families-at': {
    rat: svg(`<path d="M340 330C410 330 440 380 400 410" fill="none" stroke-width="10"/>
<ellipse cx="250" cy="320" rx="110" ry="80" fill="${C.gray}"/>
<path d="M150 300C150 240 200 210 250 230C290 245 300 290 296 330Z" fill="${C.gray}"/>
<circle cx="170" cy="236" r="34" fill="${C.pink}"/><circle cx="226" cy="214" r="30" fill="${C.pink}"/>
<path d="M120 320L84 342L128 346Z" fill="${C.pink}"/>
<circle cx="150" cy="320" r="8" fill="${C.ink}"/>
<circle cx="110" cy="330" r="9" fill="${C.pink}"/>
<path d="M126 340L70 330M128 350L72 362" fill="none" stroke-width="5"/>
<path d="M170 396V420M250 396V420" fill="none"/>`),
    bat: svg(`<path d="M102 414L118 426L265 246L374 134L326 96L243 228Z" fill="${C.tan}"/>
<path d="M265 246L374 134" fill="none" stroke="${C.brown}" stroke-width="6"/>
<circle cx="110" cy="420" r="15" fill="${C.brown}"/>
<circle cx="400" cy="390" r="58" fill="${C.white}"/>
<path d="M362 352C384 372 384 408 362 428M438 352C416 372 416 408 438 428" fill="none" stroke="${C.red}" stroke-width="6"/>`),
  },
  'word-families-an': {
    can: svg(`<ellipse cx="256" cy="390" rx="110" ry="34" fill="${C.gray}"/>
<path d="M146 150V390C146 410 360 410 366 390V150Z" fill="${C.gray}"/>
<rect x="146" y="220" width="220" height="110" fill="${C.red}" stroke-width="6"/>
<ellipse cx="256" cy="150" rx="110" ry="34" fill="${C.white}"/>
<ellipse cx="256" cy="150" rx="80" ry="22" fill="${C.gray}" stroke-width="5"/>
<circle cx="256" cy="275" r="26" fill="${C.sunflower}" stroke-width="6"/>`),
    fan: svg(`<path d="M256 420L110 190A190 190 0 0 1 402 190Z" fill="${C.pink}"/>
<path d="M256 420L170 160M256 420L214 150M256 420L256 140M256 420L298 150M256 420L342 160" fill="none" stroke-width="5"/>
<path d="M148 250A170 170 0 0 1 364 250" fill="none" stroke="${C.red}" stroke-width="8"/>
<rect x="238" y="400" width="36" height="60" rx="12" fill="${C.brown}"/>`),
    pan: svg(`<circle cx="210" cy="270" r="140" fill="${C.black}"/>
<circle cx="210" cy="270" r="100" fill="${C.gray}" stroke-width="6"/>
<path d="M330 300L460 350" fill="none" stroke="${C.brown}" stroke-width="34"/>
<path d="M330 300L460 350" fill="none" stroke="${C.tan}" stroke-width="18"/>
<circle cx="190" cy="250" r="40" fill="${C.white}" stroke-width="6"/><circle cx="190" cy="250" r="18" fill="${C.yellow}" stroke-width="5"/>`),
  },
  'word-families-ig': {
    wig: svg(`<rect x="226" y="380" width="60" height="70" fill="${C.tan}"/>
<ellipse cx="256" cy="460" rx="90" ry="22" fill="${C.brown}"/>
<ellipse cx="256" cy="300" rx="92" ry="112" fill="${C.tan}"/>
<circle cx="150" cy="350" r="40" fill="${C.orange}"/><circle cx="362" cy="350" r="40" fill="${C.orange}"/>
<path d="M150 310C126 190 186 110 256 110C326 110 386 190 362 310C350 250 332 214 304 192C274 218 236 218 208 192C180 214 162 250 150 310Z" fill="${C.orange}"/>
<path d="M140 350C140 330 168 330 168 350M344 350C344 330 372 330 372 350M230 150C250 130 280 140 280 160" fill="none" stroke-width="6"/>`),
  },
  'word-families-ot': {
    dot: svg(`<rect x="106" y="86" width="300" height="340" rx="20" fill="${C.white}"/>
<circle cx="256" cy="256" r="90" fill="${C.red}"/>
<path d="M210 220C220 200 240 192 260 196" fill="none" stroke="${C.white}" stroke-width="12"/>`),
  },
  'word-families-ug': {
    jug: svg(`<path d="M170 130H342C382 130 390 180 370 220C410 250 410 400 370 420C340 440 172 440 142 420C102 400 102 250 142 220C122 180 130 130 170 130Z" fill="${C.blue}"/>
<path d="M390 230C450 230 450 360 380 370" fill="none" stroke-width="28"/>
<path d="M390 230C450 230 450 360 380 370" fill="none" stroke="${C.blue}" stroke-width="14"/>
<path d="M170 130C200 160 312 160 342 130" fill="none"/>
<path d="M176 280C176 330 200 370 230 380" fill="none" stroke="${C.white}" stroke-width="14"/>`),
    mug: svg(`<path d="M120 170H340V380C340 410 320 424 296 424H164C140 424 120 410 120 380Z" fill="${C.orange}"/>
<path d="M340 214C420 214 420 336 340 336" fill="none" stroke-width="30"/>
<path d="M340 214C420 214 420 336 340 336" fill="none" stroke="${C.orange}" stroke-width="14"/>
<path d="M160 250H300" fill="none" stroke="${C.cream}" stroke-width="14"/>
<path d="M170 140C150 110 190 90 170 60M240 140C220 110 260 90 240 60M310 140C290 110 330 90 310 60" fill="none" stroke="${C.gray}" stroke-width="8"/>`),
    rug: svg(`<ellipse cx="256" cy="300" rx="190" ry="120" fill="${C.purple}"/>
<ellipse cx="256" cy="300" rx="140" ry="82" fill="${C.pink}" stroke-width="6"/>
<ellipse cx="256" cy="300" rx="90" ry="48" fill="${C.sunflower}" stroke-width="6"/>
<ellipse cx="256" cy="300" rx="40" ry="20" fill="${C.red}" stroke-width="6"/>
<path d="M72 270L40 262M70 300L36 300M72 330L40 340M440 270L472 262M442 300L476 300M440 330L472 340" fill="none" stroke-width="7"/>`),
  },
  'word-families-un': {
    bun: svg(`<path d="M100 330C100 190 190 130 256 130C322 130 412 190 412 330C412 400 372 420 256 420C140 420 100 400 100 330Z" fill="${C.tan}"/>
<path d="M100 330C100 190 190 130 256 130C322 130 412 190 412 330" fill="none" stroke="${C.brown}" stroke-width="8"/>
<path d="M120 340C180 360 332 360 392 340" fill="none" stroke="${C.brown}" stroke-width="6"/>
<path d="M200 220L216 232M260 190L276 206M310 224L324 238M236 262L252 276M170 280L184 292M330 288L344 298" fill="none" stroke="${C.white}" stroke-width="12"/>`),
  },
};

let n = 0;
for (const [lesson, words] of Object.entries(pictures)) {
  mkdirSync(join(out, lesson), { recursive: true });
  for (const [word, body] of Object.entries(words)) {
    writeFileSync(join(out, lesson, `${word}.svg`), body);
    n++;
  }
}
console.log('Drew', n, 'pictures for the Word Families unit.');
