// Draws the pictures of the later units that are simple flat things: clothes, two toys, the things in a home, three opposites and
// the vehicles. Palette colors only, no text (the generator's SVG test enforces both). Run: node tools/art/make-things.mjs
import { mkdirSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'content', 'art', 'little-learners');
const C = { red: '#E5524A', orange: '#F0953A', yellow: '#F7CF3E', green: '#7DBE45', dgreen: '#4C9A3C', teal: '#43B3B0', blue: '#4A90D9', purple: '#8E6BBF', pink: '#F08FA5', brown: '#B8733F', tan: '#F3D9AE', white: '#FFFFFF', gray: '#B8B8B8', black: '#2B2B2B', cream: '#FDF8E6' };
const shine = (x, y, rx, ry, rot = 0) => `<ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" transform="rotate(${rot} ${x} ${y})" fill="#FFFFFF" stroke="none" opacity="0.5"/>`;
const wheel = (x, y, r = 40) => `<circle cx="${x}" cy="${y}" r="${r}" fill="${C.black}"/><circle cx="${x}" cy="${y}" r="${r * 0.45}" fill="${C.gray}" stroke-width="5"/>`;

// lesson folder -> word -> inner svg
const art = {
  'clothes-1': {
    shirt: `<path d="M150 110 L210 84 Q256 130 302 84 L362 110 L442 190 L386 246 L350 214 L350 440 L162 440 L162 214 L126 246 L70 190 Z" fill="${C.blue}"/>
<path d="M210 84 Q256 130 302 84" fill="none"/><circle cx="296" cy="260" r="24" fill="${C.yellow}"/>${shine(196, 190, 12, 52, 8)}`,
    pants: `<path d="M150 70 L362 70 L384 452 L288 452 L256 200 L224 452 L128 452 Z" fill="${C.purple}"/>
<rect x="150" y="70" width="212" height="40" fill="${C.yellow}"/><circle cx="256" cy="90" r="12" fill="${C.white}" stroke-width="5"/><path d="M256 110 L256 200" fill="none" stroke-width="6"/>${shine(186, 250, 12, 70, 4)}`,
    dress: `<path d="M196 70 L224 70 L256 112 L288 70 L316 70 L332 176 L424 452 L88 452 L180 176 Z" fill="${C.pink}"/>
<path d="M180 176 L332 176 L330 204 L182 204 Z" fill="${C.red}"/><circle cx="256" cy="330" r="16" fill="${C.white}" stroke-width="5"/><circle cx="206" cy="390" r="12" fill="${C.white}" stroke-width="5"/><circle cx="306" cy="386" r="12" fill="${C.white}" stroke-width="5"/>${shine(214, 270, 12, 44, 8)}`,
  },
  'clothes-2': {
    socks: [0, 1].map((i) => `<g transform="translate(${i ? 178 : -78} ${i ? 109 : 79}) scale(0.68)"><path d="M150 60 L290 60 L290 270 Q290 320 350 342 Q430 366 420 420 Q410 462 340 462 L240 462 Q160 462 150 390 Z" fill="${i ? C.blue : C.orange}"/>
<rect x="150" y="60" width="140" height="56" fill="${C.white}"/><path d="M150 150 L290 150 M150 190 L290 190" fill="none" stroke="${C.white}" stroke-width="12"/></g>`).join(''),
    shoes: `<path d="M84 300 Q84 240 150 236 L236 236 L236 156 Q236 124 276 130 Q338 144 358 204 Q374 252 436 268 Q474 278 474 330 L474 384 L84 384 Z" fill="${C.red}"/>
<path d="M84 384 L474 384 L474 410 Q474 438 444 438 L114 438 Q84 438 84 410 Z" fill="${C.white}"/>
<path d="M254 176 L300 190 M262 214 L316 228 M276 250 L332 262" fill="none" stroke="${C.white}" stroke-width="10"/>${shine(140, 290, 20, 12, -10)}`,
  },
  'clothes-3': {
    jacket: `<path d="M148 100 L212 72 L256 124 L300 72 L364 100 L450 188 L450 384 L380 384 L380 442 L132 442 L132 384 L62 384 L62 188 Z" fill="${C.orange}"/>
<path d="M256 124 L256 442" fill="none"/><path d="M212 72 L256 124 L300 72" fill="${C.red}"/><circle cx="256" cy="200" r="9" fill="${C.yellow}" stroke-width="4"/><circle cx="256" cy="280" r="9" fill="${C.yellow}" stroke-width="4"/><circle cx="256" cy="360" r="9" fill="${C.yellow}" stroke-width="4"/>
<path d="M152 330 L214 330 L214 380 L152 380 Z M298 330 L360 330 L360 380 L298 380 Z" fill="none" stroke-width="6"/>${shine(190, 210, 12, 50, 8)}`,
    scarf: `<path d="M96 168 Q256 30 416 168 L388 232 Q256 120 124 232 Z" fill="${C.red}"/>
<path d="M300 190 L396 214 L432 440 L336 460 Z" fill="${C.red}"/>
<path d="M134 190 Q256 94 378 190 M318 270 L414 292 M326 330 L422 352" fill="none" stroke="${C.white}" stroke-width="12" opacity="0.9"/>
<path d="M342 460 L338 486 M366 456 L362 482 M390 452 L386 478 M414 448 L410 474" fill="none" stroke-width="8"/>`,
    gloves: [0, 1].map((i) => `<g transform="translate(${i ? 208 : -32} ${i ? 29 : -1}) scale(0.74)"><path d="M150 440 L150 230 Q150 110 240 110 Q330 110 330 230 L330 440 Z" fill="${i ? C.orange : C.purple}"/>
<path d="M150 300 Q74 280 84 344 Q96 392 150 366" fill="${i ? C.orange : C.purple}"/><rect x="140" y="396" width="200" height="66" rx="12" fill="${C.white}"/>
<path d="M220 150 L220 240 M270 150 L270 240" fill="none" stroke-width="6" opacity="0.4"/></g>`).join(''),
  },
  'toys-3': {
    blocks: `<rect x="70" y="300" width="150" height="150" rx="10" fill="${C.red}"/><rect x="236" y="300" width="150" height="150" rx="10" fill="${C.blue}"/><rect x="152" y="140" width="150" height="150" rx="10" fill="${C.yellow}"/>
<circle cx="145" cy="375" r="36" fill="${C.white}"/><path d="M311 330 L361 420 L261 420 Z" fill="${C.white}"/><path d="M227 168 L238 196 L268 198 L244 216 L252 246 L227 230 L202 246 L210 216 L186 198 L216 196 Z" fill="${C.orange}" stroke-width="5"/>`,
    drum: `<path d="M100 190 L100 390 Q256 468 412 390 L412 190 Z" fill="${C.red}"/><ellipse cx="256" cy="190" rx="156" ry="52" fill="${C.white}"/>
<path d="M118 220 L158 380 L206 250 L256 420 L306 250 L354 380 L394 220" fill="none" stroke="${C.yellow}" stroke-width="12"/>
<path d="M120 100 L270 170 M392 100 L242 170" fill="none" stroke="${C.brown}" stroke-width="14"/><circle cx="118" cy="94" r="20" fill="${C.tan}"/><circle cx="396" cy="94" r="20" fill="${C.tan}"/>`,
  },
  'my-home-1': {
    bed: `<rect x="56" y="140" width="44" height="300" rx="10" fill="${C.brown}"/><rect x="412" y="250" width="44" height="190" rx="10" fill="${C.brown}"/>
<rect x="96" y="290" width="320" height="76" rx="12" fill="${C.blue}"/><rect x="96" y="260" width="320" height="42" rx="12" fill="${C.white}"/><ellipse cx="170" cy="258" rx="62" ry="30" fill="${C.pink}"/>
<path d="M96 366 L416 366 M240 292 L240 366 M330 292 L330 366" fill="none" stroke-width="6" opacity="0.5"/>${shine(140, 250, 22, 8, -10)}`,
    door: `<rect x="132" y="50" width="248" height="400" rx="16" fill="${C.brown}"/><rect x="164" y="84" width="184" height="150" rx="10" fill="${C.orange}" stroke-width="6"/><rect x="164" y="262" width="184" height="150" rx="10" fill="${C.orange}" stroke-width="6"/>
<circle cx="330" cy="256" r="22" fill="${C.yellow}"/>${shine(150, 150, 8, 60)}`,
  },
  'my-home-2': {
    lamp: `<path d="M170 80 L342 80 L396 270 L116 270 Z" fill="${C.yellow}"/><rect x="238" y="270" width="36" height="130" fill="${C.gray}"/><ellipse cx="256" cy="418" rx="100" ry="30" fill="${C.blue}"/>
<path d="M60 150 L100 170 M452 150 L412 170 M256 24 L256 54" fill="none" stroke="#FFC93C" stroke-width="12"/>${shine(200, 140, 10, 46, 14)}`,
    table: `<rect x="62" y="190" width="388" height="54" rx="14" fill="${C.brown}"/><rect x="104" y="244" width="40" height="200" rx="8" fill="${C.brown}"/><rect x="368" y="244" width="40" height="200" rx="8" fill="${C.brown}"/>
<path d="M84 216 L420 216" fill="none" stroke="${C.tan}" stroke-width="8"/><ellipse cx="256" cy="168" rx="52" ry="14" fill="${C.white}"/><path d="M204 168 Q206 110 256 108 Q306 110 308 168" fill="${C.pink}"/>`,
    chair: `<rect x="168" y="50" width="176" height="170" rx="16" fill="${C.orange}"/><path d="M212 74 L212 200 M256 74 L256 200 M300 74 L300 200" fill="none" stroke-width="7" opacity="0.5"/>
<rect x="140" y="214" width="232" height="52" rx="14" fill="${C.red}"/><rect x="156" y="266" width="38" height="190" rx="8" fill="${C.orange}"/><rect x="318" y="266" width="38" height="190" rx="8" fill="${C.orange}"/>`,
  },
  'my-home-3': {
    sofa: `<rect x="96" y="120" width="320" height="170" rx="40" fill="${C.teal}"/><rect x="52" y="210" width="96" height="200" rx="40" fill="${C.teal}"/><rect x="364" y="210" width="96" height="200" rx="40" fill="${C.teal}"/>
<rect x="132" y="250" width="248" height="130" rx="26" fill="${C.green}"/><path d="M256 252 L256 378" fill="none" stroke-width="6" opacity="0.5"/><rect x="92" y="410" width="30" height="40" rx="8" fill="${C.brown}"/><rect x="390" y="410" width="30" height="40" rx="8" fill="${C.brown}"/>${shine(180, 168, 40, 10, -4)}`,
  },
  'opposites-2': {
    up: `<path d="M256 50 L440 250 L330 250 L330 450 L182 450 L182 250 L72 250 Z" fill="${C.green}"/>${shine(214, 300, 14, 60, 4)}`,
    down: `<path d="M256 462 L72 262 L182 262 L182 62 L330 62 L330 262 L440 262 Z" fill="${C.orange}"/>${shine(214, 160, 14, 60, 4)}`,
    slow: `<path d="M96 330 Q96 150 256 150 Q416 150 416 330 Z" fill="${C.green}"/>
<path d="M176 330 L196 220 Q226 160 256 160 M336 330 L316 220 Q286 160 256 160 M256 160 L256 330 M146 280 L366 280" fill="none" stroke="${C.dgreen}" stroke-width="10"/>
<ellipse cx="438" cy="300" rx="50" ry="40" fill="${C.dgreen}"/><circle cx="454" cy="288" r="9" fill="${C.black}" stroke="none"/><path d="M450 316 Q462 322 474 314" fill="none" stroke-width="5"/>
<rect x="120" y="326" width="56" height="64" rx="22" fill="${C.dgreen}"/><rect x="320" y="326" width="56" height="64" rx="22" fill="${C.dgreen}"/><path d="M96 320 L58 350 L98 352 Z" fill="${C.dgreen}"/>${shine(190, 200, 14, 34, 28)}`,
  },
  'transport-1': {
    bus: `<rect x="40" y="130" width="432" height="250" rx="40" fill="${C.yellow}"/><rect x="72" y="166" width="78" height="72" rx="10" fill="${C.blue}"/><rect x="170" y="166" width="78" height="72" rx="10" fill="${C.blue}"/><rect x="268" y="166" width="78" height="72" rx="10" fill="${C.blue}"/><rect x="366" y="166" width="76" height="130" rx="10" fill="${C.blue}"/>
<path d="M40 290 L472 290" fill="none" stroke="${C.red}" stroke-width="14"/><circle cx="452" cy="330" r="12" fill="${C.white}" stroke-width="5"/>${wheel(140, 390)}${wheel(380, 390)}`,
    train: `<rect x="60" y="210" width="260" height="170" rx="18" fill="${C.red}"/><rect x="320" y="110" width="132" height="270" rx="18" fill="${C.blue}"/><rect x="340" y="136" width="92" height="80" rx="10" fill="${C.cream}"/>
<rect x="100" y="120" width="56" height="96" rx="8" fill="${C.black}"/><ellipse cx="128" cy="112" rx="42" ry="14" fill="${C.black}"/><path d="M60 300 L452 300" fill="none" stroke="${C.yellow}" stroke-width="14"/>
<circle cx="96" cy="64" r="22" fill="${C.white}" stroke="none" opacity="0.8"/><circle cx="140" cy="40" r="16" fill="${C.white}" stroke="none" opacity="0.7"/>${wheel(130, 392, 44)}${wheel(260, 392, 44)}${wheel(392, 392, 44)}`,
  },
  'transport-2': {
    boat: `<path d="M256 50 L256 330 L420 330 Z" fill="${C.white}"/><path d="M236 110 L236 330 L112 330 Z" fill="${C.pink}"/><path d="M256 40 L256 340" fill="none" stroke-width="12"/>
<path d="M70 340 L442 340 L392 424 L120 424 Z" fill="${C.red}"/><path d="M52 454 Q92 430 132 454 Q172 478 212 454 Q252 430 292 454 Q332 478 372 454 Q412 430 452 454" fill="none" stroke="${C.blue}" stroke-width="14"/>`,
    plane: `<path d="M60 262 Q60 214 150 214 L410 214 Q470 214 470 262 Q470 306 410 306 L150 306 Q60 306 60 262 Z" fill="${C.white}"/>
<path d="M200 234 L130 110 L214 110 L300 234 Z" fill="${C.blue}"/><path d="M200 292 L130 416 L214 416 L300 292 Z" fill="${C.blue}"/><path d="M96 232 L52 150 L110 150 L150 232 Z" fill="${C.red}"/>
<circle cx="214" cy="260" r="16" fill="${C.teal}" stroke-width="5"/><circle cx="270" cy="260" r="16" fill="${C.teal}" stroke-width="5"/><circle cx="326" cy="260" r="16" fill="${C.teal}" stroke-width="5"/><path d="M416 224 Q462 230 466 262" fill="none" stroke="${C.blue}" stroke-width="14"/>`,
    bike: `<circle cx="120" cy="340" r="86" fill="none" stroke-width="16"/><circle cx="392" cy="340" r="86" fill="none" stroke-width="16"/><circle cx="120" cy="340" r="12" fill="${C.gray}"/><circle cx="392" cy="340" r="12" fill="${C.gray}"/>
<path d="M120 340 L216 190 L330 190 L392 340 M216 190 L260 340 L330 190 M260 340 L120 340" fill="none" stroke="${C.red}" stroke-width="18"/><path d="M330 190 L320 120 L370 108" fill="none" stroke="${C.black}" stroke-width="14"/><path d="M190 168 L250 168" fill="none" stroke="${C.black}" stroke-width="20"/>`,
  },
  'transport-3': {
    truck: `<rect x="40" y="130" width="290" height="250" rx="16" fill="${C.blue}"/><path d="M330 190 L420 190 Q468 190 468 240 L468 380 L330 380 Z" fill="${C.orange}"/><rect x="352" y="210" width="80" height="70" rx="8" fill="${C.cream}"/>
<path d="M40 300 L330 300" fill="none" stroke="${C.white}" stroke-width="12" opacity="0.8"/>${wheel(130, 392)}${wheel(260, 392)}${wheel(400, 392)}`,
  },
};

let count = 0;
for (const [lesson, words] of Object.entries(art)) {
  mkdirSync(join(root, lesson), { recursive: true });
  for (const [word, inner] of Object.entries(words)) {
    writeFileSync(join(root, lesson, `${word}.svg`), `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><g stroke="#5A3A28" stroke-width="8" stroke-linejoin="round" stroke-linecap="round">${inner}</g></svg>\n`);
    count++;
  }
}
console.log('Wrote', count, 'pictures');
