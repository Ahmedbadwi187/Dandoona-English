// Adds the extra games (improvement plan items 5, 7, 8, 10) to the lesson files, from one table. Idempotent: run it after
// `make-lessons.mjs` (which rewrites the lessons of the later units) and before `audio` / `export`.
//   node tools/art/add-extras.mjs
// No new spoken lines are needed: the games speak the words, phrases and story lines that already exist.
import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const dir = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'content', 'curriculum');
const read = (id) => readFileSync(join(dir, `${id}.yaml`), 'utf8').replace(/\r\n/g, '\n');
const write = (id, t) => writeFileSync(join(dir, `${id}.yaml`), t);

/** Adds activities (right after `after` when it is there, else at the end) to a lesson's list. */
function addActivities(t, names, after) {
  return t.replace(/^activities: \[(.*)\]$/m, (_, list) => {
    const items = list.split(',').map((s) => s.trim());
    for (const n of names) {
      if (items.includes(n)) continue;
      items.splice(after && items.includes(after) ? items.indexOf(after) + 1 : items.length, 0, n);
    }
    return `activities: [${items.join(', ')}]`;
  });
}

function setWordField(t, word, field, value) {
  return t.replace(new RegExp(`^(  - \\{ word: ${word},)(.*?)( \\})$`, 'm'), (m, a, b, c) => (new RegExp(`\\b${field}:`).test(b) ? m : `${a}${b}, ${field}: ${value}${c}`));
}

function setBins(t, bins) {
  if (/^bins:/m.test(t)) return t;
  return t.replace(/^narration:/m, `bins: [${bins.map(([k, i]) => `{ key: ${k}, icon: ${i} }`).join(', ')}]\nnarration:`);
}

function setOdd(t, odd) {
  if (/^odd:/m.test(t)) return t;
  return t.replace(/^narration:/m, `odd: [${odd.join(', ')}]\nnarration:`);
}

const files = readdirSync(dir).filter((f) => f.endsWith('.yaml')).map((f) => f.replace('.yaml', ''));
const unitOf = (id) => /^unit: (\S+)/m.exec(read(id))?.[1];
const lessonsOf = (unit) => files.filter((f) => !f.startsWith('letter-') && unitOf(f) === unit).sort();

// --- Numbers: count the balloons by touching them, and trace the numerals
for (const id of ['number-1-3', 'number-4-6', 'number-7-10']) {
  let t = read(id);
  t = addActivities(t, ['count-along'], 'match-picture');
  t = addActivities(t, ['trace']); // the numerals of the lesson, one after the other
  write(id, t);
}

// --- Colors: mixing (the lessons of the colors that can be mixed)
for (const id of ['color-orange', 'color-green', 'color-purple', 'color-pink']) write(id, addActivities(read(id), ['mix-colors'], 'record-and-listen'));

// --- Shapes: build a picture from shapes (the recipes live in the app: build_picture_activity.dart)
for (const id of ['shapes-1', 'shapes-2', 'shapes-3']) write(id, addActivities(read(id), ['build-picture'], 'match-picture'));

// --- Feelings: how does Dandoona feel in the story
write('feelings-2', addActivities(read('feelings-2'), ['story-feeling'], 'match-picture'));

// --- Sorting games: [lesson, bins [key, icon], {word: group}]
const sorts = [
  ['my-body-2', [['head', 'face'], ['limbs', 'body']], { eye: 'head', ear: 'head', nose: 'head', mouth: 'head', hand: 'limbs', foot: 'limbs' }],
  ['food-4', [['fruit', 'fruit'], ['drink', 'drink'], ['treat', 'treat']], { apple: 'fruit', banana: 'fruit', orange: 'fruit', strawberry: 'fruit', grapes: 'fruit', milk: 'drink', juice: 'drink', pizza: 'treat', 'ice cream': 'treat', cupcake: 'treat' }],
  ['clothes-3', [['warm', 'sun'], ['cold', 'snow']], { shirt: 'warm', dress: 'warm', jacket: 'cold', scarf: 'cold', gloves: 'cold' }],
  ['transport-3', [['road', 'road'], ['water', 'water'], ['sky', 'sky']], { car: 'road', bus: 'road', train: 'road', bike: 'road', van: 'road', truck: 'road', boat: 'water', plane: 'sky' }],
  ['my-home-3', [['bedroom', 'bedroom'], ['kitchen', 'kitchen'], ['living', 'living']], { bed: 'bedroom', table: 'kitchen', chair: 'kitchen', sofa: 'living' }],
  ['my-family-3', [['grandparents', 'elder'], ['parents', 'parents'], ['children', 'child']], { grandma: 'grandparents', grandpa: 'grandparents', mom: 'parents', dad: 'parents', brother: 'children', sister: 'children', baby: 'children' }],
];
for (const [id, bins, groups] of sorts) {
  let t = read(id);
  t = setBins(t, bins);
  t = addActivities(t, ['sort'], 'match-picture');
  write(id, t);
  // the groups go on the words of the whole unit
  for (const lid of lessonsOf(unitOf(id))) {
    let u = read(lid);
    for (const [w, g] of Object.entries(groups)) u = setWordField(u, w, 'group', g);
    write(lid, u);
  }
}

// --- Toys: my turn / your turn
write('toys-3', addActivities(read('toys-3'), ['turns'], 'match-picture'));

// --- Opposites: pairs for the memory game
const opposites = { big: 'small', small: 'big', hot: 'cold', cold: 'hot', up: 'down', down: 'up', fast: 'slow', slow: 'fast' };
for (const lid of lessonsOf('opposites')) {
  let t = read(lid);
  for (const [w, o] of Object.entries(opposites)) t = setWordField(t, w, 'opposite', o);
  write(lid, t);
}

const later = ['numbers', 'shapes', 'animals', 'feelings', 'my-body', 'actions', 'food', 'clothes', 'toys', 'my-family', 'my-home', 'opposites', 'transport'];

// --- Memory cards in every lesson of the later units (not Letters or Colors)
for (const unit of later) for (const lid of lessonsOf(unit)) write(lid, addActivities(read(lid), ['memory'], 'match-picture'));

// --- Odd one out (themed units) and sentences: on the second lesson of the unit (the only one when there is just one)
const odd = {
  animals: ['apple', 'ball', 'car', 'hat', 'key'],
  food: ['ball', 'car', 'hat', 'key', 'cat'],
  clothes: ['apple', 'ball', 'car', 'cat', 'key'],
  toys: ['apple', 'cat', 'tree', 'key', 'egg'],
  transport: ['apple', 'cat', 'ball', 'hat', 'key'],
  'my-body': ['apple', 'car', 'ball', 'hat', 'tree'],
  'my-home': ['apple', 'cat', 'car', 'ball', 'tree'],
  'my-family': ['apple', 'car', 'ball', 'hat', 'tree'],
};
for (const unit of later) {
  const ls = lessonsOf(unit);
  const pick = ls[Math.min(1, ls.length - 1)];
  let t = read(pick);
  t = addActivities(t, ['sentence'], 'match-picture');
  if (odd[unit]) {
    t = addActivities(t, ['odd-one-out'], 'match-picture');
    t = setOdd(t, odd[unit]);
  }
  write(pick, t);
}
console.log('Extras added.');
