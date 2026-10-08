// Draws the pictures of the Everyday English unit (Explorers) in the shared palette, no text. Run: node tools/art/make-everyday.mjs
// Written to content/art/explorers/everyday-<topic>/<word>.svg.
import { mkdirSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const out = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'content', 'art', 'explorers');
const C = { cream: '#FDF8E6', white: '#FFFFFF', ink: '#5A3A28', brown: '#B8733F', tan: '#F3D9AE', orange: '#F0953A', yellow: '#F7CF3E', green: '#7DBE45', darkGreen: '#4C9A3C', teal: '#43B3B0', blue: '#4A90D9', purple: '#8E6BBF', pink: '#F08FA5', red: '#E5524A', gray: '#B8B8B8', black: '#2B2B2B', sunflower: '#FFC93C' };
const svg = (body) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><rect width="512" height="512" fill="${C.cream}" stroke="none"/><g stroke="${C.ink}" stroke-width="8" stroke-linejoin="round" stroke-linecap="round">\n${body}\n</g></svg>\n`;

const cloud = (x, y, s, fill) => `<g transform="translate(${x} ${y}) scale(${s})"><path d="M-130 40C-180 40 -190 -30 -130 -40C-130 -100 -50 -120 -10 -70C40 -120 130 -90 120 -20C180 -20 190 40 130 40Z" fill="${fill}"/></g>`;
const drops = (pts) => pts.map(([x, y]) => `<path d="M${x} ${y}c-14 22 -14 36 0 36s14 -14 0 -36z" fill="${C.blue}" stroke-width="5"/>`).join('\n');
const panel = (fill) => `<rect x="40" y="60" width="432" height="392" rx="40" fill="${fill}" stroke-width="6"/>`;

const pictures = {
  'everyday-english-school': {
    pencil: svg(`<g transform="rotate(-35 256 256)"><rect x="110" y="226" width="250" height="60" fill="${C.yellow}"/><path d="M110 226L50 256L110 286Z" fill="${C.tan}"/><path d="M72 244L50 256L72 268Z" fill="${C.ink}" stroke-width="4"/><rect x="360" y="226" width="34" height="60" fill="${C.gray}"/><rect x="394" y="226" width="44" height="60" rx="14" fill="${C.pink}"/><path d="M150 242H345M150 270H345" fill="none" stroke="${C.orange}" stroke-width="5"/></g>`),
    book: svg(`<path d="M120 90H370C390 90 400 100 400 120V400C400 420 390 430 370 430H120C100 430 92 420 92 400V120C92 100 100 90 120 90Z" fill="${C.blue}"/><path d="M92 400C92 420 100 430 120 430H370C390 430 400 420 400 400" fill="none"/><rect x="120" y="116" width="250" height="34" rx="8" fill="${C.cream}" stroke-width="5"/><path d="M130 190H360M130 230H320" fill="none" stroke="${C.white}" stroke-width="12"/><path d="M360 90V160L378 142L396 160V90Z" fill="${C.red}" stroke-width="5"/>`),
    bag: svg(`<path d="M190 120C190 70 322 70 322 120" fill="none" stroke-width="22"/><path d="M130 190C130 140 180 120 256 120C332 120 382 140 382 190V400C382 430 362 440 340 440H172C150 440 130 430 130 400Z" fill="${C.red}"/><rect x="170" y="290" width="172" height="110" rx="20" fill="${C.yellow}"/><path d="M256 290V240M170 330H342" fill="none" stroke-width="6"/><circle cx="256" cy="230" r="14" fill="${C.sunflower}"/><path d="M130 220C100 230 100 330 130 340M382 220C412 230 412 330 382 340" fill="none" stroke-width="16"/>`),
    ruler: svg(`<g transform="rotate(-25 256 256)"><rect x="50" y="206" width="412" height="100" rx="12" fill="${C.sunflower}"/><path d="M90 206V250M130 206V236M170 206V250M210 206V236M250 206V250M290 206V236M330 206V250M370 206V236M410 206V250" fill="none" stroke-width="6"/><circle cx="426" cy="278" r="10" fill="${C.cream}" stroke-width="5"/></g>`),
  },
  'everyday-english-weather-1': {
    sunny: svg(`<circle cx="256" cy="256" r="100" fill="${C.sunflower}"/>${Array.from({ length: 12 }, (_, i) => { const a = (i * Math.PI) / 6; return `<path d="M${(256 + Math.sin(a) * 138).toFixed(1)} ${(256 - Math.cos(a) * 138).toFixed(1)}L${(256 + Math.sin(a) * 190).toFixed(1)} ${(256 - Math.cos(a) * 190).toFixed(1)}" fill="none" stroke="${C.orange}" stroke-width="16"/>`; }).join('\n')}<circle cx="226" cy="236" r="9" fill="${C.ink}"/><circle cx="286" cy="236" r="9" fill="${C.ink}"/><path d="M216 286C240 314 272 314 296 286" fill="none" stroke-width="8"/>`),
    rainy: svg(`${cloud(256, 200, 1.35, C.gray)}\n${drops([[150, 330], [220, 360], [290, 330], [360, 360], [190, 410], [330, 410]])}`),
    cloudy: svg(`${cloud(300, 170, 1.0, C.gray)}\n${cloud(220, 290, 1.5, C.white)}`),
  },
  'everyday-english-weather-2': {
    windy: svg(`<path d="M60 190H300C370 190 380 120 330 110C300 104 280 130 296 150" fill="none" stroke="${C.blue}" stroke-width="18"/><path d="M60 270H380C450 270 460 340 410 350C380 356 360 330 376 310" fill="none" stroke="${C.blue}" stroke-width="18"/><path d="M60 350H240C290 350 300 410 260 416C240 420 226 404 236 390" fill="none" stroke="${C.blue}" stroke-width="18"/><path d="M400 130C440 100 470 130 440 170C410 160 400 150 400 130Z" fill="${C.green}" stroke-width="6"/><path d="M404 134L436 166" fill="none" stroke-width="5"/>`),
    snowy: svg(`${panel(C.blue)}\n${cloud(256, 190, 1.25, C.gray)}\n${[[160, 330], [250, 350], [340, 330], [205, 410], [300, 410], [390, 395], [120, 400]].map(([x, y]) => `<g transform="translate(${x} ${y})"><path d="M0 -22V22M-19 -11L19 11M-19 11L19 -11" fill="none" stroke="${C.white}" stroke-width="7"/></g>`).join('\n')}`),
    stormy: svg(`${panel(C.purple)}\n${cloud(256, 190, 1.25, C.black)}\n<path d="M270 250L210 340H262L236 430L330 320H278L304 250Z" fill="${C.yellow}" stroke-width="7"/>\n${drops([[150, 330], [380, 340], [120, 400], [410, 410]])}`),
  },
  'everyday-english-town': {
    school: svg(`<rect x="90" y="220" width="332" height="200" fill="${C.red}"/><path d="M70 224L256 110L442 224Z" fill="${C.brown}"/><rect x="226" y="320" width="60" height="100" rx="8" fill="${C.tan}"/><rect x="120" y="260" width="60" height="60" fill="${C.cream}" stroke-width="6"/><rect x="332" y="260" width="60" height="60" fill="${C.cream}" stroke-width="6"/><circle cx="256" cy="200" r="22" fill="${C.cream}" stroke-width="6"/><path d="M256 200V186M256 200L266 206M256 110V50" fill="none" stroke-width="6"/><path d="M256 50H310L292 66L310 82H256Z" fill="${C.blue}" stroke-width="5"/>`),
    park: svg(`<path d="M30 400H482" fill="none" stroke="${C.green}" stroke-width="30"/><rect x="226" y="250" width="32" height="150" fill="${C.brown}"/><circle cx="242" cy="190" r="100" fill="${C.green}"/><circle cx="170" cy="230" r="60" fill="${C.darkGreen}"/><circle cx="320" cy="225" r="64" fill="${C.darkGreen}"/><path d="M340 350H460M345 380H455M350 350V420M450 350V420M340 320H462" fill="none" stroke="${C.brown}" stroke-width="14"/>`),
    hospital: svg(`<rect x="100" y="150" width="312" height="280" fill="${C.white}"/><rect x="226" y="340" width="60" height="90" rx="8" fill="${C.tan}"/><rect x="120" y="200" width="56" height="56" fill="${C.cream}" stroke-width="6"/><rect x="336" y="200" width="56" height="56" fill="${C.cream}" stroke-width="6"/><rect x="226" y="170" width="60" height="60" rx="8" fill="${C.red}" stroke-width="6"/><path d="M256 182V218M238 200H274" fill="none" stroke="${C.white}" stroke-width="12"/><path d="M100 150H412" fill="none" stroke="${C.red}" stroke-width="16"/>`),
  },
  'everyday-english-meals': {
    breakfast: svg(`<circle cx="256" cy="270" r="180" fill="${C.white}"/><circle cx="256" cy="270" r="140" fill="none" stroke="${C.tan}" stroke-width="6"/><path d="M180 230C160 190 220 170 250 190C290 165 340 200 320 250C340 290 290 310 250 296C210 316 170 280 180 230Z" fill="${C.white}"/><circle cx="256" cy="240" r="38" fill="${C.sunflower}"/><path d="M300 330L420 330L420 420L300 420Z" fill="${C.tan}" transform="rotate(-8 360 375)"/><path d="M330 350H400" fill="none" stroke="${C.brown}" stroke-width="6"/>`),
    dinner: svg(`<circle cx="256" cy="260" r="160" fill="${C.white}"/><circle cx="256" cy="260" r="120" fill="none" stroke="${C.tan}" stroke-width="6"/><ellipse cx="236" cy="270" rx="70" ry="46" fill="${C.sunflower}"/><circle cx="290" cy="230" r="34" fill="${C.green}"/><circle cx="318" cy="260" r="28" fill="${C.red}"/><path d="M80 120V420M64 120V200M96 120V200" fill="none" stroke-width="12"/><path d="M440 120C470 160 470 260 440 280V420" fill="none" stroke-width="12"/>`),
  },
  'everyday-english-play': {
    football: svg(`<circle cx="256" cy="256" r="190" fill="${C.white}"/><path d="M256 168L322 216L296 292H216L190 216Z" fill="${C.black}"/><path d="M256 168V86M322 216L398 190M296 292L346 360M216 292L166 360M190 216L114 190" fill="none" stroke-width="8"/><path d="M256 86L320 60M398 190L430 250M346 360L290 420M166 360L222 420M114 190L82 250" fill="none" stroke-width="8"/>`),
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
console.log('Drew', n, 'pictures for the Everyday English unit.');
