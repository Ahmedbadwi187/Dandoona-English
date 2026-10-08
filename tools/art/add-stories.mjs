// Writes the picture stories into the units file (one per unit, five pages each): the sentence Dandoona reads, the unit's own words whose
// pictures are shown, and her pose. Run: node tools/art/add-stories.mjs  (it replaces the stories already there).
import { readFileSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const file = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'content', 'curriculum', 'units', 'little-learners.yaml');

// [sentence, words shown, pose]
const stories = {
  letters: [
    ['Dandoona goes to a picnic.', [], 'waving'],
    ['She brings an apple and a banana.', ['apple', 'banana'], 'pointing-up'],
    ['A cat and a dog come too.', ['cat', 'dog'], 'jumping'],
    ['A duck brings an egg.', ['duck', 'egg'], 'thinking'],
    ['Yum! What a happy picnic!', [], 'clapping'],
  ],
  colors: [
    ['Dandoona wakes up on a sunny day.', ['sun'], 'waving'],
    ['She sees a red apple and a red strawberry.', ['apple', 'strawberry'], 'pointing-up'],
    ['A yellow duck swims by a green frog.', ['duck', 'frog'], 'jumping'],
    ['A blue balloon floats near a blue cloud.', ['balloon', 'cloud'], 'thinking'],
    ['What a colorful day!', [], 'clapping'],
  ],
  numbers: [
    ['Dandoona has one balloon.', ['one'], 'waving'],
    ['Then she gets two more. Now she has three!', ['two', 'three'], 'jumping'],
    ['Four, five, six balloons fly up.', ['four', 'five', 'six'], 'pointing-up'],
    ['Eight, nine, ten balloons float away.', ['eight', 'nine', 'ten'], 'thinking'],
    ['Wow! So many happy balloons!', [], 'clapping'],
  ],
  shapes: [
    ['Dandoona finds a ball. It is a circle.', ['ball', 'circle'], 'waving'],
    ['She sees a window. It is a rectangle.', ['window', 'rectangle'], 'pointing-up'],
    ['A kite flies high. It is a diamond.', ['kite', 'diamond'], 'jumping'],
    ['An egg is an oval. A heart is a heart.', ['egg', 'oval', 'heart'], 'thinking'],
    ['Shapes are everywhere!', [], 'clapping'],
  ],
  animals: [
    ['Dandoona visits the farm.', [], 'waving'],
    ['A cow says moo. A pig says oink.', ['cow', 'pig'], 'pointing-up'],
    ['A horse runs and a duck swims.', ['horse', 'duck'], 'jumping'],
    ['A cat and a dog play together.', ['cat', 'dog'], 'thinking'],
    ['What a fun day!', [], 'clapping'],
  ],
  feelings: [
    ['Dandoona is happy. She is playing.', ['happy'], 'jumping'],
    ['Her toy falls. Now she is sad.', ['sad'], 'thinking'],
    ['Her friend helps. Dandoona is happy again!', ['happy'], 'clapping'],
    ['It is late. Dandoona is sleepy.', ['sleepy'], 'waving'],
    ['Good night, Dandoona!', [], 'base'],
  ],
  'my-body': [
    ['Dandoona wakes up and opens her eyes.', ['eye'], 'waving'],
    ['She hears a bird with her ear.', ['ear'], 'pointing-up'],
    ['She smells breakfast with her nose.', ['nose'], 'thinking'],
    ['Yum! She eats with her mouth.', ['mouth'], 'jumping'],
    ['Then she waves her hand and stamps her foot.', ['hand', 'foot'], 'clapping'],
  ],
  actions: [
    ['Dandoona waves hello.', ['wave'], 'waving'],
    ['She jumps and claps.', ['jump', 'clap'], 'jumping'],
    ['She runs and dances.', ['run', 'dance'], 'clapping'],
    ['Then she sits and thinks.', ['sit', 'think'], 'thinking'],
    ['Time to sleep. Good night!', ['sleep'], 'base'],
  ],
  food: [
    ['Dandoona is hungry.', [], 'thinking'],
    ['She eats pizza and a carrot.', ['pizza', 'carrot'], 'pointing-up'],
    ['She drinks milk and juice.', ['milk', 'juice'], 'waving'],
    ['For dessert, ice cream and a cupcake!', ['ice cream', 'cupcake'], 'jumping'],
    ['Yummy! Now she is full.', [], 'clapping'],
  ],
  clothes: [
    ['It is cold today. Dandoona gets dressed.', [], 'waving'],
    ['She puts on a shirt and pants.', ['shirt', 'pants'], 'pointing-up'],
    ['She puts on socks and shoes.', ['socks', 'shoes'], 'jumping'],
    ['She wears a jacket, a scarf and gloves.', ['jacket', 'scarf', 'gloves'], 'thinking'],
    ['And a hat! Ready to go!', ['hat'], 'clapping'],
  ],
  toys: [
    ['Dandoona opens the toy box.', [], 'waving'],
    ['She plays with a ball and a car.', ['ball', 'car'], 'jumping'],
    ['She builds with blocks and plays the drum.', ['blocks', 'drum'], 'pointing-up'],
    ['She hugs her teddy and her doll.', ['teddy', 'doll'], 'thinking'],
    ['Then she flies a kite!', ['kite'], 'clapping'],
  ],
  'my-family': [
    ['This is my family.', [], 'waving'],
    ['My mom and my dad say hello.', ['mom', 'dad'], 'pointing-up'],
    ['My grandma and my grandpa wave.', ['grandma', 'grandpa'], 'jumping'],
    ['My brother, my sister and the baby smile.', ['brother', 'sister', 'baby'], 'thinking'],
    ['We are a happy family!', [], 'clapping'],
  ],
  'my-home': [
    ['Dandoona opens the door with a key.', ['door', 'key'], 'waving'],
    ['She sits on the sofa near the window.', ['sofa', 'window'], 'pointing-up'],
    ['A lamp is on the table.', ['lamp', 'table'], 'thinking'],
    ['She sits on a chair.', ['chair'], 'jumping'],
    ['Time for bed. Good night!', ['bed'], 'base'],
  ],
  opposites: [
    ['An elephant is big. An ant is small.', ['big', 'small'], 'waving'],
    ['The sun is hot. The snowman is cold.', ['hot', 'cold'], 'pointing-up'],
    ['The arrow goes up and then down.', ['up', 'down'], 'jumping'],
    ['A car is fast. A turtle is slow.', ['fast', 'slow'], 'thinking'],
    ['Opposites are fun!', [], 'clapping'],
  ],
  transport: [
    ['Dandoona wants to travel.', [], 'waving'],
    ['She goes by bike and by bus.', ['bike', 'bus'], 'pointing-up'],
    ['She rides a train and a car.', ['train', 'car'], 'jumping'],
    ['She sails in a boat and flies in a plane.', ['boat', 'plane'], 'thinking'],
    ['A truck and a van wave goodbye.', ['truck', 'van'], 'clapping'],
  ],
};

const lines = readFileSync(file, 'utf8').replace(/\r\n/g, '\n').split('\n');
const out = [];
let id = '';
let skipping = false;
for (const line of lines) {
  const m = line.match(/^  - id: (\S+)/);
  if (m) id = m[1];
  if (skipping) {
    if (/^    (story:|  )/.test(line) || /^      /.test(line)) continue; // the old story block
    skipping = false;
  }
  if (/^    story:/.test(line)) { skipping = true; continue; }
  out.push(line);
  if (/^    chest: /.test(line) && stories[id]) {
    out.push('    # The picture story after this unit: Dandoona reads one sentence per page; the pictures are words of the unit.');
    out.push('    story:', '      pages:');
    for (const [text, words, pose] of stories[id]) out.push(`        - { text: "${text}", words: [${words.join(', ')}], pose: ${pose} }`);
  }
}
writeFileSync(file, out.join('\n'));
console.log('Stories for', Object.keys(stories).length, 'units');
