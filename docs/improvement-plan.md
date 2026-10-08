# Improvement plan for the Little Learners track (ages 3 to 5, until the 6th birthday)

The owner approved everything below, to be built one item at a time (each item: content or code, tests, a commit, and a note here).
The 6-8 track is a separate, different track that comes later (entry by the child's age, already how the app picks a track); for now
it stays "coming soon".

Status: [x] done, [ ] to do, [~] started.

1. [x] **Stories**: a five-page picture story after every unit (Dandoona reads one sentence per page, the pictures are the unit's own words,
   tap a picture for its word). The story stop on the map opens it; reading to the end marks it.
2. [x] **Capital and small letters** (owner's addition): every letter lesson shows the capital and the small letter together ("Aa"); Dandoona
   says "capital A" and "small a" when each is tapped; the small letter is traced as well as the capital.
3. [x] **Animal sounds and where animals live** (Animals): "a cat says meow" for every animal (voice), and a game that puts each animal in its
   home (house, farm, water, wild). Built: `animal-sounds` (hear "Meow! Meow!", tap the animal; rabbit and zebra are quiet so they are not asked) and `habitat` (put the animal in its home, it says "A cow lives on the farm.").
4. [x] **"Dandoona says"** (Actions): Dandoona says an action and the child does it for real; a gentle timer, no scores. Built (`dandoona-says`, ring timer, green check, always 3 stars). Live in all three Actions lessons.
5. [x] **Counting for real and tracing numbers** (Numbers): tap each balloon as it is counted; trace the numeral 1-10. Built: `count-along` (touch each balloon, it says the number) and `trace` on the numbers lessons (the numerals one after the other).
6. [x] **Printable cards for parents** (all units): one page per unit with 3-4 things to look for at home; a web page, no tracking. Built: `AssetGenerator cards` writes cards/little_learners/*.html (15 units + index, English and Arabic, no scripts, nothing loaded from elsewhere) from content/parent/tips.yaml; the API serves them at /cards (static, anonymous, locked-down headers); the parent settings show the link with a copy button.
7. [x] **More activities on the same content** (all units): odd one out, drag to sort, memory cards. Built: `odd-one-out` (3 of the unit + 1 Letters picture), `sort` (drag or tap into bins; Body, Food, Clothes, Transport, Home, Family), `memory` (every later lesson; Opposites pair a word with its opposite).
8. [x] **From words to sentences** (all units): "The cat is big": the child completes a sentence by choosing the picture. Built: `sentence` (hear "I like pizza.", see "I like ____.", tap the picture) on the second lesson of each later unit, using the phrase audio that already existed.
9. [x] **Smart review**: the words a child misses come back in a short review before a new lesson, and in "Practice at home" for parents. Built: the words not found are kept on the phone only (`misses.v1`); an orange Practice button appears on the map when words wait (hear the word, tap the picture, a word found at once comes off the list); the parent's "Practice at home" shows the really missed words first.
10. [x] **Unit extras**: Colors (mixing colors), Shapes (build a picture from shapes), Feelings (how does Dandoona feel in a story),
    Body (drag the part to Dandoona), Food (make a meal), Clothes (dress Dandoona for the weather), Toys (my turn / your turn),
    Family (my family tree, kept on the phone only), Home (which room), Opposites (longer / shorter), Transport (road, water or sky). Built as: Colors `mix-colors`, Shapes `build-picture`, Feelings `story-feeling` (the story sentence is read, choose the face), Body/Food/Clothes/Transport/Home/Family `sort` (head or limbs, fruit/drink/treat, sunny or cold, road/water/sky, which room, grandparents/parents/children), Toys `turns` ("My turn!/Your turn!"), Opposites `memory` with opposite pairs. Nothing is stored for the family game.
11. [~] The 6-8 track: planned in `docs/explorers-plan.md` (waiting for the owner's review).

Rules that stay: no AI or ads or paid services in the product, free licenses, assets bundled or served by our own API, spend under the $25
cap with a cost estimate first, nothing about a child leaves the phone except through the optional account.

## Voice
Every game has its spoken instruction and every Actions lesson has its "Dandoona says" lines (generated once the ElevenLabs credit was added; 87 lines, about 19 cents).
