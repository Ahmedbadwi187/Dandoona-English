# Explorers phonemes: listen to every one

Text-to-speech cannot say a sound on its own reliably, and phonics is the heart of Explorers, so **every** phoneme clip is flagged
for the owner to listen to (decision 5 in `docs/explorers-plan.md`). The table lives in `content/curriculum/units/explorers.yaml`
(`phonemes:`); `say` is the text the voice reads to make the sound, written for the voice, not IPA.

How to check and fix:
1. Generate (owner's PC, keys in `.env`): `dotnet run --project tools/AssetGenerator -- audio --track explorers --dry-run`, then
   without `--dry-run`, then `export --track explorers`.
2. Play each file below. If one is wrong, either change its `say` text and run `audio --track explorers` again (only that clip
   is made again), or record your own (female voice, clear English, short, no vowel after a consonant where possible) and save
   it as `phoneme-<key>.override.mp3` next to the generated file. Export always prefers your recording.
3. Tick it here.

| | Sound | IPA | Voice reads | File to listen to | Words that use it |
|---|---|---|---|---|---|
| [ ] | **a** | `/æ/` | "aa" | `content/generated/explorers/phonemes/audio/phoneme-a.gen.mp3` | cat, jam, ant, hat |
| [ ] | **e** | `/ɛ/` | "eh" | `content/generated/explorers/phonemes/audio/phoneme-e.gen.mp3` | hen, bed, egg, ten |
| [ ] | **i** | `/ɪ/` | "ih" | `content/generated/explorers/phonemes/audio/phoneme-i.gen.mp3` | pig, fig, bin, six |
| [ ] | **o** | `/ɒ/` | "aw" | `content/generated/explorers/phonemes/audio/phoneme-o.gen.mp3` | dog, pot, box, mop |
| [ ] | **u** | `/ʌ/` | "uh" | `content/generated/explorers/phonemes/audio/phoneme-u.gen.mp3` | bug, nut, bus, cup |
| [ ] | **b** | `/b/` | "buh" | `content/generated/explorers/phonemes/audio/phoneme-b.gen.mp3` | bed, bin, box, bug, bus |
| [ ] | **c** | `/k/` | "kuh" | `content/generated/explorers/phonemes/audio/phoneme-c.gen.mp3` | cat, cup |
| [ ] | **d** | `/d/` | "duh" | `content/generated/explorers/phonemes/audio/phoneme-d.gen.mp3` | bed, dog |
| [ ] | **f** | `/f/` | "fff" | `content/generated/explorers/phonemes/audio/phoneme-f.gen.mp3` | fig |
| [ ] | **g** | `/g/` | "guh" | `content/generated/explorers/phonemes/audio/phoneme-g.gen.mp3` | egg (gg), pig, fig, dog, bug |
| [ ] | **h** | `/h/` | "huh" | `content/generated/explorers/phonemes/audio/phoneme-h.gen.mp3` | hat, hen |
| [ ] | **j** | `/dʒ/` | "juh" | `content/generated/explorers/phonemes/audio/phoneme-j.gen.mp3` | jam |
| [ ] | **m** | `/m/` | "mmm" | `content/generated/explorers/phonemes/audio/phoneme-m.gen.mp3` | jam, mop |
| [ ] | **n** | `/n/` | "nnn" | `content/generated/explorers/phonemes/audio/phoneme-n.gen.mp3` | hen, ten, bin, nut, ant |
| [ ] | **p** | `/p/` | "puh" | `content/generated/explorers/phonemes/audio/phoneme-p.gen.mp3` | pig, pot, mop, cup |
| [ ] | **s** | `/s/` | "sss" | `content/generated/explorers/phonemes/audio/phoneme-s.gen.mp3` | six, bus |
| [ ] | **t** | `/t/` | "tuh" | `content/generated/explorers/phonemes/audio/phoneme-t.gen.mp3` | cat, hat, ten, pot, nut, ant |
| [ ] | **x** | `/ks/` | "ks" | `content/generated/explorers/phonemes/audio/phoneme-x.gen.mp3` | six, box |
| [ ] | **l** | `/l/` | "lll" | `content/generated/explorers/phonemes/audio/phoneme-l.gen.mp3` | lunch, flag, clap, plum, blocks, lamp, plane, snail |
| [ ] | **r** | `/r/` | "rrr" | `content/generated/explorers/phonemes/audio/phoneme-r.gen.mp3` | rock, frog, crab, drum, truck, grapes, rose, rain, train, tree |
| [ ] | **v** | `/v/` | "vvv" | `content/generated/explorers/phonemes/audio/phoneme-v.gen.mp3` | five |
| [ ] | **z** | `/z/` | "zzz" | `content/generated/explorers/phonemes/audio/phoneme-z.gen.mp3` | nose, rose (the s says /z/) |
| [ ] | **sh** | `/ʃ/` | "shh" | `content/generated/explorers/phonemes/audio/phoneme-sh.gen.mp3` | fish, ship, shop, dish, sheep |
| [ ] | **ch** | `/tʃ/` | "chuh" | `content/generated/explorers/phonemes/audio/phoneme-ch.gen.mp3` | chick, chip, bench, lunch |
| [ ] | **th** | `/θ/` | "thh" | `content/generated/explorers/phonemes/audio/phoneme-th.gen.mp3` | bath, moth, math, path |
| [ ] | **ay** | `/eɪ/` | "ay" | `content/generated/explorers/phonemes/audio/phoneme-ay.gen.mp3` | cake, snake, plane, grapes (magic e); rain, snail, train, paint (ai) |
| [ ] | **ee** | `/iː/` | "ee" | `content/generated/explorers/phonemes/audio/phoneme-ee.gen.mp3` | tree, bee, sheep, feet |
| [ ] | **ie** | `/aɪ/` | "eye" | `content/generated/explorers/phonemes/audio/phoneme-ie.gen.mp3` | kite, bike, five, nine (magic e) |
| [ ] | **oa** | `/oʊ/` | "oh" | `content/generated/explorers/phonemes/audio/phoneme-oa.gen.mp3` | bone, nose, rose (magic e); boat, goat, soap, toast |
| [ ] | **ue** | `/juː/` | "you" | `content/generated/explorers/phonemes/audio/phoneme-ue.gen.mp3` | cube (magic e) |
| [ ] | **oo** | `/uː/` | "oo" | `content/generated/explorers/phonemes/audio/phoneme-oo.gen.mp3` | moon, spoon |
| [ ] | **ar** | `/ɑːr/` | "ar" | `content/generated/explorers/phonemes/audio/phoneme-ar.gen.mp3` | car, star |

Notes for listening:
- Short vowels are the hardest: **a** must be the vowel of *cat* (not "ay"), **o** the vowel of *dog* (not "oh"), **u** the vowel of
  *cup*, **i** of *pig*, **e** of *hen*.
- Stop consonants (b, c, d, g, p, t) cannot be said without a little vowel; it should be as short and quiet as possible ("kuh",
  not "kay"). m, n, s, f should be held sounds ("mmm", "sss").
- **x** is two sounds, /ks/, as in *box* and *six*.
- Phase 2 (Digraphs, Blends, Magic E, Vowel Teams) added the 14 rows from **l** down. One clip serves every spelling of a sound:
  the ck in *duck* and the k in *kite* play **c**; the a in *cake* and the ai in *rain* play **ay**; the s in *nose* plays **z**;
  the magic e plays nothing (it is shown quieter). In the lesson files this is written `"ck:c"`, `"a:ay"`, `"e:-"`.
- **ay, ie, oa, ue** are the letter names of a, i, o, u ("the vowel says its name"); **ie** must sound like *eye*, **oa** like *oh*.
- **th** is the soft th of *bath* (tongue between the teeth), not the buzzing th of *this*.
- **ar** is said in one go, as in *car*; British or American r are both fine, but keep one voice for all clips.
