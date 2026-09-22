# @nulijiazaizhong/maple-mono-nf-cn-webfont

Maple Mono NF CN 网页字体（WOFF2），Fontsource 风格：一字重一个 CSS。

## 安装

```bash
npm install @nulijiazaizhong/maple-mono-nf-cn-webfont
```

或 jsDelivr：

```html
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@nulijiazaizhong/maple-mono-nf-cn-webfont@7.9.0/400.css" />
```

## 文件

| CSS | weight | style |
|-----|--------|-------|
| `400.css` | 400 | normal |
| `400-italic.css` | 400 | italic |
| `500.css` | 500 | normal |
| `600.css` | 600 | normal |
| `700.css` | 700 | normal |
| `700-italic.css` | 700 | italic |

## 字体配置示例

```yaml
- id: "maple-mono-nf-cn"
  family: "Maple Mono NF CN"
  role: "mono"
  source: "fontsource"
  variants:
    - file: "@nulijiazaizhong/maple-mono-nf-cn-webfont/400.css"
      weight: 400
      style: "normal"
    - file: "@nulijiazaizhong/maple-mono-nf-cn-webfont/400-italic.css"
      weight: 400
      style: "italic"
    - file: "@nulijiazaizhong/maple-mono-nf-cn-webfont/500.css"
      weight: 500
      style: "normal"
    - file: "@nulijiazaizhong/maple-mono-nf-cn-webfont/600.css"
      weight: 600
      style: "normal"
    - file: "@nulijiazaizhong/maple-mono-nf-cn-webfont/700.css"
      weight: 700
      style: "normal"
    - file: "@nulijiazaizhong/maple-mono-nf-cn-webfont/700-italic.css"
      weight: 700
      style: "italic"
  fallback:
    - "ui-monospace"
    - "monospace"
  display: "swap"
  preload: false
```

许可证：SIL OFL 1.1。
