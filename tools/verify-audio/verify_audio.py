# /// script
# requires-python = ">=3.10,<3.13"
# dependencies = ["faster-whisper", "transformers", "torch", "numpy", "pyyaml", "soundfile", "phonemizer"]
# ///
"""
verify-audio: checks the letter intros ("This is the letter B." <pause> /b/ <pause> /b/ <pause> "ball!").

  uv run tools/verify-audio/verify_audio.py --lesson letter-b letter-p letter-v
  uv run tools/verify-audio/verify_audio.py --all-letters

For every lesson it
  1. runs ffmpeg technical checks: decodes, duration, clipping, level, and that there are exactly four spoken
     parts separated by pauses of about 0.7 / 0.5 / 0.7 seconds;
  2. transcribes the first part ("This is the letter B.") and the last part (the example word) with Whisper, locally;
  3. runs a phoneme recogniser (wav2vec2, espeak IPA) on the two sound parts and compares with the lesson's phoneme,
     and flags a sound that was read as the letter's NAME ("bee");
  4. writes content/generated/verify-audio.json and content/generated/verify-audio.html (players + verdicts).
Nothing is sent over the network except the one-time model downloads. A failed check never changes any file.
"""
import argparse, html, json, re, subprocess, sys, tempfile, unicodedata
from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parents[2]
PAUSES = [0.7, 0.5, 0.7]
PAUSE_TOLERANCE = 0.2
PHONEME_MODEL = "facebook/wav2vec2-lv-60-espeak-cv-ft"

# what a TTS says when it reads the single letter: the NAME, not the sound
LETTER_NAMES = dict(a="eɪ", b="biː", c="siː", d="diː", e="iː", f="ɛf", g="dʒiː", h="eɪtʃ", i="aɪ", j="dʒeɪ", k="keɪ", l="ɛl",
                    m="ɛm", n="ɛn", o="oʊ", p="piː", q="kjuː", r="ɑːr", s="ɛs", t="tiː", u="juː", v="viː", w="dʌbəljuː",
                    x="ɛks", y="waɪ", z="ziː")


def norm_ipa(s: str) -> str:
    s = unicodedata.normalize("NFC", s)
    for ch in "ˈˌː ʰ̩͡ˑ.":
        s = s.replace(ch, "")
    # rough equivalences between the dictionary and the recogniser's symbols
    return s.replace("ɡ", "g").replace("ɐ", "ʌ").replace("ɑ", "a").replace("ɔ", "ɒ").replace("e", "ɛ").replace("ɹ", "r")


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


def technical(path: Path):
    """ffmpeg: level + spoken parts. Returns (checks, parts[(start, end)], duration)."""
    checks = []
    probe = run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)])
    try:
        duration = float(probe.stdout.strip())
    except ValueError:
        return [("decodes", False, "ffprobe could not read the file")], [], 0.0
    checks.append(("decodes", True, f"{duration:.2f}s"))
    vol = run(["ffmpeg", "-hide_banner", "-i", str(path), "-af", "volumedetect", "-f", "null", "-"]).stderr
    mean = re.search(r"mean_volume: (-?[\d.]+) dB", vol)
    peak = re.search(r"max_volume: (-?[\d.]+) dB", vol)
    if mean and peak:
        checks.append(("not clipped", float(peak.group(1)) <= -0.3, f"peak {peak.group(1)} dB"))
        checks.append(("not too quiet", float(mean.group(1)) >= -35, f"mean {mean.group(1)} dB"))
    sil = run(["ffmpeg", "-hide_banner", "-i", str(path), "-af", "silencedetect=noise=-42dB:d=0.25", "-f", "null", "-"]).stderr
    starts = [float(x) for x in re.findall(r"silence_start: ([\d.]+)", sil)]
    ends = [float(x) for x in re.findall(r"silence_end: ([\d.]+)", sil)]
    gaps = list(zip(starts, ends[: len(starts)]))
    # a silence touching the very start or end is not a pause between parts
    gaps = [(s, e) for s, e in gaps if s > 0.05 and e < duration - 0.05]
    lens = [round(e - s, 2) for s, e in gaps]
    ok = len(gaps) == len(PAUSES) and all(abs(l - p) <= PAUSE_TOLERANCE for l, p in zip(lens, PAUSES))
    checks.append(("pauses 0.7 / 0.5 / 0.7 s", ok, "found " + (", ".join(f"{l:.2f}" for l in lens) or "none")))
    if len(gaps) != len(PAUSES):
        return checks, [], duration
    bounds = [0.0] + [x for g in gaps for x in g] + [duration]
    parts = [(bounds[i], bounds[i + 1]) for i in range(0, len(bounds), 2)]
    return checks, parts, duration


def cut(src: Path, start: float, end: float, dst: Path):
    run(["ffmpeg", "-y", "-v", "error", "-i", str(src), "-ss", f"{start:.3f}", "-to", f"{end:.3f}", "-ar", "16000", "-ac", "1", str(dst)])


def words(s: str):
    return re.findall(r"[a-z']+", s.lower().replace("-", " "))


class Models:
    whisper = None
    phon = None

    @classmethod
    def get_whisper(cls):
        if cls.whisper is None:
            from faster_whisper import WhisperModel
            cls.whisper = WhisperModel("base.en", device="cpu", compute_type="int8")
        return cls.whisper

    @classmethod
    def get_phon(cls):
        if cls.phon is None:
            # the processor's own tokenizer needs espeak-ng installed only to turn TEXT into phonemes; we only decode, so read the vocab directly
            from huggingface_hub import hf_hub_download
            from transformers import Wav2Vec2FeatureExtractor, Wav2Vec2ForCTC
            vocab = json.loads(Path(hf_hub_download(PHONEME_MODEL, "vocab.json")).read_text(encoding="utf-8"))
            cls.phon = (Wav2Vec2FeatureExtractor.from_pretrained(PHONEME_MODEL), Wav2Vec2ForCTC.from_pretrained(PHONEME_MODEL).eval(), {v: k for k, v in vocab.items()}, vocab.get("<pad>", 0))
        return cls.phon


def transcribe(wav: Path) -> str:
    import numpy as np, soundfile as sf
    audio, _sr = sf.read(str(wav), dtype="float32")  # 16 kHz mono, cut by ffmpeg
    segs, _ = Models.get_whisper().transcribe(audio, language="en", beam_size=5, temperature=0.0)
    return " ".join(s.text.strip() for s in segs).strip()


def recognise_phonemes(wav: Path) -> str:
    import numpy as np, soundfile as sf, torch
    fe, model, inv, pad = Models.get_phon()
    audio, sr = sf.read(str(wav))
    if audio.ndim > 1:
        audio = audio.mean(axis=1)
    inputs = fe(audio.astype(np.float32), sampling_rate=sr, return_tensors="pt")
    with torch.no_grad():
        ids = model(inputs.input_values).logits.argmax(-1)
    out, prev = [], None
    for i in ids[0].tolist():  # greedy CTC: collapse repeats, drop blanks
        if i != prev and i != pad and not inv.get(i, "<").startswith("<"):
            out.append(inv[i])
        prev = i
    return "".join(out).strip()


def verify_lesson(lesson_id: str, track: str, tmp: Path):
    cur = yaml.safe_load((ROOT / "content" / "curriculum" / f"{lesson_id}.yaml").read_text(encoding="utf-8"))
    letter = cur["letter"]
    expected_word = cur["narration"].get("introWord", "")
    expected_phoneme = cur["phoneme"].strip("/")
    path = ROOT / "content" / "generated" / track / lesson_id / "audio" / "intro.gen.mp3"
    result = dict(lesson=lesson_id, letter=letter, file=str(path.relative_to(ROOT)), checks=[], parts=[])
    if not path.exists():
        result["checks"].append(dict(name="file exists", ok=False, detail="intro.gen.mp3 missing"))
        return result
    checks, parts, duration = technical(path)
    result["duration"] = duration
    result["checks"] += [dict(name=n, ok=o, detail=d) for n, o, d in checks]
    if len(parts) == 4:
        wavs = []
        for i, (s, e) in enumerate(parts):
            w = tmp / f"{lesson_id}-{i}.wav"
            cut(path, s, e, w)
            wavs.append(w)
        name_text = transcribe(wavs[0])
        want = words(f"this is the letter {letter}")
        got = words(name_text)
        # Whisper may spell a lone letter as "B", "Bee" or "be"; the first four words must match
        ok_name = got[:4] == want[:4] and len(got) >= 5
        result["checks"].append(dict(name='part 1 says "This is the letter ' + letter + '."', ok=ok_name, detail=f'heard "{name_text}"'))
        word_text = transcribe(wavs[3])
        ok_word = words(expected_word) == words(word_text)
        result["checks"].append(dict(name=f'part 4 says "{expected_word}"', ok=ok_word, detail=f'heard "{word_text}"'))
        phon = [recognise_phonemes(wavs[1]), recognise_phonemes(wavs[2])]
        want_ph = norm_ipa(expected_phoneme)
        name_ph = norm_ipa(LETTER_NAMES.get(letter.lower(), "~"))
        for i, p in enumerate(phon, 1):
            n = norm_ipa(p)
            is_name = bool(name_ph) and name_ph in n and name_ph != want_ph and want_ph not in n.replace(name_ph, "")
            ok_p = want_ph in n and not is_name
            detail = f"heard /{p}/ , expected /{expected_phoneme}/" + (" - sounds like the letter NAME" if is_name else "")
            result["checks"].append(dict(name=f"sound {i} is /{expected_phoneme}/", ok=ok_p, detail=detail))
        result["parts"] = [dict(start=round(s, 2), end=round(e, 2)) for s, e in parts]
        result["transcripts"] = dict(name=name_text, word=word_text, phonemes=phon)
    result["ok"] = all(c["ok"] for c in result["checks"])
    return result


def write_review(results, out: Path):
    rows = []
    for r in results:
        verdict = "PASS" if r.get("ok") else "CHECK"
        cls = "ok" if r.get("ok") else "bad"
        checks = "".join(f'<li class="{"ok" if c["ok"] else "bad"}">{"✔" if c["ok"] else "✘"} {html.escape(c["name"])} <small>{html.escape(c["detail"])}</small></li>' for c in r["checks"])
        src = "/".join(Path(r["file"]).parts[-4:]).replace("\\", "/")
        rows.append(f'<section><h2>{html.escape(r["lesson"])} <span class="{cls}">{verdict}</span></h2>'
                    f'<audio controls src="{html.escape("../../" + r["file"].replace(chr(92), "/"))}"></audio><ul>{checks}</ul></section>')
    out.write_text('<!doctype html><meta charset="utf-8"><title>verify-audio</title>'
                   '<style>body{font:16px system-ui;max-width:760px;margin:2em auto;padding:0 1em}.ok{color:#1a7f37}.bad{color:#c62828}'
                   'li{list-style:none;margin:.3em 0}small{color:#666}section{border-bottom:1px solid #ddd;padding:1em 0}</style>'
                   '<h1>verify-audio</h1><p>Listening is still the final check: Whisper and the phoneme model are aids, not judges.</p>'
                   + "".join(rows), encoding="utf-8")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lesson", nargs="*", default=[])
    ap.add_argument("--all-letters", action="store_true")
    ap.add_argument("--track", default="little-learners")
    a = ap.parse_args()
    ids = list(a.lesson)
    if a.all_letters:
        ids += sorted(p.stem for p in (ROOT / "content" / "curriculum").glob("letter-?.yaml"))
    if not ids:
        ap.error("give --lesson <id>... or --all-letters")
    results = []
    with tempfile.TemporaryDirectory() as t:
        for lid in ids:
            r = verify_lesson(lid, a.track, Path(t))
            results.append(r)
            print(f'{"PASS " if r.get("ok") else "CHECK"} {lid}')
            for c in r["checks"]:
                print(f'   {"ok " if c["ok"] else "BAD"} {c["name"]}: {c["detail"]}')
    gen = ROOT / "content" / "generated"
    (gen / "verify-audio.json").write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
    write_review(results, gen / "verify-audio.html")
    print(f"\nReview page: {gen / 'verify-audio.html'}")
    sys.exit(0 if all(r.get("ok") for r in results) else 1)


if __name__ == "__main__":
    main()
