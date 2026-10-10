// Builds content/generated/explorers-audio-review.html: ONE page to listen through, sorted by risk.
//   node tools/verify-audio/make_review_page.mjs
// Needs (run first): uv run tools/verify-audio/verify_explorers.py   and   uv run tools/verify-audio/verify_phonemes.py
// 1. EVERY phoneme clip (33), the Sound Builders sounds first, then the ones the recogniser doubts, then the rest: all are on the owner's listening list.
// 2. Every other Explorers clip, riskiest first (what the checker heard is next to what it should say). Ticks are kept in this browser.
import fs from 'node:fs';
import path from 'node:path';

const gen = path.resolve('content/generated');
const read = (f, d = []) => (fs.existsSync(path.join(gen, f)) ? JSON.parse(fs.readFileSync(path.join(gen, f), 'utf8')) : d);
const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

// the graphemes the Sound Builders lessons use (their sounds come first: they are the first thing a 6-year-old hears)
const cur = path.resolve('content/curriculum');
const sb = new Set();
for (const f of fs.readdirSync(cur).filter((x) => x.startsWith('sound-builders-') && x.endsWith('.yaml'))) {
  for (const m of fs.readFileSync(path.join(cur, f), 'utf8').matchAll(/graphemes:\s*\[([^\]]*)\]/g)) {
    for (const g of m[1].split(',')) sb.add(g.trim().replace(/^"|"$/g, '').split(':')[0]);
  }
}

const phon = read('verify-phonemes.json');
const phRows = phon
  .map((p) => {
    const flagged = !String(p.verdict).startsWith('ok');
    return { ...p, sb: sb.has(p.key), flagged };
  })
  .sort((a, b) => Number(b.sb) - Number(a.sb) || Number(b.flagged) - Number(a.flagged) || a.key.localeCompare(b.key));

const clips = read('verify-explorers.json');
const phonemeNote = 'The checker hears sustained sounds (m, n, s, f, z, sh) as silence and short vowels roughly: its verdict is only a hint. Your ear decides.';

const player = (rel) => `<audio controls preload="none" src="${esc(rel)}"></audio>`;
const tick = (id) => `<input type="checkbox" data-id="${esc(id)}" title="heard it: fine">`;

const phHtml = phRows
  .map((p) => {
    const override = fs.existsSync(path.join(gen, 'explorers/phonemes/audio', `phoneme-${p.key}.override.mp3`));
    const file = override ? `phoneme-${p.key}.override.mp3` : p.file;
    return `<tr class="${p.flagged ? 'flag' : ''}"><td>${tick('ph-' + p.key)}</td><td><b>${esc(p.key)}</b> ${p.sb ? '<span class="sb">Sound Builders</span>' : ''}</td><td>/${esc(p.ipa)}/</td><td>voice reads "${esc(p.voice_reads ?? '')}"</td><td>${esc(p.verdict)}</td><td>${player('explorers/phonemes/audio/' + file)}</td></tr>`;
  })
  .join('');

const risky = clips.filter((c) => c.risk >= 0.2);
const rest = clips.filter((c) => c.risk < 0.2);
const row = (c) => `<tr class="${c.risk >= 0.5 ? 'flag' : ''}"><td>${tick(c.file)}</td><td>${c.risk.toFixed(2)}</td><td>${esc(c.expected)}</td><td>${esc(c.heard)}</td><td>${esc(c.lesson)} / ${esc(c.role)}</td><td>${player('explorers/' + c.file)}</td></tr>`;

const html = `<!doctype html><meta charset="utf-8"><title>Explorers audio review</title>
<style>body{font:16px system-ui;margin:24px;max-width:1200px}table{border-collapse:collapse;width:100%}td,th{border-bottom:1px solid #ddd;padding:6px 8px;text-align:left;vertical-align:middle}audio{height:34px;width:260px}h2{margin-top:36px}.flag td{background:#fff4e5}.sb{background:#e9dcff;border-radius:8px;padding:1px 8px;font-size:12px}.note{color:#555}</style>
<h1>Explorers audio review</h1>
<p class="note">${phRows.length} sounds + ${clips.length} clips heard by Whisper and a phoneme recogniser on this PC. Nothing was sent anywhere. Tick what you have heard and found fine.</p>
<h2>1. Every sound (${phRows.length}), the Sound Builders ones first</h2>
<p class="note">${phonemeNote} If one is wrong: change its <code>say</code> in <code>content/curriculum/units/explorers.yaml</code> and run <code>audio --track explorers</code>, or save your own recording as <code>phoneme-&lt;key&gt;.override.mp3</code> next to it.</p>
<table><tr><th></th><th>Sound</th><th>IPA</th><th>Reads</th><th>Checker</th><th>Play</th></tr>${phHtml}</table>
<h2>2. Words, sentences and lines, riskiest first (${risky.length} with risk of 0.20 or more)</h2>
<p class="note">Risk 0 = Whisper heard exactly the text; 1 = nothing like it. Digits, "o'clock", "sun/son" and similar are not counted as mistakes.</p>
<table><tr><th></th><th>Risk</th><th>Should say</th><th>Heard</th><th>Where</th><th>Play</th></tr>${risky.map(row).join('')}</table>
<details><summary>The other ${rest.length} clips (low risk)</summary><table>${rest.map(row).join('')}</table></details>
<script>
for (const box of document.querySelectorAll('input[type=checkbox]')) {
  const k = 'explorers-review:' + box.dataset.id;
  try { box.checked = localStorage.getItem(k) === '1'; } catch (e) {}
  box.addEventListener('change', () => { try { localStorage.setItem(k, box.checked ? '1' : '0'); } catch (e) {} });
}
</script>`;
fs.writeFileSync(path.join(gen, 'explorers-audio-review.html'), html);
console.log('explorers-audio-review.html:', phRows.length, 'sounds,', risky.length, 'risky clips,', rest.length, 'others;', [...sb].join(' '));
