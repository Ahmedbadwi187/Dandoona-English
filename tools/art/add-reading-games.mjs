// Adds True or False (to every Explorers lesson with two or more sentences) and Sight Word Hunt (to every lesson with three or more
// sight words), with a spoken instruction for each. Idempotent: run it after the lesson makers and before `audio` / `export`.
//   node tools/art/add-reading-games.mjs
import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const dir = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'content', 'curriculum');
const texts = { 'true-or-false': 'Read the sentence. Does it match the picture?', 'sight-word-hunt': 'Listen. Then tap the word you hear!' };
let changed = 0;
for (const f of readdirSync(dir).filter((n) => n.endsWith('.yaml'))) {
  let t = readFileSync(join(dir, f), 'utf8');
  const crlf = t.includes('\r\n');
  t = t.replace(/\r\n/g, '\n');
  if (!/^track: explorers$/m.test(t)) continue;
  const sentences = (t.match(/^  - \{ text:/gm) || []).length;
  const sight = /^sightWords: \[(.*)\]$/m.exec(t)?.[1].split(',').filter((s) => s.trim()).length ?? 0;
  const add = [];
  if (sentences >= 2) add.push('true-or-false');
  if (sight >= 3) add.push('sight-word-hunt');
  let u = t;
  for (const a of add) {
    if (!new RegExp(`^    ${a}:`, 'm').test(u)) u = u.replace(/^activities:/m, `    ${a}: "${texts[a]}"\nactivities:`);
    u = u.replace(/^activities: \[(.*)\]$/m, (m, list) => (list.split(',').map((s) => s.trim()).includes(a) ? m : `activities: [${list}, ${a}]`));
  }
  if (u !== t) { writeFileSync(join(dir, f), crlf ? u.replace(/\n/g, '\r\n') : u); changed++; }
}
console.log('Reading games added to', changed, 'lessons.');
