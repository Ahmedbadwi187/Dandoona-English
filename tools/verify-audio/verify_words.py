# /// script
# requires-python = ">=3.10,<3.13"
# dependencies = ["faster-whisper", "numpy", "pyyaml"]
# ///
"""
verify-words: listens (with Whisper, locally, no network) to every generated word and sight-word clip and checks that what is
said is the word the lesson expects. It catches the gross mistakes ("car" said as "ca", "kite" as "kitty"); it cannot judge accent
or an isolated sound, so those stay for human ears.

  uv run tools/verify-audio/verify_words.py                 # every word-*.gen.mp3 and sight-*.gen.mp3 under content/generated
  uv run tools/verify-audio/verify_words.py --track explorers

Writes content/generated/verify-words.json and .md (the mismatches first). A clip with `say:` in its lesson is compared with the
word, not with the respelling. Nothing is changed.
"""
import argparse, json, re, subprocess
import numpy as np
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GEN = ROOT / "content" / "generated"

NUMBERS = {"0": "zero", "1": "one", "2": "two", "3": "three", "4": "four", "5": "five", "6": "six", "7": "seven", "8": "eight", "9": "nine", "10": "ten"}


def load(path: Path):
    """16 kHz mono floats through ffmpeg (faster-whisper brings its own decoder, which does not always match the installed av)."""
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le", "-ac", "1", "-ar", "16000", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32)


def norm(s: str) -> str:
    s = s.lower().replace("-", " ")
    s = re.sub(r"[^a-z0-9' ]", "", s)
    return " ".join(NUMBERS.get(w, w) for w in s.split())


def close(a: str, b: str) -> bool:
    """Same words, or the heard text contains the expected one (Whisper adds 'the' or a repeat sometimes)."""
    if a == b:
        return True
    if a.replace(" ", "") == b.replace(" ", ""):
        return True
    return bool(b) and re.search(rf"\b{re.escape(b)}\b", a) is not None and len(a.split()) <= len(b.split()) + 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--track", choices=["explorers", "little-learners"])
    args = ap.parse_args()
    from faster_whisper import WhisperModel
    model = WhisperModel("base.en", device="cpu", compute_type="int8")

    files = []
    for track in ([args.track] if args.track else ["little-learners", "explorers"]):
        for p in sorted((GEN / track).glob("*/audio/*.gen.mp3")):
            m = re.match(r"(word|sight)-(.+)\.gen\.mp3$", p.name)
            if m:
                files.append((track, p, m.group(2).replace("-", " ")))

    results, cache = [], {}
    for i, (track, p, expected) in enumerate(files, 1):
        key = p.stat().st_size, p.read_bytes()[:4096]  # identical clips (the same word in many lessons) are heard once
        if key in cache:
            heard = cache[key]
        else:
            segs, _ = model.transcribe(load(p), language="en", beam_size=5, temperature=0.0)
            heard = " ".join(s.text.strip() for s in segs).strip()
            cache[key] = heard
        ok = close(norm(heard), norm(expected))
        results.append({"track": track, "lesson": p.parent.parent.name, "file": p.name, "expected": expected, "heard": heard, "ok": ok})
        if i % 50 == 0:
            print(f"{i}/{len(files)}", flush=True)

    (GEN / "verify-words.json").write_text(json.dumps(results, indent=1, ensure_ascii=False), encoding="utf-8")
    bad = [r for r in results if not r["ok"]]
    lines = [f"# verify-words: {len(results)} clips, {len(bad)} differ from the word they should say", ""]
    lines += [f"- `{r['track']}/{r['lesson']}/{r['file']}`: expected **{r['expected']}**, heard \"{r['heard']}\"" for r in bad]
    (GEN / "verify-words.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{len(results)} clips, {len(bad)} differ. See content/generated/verify-words.md")


if __name__ == "__main__":
    main()
