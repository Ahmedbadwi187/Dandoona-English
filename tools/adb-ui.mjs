// Dev only: drives the emulator by what is on the screen (Flutter exposes its labels to uiautomator).
//   node tools/adb-ui.mjs tap "Continue"          taps the first node whose label contains the text (use  tap "text" 2  for the 2nd match)
//   node tools/adb-ui.mjs tapat 540 1200          taps a point
//   node tools/adb-ui.mjs type "Yara"             types into the focused field
//   node tools/adb-ui.mjs swipe up|down           scrolls
//   node tools/adb-ui.mjs shot out.png            screenshot
//   node tools/adb-ui.mjs labels                  lists every label with its center
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const adb = 'C:/src/android-sdk/platform-tools/adb.exe';
const run = (...a) => execFileSync(adb, a, { encoding: 'utf8', env: { ...process.env, MSYS_NO_PATHCONV: '1' }, maxBuffer: 64 * 1024 * 1024 });

function nodes() {
  run('shell', 'uiautomator', 'dump', '/sdcard/ui.xml');
  const tmp = path.join(os.tmpdir(), 'ui.xml');
  run('pull', '/sdcard/ui.xml', tmp);
  const xml = fs.readFileSync(tmp, 'utf8');
  const out = [];
  for (const m of xml.matchAll(/<node [^>]*>/g)) {
    const n = m[0];
    const label = (/content-desc="([^"]*)"/.exec(n)?.[1] || /text="([^"]*)"/.exec(n)?.[1] || '').replace(/&#10;/g, ' ').replace(/&quot;/g, '"').replace(/&amp;/g, '&').replace(/&apos;/g, "'");
    const b = /bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"/.exec(n);
    if (!label || !b) continue;
    const [x1, y1, x2, y2] = b.slice(1).map(Number);
    out.push({ label, x: Math.round((x1 + x2) / 2), y: Math.round((y1 + y2) / 2), x1, y1, x2, y2 });
  }
  return out;
}

const [cmd, a1, a2] = process.argv.slice(2);
if (cmd === 'tap') {
  const hits = nodes().filter((n) => n.label.includes(a1));
  const hit = hits[(Number(a2) || 1) - 1];
  if (!hit) { console.error('not found:', a1); process.exit(2); }
  run('shell', 'input', 'tap', String(hit.x), String(hit.y));
  console.log('tapped', JSON.stringify(hit.label), hit.x, hit.y);
} else if (cmd === 'tapat') {
  run('shell', 'input', 'tap', a1, a2);
} else if (cmd === 'type') {
  run('shell', 'input', 'text', a1.replace(/ /g, '%s'));
} else if (cmd === 'swipe') {
  const up = a1 !== 'down';
  run('shell', 'input', 'swipe', '540', up ? '1700' : '700', '540', up ? '600' : '1700', '350');
} else if (cmd === 'shot') {
  run('shell', 'screencap', '-p', '/sdcard/s.png');
  run('pull', '/sdcard/s.png', a1);
} else if (cmd === 'labels') {
  for (const n of nodes()) console.log(n.x, n.y, n.label);
} else {
  console.error('commands: tap tapat type swipe shot labels');
}
