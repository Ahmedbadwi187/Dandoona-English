// Dev only: writes a full-progress state into the debug app's SharedPreferences on the emulator, so every late screen
// (certificates, chests, reviews, the castle) can be looked at without playing 80 lessons.
//   node tools/seed-device-progress.mjs [childName]     (the child must exist; the app is stopped, the file replaced, the app is left stopped)
// Uses `adb` (C:\src\android-sdk) and run-as, so it only works with a debug build.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const adb = 'C:/src/android-sdk/platform-tools/adb.exe';
const pkg = 'com.dandoona.kids_english_app';
const sh = (...a) => execFileSync(adb, a, { encoding: 'utf8', env: { ...process.env, MSYS_NO_PATHCONV: '1' } });
const xmlPath = 'shared_prefs/FlutterSharedPreferences.xml';

const xml = sh('shell', `run-as ${pkg} cat ${xmlPath}`);
const unesc = (s) => s.replace(/&quot;/g, '"').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>');
const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const entries = {};
for (const m of xml.matchAll(/<string name="([^"]+)">([\s\S]*?)<\/string>/g)) entries[m[1]] = unesc(m[2]);

const children = JSON.parse(entries['flutter.children.v1']);
const name = process.argv[2];
const child = name ? children.find((c) => c.name === name) : children[0];
if (!child) throw new Error('child not found');

const dir = path.resolve('content/curriculum');
const records = [];
let n = 0;
for (const f of fs.readdirSync(dir).filter((x) => x.endsWith('.yaml')).sort()) {
  const text = fs.readFileSync(path.join(dir, f), 'utf8');
  const track = /^track:\s*(\S+)/m.exec(text)?.[1];
  const lesson = f.replace('.yaml', '');
  const wanted = child.track === 'explorers' ? track === 'explorers' || lesson.startsWith('letter-') : track === 'little-learners';
  if (!wanted) continue;
  const acts = /^activities:\s*\[(.*)\]/m.exec(text)?.[1].split(',').map((s) => s.trim()).filter(Boolean) ?? [];
  for (const a of acts) {
    n++;
    records.push({
      clientRecordId: `seed-${child.id}-${n}`,
      childId: child.id,
      lessonId: lesson,
      activity: a,
      stars: n % 7 === 0 ? 2 : 3,
      attempts: 4,
      timeSpentSeconds: 40,
      completedAt: new Date(Date.UTC(2026, 8, 1 + (n % 28), 9, n % 60)).toISOString(),
    });
  }
}
entries['flutter.progress.v1'] = JSON.stringify(records);
if (process.env.FINISH) {
  // every certificate, story and review done; the chests stay closed so the opening can be looked at
  const units = child.track === 'explorers'
    ? ['letters', 'sound-builders', 'digraphs', 'blends', 'magic-e', 'vowel-teams', 'sight-words-1', 'sight-words-2', 'my-sentences', 'word-families', 'everyday-english', 'numbers-time', 'grammar-starters']
    : [];
  const certificates = Object.fromEntries(units.map((u) => [u, '2026-10-01']));
  entries['flutter.meta.v2'] = JSON.stringify({ schema: 2, children: { [child.id]: { certificates, celebrated: units, reviews: ['review-1', 'review-2', 'review-3', 'review-4'], stories: units } } });
} else {
  delete entries['flutter.meta.v2']; // rebuilt from the progress on the next start (certificates and so on)
}
entries['flutter.settings.v1'] = JSON.stringify({ ...JSON.parse(entries['flutter.settings.v1']), sessionMinutes: 60, ...(process.env.APP_LANG ? { languageCode: process.env.APP_LANG } : {}) });

const out = `<?xml version='1.0' encoding='utf-8' standalone='yes' ?>\n<map>\n${Object.entries(entries).map(([k, v]) => `    <string name="${k}">${esc(v)}</string>`).join('\n')}\n</map>\n`;
const tmp = path.join(os.tmpdir(), 'FlutterSharedPreferences.xml');
fs.writeFileSync(tmp, out);
sh('shell', `am force-stop ${pkg}`);
sh('push', tmp, '/data/local/tmp/FlutterSharedPreferences.xml');
sh('shell', `run-as ${pkg} cp /data/local/tmp/FlutterSharedPreferences.xml ${xmlPath}`);
console.log(`${records.length} progress records written for ${child.name} (${child.track})`);
