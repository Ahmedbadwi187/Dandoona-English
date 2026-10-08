// Writes the lesson files of Grammar Starters (Explorers): the patterns the child met in the earlier units (a/an, is/are) with new
// examples, and two new ones by picture too (has/have, can). No grammar terms. Run: node tools/art/make-grammar-lessons.mjs
import { writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const dir = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'content', 'curriculum');
// sentence = [text, picture, gap, choices, two?]
const lessons = [
  { key: 'a-an', intro: 'A or an? Listen to the first sound!', words: [['apple', 'little-learners:letter-a/apple'], ['igloo', 'little-learners:letter-i/igloo'], ['umbrella', 'little-learners:letter-u/umbrella'], ['bed', 'little-learners:my-home-1/bed'], ['orange', 'little-learners:letter-o/orange']],
    sentences: [['I see an apple.', 'apple', 'an', 'a, an'], ['I see an igloo.', 'igloo', 'an', 'a, an'], ['I have an umbrella.', 'umbrella', 'an', 'a, an'], ['I see a bed.', 'bed', 'a', 'a, an'], ['I have an orange.', 'orange', 'an', 'a, an']] },
  { key: 'is-are', intro: 'One is. Two are! Look at the pictures.', words: [['duck', 'little-learners:letter-d/duck'], ['frog', 'little-learners:letter-f/frog'], ['fish', 'little-learners:letter-f/fish']],
    sentences: [['The duck is big.', 'duck', 'is', 'is, are'], ['The ducks are big.', 'duck', 'are', 'is, are', true], ['The frog is wet.', 'frog', 'is', 'is, are'], ['The frogs are wet.', 'frog', 'are', 'is, are', true], ['The fish is red.', 'fish', 'is', 'is, are'], ['The fish are red.', 'fish', 'are', 'is, are', true]] },
  { key: 'has-have', intro: 'One has. Two have! Look at the pictures.', words: [['hen', 'sound-builders-e/hen'], ['pig', 'little-learners:letter-p/pig'], ['cat', 'little-learners:letter-c/cat']],
    sentences: [['The hen has an egg.', 'hen', 'has', 'has, have'], ['The hens have eggs.', 'hen', 'have', 'has, have', true], ['The pig has a wig.', 'pig', 'has', 'has, have'], ['The pigs have wigs.', 'pig', 'have', 'has, have', true], ['The cat has a hat.', 'cat', 'has', 'has, have'], ['The cats have hats.', 'cat', 'have', 'has, have', true]] },
  { key: 'can', intro: 'What can you do? I can jump. I can clap. I can run. I can sit!', words: [['jump', 'little-learners:actions-1/jump'], ['clap', 'little-learners:actions-1/clap'], ['run', 'little-learners:actions-2/run'], ['sit', 'little-learners:actions-3/sit']],
    sentences: [['I can jump.', 'jump', 'can', 'can, has, is'], ['I can clap.', 'clap', 'can', 'can, has, is'], ['I can run.', 'run', 'can', 'can, has, is'], ['I can sit.', 'sit', 'can', 'can, has, is']] },
];
lessons.forEach((l, i) => {
  const id = `grammar-starters-${l.key}`;
  const out = ['# Grammar Starters: patterns met by picture, never named. The word to choose is the one that fits the picture.', `id: ${id}`, 'unit: grammar-starters', 'track: explorers', 'level: a1', `order: ${i + 1}`, 'words:'];
  for (const [w, ref] of l.words) out.push(`  - { word: ${w}, reuse: "${ref}" }`);
  out.push('sentences:');
  for (const [text, picture, gap, choices, two] of l.sentences) out.push(`  - { text: "${text}", picture: ${picture}${two ? ', two: true' : ''}, gap: ${gap}, choices: [${choices}] }`);
  out.push('narration:', `  intro: "${l.intro}"`, '  praise: ["Great reading!", "You read it!", "Super!"]', '  instructions:',
    '    fill-the-gap: "Read. Then tap the word that fits!"', '    sentence-builder: "Listen. Then put the words in order!"', '    read-and-pick: "Read the word. Then tap its picture!"',
    'activities: [fill-the-gap, sentence-builder, read-and-pick]');
  writeFileSync(join(dir, `${id}.yaml`), out.join('\n') + '\n');
});
console.log('Wrote', lessons.length, 'Grammar Starters lessons.');
