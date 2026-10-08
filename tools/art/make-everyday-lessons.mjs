// Writes the lesson files of the Everyday English unit (Explorers). Run: node tools/art/make-everyday-lessons.mjs
// A word is [word, how]: "svg" (drawn by make-everyday.mjs), or the reuse reference of an existing picture; `say` helps the voice.
import { writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const dir = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'content', 'curriculum');
const lessons = [
  { key: 'school', intro: 'At school! A pencil. A book. A bag. A ruler!', noArticle: false, words: [['pencil', 'svg'], ['book', 'svg'], ['bag', 'svg'], ['ruler', 'svg']],
    sentences: [['I have a pencil.', 'pencil'], ['I see a book.', 'book'], ['I have a bag.', 'bag'], ['I see a ruler.', 'ruler']] },
  { key: 'weather-1', intro: 'The weather! Sunny. Rainy. Cloudy!', noArticle: true, words: [['sunny', 'svg'], ['rainy', 'svg'], ['cloudy', 'svg']],
    sentences: [['It is sunny.', 'sunny'], ['It is rainy.', 'rainy'], ['It is cloudy.', 'cloudy']] },
  { key: 'weather-2', intro: 'More weather! Windy. Snowy. Stormy!', noArticle: true, words: [['windy', 'svg'], ['snowy', 'svg'], ['stormy', 'svg']],
    sentences: [['It is windy.', 'windy'], ['It is snowy.', 'snowy'], ['It is stormy.', 'stormy']] },
  { key: 'town', intro: 'In town! A school. A park. A hospital. A shop!', noArticle: false, words: [['school', 'svg'], ['park', 'svg'], ['hospital', 'svg'], ['shop', 'digraphs-sh/shop']],
    sentences: [['I go to school.', 'school'], ['I go to the park.', 'park'], ['I go to the hospital.', 'hospital'], ['I see the shop.', 'shop']] },
  { key: 'meals', intro: 'Meals! Breakfast. Lunch. Dinner!', noArticle: true, words: [['breakfast', 'svg'], ['lunch', 'digraphs-ch/lunch'], ['dinner', 'svg']] },
  { key: 'play', intro: 'Time to play! A football. A bike. Paint. A kite!', noArticle: false, words: [['football', 'svg'], ['bike', 'little-learners:transport-2/bike'], ['paint', 'vowel-teams-ai/paint'], ['kite', 'little-learners:letter-k/kite', 'kyte']] },
];
const prompts = { pencil: 'a yellow pencil', book: 'a blue book', bag: 'a red school bag', ruler: 'a yellow ruler', sunny: 'a sunny day', rainy: 'a rainy day', cloudy: 'a cloudy day', windy: 'a windy day', snowy: 'a snowy day', stormy: 'a stormy day', school: 'a school building', park: 'a park with a tree and a bench', hospital: 'a hospital building', breakfast: 'a breakfast plate', dinner: 'a dinner plate', football: 'a football' };

lessons.forEach((l, i) => {
  const id = `everyday-english-${l.key}`;
  const out = ['# Everyday English: words for the day (school, weather, town, meals, play).', `id: ${id}`, 'unit: everyday-english', 'track: explorers', 'level: a1', `order: ${i + 1}`];
  if (l.noArticle) out.push('noArticle: true');
  out.push('words:');
  for (const [w, how, say] of l.words) out.push(how === 'svg' ? `  - { word: ${w}, source: svg, imagePrompt: "${prompts[w]}" }` : `  - { word: ${w}, reuse: "${how}"${say ? `, say: "${say}"` : ''} }`);
  if (l.sentences) {
    out.push('sentences:');
    for (const [text, picture] of l.sentences) out.push(`  - { text: "${text}", picture: ${picture}, gap: ${picture}, choices: [${[picture, ...l.words.map(([w]) => w).filter((w) => w !== picture).slice(0, 2)].join(', ')}] }`);
  }
  out.push('narration:', `  intro: "${l.intro}"`, '  praise: ["Great job!", "You know it!", "Super!"]', '  instructions:',
    '    listen-and-tap: "Listen, then tap the picture!"', '    match-picture: "Match each word to its picture!"', '    memory: "Find the matching cards!"', '    read-and-pick: "Read the word. Then tap its picture!"');
  if (l.sentences) out.push('    fill-the-gap: "Read. Then tap the word that fits!"', '    sentence-builder: "Listen. Then put the words in order!"');
  out.push(`activities: [listen-and-tap, read-and-pick, match-picture${l.sentences ? ', fill-the-gap, sentence-builder' : ''}, memory]`);
  writeFileSync(join(dir, `${id}.yaml`), out.join('\n') + '\n');
});
console.log('Wrote', lessons.length, 'Everyday English lessons.');
