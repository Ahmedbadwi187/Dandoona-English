// Writes the six lesson files of the Word Families unit (Explorers). Run: node tools/art/make-family-lessons.mjs
// A word is [word, graphemes, how]: how = "svg" (drawn by make-families.mjs) or the reuse reference of an existing picture.
import { writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const dir = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'content', 'curriculum');

const prompts = { rat: 'a small gray rat', bat: 'a baseball bat and ball', can: 'a tin can', fan: 'a pink folding hand fan', pan: 'a frying pan with an egg', wig: 'a wig on a stand', dot: 'a red dot on paper', jug: 'a blue jug', mug: 'an orange mug', rug: 'a round colorful rug', bun: 'a bread bun' };

const families = [
  ['at', 'Family -at: cat, hat, rat, bat. They all end the same!', [['cat', 'c a t', 'little-learners:letter-c/cat'], ['hat', 'h a t', 'little-learners:letter-h/hat'], ['rat', 'r a t', 'svg'], ['bat', 'b a t', 'svg']]],
  ['an', 'Family -an: van, can, fan, pan. They all end the same!', [['van', 'v a n', 'little-learners:letter-v/van'], ['can', 'c a n', 'svg'], ['fan', 'f a n', 'svg'], ['pan', 'p a n', 'svg']]],
  ['ig', 'Family -ig: pig, wig, fig. They all end the same!', [['pig', 'p i g', 'little-learners:letter-p/pig'], ['wig', 'w i g', 'svg'], ['fig', 'f i g', 'sound-builders-i/fig']]],
  ['ot', 'Family -ot: pot, dot, hot. They all end the same!', [['pot', 'p o t', 'sound-builders-o/pot'], ['dot', 'd o t', 'svg'], ['hot', 'h o t', 'little-learners:letter-s/sun']]],
  ['ug', 'Family -ug: bug, jug, mug, rug. They all end the same!', [['bug', 'b u g', 'sound-builders-u/bug'], ['jug', 'j u g', 'svg'], ['mug', 'm u g', 'svg'], ['rug', 'r u g', 'svg']]],
  ['un', 'Family -un: sun, bun, run. They all end the same!', [['sun', 's u n', 'little-learners:letter-s/sun'], ['bun', 'b u n', 'svg'], ['run', 'r u n', 'little-learners:actions-2/run']]],
];

families.forEach(([ending, intro, words], i) => {
  const id = `word-families-${ending}`;
  const lines = ['# Word Families: words that end the same sound alike. Everyday words (animals, food, school, home).', `id: ${id}`, 'unit: word-families', 'track: explorers', 'level: a1', `order: ${i + 1}`, 'words:'];
  for (const [w, g, how] of words) {
    const graphemes = `[${g.split(' ').join(', ')}]`;
    lines.push(how === 'svg' ? `  - { word: ${w}, graphemes: ${graphemes}, source: svg, imagePrompt: "${prompts[w]}" }` : `  - { word: ${w}, graphemes: ${graphemes}, reuse: "${how}" }`);
  }
  lines.push('narration:', `  intro: "${intro}"`, '  praise: ["Great reading!", "You spelled it!", "Super!"]', '  instructions:',
    '    sound-tap: "Tap each box to hear its sound. Then read the word!"',
    '    word-builder: "Listen. Then tap the letters to build the word!"',
    '    spell-it: "Listen. Then spell the word with the letters!"',
    '    read-and-pick: "Read the word. Then tap its picture!"',
    'activities: [sound-tap, word-builder, spell-it, read-and-pick]');
  writeFileSync(join(dir, `${id}.yaml`), lines.join('\n') + '\n');
});
console.log('Wrote', families.length, 'Word Families lessons.');
