<#
.SYNOPSIS
  将 TTF/OTF 批量转换为 WOFF2，并生成 @font-face CSS 与 npm/jsDelivr 发布骨架。

.DESCRIPTION
  依赖：Python 3 + fonttools + brotli
    py -m pip install fonttools brotli

  默认扫描当前目录（或 -InputDir）下的 *.ttf / *.otf，输出到 webfonts/，
  并生成 css/<family-slug>.css。可选 -MakePackage 生成 package.json。

.EXAMPLE
  .\convert-fonts.ps1
  .\convert-fonts.ps1 -InputDir .\MapleMono-NF-CN-unhinted -FamilyName "Maple Mono NF CN"
  .\convert-fonts.ps1 -SubsetTextFile .\chars.txt -MakePackage -PackageName "maple-mono-nf-cn-woff2"
#>
[CmdletBinding()]
param(
  [string]$InputDir = ".",
  [string]$OutputDir = "webfonts",
  [string]$CssDir = "css",
  [string]$FamilyName = "Maple Mono NF CN",
  [string]$FamilySlug = "maple-mono-nf-cn",
  # 可选：按文本子集化（显著减小体积）
  [string]$SubsetTextFile,
  [string]$SubsetUnicodes,
  # 可选：生成 npm package.json（便于发布到 jsDelivr）
  [switch]$MakePackage,
  [string]$PackageName = "maple-mono-nf-cn-woff2",
  [string]$PackageVersion = "1.0.0",
  [string]$Author = "",
  [string]$Homepage = "",
  [switch]$Force
)

$ErrorActionPreference = "Stop"

function Resolve-Python {
  foreach ($cand in @($env:MIMO_PYTHON, "python", "py")) {
    if (-not $cand) { continue }
    try {
      $out = & $cand -c "import sys; print(sys.executable)" 2>$null
      if ($out) { return $cand }
    } catch {}
  }
  throw "未找到 Python。请安装 Python 3 并执行: pip install fonttools brotli"
}

function Get-FontStyleWeight {
  param([string]$Name)
  # 从文件名解析 weight / italic，例如 MapleMono-NF-CN-BoldItalic.ttf
  $style = "normal"
  $weight = 400
  $base = $Name -replace '\.(ttf|otf)$', ''

  if ($base -match 'Italic$' -or $base -match 'Oblique$') { $style = "italic" }

  if ($base -match 'ExtraBold' -or $base -match 'ExtraBlack') { $weight = 800 }
  elseif ($base -match 'SemiBold' -or $base -match 'DemiBold') { $weight = 600 }
  elseif ($base -match 'Bold') { $weight = 700 }
  elseif ($base -match 'ExtraLight' -or $base -match 'UltraLight') { $weight = 200 }
  elseif ($base -match 'Light') { $weight = 300 }
  elseif ($base -match 'Thin' -or $base -match 'Hairline') { $weight = 100 }
  elseif ($base -match 'Medium') { $weight = 500 }
  elseif ($base -match 'Black' -or $base -match 'Heavy') { $weight = 900 }
  elseif ($base -match 'Regular' -or $base -match 'Book') { $weight = 400 }
  else { $weight = 400 }

  # BoldItalic：先判 Italic，再由上面 Bold 分支定 700（已处理）
  # ExtraBoldItalic 等同理

  [pscustomobject]@{ Style = $style; Weight = $weight }
}

$python = Resolve-Python
$InputDir = (Resolve-Path $InputDir).Path
$projectRoot = (Get-Location).Path

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
New-Item -ItemType Directory -Force -Path $CssDir | Out-Null
$OutputDir = (Resolve-Path $OutputDir).Path
$CssDir = (Resolve-Path $CssDir).Path

$sources = Get-ChildItem -Path $InputDir -File -Include *.ttf, *.otf -Recurse |
  Where-Object { $_.FullName -notlike "*\webfonts\*" }

if (-not $sources) {
  throw "在 $InputDir 未找到 .ttf / .otf 文件"
}

Write-Host "找到 $($sources.Count) 个字体文件" -ForegroundColor Cyan
Write-Host "输出目录: $OutputDir" -ForegroundColor DarkGray

$cssRules = New-Object System.Collections.Generic.List[string]
$results = @()
$i = 0

foreach ($src in $sources) {
  $i++
  $outName = [IO.Path]::ChangeExtension($src.Name, ".woff2")
  $outPath = Join-Path $OutputDir $outName

  if ((Test-Path $outPath) -and -not $Force) {
    Write-Host "[$i/$($sources.Count)] 跳过（已存在）: $outName" -ForegroundColor DarkGray
  }
  else {
    Write-Host "[$i/$($sources.Count)] 转换: $($src.Name) -> $outName" -ForegroundColor Yellow
    $pyArgs = @("-m", "fontTools.subset")  # 先判断是否子集化
    $doSubset = $false
    $subsetArgs = @()
    if ($SubsetTextFile -and (Test-Path $SubsetTextFile)) {
      $doSubset = $true
      $subsetArgs += @("--text-file=`"$SubsetTextFile`"")
    }
    if ($SubsetUnicodes) {
      $doSubset = $true
      $subsetArgs += @("--unicodes=$SubsetUnicodes")
    }

    if ($doSubset) {
      # 子集化并直接输出 woff2
      $cmd = "& `"$python`" -m fontTools.subset `"$($src.FullName)`" --flavor=woff2 --output-file=`"$outPath`" --layout-features='*' --no-hinting --desubroutinize " + ($subsetArgs -join " ")
    }
    else {
      $cmd = "& `"$python`" -m fontTools.ttLib.woff2 compress `"$($src.FullName)`" `"$outPath`""
    }

    Invoke-Expression $cmd
    if (-not (Test-Path $outPath)) {
      throw "转换失败: $($src.Name)"
    }
  }

  $meta = Get-FontStyleWeight -Name $src.Name
  $ttfSize = $src.Length
  $woff2Size = (Get-Item $outPath).Length
  $ratio = if ($ttfSize -gt 0) { [math]::Round(100 * $woff2Size / $ttfSize, 1) } else { 0 }

  $results += [pscustomobject]@{
    Source = $src.Name
    Woff2  = $outName
    Weight = $meta.Weight
    Style  = $meta.Style
    TtfMB  = [math]::Round($ttfSize / 1MB, 2)
    Woff2MB = [math]::Round($woff2Size / 1MB, 2)
    Ratio  = "$ratio%"
  }

  $cssRules.Add(@"
@font-face {
  font-family: '$FamilyName';
  src: url('../$OutputDir/$outName') format('woff2');
  font-weight: $($meta.Weight);
  font-style: $($meta.Style);
  font-display: swap;
}
"@)
}

# 写 CSS（本地相对路径版）
$cssPath = Join-Path $CssDir "$FamilySlug.css"
$cssHeader = @"
/* $FamilyName — WOFF2 web fonts
 * Generated by convert-fonts.ps1
 * Source format: TTF/OTF → WOFF2
 */
"@
Set-Content -Path $cssPath -Value ($cssHeader + "`n`n" + ($cssRules -join "`n`n")) -Encoding utf8
Write-Host "CSS 已生成: $cssPath" -ForegroundColor Green

# 可选：生成绝对路径 CSS 占位（发布后替换 CDN 前缀）
$cdnCssPath = Join-Path $CssDir "$FamilySlug.cdn.css"
$cdnRules = foreach ($r in $results) {
  @"
@font-face {
  font-family: '$FamilyName';
  /* TODO: 将 __CDN_BASE__ 替换为 jsDelivr 地址，例如
     https://cdn.jsdelivr.net/npm/$PackageName@$PackageVersion/webfonts */
  src: url('__CDN_BASE__/webfonts/$($r.Woff2)') format('woff2');
  font-weight: $($r.Weight);
  font-style: $($r.Style);
  font-display: swap;
}
"@
}
Set-Content -Path $cdnCssPath -Value ($cssHeader + "`n/* CDN 版：发布前替换 __CDN_BASE__ */`n`n" + ($cdnRules -join "`n`n")) -Encoding utf8

# 汇总
Write-Host "`n=== 转换结果 ===" -ForegroundColor Cyan
$results | Format-Table Source, Weight, Style, TtfMB, Woff2MB, Ratio -AutoSize

$totalTtf = ($results | Measure-Object TtfMB -Sum).Sum
$totalW = ($results | Measure-Object Woff2MB -Sum).Sum
Write-Host ("合计: TTF {0:N2} MB → WOFF2 {1:N2} MB" -f $totalTtf, $totalW) -ForegroundColor Green

# package.json（npm / jsDelivr）
if ($MakePackage) {
  $files = @($results.Woff2 | ForEach-Object { "webfonts/$_" })
  $files += @("css/$FamilySlug.css", "css/$FamilySlug.cdn.css", "LICENSE.txt", "README.md")

  $pkg = [ordered]@{
    name        = $PackageName
    version     = $PackageVersion
    description = "$FamilyName web fonts (WOFF2)"
    license     = "OFL-1.1"
    author      = $Author
    homepage    = $Homepage
    repository  = $Homepage
    files       = $files
    keywords    = @("font", "woff2", "webfont", $FamilySlug)
  }
  if (-not $Author) { $pkg.Remove("author") }
  if (-not $Homepage) { $pkg.Remove("homepage"); $pkg.Remove("repository") }

  $pkgPath = Join-Path $projectRoot "package.json"
  $pkg | ConvertTo-Json -Depth 5 | Set-Content -Path $pkgPath -Encoding utf8
  Write-Host "package.json 已生成: $pkgPath" -ForegroundColor Green

  # 拷贝许可证（若源目录有）
  $lic = Get-ChildItem -Path $InputDir -Filter "LICENSE*" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($lic -and -not (Test-Path (Join-Path $projectRoot "LICENSE.txt"))) {
    Copy-Item $lic.FullName (Join-Path $projectRoot "LICENSE.txt")
    Write-Host "已复制 LICENSE" -ForegroundColor DarkGray
  }
}

Write-Host "`n完成。网页引入示例见 README.md" -ForegroundColor Cyan
