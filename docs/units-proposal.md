# Units proposal (for approval, nothing built yet)

Written for the project owner. **Status: approved and built (Parts 1-4 committed separately).** Covers: content structure, Colors unit, two unit-map designs, certificate, cost.

## 1. Content structure

### Curriculum (source of truth)
One new file lists the units in order; every lesson file says which unit it belongs to. Lesson ids never change, so the
Letters lessons keep `letter-a` ... `letter-z` and all existing progress still points at them.

```yaml
# content/curriculum/units.yaml
track: little-learners
units:
  - { id: letters, order: 1, title: { en: "Letters",   ar: "الحروف" },  icon: letters,  color: red }
  - { id: colors,  order: 2, title: { en: "Colors",    ar: "الألوان" }, icon: colors,   color: orange }
  - { id: numbers, order: 3, title: { en: "Numbers 1-10", ar: "الأرقام" }, icon: numbers, color: blue }
  # shapes, animals, my-body, food, my-family follow the same shape
```

```yaml
# content/curriculum/letter-b.yaml   (only one new line: unit)
id: letter-b
unit: letters
track: little-learners
...
```

```yaml
# content/curriculum/color-red.yaml  (new kind of lesson)
id: color-red
unit: colors
track: little-learners
level: pre-a1
color: { name: red, hex: "#E5524A" }          # the swatch is drawn from this
words:
  - { word: apple,      source: svg, reuse: letter-a/apple }      # reuse = copy an existing picture
  - { word: strawberry, source: svg }
  - { word: heart,      source: svg }
narration:
  intro: "This is red! Red, red, red!"
  colorName: "red"
  phrases: { apple: "A red apple.", strawberry: "A red strawberry.", heart: "A red heart." }
  praise: ["Great job!", "Well done!", "You did it!"]
  instructions:
    listen-and-tap: "Listen, then tap something red!"
    match-picture: "Match each word to its picture!"
    record-and-listen: "Listen, then say it!"
    color-the-object: "Color the apple red!"
activities: [listen-and-tap, match-picture, record-and-listen, color-the-object]
```

### What the app reads (`little_learners.json`, schemaVersion 2)
```json
{ "schemaVersion": 2, "track": "little-learners", "mascot": "images/mascot/mascot.webp",
  "units": [
    { "id": "letters", "order": 1, "title": {"en": "Letters", "ar": "الحروف"}, "icon": "letters",
      "audio": { "title": "audio/units/letters/title.mp3", "celebration": "audio/units/letters/celebration.mp3" },
      "lessons": [ { "id": "letter-a", "...": "as today" } ] },
    { "id": "colors", "order": 2, "lessons": [ { "id": "color-red", "color": {"name":"red","hex":"#E5524A"}, "...": "..." } ] }
  ] }
```
The app builds the unit map from `units`, so a new unit is only new YAML plus `export`; no Dart change.
An old (schemaVersion 1) file still loads as one unit named Letters.

### Rules
- **A unit opens when the previous unit is finished.** "Finished" = every lesson of it has progress (the same rule the
  letter map uses today for opening the next letter), so nobody who unlocked all letters loses anything. *Decision 1 below.*
- Inside a unit, the lesson path keeps today's behaviour (next lesson opens when the previous has progress).
- The parent's "unlock all" setting also opens all units.

### Progress migration (local)
- Progress records (`progress.v1`) are not rewritten: they are keyed by lesson id, and the ids stay.
- New small store `meta.v2` per child: `{ "schema": 2, "certificates": { "letters": "2026-10-07" } }`.
- Migration on first launch: for every child whose 26 letters all have progress, mark the Letters certificate as earned and
  the celebration as already seen. Idempotent; a test loads a v1 store with partial and complete children and checks both,
  and that no progress record changes.

## 2. Colors unit

| # | Lesson | Things (reused picture = from Letters, to verify the color fits) | New SVGs |
|---|---|---|---|
| 1 | red | apple (reuse), strawberry, heart | 2 |
| 2 | blue | whale (reuse), cloud, balloon | 2 |
| 3 | yellow | banana (reuse), sun (reuse), duck (reuse) | 0 |
| 4 | green | frog (reuse), leaf (reuse), tree (reuse) | 0 |
| 5 | orange | orange (reuse), carrot, pumpkin | 2 |
| 6 | purple | grapes, eggplant, flower | 3 |
| 7 | pink | pig (reuse), cupcake, bow (reuse, from accessories) | 1 |
| 8 | brown | bear (reuse), monkey (reuse), nut (reuse) | 0 |
| 9 | black | black cat, tire, spider | 3 |
| 10 | white | egg (reuse), snowman, milk | 2 |

15 new simple SVGs + 10 swatches, all in `palette.json` colors (plus the fill placeholder for coloring pages).
OpenAI images: none planned. If a drawing looks poor I will list it in `docs/asset-decisions.md` before using OpenAI.

### Activities (4 per lesson, each with a spoken instruction in Dandoona's voice, auto-played, speaker button to repeat)
1. **listen-and-tap** (reused): Dandoona says the color, the child taps the picture of that color among 3.
2. **match-picture** (reused): word sound to picture.
3. **record-and-listen** (reused): "a red apple", then the child says it and hears both.
4. **color-the-object** (new): a row of 4 color swatches (the lesson color + 3 others from the unit) and a line drawing.
   Tap a color, tap the drawing, it fills. The right color gives praise and 3 stars; a wrong color shakes the swatch and
   replays the color name (no spoken scolding); stars drop by one per mistake, minimum 1. Drawings are SVGs with one fill
   region; the app swaps the fill color at run time, so it needs no new package.

### Audio per lesson (same narrator voice and speed 0.8)
intro, color name, 3 words, 3 phrases, 3 praise, 4 instructions = 15 lines. Per unit: title, "let's learn" line and a
celebration line. The child's name cannot be recorded in advance, so "Hi, Omar!" is text only; the greeting that is
spoken is generic ("Hello! Let's play!").

## 3. Unit map: two options (screenshots in `docs/design-options/`)
- **A, Islands** (`unit-map-option-a-islands.png`): each unit is a floating island on a dotted sky path; Dandoona stands next to
  the current island; the current island is bigger with a glow, a progress bar (4/10) and a play button; done islands have
  a check and a Certificate chip; locked ones are grey with a lock. Feels like a journey; picture-first for non-readers.
- **B, Road stops** (`unit-map-option-b-road.png`): a winding road with a card per unit; the current card is large with progress
  and a play button. Bigger text and tap areas, but more like a list.

Recommendation: **A**, with the whole island plus its label as the tap target (at least 96 dp). The Letters unit's
lesson path stays the current letter map.

## 4. Certificate
Celebration (Dandoona jumps, stars) then a certificate: Dandoona, the child's name, the unit name, the date, in Dandoona's
colors. Drawn in the app with a normal widget and turned into a PNG on the device (`RepaintBoundary.toImage`); no service.
Saving/sharing sits behind the parental gate. Sharing uses the system share sheet via `share_plus` (BSD-3, no permission
needed); saving to the gallery/downloads would need a storage permission, so I propose share-only. *Decision 3 below.*
Children who already finished Letters get that certificate unlocked by the migration.

## 5. Cost estimate
| Item | Estimate |
|---|---|
| ElevenLabs, Colors lessons (10 x about 250 characters) + unit lines | about 3,000 characters, about 0.25 USD at 0.08 USD per 1,000 characters |
| OpenAI images | 0 USD (everything self-drawn); contingency 0.50 USD if two objects need it |
| Total | under 1 USD. Spent so far 3.49 USD of the 25 USD cap |

## 6. Decisions I need from you
1. Unit finished = every lesson has progress (recommended, matches today), or = every activity of every lesson done?
2. Map design A or B?
3. Certificate: PNG shared through the system share sheet (adds `share_plus`), or also a PDF (adds the `pdf` package, Apache-2.0)?
4. Is the Colors list above OK (especially black: cat, tire, spider)?
