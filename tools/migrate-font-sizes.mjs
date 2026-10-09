// One-off migration: replaces `TextStyle(... fontSize: N ...)` with the named styles of lib/core/type.dart (nearest size).
// Usage: node tools/migrate-font-sizes.mjs <lib dir>
import fs from 'node:fs';
import path from 'node:path';

const KID = [[18, 'kidCaption'], [24, 'kidBody'], [32, 'kidTitle'], [44, 'kidGameWord'], [72, 'kidHero']];
const PARENT = [[13, 'parentCaption'], [16, 'parentBody'], [18, 'parentSubtitle'], [22, 'parentTitle'], [28, 'parentStat']];
const PARENT_DIRS = ['features/parent/', 'features/onboarding/', 'features/sync/', 'features/gate/'];
const SKIP = ['core/type.dart', 'core/theme.dart'];

const nearest = (n, scale) => scale.reduce((b, c) => (Math.abs(c[0] - n) < Math.abs(b[0] - n) ? c : b))[1];

function walk(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => (e.isDirectory() ? walk(path.join(dir, e.name)) : e.name.endsWith('.dart') ? [path.join(dir, e.name)] : []));
}

function splitTop(s) {
  const parts = []; let depth = 0, cur = '', q = null;
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (q) { cur += c; if (c === q && s[i - 1] !== String.fromCharCode(92)) q = null; continue; }
    if (c === "'" || c === '"') { q = c; cur += c; continue; }
    if ('([{'.includes(c)) depth++;
    if (')]}'.includes(c)) depth--;
    if (c === ',' && depth === 0) { parts.push(cur); cur = ''; } else cur += c;
  }
  if (cur.trim()) parts.push(cur);
  return parts;
}

let total = 0;
for (const file of walk(process.argv[2])) {
  const rel = path.relative(process.argv[2], file).split(path.sep).join('/');
  if (SKIP.includes(rel)) continue;
  const scale = PARENT_DIRS.some((d) => rel.startsWith(d)) ? PARENT : KID;
  let s = fs.readFileSync(file, 'utf8');
  let out = '', i = 0, changed = false;
  const re = /(const\s+)?TextStyle\(/g;
  let m;
  while ((m = re.exec(s))) {
    // find the matching paren
    let depth = 1, j = m.index + m[0].length;
    for (; j < s.length && depth > 0; j++) { if (s[j] === '(') depth++; else if (s[j] === ')') depth--; }
    const inner = s.slice(m.index + m[0].length, j - 1);
    const args = splitTop(inner);
    const idx = args.findIndex((a) => /^\s*fontSize:\s*\d+(\.\d+)?\s*$/.test(a));
    if (idx < 0) continue;
    const n = parseFloat(args[idx].split(':')[1]);
    const rest = args.filter((_, k) => k !== idx).map((a) => a.trim()).filter(Boolean);
    const token = nearest(n, scale);
    const repl = rest.length ? `${token}.copyWith(${rest.join(', ')})` : token;
    out += s.slice(i, m.index) + repl;
    i = j;
    re.lastIndex = j;
    changed = true; total++;
  }
  if (!changed) continue;
  out += s.slice(i);
  const imp = `import '${'../'.repeat(rel.split('/').length - 1)}core/type.dart';`;
  if (!out.includes('core/type.dart')) {
    // after the last package/relative import line
    const lines = out.split('\n');
    let last = -1;
    lines.forEach((l, k) => { if (/^import /.test(l)) last = k; });
    lines.splice(last + 1, 0, imp);
    out = lines.join('\n');
  }
  fs.writeFileSync(file, out);
  console.log(rel);
}
console.log('replaced', total);
