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
4. [~] **"Dandoona says"** (Actions): Dandoona says an action and the child does it for real; a gentle timer, no scores. Built (`dandoona-says`, ring timer, green check, always 3 stars) and live in Actions lesson 1. **Waiting for voice credit**: the ElevenLabs monthly quota ran out (40000 credits), so lessons 2 and 3 (`node tools/art/make-lessons.mjs actions` already writes their `says` lines; then `audio` + `export`; about 20 credits left of need ~50) are not switched on yet.
5. [ ] **Counting for real and tracing numbers** (Numbers): tap each balloon as it is counted; trace the numeral 1-10.
6. [ ] **Printable cards for parents** (all units): one page per unit with 3-4 things to look for at home; a web page, no tracking.
7. [ ] **More activities on the same content** (all units): odd one out, drag to sort, memory cards.
8. [ ] **From words to sentences** (all units): "The cat is big": the child completes a sentence by choosing the picture.
9. [ ] **Smart review**: the words a child misses come back in a short review before a new lesson, and in "Practice at home" for parents.
10. [ ] **Unit extras**: Colors (mixing colors), Shapes (build a picture from shapes), Feelings (how does Dandoona feel in a story),
    Body (drag the part to Dandoona), Food (make a meal), Clothes (dress Dandoona for the weather), Toys (my turn / your turn),
    Family (my family tree, kept on the phone only), Home (which room), Opposites (longer / shorter), Transport (road, water or sky).
11. [ ] Later and separate: the 6-8 track.

Rules that stay: no AI or ads or paid services in the product, free licenses, assets bundled or served by our own API, spend under the $25
cap with a cost estimate first, nothing about a child leaves the phone except through the optional account.
