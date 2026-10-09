// Builds content/generated/listen-check.html: one page with a player for every clip the automatic checks flagged.
//   node tools/verify-audio/make_listen_page.mjs
// Reads verify-words.json, verify-phonemes.json and verify-audio.json (run the three verify scripts first).
import fs from 'node:fs';
import path from 'node:path';

const gen = path.resolve('content/generated');
const read = (f) => (fs.existsSync(path.join(gen, f)) ? JSON.parse(fs.readFileSync(path.join(gen, f), 'utf8')) : []);
const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
const player = (rel) => `<audio controls preload="none" src="${esc(rel.split(path.sep).join('/'))}"></audio>`;

// Whisper writes digits, homophones and spellings that are not mistakes: these differences are not flagged.
const harmless = (r) => /^\d+\.?$/.test(r.heard.trim()) || /o'?clock/i.test(r.heard) || /^(son|b|i|buss|plumb|goats)\.?$/i.test(r.heard.trim());

const words = read('verify-words.json').filter((r) => !r.ok && !harmless(r));
const phonemes = read('verify-phonemes.json').filter((r) => !String(r.verdict).startsWith('ok'));
const letters = read('verify-audio.json').filter((l) => (l.checks || []).some((c) => !c.ok));

const rows = [];
for (const w of words) {
  rows.push(`<tr><td>${esc(w.expected)}</td><td>heard "${esc(w.heard)}"</td><td>${esc(w.track)}/${esc(w.lesson)}</td><td>${player(`${w.track}/${w.lesson}/audio/${w.file}`)}</td></tr>`);
}
const prow = phonemes.map((p) => `<tr><td><b>${esc(p.key)}</b> /${esc(p.ipa)}/ (voice reads "${esc(p.voice_reads)}")</td><td>${esc(p.verdict)}</td><td></td><td>${player(`explorers/phonemes/audio/${p.file}`)}</td></tr>`);
const lrow = letters.map((l) => `<tr><td>${esc(l.lesson)} (${esc(l.letter)})</td><td>${esc(l.checks.filter((c) => !c.ok).map((c) => c.name + ': ' + c.detail).join('; '))}</td><td></td><td>${player(path.relative(gen, path.resolve(l.file)))}</td></tr>`);

const table = (title, body, note) => `<h2>${title}</h2><p>${note}</p><table><tr><th>Should say</th><th>What the checker heard</th><th>Where</th><th>Play</th></tr>${body.join('')}</table>`;
const html = `<!doctype html><meta charset="utf-8"><title>Listen check</title>
<style>body{font:16px system-ui;margin:24px;max-width:1100px}table{border-collapse:collapse;width:100%}td,th{border-bottom:1px solid #ddd;padding:6px 8px;text-align:left}audio{height:34px}h2{margin-top:32px}</style>
<h1>Clips to listen to</h1>
<p>The automatic checker (Whisper and a phoneme recogniser, both run on this PC) cannot judge accent or an isolated sound. It listed these as different from what they should be. Your ears decide.</p>
${table('Letter intros (' + lrow.length + ')', lrow, 'The four-part intro of the letter: "This is the letter X", the sound twice, the word.')}
${table('Explorers sounds (' + prow.length + ' of 32)', prow, 'Each sound on its own. The recogniser hears sustained sounds (m, n, s, f, z, sh) as silence, so those are not wrong by themselves.')}
${table('Words (' + rows.length + ')', rows, 'Words whose transcription differs from the word (digits, "sun/son", "bee/B" and similar are left out).')}`;
fs.writeFileSync(path.join(gen, 'listen-check.html'), html);
console.log('listen-check.html:', lrow.length, 'letters,', prow.length, 'sounds,', rows.length, 'words');
