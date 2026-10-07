# Treasure chest rewards (the plan for every chest on the map)

After every unit on the map there is a treasure chest. It opens once the unit is done (also for children who finished or
skipped the unit before chests existed). **Rewards are fixed per chest, never random.** The plan lives in
`content/curriculum/units/little-learners.yaml` (`chest: { accessory, stickers }` under each unit), so changing a reward is a
change there (plus the drawing), not in code.

Each chest gives:
- **One outfit for Dandoona** (an SVG in `content/art/accessories/<id>.svg`), themed to the unit before it. She wears it right
  away; the wardrobe keeps all of them.
- **3-4 stickers** of that unit's words for the Sticker Book (tap a sticker and Dandoona says the word). A sticker uses the
  word's own picture and audio, so it costs no new art or voice.

The five older outfits (party hat, glasses, bow, crown, bow tie) are still earned with stars; they are not chest rewards.

| # | Unit | Chest outfit | Stickers | Built |
|---|------|--------------|----------|-------|
| 1 | Letters | `grad-cap` (graduation cap) | apple, ball, cat, dog | yes |
| 2 | Colors | `beret` (painter's beret) | strawberry, sun, frog, cloud | yes |
| 3 | Numbers | `top-hat` (magic top hat with a star) | one, three, five, ten | yes |
| 4 | Shapes | `star-headband` (star bopper) | circle, triangle, star, heart | yes |
| 5 | Animals | `animal-ears` (cat ears headband) | cat, dog, duck, fish | yes |
| 6 | Feelings | `heart-glasses` (heart-shaped glasses) | happy, sad, angry, sleepy | when Feelings is built |
| 7 | My Body | `sweatband` (sporty headband) | hand, foot, eye, nose | when My Body is built |
| 8 | Actions | `hero-mask` (little hero mask) | jump, run, clap, dance | when Actions is built |
| 9 | Food | `chef-hat` | apple, bread, milk, cake | when Food is built |
| 10 | Clothes | `beanie` (woolly hat) | shirt, shoes, hat, socks | when Clothes is built |
| 11 | Toys | `propeller-cap` | ball, doll, kite, teddy | when Toys is built |
| 12 | My Family | `flower-crown` | mom, dad, baby, grandma | when My Family is built |
| 13 | My Home | `night-cap` (cozy nightcap) | bed, door, lamp, window | when My Home is built |
| 14 | Opposites | `sunglasses` | big, small, hot, cold | when Opposites is built |
| 15 | Transport | `pilot-cap` | car, bus, boat, plane | when Transport is built |

For a unit that is not built yet the sticker words are the intended ones; when the unit's content is written the words must
match (the generator refuses a sticker that is not a word of its unit, and a built unit must have its outfit drawn).
Outfits are drawn to sit on Dandoona's square frame: preview them with
`flutter test test_screenshots/accessories_preview_test.dart --update-goldens`.

## Where things are stored
- Opened chests: `meta.v2` per child (`chests`, unit ids), synced with the other achievements.
- What a child owns is **derived**: the outfit and stickers of every opened chest. Nothing else is stored, so children who had
  opened a chest before the rewards existed get its outfit and stickers automatically.
- The worn outfit: `equippedAccessory` on the child profile (as before).

## Later (not started)
Mini-games, coloring pages and map decorations as further rewards; the castle at the end gets its own big reward.
