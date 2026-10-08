// Writes the lesson files of the Numbers & Time unit (Explorers). Run: node tools/art/make-numbers-time-lessons.mjs
// A word is [word, intro bit, `say` (what the voice reads, optional)]; the picture of each is drawn by make-numbers-time.mjs.
import { writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const dir = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'content', 'curriculum');
const cap = (w) => w[0].toUpperCase() + w.slice(1);
const lessons = [
  ['teens-1', 'Count more! Eleven. Twelve. Thirteen!', ['eleven', 'twelve', 'thirteen']],
  ['teens-2', 'Count more! Fourteen. Fifteen. Sixteen!', ['fourteen', 'fifteen', 'sixteen']],
  ['teens-3', 'Count more! Seventeen. Eighteen. Nineteen!', ['seventeen', 'eighteen', 'nineteen']],
  ['tens-1', 'Count by tens! Twenty. Thirty. Forty!', ['twenty', 'thirty', 'forty']],
  ['tens-2', 'Count by tens! Fifty. Sixty. Seventy!', ['fifty', 'sixty', 'seventy']],
  ['tens-3', 'Count by tens! Eighty. Ninety. One hundred!', [['eighty'], ['ninety'], ['hundred', 'one hundred']]],
  ['days-1', 'The days of the week! Monday. Tuesday. Wednesday. Thursday!', ['Monday', 'Tuesday', 'Wednesday', 'Thursday']],
  ['days-2', 'More days! Friday. Saturday. Sunday!', ['Friday', 'Saturday', 'Sunday']],
  ['months-1', 'The months of the year! January. February. March. April!', ['January', 'February', 'March', 'April']],
  ['months-2', 'More months! May. June. July. August!', ['May', 'June', 'July', 'August']],
  ['months-3', 'The last months! September. October. November. December!', ['September', 'October', 'November', 'December']],
  ['clock-1', "What time is it? One o'clock. Two o'clock. Three o'clock!", ["one o'clock", "two o'clock", "three o'clock"]],
  ['clock-2', "What time is it? Four o'clock. Five o'clock. Six o'clock!", ["four o'clock", "five o'clock", "six o'clock"]],
  ['clock-3', "What time is it? Seven o'clock. Eight o'clock. Nine o'clock!", ["seven o'clock", "eight o'clock", "nine o'clock"]],
  ['clock-4', "What time is it? Ten o'clock. Eleven o'clock. Twelve o'clock!", ["ten o'clock", "eleven o'clock", "twelve o'clock"]],
];
lessons.forEach(([key, intro, words], i) => {
  const id = `numbers-time-${key}`;
  const lines = ['# Numbers & Time: numbers to 100, the days, the months and the clock. Each picture shows the number, the day or the time.', `id: ${id}`, 'unit: numbers-time', 'track: explorers', 'level: a1', `order: ${i + 1}`, 'noArticle: true', 'words:'];
  for (const w of words) {
    const [word, say] = Array.isArray(w) ? w : [w];
    lines.push(`  - { word: ${word.includes("'") ? `"${word}"` : word}, source: svg, imagePrompt: "${word}"${say ? `, say: "${say}"` : ''} }`);
  }
  lines.push('narration:', `  intro: "${intro}"`, '  praise: ["Great job!", "You know it!", "Super!"]', '  instructions:',
    '    listen-and-tap: "Listen, then tap the picture!"',
    '    match-picture: "Match each word to its picture!"',
    '    memory: "Find the matching cards!"',
    '    read-and-pick: "Read the word. Then tap its picture!"',
    'activities: [listen-and-tap, read-and-pick, match-picture, memory]');
  writeFileSync(join(dir, `${id}.yaml`), lines.join('\n') + '\n');
});
console.log('Wrote', lessons.length, 'Numbers & Time lessons.');
