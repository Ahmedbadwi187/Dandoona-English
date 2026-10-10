// Draws the six friend avatars of Dandoona with OpenAI images (same fluffy pom-pom look as the mascot), on a transparent background.
//   node tools/art/make-avatars-openai.mjs [name ...]      (default: all). Output: tools/art/out/avatars/<name>.webp (1024 px)
// Reads OPENAI_API_KEY from .env, writes the actual cost to content/generated/cost-ledger.json (same model and quality as the generator).
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve('.');
const env = Object.fromEntries(fs.readFileSync(path.join(root, '.env'), 'utf8').split(/\r?\n/).filter((l) => l.includes('=') && !l.startsWith('#')).map((l) => [l.slice(0, l.indexOf('=')).trim(), l.slice(l.indexOf('=') + 1).trim().replace(/^["']|["']$/g, '')]));
const key = env.OPENAI_API_KEY;
if (!key) throw new Error('OPENAI_API_KEY is not in .env');
const model = 'gpt-image-2.5-flare';

const style = 'A cute fluffy pom-pom plush character in the exact same style as a round plum-purple fuzzy mascot: soft glossy 3D render, very fluffy fur, big dark-blue sparkling eyes with white highlights, rosy pink cheeks, a small friendly open smile, short round arms, stubby feet, centered, full body, facing the viewer, soft studio lighting, clean and simple, no accessories, no text, no frame, no border, no shadow on the ground. Transparent background.';
const animals = {
  bunny: 'a white and soft pink bunny with two tall fluffy ears',
  cat: 'an orange tabby kitten with small pointed ears and a lighter belly',
  bear: 'a warm brown teddy bear with small round ears and a cream muzzle',
  owl: 'a teal-and-brown owl with big round eyes and tiny feathery ear tufts',
  fish: 'a cheerful orange goldfish with a flowing tail and little fins',
  puppy: 'a golden-cream puppy with floppy ears and a small pink tongue',
  penguin: 'a little black-and-white penguin with an orange beak and orange feet',
  // for the 10 to 12 year olds: the same fluffy look, a little cooler and less babyish
  fox: 'a confident orange fox with a white-tipped fluffy tail, pointed ears and a cheeky smile',
  wolf: 'a young grey wolf pup with pointed ears, a lighter muzzle and a brave friendly grin',
  dragon: 'a friendly teal dragon with small round wings, tiny horns and a spiky tail, smiling proudly',
  dino: 'a green baby dinosaur with a row of soft orange back plates and a big happy smile',
  robot: 'a fluffy round little robot with a soft silver-blue body, an antenna, glowing blue eyes and a smile (still furry and plush)',
  tiger: 'a young tiger cub with bold dark stripes, a cream muzzle and a confident grin',
  shark: 'a friendly little blue shark with a pale belly, a small fin on top and a cool, cheeky smile (no teeth showing)',
  panda: 'a chubby panda with black ears, eye patches and arms, wearing a small cool red headband',
};

const out = path.join(root, 'tools/art/out/avatars');
fs.mkdirSync(out, { recursive: true });
const wanted = process.argv.slice(2).length ? process.argv.slice(2) : Object.keys(animals);
const ledgerPath = path.join(root, 'content/generated/cost-ledger.json');
const ledger = JSON.parse(fs.readFileSync(ledgerPath, 'utf8'));

for (const name of wanted) {
  const res = await fetch('https://api.openai.com/v1/images/generations', {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ model, prompt: `${style} The character is ${animals[name]}.`, n: 1, size: '1024x1024', quality: 'medium', background: 'transparent', output_format: 'webp' }),
  });
  const json = await res.json();
  if (!res.ok) throw new Error(`${name}: ${res.status} ${JSON.stringify(json).slice(0, 300)}`);
  fs.writeFileSync(path.join(out, `${name}.webp`), Buffer.from(json.data[0].b64_json, 'base64'));
  const u = json.usage ?? {};
  const usd = ((u.input_tokens_details?.text_tokens ?? u.input_tokens ?? 0) * 5 + (u.output_tokens ?? 0) * 30) / 1e6 || 0.07;
  ledger.push({ atUtc: new Date().toISOString(), service: 'OpenAI', what: `avatar ${name}`, usd: Math.round(usd * 1e5) / 1e5, estimated: !json.usage });
  console.log(name, 'ok', usd.toFixed(3));
}
fs.writeFileSync(ledgerPath, JSON.stringify(ledger, null, 2));
const total = ledger.reduce((t, e) => t + e.usd, 0);
console.log('ledger total', total.toFixed(2), 'USD');
