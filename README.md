# Maple Mono NF CN Web Fonts

网页用 **WOFF2** 字体包，按文件夹组织，可直接通过 [jsDelivr](https://www.jsdelivr.com/) 引用。

字体来源：[Maple Mono](https://github.com/subframe7536/maple-font) · 许可证：SIL OFL 1.1

## 目录结构

```text
webfonts/              # 全量 WOFF2（16 字重/斜体，约 97MB）
css/
  maple-mono-nf-cn.css # 本地 @font-face
  maple-mono-nf-cn.cdn.css
demo/index.html        # 浏览器预览
packages/
  slim-core/           # 精简包 4 文件 ≈ 25MB（推荐）
  slim-standard/       # 精简包 6 文件 ≈ 37MB
convert-fonts.ps1      # TTF/OTF → WOFF2
convert-fonts.py
make-slim.ps1          # 生成精简包
make-slim.py
publish.ps1
```

## jsDelivr 引用（GitHub）

替换 `<user>/<repo>` 与 tag：

```html
<!-- 全量 Regular -->
<link rel="stylesheet"
  href="https://cdn.jsdelivr.net/gh/nulijiazaizhong/webfonts@main/css/maple-mono-nf-cn.css" />
```

或只引用精简包：

```html
<link rel="stylesheet"
  href="https://cdn.jsdelivr.net/gh/nulijiazaizhong/webfonts@main/packages/slim-core/css/maple-mono-nf-cn.css" />
```

单文件：

```text
https://cdn.jsdelivr.net/gh/nulijiazaizhong/webfonts@main/webfonts/MapleMono-NF-CN-Regular.woff2
https://cdn.jsdelivr.net/gh/nulijiazaizhong/webfonts@main/packages/slim-core/webfonts/MapleMono-NF-CN-Regular.woff2
```

生产环境建议固定 tag（如 `@v7.9.0`），不要用 `@main`。

## 本地预览

用浏览器打开 `demo/index.html`，或：

```powershell
python -m http.server 8080
# 打开 http://localhost:8080/demo/
```

## 重新生成

```powershell
pip install fonttools brotli
.\convert-fonts.ps1 -InputDir .\MapleMono-NF-CN-unhinted
.\make-slim.ps1 -Preset core
.\make-slim.ps1 -Preset standard
```
