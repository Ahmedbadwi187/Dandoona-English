# /// script
# dependencies = ["pillow"]
# ///
"""Dev only: puts the English and the Arabic screenshot of each page side by side (one file per page), for uploading to ChatGPT.
  uv run tools/ux-pairs.py        ->  dist/review/ux/for-chatgpt/NN-page.png"""
from pathlib import Path
from PIL import Image
root = Path(__file__).resolve().parents[1] / "dist" / "review" / "ux"
out = root / "for-chatgpt"; out.mkdir(exist_ok=True)
en = {p.name.split("-", 1)[1]: p for p in sorted((root / "en").glob("*.png"))}
ar = {p.name.split("-", 1)[1]: p for p in sorted((root / "ar").glob("*.png"))}
n = 0
for name, e in en.items():
    n += 1
    imgs = [Image.open(e)] + ([Image.open(ar[name])] if name in ar else [])
    w = sum(i.width for i in imgs) + 40 * (len(imgs) - 1)
    sheet = Image.new("RGB", (w, max(i.height for i in imgs)), "white")
    x = 0
    for i in imgs:
        sheet.paste(i, (x, 0)); x += i.width + 40
    sheet.thumbnail((1800, 2000))
    sheet.save(out / f"{n:02d}-{name}", optimize=True)
print(n, "files in", out)
