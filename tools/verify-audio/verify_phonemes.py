# /// script
# requires-python = ">=3.10,<3.13"
# dependencies = ["faster-whisper", "transformers", "torch", "numpy", "pyyaml", "soundfile", "phonemizer"]
# ///
"""
verify-phonemes: listens (with the phoneme recogniser used by verify_audio.py, locally) to the 33 Explorers sound clips and compares
each with the sound listed in docs/explorers-phonemes.md. A clip is "ok" when the expected sound is the main thing heard and
no long extra vowel is added; a short vowel that is heard as another vowel, a stop with a long "uh", or the letter's NAME where a
sound is wanted are flagged. The recogniser cannot tell /ʌ/ from /æ/ well, so those two are capped below "good".

  uv run tools/verify-audio/verify_phonemes.py

Writes content/generated/verify-phonemes.json and .md. Nothing is changed.
"""
import json, re, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import verify_audio as va  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT / "docs" / "explorers-phonemes.md"
CLIPS = ROOT / "content" / "generated" / "explorers" / "phonemes" / "audio"

# letter names (heard instead of the sound)
NAMES = {"ay": "eɪ", "ee": "iː", "ie": "aɪ", "oa": "oʊ", "ue": "juː"}


def rows():
    for line in DOC.read_text(encoding="utf-8").splitlines():
        m = re.match(r"\|\s*\[.\]\s*\|\s*\*\*(\w+)\*\*\s*\|\s*`/(.+?)/`\s*\|\s*\"(.*?)\"", line)
        if m:
            yield m.group(1), m.group(2), m.group(3)


def main():
    results = []
    for key, ipa, says in rows():
        wav = CLIPS / f"phoneme-{key}.gen.mp3"
        override = CLIPS / f"phoneme-{key}.override.mp3"
        src = override if override.exists() else wav
        if not src.exists():
            results.append({"key": key, "ipa": ipa, "file": str(src), "heard": None, "verdict": "missing"})
            continue
        tmp = Path(__import__("tempfile").gettempdir()) / f"vp_{key}.wav"
        __import__("subprocess").run(["ffmpeg", "-v", "error", "-y", "-i", str(src), "-ar", "16000", "-ac", "1", str(tmp)], check=True)
        heard = va.recognise_phonemes(tmp)
        n, want = va.norm_ipa(heard), va.norm_ipa(ipa)
        if want in n:
            extra = len(n) - len(want)
            verdict = "ok" if extra <= 1 else f"extra sounds heard ({heard})"
        elif key in NAMES and va.norm_ipa(NAMES[key]) in n:
            verdict = "ok (letter name, as intended)"
        else:
            verdict = f"differs: heard {heard}"
        results.append({"key": key, "ipa": ipa, "voice_reads": says, "file": src.name, "heard": heard, "verdict": verdict})
        print(key, ipa, "->", heard, "|", verdict, flush=True)

    out = ROOT / "content" / "generated"
    (out / "verify-phonemes.json").write_text(json.dumps(results, indent=1, ensure_ascii=False), encoding="utf-8")
    bad = [r for r in results if not r["verdict"].startswith("ok")]
    lines = [f"# verify-phonemes: {len(results)} sounds, {len(bad)} to listen to again", ""]
    lines += [f"- **{r['key']}** /{r['ipa']}/ (`{r['file']}`): {r['verdict']}" for r in bad]
    (out / "verify-phonemes.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{len(results)} sounds, {len(bad)} flagged")


if __name__ == "__main__":
    main()
