// Writes the lesson files of the later units (Actions, Food, Clothes, Toys, My Family, My Home, Opposites, Transport) from one table,
// so every unit has the same shape. A word is `[word, phrase, how]`: how = `reuse` (the picture of a word that already exists in
// the Letters or Colors; found by name), `svg` (drawn by tools/art/make-*.mjs), `openai` (generated, then approved) or `mascot`
// (Dandoona herself, made with the edits model from her reference). Run: node tools/art/make-lessons.mjs
import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const curriculum = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'content', 'curriculum');

/** Which existing lesson has a picture for [word] (looked up in the Letters, Colors, Shapes... lesson files). */
function reuseOf(word, preferred) {
  if (preferred) return preferred;
  for (const f of readdirSync(curriculum).filter((n) => /^(letter|color)-.*\.yaml$/.test(n))) {
    const text = readFileSync(join(curriculum, f), 'utf8');
    // the lesson that owns the picture: a line that itself reuses another picture is not the source
    if (new RegExp(`word: ${word.replace('-', '\\-')}, (?!reuse:)`).test(text)) return `${f.replace('.yaml', '')}/${word.replace(/ /g, '-')}`;
  }
  throw new Error(`no existing picture for ${word}`);
}

const units = [
  {
    id: 'actions',
    listen: 'Listen, then tap what Dandoona does!',
    prompt: (w) => `Dandoona ${w}`,
    lessons: [
      ['Let\'s move! ... Wave. ... Jump. ... Clap!', [['wave', 'I can wave.', 'openai'], ['jump', 'I can jump.', 'openai'], ['clap', 'I can clap.', 'openai']]],
      ['More actions! ... Point. ... Think. ... Run!', [['point', 'I can point.', 'openai'], ['think', 'I can think.', 'openai'], ['run', 'I can run.', 'mascot']]],
      ['Last actions! ... Dance. ... Sit. ... Sleep!', [['dance', 'I can dance.', 'mascot'], ['sit', 'I can sit.', 'mascot'], ['sleep', 'I can sleep.', 'mascot']]],
    ],
  },
  {
    id: 'food',
    listen: 'Listen, then tap the food!',
    lessons: [
      ['Yummy food! ... An apple. ... A banana. ... An orange!', [['apple', 'I like apples.', 'reuse'], ['banana', 'I like bananas.', 'reuse'], ['orange', 'I like oranges.', 'reuse']]],
      ['More food! ... A strawberry. ... A carrot. ... Grapes!', [['strawberry', 'I like strawberries.', 'reuse'], ['carrot', 'I like carrots.', 'reuse'], ['grapes', 'I like grapes.', 'reuse']]],
      ['Time to drink and eat! ... Milk. ... Juice. ... An egg!', [['milk', 'I like milk.', 'reuse'], ['juice', 'I like juice.', 'reuse'], ['egg', 'I like eggs.', 'reuse']]],
      ['Tasty treats! ... Pizza. ... Ice cream. ... A cupcake!', [['pizza', 'I like pizza.', 'reuse'], ['ice cream', 'I like ice cream.', 'reuse'], ['cupcake', 'I like cupcakes.', 'reuse']]],
    ],
  },
  {
    id: 'clothes',
    listen: 'Listen, then tap the clothes!',
    lessons: [
      ['Let\'s get dressed! ... A shirt. ... Pants. ... A dress!', [['shirt', 'I wear a shirt.', 'svg'], ['pants', 'I wear pants.', 'svg'], ['dress', 'I wear a dress.', 'svg']]],
      ['Feet and head! ... Socks. ... Shoes. ... A hat!', [['socks', 'I wear socks.', 'svg'], ['shoes', 'I wear shoes.', 'svg'], ['hat', 'I wear a hat.', 'reuse']]],
      ['Cold weather! ... A jacket. ... A scarf. ... Gloves!', [['jacket', 'I wear a jacket.', 'svg'], ['scarf', 'I wear a scarf.', 'svg'], ['gloves', 'I wear gloves.', 'svg']]],
    ],
  },
  {
    id: 'toys',
    listen: 'Listen, then tap the toy!',
    lessons: [
      ['Time to play! ... A ball. ... A car. ... A kite!', [['ball', 'I play with a ball.', 'reuse'], ['car', 'I play with a car.', 'reuse'], ['kite', 'I play with a kite.', 'reuse']]],
      ['More toys! ... A balloon. ... A yo-yo. ... A teddy!', [['balloon', 'I play with a balloon.', 'reuse'], ['yo-yo', 'I play with a yo-yo.', 'reuse'], ['teddy', 'I hug my teddy.', 'openai']]],
      ['Even more toys! ... A doll. ... Blocks. ... A drum!', [['doll', 'I play with a doll.', 'openai'], ['blocks', 'I play with blocks.', 'svg'], ['drum', 'I play the drum.', 'svg']]],
    ],
  },
  {
    id: 'my-family',
    listen: 'Listen, then tap the person!',
    lessons: [
      ['This is my family! ... Mom. ... Dad. ... Baby!', [['mom', 'This is my mom.', 'openai'], ['dad', 'This is my dad.', 'openai'], ['baby', 'This is my baby.', 'openai']]],
      ['Grandparents! ... Grandma. ... Grandpa!', [['grandma', 'This is my grandma.', 'openai'], ['grandpa', 'This is my grandpa.', 'openai']]],
      ['Brother and sister! ... Brother. ... Sister!', [['brother', 'This is my brother.', 'openai'], ['sister', 'This is my sister.', 'openai']]],
    ],
  },
  {
    id: 'my-home',
    listen: 'Listen, then tap the thing!',
    lessons: [
      ['Welcome home! ... A bed. ... A door. ... A window!', [['bed', 'This is a bed.', 'svg'], ['door', 'This is a door.', 'svg'], ['window', 'This is a window.', 'reuse']]],
      ['Inside the house! ... A lamp. ... A table. ... A chair!', [['lamp', 'This is a lamp.', 'svg'], ['table', 'This is a table.', 'svg'], ['chair', 'This is a chair.', 'svg']]],
      ['More things! ... A sofa. ... A key!', [['sofa', 'This is a sofa.', 'svg'], ['key', 'This is a key.', 'reuse']]],
    ],
  },
  {
    id: 'opposites',
    listen: 'Listen, then tap the picture!',
    lessons: [
      ['Opposites! ... Big. ... Small. ... Hot. ... Cold!', [['big', 'The elephant is big.', 'reuse:letter-e/elephant'], ['small', 'The ant is small.', 'reuse:letter-a/ant'], ['hot', 'The sun is hot.', 'reuse:letter-s/sun'], ['cold', 'The snowman is cold.', 'reuse:color-white/snowman']]],
      ['More opposites! ... Up. ... Down. ... Fast. ... Slow!', [['up', 'The arrow goes up.', 'svg'], ['down', 'The arrow goes down.', 'svg'], ['fast', 'The car is fast.', 'reuse:letter-c/car'], ['slow', 'The turtle is slow.', 'svg']]],
    ],
  },
  {
    id: 'transport',
    listen: 'Listen, then tap the vehicle!',
    lessons: [
      ['Let\'s go! ... A car. ... A bus. ... A train!', [['car', 'This is a car.', 'reuse'], ['bus', 'This is a bus.', 'svg'], ['train', 'This is a train.', 'svg']]],
      ['Water, sky and road! ... A boat. ... A plane. ... A bike!', [['boat', 'This is a boat.', 'svg'], ['plane', 'This is a plane.', 'svg'], ['bike', 'This is a bike.', 'svg']]],
      ['Big vehicles! ... A van. ... A truck!', [['van', 'This is a van.', 'reuse'], ['truck', 'This is a truck.', 'svg']]],
    ],
  },
];

const only = process.argv.slice(2);
for (const u of units) {
  if (only.length && !only.includes(u.id)) continue;
  u.lessons.forEach(([intro, words], i) => {
    const id = `${u.id}-${i + 1}`;
    const lines = [`id: ${id}`, `unit: ${u.id}`, 'track: little-learners', 'level: pre-a1', `order: ${i + 1}`, 'words:'];
    for (const [word, , how] of words) {
      const [kind, pref] = how.split(':');
      const spoken = word.replace('-', ' ');
      if (kind === 'reuse') lines.push(`  - { word: ${word}, reuse: ${reuseOf(word, pref)} }`);
      else if (kind === 'svg') lines.push(`  - { word: ${word}, imagePrompt: "${spoken}", source: svg }`);
      else if (kind === 'mascot') lines.push(`  - { word: ${word}, imagePrompt: "${(u.prompt ?? ((w) => w))(spoken)}", mascot: true, source: openai }`);
      else lines.push(`  - { word: ${word}, imagePrompt: "${(u.prompt ? u.prompt(spoken) : `a friendly cartoon ${spoken}`)}", source: openai }`);
    }
    lines.push('narration:', `  intro: "${intro}"`);
    lines.push(`  phrases: { ${words.map(([w, p]) => `${w}: "${p}"`).join(', ')} }`);
    lines.push('  praise: ["Great job!", "Well done!", "You did it!"]', '  instructions:');
    lines.push(`    listen-and-tap: "${u.listen}"`, '    match-picture: "Match each word to its picture!"', '    record-and-listen: "Listen, then say it!"');
    lines.push('activities: [listen-and-tap, match-picture, record-and-listen]');
    writeFileSync(join(curriculum, `${id}.yaml`), lines.join('\n') + '\n');
  });
}
console.log('Wrote lessons for', (only.length ? only : units.map((u) => u.id)).join(', '));
