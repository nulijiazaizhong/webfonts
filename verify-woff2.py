from pathlib import Path
from fontTools.ttLib import TTFont

files = sorted(Path("webfonts").glob("*.woff2"))
ok = 0
for p in files:
    f = TTFont(str(p))
    print(f"{p.name}: {p.stat().st_size/1024/1024:.2f} MB, glyphs={f['maxp'].numGlyphs}")
    f.close()
    ok += 1
print(f"validated {ok}/{len(files)}")
