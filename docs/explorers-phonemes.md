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
| [ ] | **a** | `/æ/` | "aa" | `content/generated/explorers/phonemes/audio/phoneme-a.gen.mp3` | cat, jam, bag, hat |
| [ ] | **e** | `/ɛ/` | "eh" | `content/generated/explorers/phonemes/audio/phoneme-e.gen.mp3` | hen, bed, pen, ten |
| [ ] | **i** | `/ɪ/` | "ih" | `content/generated/explorers/phonemes/audio/phoneme-i.gen.mp3` | pig, fig, bin, six |
| [ ] | **o** | `/ɒ/` | "aw" | `content/generated/explorers/phonemes/audio/phoneme-o.gen.mp3` | dog, pot, box, mop |
| [ ] | **u** | `/ʌ/` | "uh" | `content/generated/explorers/phonemes/audio/phoneme-u.gen.mp3` | bug, nut, bus, cup |
| [ ] | **b** | `/b/` | "buh" | `content/generated/explorers/phonemes/audio/phoneme-b.gen.mp3` | bag, bed, bin, box, bug, bus |
| [ ] | **c** | `/k/` | "kuh" | `content/generated/explorers/phonemes/audio/phoneme-c.gen.mp3` | cat, cup |
| [ ] | **d** | `/d/` | "duh" | `content/generated/explorers/phonemes/audio/phoneme-d.gen.mp3` | bed, dog |
| [ ] | **f** | `/f/` | "fff" | `content/generated/explorers/phonemes/audio/phoneme-f.gen.mp3` | fig |
| [ ] | **g** | `/g/` | "guh" | `content/generated/explorers/phonemes/audio/phoneme-g.gen.mp3` | bag, pig, fig, dog, bug |
| [ ] | **h** | `/h/` | "huh" | `content/generated/explorers/phonemes/audio/phoneme-h.gen.mp3` | hat, hen |
| [ ] | **j** | `/dʒ/` | "juh" | `content/generated/explorers/phonemes/audio/phoneme-j.gen.mp3` | jam |
| [ ] | **m** | `/m/` | "mmm" | `content/generated/explorers/phonemes/audio/phoneme-m.gen.mp3` | jam, mop |
| [ ] | **n** | `/n/` | "nnn" | `content/generated/explorers/phonemes/audio/phoneme-n.gen.mp3` | hen, pen, ten, bin, nut |
| [ ] | **p** | `/p/` | "puh" | `content/generated/explorers/phonemes/audio/phoneme-p.gen.mp3` | pen, pig, pot, mop, cup |
| [ ] | **s** | `/s/` | "sss" | `content/generated/explorers/phonemes/audio/phoneme-s.gen.mp3` | six, bus |
| [ ] | **t** | `/t/` | "tuh" | `content/generated/explorers/phonemes/audio/phoneme-t.gen.mp3` | cat, hat, ten, pot, nut |
| [ ] | **x** | `/ks/` | "ks" | `content/generated/explorers/phonemes/audio/phoneme-x.gen.mp3` | six, box |

Notes for listening:
- Short vowels are the hardest: **a** must be the vowel of *cat* (not "ay"), **o** the vowel of *dog* (not "oh"), **u** the vowel of
  *cup*, **i** of *pig*, **e** of *hen*.
- Stop consonants (b, c, d, g, p, t) cannot be said without a little vowel; it should be as short and quiet as possible ("kuh",
  not "kay"). m, n, s, f should be held sounds ("mmm", "sss").
- **x** is two sounds, /ks/, as in *box* and *six*.
