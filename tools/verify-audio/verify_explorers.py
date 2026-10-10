# /// script
# requires-python = ">=3.10,<3.13"
# dependencies = ["faster-whisper", "numpy", "pyyaml"]
# ///
"""
verify-explorers: listens (Whisper, locally, no network) to EVERY generated Explorers clip (words, sight words, plurals, sentences, intros,
praise, instructions) and compares what is said with the text the lesson file says it should be. Writes content/generated/verify-explorers.json
with a risk per clip (0 = said exactly, 1 = nothing like it). The phonemes are not here (they are single sounds: verify_phonemes.py).

  uv run tools/verify-audio/verify_explorers.py

Then: node tools/verify-audio/make_listen_page.mjs   (builds the one review page, sorted by risk).
Nothing is changed and nothing leaves this computer.
"""
import difflib, json, re, subprocess
from pathlib import Path

import numpy as np
import yaml

ROOT = Path(__file__).resolve().parents[2]
GEN = ROOT / "content" / "generated" / "explorers"
CUR = ROOT / "content" / "curriculum"

NUMBERS = {"0": "zero", "1": "one", "2": "two", "3": "three", "4": "four", "5": "five", "6": "six", "7": "seven", "8": "eight", "9": "nine", "10": "ten",
           "11": "eleven", "12": "twelve", "13": "thirteen", "14": "fourteen", "15": "fifteen", "16": "sixteen", "17": "seventeen", "18": "eighteen", "19": "nineteen",
           "20": "twenty", "30": "thirty", "40": "forty", "50": "fifty", "60": "sixty", "70": "seventy", "80": "eighty", "90": "ninety", "100": "hundred"}
# what Whisper writes for a word that is said right: same sound, other spelling (not a mistake)
HOMOPHONES = [("o'clock", "oclock"), ("o clock", "oclock"), ("to", "two"), ("too", "two"), ("for", "four"), ("won", "one"), ("ate", "eight"), ("son", "sun"), ("bee", "b"), ("eye", "i")]


def slug(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def norm(s: str) -> str:
    s = s.lower().replace("-", " ")
    s = re.sub(r"[^a-z0-9' ]", "", s)
    s = " ".join(NUMBERS.get(w, w) for w in s.split())
    for a, b in HOMOPHONES:
        s = re.sub(rf"\b{re.escape(a)}\b", b, s)
    return s.replace("'", "").replace(" ", "")


def load(path: Path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le", "-ac", "1", "-ar", "16000", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32)


def expected_for(lesson: dict) -> dict:
    out = {}
    n = lesson.get("narration") or {}
    if n.get("intro"):
        out["intro"] = n["intro"]
    for i, p in enumerate(n.get("praise") or []):
        out[f"praise-{i}"] = p
    for k, v in (n.get("instructions") or {}).items():
        out[f"instr-{k}"] = v
    for w in lesson.get("words") or []:
        word = w["word"] if isinstance(w, dict) else str(w)
        out[f"word-{slug(word)}"] = (w.get("say") if isinstance(w, dict) and w.get("say") else word)
        if isinstance(w, dict) and w.get("plural"):
            out[f"plural-{slug(w['plural'])}"] = w["plural"]
    for sw in lesson.get("sightWords") or []:
        out[f"sight-{slug(str(sw))}"] = str(sw)
    for i, s in enumerate(lesson.get("sentences") or []):
        out[f"sentence-{i + 1}"] = s["text"] if isinstance(s, dict) else str(s)
    return out


def main():
    from faster_whisper import WhisperModel
    model = WhisperModel("base.en", device="cpu", compute_type="int8")
    heard_cache, results = {}, []
    clips = []
    for d in sorted(p for p in GEN.iterdir() if p.is_dir() and p.name != "phonemes"):
        f = CUR / f"{d.name}.yaml"
        if not f.exists():
            continue
        expected = expected_for(yaml.safe_load(f.read_text(encoding="utf-8")))
        for mp3 in sorted((d / "audio").glob("*.gen.mp3")):
            role = mp3.name.removesuffix(".gen.mp3")
            if role in expected:
                clips.append((d.name, mp3, role, expected[role]))
    for i, (lesson, mp3, role, text) in enumerate(clips, 1):
        key = (mp3.stat().st_size, mp3.read_bytes()[:8192])
        if key not in heard_cache:
            segs, _ = model.transcribe(load(mp3), language="en", beam_size=5, temperature=0.0)
            heard_cache[key] = " ".join(s.text.strip() for s in segs).strip()
        heard = heard_cache[key]
        a, b = norm(heard), norm(text)
        sim = difflib.SequenceMatcher(None, a, b).ratio()
        # a word clip that also says more (a repeated sound effect, "Buzz buzz") is as risky as one that says less
        risk = round(1 - sim, 3)
        results.append({"lesson": lesson, "role": role, "file": str(mp3.relative_to(GEN)).replace("\\", "/"), "expected": text, "heard": heard, "risk": risk})
        if i % 100 == 0:
            print(f"{i}/{len(clips)}", flush=True)
    results.sort(key=lambda r: -r["risk"])
    (ROOT / "content" / "generated" / "verify-explorers.json").write_text(json.dumps(results, indent=1, ensure_ascii=False), encoding="utf-8")
    flagged = sum(1 for r in results if r["risk"] >= 0.25)
    print(f"{len(results)} clips heard, {flagged} with risk >= 0.25. Next: node tools/verify-audio/make_listen_page.mjs")


if __name__ == "__main__":
    main()
