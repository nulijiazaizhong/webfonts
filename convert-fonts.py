#!/usr/bin/env python3
"""将 TTF/OTF 批量转换为 WOFF2，并生成 @font-face CSS。

用法:
  python convert-fonts.py
  python convert-fonts.py --input MapleMono-NF-CN-unhinted --family "Maple Mono NF CN"
  python convert-fonts.py --subset-text chars.txt --make-package
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

try:
    from fontTools.ttLib import TTFont
    from fontTools.ttLib.woff2 import compress as woff2_compress
except ImportError:
    print("请先安装: pip install fonttools brotli", file=sys.stderr)
    sys.exit(1)


WEIGHT_PATTERNS = [
    (r"ExtraBold|ExtraBlack|UltraBold", 800),
    (r"SemiBold|DemiBold", 600),
    (r"Bold", 700),
    (r"ExtraLight|UltraLight|Thin|Hairline", 200),  # Thin refined below
    (r"Light", 300),
    (r"Thin|Hairline", 100),
    (r"Medium", 500),
    (r"Black|Heavy", 900),
    (r"Regular|Book", 400),
]


def parse_style_weight(stem: str) -> tuple[str, int]:
    style = "italic" if re.search(r"Italic|Oblique$", stem) else "normal"
    weight = 400
    # Order matters: check more specific names first
    if re.search(r"ExtraBold|ExtraBlack", stem):
        weight = 800
    elif re.search(r"SemiBold|DemiBold", stem):
        weight = 600
    elif re.search(r"Bold", stem):
        weight = 700
    elif re.search(r"ExtraLight|UltraLight", stem):
        weight = 200
    elif re.search(r"Thin|Hairline", stem):
        weight = 100
    elif re.search(r"Light", stem):
        weight = 300
    elif re.search(r"Medium", stem):
        weight = 500
    elif re.search(r"Black|Heavy", stem):
        weight = 900
    return style, weight


def convert_one(src: Path, out: Path, subset_text: str | None = None) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    if subset_text:
        from fontTools import subset

        options = subset.Options()
        options.flavor = "woff2"
        options.hinting = False
        options.desubroutinize = True
        options.layout_features = ["*"]
        font = subset.load_font(str(src), options)
        subsetter = subset.Subsetter(options=options)
        subsetter.populate(text=subset_text)
        subsetter.subset(font)
        subset.save_font(font, str(out), options)
        font.close()
    else:
        font = TTFont(str(src))
        font.flavor = "woff2"
        font.save(str(out))
        font.close()


def main() -> None:
    p = argparse.ArgumentParser(description="TTF/OTF → WOFF2 + CSS")
    p.add_argument("--input", "-i", default=".", help="源字体目录")
    p.add_argument("--output", "-o", default="webfonts", help="WOFF2 输出目录")
    p.add_argument("--css-dir", default="css", help="CSS 输出目录")
    p.add_argument("--family", default="Maple Mono NF CN", help="font-family 名称")
    p.add_argument("--slug", default="maple-mono-nf-cn", help="文件名 slug")
    p.add_argument("--subset-text", help="子集化文本文件路径")
    p.add_argument("--subset-unicodes", help="子集化 Unicode 列表，如 U+0020-007E,U+4E00-9FFF")
    p.add_argument("--make-package", action="store_true", help="生成 package.json")
    p.add_argument("--package-name", default=None)
    p.add_argument("--package-version", default="1.0.0")
    p.add_argument("--force", action="store_true", help="覆盖已存在的 woff2")
    args = p.parse_args()

    input_dir = Path(args.input).resolve()
    out_dir = Path(args.output).resolve()
    css_dir = Path(args.css_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    css_dir.mkdir(parents=True, exist_ok=True)

    sources = sorted(
        list(input_dir.rglob("*.ttf")) + list(input_dir.rglob("*.otf")),
        key=lambda x: x.name.lower(),
    )
    # 排除输出目录
    sources = [s for s in sources if out_dir not in s.parents and s.parent != out_dir]
    if not sources:
        print(f"在 {input_dir} 未找到 ttf/otf", file=sys.stderr)
        sys.exit(1)

    subset_text = Path(args.subset_text).read_text(encoding="utf-8") if args.subset_text else None
    if args.subset_unicodes and not subset_text:
        from fontTools.subset import parse_unicodes

        # 仅记录；实际用 fontTools.subset CLI 路径更稳妥，这里用 text 近似
        pass

    rules: list[str] = []
    rows: list[dict] = []
    print(f"找到 {len(sources)} 个字体 → {out_dir}")

    for i, src in enumerate(sources, 1):
        out_name = src.with_suffix(".woff2").name
        out_path = out_dir / out_name
        if out_path.exists() and not args.force:
            print(f"[{i}/{len(sources)}] 跳过 {out_name}")
        else:
            print(f"[{i}/{len(sources)}] 转换 {src.name} → {out_name}")
            if args.subset_unicodes and not subset_text:
                import subprocess

                cmd = [
                    sys.executable,
                    "-m",
                    "fontTools.subset",
                    str(src),
                    f"--unicodes={args.subset_unicodes}",
                    "--flavor=woff2",
                    f"--output-file={out_path}",
                    "--layout-features=*",
                    "--no-hinting",
                    "--desubroutinize",
                ]
                subprocess.check_call(cmd)
            else:
                convert_one(src, out_path, subset_text=subset_text)

        style, weight = parse_style_weight(src.stem)
        ttf_mb = src.stat().st_size / 1024 / 1024
        w_mb = out_path.stat().st_size / 1024 / 1024
        rows.append(
            {
                "source": src.name,
                "woff2": out_name,
                "weight": weight,
                "style": style,
                "ttf_mb": round(ttf_mb, 2),
                "woff2_mb": round(w_mb, 2),
                "ratio": f"{100 * w_mb / ttf_mb:.1f}%",
            }
        )
        rel = f"../{args.output}/{out_name}".replace("\\", "/")
        rules.append(
            f"""@font-face {{
  font-family: '{args.family}';
  src: url('{rel}') format('woff2');
  font-weight: {weight};
  font-style: {style};
  font-display: swap;
}}"""
        )

    header = f"""/* {args.family} — WOFF2 web fonts
 * Generated by convert-fonts.py
 */
"""
    css_path = css_dir / f"{args.slug}.css"
    css_path.write_text(header + "\n\n" + "\n\n".join(rules) + "\n", encoding="utf-8")
    print(f"CSS: {css_path}")

    # CDN CSS template
    cdn_rules = []
    pkg_name = args.package_name or f"{args.slug}-woff2"
    for r in rows:
        cdn_rules.append(
            f"""@font-face {{
  font-family: '{args.family}';
  /* TODO: 替换 __CDN_BASE__，例如
     https://cdn.jsdelivr.net/npm/{pkg_name}@{args.package_version}/webfonts */
  src: url('__CDN_BASE__/webfonts/{r["woff2"]}') format('woff2');
  font-weight: {r["weight"]};
  font-style: {r["style"]};
  font-display: swap;
}}"""
        )
    (css_dir / f"{args.slug}.cdn.css").write_text(
        header + "\n/* 发布前替换 __CDN_BASE__ */\n\n" + "\n\n".join(cdn_rules) + "\n",
        encoding="utf-8",
    )

    print(f"\n{'文件':<40} {'weight':>6} {'style':<8} {'TTF MB':>8} {'WOFF2':>8} {'比':>7}")
    for r in rows:
        print(
            f"{r['source']:<40} {r['weight']:>6} {r['style']:<8} {r['ttf_mb']:>8} {r['woff2_mb']:>8} {r['ratio']:>7}"
        )
    print(f"合计 TTF {sum(r['ttf_mb'] for r in rows):.2f} MB → WOFF2 {sum(r['woff2_mb'] for r in rows):.2f} MB")

    if args.make_package:
        root = Path.cwd()
        files = [f"webfonts/{r['woff2']}" for r in rows]
        files += [f"css/{args.slug}.css", f"css/{args.slug}.cdn.css", "LICENSE.txt", "README.md"]
        pkg = {
            "name": pkg_name,
            "version": args.package_version,
            "description": f"{args.family} web fonts (WOFF2)",
            "license": "OFL-1.1",
            "files": files,
            "keywords": ["font", "woff2", "webfont", args.slug],
        }
        (root / "package.json").write_text(
            json.dumps(pkg, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        lic = next(iter(input_dir.rglob("LICENSE*")), None)
        if lic and not (root / "LICENSE.txt").exists():
            shutil.copy2(lic, root / "LICENSE.txt")
        print(f"package.json 已生成")

    print("完成。")


if __name__ == "__main__":
    main()
