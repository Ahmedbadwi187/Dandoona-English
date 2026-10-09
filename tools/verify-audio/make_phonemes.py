# /// script
# requires-python = ">=3.10,<3.13"
# dependencies = ["faster-whisper", "transformers", "torch", "numpy", "pyyaml", "soundfile", "phonemizer"]
# ///
"""
make_phonemes: finds a good isolated sound (/b/, /p/ ...) for each letter, with Dandoona's voice.

  uv run tools/verify-audio/make_phonemes.py --stage respell            # step 1: "buh", "bh", "b-b"
  uv run tools/verify-audio/make_phonemes.py --stage tags --tag-model eleven_flash_v2   # step 2 (only letters that failed)
  uv run tools/verify-audio/make_phonemes.py --stage cut                # step 3: cut the first sound out of short words
  uv run tools/verify-audio/make_phonemes.py --stage apply              # copy each letter's best clip to phoneme.gen.mp3

Every candidate is scored by the phoneme recogniser (see verify_audio.score_sound). Generated candidates are kept in
content/generated/<track>/<lesson>/audio/_review/ (git-ignored) and never generated twice; the choices and scores are
in content/generated/phoneme-choices.json. Spend is added to content/generated/cost-ledger.json.
"""
import argparse, json, os, re, subprocess, sys, urllib.request, urllib.error
from datetime import datetime, timezone
from pathlib import Path
import yaml
import verify_audio as va

ROOT = va.ROOT
TRACK = "little-learners"
CHOICES = ROOT / "content" / "generated" / "phoneme-choices.json"
LEDGER = ROOT / "content" / "generated" / "cost-ledger.json"
RATE_PER_CHAR = 0.08 / 1000
RUN_CAP_USD = 1.00
GOOD = 0.75          # a clip scoring this or more is "good"; below it the next step is tried

RESPELL = dict(
    a=["aah", "aa", "ahh"], b=["buh", "bh", "b-b"], c=["kuh", "kh", "k-k"], d=["duh", "dh", "d-d"],
    e=["eh", "ehh", "eh-eh"], f=["fff", "ffff", "fuh"], g=["guh", "gh", "g-g"], h=["huh", "hh", "h-h"],
    i=["ih", "ihh", "ih-ih"], j=["juh", "jh", "j-j"], k=["kuh", "kh", "k-k"], l=["lll", "luh", "ll"],
    m=["mmm", "mm", "muh"], n=["nnn", "nn", "nuh"], o=["aw", "awh", "ahw"], p=["puh", "ph", "p-p"],
    q=["kwuh", "kw", "kwh"], r=["rrr", "ruh", "rr"], s=["sss", "ss", "suh"], t=["tuh", "tt", "t-t"],
    u=["uh", "uhh", "uh-uh"], v=["vvv", "vuh", "vv"], w=["wuh", "wh", "www"], x=["ks", "kss", "ksss"],
    y=["yuh", "yh", "yyy"], z=["zzz", "zuh", "zz"])
# short words that start with the sound (step 3); several words that start differently from the letter's name on purpose
CUT_WORDS = dict(
    a=["add", "ant", "act"], b=["bat", "bed", "bus"], c=["cat", "cup", "cot"], d=["dog", "dad", "dip"],
    e=["end", "egg", "elf"], f=["fan", "fun", "fit"], g=["got", "gum", "gap"], h=["hat", "hot", "hop"],
    i=["in", "it", "if"], j=["jam", "jug", "jet"], k=["kit", "kid", "cat"], l=["leg", "lip", "log"],
    m=["mat", "mom", "map"], n=["net", "nap", "nut"], o=["odd", "box", "on"], p=["pen", "pig", "pot"],
    q=["quit", "quiz", "quack"], r=["run", "rat", "red"], s=["sun", "sit", "sad"], t=["top", "ten", "tap"],
    u=["up", "us", "bus"], v=["van", "vet", "van."], w=["wet", "win", "web"], x=["six", "box", "fox"],
    y=["yes", "yet", "yam"], z=["zip", "zoo", "zap"])
CUT_WINDOWS = [0.14, 0.20, 0.28]   # seconds taken from the start of the word, after trimming leading silence


def load_env():
    for line in (ROOT / ".env").read_text(encoding="utf-8").splitlines():
        if "=" in line and not line.strip().startswith("#"):
            k, v = line.split("=", 1)
            os.environ.setdefault(k.strip(), v.strip().strip("\"'"))


def voice_settings():
    text = (ROOT / "content" / "style" / "voices.json").read_text(encoding="utf-8")
    text = re.sub(r"^\s*//.*$", "", text, flags=re.M)
    cfg = json.loads(text)
    v = cfg["voices"]["narrator"]
    return cfg, v, (v.get("voiceId") or os.environ["ELEVENLABS_VOICE_ID"])


class Spend:
    total = 0.0

    @classmethod
    def add(cls, what: str, chars: int):
        usd = chars * RATE_PER_CHAR
        if cls.total + usd > RUN_CAP_USD:
            sys.exit(f"Stopping: this run would spend more than ${RUN_CAP_USD:.2f}.")
        cls.total += usd
        entries = json.loads(LEDGER.read_text(encoding="utf-8"))
        entries.append(dict(atUtc=datetime.now(timezone.utc).isoformat(), service="ElevenLabs", what=what, usd=round(usd, 6), estimated=False))
        LEDGER.write_text(json.dumps(entries, indent=2), encoding="utf-8")


def synth(text: str, out: Path, model: str | None = None):
    """Dandoona's voice (voices.json narrator, same settings as every other line). Skips a file that already exists."""
    if out.exists():
        return
    cfg, v, voice_id = voice_settings()
    body = dict(text=text, model_id=model or cfg["model"], voice_settings=dict(
        stability=v["stability"], similarity_boost=v["similarityBoost"], style=v["style"], speed=v["speed"], use_speaker_boost=v["useSpeakerBoost"]))
    req = urllib.request.Request(f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}?output_format={cfg['outputFormat']}",
                                 data=json.dumps(body).encode(), headers={"xi-api-key": os.environ["ELEVENLABS_API_KEY"], "Content-Type": "application/json"})
    try:
        data = urllib.request.urlopen(req, timeout=120).read()
    except urllib.error.HTTPError as e:
        raise SystemExit(f"ElevenLabs {e.code}: {e.read().decode()[:300]}")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(data)
    Spend.add(f"phoneme candidate {out.parent.parent.parent.name}/{out.stem} ({len(text)} chars)", len(text))


def duration(path: Path) -> float:
    return float(va.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)]).stdout.strip())


def finish(src: Path, dst: Path, max_seconds: float | None = None):
    """Trim the silence round a clip, optionally keep only its first max_seconds, then fade 4 ms in and 10 ms out (no clicks)."""
    trim = "silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.01"
    chain = [trim, f"atrim=duration={max_seconds}"] if max_seconds else [trim, "areverse", trim, "areverse"]
    dst.parent.mkdir(parents=True, exist_ok=True)
    mid = dst.with_suffix(".mid.wav")
    r = va.run(["ffmpeg", "-y", "-v", "error", "-i", str(src), "-af", ",".join(chain), "-ac", "1", "-ar", "44100", str(mid)])
    if r.returncode:
        raise SystemExit(r.stderr)
    d = duration(mid)
    r = va.run(["ffmpeg", "-y", "-v", "error", "-i", str(mid), "-af", f"afade=t=in:d=0.004,afade=t=out:st={max(d - 0.01, 0):.3f}:d=0.01",
                "-c:a", "libmp3lame", "-b:a", "128k", str(dst)])
    mid.unlink()
    if r.returncode:
        raise SystemExit(r.stderr)


def score_file(mp3: Path, letter: str, expected: str, tmp: Path):
    wav = tmp / (mp3.stem + ".wav")
    va.run(["ffmpeg", "-y", "-v", "error", "-i", str(mp3), "-af", "adelay=300:all=1,apad=pad_dur=0.3", "-ar", "16000", "-ac", "1", str(wav)])  # the recogniser expects speech with silence round it
    dur = duration(mp3)
    s, heard, is_name = va.score_sound(wav, letter, expected, dur)
    return dict(score=round(s, 2), heard=heard, name_like=is_name, seconds=round(dur, 2))


def add(entry, cand):
    entry["candidates"] = [c for c in entry["candidates"] if c["file"] != cand["file"]] + [cand]


def letters():
    for p in sorted((ROOT / "content" / "curriculum").glob("letter-?.yaml")):
        cur = yaml.safe_load(p.read_text(encoding="utf-8"))
        yield p.stem, cur["letter"].lower(), cur["phoneme"].strip("/")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--stage", required=True, choices=["respell", "tags", "cut", "apply", "rescore", "settle"])
    ap.add_argument("--tag-model", help="ElevenLabs model id that supports <phoneme> tags")
    ap.add_argument("--only", nargs="*", help="letters, e.g. b p v")
    a = ap.parse_args()
    load_env()
    state = json.loads(CHOICES.read_text(encoding="utf-8")) if CHOICES.exists() else {}
    import tempfile
    with tempfile.TemporaryDirectory() as t:
        tmp = Path(t)
        for lesson, letter, ipa in letters():
            if a.only and letter not in a.only:
                continue
            entry = state.setdefault(lesson, dict(letter=letter, phoneme=ipa, candidates=[]))
            cdir = ROOT / "content" / "generated" / TRACK / lesson / "audio" / "_review"
            best = max(entry["candidates"], key=lambda c: c["score"], default=None)

            if a.stage == "settle":
                # the sound is judged again inside the real intro (cut out after the stitching): try the best candidates in turn
                if not a.only:
                    sys.exit("--stage settle needs --only <letters>")
                dst = ROOT / "content" / "generated" / TRACK / lesson / "audio" / "phoneme.gen.mp3"
                tried = []
                for cand in sorted(entry["candidates"], key=lambda c: -c["score"]):
                    if cand["score"] <= 0 or any(t[1]["file"] == cand["file"] for t in tried):
                        continue
                    dst.write_bytes((ROOT / cand["file"]).read_bytes())
                    subprocess.run(["dotnet", "run", "--no-build", "--", "audio", "--lesson", lesson], cwd=ROOT / "tools" / "AssetGenerator", capture_output=True)
                    res = va.verify_lesson(lesson, TRACK, tmp)
                    sound_ok = all(c["ok"] for c in res["checks"] if c["name"].startswith("sound"))
                    tried.append((sound_ok, cand))
                    print(f"  {lesson} {cand['method']} '{cand['text'][:40]}' {cand['score']}: {'ok' if sound_ok else 'no'}")
                    if sound_ok:
                        break
                pick = next((c for ok, c in tried if ok), None) or (tried[0][1] if tried else best)
                dst.write_bytes((ROOT / pick["file"]).read_bytes())
                subprocess.run(["dotnet", "run", "--no-build", "--", "audio", "--lesson", lesson], cwd=ROOT / "tools" / "AssetGenerator", capture_output=True)
                entry["applied"] = pick["file"]; entry["method"] = pick["method"]; entry["chosen"] = pick
                entry["best_available"] = not any(ok for ok, _ in tried)
                print(f"{lesson}: {pick['method']} '{pick['text'][:40]}'" + ("  BEST AVAILABLE" if entry["best_available"] else "  verified in the intro"))
                CHOICES.write_text(json.dumps(state, indent=2, ensure_ascii=False), encoding="utf-8")
                continue

            if a.stage == "rescore":   # same files, new scoring rules: no API calls
                for c in entry["candidates"]:
                    c.update(score_file(ROOT / c["file"], letter, ipa, tmp))
                best = max(entry["candidates"], key=lambda c: c["score"], default=None)
                print(f"{lesson}: best {best['method']} '{best['text']}' score {best['score']} heard /{best['heard']}/" if best else f"{lesson}: none")
                continue

            if a.stage == "apply":
                if not best:
                    print(f"{lesson}: no candidate"); continue
                dst = ROOT / "content" / "generated" / TRACK / lesson / "audio" / "phoneme.gen.mp3"
                orig = ROOT / "content" / "generated" / TRACK / lesson / "audio" / "_review" / "phoneme.tts-original.mp3"
                if dst.exists() and not orig.exists() and not entry.get("applied"):
                    orig.parent.mkdir(parents=True, exist_ok=True); orig.write_bytes(dst.read_bytes())
                dst.write_bytes((ROOT / best["file"]).read_bytes())
                entry["applied"] = best["file"]; entry["method"] = best["method"]; entry["chosen"] = best
                entry["best_available"] = best["score"] < GOOD
                print(f"{lesson}: {best['method']} '{best['text']}' score {best['score']} heard /{best['heard']}/" + ("  BEST AVAILABLE" if best["score"] < GOOD else ""))
                continue

            if best and best["score"] >= GOOD:
                print(f"{lesson}: already good ({best['method']} '{best['text']}' {best['score']})"); continue

            if a.stage == "respell":
                for text in RESPELL[letter]:
                    raw = cdir / f"respell-{re.sub('[^a-z]', '_', text)}.raw.mp3"
                    synth(text, raw)
                    fin = cdir / f"respell-{re.sub('[^a-z]', '_', text)}.mp3"
                    finish(raw, fin)
                    add(entry, dict(method="respelling", text=text, file=str(fin.relative_to(ROOT)), **score_file(fin, letter, ipa, tmp)))
            elif a.stage == "tags":
                if not a.tag_model:
                    sys.exit("--tag-model is needed for the tags stage")
                text = f'<phoneme alphabet="ipa" ph="{ipa}">{letter}</phoneme>'
                raw = cdir / f"tag-{a.tag_model}.raw.mp3"
                synth(text, raw, model=a.tag_model)
                fin = cdir / f"tag-{a.tag_model}.mp3"
                finish(raw, fin)
                add(entry, dict(method=f"phoneme tag ({a.tag_model})", text=text, file=str(fin.relative_to(ROOT)), **score_file(fin, letter, ipa, tmp)))
            elif a.stage == "cut":
                for word in CUT_WORDS[letter]:
                    raw = cdir / f"word-{re.sub('[^a-z]', '_', word)}.raw.mp3"
                    synth(word.strip("."), raw)
                    for w in CUT_WINDOWS:
                        fin = cdir / f"cut-{re.sub('[^a-z]', '_', word)}-{int(w * 1000)}ms.mp3"
                        finish(raw, fin, max_seconds=w)
                        add(entry, dict(method="cut from word", text=f"{word.strip('.')} first {int(w * 1000)} ms", file=str(fin.relative_to(ROOT)), **score_file(fin, letter, ipa, tmp)))
            best = max(entry["candidates"], key=lambda c: c["score"])
            print(f"{lesson}: best so far {best['method']} '{best['text']}' score {best['score']} heard /{best['heard']}/")
            CHOICES.write_text(json.dumps(state, indent=2, ensure_ascii=False), encoding="utf-8")
    CHOICES.write_text(json.dumps(state, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\nSpent this run: ${Spend.total:.4f}")


if __name__ == "__main__":
    main()
